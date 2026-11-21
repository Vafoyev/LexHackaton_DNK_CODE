"""
LexGuard AI — Tahlil yadrosi testlari: qoidalar butunligi, ijobiy/salbiy holatlar, iqtibos kafolati,
kirill/apostrof variantlari, shartnoma turi bo'yicha gating, Active Self-Correction, modda qidiruvi.
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.analyzer import ClauseIn, analyzer
from app.knowledge_graph import legal_graph
from app.rules import ANY, RULES, canonical_doc_type
from app.text_utils import normalize_text, split_sentences
from app.vector_store import legal_vector_store


def run(text, doc_type="SERVICE", party_role=""):
    return analyzer.analyze_clause(ClauseIn("c1", "1.1", text), doc_type, party_role, use_llm=False)


def codes(report):
    return [f.rule_code for f in report.findings]


class TestRuleCatalogIntegrity(unittest.TestCase):
    def test_rule_codes_unique(self):
        all_codes = [r.code for r in RULES]
        self.assertEqual(len(all_codes), len(set(all_codes)))

    def test_every_cited_article_exists_in_corpus(self):
        """Hallyutsinatsiya yo'q: har bir qoidaning root/related moddasi korpusda mavjud bo'lishi shart."""
        missing = []
        for r in RULES:
            for node_id in (r.root, *r.related, *r.root_by_doc.values()):
                if node_id not in legal_graph.nodes:
                    missing.append((r.code, node_id))
        self.assertEqual(missing, [])

    def test_rules_have_redline_and_explanation(self):
        for r in RULES:
            self.assertTrue(r.why.strip(), r.code)
            self.assertTrue(r.redline.strip(), r.code)
            self.assertIn(r.risk, ("RED", "YELLOW"), r.code)

    def test_dispositive_rules_are_never_red(self):
        for r in RULES:
            if r.norm_nature == "DISPOSITIVE":
                self.assertEqual(r.risk, "YELLOW", f"{r.code}: dispozitiv norma RED bo'la olmaydi")

    def test_doc_type_mapping(self):
        self.assertEqual(canonical_doc_type("B2B_SERVICE"), "SERVICE")
        self.assertEqual(canonical_doc_type("SERVICE_AGREEMENT"), "SERVICE")
        self.assertEqual(canonical_doc_type("SUPPLY_SALE"), "SALE")
        self.assertEqual(canonical_doc_type("COMMERCIAL_LEASE"), "LEASE")
        self.assertEqual(canonical_doc_type("employment"), "EMPLOYMENT")
        self.assertEqual(canonical_doc_type(""), "GENERAL")
        self.assertEqual(canonical_doc_type("nomalum"), "GENERAL")
        self.assertEqual(canonical_doc_type("any"), ANY)


class TestRuleDetection(unittest.TestCase):
    POSITIVE = [
        # (doc_type, matn, kutilgan qoida, kutilgan daraja)
        ("SERVICE", "Buyurtmachi istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin.", "TERM_UNILATERAL_SERVICE", "RED"),
        ("SERVICE", "Buyurtmachi Ijrochini ogohlantirmasdan va to'lovsiz shartnomani bekor qilishi mumkin.", "TERM_UNILATERAL_SERVICE", "RED"),
        ("SERVICE", "Kechiktirilgan har bir kun uchun 1% miqdorida penya to'lanadi.", "PENALTY_DISPROPORTIONATE", "YELLOW"),
        ("SERVICE", "Majburiyat kechiktirilsa, Ijrochi penya to'laydi.", "PENALTY_DISPROPORTIONATE", "YELLOW"),
        ("SALE", "Ko'chmas mulk oldi-sotdi shartnomasi oddiy yozma shaklda tuziladi.", "FORM_REALESTATE_WRONG_FORM", "RED"),
        ("SALE", "Sotuvchi kvartirani Xaridorga sotadi.", "FORM_REALESTATE_REGISTRATION", "YELLOW"),
        ("SERVICE", "Ijrochi barcha zararlarni to'liq qoplaydi.", "LIABILITY_UNLIMITED_SERVICE", "YELLOW"),
        ("SERVICE", "Ijrochi hech qanday javobgar bo'lmaydi.", "LIABILITY_EXCLUSION", "YELLOW"),
        ("SERVICE", "Ijrochi hech qanday javobgar bo'lmaydi, hatto qasddan yetkazilgan zarar uchun ham.", "LIABILITY_EXCLUSION", "RED"),
        ("EMPLOYMENT", "Xodimga 6 oy sinov muddati belgilanadi.", "EMP_PROBATION_EXCESS", "RED"),
        ("SERVICE", "Shaxsiy ma'lumotlar subyekt roziligisiz chet elga uzatiladi.", "PRIVACY_CROSS_BORDER", "YELLOW"),
        ("SERVICE", "Shaxsiy ma'lumotlar roziligisiz qayta ishlanadi.", "PRIVACY_NO_CONSENT", "YELLOW"),
        ("SERVICE", "Xizmatlar hajmi keyin kelishiladi.", "ESSENTIAL_TERMS_VAGUE", "RED"),
        ("SERVICE", "Xizmat narxi keyinroq kelishiladi.", "ESSENTIAL_TERMS_VAGUE", "YELLOW"),
        ("SALE", "Avans 100% miqdorida to'lanadi va qaytarilmaydi.", "ADVANCE_PAYMENT_NONREFUNDABLE", "YELLOW"),
        ("SERVICE", "Ijrochi narxni istalgan vaqtda bir tomonlama oshirishi mumkin.", "PRICE_UNILATERAL_CHANGE", "YELLOW"),
        ("SERVICE", "Maxfiy ma'lumotlarni oshkor qilmaslik majburiyati muddatsiz amal qiladi.", "CONFIDENTIALITY_PERPETUAL", "YELLOW"),
        ("SERVICE", "Ijrochi ushbu shartnoma bo'yicha yaratilgan barcha intellektual mulk huquqlarini bepul topshiradi.", "IP_FUTURE_WORKS_ASSIGNMENT", "YELLOW"),
        ("SERVICE", "Muallif kelgusida yaratadigan barcha intellektual mulk huquqlarini bepul topshiradi.", "IP_FUTURE_WORKS_ASSIGNMENT", "RED"),
        ("SERVICE", "Qarzdor o'z qarzini kreditor roziligisiz uchinchi shaxsga o'tkazishi mumkin.", "DEBT_TRANSFER_NO_CONSENT", "RED"),
        ("SALE", "Xaridor nuqsonli tovarni almashtirish huquqidan voz kechadi.", "CONSUMER_RIGHTS_WAIVER", "RED"),
        ("SERVICE", "Nizolar London xalqaro tijorat arbitrajida hal qilinadi.", "FOREIGN_LAW_JURISDICTION", "YELLOW"),
        ("SERVICE", "Ijrochi ish vaqti jadvaliga va ichki mehnat tartibiga bo'ysunadi, pudrat shartnomasi doirasida.", "DISGUISED_EMPLOYMENT", "RED"),
    ]

    NEGATIVE = [
        ("SERVICE", "Ijrochi xizmat ko'rsatadi."),
        ("SERVICE", "Taraflardan har biri 15 kun oldin yozma ogohlantirib shartnomani bekor qilishi mumkin; xarajatlar qoplanadi."),
        ("SERVICE", "Kechiktirilgan har bir kun uchun 0,1% penya, umumiy summa 10% dan oshmaydi."),
        ("SERVICE", "Buyurtmachi istalgan vaqtda hisobot talab qilishi mumkin."),
        ("SERVICE", "Fors-major holatlarida Taraflar javobgar bo'lmaydi."),
        ("SALE", "Ko'chmas mulk oldi-sotdi shartnomasi notarial tasdiqlanadi va davlat ro'yxatidan o'tkaziladi."),
        ("EMPLOYMENT", "Xodimga 3 oy sinov muddati belgilanadi."),
        ("SERVICE", "To'lov shartnoma imzolangandan keyin 5 bank kuni ichida amalga oshiriladi."),
    ]

    def test_positive_cases(self):
        for doc, text, rule, risk in self.POSITIVE:
            with self.subTest(text=text):
                rep = run(text, doc)
                self.assertIn(rule, codes(rep), f"{rule} topilmadi: {codes(rep)}")
                finding = next(f for f in rep.findings if f.rule_code == rule)
                self.assertEqual(finding.risk_level, risk)

    def test_negative_cases_have_no_findings(self):
        for doc, text in self.NEGATIVE:
            with self.subTest(text=text):
                self.assertEqual(codes(run(text, doc)), [], text)

    def test_problematic_quote_is_exact_substring_of_clause(self):
        """Backend 'substring grounding' (3-vektor) uchun iqtibos asl matndan aynan ko'chirilishi shart."""
        for doc, text, _, _ in self.POSITIVE:
            rep = run(text, doc)
            for f in rep.findings:
                self.assertIn(f.problematic_quote, text, f"{f.rule_code}: iqtibos substring emas")

    def test_quote_picks_the_risky_sentence_not_whole_clause(self):
        text = "1.1. Ijrochi xizmat ko'rsatadi. Buyurtmachi istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin. 1.2. To'lov 5 kunda."
        rep = run(text)
        f = rep.findings[0]
        self.assertIn("bir tomonlama bekor", f.problematic_quote)
        self.assertNotIn("To'lov 5 kunda", f.problematic_quote)

    def test_findings_sorted_by_severity(self):
        rep = run("Buyurtmachi istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin. Har bir kun uchun 1% penya to'lanadi.")
        levels = [f.risk_level for f in rep.findings]
        self.assertEqual(levels, sorted(levels, key=lambda x: {"RED": 0, "YELLOW": 1}[x]))
        self.assertEqual(rep.findings[0].risk_level, "RED")

    def test_finding_is_enriched_with_chain_and_official_url(self):
        f = run("Buyurtmachi istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin.").findings[0]
        self.assertIn("707", f.cited_article)
        self.assertIn("lex.uz", f.lex_uz_url)
        self.assertGreaterEqual(len(f.multi_hop_chain), 2)
        self.assertIn("xarajat", f.suggested_redline.lower())
        self.assertNotIn("full_text", f.multi_hop_chain[0])


