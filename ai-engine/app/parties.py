"""
LexGuard AI — Shartnoma tomonlarini aniqlash (balans tahlili uchun umumiy yordamchilar).

Matnlar `text_utils.normalize_text` dan o'tgan bo'lishi kerak (kichik harf, apostrofsiz, lotin).
PROVIDER — majburiyatni bajaruvchi (ijrochi, sotuvchi, pudratchi, ijaraga beruvchi, xodim),
RECIPIENT — natijani oluvchi (buyurtmachi, xaridor, ijarachi, ish beruvchi, iste'molchi).
"""

import re
from typing import Optional, Tuple

PROVIDER = "PROVIDER"
RECIPIENT = "RECIPIENT"
BOTH = "BOTH"  # ikki tomonga teng (simmetrik band)

PROVIDER_RE = re.compile(r"\b(?:ijrochi|sotuvchi|yetkazib beruvchi|pudratchi|ijaraga beruvchi|taminotchi|xizmat korsatuvchi|xodim)\w*")
RECIPIENT_RE = re.compile(r"\b(?:buyurtmachi|xaridor|sotib oluvchi|ijaraga oluvchi|ijarachi|istemolchi|mijoz|ish beruvchi)\w*")

# "taraflardan har biri", "ikkala taraf", "har ikki tomon", "taraflar" — ikki tomonga teng qamrov
SYMMETRIC_RE = re.compile(
    r"\btaraflardan (?:har biri|istalgan\w*)\b|\bikkala (?:taraf|tomon)\w*|\bhar ikki (?:taraf|tomon)\w*|"
    r"\bhar qanday taraf\w*|\bistalgan taraf\w*|\bhar bir taraf\w*|\b(?:buzgan|kechiktirgan|bajarmagan|buzuvchi)\s+taraf\w*|"
    r"\btaraflar\b|\bozaro\b"
)

# Taqiqlovchi/inkor shakllar: "bir tomonlama bekor qilish taqiqlanadi" — xavfli huquq berilmagan, aksincha cheklangan
PROHIBITION_RE = re.compile(
    r"\btaqiqlan\w*|\bman etil\w*|\bmumkin emas\b|\bmumkin bolmaydi\b|\bhaqli emas\b|\bhuquqi yoq\b|"
    r"\bhuquqqa ega emas\b|\byol qoyilmay\w*|\bruxsat etilmay\w*|\bqila olmay\w*|\bqilolmay\w*"
)

# "Ijrochi va Buyurtmachi ..." — ikkala tomon birga sanalgan
_JOIN_RE = re.compile(r"^\s*(?:va|hamda|,)\s*$")


def first_side(sentence_norm: str) -> Optional[str]:
    """Gapda birinchi tilga olingan tomon (odatda gap egasi)."""
    p, r = PROVIDER_RE.search(sentence_norm), RECIPIENT_RE.search(sentence_norm)
    if not p and not r:
        return None
    if p and (not r or p.start() < r.start()):
        return PROVIDER
    return RECIPIENT


def is_symmetric(sentence_norm: str) -> bool:
    """
    Gap ikkala tomonga bir xil tegishli bo'lsa True:
      - "Taraflardan har biri ...", "ikkala taraf ...", yoki
      - "Ijrochi va Buyurtmachi ..." (ikkalasi bog'lovchi bilan birga sanalgan).
    Aniq bir tomon avval kelib, keyin "taraflar" tilga olinsa — simmetrik hisoblanmaydi.
    """
    p, r = PROVIDER_RE.search(sentence_norm), RECIPIENT_RE.search(sentence_norm)
    m = SYMMETRIC_RE.search(sentence_norm)
    first_party = min((x.start() for x in (p, r) if x), default=None)
    if m and (first_party is None or m.start() <= first_party):
        return True
    if p and r:
        a, b = (p, r) if p.start() < r.start() else (r, p)
        if _JOIN_RE.match(sentence_norm[a.end():b.start()]):
            return True
    return False


def other(side: str) -> str:
    return RECIPIENT if side == PROVIDER else PROVIDER


def has_prohibition(sentence_norm: str) -> bool:
    return bool(PROHIBITION_RE.search(sentence_norm))


def side_pair(sentence_norm: str) -> Tuple[Optional[str], bool]:
    """(birinchi tilga olingan tomon, simmetrikmi)."""
    return first_side(sentence_norm), is_symmetric(sentence_norm)
