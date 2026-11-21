"""
LexGuard AI — Uzbek Script Normalizer & Foreign-Law Scope Guard (DOCX §3 & §4)
Normalizes Uzbek Cyrillic, Old Latin (o'/g'), Reformed Latin (ö/ğ/ş/ç),
and typographic apostrophes into one canonical lowercase Latin form.
"""

from __future__ import annotations

import re

_CYRILLIC_TO_LATIN = {
    "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "yo",
    "ж": "j", "з": "z", "и": "i", "й": "y", "к": "k", "л": "l", "м": "m",
    "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u",
    "ф": "f", "х": "x", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "sh",
    "ъ": "'", "ы": "i", "ь": "", "э": "e", "ю": "yu", "я": "ya",
    "ў": "o'", "қ": "q", "ғ": "g'", "ҳ": "h",
}

_REFORMED_TO_CANONICAL = {
    "ö": "o'",
    "ğ": "g'",
    "ş": "sh",
    "ç": "ch",
    "ō": "o'",
    "ḡ": "g'",
}

_APOSTROPHE_RE = re.compile(r"[‘’ʻʼ`´]")
_WS_RE = re.compile(r"\s+")

_FOREIGN_LAW_PATTERNS = (
    "english law",
    "laws of england",
    "lcia",
    "london court of international arbitration",
    "icc paris",
    "icc in paris",
    "arbitration of the icc",
    "icc rules",
    "singapore international arbitration",
    "singapore law",
    "siac",
    "swiss law",
    "delaware law",
    "difc",
    "new york law",
    "xorijiy qonun",
    "chet el qonunchiligi",
    "rossiya federatsiyasi fuqarolik kodeksi",
    "gk rf",
    "гк рф",
    "xalqaro savdo odatlari",
    "иностранное право",
    "право англии",
    "лондонский арбитраж",
)


def normalize_uzbek(text: str) -> str:
    """Converts any Uzbek script (Cyrillic / Old Latin / Reformed Latin) into canonical lowercase Latin."""
    if not text:
        return ""
    s = _APOSTROPHE_RE.sub("'", text.lower())
    out: list[str] = []
    for ch in s:
        if ch in _REFORMED_TO_CANONICAL:
            out.append(_REFORMED_TO_CANONICAL[ch])
        elif ch in _CYRILLIC_TO_LATIN:
            out.append(_CYRILLIC_TO_LATIN[ch])
        else:
            out.append(ch)
    return _WS_RE.sub(" ", "".join(out)).strip()


def is_foreign_law_clause(text: str) -> bool:
    """Detects clauses governed by foreign jurisdictions outside Uzbekistan law scope (DOCX §4)."""
    low = (text or "").lower()
    norm = normalize_uzbek(text)
    return any(p in low or p in norm for p in _FOREIGN_LAW_PATTERNS)
