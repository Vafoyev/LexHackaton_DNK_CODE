"""
LexGuard AI — Lex.uz Downloader & Legal Corpus Extractor
Vazifasi: Lex.uz milliy qonunchilik bazasidan barcha asosiy shartnomaviy,
fuqarolik, mehnat va tijorat qonunlarini yuklab olib, moddama-modda JSON formatida saqlash.
"""

import os
import re
import json
import urllib.request
from typing import Dict, List, Any, Optional

LEX_SOURCES = {
    "FK_PART_1": {
        "title": "Fuqarolik Kodeksi (1-qism)",
        "code": "FK-UZ-1",
        "doc_id": "-111189",
        "url": "https://lex.uz/docs/-111189"
    },
    "FK_PART_2": {
        "title": "Fuqarolik Kodeksi (2-qism)",
        "code": "FK-UZ-2",
        "doc_id": "-180552",
        "url": "https://lex.uz/docs/-180552"
    },
    "MK_2022": {
        "title": "Mehnat Kodeksi (Yangi tahrir)",
        "code": "MK-2022",
        "doc_id": "-6257288",
        "url": "https://lex.uz/docs/-6257288"
    },
    "SHARTNOMA_BAZASI": {
        "title": "Xo'jalik yurituvchi subyektlar faoliyatining shartnomaviy-huquqiy bazasi to'g'risida Qonun (670-I)",
        "code": "670-I",
        "doc_id": "-18942",
        "url": "https://lex.uz/docs/-18942"
    },
    "ISTEMOLCHI_HUQUQI": {
        "title": "Iste'molchilarning huquqlarini himoya qilish to'g'risida Qonun (221-I)",
        "code": "221-I",
        "doc_id": "-4704",
        "url": "https://lex.uz/docs/-4704"
    },
    "SHAXSIY_MALUMOTLAR": {
        "title": "Shaxsga doir ma'lumotlar to'g'risida Qonun (O'RQ-547)",
        "code": "ORQ-547",
        "doc_id": "-4396419",
        "url": "https://lex.uz/docs/-4396419"
    },
    "MEDIATSIYA": {
        "title": "Mediatsiya to'g'risida Qonun (O'RQ-482)",
        "code": "ORQ-482",
        "doc_id": "-3805227",
        "url": "https://lex.uz/uz/docs/-3805227"
    },
    "ELEKTRON_TIJORAT": {
        "title": "Elektron tijorat to'g'risida Qonun (O'RQ-792)",
        "code": "ORQ-792",
        "doc_id": "-6213382",
        "url": "https://lex.uz/uz/docs/-6213382"
    },
    "RAQOBAT": {
        "title": "Raqobat to'g'risida Qonun (O'RQ-850)",
        "code": "ORQ-850",
        "doc_id": "-6518381",
        "url": "https://lex.uz/docs/-6518381"
    },
    "DAVLAT_XARIDLARI": {
        "title": "Davlat xaridlari to'g'risida Qonun (O'RQ-684)",
        "code": "ORQ-684",
        "doc_id": "-5382974",
        "url": "https://lex.uz/docs/-5382974"
    }
}

