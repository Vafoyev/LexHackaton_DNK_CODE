"""
LexGuard AI — LLM citation guard, ovozli brifing/savol-javob, servis qatlami va REST endpointlar testlari.
LLM chaqiruvlari httpx.MockTransport bilan simulyatsiya qilinadi (tarmoq kerak emas).
"""

import io
import json
import os
import sys
import unittest
from xml.dom import minidom

import httpx

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from fastapi.testclient import TestClient

from app import service
from app.analyzer import ClauseAnalyzer, ClauseIn
from app.knowledge_graph import legal_graph
from app.llm import OpenAICompatRefiner, citations_allowed
from app.main import app
from app.vector_store import legal_vector_store
from app.voice import answer_voice_query, build_voice_brief

UNILATERAL = "Buyurtmachi istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin."


def make_refiner(reply: str, status: int = 200, base_url="http://localhost:8001/v1", capture=None):
    def handler(request: httpx.Request) -> httpx.Response:
        if capture is not None:
            capture.append(json.loads(request.content))
        if status != 200:
            return httpx.Response(status, json={"error": "boom"})
        return httpx.Response(200, json={"choices": [{"message": {"content": reply}}]})

    client = httpx.Client(transport=httpx.MockTransport(handler))
    return OpenAICompatRefiner(base_url, "", "test-model", client=client)


def make_analyzer(refiner):
    return ClauseAnalyzer(legal_graph, legal_vector_store, refiner=refiner)


class TestCitationGuard(unittest.TestCase):
    ALLOWED = {"FK-UZ-2 707-modda", "FK-UZ-1 354-modda", "FK-UZ-1 324-modda"}

    def test_allowed_citations_pass(self):
        self.assertTrue(citations_allowed("FK 707-modda va 354-modda talablari.", self.ALLOWED))
        self.assertTrue(citations_allowed("Hech qanday modda keltirilmagan matn.", self.ALLOWED))

    def test_foreign_article_rejected(self):
        self.assertFalse(citations_allowed("FK 999-modda bo'yicha", self.ALLOWED))
        self.assertFalse(citations_allowed("707-modda va 123-modda", self.ALLOWED))

    def test_law_must_match_number(self):
        # 130-modda ruxsat etilgan ro'yxatda faqat MK uchun bo'lsa, FK 130 rad etiladi
        self.assertFalse(citations_allowed("FK 130-modda", {"MK-2022 130-modda"}))
        self.assertTrue(citations_allowed("MK 130-modda", {"MK-2022 130-modda"}))


