"""
LexGuard AI — gRPC Legal AI Server (proto/legal_ai.proto implementatsiyasi)
Go backend bilan binar aloqa:
  - ProcessDocumentOCR: Skan/rasm hujjatlarni OCR qilib bandlarga ajratish
  - AnalyzeClauses: bandma-band streaming tahlil (qoidalar + Knowledge Graph multi-hop)
  - SelfCorrectFinding: Active Self-Correction
  - GenerateVoiceBrief: ovozli brifing va SSML
  - StreamVoiceQuery: ovozli savol-javob oqimi
"""

import logging
import os
import sys
from concurrent import futures
from typing import Iterator

import grpc

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from proto import legal_ai_pb2 as pb2
from proto import legal_ai_pb2_grpc as pb2_grpc

from app.analyzer import ClauseIn, Finding, analyzer
from app.knowledge_graph import legal_graph
from app.ocr import ocr_processor
from app.vector_store import legal_vector_store
from app.voice import answer_voice_query, build_voice_brief, chunk_words

logger = logging.getLogger("ai-engine-grpc")

MAX_MESSAGE_BYTES = 20 * 1024 * 1024  # OCR uchun fayl baytlari (backend limiti 15MB)


def _to_raw_finding(f: Finding, clause_id: str = None) -> pb2.RawFinding:
    return pb2.RawFinding(
        clause_id=f.clause_id if clause_id is None else clause_id,
        risk_level=f.risk_level,
        category=f.category,
        issue_title=f.issue_title,
        issue_explanation=f.issue_explanation,
        cited_article=f.cited_article,
        suggested_redline=f.suggested_redline,
        balance_label=f.balance_label,
    )


def _llm_allowed(use_local_only: bool) -> bool:
    refiner = analyzer.refiner
    return refiner is not None and (not use_local_only or refiner.is_local)


class LegalAIServiceImpl(pb2_grpc.LegalAIServiceServicer):
    """proto/legal_ai.proto shartnomasi bo'yicha gRPC servis implementatsiyasi."""

    def ProcessDocumentOCR(self, request: pb2.OCRRequest, context: grpc.ServicerContext) -> pb2.OCRResponse:
        logger.info("[gRPC] ProcessDocumentOCR: doc_id=%s, mime=%s", request.document_id, request.mime_type)
        try:
            res = ocr_processor.process_document(request.file_bytes, request.mime_type)
            return pb2.OCRResponse(
                full_text=res.get("full_text", ""),
                clauses=[
                    pb2.ExtractedClause(
                        clause_id=c.get("clause_id", ""), clause_number=c.get("clause_number", ""),
                        text=c.get("text", ""), page_number=c.get("page_number", 1),
                    )
                    for c in res.get("clauses", [])
                ],
                confidence_score=float(res.get("confidence_score", 0.95)),
            )
        except Exception as e:
            logger.error("[gRPC] OCR xatoligi: %s", e, exc_info=True)
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(f"OCR qayta ishlashda xatolik: {e}")
            return pb2.OCRResponse()

    def AnalyzeClauses(self, request: pb2.ClauseAnalysisRequest, context: grpc.ServicerContext) -> Iterator[pb2.ClauseAnalysisEvent]:
        clauses = list(request.clauses)
        total = max(len(clauses), 1)
        use_llm = _llm_allowed(request.use_local_slm_only)
        logger.info("[gRPC] AnalyzeClauses: analysis_id=%s, %d band, doc_type=%s, llm=%s",
                    request.analysis_id, len(clauses), request.document_type, use_llm)

        yield pb2.ClauseAnalysisEvent(event_type="stage_changed", progress_pct=5, stage_name="knowledge_graph_indexing")

        for idx, c in enumerate(clauses):
            if not context.is_active():  # mijoz (Go backend) uzildi — ishni to'xtatamiz
                logger.info("[gRPC] AnalyzeClauses bekor qilindi: %s", request.analysis_id)
                return
            try:
                report = analyzer.analyze_clause(
                    ClauseIn(c.clause_id, c.clause_number, c.text), request.document_type, request.party_role, use_llm,
                )
            except Exception as e:
                logger.error("[gRPC] Band tahlilida xatolik (%s): %s", c.clause_id, e, exc_info=True)
                continue

            progress = int(10 + (idx + 1) / total * 80)
            if not report.findings:
                yield pb2.ClauseAnalysisEvent(event_type="progress", progress_pct=progress, stage_name="clause_evaluation")
                continue
            for f in report.findings:
                yield pb2.ClauseAnalysisEvent(
                    event_type="partial_finding", progress_pct=progress,
                    stage_name="clause_evaluation", finding=_to_raw_finding(f),
                )

        yield pb2.ClauseAnalysisEvent(event_type="stage_changed", progress_pct=100, stage_name="completed")
        logger.info("[gRPC] AnalyzeClauses yakunlandi: %s", request.analysis_id)

    def SelfCorrectFinding(self, request: pb2.SelfCorrectionRequest, context: grpc.ServicerContext) -> pb2.SelfCorrectionResponse:
        logger.info("[gRPC] SelfCorrectFinding: error=%r, candidates=%s", request.verification_error, list(request.candidate_articles))
        try:
            f = analyzer.self_correct(
                request.clause_text, request.previous_cited_article, request.verification_error,
                list(request.candidate_articles),
            )
        except Exception as e:
            logger.error("[gRPC] SelfCorrect xatoligi: %s", e, exc_info=True)
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))
            return pb2.SelfCorrectionResponse(resolved=False)
        if f is None:
            return pb2.SelfCorrectionResponse(resolved=False)
        return pb2.SelfCorrectionResponse(resolved=True, corrected_finding=_to_raw_finding(f, clause_id=""))

    def GenerateVoiceBrief(self, request: pb2.VoiceBriefRequest, context: grpc.ServicerContext) -> pb2.VoiceBriefResponse:
        brief = build_voice_brief(list(request.top_risks), request.summary_text)
        return pb2.VoiceBriefResponse(
            audio_script_uz=brief["audio_script_uz"], ssml=brief["ssml"], duration_sec=brief["duration_sec"],
        )

    def StreamVoiceQuery(self, request_iterator: Iterator[pb2.VoiceQueryChunk], context: grpc.ServicerContext) -> Iterator[pb2.VoiceAnswerChunk]:
        for chunk in request_iterator:
            if not context.is_active():
                return
            query = chunk.user_query_text.strip()
            if not query:
                continue
            answer = answer_voice_query(query, legal_graph, legal_vector_store)
            parts = chunk_words(answer)
            for i, part in enumerate(parts):
                yield pb2.VoiceAnswerChunk(text_chunk=part, audio_chunk=b"", is_final=(i == len(parts) - 1))


def serve_grpc(port: int = 50051) -> grpc.Server:
    server = grpc.server(
        futures.ThreadPoolExecutor(max_workers=10),
        options=[
            ("grpc.max_receive_message_length", MAX_MESSAGE_BYTES),
            ("grpc.max_send_message_length", MAX_MESSAGE_BYTES),
        ],
    )
    pb2_grpc.add_LegalAIServiceServicer_to_server(LegalAIServiceImpl(), server)
    server.add_insecure_port(f"0.0.0.0:{port}")
    server.start()
    logger.info("LegalAIService gRPC Server ishga tushdi: 0.0.0.0:%s", port)
    return server


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    s = serve_grpc(50051)
    try:
        s.wait_for_termination()
    except KeyboardInterrupt:
        s.stop(0)
