"""
LexGuard AI — Legal Knowledge Graph (O'zbekiston Qonunlari Zanjirli Bog'lanish Tizimi)
Muallif: AI & Legal Engineering Group
Vazifasi: Lex.uz dan yuklab olingan 2,058 ta modda va ulardagi o'zaro murakkab havolalarni
(cross-references: A -> B -> C) yechish hamda AI ga butun zanjir bo'yicha to'g'ri,
100% qonuniy xulosani yetkazish.
"""

import os
import re
import json
from typing import Dict, List, Optional, Any
from collections import defaultdict

from app.config import CORPUS_PATH

# "FK 707", "FK-UZ 707", "MK 130" kabi qisqa havolalar uchun qonun -> manba kodlari
_LAW_ALIASES = {
    "fk": ("FK-UZ-1", "FK-UZ-2"),
    "fkuz": ("FK-UZ-1", "FK-UZ-2"),
    "mk": ("MK-2022",),
    "mk2022": ("MK-2022",),
    "670i": ("670-I",),
    "221i": ("221-I",),
    "orq547": ("ORQ-547",), "orq482": ("ORQ-482",), "orq792": ("ORQ-792",),
    "orq850": ("ORQ-850",), "orq684": ("ORQ-684",),
}
_CURATED_RELATIONS_EXCLUDE = {"internal_reference", "civil_code_cross_part"}


