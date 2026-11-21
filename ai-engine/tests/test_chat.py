"""
LexGuard AI — Suhbat (chat) testlari: yo'naltirish (intent), manbalar, ovozli matn, REST endpoint.
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from fastapi.testclient import TestClient

from app.chat import MAX_MESSAGE_CHARS, SEARCH_MIN_SCORE, answer_chat, clean_article_text
from app.knowledge_graph import legal_graph
from app.main import app


class TestChatIntents(unittest.TestCase):
    def test_greeting_returns_help_with_suggestions(self):
        r = answer_chat("salom")
        self.assertEqual(r["intent"], "help")
        self.assertTrue(r["suggestions"])

    def test_empty_message_returns_help(self):
        self.assertEqual(answer_chat("   ")["intent"], "help")

    def test_article_question(self):
        r = answer_chat("707-modda nima deydi?")
        self.assertEqual(r["intent"], "article")
        self.assertIn("707", r["sources"][0]["code"])
        self.assertIn("lex.uz", r["sources"][0]["url"])

    def test_article_with_law_prefix(self):
        r = answer_chat("MK 130 modda nima?")
        self.assertEqual(r["intent"], "article")
        self.assertEqual(r["sources"][0]["id"], "MK-2022_130")

    def test_unknown_article_number_falls_through(self):
        r = answer_chat("99999-modda nima deydi?")
        self.assertNotEqual(r["intent"], "article")

    def test_topic_question_uses_curated_rule_with_citations(self):
        r = answer_chat("Penya qancha bo'lishi mumkin?")
        self.assertEqual(r["intent"], "topic")
        self.assertIn("670-I", r["answer"])
        codes = [s["code"] for s in r["sources"]]
        self.assertTrue(any("326" in c for c in codes), codes)

    def test_topic_answer_omits_clause_specific_sentences(self):
        r = answer_chat("Shartnomani bir tomonlama bekor qilish mumkinmi?")
        self.assertEqual(r["intent"], "topic")
        self.assertNotIn("Band shartnomani", r["answer"])
        self.assertIn("707", r["answer"])

    def test_clause_is_analyzed_with_findings(self):
        r = answer_chat("Buyurtmachi istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin.")
        self.assertEqual(r["intent"], "analysis")
        self.assertEqual(len(r["findings"]), 1, "bir xil xavf takrorlanmasligi kerak")
        self.assertEqual(r["findings"][0]["risk_level"], "RED")
        self.assertIn("707", r["findings"][0]["cited_article"])
        self.assertIn("xarajat", r["findings"][0]["suggested_redline"].lower())
        self.assertNotIn(r["findings"][0]["suggested_redline"], r["answer"], "tahrir matnda takrorlanmasligi kerak")
        self.assertNotIn("Bog'liq normalar", r["answer"], "bog'liq normalar manba chiplarida ko'rsatiladi")

    def test_clean_clause_reports_no_findings_without_guaranteeing_safety(self):
        r = answer_chat("Ijrochi xizmat ko'rsatadi va hisobot topshiradi har oy oxirida.")
        self.assertEqual(r["intent"], "no_findings")
        self.assertIn("kafolatlamaydi", r["answer"])
        self.assertEqual(r["findings"], [])

    def test_off_topic_is_rejected_not_answered_with_random_article(self):
        for q in ("bugun ob-havo qanday", "pitsa buyurtma qilmoqchiman"):
            with self.subTest(q=q):
                r = answer_chat(q)
                self.assertEqual(r["intent"], "no_match")
                self.assertEqual(r["sources"], [])

    def test_general_legal_question_gets_search_results(self):
        r = answer_chat("Iste'molchi nuqsonli tovarni qaytara oladimi?")
        self.assertIn(r["intent"], ("topic", "search"))
        self.assertTrue(r["sources"])

    def test_every_source_exists_in_corpus(self):
        for q in ("707-modda nima?", "Penya qancha?", "Mehnat shartnomasida sinov muddati necha oy?",
                  "Buyurtmachi istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin."):
            for s in answer_chat(q)["sources"]:
                self.assertIn(s["id"], legal_graph.nodes, f"{q}: {s}")

    def test_search_threshold_constant_is_sane(self):
        self.assertGreater(SEARCH_MIN_SCORE, 7.5)  # mavzudan tashqari savollar (ball <= ~7) rad etilishi uchun


class TestChatTextQuality(unittest.TestCase):
    def test_clean_article_text_strips_service_tags_everywhere(self):
        raw = "[ OKOZ: 1. 05.00 Mehnat] Birinchi gap. [ SPiT: 1. Извините ] Ikkinchi gap."
        cleaned = clean_article_text(raw)
        self.assertNotIn("OKOZ", cleaned)
        self.assertNotIn("SPiT", cleaned)
        self.assertNotIn("Извините", cleaned)

    def test_clean_article_text_strips_amendment_notes_and_reference_tail(self):
        raw = "Asosiy matn shu yerda. (21-moddaning matni 2021-yil 21-apreldagi OʻRQ-683-sonli Qonuni tahririda — baza) mazkur Kodeksning 101, 105-moddalari."
        cleaned = clean_article_text(raw)
        self.assertNotIn("tahririda", cleaned)
        self.assertNotIn("mazkur Kodeksning", cleaned)
        self.assertTrue(cleaned.startswith("Asosiy matn"))

    def test_clean_article_text_truncates_at_sentence_boundary(self):
        raw = ("Birinchi gap bor. " * 40).strip()
        cleaned = clean_article_text(raw, limit=100)
        self.assertLessEqual(len(cleaned), 101)
        self.assertTrue(cleaned.endswith("."))

    def test_no_service_tags_leak_into_any_answer(self):
        for q in ("Ish beruvchi meni ishdan bo'shatsa nima qilaman?", "Mehnat shartnomasida sinov muddati necha oy?", "130-modda nima?"):
            self.assertNotIn("OKOZ", answer_chat(q)["answer"], q)

    def test_speech_is_clean_for_tts(self):
        r = answer_chat("Buyurtmachi istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin.")
        speech = r["speech"]
        self.assertNotIn("http", speech)
        self.assertNotIn("🔴", speech)
        self.assertNotIn(":.", speech)
        self.assertNotIn("..", speech)
        self.assertLessEqual(len(speech), 400)

    def test_disclaimer_present(self):
        self.assertIn("yurist", answer_chat("salom")["disclaimer"])


class TestChatEndpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)

    def test_chat_endpoint_shape(self):
        r = self.client.post("/api/v1/chat", json={"message": "707-modda nima deydi?"})
        self.assertEqual(r.status_code, 200)
        body = r.json()
        for key in ("intent", "answer", "speech", "sources", "findings", "suggestions", "disclaimer"):
            self.assertIn(key, body)

    def test_empty_message_rejected(self):
        self.assertEqual(self.client.post("/api/v1/chat", json={"message": "  "}).status_code, 422)

    def test_missing_message_rejected(self):
        self.assertEqual(self.client.post("/api/v1/chat", json={}).status_code, 422)

    def test_too_long_message_rejected(self):
        r = self.client.post("/api/v1/chat", json={"message": "a" * (MAX_MESSAGE_CHARS + 1)})
        self.assertEqual(r.status_code, 413)


if __name__ == "__main__":
    unittest.main()
