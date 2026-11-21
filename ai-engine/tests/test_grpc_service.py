"""
LexGuard AI — gRPC servis testlari (jonli in-process server): streaming eventlar, party_role, Self-Correction, ovoz.
"""

import os
import sys
import unittest
from concurrent import futures

import grpc

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app import grpc_server
from app.grpc_server import LegalAIServiceImpl
from proto import legal_ai_pb2 as pb2
from proto import legal_ai_pb2_grpc as pb2_grpc


class TestGrpcService(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = grpc.server(futures.ThreadPoolExecutor(max_workers=2))
        pb2_grpc.add_LegalAIServiceServicer_to_server(LegalAIServiceImpl(), cls.server)
        port = cls.server.add_insecure_port("127.0.0.1:0")
        cls.server.start()
        cls.channel = grpc.insecure_channel(f"127.0.0.1:{port}")
        cls.stub = pb2_grpc.LegalAIServiceStub(cls.channel)

    @classmethod
    def tearDownClass(cls):
        cls.channel.close()
        cls.server.stop(0)

    def _analyze(self, clauses, doc_type="SERVICE_AGREEMENT", role=""):
        req = pb2.ClauseAnalysisRequest(
            analysis_id="g1", document_type=doc_type, party_role=role,
            clauses=[pb2.ExtractedClause(clause_id=f"c{i}", clause_number=f"{i}.1", text=t) for i, t in enumerate(clauses, 1)],
        )
        return list(self.stub.AnalyzeClauses(req))

    def test_stream_has_progress_for_every_clause_and_ends_completed(self):
        events = self._analyze(["Ijrochi xizmat ko'rsatadi.", "Hisobot oyiga bir marta topshiriladi."])
        types = [e.event_type for e in events]
        self.assertEqual(types[0], "stage_changed")
        self.assertEqual(types.count("progress"), 2)  # xavfsiz bandlar uchun ham progress
        self.assertEqual(events[-1].stage_name, "completed")
        self.assertEqual(events[-1].progress_pct, 100)
        pcts = [e.progress_pct for e in events]
        self.assertEqual(pcts, sorted(pcts))

    def test_findings_streamed_with_clause_id_and_balance(self):
        events = self._analyze(
            ["Ijrochi xizmat ko'rsatadi.", "Buyurtmachi istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin."],
            role="EXECUTOR",
        )
        findings = [e.finding for e in events if e.event_type == "partial_finding"]
        self.assertEqual(len(findings), 1)
        f = findings[0]
        self.assertEqual(f.clause_id, "c2")
        self.assertEqual(f.risk_level, "RED")
        self.assertIn("707", f.cited_article)
        self.assertIn("sizning tomoningizga", f.balance_label)

    def test_multiple_findings_for_one_clause_are_all_streamed(self):
        events = self._analyze(["Har bir kun uchun 1% penya to'lanadi. Ijrochi barcha zararlarni to'liq qoplaydi."])
        findings = [e.finding for e in events if e.event_type == "partial_finding"]
        self.assertEqual({f.risk_level for f in findings}, {"YELLOW"})
        self.assertEqual(len(findings), 2)

    def test_doc_type_changes_result(self):
        text = "Buyurtmachi istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin."
        service = [e.finding for e in self._analyze([text], "SERVICE_AGREEMENT") if e.event_type == "partial_finding"]
        sale = [e.finding for e in self._analyze([text], "SUPPLY_SALE") if e.event_type == "partial_finding"]
        self.assertIn("707", service[0].cited_article)
        self.assertIn("237", sale[0].cited_article)

    def test_self_correct_excludes_rejected_and_resolves(self):
        resp = self.stub.SelfCorrectFinding(pb2.SelfCorrectionRequest(
            clause_text="Buyurtmachi shartnomani istalgan paytda bir tomonlama bekor qiladi",
            previous_cited_article="FK 707", verification_error="mos emas",
            candidate_articles=["FK-UZ-2_707"],
        ))
        self.assertTrue(resp.resolved)
        self.assertNotIn("707", resp.corrected_finding.cited_article)

    def test_self_correct_unresolved(self):
        resp = self.stub.SelfCorrectFinding(pb2.SelfCorrectionRequest(clause_text="qwxz plmk"))
        self.assertFalse(resp.resolved)

    def test_voice_brief_uses_findings(self):
        resp = self.stub.GenerateVoiceBrief(pb2.VoiceBriefRequest(
            analysis_id="g1",
            top_risks=[pb2.RawFinding(risk_level="RED", issue_title="Bekor qilish & xavf", issue_explanation="Izoh.")],
        ))
        self.assertIn("Bekor qilish & xavf", resp.audio_script_uz)
        self.assertIn("&amp;", resp.ssml)

    def test_voice_query_stream_marks_final_chunk(self):
        chunks = list(self.stub.StreamVoiceQuery(iter([pb2.VoiceQueryChunk(session_id="s", user_query_text="707-modda nima deydi?")])))
        self.assertGreater(len(chunks), 1)
        self.assertEqual([c.is_final for c in chunks][-1], True)
        self.assertEqual(sum(c.is_final for c in chunks), 1)
        self.assertIn("707", "".join(c.text_chunk for c in chunks))

    def test_ocr_roundtrip(self):
        resp = self.stub.ProcessDocumentOCR(pb2.OCRRequest(
            document_id="d", mime_type="text/plain",
            file_bytes=b"1.1. Birinchi band matni shu yerda.\n1.2. Ikkinchi band matni shu yerda.\n",
        ))
        self.assertEqual([c.clause_number for c in resp.clauses], ["1.1.", "1.2."])

    def test_local_only_flag_skips_remote_llm(self):
        class Remote:
            is_local = False
        original = grpc_server.analyzer.refiner
        try:
            grpc_server.analyzer.refiner = Remote()
            self.assertFalse(grpc_server._llm_allowed(True))
            self.assertTrue(grpc_server._llm_allowed(False))
        finally:
            grpc_server.analyzer.refiner = original


if __name__ == "__main__":
    unittest.main()
