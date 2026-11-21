"""
LexGuard AI — Hujjat darajasidagi balans tahlili ("Tomonlar balansi").

Maqsad: shartnoma ikki tomondan biriga ortiqcha og'ir tushmayotganini ko'rsatish va tengsizlik topilsa
ikki tomonga teng (reciprocal) tahrir taklif qilish.

Qanday ishlaydi (evristik, tushunarli va tekshiriladigan):
  1. Har bir bandning gaplari bo'yicha "daftar" yuritiladi: bekor qilish huquqi, penya, javobgarlik, javobgarlikdan ozod qilish,
     narx/shartni bir tomonlama o'zgartirish, maxfiylik. Har bir yozuvda HUQUQ yoki MAJBURIYAT kimda ekani aniqlanadi
     (parties.py: birinchi tilga olingan tomon, "taraflardan har biri" kabi simmetrik shakllar, inkor).
  2. Har bir mavzu bo'yicha: ikkala tomonda bor -> teng; faqat bir tomonda -> bir tomonlama; penya stavkalari 2 baravar farq -> tengsiz.
  3. Qoidalar katalogi topilmalari (analyzer) yuk ko'taruvchi tomonga ballanadi (qizil = 3, sariq = 1), daftar tengsizliklari +2.
  4. Ballar yig'indisidan: kim qancha yuk ko'tarayotgani, simmetriya (0-100) va xulosa chiqadi.

Muhim cheklovlar (javobda `limitations` sifatida qaytariladi):
  - Balans qonuniy talab emas (shartnoma erkinligi, FK 354); bu tijoriy mezon. Qonunga zid bandlar alohida (qoidalar katalogi) ko'rsatiladi.
  - Tomonlar gap egasi bo'yicha aniqlanadi; murakkab/majhul gaplarda aniqlanmay qolishi mumkin.
"""

import re
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Pattern, Tuple

from app.analyzer import SIDE_NAMES, ClauseIn, ClauseReport
from app.knowledge_graph import legal_graph
from app.parties import BOTH, PROVIDER, RECIPIENT, has_prohibition, other, side_pair
from app.rules import GENERAL, canonical_doc_type
from app.text_utils import normalize_text, split_sentences

POINTS_RED = 3.0
POINTS_YELLOW = 1.0
POINTS_TOPIC = 2.0       # bir tomonlama/tengsiz mavzu
HEAVY_THRESHOLD = 5.0    # bir tomon uchun yuk ballari shundan yuqori bo'lsa "og'ir"
SYMMETRY_BALANCED = 0.25  # asimmetriya shundan past bo'lsa "teng"
MAGNITUDE_FULL = 4.0     # umumiy ball shundan kam bo'lsa asimmetriya ta'siri kamaytiriladi (1 ta sariq band "bir tomonlama" bo'lib ketmasligi uchun)
UNEQUAL_RATE_RATIO = 2.0
MIN_SIGNAL = 2.0         # umumiy ball shundan kam bo'lsa (masalan, bitta kichik xavf) shartnoma "bir tomonlama" deb belgilanmaydi

_RATE_RE = re.compile(r"(\d+(?:[.,]\d+)?)\s*(?:%|foiz)")
_EXEMPT_RE = re.compile(r"\bjavobgar\w* (?:emas|bolmaydi|zimmasiga olmaydi)\b|\bjavobgarlikdan (?:toliq )?ozod\w*|\bhech qanday javobgar\w*")
_FORCE_MAJEURE_RE = re.compile(r"\bfors-?major\w*|\bengib bolmas\w*|\bhal qiluvchi kuch\w*|\bfavqulodda\b|\btabiiy ofat\w*")
_UNILATERAL_HINT_RE = re.compile(r"\bbir tomonlama\b|\bixtiyori\w*|\bozi(?:ning)? xohishi\w*|\bogohlantirmasdan\b|\bistalgan (?:vaqt|payt)da\b")
_CONTRAST_RE = re.compile(r"\bammo\b|\bbiroq\b|\blekin\b")


@dataclass(frozen=True)
class Topic:
    code: str
    label: str
    kind: str          # right: kimdadir huquq bor; obligation: kimdadir majburiyat bor
    rx: Pattern
    fix: str           # ikki tomonga teng tahrir
    require: Optional[Pattern] = None


