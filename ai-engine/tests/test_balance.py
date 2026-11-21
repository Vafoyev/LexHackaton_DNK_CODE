"""
LexGuard AI — Tomonlar balansi testlari: bir tomonlama/teng/ikki tomonga og'ir, inkor, simmetriya, tengsiz penya,
doc-type nomlari, party_role, ishonch darajasi va REST endpoint.
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from fastapi.testclient import TestClient

from app import service
from app.analyzer import ClauseIn, analyzer
from app.knowledge_graph import legal_graph
from app.main import app
from app.parties import BOTH, PROVIDER, RECIPIENT, first_side, has_prohibition, is_symmetric
from app.text_utils import normalize_text

SERVICE = "SERVICE_AGREEMENT"


def balance(clauses, doc_type=SERVICE, role=""):
    return service.balance_request(
        [{"clause_id": str(i), "clause_number": n, "text": t} for i, (n, t) in enumerate(clauses, 1)], doc_type, role,
    )


def topic(result, code):
    return next((t for t in result["topics"] if t["topic"] == code), None)


ONE_SIDED = [
    ("2.1", "Kechiktirilgan har bir kun uchun Ijrochi 1% penya to'laydi."),
    ("4.1", "Buyurtmachi istalgan vaqtda to'lovsiz shartnomani bir tomonlama bekor qilishi mumkin."),
    ("5.1", "Ijrochi barcha zararlar uchun to'liq javobgar bo'ladi."),
    ("6.1", "Buyurtmachi narxni istalgan vaqtda bir tomonlama oshirishi mumkin."),
]
BALANCED = [
    ("2.1", "Majburiyatni kechiktirgan taraf har bir kun uchun 0,1% penya to'laydi, umumiy summa 10% dan oshmaydi."),
    ("4.1", "Taraflardan har biri 15 kun oldin yozma ogohlantirib shartnomani bekor qilishi mumkin."),
    ("5.1", "Taraflar shartnoma bahosi doirasida javobgar bo'ladi."),
]
SYMMETRIC_BUT_HEAVY = [
    ("2.1", "Ijrochi har bir kun uchun 1% penya to'laydi."),
    ("2.2", "Buyurtmachi har bir kun uchun 1% penya to'laydi."),
    ("4.1", "Ijrochi istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin."),
    ("4.2", "Buyurtmachi istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin."),
    ("5.1", "Ijrochi hech qanday javobgar bo'lmaydi."),
    ("5.2", "Buyurtmachi hech qanday javobgar bo'lmaydi."),
]


class TestPartiesHelpers(unittest.TestCase):
    def n(self, t):
        return normalize_text(t)

    def test_first_side(self):
        self.assertEqual(first_side(self.n("Ijrochi Buyurtmachiga penya to'laydi")), PROVIDER)
        self.assertEqual(first_side(self.n("Buyurtmachi Ijrochiga haq to'laydi")), RECIPIENT)
        self.assertIsNone(first_side(self.n("Penya to'lanadi")))

    def test_symmetric_markers(self):
        for t in ("Taraflardan har biri bekor qilishi mumkin", "Ikkala taraf javob beradi", "Har ikki tomon penya to'laydi",
                  "Majburiyatni kechiktirgan taraf penya to'laydi", "Ijrochi va Buyurtmachi penya to'laydi"):
            self.assertTrue(is_symmetric(self.n(t)), t)

    def test_named_party_before_generic_word_is_not_symmetric(self):
        self.assertFalse(is_symmetric(self.n("Buyurtmachi taraflar oldida javobgar")))
        self.assertFalse(is_symmetric(self.n("Ijrochi penya to'laydi")))

    def test_prohibition(self):
        self.assertTrue(has_prohibition(self.n("Bir tomonlama bekor qilish taqiqlanadi")))
        self.assertTrue(has_prohibition(self.n("Bekor qilish mumkin emas")))
        self.assertFalse(has_prohibition(self.n("Bekor qilish mumkin")))


class TestAnalyzerBalanceFields(unittest.TestCase):
    def run_clause(self, text, doc="SERVICE", role=""):
        return analyzer.analyze_clause(ClauseIn("c", "1", text), doc, role, use_llm=False)

    def test_negation_suppresses_risky_right(self):
        self.assertEqual(self.run_clause("Bir tomonlama bekor qilish taqiqlanadi.").findings, [])
        self.assertEqual(self.run_clause("Shartnomani istalgan vaqtda bir tomonlama bekor qilish mumkin emas.").findings, [])

    def test_contrast_conjunction_keeps_the_risk(self):
        rep = self.run_clause("Buyurtmachi istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin, lekin Ijrochi bekor qila olmaydi.")
        self.assertEqual([f.rule_code for f in rep.findings], ["TERM_UNILATERAL_SERVICE"])

    def test_symmetric_clause_is_labeled_balanced_but_risk_stays(self):
        f = self.run_clause("Taraflardan har biri istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin.").findings[0]
        self.assertEqual(f.burdened_side, BOTH)
        self.assertEqual(f.balance_label, "Muvozanatli (ikki tomonga teng)")
        self.assertEqual(f.risk_level, "RED")  # FK 707 baribir buziladi: balans huquqiy xavfni yo'qotmaydi

    def test_burdened_side_is_set(self):
        f = self.run_clause("Buyurtmachi istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin.").findings[0]
        self.assertEqual(f.burdened_side, PROVIDER)
        f = self.run_clause("Ijrochi istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin.").findings[0]
        self.assertEqual(f.burdened_side, RECIPIENT)

    def test_neutral_rule_has_no_burdened_side(self):
        f = self.run_clause("Xodimga 6 oy sinov muddati belgilanadi.", "EMPLOYMENT").findings[0]
        self.assertIsNone(f.burdened_side)


class TestContractBalance(unittest.TestCase):
    def test_one_sided_contract(self):
        b = balance(ONE_SIDED)
        self.assertEqual(b["verdict"], "ONE_SIDED_PROVIDER")
        self.assertEqual(b["verdict_label"], "Ijrochi tomoniga og'ir")
        self.assertGreater(b["sides"]["provider"]["share"], 90)
        self.assertLess(b["score"], 30)
        for code in ("TERMINATION", "PENALTY", "LIABILITY", "CHANGE"):
            self.assertEqual(topic(b, code)["status"], "ONE_SIDED", code)
            self.assertEqual(topic(b, code)["burdened_side"], PROVIDER, code)

    def test_right_given_to_one_side_burdens_the_other(self):
        t = topic(balance(ONE_SIDED), "TERMINATION")
        self.assertIn("Faqat Buyurtmachi tomoniga berilgan", t["detail"])
        self.assertEqual(t["burdened_name"], "Ijrochi")

    def test_obligation_on_one_side_burdens_that_side(self):
        t = topic(balance(ONE_SIDED), "PENALTY")
        self.assertIn("Faqat Ijrochi uchun belgilangan", t["detail"])

    def test_recommendations_are_reciprocal(self):
        recs = {r["topic"]: r["text"] for r in balance(ONE_SIDED)["recommendations"]}
        self.assertIn("Taraflardan har biri", recs["TERMINATION"])
        self.assertIn("ikkalasi ham", recs["PENALTY"])
        self.assertIn("o'zaro teng", recs["LIABILITY"])
        self.assertIn("ikkala tarafning", recs["CHANGE"])

    def test_balanced_contract(self):
        b = balance(BALANCED)
        self.assertEqual(b["verdict"], "BALANCED")
        self.assertEqual(b["score"], 100)
        self.assertEqual(b["recommendations"], [])
        for t in b["topics"]:
            self.assertEqual(t["status"], "BALANCED", t["topic"])

    def test_symmetric_but_risky_is_flagged_heavy_for_both(self):
        b = balance(SYMMETRIC_BUT_HEAVY)
        self.assertEqual(b["verdict"], "BALANCED_HEAVY")
        self.assertEqual(b["verdict_label"], "Ikki tomonga ham og'ir")
        self.assertTrue(b["sides"]["provider"]["heavy"] and b["sides"]["recipient"]["heavy"])
        self.assertEqual(b["sides"]["provider"]["burden"], b["sides"]["recipient"]["burden"])
        self.assertIn("xavfli", b["summary"])

    def test_unequal_penalty_rates_are_detected(self):
        b = balance([
            ("2.1", "Ijrochi kechiktirsa, har bir kun uchun 1% penya to'laydi, umumiy summa 10% dan oshmaydi."),
            ("2.2", "Buyurtmachi kechiktirsa, har bir kun uchun 0,1% penya to'laydi, umumiy summa 10% dan oshmaydi."),
        ])
        t = topic(b, "PENALTY")
        self.assertEqual(t["status"], "UNEQUAL")
        self.assertEqual(t["burdened_side"], PROVIDER)
        self.assertIn("10.0 baravar", t["detail"])

    def test_equal_penalty_rates_are_balanced(self):
        b = balance([
            ("2.1", "Ijrochi kechiktirsa, har bir kun uchun 0,1% penya to'laydi."),
            ("2.2", "Buyurtmachi kechiktirsa, har bir kun uchun 0,1% penya to'laydi."),
        ])
        self.assertEqual(topic(b, "PENALTY")["status"], "BALANCED")

    def test_prohibition_does_not_create_a_right(self):
        b = balance([("4.1", "Bir tomonlama bekor qilish taqiqlanadi."), ("4.2", "Taraflar shartnomani kelishuv bilan bekor qiladi.")])
        t = topic(b, "TERMINATION")
        self.assertNotIn("4.1", t["clause_numbers"], "taqiqlovchi gap huquq sifatida yozilmasligi kerak")
        self.assertEqual(t["status"], "BALANCED")
        self.assertEqual(b["verdict"], "BALANCED")

    def test_force_majeure_exemption_is_not_one_sided(self):
        b = balance([("5.1", "Fors-major holatlarida Ijrochi javobgar bo'lmaydi.")])
        self.assertIsNone(topic(b, "LIABILITY_EXEMPTION"))

    def test_exemption_for_one_side_burdens_the_other(self):
        b = balance([("5.1", "Ijrochi hech qanday javobgar bo'lmaydi."), ("5.2", "Ijrochi xizmatni sifatli ko'rsatadi."), ("5.3", "Buyurtmachi to'laydi.")])
        t = topic(b, "LIABILITY_EXEMPTION")
        self.assertEqual(t["status"], "ONE_SIDED")
        self.assertEqual(t["burdened_side"], RECIPIENT)

    def test_same_clause_is_not_counted_twice(self):
        """Bir band ham qoida topilmasi (sariq=1), ham daftar tengsizligi (2) bersa, katta hissa olinadi (2), yig'indi (3) emas."""
        b = balance([("2.1", "Kechiktirilgan har bir kun uchun Ijrochi 1% penya to'laydi.")])
        self.assertEqual(topic(b, "PENALTY")["status"], "ONE_SIDED")
        self.assertEqual(b["sides"]["provider"]["burden"], 2.0)

    def test_red_finding_outweighs_topic_points_on_same_clause(self):
        b = balance([("4.1", "Buyurtmachi istalgan vaqtda to'lovsiz shartnomani bir tomonlama bekor qilishi mumkin.")])
        self.assertEqual(b["sides"]["provider"]["burden"], 3.0)  # RED=3 (daftar 2 emas, yig'indi 5 emas)

    def test_single_small_risk_is_not_one_sided(self):
        b = balance([("1.1", "Maxfiy ma'lumotlarni oshkor qilmaslik majburiyati muddatsiz amal qiladi."), ("1.2", "Ijrochi ishlaydi."), ("1.3", "Buyurtmachi to'laydi.")])
        self.assertEqual(b["verdict"], "BALANCED")
        self.assertLess(b["sides"]["provider"]["burden"] + b["sides"]["recipient"]["burden"], 2)

    def test_no_signals_is_balanced_but_not_guaranteed_safe(self):
        b = balance([("1.1", "Ijrochi xizmat ko'rsatadi."), ("1.2", "Buyurtmachi to'laydi."), ("1.3", "Hisobot oyiga bir marta topshiriladi.")])
        self.assertEqual(b["verdict"], "BALANCED")
        self.assertIn("kafolatlamaydi", b["summary"])

    def test_party_role_marks_the_users_side(self):
        # Ijrochi og'ir; foydalanuvchi Ijrochi (EXECUTOR)
        self.assertIn("Siz shu tomondasiz", balance(ONE_SIDED, role="EXECUTOR")["summary"])
        self.assertNotIn("Siz shu tomondasiz", balance(ONE_SIDED, role="CUSTOMER")["summary"])

    def test_doc_type_changes_side_names(self):
        b = balance([("2.1", "Sotuvchi kechiktirsa 1% penya to'laydi."), ("3.1", "Xaridor istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin.")], "SUPPLY_SALE")
        self.assertEqual(b["sides"]["provider"]["name"], "Sotuvchi")
        self.assertEqual(b["sides"]["recipient"]["name"], "Xaridor")
        self.assertIn("Sotuvchi", b["verdict_label"])

    def test_confidence_is_low_for_tiny_documents(self):
        self.assertEqual(balance([("1.1", "Penya 1% bo'ladi.")])["confidence"], "LOW")
        self.assertEqual(balance(ONE_SIDED)["confidence"], "MEDIUM")

    def test_unattributed_sentences_are_counted_not_guessed(self):
        b = balance([("2.1", "Penya to'lanadi."), ("2.2", "Ijrochi ishlaydi."), ("2.3", "Buyurtmachi to'laydi.")])
        self.assertIsNone(topic(b, "PENALTY"))
        self.assertGreaterEqual(b["stats"]["unattributed"], 1)

    def test_result_shape_and_bounds(self):
        for case in (ONE_SIDED, BALANCED, SYMMETRIC_BUT_HEAVY):
            b = balance(case)
            self.assertTrue(0 <= b["score"] <= 100)
            self.assertEqual(b["method"], "heuristic")
            self.assertTrue(b["limitations"])
            self.assertLessEqual(b["sides"]["provider"]["share"] + b["sides"]["recipient"]["share"], 101)
            for key in ("verdict", "verdict_label", "summary", "sides", "topics", "recommendations", "stats", "confidence", "basis"):
                self.assertIn(key, b)

    def test_basis_cites_real_corpus_articles(self):
        basis = balance(ONE_SIDED)["basis"]
        self.assertEqual({b["id"] for b in basis}, {"FK-UZ-1_1", "FK-UZ-1_354"})
        for b in basis:
            self.assertIn(b["id"], legal_graph.nodes)
            self.assertIn("lex.uz", b["url"])

    def test_limitations_state_balance_is_not_a_legal_requirement(self):
        self.assertTrue(any("qonuniy talab emas" in x for x in balance(ONE_SIDED)["limitations"]))

    def test_cyrillic_contract_is_balanced_too(self):
        b = balance([("4.1", "Буюртмачи истаган вақтда бир томонлама бекор қилиши мумкин."), ("2.1", "Ижрочи пеня тўлайди."), ("3.1", "Ижрочи жавобгар.")])
        self.assertEqual(topic(b, "TERMINATION")["burdened_side"], PROVIDER)


class TestBalanceEndpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)

    def payload(self, clauses=ONE_SIDED):
        return {"document_type": SERVICE, "party_role": "EXECUTOR",
                "clauses": [{"clause_id": str(i), "clause_number": n, "text": t} for i, (n, t) in enumerate(clauses, 1)]}

    def test_endpoint(self):
        r = self.client.post("/api/v1/balance", json=self.payload())
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["verdict"], "ONE_SIDED_PROVIDER")

    def test_empty_clauses_rejected(self):
        self.assertEqual(self.client.post("/api/v1/balance", json={"clauses": []}).status_code, 422)

    def test_too_many_clauses_rejected(self):
        many = {"clauses": [{"clause_id": str(i), "text": "x"} for i in range(501)]}
        self.assertEqual(self.client.post("/api/v1/balance", json=many).status_code, 413)

    def test_analyze_clauses_includes_balance(self):
        r = self.client.post("/api/v1/analyze-clauses", json={"analysis_id": "b1", "document_type": SERVICE, **self.payload()}).json()
        self.assertIn("balance", r)
        self.assertEqual(r["balance"]["verdict"], "ONE_SIDED_PROVIDER")
        self.assertIn("burdened_side", r["findings"][0])


if __name__ == "__main__":
    unittest.main()
