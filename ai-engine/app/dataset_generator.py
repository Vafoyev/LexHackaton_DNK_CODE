"""
LexGuard AI — Legal Instruction Dataset Generator
Vazifasi: Lex.uz dan yuklab olingan 2,058 ta moddalar va shartnoma bandlaridan
AI modelini o'qitish (Fine-Tuning: LoRA / SFT) uchun Alpaca va ShareGPT formatidagi
yuqori sifatli JSONL datasetlarini yaratish.
"""

import os
import re
import json
from typing import List, Dict, Any

class LegalDatasetGenerator:
    def __init__(
        self,
        unified_corpus_path: str = "/Users/baxrom/ish_full/LexHackaton_DNK_CODE/ai-engine/data/uzbek_legal_corpus_unified.json",
        output_alpaca: str = "/Users/baxrom/ish_full/LexHackaton_DNK_CODE/ai-engine/data/legal_instructions_train.jsonl",
        output_sharegpt: str = "/Users/baxrom/ish_full/LexHackaton_DNK_CODE/ai-engine/data/legal_sharegpt_train.jsonl",
        output_eval: str = "/Users/baxrom/ish_full/LexHackaton_DNK_CODE/ai-engine/data/legal_cross_ref_eval.jsonl"
    ):
        self.corpus_path = unified_corpus_path
        self.output_alpaca = output_alpaca
        self.output_sharegpt = output_sharegpt
        self.output_eval = output_eval

    def generate(self) -> Dict[str, int]:
        if not os.path.exists(self.corpus_path):
            raise FileNotFoundError(f"Korpus fayli topilmadi: {self.corpus_path}")

        with open(self.corpus_path, "r", encoding="utf-8") as f:
            articles = json.load(f)

        alpaca_entries = []
        sharegpt_entries = []
        eval_entries = []

        print(f"[DatasetGenerator] {len(articles)} ta qonun moddasidan ta'lim juftliklari generatsiya qilinmoqda...")

        # 1. Har bir moddadan huquqiy tushuntirish va ta'lim juftliklari
        for art in articles:
            source = art.get("source_code", "O'zbekiston qonunchiligi")
            art_num = art.get("article_number", "")
            title = art.get("title", "")
            text = art.get("full_text", "")
            url = art.get("official_url", "")
            cross_refs = art.get("cross_references", [])

            # a) Modda tushuntirish juftligi (Instruction QA)
            instruction_qa = f"O'zbekiston Respublikasi {source} doirasida {art_num}ning mohiyati, qo'llanilish doirasi va shartnomalar uchun ahamiyatini tushuntiring."
            input_qa = f"Norma sarlavhasi: {title}"
            output_qa = (
                f"Huquqiy asos: {source} {art_num} — «{title}».\n\n"
                f"Norma rasmiy matni:\n\"{text[:800]}\"\n\n"
                f"Rasmiy manba havolasi: {url}\n\n"
                f"Yuridik tahlil: Ushbu norma shartnoma tuzish va bajarish jarayonida taraflarning qonuniy manfaatlarini belgilaydi. "
                f"Unga zid keluvchi shartnoma bandlari O'zbekiston Respublikasi Fuqarolik kodeksining imperativ talablariga muvofiq haqiqiy emas deb topilishi mumkin."
            )

            alpaca_entries.append({
                "instruction": instruction_qa,
                "input": input_qa,
                "output": output_qa
            })

            sharegpt_entries.append({
                "conversations": [
                    {"from": "human", "value": f"{instruction_qa}\n\n{input_qa}"},
                    {"from": "gpt", "value": output_qa}
                ]
            })

            # b) Havolalar (Cross-References) bo'yicha maxsus ko'p bosqichli (Multi-Hop) ta'lim juftliklari
            if cross_refs:
                refs_str = ", ".join(cross_refs[:4])
                instruction_cross = f"O'zbekiston qonunchiligi bo'yicha {source} {art_num} qo'llanilganda qaysi boshqa normativ havolalarni (cross-references) birga inobatga olish shart?"
                input_cross = f"Modda: {art_num} («{title}»)"
                output_cross = (
                    f"{source} {art_num} quyidagi bog'liq normalarga havolalarni o'z ichiga oladi: {refs_str}.\n\n"
                    f"Zanjirli tahlil (Multi-Hop Reasoning):\n"
                    f"Shartnoma shartlarini tahlil qilishda faqatgina {art_num} bilan cheklanmasdan, "
                    f"ushbu ko'rsatilgan moddalar ({refs_str}) bo'yicha belgilangan majburiyatlar va shartnoma erkinligi chegaralarini birgalikda qo'llash shart. "
                    f"Aks holda yuridik xulosa xato yoki to'liqsiz bo'ladi."
                )

                alpaca_entries.append({
                    "instruction": instruction_cross,
                    "input": input_cross,
                    "output": output_cross
                })

                eval_entries.append({
                    "test_type": "cross_reference_resolution",
                    "article": f"{source}_{art_num}",
                    "expected_references": cross_refs,
                    "prompt": instruction_cross,
                    "context": text[:500]
                })

        # 2. Sintetik va Amaliy Shartnoma xavflari (RED/YELLOW/GREEN) va Redline takliflari
        expert_cases = self._get_expert_contract_cases()
        for case in expert_cases:
            alpaca_entries.append({
                "instruction": case["instruction"],
                "input": case["input"],
                "output": case["output"]
            })
            sharegpt_entries.append({
                "conversations": [
                    {"from": "human", "value": f"{case['instruction']}\n\nBand matni:\n\"{case['input']}\""},
                    {"from": "gpt", "value": case["output"]}
                ]
            })

        # Fayllarga saqlash
        with open(self.output_alpaca, "w", encoding="utf-8") as f:
            for item in alpaca_entries:
                f.write(json.dumps(item, ensure_ascii=False) + "\n")

        with open(self.output_sharegpt, "w", encoding="utf-8") as f:
            for item in sharegpt_entries:
                f.write(json.dumps(item, ensure_ascii=False) + "\n")

        with open(self.output_eval, "w", encoding="utf-8") as f:
            for item in eval_entries:
                f.write(json.dumps(item, ensure_ascii=False) + "\n")

        stats = {
            "alpaca_pairs": len(alpaca_entries),
            "sharegpt_dialogues": len(sharegpt_entries),
            "cross_ref_eval_tests": len(eval_entries)
        }

        print(f"\n[DatasetGenerator] MUVAFFAQIShIYATLI YARATILDI:")
        print(f"  • Alpaca format: {self.output_alpaca} ({stats['alpaca_pairs']} ta juftlik)")
        print(f"  • ShareGPT format: {self.output_sharegpt} ({stats['sharegpt_dialogues']} ta dialog)")
        print(f"  • Eval Suite: {self.output_eval} ({stats['cross_ref_eval_tests']} ta test keysi)")

        return stats

    def _get_expert_contract_cases(self) -> List[Dict[str, str]]:
        return [
            {
                "instruction": "Quyidagi xizmat ko'rsatish shartnomasi bandini O'zbekiston qonunchiligiga muvofiqligini tekshiring, xavf darajasini aniqlang va qonuniy tahrir (redline) taklif qiling.",
                "input": "Buyurtmachi istalgan vaqtda Ijrochini xabardor qilmasdan va sarflangan xarajatlarni qoplamasdan shartnomani bir tomonlama bekor qilish huquqiga ega.",
                "output": (
                    "🔴 XAVF DARAJASI: QIZIL (LEGAL RISK)\n"
                    "Yuridik asos: Fuqarolik Kodeksi 707-moddasi (Haq evaziga xizmat ko'rsatish shartnomasini bajarishdan bosh tortish), "
                    "bog'liq FK 354-modda (Shartnoma erkinligi chegaralari) va FK 324-modda (Zararni to'lash majburiyati).\n"
                    "Zanjirli tahlil: FK 707-moddasiga binoan, Buyurtmachi ijrochiga u qilgan haqiqiy xarajatlarni to'lash sharti bilangina shartnomadan voz kechishga haqli. "
                    "FK 354-moddasi shartnoma erkinligini kafolatlasa-da, bu norma imperativ qonun talablarini bekor qila olmasligini belgilaydi. "
                    "Asossiz va xarajatlarsiz bir tomonlama bekor qilish qonunga zid va haqiqiy emas.\n\n"
                    "🟢 TAVSIYA ETILGAN TAHRIR (REDLINE):\n"
                    "\"Buyurtmachi shartnomani bekor qilishdan kamida 15 (o'n besh) kun oldin Ijrochini yozma xabardor qiladi hamda Ijrochi tomonidan amalda ko'rsatilgan xizmatlar haqini va asoslangan haqiqiy xarajatlarini to'liq qoplaydi.\""
                )
            },
            {
                "instruction": "Quyidagi javobgarlik bandidagi penya miqdorini tahlil qiling va O'zbekiston qonunchiligiga mos tijoriy limit taklif qiling.",
                "input": "Ijrochi xizmatni topshirish muddatini kechiktirsa, har bir kechiktirilgan kun uchun shartnoma umumiy summasining 1% miqdorida penya to'laydi.",
                "output": (
                    "🟡 XAVF DARAJASI: SARIQ (COMMERCIAL RISK — ASIMMETRIYA)\n"
                    "Yuridik asos: Fuqarolik Kodeksi 326-moddasi (Neustoykani kamaytirish), FK 260-moddasi hamda "
                    "'Xo'jalik yurituvchi subyektlar faoliyatining shartnomaviy-huquqiy bazasi to'g'risida'gi Qonunning 25-moddasi.\n"
                    "Zanjirli tahlil: Kunlik 1% penya (oyiga 30%) amaliyotda nomutanosib yuqori hisoblanadi. "
                    "Qonunning 25-moddasiga ko'ra penyaning umumiy miqdori kechiktirilgan majburiyat summasining 50 foizidan oshmasligi shart. "
                    "Sud FK 326-moddasiga binoan bunday asossiz neustoykani kamaytirishga haqli.\n\n"
                    "🟢 TAVSIYA ETILGAN TAHRIR (REDLINE):\n"
                    "\"Ijrochi majburiyatni kechiktirgan har bir kun uchun bajarilmagan qism summasining 0.1% miqdorida, lekin umumiy shartnoma qiymatining 10% idan oshmagan miqdorda penya to'laydi.\""
                )
            },
            {
                "instruction": "Quyidagi nizo hal qilish bandidagi xavflarni tahlil qiling va kichik biznes manfaati uchun to'g'irlash bering.",
                "input": "Barcha nizolar taraflarning yashash joyidagi sudda hal etiladi. Pretenziya bildirish va muzokaralar tartibi talab etilmaydi.",
                "output": (
                    "🟡 XAVF DARAJASI: SARIQ (COMMERCIAL RISK)\n"
                    "Yuridik asos: Fuqarolik Kodeksi, Iqtisodiy protsessual kodeks hamda 'Mediatsiya to'g'risida'gi Qonun (O'RQ-482).\n"
                    "Zanjirli tahlil: Suddan oldingi hal qilish mexanizmining yo'qligi tomonlarni yuqori davlat boji va vaqt sarfiga duchor qiladi. "
                    "Pretenziya va mediatsiya tartibi tadbirkorlar o'rtasida sheriklikni saqlab qolishning eng samarali usulidir.\n\n"
                    "🟢 TAVSIYA ETILGAN TAHRIR (REDLINE):\n"
                    "\"Taraflar kelib chiqqan nizolarni muzokaralar va yozma pretenziya bildirish orqali (javob berish muddati 15 kalendar kun), shuningdek professional mediator ishtirokida hal qilish choralarini ko'radilar. Kelishuvga erishilmagan taqdirda nizo Iqtisodiy sudda ko'rib chiqiladi.\""
                )
            },
            {
                "instruction": "Quyidagi shaxsiy ma'lumotlar va axborot xavfsizligi bandini tekshiring.",
                "input": "Ijrochi Buyurtmachining mijozlari ma'lumotlarini o'z marketing maqsadlarida va xorijdagi serverlarida cheklovlarsiz qayta ishlash huquqiga ega.",
                "output": (
                    "🔴 XAVF DARAJASI: QIZIL (LEGAL COMPLIANCE RISK)\n"
                    "Yuridik asos: 'Shaxsga doir ma'lumotlar to'g'risida'gi O'zbekiston Respublikasi Qonuni (O'RQ-547) 15-modda va 27-1-moddasi.\n"
                    "Zanjirli tahlil: Qonunning 27-1-moddasiga ko'ra, O'zbekiston fuqarolarining shaxsga doir ma'lumotlari jismoniy jihatdan O'zbekiston hududidagi serverlarda joylashishi va saqlanishi shart. "
                    "Subyekt roziligisiz marketing maqsadida foydalanish va xorijga noqonuniy uzatish ma'muriy va jinoiy javobgarlikka sabab bo'ladi.\n\n"
                    "🟢 TAVSIYA ETILGAN TAHRIR (REDLINE):\n"
                    "\"Ijrochi Buyurtmachining ma'lumotlarini faqat shartnoma maqsadlarida, O'zbekiston Respublikasining O'RQ-547 qonuniga muvofiq, O'zbekiston hududidagi serverlarda saqlash va subyektlarning yozma roziligi bilan qayta ishlash majburiyatini oladi.\""
                )
            }
        ]

if __name__ == "__main__":
    gen = LegalDatasetGenerator()
    gen.generate()