TOPICS: Tuple[Topic, ...] = (
    Topic(
        "TERMINATION", "Shartnomani bekor qilish huquqi", "right",
        re.compile(
            r"\bshartnom\w*[^.]{0,60}\b(?:bekor qil|voz kech|toxtat|tugat)\w*|\b(?:bekor qil|voz kech)\w*[^.]{0,30}\bshartnom\w*|"
            r"\b(?:bekor qil|voz kech)\w*[^.]{0,40}\b(?:huquq|mumkin|haqli)\w*|\b(?:huquq|mumkin|haqli)\w*[^.]{0,40}\b(?:bekor qil|voz kech)\w*"
        ),
        "Taraflardan har biri shartnomani kamida 15 (o'n besh) kun oldin yozma ogohlantirib bekor qilishi mumkin; "
        "bekor qilingunga qadar bajarilgan majburiyatlar va asoslangan xarajatlar to'liq to'lanadi.",
    ),
    Topic(
        "PENALTY", "Penya va jarima", "obligation",
        re.compile(r"\b(?:penya|neustoyka|jarima|ustama)\w*"),
        "Majburiyatni kechiktirgan taraf (ikkalasi ham) kechiktirilgan har bir kun uchun bajarilmagan qism summasining 0,1% miqdorida "
        "penya to'laydi; umumiy summa shartnoma qiymatining 10% idan oshmaydi.",
    ),
    Topic(
        "LIABILITY", "Javobgarlik va zararni qoplash", "obligation",
        re.compile(r"\bjavobgar\w*|\bzarar\w*[^.]{0,30}\bqopla\w*"),
        "Tomonlarning javobgarligi o'zaro teng: har bir taraf majburiyatni buzganlik uchun shartnoma bahosi doirasida javob beradi; "
        "qasddan buzish holatlari bundan mustasno.",
    ),
    Topic(
        "LIABILITY_EXEMPTION", "Javobgarlikdan ozod qilish", "right",
        _EXEMPT_RE,
        "Tomonlardan hech biri o'z majburiyatini buzganlik uchun javobgarlikdan ozod qilinmaydi (fors-major holatlari ikkala taraf uchun bir xil).",
    ),
    Topic(
        "CHANGE", "Narx va shartlarni o'zgartirish huquqi", "right",
        re.compile(r"\b(?:narx|baho|tarif|stavka|shartlar|shartnoma shartlari)\w*[^.]{0,40}\b(?:ozgartir|oshir)\w*"),
        "Shartnoma narxi va shartlari faqat ikkala tarafning yozma kelishuvi bilan o'zgartiriladi.",
        require=_UNILATERAL_HINT_RE,
    ),
    Topic(
        "CONFIDENTIALITY", "Maxfiylik majburiyati", "obligation",
        re.compile(r"\b(?:maxfiy|konfidensial|tijorat sir)\w*"),
        "Maxfiylik majburiyati ikkala taraf uchun teng amal qiladi va shartnoma tugagandan keyin 3 (uch) yil davom etadi.",
        require=re.compile(r"\boshkor qil\w*|\btarqat\w*|\bochmayd\w*|\bmajbur\w*|\bsaqla\w*"),
    ),
)


@dataclass
class Entry:
    topic: str
    holder: str                 # PROVIDER | RECIPIENT | BOTH
    clause_number: str
    quote: str
    rate: Optional[float] = None


def _extract_entries(clauses: List[ClauseIn]) -> Tuple[List[Entry], int]:
    """Daftar yozuvlari va tomoni aniqlanmagan gaplar soni."""
    entries: List[Entry] = []
    unattributed = 0
    for clause in clauses:
        for sentence in split_sentences(clause.text or "") or [clause.text or ""]:
            norm = normalize_text(sentence)
            if not norm:
                continue
            for topic in TOPICS:
                if not topic.rx.search(norm):
                    continue
                if topic.require and not topic.require.search(norm):
                    continue
                if topic.code == "LIABILITY" and _EXEMPT_RE.search(norm):
                    continue  # bu — "javobgarlikdan ozod qilish" mavzusi
                if topic.code == "LIABILITY_EXEMPTION" and _FORCE_MAJEURE_RE.search(norm):
                    continue  # fors-major bo'yicha ozod qilish ikkala tomon uchun odatiy
                if topic.kind == "right" and has_prohibition(norm) and not _CONTRAST_RE.search(norm):
                    continue  # "bekor qilish taqiqlanadi" — huquq berilmagan
                first, symmetric = side_pair(norm)
                holder = BOTH if symmetric else first
                if holder is None:
                    unattributed += 1
                    continue
                rate = None
                if topic.code == "PENALTY":
                    m = _RATE_RE.search(norm)
                    rate = float(m.group(1).replace(",", ".")) if m else None
                entries.append(Entry(topic.code, holder, clause.clause_number, sentence.strip(), rate))
    return entries, unattributed