class TestLLMRefine(unittest.TestCase):
    def test_valid_refinement_is_applied(self):
        reply = json.dumps({"explanation": "Band FK 707-modda talablariga zid: xarajatlar qoplanmaydi.",
                            "redline": "Buyurtmachi 15 kun oldin ogohlantirib, xarajatlarni qoplaydi."})
        rep = make_analyzer(make_refiner(reply)).analyze_clause(ClauseIn("c", "1", UNILATERAL), "SERVICE")
        f = rep.findings[0]
        self.assertEqual(f.source, "RULE+LLM")
        self.assertIn("Band FK 707-modda", f.issue_explanation)
        self.assertEqual(f.cited_article, "FK-UZ-2 707-modda")  # modda LLM tomonidan o'zgartirilmaydi

    def test_hallucinated_article_is_rejected_and_rule_result_kept(self):
        reply = json.dumps({"explanation": "FK 999-modda bo'yicha bu band haqiqiy emas.", "redline": "Yangi tahrir."})
        rep = make_analyzer(make_refiner(reply)).analyze_clause(ClauseIn("c", "1", UNILATERAL), "SERVICE")
        f = rep.findings[0]
        self.assertEqual(f.source, "RULE")
        self.assertNotIn("999", f.issue_explanation)

    def test_invalid_json_falls_back(self):
        rep = make_analyzer(make_refiner("bu json emas")).analyze_clause(ClauseIn("c", "1", UNILATERAL), "SERVICE")
        self.assertEqual(rep.findings[0].source, "RULE")

    def test_http_error_falls_back_without_breaking_analysis(self):
        rep = make_analyzer(make_refiner("", status=500)).analyze_clause(ClauseIn("c", "1", UNILATERAL), "SERVICE")
        self.assertEqual(len(rep.findings), 1)
        self.assertEqual(rep.findings[0].source, "RULE")

    def test_json_wrapped_in_markdown_is_parsed(self):
        reply = "```json\n" + json.dumps({"explanation": "Aniq tushuntirish.", "redline": "Aniq tahrir."}) + "\n```"
        rep = make_analyzer(make_refiner(reply)).analyze_clause(ClauseIn("c", "1", UNILATERAL), "SERVICE")
        self.assertEqual(rep.findings[0].source, "RULE+LLM")

    def test_use_llm_false_skips_the_call(self):
        calls = []
        refiner = make_refiner(json.dumps({"explanation": "x", "redline": "y"}), capture=calls)
        make_analyzer(refiner).analyze_clause(ClauseIn("c", "1", UNILATERAL), "SERVICE", use_llm=False)
        self.assertEqual(calls, [])

    def test_prompt_contains_only_allowed_norms(self):
        calls = []
        refiner = make_refiner(json.dumps({"explanation": "x qisqa", "redline": "y qisqa"}), capture=calls)
        make_analyzer(refiner).analyze_clause(ClauseIn("c", "1", UNILATERAL), "SERVICE")
        user_prompt = calls[0]["messages"][1]["content"]
        self.assertIn("RUXSAT ETILGAN MODDALAR", user_prompt)
        self.assertIn("FK-UZ-2 707-modda", user_prompt)
        self.assertEqual(calls[0]["temperature"], 0)

    def test_is_local_detection(self):
        self.assertTrue(make_refiner("{}", base_url="http://localhost:11434/v1").is_local)
        self.assertFalse(make_refiner("{}", base_url="https://api.example.com/v1").is_local)


class TestLLMTriage(unittest.TestCase):
    CLAUSE = "Kechiktirilgan har bir kun uchun 0,1% penya, umumiy summa 10% dan oshmaydi."

    def _related_code(self):
        rep = make_analyzer(None).analyze_clause(ClauseIn("c", "1", self.CLAUSE), "SERVICE")
        return rep.related_norms

    def test_triage_creates_yellow_finding_from_related_norm(self):
        related = self._related_code()
        self.assertTrue(related, "bu test uchun bog'liq norma kerak")
        reply = json.dumps({"risky": True, "norm": related[0]["code"], "title": "Tekshiruv",
                            "explanation": "Band tekshirilishi lozim.", "redline": "Aniqlashtiring."})
        rep = make_analyzer(make_refiner(reply)).analyze_clause(ClauseIn("c", "1", self.CLAUSE), "SERVICE")
        self.assertEqual(len(rep.findings), 1)
        f = rep.findings[0]
        self.assertEqual(f.risk_level, "YELLOW")
        self.assertEqual(f.source, "LLM_TRIAGE")
        self.assertEqual(f.cited_article, related[0]["code"])

    def test_triage_cannot_cite_norm_outside_candidates(self):
        reply = json.dumps({"risky": True, "norm": "FK-UZ-2 707-modda", "explanation": "Xavfli.", "redline": "Tuzating."})
        rep = make_analyzer(make_refiner(reply)).analyze_clause(ClauseIn("c", "1", self.CLAUSE), "SERVICE")
        self.assertEqual(rep.findings, [])

    def test_triage_not_risky_yields_nothing(self):
        related = self._related_code()
        reply = json.dumps({"risky": False, "norm": related[0]["code"]})
        rep = make_analyzer(make_refiner(reply)).analyze_clause(ClauseIn("c", "1", self.CLAUSE), "SERVICE")
        self.assertEqual(rep.findings, [])


