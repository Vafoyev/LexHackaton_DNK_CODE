"""
LexGuard AI — gRPC Legal AI Server (proto/legal_ai.proto implementatsiyasi)
Muallif: AI & Legal Engineering Group
Vazifasi: Go backend bilan proto/legal_ai.proto orqali yuqori tezlikdagi binar aloqa:
  - ProcessDocumentOCR: Skan/rasm hujjatlarni OCR qilib bandlarga ajratish
  - AnalyzeClauses: Streaming tarzda multi-hop Knowledge Graph va SLM tahlili
  - SelfCorrectFinding: Active Self-Correction orqali xato moddalarni qayta aniqlash
  - GenerateVoiceBrief: Ovozli tahliliy brifing va SSML generatsiyasi
  - StreamVoiceQuery: Interaktiv ovozli savol-javob oqimi
"""

import sys
import os
import time
import logging
from concurrent import futures
from typing import Iterator

import grpc

# Add proto to sys.path if not present
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from proto import legal_ai_pb2 as pb2
from proto import legal_ai_pb2_grpc as pb2_grpc

from app.knowledge_graph import legal_graph
from app.vector_store import legal_vector_store
from app.ocr import ocr_processor

logger = logging.getLogger("ai-engine-grpc")

class LegalAIServiceImpl(pb2_grpc.LegalAIServiceServicer):
    """
    proto/legal_ai.proto shartnomasi bo'yicha to'liq gRPC servis implementatsiyasi
    """

    def ProcessDocumentOCR(self, request: pb2.OCRRequest, context: grpc.ServicerContext) -> pb2.OCRResponse:
        logger.info(f"[gRPC] ProcessDocumentOCR chaqirildi: doc_id={request.document_id}, mime={request.mime_type}")
        try:
            res = ocr_processor.process_document(request.file_bytes, request.mime_type)
            extracted_clauses = []
            for c in res.get("clauses", []):
                extracted_clauses.append(pb2.ExtractedClause(
                    clause_id=c.get("clause_id", ""),
                    clause_number=c.get("clause_number", ""),
                    text=c.get("text", ""),
                    page_number=c.get("page_number", 1)
                ))

            return pb2.OCRResponse(
                full_text=res.get("full_text", ""),
                clauses=extracted_clauses,
                confidence_score=float(res.get("confidence_score", 0.95))
            )
        except Exception as e:
            logger.error(f"[gRPC] OCR xatoligi: {e}", exc_info=True)
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(f"OCR qayta ishlashda xatolik: {str(e)}")
            return pb2.OCRResponse()

    def AnalyzeClauses(self, request: pb2.ClauseAnalysisRequest, context: grpc.ServicerContext) -> Iterator[pb2.ClauseAnalysisEvent]:
        analysis_id = request.analysis_id
        clauses = list(request.clauses)
        total_clauses = len(clauses)

        logger.info(f"[gRPC] AnalyzeClauses boshlandi: analysis_id={analysis_id}, {total_clauses} bandlar")

        # 1. Boshlanish bosqichi
        yield pb2.ClauseAnalysisEvent(
            event_type="stage_changed",
            progress_pct=5,
            stage_name="knowledge_graph_indexing"
        )

        processed = 0
        for idx, c in enumerate(clauses):
            c_text = c.text
            # Knowledge Graph tekshiruvi
            eval_res = legal_graph.evaluate_clause_text(c_text)

            # Agar to'g'ridan-to'g'ri tushmasa, BM25 qidiruv
            if not eval_res or not eval_res.get("found"):
                hits = legal_vector_store.search(c_text, top_k=1)
                if hits and hits[0]["score"] > 18.0:
                    top_hit = hits[0]
                    chain_res = legal_graph.resolve_chain(top_hit["article_number"])
                    eval_res = {
                        "found": True,
                        "root_article": f"{top_hit['source_code']} {top_hit['article_number']}",
                        "root_title": top_hit["title"],
                        "url": top_hit["official_url"],
                        "risk_level": "YELLOW",
                        "category": "COMPLIANCE",
                        "issue_title": f"{top_hit['title']} talablariga nomuvofiqlik ehtimoli",
                        "combined_explanation": f"Ushbu band {top_hit['source_code']} {top_hit['article_number']} doirasidagi talablarga muvofiqlashtirilishi lozim. {top_hit['snippet']}",
                        "suggested_redline": f"Band matni O'zbekiston qonunchiligining {top_hit['article_number']} talablariga muvofiqlashtirilishi tavsiya etiladi."
                    }

            if eval_res and eval_res.get("found"):
                raw_finding = pb2.RawFinding(
                    clause_id=c.clause_id,
                    risk_level=eval_res.get("risk_level", "YELLOW"),
                    category=eval_res.get("category", "LEGAL"),
                    issue_title=eval_res.get("issue_title", "Qonuniy nomutanosiblik"),
                    issue_explanation=eval_res.get("combined_explanation", ""),
                    cited_article=eval_res.get("root_article", ""),
                    suggested_redline=eval_res.get("suggested_redline", ""),
                    balance_label="Ijrochiga og'ir" if eval_res.get("risk_level") == "RED" else "Muvozanatli"
                )

                progress = int(10 + (idx + 1) / max(total_clauses, 1) * 80)
                yield pb2.ClauseAnalysisEvent(
                    event_type="partial_finding",
                    progress_pct=progress,
                    stage_name="clause_evaluation",
                    finding=raw_finding
                )

            processed += 1

        # 3. Yakunlash bosqichi
        yield pb2.ClauseAnalysisEvent(
            event_type="stage_changed",
            progress_pct=100,
            stage_name="completed"
        )
        logger.info(f"[gRPC] AnalyzeClauses yakunlandi: analysis_id={analysis_id}")

    def SelfCorrectFinding(self, request: pb2.SelfCorrectionRequest, context: grpc.ServicerContext) -> pb2.SelfCorrectionResponse:
        """
        Active Self-Correction: Agar Go Verifier nomuvofiqlik topsa,
        AI Knowledge Graph va candidate moddalar orqali intellektual refleksiya qiladi.
        """
        clause_text = request.clause_text
        error_msg = request.verification_error
        candidates = list(request.candidate_articles)

        logger.info(f"[gRPC] SelfCorrectFinding: error='{error_msg}', candidates={candidates}")

        # 1. Nomzod moddalar ichidan tekshirish
        for cand in candidates:
            res = legal_graph.resolve_chain(cand)
            if res.get("found"):
                finding = pb2.RawFinding(
                    clause_id="",
                    risk_level="YELLOW",
                    category="LEGAL",
                    issue_title="Verifikatsiya tuzatishi (Self-Correction)",
                    issue_explanation=f"Go Verifier xatosi ({error_msg}) sababli yangi zanjirli norma aniqlandi: {res.get('combined_explanation')}",
                    cited_article=res.get("root_article", cand),
                    suggested_redline=res.get("suggested_redline", "Band matnini to'g'rilash tavsiya etiladi."),
                    balance_label="Muvozanatli"
                )
                return pb2.SelfCorrectionResponse(
                    resolved=True,
                    corrected_finding=finding
                )

        # 2. To'g'ridan-to'g'ri matn bo'yicha baholash
        eval_res = legal_graph.evaluate_clause_text(clause_text)
        if eval_res and eval_res.get("found"):
            finding = pb2.RawFinding(
                clause_id="",
                risk_level=eval_res.get("risk_level", "YELLOW"),
                category=eval_res.get("category", "LEGAL"),
                issue_title=eval_res.get("issue_title", "Tuzatilgan norma"),
                issue_explanation=eval_res.get("combined_explanation", ""),
                cited_article=eval_res.get("root_article", ""),
                suggested_redline=eval_res.get("suggested_redline", ""),
                balance_label="Muvozanatli"
            )
            return pb2.SelfCorrectionResponse(
                resolved=True,
                corrected_finding=finding
            )

        # 3. BM25 eng yaqin qonunni topish
        hits = legal_vector_store.search(clause_text, top_k=1)
        if hits:
            hit = hits[0]
            chain_res = legal_graph.resolve_chain(hit["article_number"])
            finding = pb2.RawFinding(
                clause_id="",
                risk_level="YELLOW",
                category="COMPLIANCE",
                issue_title=f"{hit['title']} (Refleksiya natijasi)",
                issue_explanation=f"Leksik tahlil va semantik zanjir asosida yangi norma aniqlandi: {hit['source_code']} {hit['article_number']}. {chain_res.get('combined_explanation', hit['snippet'])}",
                cited_article=f"{hit['source_code']} {hit['article_number']}",
                suggested_redline=chain_res.get("suggested_redline", f"O'zR {hit['article_number']} talablariga muvofiqlashtirish tavsiya etiladi."),
                balance_label="Muvozanatli"
            )
            return pb2.SelfCorrectionResponse(
                resolved=True,
                corrected_finding=finding
            )

        return pb2.SelfCorrectionResponse(resolved=False)

    def GenerateVoiceBrief(self, request: pb2.VoiceBriefRequest, context: grpc.ServicerContext) -> pb2.VoiceBriefResponse:
        """
        O'zbek tilida tabiiy ovozli yuridik brifing va SSML generatsiyasi
        """
        top_risks = list(request.top_risks)
        risk_count = len(top_risks)

        red_count = sum(1 for r in top_risks if r.risk_level == "RED")
        yellow_count = sum(1 for r in top_risks if r.risk_level == "YELLOW")

        script_parts = [
            "Assalomu alaykum! LexGuard AI tahlil xulosasi tayyor.",
            f"Ushbu shartnomada jami {risk_count} ta e'tibor qaratilishi zarur bo'lgan huquqiy va tijoriy bandlar aniqlandi."
        ]

        if red_count > 0:
            script_parts.append(f"Xususan, {red_count} ta band qizil darajadagi jiddiy xavf sifatida baholandi.")
            top_red = next((r for r in top_risks if r.risk_level == "RED"), None)
            if top_red:
                script_parts.append(f"Eng asosiy xavf: {top_red.issue_title}. {top_red.issue_explanation[:200]}.")
        else:
            script_parts.append("Shartnomada qizil darajadagi tanqidiy xavflar aniqlanmadi.")

        if yellow_count > 0:
            script_parts.append(f"Shuningdek, {yellow_count} ta tijoriy muvozanatni tiklashga doir tavsiya mavjud.")

        script_parts.append("Tavsiya etilgan redline tahrirlarni ekranda ko'rib chiqishingiz va bir tugma bilan qabul qilishingiz mumkin.")

        audio_script_uz = " ".join(script_parts)

        # SSML formatlash
        ssml = (
            "<speak>\n"
            "  <prosody rate=\"medium\" pitch=\"default\">\n"
            f"    <s>Assalomu alaykum! <break time=\"300ms\"/> LexGuard AI tahlil xulosasi tayyor.</s>\n"
            f"    <s>Shartnomada jami <emphasis level=\"moderate\">{risk_count} ta</emphasis> huquqiy xavf aniqlandi.</s>\n"
            f"    <s>{audio_script_uz.replace('&', '&amp;')}</s>\n"
            "  </prosody>\n"
            "</speak>"
        )

        duration_sec = max(10, len(audio_script_uz.split()) * 60 // 130)

        return pb2.VoiceBriefResponse(
            audio_script_uz=audio_script_uz,
            ssml=ssml,
            duration_sec=duration_sec
        )

    def StreamVoiceQuery(self, request_iterator: Iterator[pb2.VoiceQueryChunk], context: grpc.ServicerContext) -> Iterator[pb2.VoiceAnswerChunk]:
        """
        Interaktiv jonli ovozli savol-javob oqimi
        """
        for chunk in request_iterator:
            query = chunk.user_query_text
            if not query:
                continue

            # Answer synthesis
            hits = legal_vector_store.search(query, top_k=1)
            if hits:
                top_hit = hits[0]
                ans_text = f"O'zbekiston Respublikasi {top_hit['source_code']} {top_hit['article_number']} («{top_hit['title']}») bo'yicha: {top_hit['snippet'][:300]}."
            else:
                ans_text = "Ushbu savol bo'yicha qonunlar bazasidan ma'lumot topilmadi. Yurist maslahati tavsiya etiladi."

            # Stream words as chunks
            words = ans_text.split()
            for i in range(0, len(words), 4):
                sub_text = " ".join(words[i:i+4]) + " "
                yield pb2.VoiceAnswerChunk(
                    text_chunk=sub_text,
                    audio_chunk=b""
                )
                time.sleep(0.05)

def serve_grpc(port: int = 50051) -> grpc.Server:
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    pb2_grpc.add_LegalAIServiceServicer_to_server(LegalAIServiceImpl(), server)
    server.add_insecure_port(f"0.0.0.0:{port}")
    server.start()
    logger.info(f"🚀 LegalAIService gRPC Server muvaffaqiyatli ishga tushdi: 0.0.0.0:{port}")
    return server

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    s = serve_grpc(50051)
    try:
        s.wait_for_termination()
    except KeyboardInterrupt:
        s.stop(0)