def _topic_result(topic: Topic, entries: List[Entry], names: Tuple[str, str]) -> Dict[str, Any]:
    mine = [e for e in entries if e.topic == topic.code]
    covered = set()
    for e in mine:
        covered |= {PROVIDER, RECIPIENT} if e.holder == BOTH else {e.holder}

    status, burdened, detail = "BALANCED", None, ""
    if len(covered) == 1:
        side = next(iter(covered))
        status = "ONE_SIDED"
        burdened = other(side) if topic.kind == "right" else side
        who = names[0] if side == PROVIDER else names[1]
        detail = f"Faqat {who} uchun belgilangan." if topic.kind == "obligation" else f"Faqat {who} tomoniga berilgan."
    elif topic.code == "PENALTY":
        rates = {side: [e.rate for e in mine if e.holder == side and e.rate is not None] for side in (PROVIDER, RECIPIENT)}
        if rates[PROVIDER] and rates[RECIPIENT]:
            hi_side = PROVIDER if max(rates[PROVIDER]) > max(rates[RECIPIENT]) else RECIPIENT
            hi, lo = max(rates[hi_side]), max(rates[other(hi_side)])
            if lo > 0 and hi / lo >= UNEQUAL_RATE_RATIO:
                status, burdened = "UNEQUAL", hi_side
                who = names[0] if hi_side == PROVIDER else names[1]
                detail = f"{who} uchun penya stavkasi {hi:g}%, ikkinchi tomon uchun {lo:g}% ({hi / lo:.1f} baravar farq)."

    return {
        "topic": topic.code,
        "label": topic.label,
        "status": status,
        "burdened_side": burdened,
        "burdened_name": None if burdened is None else (names[0] if burdened == PROVIDER else names[1]),
        "detail": detail,
        "clause_numbers": sorted({e.clause_number for e in mine}, key=lambda x: (len(x), x)),
        "quotes": [e.quote for e in mine[:2]],
        "fix": topic.fix if status != "BALANCED" else "",
    }


def _basis() -> List[Dict[str, str]]:
    out = []
    for node_id in ("FK-UZ-1_1", "FK-UZ-1_354"):
        node = legal_graph.nodes.get(node_id)
        if node:
            out.append({"id": node_id, "code": node["code"], "title": node["title"], "url": node["url"]})
    return out