class TestVoice(unittest.TestCase):
    def test_brief_ssml_is_valid_xml_even_with_special_chars(self):
        risks = [{"risk_level": "RED", "issue_title": "Penya & <jarima> \"xavfi\"", "issue_explanation": "A & B < C. Ikkinchi gap."}]
        brief = build_voice_brief(risks)
        minidom.parseString(brief["ssml"].encode("utf-8"))  # buzuq XML bo'lsa istisno
        self.assertIn("Assalomu alaykum", brief["audio_script_uz"])
        self.assertGreater(brief["duration_sec"], 5)

    def test_brief_text_not_duplicated_in_ssml(self):
        brief = build_voice_brief([{"risk_level": "RED", "issue_title": "X", "issue_explanation": "Y."}])
        self.assertEqual(brief["ssml"].count("Assalomu alaykum"), 1)

    def test_brief_counts_and_disclaimer(self):
        risks = [{"risk_level": "RED", "issue_title": "A", "issue_explanation": "a."},
                 {"risk_level": "YELLOW", "issue_title": "B", "issue_explanation": "b."}]
        script = build_voice_brief(risks)["audio_script_uz"]
        self.assertIn("jami 2 ta", script)
        self.assertIn("yurist ko'rigidan", script)

    def test_brief_without_risks(self):
        self.assertIn("aniqlanmadi", build_voice_brief([])["audio_script_uz"])

    def test_answer_for_explicit_article_reference(self):
        ans = answer_voice_query("707-modda nima deydi?", legal_graph, legal_vector_store)
        self.assertIn("FK-UZ-2 707-modda", ans)
        self.assertIn("lex.uz", ans)

    def test_answer_falls_back_to_bm25(self):
        ans = answer_voice_query("neustoykani kamaytirish mumkinmi", legal_graph, legal_vector_store)
        self.assertIn("326", ans)

    def test_answer_for_gibberish(self):
        self.assertIn("topilmadi", answer_voice_query("qwxz plmk", legal_graph, legal_vector_store))