class TestNormalizationVariants(unittest.TestCase):
    def test_apostrophe_variants_trigger_same_rule(self):
        for apos in ("'", "ʻ", "’", "‘", "`"):
            text = f"Buyurtmachi istalgan vaqtda to{apos}lovsiz bir tomonlama bekor qilishi mumkin."
            self.assertEqual(codes(run(text)), ["TERM_UNILATERAL_SERVICE"], f"apostrof {apos!r}")

    def test_cyrillic_text_is_analyzed(self):
        rep = run("Шартномани истаган вақтда бир томонлама бекор қилиш мумкин.")
        self.assertEqual(codes(rep), ["TERM_UNILATERAL_SERVICE"])
        self.assertIn("бир томонлама", rep.findings[0].problematic_quote)  # asl (kirill) matn saqlanadi

    def test_normalize_text(self):
        self.assertEqual(normalize_text("Кўчмас мулк"), "kochmas mulk")
        self.assertEqual(normalize_text("Koʻchmas   Mulk"), "kochmas mulk")

    def test_split_sentences_returns_exact_substrings(self):
        text = "1.1. Birinchi gap. Ikkinchi gap; uchinchi.\n1.2. To'rtinchi gap!"
        parts = split_sentences(text)
        self.assertGreaterEqual(len(parts), 3)
        for p in parts:
            self.assertIn(p, text)