def compute_balance(
    clauses: List[ClauseIn], reports: List[ClauseReport], doc_type: str = "", party_role: str = "",
) -> Dict[str, Any]:
    doc = canonical_doc_type(doc_type)
    names = SIDE_NAMES.get(doc, SIDE_NAMES[GENERAL])
    role_side = {"EXECUTOR": PROVIDER, "CUSTOMER": RECIPIENT}.get((party_role or "").upper())

    entries, unattributed = _extract_entries(clauses)
    topic_results = [_topic_result(t, entries, names) for t in TOPICS if any(e.topic == t.code for e in entries)]

    # --- ballar: (band, tomon) bo'yicha eng katta hissa (bir bandni ikki marta sanamaslik uchun)
    contrib: Dict[Tuple[str, str], float] = {}

    def add(clause_number: str, side: str, pts: float) -> None:
        key = (clause_number, side)
        contrib[key] = max(contrib.get(key, 0.0), pts)

    symmetric_findings = unattributed_findings = 0
    for rep in reports:
        for f in rep.findings:
            if f.burdened_side in (PROVIDER, RECIPIENT):
                add(rep.clause_number, f.burdened_side, POINTS_RED if f.risk_level == "RED" else POINTS_YELLOW)
            elif f.burdened_side == BOTH:
                symmetric_findings += 1
            else:
                unattributed_findings += 1

    for tr in topic_results:
        if tr["status"] in ("ONE_SIDED", "UNEQUAL") and tr["burdened_side"]:
            # aynan shu band kaliti bilan: xuddi shu bandning topilmasi bilan ikki marta sanalmasligi uchun
            first_clause = tr["clause_numbers"][0] if tr["clause_numbers"] else "?"
            add(first_clause, tr["burdened_side"], POINTS_TOPIC)

    p = sum(v for (_, side), v in contrib.items() if side == PROVIDER)
    r = sum(v for (_, side), v in contrib.items() if side == RECIPIENT)
    total = p + r
    asym = abs(p - r) / total if total else 0.0
    asym_eff = asym * min(1.0, total / MAGNITUDE_FULL)
    score = round(100 * (1 - asym_eff))

    heavy = [s for s, v in ((PROVIDER, p), (RECIPIENT, r)) if v >= HEAVY_THRESHOLD]
    if total < MIN_SIGNAL:
        verdict = "BALANCED"
    elif asym_eff < SYMMETRY_BALANCED:
        verdict = "BALANCED_HEAVY" if len(heavy) == 2 else "BALANCED"
    else:
        verdict = "ONE_SIDED_PROVIDER" if p > r else "ONE_SIDED_RECIPIENT"

    favored_burden = PROVIDER if p > r else RECIPIENT
    if verdict.startswith("ONE_SIDED"):
        who = names[0] if favored_burden == PROVIDER else names[1]
        label = f"{who} tomoniga og'ir"
        summary = (f"Shartnoma {who} tomoniga og'irroq: xavf ballarining {round(100 * max(p, r) / total)}% shu tomonga to'g'ri keladi.")
        if role_side == favored_burden:
            summary += " Siz shu tomondasiz: imzolashdan oldin quyidagi tahrirlarni talab qiling."
    elif verdict == "BALANCED_HEAVY":
        label = "Ikki tomonga ham og'ir"
        summary = "Yuk ikki tomonga teng taqsimlangan, lekin ikkala tomon uchun ham xavfli bandlar ko'p. Bu muvozanatli, ammo xavfli shartnoma."
    elif total < MIN_SIGNAL:
        label = "Muvozanatli"
        summary = ("Qoidalarimiz doirasida tomonlar o'rtasida yuk farqi topilmadi. Bu to'liq xavfsizlikni kafolatlamaydi."
                   if total == 0 else "Tomonlar o'rtasida sezilarli yuk farqi topilmadi (faqat bitta kichik xavf aniqlandi).")
    else:
        label = "Muvozanatli"
        summary = "Tomonlar o'rtasida sezilarli yuk farqi topilmadi."

    recommendations = [
        {"topic": tr["topic"], "label": tr["label"], "text": tr["fix"], "clause_numbers": tr["clause_numbers"]}
        for tr in topic_results if tr["fix"]
    ]
    analyzed = len(clauses)
    low_confidence = analyzed < 3 or (not entries and not any(rep.findings for rep in reports))

    return {
        "verdict": verdict,
        "verdict_label": label,
        "summary": summary,
        "score": score,
        "sides": {
            "provider": {"name": names[0], "burden": round(p, 1), "share": round(100 * p / total) if total else 0, "heavy": PROVIDER in heavy},
            "recipient": {"name": names[1], "burden": round(r, 1), "share": round(100 * r / total) if total else 0, "heavy": RECIPIENT in heavy},
        },
        "topics": topic_results,
        "recommendations": recommendations,
        "stats": {
            "clauses": analyzed,
            "ledger_entries": len(entries),
            "symmetric_findings": symmetric_findings,
            "unattributed": unattributed + unattributed_findings,
        },
        "confidence": "LOW" if low_confidence else "MEDIUM",
        "method": "heuristic",
        "basis": _basis(),
        "limitations": [
            "Balans qonuniy talab emas (shartnoma erkinligi, FK 354): bu tijoriy mezon. Qonunga zid bandlar alohida ko'rsatiladi.",
            "Tomonlar gap egasi bo'yicha aniqlanadi; murakkab yoki majhul gaplarda tomon aniqlanmay qolishi mumkin.",
            "Faqat bekor qilish, penya, javobgarlik, narx/shartni o'zgartirish va maxfiylik mavzulari tekshiriladi.",
        ],
    }
