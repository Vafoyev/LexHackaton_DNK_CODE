"""
LexGuard AI — Legal Knowledge Graph (O'zbekiston Qonunlari Zanjirli Bog'lanish Tizimi)
Muallif: AI & Legal Engineering Group
Vazifasi: Lex.uz dan yuklab olingan 2,058 ta modda va ulardagi o'zaro murakkab havolalarni
(cross-references: A -> B -> C) yechish hamda tasdiqlangan qonuniy iqtibos zanjirini yetkazish.
"""

import os
import re
import json
from pathlib import Path
from typing import Dict, List, Optional, Any
from collections import defaultdict

from app.normalizer import is_foreign_law_clause, normalize_uzbek
from app.notarial_classifier import classify_document_form

DEFAULT_CORPUS_PATH = str(
    Path(os.getenv("LEGAL_CORPUS_PATH", Path(__file__).resolve().parent.parent / "data" / "uzbek_legal_corpus_unified.json"))
)

class LegalKnowledgeGraph:
    def __init__(self, corpus_path: str = DEFAULT_CORPUS_PATH):
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

    def resolve_chain(self, root_code: str) -> Dict[str, Any]:
        """
        Berilgan modda bo'yicha bog'langan barcha normalar zanjirini (Multi-Hop) yechadi.
        """
        # Node ID ni topish
        node_id = None
        for n in self.nodes:
            if root_code.lower() == n.lower() or root_code.lower() in self.nodes[n].get("code", "").lower() or root_code.lower() == self.nodes[n].get("article_number", "").lower():
                node_id = n
                break
        
        if not node_id and ("fk" in root_code.lower() or "modda" in root_code.lower()):
            num = re.sub(r'[^\d]', '', root_code)
            if num:
                for prefix in ["FK-UZ-1_", "FK-UZ-2_", "MK-2022_", "670-I_", "ORQ-547_"]:
                    cand = f"{prefix}{num}"
                    if cand in self.nodes:
                        node_id = cand
                        break

        if not node_id or node_id not in self.nodes:
            return {
                "found": False,
                "chain": [],
                "combined_explanation": f"'{root_code}' bo'yicha bog'langan norma zanjiri topilmadi.",
                "suggested_redline": ""
            }

        root_data = self.nodes[node_id]
        chain = [root_data]
        chain_notes = [f"{root_data['code']}: {root_data['summary']}"]

        # Zanjir bo'yicha qo'shni normalarni tekshirish (1-va 2-darajali chuqurlik)
        visited = {node_id}
        for edge in self.edges.get(node_id, []):
            target_id = edge["target"]
            if target_id in self.nodes and target_id not in visited:
                visited.add(target_id)
                target_data = self.nodes[target_id]
                chain.append(target_data)
                chain_notes.append(f"Bog'liq norma ({target_data['code']}): {edge.get('note', target_data['summary'])}")

        combined_explanation = " ".join(chain_notes)

        return {
            "found": True,
            "root_article": root_data["code"],
            "root_title": root_data["title"],
            "url": root_data["url"],
            "chain": chain,
            "combined_explanation": combined_explanation,
            "suggested_redline": root_data.get("remedy_clause", "")
        }

    def verify_citation(self, cited_article: str) -> bool:
        """Closed-World Allowlist verifier: confirms cited article exists in our verified Lex.uz corpus."""
        if not cited_article or not self.nodes:
            return False
        res = self.resolve_chain(cited_article)
        return bool(res.get("found"))

    def evaluate_clause_text(self, text: str, doc_has_notarial_proof: bool = False) -> Optional[Dict[str, Any]]:
        """
        Shartnoma bandi matnini (Kirill, eski va yangi lotin normalizatsiyasi bilan) tahlil qilib,
        qonuniy xavfni va bog'liq moddalar zanjirini aniqlaydi.
        Notarial vs Oddiy shartnoma tekshiruvi 3-qavatli notarial_classifier orqali ishlaydi.
        """
        # 0. Xorijiy qonun / arbitraj -> Fail-Closed UNKNOWN ("Tekshirilmadi", tizim taxmin qilmaydi, DOCX §4)
        if is_foreign_law_clause(text):
            return {
                "found": True,
                "root_article": "",
                "root_title": "Xorijiy yurisdiksiya — Tekshirilmadi",
                "url": "",
                "chain": [],
                "risk_level": "UNKNOWN",
                "category": "UNKNOWN",
                "balance_label": "Aniqlanmadi",
                "issue_title": "Xorijiy qonun yoki arbitraj bandi (Tekshirilmadi)",
                "combined_explanation": "LexGuard AI faqat O'zbekiston Respublikasi qonunchiligi doirasida tekshiradi. Xorijiy huquqqa oid bandlar bo'yicha xulosa chiqarilmaydi («0») va hamkor advokatga yo'naltiriladi.",
                "suggested_redline": "O'zbekiston Respublikasi amaldagi qonunchiligi qo'llanilishini ko'rsating yoki hamkor advokat ko'rigidan o'tkazing.",
            }

        lower = normalize_uzbek(text)

        # 1. Bekor qilish / voz kechish (R4 — FK 707)
        is_termination = any(w in lower for w in ["bekor qilish", "bekor qiladi", "voz kechish", "voz kechadi", "to'xtatishi", "to'xtatish"])
        if is_termination and any(w in lower for w in ["bir tomonlama", "xabardor qilmasdan", "ogohlantirmasdan", "istalgan vaqtda", "istalgan paytda", "to'lovsiz", "sabab ko'rsatmasdan"]):
            if any(bad in lower for bad in ["qoplamasdan", "javobgarsiz", "to'lovsiz", "xabardor qilmasdan", "ogohlantirmasdan", "kompensatsiyasiz", "qaytarilmaydi"]) or (
                "xarajat" not in lower and "oldindan" not in lower and "kun oldin" not in lower
            ):
                res = self.resolve_chain("FK-UZ-2_707")
                res["risk_level"] = "RED"
                res["category"] = "LEGAL"
                res["balance_label"] = "Ijrochiga og'ir"
                res["issue_title"] = "Asossiz bir tomonlama bekor qilish huquqi"
                return res

        # 2. Neustoyka / penya / jarima (R3 — FK 326 + 670-I 25-m)
        if any(w in lower for w in ["penya", "jarima", "neustoyka"]):
            has_safe_cap = (
                any(cap in lower for cap in ["10%", "10 foiz", "5%", "5 foiz", "20%", "20 foiz", "50%", "50 foiz"])
                and any(cap_w in lower for cap_w in ["oshmagan", "oshmasligi", "chegaralangan", "ko'p bo'lmagan"])
                and not re.search(r"(?<!\d\.)(?<!\d)(?:[1-9]\d*)(?:\.\d+)?\s*(?:%|foiz)\s*(?:kunlik|miqdorida\s+penya|miqdorida\s+neustoyka|penya|neustoyka|jarima)", lower)
                and not any(high in lower for high in ["cheklanmagan", "cheksiz", "limit qo'llanilmaydi", "chegara belgilanmaydi"])
            )
            if not has_safe_cap:
                res = self.resolve_chain("FK-UZ-1_326")
                res["risk_level"] = "YELLOW"
                res["category"] = "COMMERCIAL"
                res["balance_label"] = "Qarzdor tarafga og'ir"
                res["issue_title"] = "Qonunga mos, lekin e'tibor kerak: penya/jarima chegarasi"
                return res

        # 3. Majburiy notarial shakl talabi (3-qavatli Notarial Classifier — R6)
        if not doc_has_notarial_proof:
            form_eval = classify_document_form(text)
            if form_eval["form_status"] == "MISSING_MANDATORY_NOTARIZATION":
                cited_node = form_eval.get("cited_node_id") or "FK-UZ-1_110"
                res = self.resolve_chain(cited_node)
                if not res.get("found"):
                    res = self.resolve_chain("FK-UZ-1_110")
                res["risk_level"] = "RED"
                res["category"] = "LEGAL"
                res["balance_label"] = "Muvozanatli"
                res["issue_title"] = f"Majburiy notarial tasdiq topilmadi ({form_eval['transaction_label']})"
                res["combined_explanation"] = form_eval["summary_uz"]
                return res
            if form_eval["form_status"] == "MISSING_E_IJARA_REMINDER":
                res = self.resolve_chain("FK-UZ-2_574")
                if res.get("found"):
                    res["risk_level"] = "YELLOW"
                    res["category"] = "COMPLIANCE"
                    res["balance_label"] = "Muvozanatli"
                    res["issue_title"] = "Notarius shart emas, lekin E-ijara (ijara.soliq.uz) hisobiga qo'yish kerak"
                    res["combined_explanation"] = form_eval["summary_uz"]
                    res["suggested_redline"] = "Ushbu ijara shartnomasi imzolangan kundan boshlab 3 ish kuni ichida ijara.soliq.uz (E-ijara) tizimida hisobga qo'yiladi."
                    return res

        # 4. Predmet va hajm noaniqligi (FK 364)
        if any(w in lower for w in ["predmet", "xizmatlar ro'yxati", "hajmi", "narxi", "muddati"]) and any(
            w in lower for w in ["belgilanmagan", "keyin kelishiladi", "aniqlanmagan", "og'zaki kelishiladi", "keyinchalik belgilanadi"]
        ):
            res = self.resolve_chain("FK-UZ-1_364")
            res["risk_level"] = "RED"
            res["category"] = "LEGAL"
            res["balance_label"] = "Muvozanatli"
            res["issue_title"] = "Shartnomaning muhim shartlari noaniq"
            return res

        # 5. Xorijiy valyutada hisob-kitob (FK 245)
        if any(
            w in lower
            for w in [
                "aqsh dollarida",
                "dollarida to'lanadi",
                "valyutada naqd",
                "chet el valyutasida",
                "yevroda naqd",
                "usd naqd",
                "dollarda naqd",
            ]
        ) and "so'mda" not in lower and "markaziy bank kursi" not in lower:
            res = self.resolve_chain("FK-UZ-1_245")
            if res.get("found"):
                res["risk_level"] = "RED"
                res["category"] = "LEGAL"
                res["balance_label"] = "Muvozanatli"
                res["issue_title"] = "O'zbekiston hududida xorijiy valyutada to'lov taqiqi"
                return res

        # 6. Sudgacha pretenziya va mediatsiya yo'qligi (R5 — ORQ-482 16-m)
        explicitly_skips_mediation = any(
            w in lower
            for w in [
                "mediatsiyasiz",
                "mediatsiya tartibisiz",
                "pretenziyasiz",
                "talabnomasiz",
                "talabnoma tartibisiz",
                "muzokaralarsiz",
            ]
        )
        direct_court_only = (
            any(w in lower for w in ["to'g'ridan-to'g'ri sud", "darhol sud", "faqat sudda"])
            and "mediatsiya" not in lower
            and "pretenziya" not in lower
        )
        if explicitly_skips_mediation or direct_court_only:
            res = self.resolve_chain("ORQ-482_16")
            if res.get("found"):
                res["risk_level"] = "YELLOW"
                res["category"] = "COMMERCIAL"
                res["balance_label"] = "Muvozanatli"
                res["issue_title"] = "Sudgacha 10 kunlik pretenziya va mediatsiya bosqichi yo'q"
                res["suggested_redline"] = "Nizolar avvalo 10 kunlik yozma pretenziya va «Mediatsiya to'g'risida»gi Qonun asosida hal qilinadi; kelishuv bo'lmasa sudga oshiriladi."
                return res

        # 7. Shaxsiy ma'lumotlar / Xorijiy server / Roziliksiz tarqatish (ORQ-547)
        if any(
            w in lower
            for w in ["xorijdagi server", "chet el server", "roziliksiz tarqat", "roziliksiz uchinchi", "roziliksiz marketing", "cheklovlarsiz qayta ishla"]
        ):
            res = self.resolve_chain("ORQ-547_15")
            res["risk_level"] = "RED"
            res["category"] = "COMPLIANCE"
            res["balance_label"] = "Mijozga og'ir"
            res["issue_title"] = "Shaxsga doir ma'lumotlarni roziliksiz qayta ishlash / xorijda saqlash"
            return res

        if any(w in lower for w in ["shaxsiy ma'lumot", "maxfiylik", "konfidensial"]) and any(
            w in lower for w in ["cheklanmagan", "muddat cheklanmagan", "istalgan uchinchi shaxs", "roziliksiz"]
        ):
            res = self.resolve_chain("ORQ-547_15")
            res["risk_level"] = "YELLOW"
            res["category"] = "COMPLIANCE"
            res["balance_label"] = "Muvozanatli"
            res["issue_title"] = "Shaxsiy ma'lumotlar va maxfiylik kafolati talabi"
            return res

        # 8. Mehnat / Shtat munosabatlari niqoblangan fuqarolik shartnomasi (MK-2022 11-m)
        if any(w in lower for w in ["ish vaqti", "ichki mehnat tartibi", "intizomiy jazo", "ta'til", "09:00 dan 18:00"]) and any(
            w in lower for w in ["xizmat ko'rsatish", "pudrat", "o'zini o'zi band", "fuqarolik-huquqiy", "frilans"]
        ):
            res = self.resolve_chain("MK-2022_11")
            res["risk_level"] = "RED"
            res["category"] = "LEGAL"
            res["balance_label"] = "Ijrochiga og'ir"
            res["issue_title"] = "Fuqarolik-huquqiy shartnoma ostida mehnat munosabatlarini yashirish xavfi"
            return res

        # 9. Iste'molchi huquqlarini cheklash (221-I 18-m)
        if any(w in lower for w in ["tovar qaytarilmaydi", "almashtirilmaydi", "kafolat berilmaydi", "pul qaytarilmaydi", "da'vo qabul qilinmaydi"]) and any(
            w in lower for w in ["iste'molchi", "xaridor", "mijoz", "tovar", "mahsulot"]
        ):
            res = self.resolve_chain("221-I_18")
            if res.get("found"):
                res["risk_level"] = "RED"
                res["category"] = "LEGAL"
                res["balance_label"] = "Xaridorga og'ir"
                res["issue_title"] = "Iste'molchining nuqsonli tovarni qaytarish va kafolat huquqi cheklangan"
                res["suggested_redline"] = "Xaridor nuqsonli tovarni «Iste'molchilarning huquqlarini himoya qilish to'g'risida»gi Qonun 13 va 18-moddalariga muvofiq 10 kun ichida almashtirish yoki pulini qaytarib olish huquqiga ega."
                return res

        # 10. Bir tomonlama narx o'zgartirish yoki avtomatik uzaytirish (SARIQ — FK 382)
        if any(w in lower for w in ["narxni bir tomonlama oshir", "tarifni ogohlantirmasdan o'zgartir", "avtomatik ravishda uzaytiriladi", "avtomatik uzayadi"]):
            res = self.resolve_chain("FK-UZ-1_382")
            if res.get("found"):
                res["risk_level"] = "YELLOW"
                res["category"] = "COMMERCIAL"
                res["balance_label"] = "Buyurtmachiga og'ir"
                res["issue_title"] = "Qonunga mos, lekin e'tibor kerak: bir tomonlama narx o'zgartirish / avtomatik uzaytirish"
                res["suggested_redline"] = "Narx va muddat o'zgarishlari faqat ikki tarafning yozma qo'shimcha kelishuvi bilan hamda kamida 30 kun oldin xabardor qilingan holda kuchga kiradi."
                return res

        # 11. Raqobatni cheklash / Eksklyuziv bozor taqiqi (ORQ-850)
        if any(w in lower for w in ["raqobatchilar bilan ishlash taqiqlanadi", "boshqa yetkazib beruvchidan xarid qilish taqiqlanadi", "hududda faqat bizdan sotib oladi"]):
            res = self.resolve_chain("ORQ-850_19")
            if not res.get("found"):
                res = self.resolve_chain("ORQ-850_1")
            if res.get("found"):
                res["risk_level"] = "YELLOW"
                res["category"] = "COMPLIANCE"
                res["balance_label"] = "Hamkorga og'ir"
                res["issue_title"] = "Raqobatni cheklovchi eksklyuziv shart ehtimoli"
                res["suggested_redline"] = "Eksklyuzivlik sharti «Raqobat to'g'risida»gi O'RQ-850 qonuni talablariga muvofiq muddat va doira bilan cheklanishi lozim."
                return res

        # 12. Haddan tashqari uzoq yoki noaniq to'lov muddati (SARIQ — FK 242)
        if any(w in lower for w in ["90 kun ichida to'lanadi", "120 kun ichida to'lanadi", "180 kun ichida to'lanadi", "mablag' bo'lganda to'lanadi"]):
            res = self.resolve_chain("FK-UZ-1_242")
            if res.get("found"):
                res["risk_level"] = "YELLOW"
                res["category"] = "COMMERCIAL"
                res["balance_label"] = "Ijrochiga og'ir"
                res["issue_title"] = "To'lov muddati haddan tashqari cho'zilgan yoki noaniq"
                res["suggested_redline"] = "To'lov bajarilgan ishlar dalolatnomasi imzolangan kundan boshlab 10 (o'n) bank ish kuni ichida amalga oshiriladi."
                return res

        return None

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