class LegalKnowledgeGraph:
    def __init__(self, corpus_path: str = str(CORPUS_PATH)):
        self.corpus_path = corpus_path
        self.nodes: Dict[str, Dict[str, Any]] = {}
        self.edges: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
        
        # 1. Birlamchi qonuniy korpusni yuklash (2,058 modda)
        self._load_corpus()
        
        # 2. Asosiy shartnomaviy imperativ normalar va ekspert qoidalarini mustahkamlash
        self._enhance_expert_contract_rules()

    def add_node(self, node_id: str, **attrs):
        self.nodes[node_id] = attrs

    def add_edge(self, from_node: str, to_node: str, **attrs):
        # Takroriy edge qo'shmaslik
        for e in self.edges[from_node]:
            if e["target"] == to_node:
                return
        self.edges[from_node].append({"target": to_node, **attrs})

    def _load_corpus(self):
        if not os.path.exists(self.corpus_path):
            print(f"[KnowledgeGraph] ⚠️ Korpus fayli topilmadi: {self.corpus_path}")
            return

        try:
            with open(self.corpus_path, "r", encoding="utf-8") as f:
                articles = json.load(f)

            print(f"[KnowledgeGraph] {len(articles)} ta qonun moddasi yuklanmoqda...")
            for art in articles:
                node_id = art["id"]
                art_num = art["article_number"]
                source_code = art["source_code"]
                
                self.add_node(
                    node_id,
                    id=node_id,
                    code=f"{source_code} {art_num}",
                    article_number=art_num,
                    title=art.get("title", ""),
                    source_code=source_code,
                    law=self._get_law_full_name(source_code),
                    url=art.get("official_url", ""),
                    summary=art.get("full_text", "")[:350],
                    full_text=art.get("full_text", ""),
                    is_imperative="shart" in art.get("full_text", "").lower() or "majbur" in art.get("full_text", "").lower() or "taqiqlanadi" in art.get("full_text", "").lower(),
                    cross_references=art.get("cross_references", [])
                )

            # Havolalar (Cross-References) bo'yicha Graph Edge larini qurish
            edge_count = 0
            for art in articles:
                src_id = art["id"]
                src_code = art["source_code"]
                for ref in art.get("cross_references", []):
                    ref_num = re.sub(r'[^\d]', '', ref)
                    if not ref_num:
                        continue
                    # Ayni qonun ichidagi boshqa moddani qidirish
                    target_id = f"{src_code}_{ref_num}"
                    if target_id in self.nodes and target_id != src_id:
                        self.add_edge(src_id, target_id, relation="internal_reference", note=f"{art['article_number']} matnida {ref}ga havola mavjud")
                        edge_count += 1
                    
                    # Agar FK bo'lsa (FK-UZ-1 yoki FK-UZ-2 o'rtasidagi o'zaro bog'lanish)
                    if "FK" in src_code:
                        alt_target = f"FK-UZ-2_{ref_num}" if src_code == "FK-UZ-1" else f"FK-UZ-1_{ref_num}"
                        if alt_target in self.nodes and alt_target != src_id:
                            self.add_edge(src_id, alt_target, relation="civil_code_cross_part", note=f"Fuqarolik kodeksining boshqa qismidagi {ref}ga havola")
                            edge_count += 1

            print(f"[KnowledgeGraph] Graf tayyor: {len(self.nodes)} tugunlar, {edge_count} ta avtomatik bog'lanishlar!")
        except Exception as e:
            print(f"[KnowledgeGraph] ⚠️ Korpusni o'qishda xatolik: {e}")

    def _get_law_full_name(self, source_code: str) -> str:
        mapping = {
            "FK-UZ-1": "O'zbekiston Respublikasi Fuqarolik Kodeksi (1-qism)",
            "FK-UZ-2": "O'zbekiston Respublikasi Fuqarolik Kodeksi (2-qism)",
            "MK-2022": "O'zbekiston Respublikasining Mehnat Kodeksi",
            "670-I": "Xo'jalik yurituvchi subyektlar faoliyatining shartnomaviy-huquqiy bazasi to'g'risida Qonun",
            "221-I": "Iste'molchilarning huquqlarini himoya qilish to'g'risida Qonun",
            "ORQ-547": "Shaxsga doir ma'lumotlar to'g'risida Qonun",
            "ORQ-482": "Mediatsiya to'g'risida Qonun",
            "ORQ-792": "Elektron tijorat to'g'risida Qonun",
            "ORQ-850": "Raqobat to'g'risida Qonun",
            "ORQ-684": "Davlat xaridlari to'g'risida Qonun"
        }
        return mapping.get(source_code, source_code)

    def _enhance_expert_contract_rules(self):
        """
        Shartnomalarda eng ko'p uchraydigan tuzoq va xavflar bo'yicha ekspert remedylari va zanjirlari.
        """
        # FK 707 (Xizmat shartnomasidan bir tomonlama voz kechish)
        node_707 = "FK-UZ-2_707"
        if node_707 in self.nodes:
            self.nodes[node_707]["remedy_clause"] = "Buyurtmachi shartnomani bekor qilishdan kamida 15 (o'n besh) kun oldin Ijrochini yozma xabardor qiladi hamda Ijrochi tomonidan amalda ko'rsatilgan xizmatlar haqini va asoslangan haqiqiy xarajatlarini to'liq qoplaydi."
            self.nodes[node_707]["is_imperative"] = True
            self.nodes[node_707]["risk_category"] = "LEGAL"

            # Shartnoma erkinligi chegaralari (FK 354) va zararni to'lash (FK 324) ga qo'lda mustahkam zanjir
            if "FK-UZ-1_354" in self.nodes:
                self.add_edge(node_707, "FK-UZ-1_354", relation="governed_by_freedom_limits",
                    note="Shartnomada bir tomonlama bekor qilish kiritilishi mumkin, lekin FK 354 talabiga ko'ra bu FK 707 ning majburiy xarajat qoplash qoidasini bekor qila olmaydi.")
            if "FK-UZ-1_324" in self.nodes:
                self.add_edge(node_707, "FK-UZ-1_324", relation="requires_damages_compensation",
                    note="Agar bir tomonlama bekor qilish oqibatida zarar yuzaga kelsa, xarajatlar va haqiqiy zarar qoplanishi shart.")

        # FK 326 (Neustoykani kamaytirish)
        node_326 = "FK-UZ-1_326"
        if node_326 in self.nodes:
            self.nodes[node_326]["remedy_clause"] = "Majburiyat buzilgan har bir kechiktirilgan kun uchun bajarilmagan qism summasining 0.1% miqdorida, lekin umumiy shartnoma qiymatining 10% idan oshmagan miqdorda penya to'lanadi."
            self.nodes[node_326]["is_imperative"] = True
            self.nodes[node_326]["risk_category"] = "COMMERCIAL"

            # 670-I Qonun 25-moddasi (Penyaning maksimal chegarasi: 50%)
            if "670-I_25" in self.nodes:
                self.add_edge(node_326, "670-I_25", relation="statutory_penalty_cap",
                    note="Xo'jalik shartnomalari to'g'risidagi qonunning 25-moddasiga muvofiq penyaning umumiy summasi kechiktirilgan tovar/xizmat bahosining 50 foizidan oshmasligi shart.")

        # FK 364 (Muhim shartlar)
        node_364 = "FK-UZ-1_364"
        if node_364 in self.nodes:
            self.nodes[node_364]["remedy_clause"] = "Shartnoma predmeti, ko'rsatiladigan xizmatlar ro'yxati, natijani qabul qilish mezonlari va aniq bajarilish muddatlari Taraflar o'rtasida to'liq kelishilgan bo'lishi shart."
            self.nodes[node_364]["is_imperative"] = True

        # FK 110 (Bitimning notarial shakli)
        node_110 = "FK-UZ-1_110"
        if node_110 in self.nodes:
            self.nodes[node_110]["remedy_clause"] = "Ushbu turdagi bitim O'zbekiston qonunchiligiga ko'ra notarial tasdiqlanishi talab etiladi. Hujjatni notarius orqali rasmiylashtirish tavsiya etiladi."
            self.nodes[node_110]["is_imperative"] = True

        # ORQ-547 (Shaxsga doir ma'lumotlar)
        node_547 = "ORQ-547_15"
        if node_547 in self.nodes:
            self.nodes[node_547]["remedy_clause"] = "Taraflar bir-birlariga taqdim etiladigan barcha shaxsiy va maxfiy ma'lumotlarning himoyasini O'RQ-547 qonuniga muvofiq qat'iy kafolatlaydilar va roziliksiz tarqatmaydilar."
            self.nodes[node_547]["is_imperative"] = True

    def find_node_id(self, ref: str) -> Optional[str]:
        """
        Havolani tugun ID siga aylantiradi. Qabul qilinadigan shakllar:
        "FK-UZ-2_707", "FK-UZ-2 707-modda", "FK 707", "707-modda", "ORQ-547_15".
        Raqam bo'yicha qidiruvda aniq moslik talab qilinadi ("7-modda" "107-modda" ga mos kelmaydi).
        """
        if not ref:
            return None
        ref = ref.strip()
        if ref in self.nodes:
            return ref
        for nid, data in self.nodes.items():
            if ref.lower() == nid.lower() or ref.lower() == data.get("code", "").lower():
                return nid

        m = re.fullmatch(r"\s*([A-Za-z][A-Za-z0-9\-]*)?[\s_]*?(\d+)(?:[-\s]*modda)?\s*", ref)
        if not m:
            return None
        law, num = m.group(1), m.group(2)
        if law:
            key = re.sub(r"[^a-z0-9]", "", law.lower())
            sources = _LAW_ALIASES.get(key)
            if not sources:
                # "FK-UZ-2" kabi to'liq manba kodi
                sources = tuple(s for s in {d["source_code"] for d in self.nodes.values()} if re.sub(r"[^a-z0-9]", "", s.lower()) == key)
        else:
            sources = ("FK-UZ-1", "FK-UZ-2", "670-I", "MK-2022", "221-I", "ORQ-547")
        for src in sources:
            nid = f"{src}_{num}"
            if nid in self.nodes:
                return nid
        return None

    def resolve_chain(self, root_code: str, max_depth: int = 2, max_nodes: int = 8) -> Dict[str, Any]:
        """
        Berilgan modda bo'yicha bog'langan normalar zanjirini (Multi-Hop, BFS) yechadi.
        Qo'lda tuzilgan (curated) bog'lanishlar avtomatik "havola" qirralaridan ustun qo'yiladi.
        """
        node_id = self.find_node_id(root_code)
        if not node_id:
            return {
                "found": False,
                "chain": [],
                "combined_explanation": f"'{root_code}' bo'yicha bog'langan norma zanjiri topilmadi.",
                "suggested_redline": ""
            }

        def chain_item(nid: str, relation: str = "", note: str = "") -> Dict[str, Any]:
            item = {k: v for k, v in self.nodes[nid].items() if k != "full_text"}
            item["relation"] = relation
            item["note"] = note
            return item

        root_data = self.nodes[node_id]
        chain = [chain_item(node_id, "root")]
        chain_notes = [f"{root_data['code']}: {root_data['summary']}"]
        visited = {node_id}
        frontier = [node_id]

        for depth in range(max_depth):
            next_frontier = []
            for src in frontier:
                edges = sorted(
                    self.edges.get(src, []),
                    key=lambda e: e.get("relation") in _CURATED_RELATIONS_EXCLUDE,  # curated birinchi
                )
                for edge in edges:
                    tgt = edge["target"]
                    if tgt in visited or tgt not in self.nodes:
                        continue
                    # 2-darajada faqat curated qirralar (aks holda zanjir shovqinga to'ladi)
                    if depth > 0 and edge.get("relation") in _CURATED_RELATIONS_EXCLUDE:
                        continue
                    if len(chain) >= max_nodes:
                        break
                    visited.add(tgt)
                    note = edge.get("note", "") or self.nodes[tgt]["summary"]
                    chain.append(chain_item(tgt, edge.get("relation", "reference"), note))
                    chain_notes.append(f"Bog'liq norma ({self.nodes[tgt]['code']}): {note}")
                    next_frontier.append(tgt)
            frontier = next_frontier
            if not frontier:
                break

        return {
            "found": True,
            "root_article": root_data["code"],
            "root_title": root_data["title"],
            "url": root_data["url"],
            "chain": chain,
            "combined_explanation": " ".join(chain_notes),
            "suggested_redline": root_data.get("remedy_clause", "")
        }

    def evaluate_clause_text(self, text: str, doc_type: str = "ANY") -> Optional[Dict[str, Any]]:
        """
        Orqaga moslik uchun: band matnini qoidalar katalogi bo'yicha baholab, eng muhim topilmani
        resolve_chain formatida qaytaradi. Yangi kod `app.analyzer.ClauseAnalyzer` dan foydalanishi kerak.
        """
        from app.analyzer import ClauseIn, analyzer  # kech import: aylanma bog'liqlikdan qochish

        report = analyzer.analyze_clause(ClauseIn("eval", "", text), doc_type)
        if not report.findings:
            return None
        f = report.findings[0]
        return {
            "found": True,
            "root_article": f.cited_article,
            "root_title": f.multi_hop_chain[0]["title"] if f.multi_hop_chain else "",
            "url": f.lex_uz_url,
            "chain": f.multi_hop_chain,
            "combined_explanation": f.issue_explanation,
            "suggested_redline": f.suggested_redline,
            "risk_level": f.risk_level,
            "category": f.category,
            "issue_title": f.issue_title,
        }

# Singleton instance
legal_graph = LegalKnowledgeGraph()

if __name__ == "__main__":
    print(f"Graf umumiy tugunlari: {len(legal_graph.nodes)}")
    print(f"Graf bog'lanishlari: {sum(len(edges) for edges in legal_graph.edges.values())}")
    
    # Test resolve_chain
    chain_707 = legal_graph.resolve_chain("707-modda")
    print("\n--- FK 707 ZANJIRI ---")
    print("Topildi:", chain_707["found"])
    print("Zanjir uzunligi:", len(chain_707["chain"]))
    print("Birlashtirilgan tushuntirish:\n", chain_707["combined_explanation"][:250], "...")
    print("Tavsiya redline:", chain_707["suggested_redline"])
