"""
LexGuard AI — Comprehensive AI Engine Test Suite
Tests:
  1. Knowledge Graph (2,058 articles, 2,086 edges, multi-hop chains)
  2. OCR Module (document processing, clause chunking, image magic-byte sniffing)
  3. Uzbek Script Normalizer (Cyrillic, Reformed Latin, Old Latin)
  4. Anti-Hallucination & Fail-Closed Guard (Foreign Law -> UNKNOWN, R6 no false positive, allowlist verify_citation)
  5. Zero-Dependency HTTP Server live integration tests (/health, /verify-citation, /analyze-clauses, /self-correct)
  6. gRPC Server (when grpcio is installed)
  7. FastAPI Server & Endpoints (when fastapi is installed)
"""

import json
import os
import sys
import threading
import unittest
import urllib.error
import urllib.parse
import urllib.request
from concurrent import futures
from http.server import HTTPServer

# Set PYTHONPATH
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from app.contract_dataset_builder import build_600_contracts, evaluate_engine_on_contracts
from app.knowledge_graph import legal_graph
from app.local_model_runtime import local_neural_runtime
from app.normalizer import is_foreign_law_clause, normalize_uzbek
from app.notarial_classifier import classify_document_form
from app.ocr import ocr_processor
from app.server import LexGuardHTTPRequestHandler
from app.slm_runtime import verify_and_sanitize_slm_output
from app.train_slm import (
    build_assistant_only_labels,
    check_contract_leakage,
    load_jsonl,
    validate_sft_dataset,
)
from app.vector_store import legal_vector_store

try:
    import grpc
    from app.grpc_server import LegalAIServiceImpl
    from proto import legal_ai_pb2 as pb2
    from proto import legal_ai_pb2_grpc as pb2_grpc
    HAS_GRPC = True
except ImportError:
    HAS_GRPC = False

try:
    from fastapi.testclient import TestClient
    from app.main import app as fastapi_app
    HAS_FASTAPI = True
except ImportError:
    HAS_FASTAPI = False