class TestDocTypeAndParty(unittest.TestCase):
    TEXT = "Buyurtmachi istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin."

    def test_707_only_for_service_contracts(self):
        self.assertIn("TERM_UNILATERAL_SERVICE", codes(run(self.TEXT, "SERVICE")))
        sale = run(self.TEXT, "SALE")
        self.assertNotIn("TERM_UNILATERAL_SERVICE", codes(sale))
        self.assertIn("TERM_UNILATERAL_GENERAL", codes(sale))
        self.assertIn("237", sale.findings[0].cited_article)

    def test_general_unilateral_is_yellow_not_red(self):
        self.assertEqual(run(self.TEXT, "SALE").findings[0].risk_level, "YELLOW")

    def test_lease_uses_lease_specific_redline(self):
        f = run(self.TEXT, "LEASE").findings[0]
        self.assertIn("540", f.suggested_redline)

    def test_balance_label_names_burdened_party(self):
        f = run(self.TEXT, "SERVICE").findings[0]
        self.assertEqual(f.balance_label, "Ijrochiga og'ir")
        f = run("Ijrochi istalgan vaqtda to'lovsiz bir tomonlama bekor qilishi mumkin.", "SERVICE").findings[0]
        self.assertEqual(f.balance_label, "Buyurtmachiga og'ir")

    def test_balance_label_marks_users_side(self):
        f = run(self.TEXT, "SERVICE", party_role="EXECUTOR").findings[0]
        self.assertIn("sizning tomoningizga", f.balance_label)
        f = run(self.TEXT, "SERVICE", party_role="CUSTOMER").findings[0]
        self.assertNotIn("sizning tomoningizga", f.balance_label)

    def test_employment_probation_only_for_employment(self):
        self.assertEqual(codes(run("Xodimga 6 oy sinov muddati belgilanadi.", "SERVICE")), [])

    def test_manager_probation_limit_is_six_months(self):
        self.assertEqual(codes(run("Tashkilot rahbariga 6 oy sinov muddati belgilanadi.", "EMPLOYMENT")), [])

    def test_unknown_doc_type_is_general(self):
        self.assertIn("TERM_UNILATERAL_GENERAL", codes(run(self.TEXT, "nomalum")))

    def test_any_doc_type_collapses_general_variant_into_specific_one(self):
        """Tur noma'lum (chat) bo'lganda bitta band uchun 707 (RED) va 237 (YELLOW) takrorlanmaydi."""
        rep = run(self.TEXT, "ANY")
        self.assertEqual(codes(rep), ["TERM_UNILATERAL_SERVICE"])
        self.assertIn("707", rep.findings[0].cited_article)

    def test_any_doc_type_still_finds_rules_of_every_type(self):
        self.assertIn("FORM_REALESTATE_WRONG_FORM", codes(run("Ko'chmas mulk oldi-sotdi shartnomasi oddiy yozma shaklda tuziladi.", "ANY")))
        self.assertIn("EMP_PROBATION_EXCESS", codes(run("Xodimga 6 oy sinov muddati belgilanadi.", "ANY")))

    def test_collapse_can_be_disabled(self):
        rep = analyzer.analyze_clause(ClauseIn("c", "1", self.TEXT), "ANY", use_llm=False, collapse_variants=False)
        self.assertEqual(set(codes(rep)), {"TERM_UNILATERAL_SERVICE", "TERM_UNILATERAL_GENERAL"})

    def test_supersedes_targets_exist(self):
        from app.rules import RULES_BY_CODE
        for r in RULES:
            for target in r.supersedes:
                self.assertIn(target, RULES_BY_CODE, f"{r.code} -> {target}")


