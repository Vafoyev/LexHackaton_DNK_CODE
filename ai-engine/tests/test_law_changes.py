"""
LexGuard AI — O'zgargan normalar tasmasi testlari (korpusdagi Lex.uz tahrir izohlaridan).
"""

import os
import re
import sys
import unittest
from datetime import date

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from fastapi.testclient import TestClient

from app import law_changes as lc
from app.knowledge_graph import legal_graph
from app.main import app
from app.rules import RULES

NOTE = ("(2-moddaning beshinchi qismi Oʻzbekiston Respublikasining 2025-yil 23-iyundagi OʻRQ-1070-sonli Qonuni tahririda — "
        "Qonunchilik maʼlumotlari milliy bazasi, 24.06.2025-y., 03/25/1070/0536-son. Kuchga kirish sanasi — 2025-yil 25-sentabr)")


class TestParseNotes(unittest.TestCase):
    def test_full_note(self):
        a = lc.parse_notes("Matn. " + NOTE)[0]
        self.assertEqual(a.changed_on, date(2025, 6, 23))
        self.assertEqual(a.amended_by, "OʻRQ-1070")
        self.assertEqual(a.amended_by_kind, "Qonun")
        self.assertEqual(a.effective_from, date(2025, 9, 25))
        self.assertEqual(a.part, "2-moddaning beshinchi qismi")

    def test_law_number_with_space(self):
        a = lc.parse_notes("(423-moddaning birinchi qismi Oʻzbekiston Respublikasining 2026-yil 22-iyundagi OʻRQ 1154-sonli Qonuni tahririda — baza, 23.06.2026-y.)")[0]
        self.assertEqual(a.amended_by, "OʻRQ-1154")
        self.assertEqual(a.changed_on, date(2026, 6, 22))

    def test_old_style_law_number(self):
        a = lc.parse_notes("(490-moddaning birinchi qismi Oʻzbekiston Respublikasi 1999-yil 20-avgustdagi 832-I-sonli Qonuni tahririda — Oliy Majlis Axborotnomasi)")[0]
        self.assertEqual(a.amended_by, "832-I")
        self.assertEqual(a.changed_on, date(1999, 8, 20))

    def test_constitutional_law_kind(self):
        a = lc.parse_notes("(3-moddaning uchinchi qismi Oʻzbekiston Respublikasining 2026-yil 13-iyuldagi OʻRQ-1158-sonli Konstitutsiyaviy Qonuni tahririda — baza)")[0]
        self.assertEqual(a.amended_by_kind, "Konstitutsiyaviy qonun")

    def test_truncated_part_is_dropped(self):
        a = lc.parse_notes("(398-moddaning Oʻzbekiston Respublikasining 2026-yil 11-iyundagi OʻRQ-1150-sonli Qonuni tahririda — baza)")[0]
        self.assertEqual(a.part, "")

    def test_abbreviated_month_is_understood(self):
        # korpusda "25-sentab" kabi qisqartirish uchraydi
        a = lc.parse_notes(NOTE.replace("25-sentabr", "25-sentab"))[0]
        self.assertEqual(a.effective_from, date(2025, 9, 25))

    def test_no_notes(self):
        self.assertEqual(lc.parse_notes("Oddiy modda matni."), [])
        self.assertEqual(lc.parse_notes(""), [])

    def test_unparsable_date_is_skipped_not_guessed(self):
        self.assertEqual(lc.parse_notes("(1-modda Oʻzbekiston Respublikasining OʻRQ-1-sonli Qonuni tahririda — baza)"), [])

    def test_invalid_calendar_date_is_skipped(self):
        self.assertEqual(lc.parse_notes("(1-modda Oʻzbekiston Respublikasining 2025-yil 31-fevraldagi OʻRQ-1-sonli Qonuni tahririda — baza)"), [])

    def test_corpus_coverage(self):
        """Korpusdagi tahrir izohlarining deyarli hammasi tahlil qilinadi (eski 27 ta yaroqsiz shakl tuzatilgan)."""
        total = failed = 0
        for n in legal_graph.nodes.values():
            if re.search(r"sonli[^()]*tahririda", n["full_text"]):
                total += 1
                failed += not lc.parse_notes(n["full_text"])
        self.assertGreater(total, 500)
        self.assertLessEqual(failed / total, 0.01, f"{failed}/{total} izoh tahlil qilinmadi")


class TestFeed(unittest.TestCase):
    def test_sorted_newest_first_and_unique_articles(self):
        items = lc.list_changes(limit=100)["items"]
        dates = [i["changed_on"] for i in items]
        self.assertEqual(dates, sorted(dates, reverse=True))
        ids = [i["id"] for i in items]
        self.assertEqual(len(ids), len(set(ids)))

    def test_items_reference_real_articles_with_lex_links(self):
        for i in lc.list_changes(limit=50)["items"]:
            self.assertIn(i["id"], legal_graph.nodes)
            self.assertIn("lex.uz", i["url"])
            self.assertTrue(i["amended_by"])
            self.assertNotIn("OKOZ", i["snippet"])

    def test_snapshot_is_the_latest_change(self):
        r = lc.list_changes(limit=1)
        self.assertEqual(r["snapshot_latest"], r["items"][0]["changed_on"])

    def test_source_filter(self):
        items = lc.list_changes(limit=20, source="mk-2022")["items"]
        self.assertTrue(items)
        self.assertTrue(all(i["source_code"] == "MK-2022" for i in items))

    def test_since_filter(self):
        r = lc.list_changes(limit=100, since=date(2026, 1, 1))
        self.assertTrue(r["items"])
        self.assertTrue(all(i["changed_on"] >= "2026-01-01" for i in r["items"]))

    def test_limit_is_bounded(self):
        self.assertLessEqual(len(lc.list_changes(limit=10_000)["items"]), 100)
        self.assertEqual(len(lc.list_changes(limit=0)["items"]), 1)

    def test_used_in_analysis_matches_rule_articles(self):
        used_ids = set()
        for r in RULES:
            used_ids.add(r.root)
            used_ids.update(r.related)
        for i in lc.list_changes(limit=100)["items"]:
            self.assertEqual(i["used_in_analysis"], i["id"] in used_ids)

    def test_only_used_filter(self):
        r = lc.list_changes(limit=100, only_used=True)
        self.assertTrue(r["items"])
        self.assertTrue(all(i["used_in_analysis"] for i in r["items"]))
        self.assertEqual(r["affecting_analysis"], r["total_changed_articles"])

    def test_laws_groups(self):
        r = lc.list_changes(limit=5)
        self.assertTrue(r["laws"])
        self.assertEqual(r["laws"][0]["changed_on"], r["snapshot_latest"])
        self.assertGreaterEqual(r["laws"][0]["articles_count"], 1)

    def test_honest_source_note(self):
        self.assertIn("jonli yangilanish emas", lc.list_changes()["source_note"])


class TestEndpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)

    def test_endpoint(self):
        r = self.client.get("/api/v1/law-changes", params={"limit": 3})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(len(r.json()["items"]), 3)

    def test_bad_since_rejected(self):
        self.assertEqual(self.client.get("/api/v1/law-changes", params={"since": "kecha"}).status_code, 422)

    def test_bad_limit_rejected(self):
        self.assertEqual(self.client.get("/api/v1/law-changes", params={"limit": 0}).status_code, 422)
        self.assertEqual(self.client.get("/api/v1/law-changes", params={"limit": 101}).status_code, 422)

    def test_source_is_validated(self):
        self.assertEqual(self.client.get("/api/v1/law-changes", params={"source": "x;drop"}).status_code, 422)


if __name__ == "__main__":
    unittest.main()