def _http_json(url: str, method: str = "GET", payload=None):
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    headers = {"Content-Type": "application/json"} if payload is not None else {}
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=5) as resp:
        return resp.status, json.loads(resp.read().decode("utf-8"))


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

    def test_03_ocr_clause_segmentation_and_magic_bytes(self):
        """OCR moduli: bandlarga ajratish va octet-stream rasm magic-byte aniqlash"""
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

        # Go multipart uploads set application/octet-stream — must still sniff JPEG magic bytes
        fake_jpeg = b"\xff\xd8\xff\xe0\x00\x10JFIF"
        img_res = ocr_processor.process_document(fake_jpeg, "application/octet-stream")
        self.assertNotIn("JFIF", img_res["full_text"], "JPEG baytlari latin-1 matn sifatida o'qilmasligi kerak!")

    def test_04_uzbek_normalizer_and_multilingual_matching(self):
        """Kirill, Isloh qilingan lotin va Eski lotin yozuvlarida bir xil natija"""
        variants = [
            "Буюртмачи шартномани исталган вақтда тўловсиз бир томонлама бекор қилиши мумкин.",
            "Buyurtmaçi şartnomani istalgan vaqtda tölo'vsiz bir tomonlama bekor qilişi mumkin.",
            "Buyurtmachi shartnomani istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin.",
        ]
        for text in variants:
            res = legal_graph.evaluate_clause_text(text)
            self.assertIsNotNone(res, f"Variant topilmadi: {text}")
            self.assertTrue(res["found"])
            self.assertEqual(res["risk_level"], "RED")
            self.assertIn("707", res["root_article"])
            self.assertTrue(legal_graph.verify_citation(res["root_article"]))

        # BM25 vector search should also find results for Cyrillic queries
        cyr_hits = legal_vector_store.search("шартнома мажбурият неустойка пеня", top_k=3)
        self.assertGreater(len(cyr_hits), 0)

    def test_05_anti_hallucination_and_fail_closed(self):
        """Anti-hallucination: Xorijiy qonun -> UNKNOWN, R6 false-positive yo'q, Allowlist verifier"""
        # 1. Foreign Law -> strictly UNKNOWN («0» xulosa) with empty citation
        foreign_clause = "This Agreement shall be governed by English law and any disputes resolved via LCIA arbitration in London."
        self.assertTrue(is_foreign_law_clause(foreign_clause))
        f_res = legal_graph.evaluate_clause_text(foreign_clause)
        self.assertIsNotNone(f_res)
        self.assertTrue(f_res["found"])
        self.assertEqual(f_res["risk_level"], "UNKNOWN")
        self.assertEqual(f_res["root_article"], "")
        self.assertEqual(f_res["url"], "")

        # 2. Normal B2B office lease must NOT trigger R6 Notarial RED false positive
        office_lease = "Noturar joy ofis xonasini 6 oy muddatga ijaraga berish va oylik to'lov tartibi."
        lease_res = legal_graph.evaluate_clause_text(office_lease)
        if lease_res and lease_res.get("found"):
            self.assertNotIn("110", lease_res.get("root_article", ""), "Oddiy ofis ijarasiga FK 110 notarial RED chiqmasligi shart!")

        # 3. Real estate sale without notarization MUST trigger R6 RED (FK-UZ-1 110)
        real_estate_sale = "Kvartira ko'chmas mulk oldi-sotdi bitimi notarial tasdiqlashsiz kuchga kiradi."
        sale_res = legal_graph.evaluate_clause_text(real_estate_sale)
        self.assertIsNotNone(sale_res)
        self.assertEqual(sale_res["risk_level"], "RED")
        self.assertIn("110", sale_res["root_article"])

        # 4. Currency clause -> FK-UZ-1 245 RED
        usd_clause = "Xizmat haqi AQSh dollarida (USD) naqd shaklda amalga oshiriladi."
        usd_res = legal_graph.evaluate_clause_text(usd_clause)
        self.assertIsNotNone(usd_res)
        self.assertEqual(usd_res["risk_level"], "RED")
        self.assertIn("245", usd_res["root_article"])

        # 5. Mediation clause -> ORQ-482 16 YELLOW
        med_clause = "Nizolar sudgacha talabnoma va mediatsiya tartibisiz bevosita ko'rib chiqiladi."
        med_res = legal_graph.evaluate_clause_text(med_clause)
        self.assertIsNotNone(med_res)
        self.assertEqual(med_res["risk_level"], "YELLOW")
        self.assertIn("ORQ-482", med_res["root_article"])

        # 6. Allowlist verify_citation
        self.assertTrue(legal_graph.verify_citation("FK-UZ-2 707-modda"))
        self.assertTrue(legal_graph.verify_citation("FK-UZ-1_326"))
        self.assertFalse(legal_graph.verify_citation("FK-UZ 9999-modda"))
        self.assertFalse(legal_graph.verify_citation(""))

    def test_06_zero_dependency_http_server(self):
        """Zero-dependency HTTP server: /health, /verify-citation, /analyze-clauses, /self-correct"""
        httpd = HTTPServer(("127.0.0.1", 0), LexGuardHTTPRequestHandler)
        port = httpd.server_address[1]
        thread = threading.Thread(target=httpd.serve_forever, daemon=True)
        thread.start()
        base = f"http://127.0.0.1:{port}"
        try:
            # /health
            status, body = _http_json(f"{base}/health")
            self.assertEqual(status, 200)
            self.assertEqual(body["indexed_articles"], 2058)
            self.assertEqual(body["knowledge_graph_edges"], 2086)

            # /api/v1/verify-citation (valid vs fabricated)
            q_ok = urllib.parse.quote("FK-UZ-2 707-modda")
            status, body = _http_json(f"{base}/api/v1/verify-citation?article={q_ok}")
            self.assertEqual(status, 200)
            self.assertTrue(body["verified"])

            q_bad = urllib.parse.quote("FK-UZ 9999-modda")
            status, body = _http_json(f"{base}/api/v1/verify-citation?article={q_bad}")
            self.assertEqual(status, 200)
            self.assertFalse(body["verified"])
            self.assertEqual(body["status"], "UNKNOWN")

            # /api/v1/analyze-clauses (Cyrillic RED + Foreign Law UNKNOWN)
            status, body = _http_json(
                f"{base}/api/v1/analyze-clauses",
                method="POST",
                payload={
                    "analysis_id": "http-test-1",
                    "clauses": [
                        {
                            "clause_id": "c1",
                            "clause_number": "1.1",
                            "text": "Буюртмачи исталган вақтда тўловсиз бир томонлама бекор қилади.",
                        },
                        {
                            "clause_id": "c2",
                            "clause_number": "9.1",
                            "text": "Disputes shall be settled under English law at LCIA London.",
                        },
                    ],
                },
            )
            self.assertEqual(status, 200)
            self.assertEqual(len(body["findings"]), 2)
            self.assertEqual(body["findings"][0]["risk_level"], "RED")
            self.assertIn("707", body["findings"][0]["cited_article"])
            self.assertEqual(body["findings"][1]["risk_level"], "UNKNOWN")
            self.assertEqual(body["findings"][1]["cited_article"], "")

            # /api/v1/self-correct fail-closed on foreign/unrelated text
            status, body = _http_json(
                f"{base}/api/v1/self-correct",
                method="POST",
                payload={
                    "clause_text": "Governed by Delaware corporate law and ICC Paris arbitration.",
                    "previous_cited_article": "FK 9999",
                    "verification_error": "Not found",
                    "candidate_articles": [],
                },
            )
            self.assertEqual(status, 200)
            self.assertFalse(body["resolved"], "Xorijiy qonun bo'yicha self-correct taxmin qilmasligi kerak!")

            # /api/v1/self-correct fail-closed on random gibberish
            status, body = _http_json(
                f"{base}/api/v1/self-correct",
                method="POST",
                payload={
                    "clause_text": "qwertyuiop asdfghjkl zxcvbnm 12345",
                    "previous_cited_article": "FK 9999",
                    "verification_error": "Not found",
                    "candidate_articles": [],
                },
            )
            self.assertEqual(status, 200)
            self.assertFalse(body["resolved"], "Ma'nosiz matn bo'yicha self-correct hallucination qilmasligi kerak!")
        finally:
            httpd.shutdown()
            httpd.server_close()

    @unittest.skipUnless(HAS_GRPC, "grpcio kutubxonasi ushbu muhitda o'rnatilmagan")
    def test_07_grpc_server_methods(self):
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

            # 3. Active Self-Correction (valid + fail-closed foreign law)
            self_correct_req = pb2.SelfCorrectionRequest(
                clause_text="Buyurtmachi shartnomani istalgan paytda bir tomonlama bekor qiladi",
                previous_cited_article="FK 100",
                verification_error="FK 100 mavjud emas yoki mos emas",
                candidate_articles=["FK-UZ-2_707", "FK-UZ-1_354"]
            )
            sc_resp = stub.SelfCorrectFinding(self_correct_req)
            self.assertTrue(sc_resp.resolved)
            self.assertIn("707", sc_resp.corrected_finding.cited_article)

            sc_foreign = stub.SelfCorrectFinding(pb2.SelfCorrectionRequest(
                clause_text="Governed by English law and LCIA arbitration",
                previous_cited_article="FK 9999",
                verification_error="Not found",
                candidate_articles=[]
            ))
            self.assertFalse(sc_foreign.resolved)

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

    @unittest.skipUnless(HAS_FASTAPI, "fastapi kutubxonasi ushbu muhitda o'rnatilmagan")
    def test_08_fastapi_endpoints(self):
        """FastAPI REST endpointlari: /health, /corpus-stats, /verify-citation, /analyze-clauses, /self-correct"""
        client = TestClient(fastapi_app)

        r = client.get("/health")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["indexed_articles"], 2058)
        self.assertEqual(r.json()["knowledge_graph_edges"], 2086)

        r = client.get("/api/v1/corpus-stats")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["total_articles"], 2058)

        r = client.get("/api/v1/verify-citation", params={"article": "FK-UZ-2 707-modda"})
        self.assertEqual(r.status_code, 200)
        self.assertTrue(r.json()["verified"])

        r = client.get("/api/v1/verify-citation", params={"article": "FK-UZ 9999-modda"})
        self.assertEqual(r.status_code, 200)
        self.assertFalse(r.json()["verified"])

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

        r = client.post("/api/v1/self-correct", json={
            "clause_text": "Governed by English law and LCIA arbitration",
            "previous_cited_article": "FK 9999",
            "verification_error": "Not found",
            "candidate_articles": []
        })
        self.assertEqual(r.status_code, 200)
        self.assertFalse(r.json()["resolved"])

    def test_09_notarial_classifier_and_600_contract_benchmark(self):
        """3-qavatli Notarial vs Oddiy arxitektura va 600 ta shartnoma benchmarki"""
        # 1. Majburiy notarial (tasdiqsiz) -> RED
        res_bad = classify_document_form("Kvartira oldi-sotdi shartnomasi notariussiz imzolandi.")
        self.assertEqual(res_bad["form_status"], "MISSING_MANDATORY_NOTARIZATION")
        self.assertEqual(res_bad["risk_level"], "RED")

        # 2. Majburiy notarial (tasdiqli E-Notarius) -> GREEN
        res_ok = classify_document_form(
            "Kvartira oldi-sotdi shartnomasi. Xususiy amaliyot bilan shug'ullanuvchi notarius tomonidan tasdiqlandi, "
            "reyestr raqami 2026/4812, QR-kod mavjud."
        )
        self.assertEqual(res_ok["form_status"], "VERIFIED_NOTARIAL_DOCUMENT")
        self.assertEqual(res_ok["risk_level"], "GREEN")

        # 3. Ofis ijarasi (E-ijarasiz) -> YELLOW eslatma (NOTARIUS SHART EMAS!)
        res_lease = classify_document_form("Noturar joy ofis xonasini 6 oy muddatga ijaraga berish shartnomasi.")
        self.assertEqual(res_lease["form_status"], "MISSING_E_IJARA_REMINDER")
        self.assertEqual(res_lease["risk_level"], "YELLOW")

        # 4. Oddiy B2B xizmat -> GREEN
        res_b2b = classify_document_form("IT xizmat ko'rsatish shartnomasi. To'lov milliy valyuta so'mda amalga oshiriladi.")
        self.assertEqual(res_b2b["form_status"], "VALID_SIMPLE_WRITTEN")
        self.assertEqual(res_b2b["risk_level"], "GREEN")

        # 5. To'liq 600 ta shartnoma + 124 ta xato senariysi benchmarki
        contracts, catalog = build_600_contracts(seed=42)
        self.assertGreaterEqual(len(contracts), 600)
        self.assertGreaterEqual(len(catalog), 100)
        metrics = evaluate_engine_on_contracts(contracts)
        self.assertEqual(metrics["form_classification_accuracy_pct"], 100.0, f"Notarial aniqligi 100% emas: {metrics}")
        self.assertEqual(metrics["defect_detection_recall_pct"], 100.0, f"Xato topish 100% emas: {metrics}")
        self.assertEqual(metrics["false_positive_rate_pct"], 0.0, f"Yashil shartnomada FP bor: {metrics}")
        self.assertEqual(metrics["foreign_fail_closed_accuracy_pct"], 100.0, f"Xorijiy qonun fail-closed 100% emas: {metrics}")
        self.assertEqual(metrics["citation_allowlist_verified_pct"], 100.0, f"Allowlist verifikatsiya 100% emas: {metrics}")

    def test_10_slm_fine_tuning_quality_gate_and_runtime_guard(self):
        """Optimal RAFT fine-tuning Quality Gate, Assistant-Only Loss Masking va Runtime Verifier"""
        # 1. Assistant-Only Loss Masking tekshiruvi
        ids = [10, 20, 30, 40, 50, 0, 0]
        labels = build_assistant_only_labels(ids, prompt_token_len=3, pad_token_id=0)
        self.assertEqual(labels, [-100, -100, -100, 40, 50, -100, -100])

        # 2. Runtime Closed-World Verifier: soxta moddali RED -> UNKNOWN ga tushishi shart!
        hallucinated = json.dumps({
            "task": "clause_audit",
            "risk_level": "RED",
            "category": "LEGAL",
            "cited_article": "FK-UZ 9999-modda",
            "lex_uz_url": "https://fake.example/9999",
            "issue_title": "Bu bitim haqiqiy emas",
            "explanation": "100% xavfsiz emas",
            "suggested_redline": "Qayta yozing",
        })
        sanitized = verify_and_sanitize_slm_output(hallucinated)
        self.assertIsNotNone(sanitized)
        self.assertEqual(sanitized["risk_level"], "UNKNOWN")
        self.assertEqual(sanitized["cited_article"], "")
        self.assertEqual(sanitized["lex_uz_url"], "")
        self.assertNotIn("100%", sanitized["explanation"])
        self.assertNotIn("xavfsiz", sanitized["explanation"].lower())
        self.assertNotIn("bu bitim haqiqiy emas", sanitized["issue_title"].lower())

        # 3. Runtime Verifier: haqiqiy modda -> rasmiy Lex.uz URL bilan tasdiqlanadi
        valid_slm = json.dumps({
            "task": "clause_audit",
            "risk_level": "RED",
            "category": "LEGAL",
            "cited_article": "FK-UZ-2 707-modda",
            "lex_uz_url": "https://wrong-url.invalid",
            "issue_title": "Asossiz bir tomonlama bekor qilish",
            "explanation": "FK 707 talabiga zid.",
            "suggested_redline": "15 kun oldin xabardor qilinadi va xarajatlar qoplanadi.",
        })
        verified = verify_and_sanitize_slm_output(valid_slm)
        self.assertIsNotNone(verified)
        self.assertEqual(verified["risk_level"], "RED")
        self.assertTrue(verified["verified_by_lexuz"])
        self.assertIn("lex.uz", verified["lex_uz_url"])

        # 4. Real contract_audit_train / eval Quality Gate & Zero Leakage
        from pathlib import Path
        data_dir = Path(__file__).resolve().parent / "data"
        train_rows = load_jsonl(data_dir / "contract_audit_train.jsonl")
        eval_rows = load_jsonl(data_dir / "contract_audit_eval.jsonl")
        self.assertGreater(len(train_rows), 1000)
        self.assertGreater(len(eval_rows), 400)
        t_gate = validate_sft_dataset(train_rows, label="TRAIN", strict_json=True)
        e_gate = validate_sft_dataset(eval_rows, label="EVAL", strict_json=True)
        self.assertTrue(t_gate["valid"], f"TRAIN Quality Gate xato: {t_gate['sample_errors']}")
        self.assertTrue(e_gate["valid"], f"EVAL Quality Gate xato: {e_gate['sample_errors']}")
        self.assertEqual(check_contract_leakage(train_rows, eval_rows), [])

    def test_11_local_neural_model_live_inference(self):
        """Local o'qitilgan PyTorch neyron modeli (model.pt) jonli inference va parafraza sinovi"""
        self.assertTrue(local_neural_runtime.is_ready, "model.pt topilmadi! Avval train_local_model.py ni ishga tushiring.")
        metrics = local_neural_runtime.eval_metrics
        self.assertGreaterEqual(metrics.get("eval_risk_accuracy_pct", 0), 95.0)
        self.assertGreaterEqual(metrics.get("eval_article_accuracy_pct", 0), 95.0)
        self.assertGreaterEqual(metrics.get("eval_form_accuracy_pct", 0), 95.0)

        # 1. Parafraza RED (tuzoq band) -> tasdiqlangan FK 707
        p_red = local_neural_runtime.predict_clause(
            "Buyurtmachi hech qanday ogohlantirishsiz va xarajatlarni qoplamay bir tomonlama shartnomani bekor qila oladi."
        )
        self.assertIsNotNone(p_red)
        self.assertEqual(p_red["risk_level"], "RED")
        self.assertIn("707", p_red["root_article"])
        self.assertTrue(legal_graph.verify_citation(p_red["root_article"]))

        # 2. Parafraza RED (iste'molchi huquqi) -> tasdiqlangan 221-I
        p_cons = local_neural_runtime.predict_clause(
            "Do'kondan xarid qilingan mahsulotda nuqson chiqsa ham xaridorga pul qaytarilmaydi va almashtirilmaydi."
        )
        self.assertIsNotNone(p_cons)
        self.assertEqual(p_cons["risk_level"], "RED")
        self.assertIn("221-I", p_cons["root_article"])

        # 3. Parafraza GREEN (to'g'ri muvozanatli to'lov) -> xavf chiqarmasligi shart!
        p_green = local_neural_runtime.predict_clause(
            "Shartnoma summasi O'zbekiston milliy valyutasi so'mda dalolatnoma imzolangach 10 bank ish kuni ichida o'tkaziladi."
        )
        self.assertIsNotNone(p_green)
        self.assertEqual(p_green["risk_level"], "GREEN")
        self.assertFalse(p_green["found"])

        # 4. Xorijiy qonun -> fail-closed UNKNOWN
        p_unk = local_neural_runtime.predict_clause(
            "Any dispute under this agreement shall be resolved by LCIA London under English law."
        )
        self.assertIsNotNone(p_unk)
        self.assertEqual(p_unk["risk_level"], "UNKNOWN")
        self.assertEqual(p_unk["root_article"], "")


if __name__ == "__main__":
    unittest.main(verbosity=2)