class TestPenaltyNumbers(unittest.TestCase):
    def test_daily_rate_above_statutory_is_flagged_with_detail(self):
        f = run("Har bir kechikkan kun uchun 2% penya to'lanadi.").findings[0]
        self.assertIn("0,5%", f.issue_explanation)
        self.assertIn("670-I", f.issue_explanation)

    def test_daily_rate_within_statutory_and_capped_is_ok(self):
        self.assertEqual(codes(run("Har bir kechikkan kun uchun 0,5% penya to'lanadi, umumiy summa 50% dan oshmaydi.")), [])

    def test_daily_rate_within_statutory_without_cap_is_flagged(self):
        self.assertEqual(codes(run("Har bir kechikkan kun uchun 0,3% penya to'lanadi.")), ["PENALTY_DISPROPORTIONATE"])


class TestRelatedNorms(unittest.TestCase):
    def test_bm25_is_not_reported_as_violation(self):
        rep = run("Ijrochi hisobotni har oyning oxirigacha topshiradi.")
        self.assertEqual(rep.findings, [])
        self.assertEqual(rep.status, "NO_RULE_MATCH")

    def test_related_norms_returned_for_penalty_clause(self):
        rep = run("Kechiktirilgan har bir kun uchun 0,1% penya, umumiy summa 10% dan oshmaydi.")
        self.assertEqual(rep.status, "NO_RULE_MATCH")
        self.assertTrue(any("670-I" in n["code"] for n in rep.related_norms), rep.related_norms)


class TestFindNodeId(unittest.TestCase):
    def test_exact_numbers_only(self):
        self.assertEqual(legal_graph.find_node_id("FK-UZ-2_707"), "FK-UZ-2_707")
        self.assertEqual(legal_graph.find_node_id("FK 707"), "FK-UZ-2_707")
        self.assertEqual(legal_graph.find_node_id("707-modda"), "FK-UZ-2_707")
        self.assertEqual(legal_graph.find_node_id("FK-UZ-2 707-modda"), "FK-UZ-2_707")
        self.assertEqual(legal_graph.find_node_id("MK 130"), "MK-2022_130")
        self.assertEqual(legal_graph.find_node_id("ORQ-547_15"), "ORQ-547_15")

    def test_short_number_does_not_match_longer_article(self):
        """Eski xato: "7-modda" in "107-modda" -> noto'g'ri modda."""
        nid = legal_graph.find_node_id("7-modda")
        self.assertIn(nid, (None, "FK-UZ-1_7"))
        self.assertNotEqual(nid, "FK-UZ-1_107")

    def test_garbage_returns_none(self):
        self.assertIsNone(legal_graph.find_node_id("abrakadabra"))
        self.assertIsNone(legal_graph.find_node_id(""))
        self.assertIsNone(legal_graph.find_node_id("FK 99999"))

    def test_chain_has_relations_and_is_bounded(self):
        res = legal_graph.resolve_chain("FK-UZ-2_707")
        self.assertLessEqual(len(res["chain"]), 8)
        self.assertEqual(res["chain"][0]["relation"], "root")
        self.assertTrue(all("full_text" not in n for n in res["chain"]))