class TestServiceAndRest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)

    def test_stats_are_computed_not_hardcoded(self):
        stats = service.corpus_stats()
        self.assertEqual(stats["total_articles"], len(legal_graph.nodes))
        self.assertEqual(sum(s["articles"] for s in stats["sources"]), stats["total_articles"])
        self.assertEqual(stats["total_laws"], len(stats["sources"]))
        self.assertGreater(stats["fine_tuning_pairs"], 0)

    def test_health_reports_engine_state(self):
        r = self.client.get("/health").json()
        self.assertEqual(r["status"], "UP")
        self.assertEqual(r["rules_loaded"], len(service.rules_catalog()))
        self.assertFalse(r["llm_enabled"])

    def test_rules_endpoint(self):
        r = self.client.get("/api/v1/rules").json()
        self.assertEqual(r["count"], len(r["rules"]))
        by_code = {x["code"]: x for x in r["rules"]}
        self.assertIn("707", by_code["TERM_UNILATERAL_SERVICE"]["root_article"])
        self.assertIn("lex.uz", by_code["TERM_UNILATERAL_SERVICE"]["url"])

    def test_analyze_clauses_response_shape(self):
        r = self.client.post("/api/v1/analyze-clauses", json={
            "analysis_id": "t1", "document_type": "SERVICE_AGREEMENT", "party_role": "EXECUTOR",
            "clauses": [
                {"clause_id": "a", "clause_number": "1.1", "text": UNILATERAL},
                {"clause_id": "b", "clause_number": "1.2", "text": "Ijrochi xizmat ko'rsatadi."},
            ],
        }).json()
        self.assertEqual(r["total_clauses"], 2)
        self.assertEqual(r["findings_count"], 1)
        self.assertEqual(r["risk_summary"], {"RED": 1, "YELLOW": 0})
        f = r["findings"][0]
        for key in ("clause_id", "risk_level", "category", "issue_title", "problematic_quote", "issue_explanation",
                    "cited_article", "suggested_redline", "balance_label", "lex_uz_url", "multi_hop_chain"):
            self.assertIn(key, f)
        self.assertEqual(f["clause_id"], "a")
        statuses = {c["clause_id"]: c["status"] for c in r["clause_reports"]}
        self.assertEqual(statuses, {"a": "RULE_MATCHED", "b": "NO_RULE_MATCH"})

    def test_analyze_clauses_go_backend_contract_is_compatible(self):
        """Go ai.EngineClient JSON maydonlari (engine_client.go FindingOutput) saqlangan."""
        r = self.client.post("/api/v1/analyze-clauses", json={
            "analysis_id": "clause-eval", "document_type": "SERVICE_AGREEMENT", "contract_date": "2026-11-21",
            "clauses": [{"clause_id": "cl-1", "clause_number": "1.1", "text": UNILATERAL}],
        }).json()
        f = r["findings"][0]
        self.assertEqual(f["risk_level"], "RED")
        self.assertEqual(len(f["cited_article"].split(" ", 1)), 2)  # "FK-UZ-2 707-modda" -> law + article
        self.assertIsInstance(f["multi_hop_chain"], list)

    def test_analyze_document_end_to_end(self):
        doc = ("1.1. Ijrochi xizmat ko'rsatadi.\n"
               "1.2. Buyurtmachi istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin.\n"
               "2.1. Kechiktirilgan har bir kun uchun 1% penya to'lanadi.\n")
        r = self.client.post(
            "/api/v1/analyze-document",
            files={"file": ("shartnoma.txt", io.BytesIO(doc.encode("utf-8")), "text/plain")},
            data={"document_type": "SERVICE_AGREEMENT"},
        )
        self.assertEqual(r.status_code, 200)
        body = r.json()
        self.assertEqual(body["total_clauses"], 3)
        self.assertEqual(body["risk_summary"]["RED"], 1)
        self.assertEqual(body["risk_summary"]["YELLOW"], 1)
        self.assertFalse(body["needs_human_review"])
        for f in body["findings"]:
            self.assertIn(f["problematic_quote"], doc)

    def test_upload_size_limit(self):
        from app import main
        big = io.BytesIO(b"a" * (main.MAX_UPLOAD_BYTES + 10))
        r = self.client.post("/api/v1/ocr", files={"file": ("big.txt", big, "text/plain")})
        self.assertEqual(r.status_code, 413)

    def test_self_correct_excludes_rejected_article(self):
        r = self.client.post("/api/v1/self-correct", json={
            "clause_text": "Buyurtmachi shartnomani istalgan paytda bir tomonlama bekor qiladi",
            "previous_cited_article": "FK 707", "verification_error": "mos emas",
            "candidate_articles": ["FK-UZ-2_707"],
        }).json()
        self.assertTrue(r["resolved"])
        self.assertNotIn("707", r["corrected_article"])

    def test_self_correct_unresolved(self):
        r = self.client.post("/api/v1/self-correct", json={"clause_text": "qwxz plmk"}).json()
        self.assertFalse(r["resolved"])

    def test_voice_endpoints(self):
        r = self.client.post("/api/v1/voice-query", json={"query": "707-modda nima deydi?"}).json()
        self.assertIn("707", r["answer"])
        self.assertEqual(self.client.post("/api/v1/voice-query", json={"query": "  "}).status_code, 422)
        r = self.client.post("/api/v1/voice-brief", json={"analysis_id": "x", "top_risks": []}).json()
        self.assertIn("<speak>", r["ssml"])

    def test_search_laws_validates_top_k(self):
        self.assertEqual(self.client.get("/api/v1/search-laws", params={"q": "neustoyka", "top_k": 0}).status_code, 422)

    def test_cors_not_wildcard_with_credentials(self):
        r = self.client.options("/health", headers={"Origin": "https://evil.example", "Access-Control-Request-Method": "GET"})
        self.assertNotEqual(r.headers.get("access-control-allow-credentials"), "true")


if __name__ == "__main__":
    unittest.main()