class LexUzScraper:
    def __init__(self, output_dir: str = "/Users/baxrom/ish_full/LexHackaton_DNK_CODE/ai-engine/data"):
        self.output_dir = output_dir
        self.raw_dir = os.path.join(output_dir, "raw")
        self.articles_dir = os.path.join(output_dir, "articles")
        os.makedirs(self.raw_dir, exist_ok=True)
        os.makedirs(self.articles_dir, exist_ok=True)

    def extract_cross_references(self, text: str) -> List[str]:
        """
        Matndagi havolalarni (masalan: 354-modda, FK 324-moddasi, 3-moddasi) ajratib olish.
        """
        refs = []
        # Pattern: raqam + modda
        matches = re.findall(r'(\d+)\s*[-–—]\s*modda', text, re.IGNORECASE)
        for m in matches:
            ref = f"{m}-modda"
            if ref not in refs:
                refs.append(ref)
        return refs

    def extract_articles_from_html(self, html_text: str, source_code: str, base_url: str) -> List[Dict[str, Any]]:
        """
        Lex.uz HTML sahifasidan har bir moddani, uning sarlavhasi, toza matni va havolalarini ajratib oladi.
        """
        # 1. Keraksiz UI elementlari va toolbarlarni tozalash
        cleaned_html = re.sub(r'<div[^>]+class=[\'"][^\'"]*lx_elem[23][^\'"]*[\'"].*?</div>', '', html_text, flags=re.DOTALL)
        cleaned_html = re.sub(r'<div[^>]+class=[\'"][^\'"]*LX_COMMENT[^\'"]*[\'"].*?</div>', '', cleaned_html, flags=re.DOTALL)
        cleaned_html = re.sub(r'<script.*?</script>', '', cleaned_html, flags=re.DOTALL)
        cleaned_html = re.sub(r'<style.*?</style>', '', cleaned_html, flags=re.DOTALL)

        # 2. Moddalar sarlavhasi patterni: <div ... id="(-?\d+)" ...>\s*(\d+)\s*-modda.\s*([^<]+)</div>
        # yoki umumiyroq modda sarlavhasi
        pattern = r'<div[^>]+id=[\'"](-?\d+)[\'"][^>]*>\s*(\d+)\s*[-–—]\s*modda\.\s*([^<]+)</div>'
        matches = list(re.finditer(pattern, cleaned_html, re.IGNORECASE))
        
        articles = []

        if matches:
            for i in range(len(matches)):
                anchor_id, art_num, art_title = matches[i].groups()
                start_pos = matches[i].end()
                end_pos = matches[i+1].start() if i + 1 < len(matches) else start_pos + 4000
                body_html = cleaned_html[start_pos:end_pos]

                # HTML teglaridan tozalash
                body_text = re.sub(r'<[^>]+>', ' ', body_html)
                # Standart Lex.uz UI yozuvlarini va tahrir izohlarini tozalash
                body_text = re.sub(r'Ҳужжатга таклиф юбориш|Аудиони тинглаш|Ҳужжат элементидан ҳавола олиш|Oldingi tahrirga qarang\.?|LexUZ sharhi|Qarang:', '', body_text, flags=re.IGNORECASE)
                body_text = re.sub(r'^\s*\([^\)]*tahririda[^\)]*\)\s*', '', body_text, flags=re.IGNORECASE)
                body_text = re.sub(r'^\s*\([^\)]*qoʻshimcha kiritilgan[^\)]*\)\s*', '', body_text, flags=re.IGNORECASE)
                body_text = re.sub(r'^\s*\([^\)]*oʻz kuchini yoʻqotgan[^\)]*\)\s*', '', body_text, flags=re.IGNORECASE)
                body_text = re.sub(r'\s+', ' ', body_text).strip()

                # Cross-references qidirish
                cross_refs = self.extract_cross_references(body_text)

                clean_title = art_title.strip().replace('&nbsp;', ' ')

                articles.append({
                    "id": f"{source_code}_{art_num}",
                    "source_code": source_code,
                    "article_number": f"{art_num}-modda",
                    "title": clean_title,
                    "full_text": body_text[:3000],
                    "official_url": f"{base_url}#{anchor_id}",
                    "cross_references": cross_refs
                })
        else:
            # Fallback: agar ID divs formatida bo'lmasa, oddiy matn orqali regex
            raw_text = re.sub(r'<[^>]+>', ' ', cleaned_html)
            raw_text = re.sub(r'\s+', ' ', raw_text).strip()
            art_matches = list(re.finditer(r'(\d+)\s*[-–—]\s*modda\s*\.?\s*([^\n\r]+?)(?=\d+\s*[-–—]\s*modda|\Z)', raw_text, flags=re.IGNORECASE))
            for m in art_matches:
                art_num = m.group(1).strip()
                content = m.group(2).strip()
                lines = content.split('. ', 1)
                title = lines[0].strip() if len(lines) > 1 else f"{art_num}-modda"
                body = lines[1].strip() if len(lines) > 1 else content

                articles.append({
                    "id": f"{source_code}_{art_num}",
                    "source_code": source_code,
                    "article_number": f"{art_num}-modda",
                    "title": title[:150],
                    "full_text": body[:3000],
                    "official_url": f"{base_url}#{art_num}",
                    "cross_references": self.extract_cross_references(body)
                })

        return articles

    def download_and_ingest(self) -> Dict[str, int]:
        """
        Barcha qonunlarni yuklab olib, JSON formatida saqlaydi.
        """
        results = {}
        all_articles_summary = []

        print(f"[LexUzScraper] Boshlandi: Jami {len(LEX_SOURCES)} ta qonun manbasi indekslanadi...")

        for key, src in LEX_SOURCES.items():
            out_file = os.path.join(self.articles_dir, f"{key.lower()}.json")
            raw_html_file = os.path.join(self.raw_dir, f"{key.lower()}.html")
            articles = []

            print(f"[LexUzScraper] Yuklanmoqda: {src['title']} ({src['url']})...")
            try:
                req = urllib.request.Request(
                    src["url"],
                    headers={"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) LexGuard-Legal-Indexer/2.0"}
                )
                with urllib.request.urlopen(req, timeout=15) as response:
                    html_content = response.read().decode('utf-8', errors='ignore')
                    
                    # Raw HTML nusxasini saqlash
                    with open(raw_html_file, "w", encoding="utf-8") as f_raw:
                        f_raw.write(html_content)

                    articles = self.extract_articles_from_html(html_content, src["code"], src["url"])
                    print(f"  ✓ {len(articles)} ta modda muvaffaqiyatli ajratildi!")
            except Exception as e:
                print(f"  ⚠️ Tarmoqdan yuklashda xatolik ({e}), mavjud yoki standart korpusdan foydalaniladi.")
                if os.path.exists(raw_html_file):
                    with open(raw_html_file, "r", encoding="utf-8") as f_raw:
                        articles = self.extract_articles_from_html(f_raw.read(), src["code"], src["url"])
                else:
                    articles = self._get_fallback_corpus(key, src)

            # JSON faylga saqlash
            with open(out_file, "w", encoding="utf-8") as f:
                json.dump(articles, f, ensure_ascii=False, indent=2)

            results[key] = len(articles)
            all_articles_summary.extend(articles)

        # Umumiy birlashtirilgan korpusni saqlash
        unified_file = os.path.join(self.output_dir, "uzbek_legal_corpus_unified.json")
        with open(unified_file, "w", encoding="utf-8") as f_uni:
            json.dump(all_articles_summary, f_uni, ensure_ascii=False, indent=2)

        print(f"\n[LexUzScraper] TUGATILDI! Jami {len(all_articles_summary)} ta modda bazaga kiritildi: {unified_file}")
        return results

    def _get_fallback_corpus(self, key: str, src: Dict[str, str]) -> List[Dict[str, Any]]:
        return [
            {
                "id": f"{src['code']}_707",
                "source_code": src["code"],
                "article_number": "707-modda",
                "title": "Haq evaziga xizmat ko'rsatish shartnomasini bajarishdan bosh tortish",
                "full_text": "Buyurtmachi ijrochiga u qilgan haqiqiy xarajatlarni to'lash sharti bilangina haq evaziga xizmat ko'rsatish shartnomasini bajarishdan bosh tortishga haqli.",
                "official_url": "https://lex.uz/docs/-180552#181540",
                "cross_references": ["354-modda", "324-modda"]
            },
            {
                "id": f"{src['code']}_326",
                "source_code": src["code"],
                "article_number": "326-modda",
                "title": "Neustoykani kamaytirish",
                "full_text": "Agar to'lanishi lozim bo'lgan neustoyka kreditorning majburiyati buzilishi oqibatlariga nomutanosibligi ko'rinib tursa, sud neustoykani kamaytirishga haqli.",
                "official_url": "https://lex.uz/docs/-111189#111520",
                "cross_references": ["260-modda"]
            },
            {
                "id": f"{src['code']}_354",
                "source_code": src["code"],
                "article_number": "354-modda",
                "title": "Shartnoma tuzish erkinligi",
                "full_text": "Fuqarolar va yuridik shaxslar shartnoma tuzishda erkindirlar. Shartnoma shartlari qonun hujjatlarining imperativ talablariga zid bo'lmasligi lozim.",
                "official_url": "https://lex.uz/docs/-111189#155463",
                "cross_references": ["355-modda", "364-modda"]
            }
        ]

if __name__ == "__main__":
    scraper = LexUzScraper()
    res = scraper.download_and_ingest()
    print("Yuklangan qonunlar statistikasi:", res)
