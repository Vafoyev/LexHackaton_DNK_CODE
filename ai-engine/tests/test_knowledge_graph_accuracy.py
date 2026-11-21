"""
LexGuard AI — Legal Knowledge Graph & Active Self-Correction Accuracy Tests
Test qamrovi:
1. 2,058 ta qonun moddasining to'liq yuklanganligi va 0% soxta modda qoidasi.
2. Multi-hop qonun zanjiri (FK 707 -> FK 354 & FK 324; FK 326 -> 670-I 25-modda).
3. Active Self-Correction sikli: soxta/noto'g'ri modda kiritilganda haqiqiy qonuniy asosga tuzatish.
4. Lex.uz rasmiy URL strukturasining to'g'riligi.
"""

import unittest
import os
import sys

# ai-engine papkasini path ga qo'shish
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.knowledge_graph import legal_graph
from app.vector_store import legal_vector_store


class TestKnowledgeGraphAccuracy(unittest.TestCase):

    def test_knowledge_graph_node_count(self):
        """Knowledge Graph kamida 2,000 ta haqiqiy Lex.uz moddalarini o'z ichiga oladi"""
        self.assertGreaterEqual(len(legal_graph.nodes), 2000, f"Moddalar soni kam: {len(legal_graph.nodes)}")
        total_edges = sum(len(e) for e in legal_graph.edges.values())
        self.assertGreaterEqual(total_edges, 2000, "Bog'lanishlar soni kam")

    def test_zero_fake_articles_allowlist(self):
        """Barcha tugunlar rasmiy 10 ta O'zbekiston qonunlariga tegishli (soxta moddalar 0%)"""
        allowed_sources = {
            "FK-UZ-1", "FK-UZ-2", "MK-2022", "670-I", "221-I",
            "ORQ-547", "ORQ-482", "ORQ-792", "ORQ-850", "ORQ-684"
        }

        fake_articles = []
        for node_id, data in legal_graph.nodes.items():
            src = data.get("source_code")
            if src not in allowed_sources:
                fake_articles.append(node_id)
            
            # Har bir moddada rasmiy Lex.uz havolasi bo'lishi shart
            url = data.get("url", "")
            self.assertIn("lex.uz", url, f"Modda {node_id} da rasmiy lex.uz havolasi yo'q: {url}")

        self.assertEqual(len(fake_articles), 0, f"Soxta moddalar topildi: {fake_articles}")

    def test_multi_hop_chain_fk707(self):
        """FK 707 (Xizmatni bir tomonlama bekor qilish) multi-hop zanjirini tekshirish"""
        chain_res = legal_graph.resolve_chain("FK-UZ-2_707")
        self.assertTrue(chain_res["found"])
        self.assertIn("707", chain_res["root_article"])
        self.assertIn("lex.uz", chain_res["url"])
        self.assertGreaterEqual(len(chain_res["chain"]), 2, "FK 707 bog'langan normalari topilmadi")

        # Zanjirda FK 354 yoki FK 324 mavjudligi
        chain_codes = [c.get("code", "") for c in chain_res["chain"]]
        has_related = any("354" in c or "324" in c for c in chain_codes)
        self.assertTrue(has_related, f"FK 707 zanjirida FK 354/324 yo'q: {chain_codes}")

    def test_multi_hop_chain_fk326(self):
        """FK 326 (Neustoykani kamaytirish) -> 670-I (Penya 50% chegarasi) zanjirini tekshirish"""
        chain_res = legal_graph.resolve_chain("FK-UZ-1_326")
        self.assertTrue(chain_res["found"])
        self.assertIn("326", chain_res["root_article"])
        
        chain_codes = [c.get("code", "") for c in chain_res["chain"]]
        has_670 = any("670-I" in c for c in chain_codes)
        self.assertTrue(has_670, f"FK 326 zanjirida 670-I qonuni yo'q: {chain_codes}")

    def test_active_self_correction_accuracy(self):
        """Active Self-Correction tekshiruvi: Shartnoma xavfli bandini to'g'ri moddaga yo'naltirish"""
        # 1. Bekor qilish bandi
        eval_unilateral = legal_graph.evaluate_clause_text(
            "Buyurtmachi Ijrochini ogohlantirmasdan va to'lovsiz shartnomani bekor qilishi mumkin."
        )
        self.assertIsNotNone(eval_unilateral)
        self.assertTrue(eval_unilateral["found"])
        self.assertEqual(eval_unilateral["risk_level"], "RED")
        self.assertIn("707", eval_unilateral["root_article"])

        # 2. Penya bandi
        eval_penalty = legal_graph.evaluate_clause_text(
            "Kechiktirilgan har bir kun uchun 1% miqdorida penya to'lanadi."
        )
        self.assertIsNotNone(eval_penalty)
        self.assertTrue(eval_penalty["found"])
        self.assertEqual(eval_penalty["risk_level"], "YELLOW")
        self.assertIn("326", eval_penalty["root_article"])

        # 3. Notarial shakl bandi
        eval_notary = legal_graph.evaluate_clause_text(
            "Ko'chmas mulk oldi-sotdi shartnomasi oddiy yozma shaklda tuziladi."
        )
        self.assertIsNotNone(eval_notary)
        self.assertTrue(eval_notary["found"])
        self.assertEqual(eval_notary["risk_level"], "RED")
        self.assertIn("110", eval_notary["root_article"])


if __name__ == "__main__":
    unittest.main()
