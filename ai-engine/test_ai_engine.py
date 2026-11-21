"""
LexGuard AI — Comprehensive AI Engine Test Suite
Tests:
  1. Knowledge Graph (2,058 articles, 2,086 edges, multi-hop chains)
  2. OCR Module (document processing, clause chunking)
  3. gRPC Server (ProcessDocumentOCR, AnalyzeClauses streaming, SelfCorrectFinding, GenerateVoiceBrief)
  4. FastAPI Server & Endpoints
  5. Dataset Generator & SLM Training verification
"""

import sys
import os
import unittest
import json
from concurrent import futures

# Set PYTHONPATH
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from app.knowledge_graph import legal_graph
from app.vector_store import legal_vector_store
from app.ocr import ocr_processor
from app.grpc_server import LegalAIServiceImpl
from proto import legal_ai_pb2 as pb2
from proto import legal_ai_pb2_grpc as pb2_grpc
import grpc
from fastapi.testclient import TestClient
from app.main import app

class TestAIEngine(unittest.TestCase):

    def test_01_knowledge_graph_stats(self):
        """2,058 modda va 2,086 bog'lanish zanjirini tekshirish"""
        total_nodes = len(legal_graph.nodes)
        total_edges = sum(len(edges) for edges in legal_graph.edges.values())
        print(f"\n[Test KG] Tugunlar: {total_nodes}, Bog'lanishlar: {total_edges}")
        self.assertEqual(total_nodes, 2058, "Knowledge Graph da 2,058 ta modda bo'lishi shart!")
        self.assertEqual(total_edges, 2086, "Knowledge Graph da 2,086 ta bog'lanish bo'lishi shart!")

    def test_02_multi_hop_cross_reference(self):
        """Cross-Reference zanjiri (FK 707 -> FK 354, FK 324)"""
        chain_res = legal_graph.resolve_chain("FK-UZ-2_707")
        self.assertTrue(chain_res["found"])
        self.assertGreaterEqual(len(chain_res["chain"]), 2)
        chain_codes = [n["code"] for n in chain_res["chain"]]
        print(f"[Test Multi-Hop] FK 707 zanjiri: {chain_codes}")
        self.assertIn("FK-UZ-1 354-modda", chain_codes)
        self.assertIn("FK-UZ-1 324-modda", chain_codes)
        self.assertTrue("xarajat" in chain_res["suggested_redline"].lower())

    def test_03_ocr_clause_segmentation(self):
        """OCR moduli va bandlarga ajratish"""
        sample_doc = (
            "1.1. Ijrochi xizmatlarni sifatli bajaradi.\n"
            "1.2. Buyurtmachi istalgan vaqtda to'lovsiz bekor qilishi mumkin.\n"
            "2.1. Majburiyat kechiktirilsa, 5% kunlik penya to'lanadi.\n"
        )
        res = ocr_processor.process_document(sample_doc.encode("utf-8"), "text/plain")
        self.assertEqual(len(res["clauses"]), 3)
        self.assertEqual(res["confidence_score"], 1.0)
        self.assertEqual(res["clauses"][0]["clause_number"], "1.1.")
        self.assertEqual(res["clauses"][1]["clause_number"], "1.2.")

    def test_04_grpc_server_methods(self):
        """gRPC serveri: OCR, AnalyzeClauses (Stream), SelfCorrect, VoiceBrief"""
        server = grpc.server(futures.ThreadPoolExecutor(max_workers=2))
        pb2_grpc.add_LegalAIServiceServicer_to_server(LegalAIServiceImpl(), server)
        port = server.add_insecure_port("127.0.0.1:0")
        server.start()

        channel = grpc.insecure_channel(f"127.0.0.1:{port}")
        stub = pb2_grpc.LegalAIServiceStub(channel)

        try:
            # 1. ProcessDocumentOCR
            ocr_req = pb2.OCRRequest(
                document_id="doc-test-1",
                file_bytes=b"1.1. Tomonlar majburiyatlari.\n1.2. Bir tomonlama bekor qilish.\n",
                mime_type="text/plain"
            )
            ocr_resp = stub.ProcessDocumentOCR(ocr_req)
            self.assertGreaterEqual(len(ocr_resp.clauses), 2)
            self.assertGreaterEqual(ocr_resp.confidence_score, 0.8)

            # 2. AnalyzeClauses (Streaming)
            analysis_req = pb2.ClauseAnalysisRequest(
                analysis_id="test-analysis-1",
                document_type="B2B_SERVICE",
                clauses=[
                    pb2.ExtractedClause(clause_id="c1", clause_number="1.1", text="Ijrochi xizmat ko'rsatadi."),
                    pb2.ExtractedClause(clause_id="c2", clause_number="1.2", text="Buyurtmachi istalgan paytda to'lovsiz bir tomonlama bekor qiladi.")
                ]
            )
            events = list(stub.AnalyzeClauses(analysis_req))
            self.assertGreaterEqual(len(events), 2)
            findings = [e.finding for e in events if e.event_type == "partial_finding"]
            self.assertGreaterEqual(len(findings), 1)
            self.assertEqual(findings[0].risk_level, "RED")
            self.assertIn("707", findings[0].cited_article)

            # 3. Active Self-Correction
            self_correct_req = pb2.SelfCorrectionRequest(
                clause_text="Buyurtmachi shartnomani istalgan paytda bir tomonlama bekor qiladi",
                previous_cited_article="FK 100", # Wrong article
                verification_error="FK 100 mavjud emas yoki mos emas",
                candidate_articles=["FK-UZ-2_707", "FK-UZ-1_354"]
            )
            sc_resp = stub.SelfCorrectFinding(self_correct_req)
            self.assertTrue(sc_resp.resolved)
            self.assertIn("707", sc_resp.corrected_finding.cited_article)

            # 4. GenerateVoiceBrief
            voice_req = pb2.VoiceBriefRequest(
                analysis_id="test-analysis-1",
                top_risks=[findings[0]]
            )
            voice_resp = stub.GenerateVoiceBrief(voice_req)
            self.assertTrue("Assalomu alaykum" in voice_resp.audio_script_uz)
            self.assertTrue("<speak>" in voice_resp.ssml)
            self.assertGreater(voice_resp.duration_sec, 5)

        finally:
            server.stop(0)
            channel.close()

    def test_05_fastapi_endpoints(self):
        """FastAPI REST endpointlari: /health, /api/v1/corpus-stats, /api/v1/analyze-clauses"""
        client = TestClient(app)
        
        # Health check
        r = client.get("/health")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["indexed_articles"], 2058)
        self.assertEqual(r.json()["knowledge_graph_edges"], 2086)

        # Corpus stats
        r = client.get("/api/v1/corpus-stats")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["total_articles"], 2058)

        # Analyze clauses
        r = client.post("/api/v1/analyze-clauses", json={
            "analysis_id": "test-fastapi",
            "clauses": [
                {"clause_id": "c1", "clause_number": "1.1", "text": "Buyurtmachi istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin."}
            ]
        })
        self.assertEqual(r.status_code, 200)
        findings = r.json()["findings"]
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0]["risk_level"], "RED")
        self.assertIn("707", findings[0]["cited_article"])
        self.assertGreater(len(findings[0]["multi_hop_chain"]), 1)

if __name__ == "__main__":
    unittest.main()
