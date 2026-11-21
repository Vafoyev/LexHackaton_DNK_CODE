"""
LexGuard AI — Matn normalizatsiyasi (o'zbek lotin/kirill, apostrof variantlari), gaplarga ajratish, stemming.
"""

import re
from typing import List

# O'zbek kirill -> lotin (ikki harfli birikmalar uchun oddiy xaritalash)
_CYR2LAT = {
    "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "yo", "ж": "j", "з": "z",
    "и": "i", "й": "y", "к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p", "р": "r",
    "с": "s", "т": "t", "у": "u", "ф": "f", "х": "x", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "shch",
    "ъ": "'", "ы": "i", "ь": "", "э": "e", "ю": "yu", "я": "ya",
    "ў": "o'", "қ": "q", "ғ": "g'", "ҳ": "h",
}
_CYRILLIC_RE = re.compile(r"[Ѐ-ӿ]")
_APOSTROPHES_RE = re.compile(r"[ʻʼ’‘`´′ʹʽ]")
_WS_RE = re.compile(r"\s+")

# Eng ko'p uchraydigan o'zbekcha qo'shimchalar (uzundan qisqaga). Stem kamida 4 harf qolishi shart.
_SUFFIXES = (
    "larning", "lardan", "larida", "lariga", "larini", "lar", "ning", "dan", "ida", "iga", "ini",
    "ning", "ni", "da", "ga", "ka", "qa", "si", "ib", "ish", "ishi", "lik", "chi", "dagi",
)


def has_cyrillic(text: str) -> bool:
    return bool(_CYRILLIC_RE.search(text))


def transliterate_cyrillic(text: str) -> str:
    out = []
    for ch in text:
        low = ch.lower()
        if low in _CYR2LAT:
            lat = _CYR2LAT[low]
            out.append(lat.upper() if ch != low and lat else lat)
        else:
            out.append(ch)
    return "".join(out)


def normalize_apostrophes(text: str) -> str:
    return _APOSTROPHES_RE.sub("'", text)


def normalize_text(text: str) -> str:
    """
    Qoidalar va qidiruv uchun kanonik shakl: lotin, kichik harf, apostroflar olib tashlangan
    ("ko'chmas" / "koʻchmas" / "кўчмас" -> "kochmas"), ortiqcha bo'shliqlarsiz.
    """
    if not text:
        return ""
    if has_cyrillic(text):
        text = transliterate_cyrillic(text)
    text = normalize_apostrophes(text).lower()
    text = text.replace("'", "")
    return _WS_RE.sub(" ", text).strip()


def stem(token: str) -> str:
    for suf in _SUFFIXES:
        if token.endswith(suf) and len(token) - len(suf) >= 4:
            return token[: -len(suf)]
    return token


def tokenize(text: str) -> List[str]:
    """BM25 uchun tokenlar: normalizatsiya + stemming, juda qisqa so'zlarsiz."""
    clean = re.sub(r"[^\w\s]", " ", normalize_text(text))
    return [stem(w) for w in clean.split() if len(w) > 2]


_SENT_SPLIT_RE = re.compile(
    r"(?<=[;!?])\s+"
    r"|(?<=[a-zа-яўқғҳʻʼ'’\)»\"])\.\s+(?=[A-ZА-ЯЎҚҒҲ«\"0-9])"
)


def split_sentences(text: str) -> List[str]:
    """
    Matnni gaplarga ajratadi. Qaytarilgan har bir bo'lak ASL matnning aynan substringi
    (Go tomonidagi 'substring grounding' tekshiruvi uchun muhim).
    Faqat raqamdan iborat bo'lak ("1.1.") keyingi gapga biriktiriladi.
    """
    spans = []
    start = 0
    for m in _SENT_SPLIT_RE.finditer(text):
        spans.append((start, m.start()))
        start = m.end()
    spans.append((start, len(text)))

    result: List[str] = []
    carry_start = None
    for a, b in spans:
        piece = text[a:b].strip()
        if not piece:
            continue
        if re.fullmatch(r"[\d.\-\)]+", piece):
            carry_start = a if carry_start is None else carry_start
            continue
        if carry_start is not None:
            a, carry_start = carry_start, None
        result.append(text[a:b].strip())
    if carry_start is not None:
        result.append(text[carry_start:].strip())
    return result