class TestSelfCorrect(unittest.TestCase):
    CLAUSE = "Buyurtmachi shartnomani istalgan paytda bir tomonlama bekor qiladi"

    def test_rejected_article_is_excluded(self):
        f = analyzer.self_correct(self.CLAUSE, previous_cited="FK 707", candidates=["FK-UZ-2_707", "FK-UZ-1_354"])
        self.assertIsNotNone(f)
        self.assertNotIn("707", f.cited_article)

    def test_candidate_intersecting_rule_is_preferred(self):
        f = analyzer.self_correct(self.CLAUSE, previous_cited="FK 100", candidates=["FK-UZ-2_707", "FK-UZ-1_354"])
        self.assertIn("707", f.cited_article)

    def test_irrelevant_candidates_do_not_blindly_win(self):
        """Eski xatti-harakat: istalgan mavjud nomzod ko'r-ko'rona qabul qilinardi."""
        f = analyzer.self_correct(self.CLAUSE, previous_cited="FK 100", candidates=["MK-2022_130"])
        self.assertIn("707", f.cited_article)

    def test_candidate_chosen_by_lexical_relevance_when_no_rule(self):
        f = analyzer.self_correct(
            "Sotuvchi tovar haqini oldindan to'lashni talab qiladi", previous_cited="FK 1",
            candidates=["MK-2022_130", "FK-UZ-2_420"],
        )
        self.assertIsNotNone(f)
        self.assertIn("420", f.cited_article)

    def test_unresolvable_returns_none(self):
        self.assertIsNone(analyzer.self_correct("qwxz plmk vbnt", candidates=[]))


class TestRetrievalQuality(unittest.TestCase):
    GOLD = [
        ("Majburiyatni bajarishdan bir tomonlama bosh tortish va shartnoma shartlarini o'zgartirish", "FK-UZ-1_237"),
        ("Neustoykani kamaytirish nomutanosib neustoyka", "FK-UZ-1_326"),
        ("Shaxsga doir ma'lumotlarni chet elga uzatish", "ORQ-547_15"),
        ("dastlabki sinov muddati uch oydan oshmasligi", "MK-2022_130"),
        ("Ko'chmas mulkni sotish shartnomasining shakli", "FK-UZ-2_480"),
        ("tovar haqini oldindan to'lash", "FK-UZ-2_420"),
        ("xizmat ko'rsatish shartnomasini bekor qilish", "FK-UZ-2_707"),
        ("iste'molchi huquqlarini cheklab qo'yadigan shartlar haqiqiy emas", "221-I_21"),
        ("xizmat va tijorat siri himoyasi", "FK-UZ-1_98"),
        ("qarzni boshqa shaxsga o'tkazish kreditor roziligi", "FK-UZ-1_322"),
        ("buyurtmachining bajarilgan ishlarni qabul qilishi", "FK-UZ-2_646"),
        ("ish haqini to'lash muddatlari", "MK-2022_253"),
        ("javobgarlik hajmini cheklash", "FK-UZ-1_332"),
        ("kvartirani sotish shartnomasi notarial tasdiqlanishi", "FK-UZ-2_488"),
    ]

    def test_hit_at_5(self):
        hits = 0
        for q, expected in self.GOLD:
            ids = [h["id"] for h in legal_vector_store.search(q, top_k=5)]
            hits += expected in ids
        self.assertGreaterEqual(hits / len(self.GOLD), 0.9, f"hit@5 = {hits}/{len(self.GOLD)}")

    def test_apostrophe_variants_give_same_results(self):
        a = [h["id"] for h in legal_vector_store.search("ko'chmas mulk oldi-sotdisi", top_k=5)]
        b = [h["id"] for h in legal_vector_store.search("koʻchmas mulk oldi-sotdisi", top_k=5)]
        self.assertEqual(a, b)


if __name__ == "__main__":
    unittest.main()
