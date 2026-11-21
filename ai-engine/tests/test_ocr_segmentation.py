"""
LexGuard AI — OCR bandlarga ajratish (segment_clauses) regressiya testlari.
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.ocr import ocr_processor


def numbers(text):
    return [c["clause_number"] for c in ocr_processor.segment_clauses(text)]


class TestClauseSegmentation(unittest.TestCase):
    def test_long_numbered_clause_is_its_own_clause(self):
        """Eski xato: 120+ belgili "1.1. ..." qatori oldingi bandga qo'shilib ketardi."""
        long_line = "1.1. " + "Ijrochi Buyurtmachiga dasturiy ta'minotni ishlab chiqish xizmatlarini ko'rsatadi. " * 3
        clauses = ocr_processor.segment_clauses(f"1. SHARTNOMA PREDMETI\n{long_line}\n1.2. Ikkinchi band matni shu yerda.")
        self.assertEqual([c["clause_number"] for c in clauses], ["1.", "1.1.", "1.2."])
        self.assertTrue(clauses[1]["text"].startswith("1.1."))

    def test_date_line_is_not_a_clause_header(self):
        clauses = ocr_processor.segment_clauses("15.03.2026 y. Toshkent sh.\n1.1. Birinchi band matni shu yerda yoziladi.")
        self.assertEqual([c["clause_number"] for c in clauses], ["KIRISH", "1.1."])

    def test_money_amount_is_not_a_clause_header(self):
        clauses = ocr_processor.segment_clauses("1.1. Birinchi band matni shu yerda.\n100.000 so'm to'lanadi.\n1.2. Ikkinchi band matni.")
        self.assertEqual([c["clause_number"] for c in clauses], ["1.1.", "1.2."])
        self.assertIn("100.000", clauses[0]["text"])

    def test_modda_header_with_trailing_dot(self):
        self.assertEqual(numbers("1. Kirish qismi matni shu yerda.\n3-modda. Javobgarlik\nPenya to'lanadi va hokazo."), ["1.", "3-modda."])

    def test_list_items_stay_inside_their_clause(self):
        clauses = ocr_processor.segment_clauses("2.1. Buyurtmachi quyidagilarni bajaradi:\n1) birinchi vazifa;\n2) ikkinchi vazifa.")
        self.assertEqual(len(clauses), 1)
        self.assertIn("2) ikkinchi vazifa", clauses[0]["text"])

    def test_paren_numbering_is_used_when_it_is_the_only_numbering(self):
        clauses = ocr_processor.segment_clauses("Shartnoma\n1) Ijrochi xizmat ko'rsatadi va davom etadi.\n2) Buyurtmachi to'laydi va davom etadi.")
        self.assertEqual([c["clause_number"] for c in clauses], ["1)", "2)"])

    def test_plain_text_falls_back_to_paragraphs(self):
        text = ("Birinchi xatboshi matni " * 5) + "\n\n" + ("Ikkinchi xatboshi matni " * 5)
        self.assertEqual(len(ocr_processor.segment_clauses(text)), 2)

    def test_empty_text(self):
        self.assertEqual(ocr_processor.segment_clauses(""), [])


if __name__ == "__main__":
    unittest.main()
