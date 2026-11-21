"""
LexGuard AI — Suhbat (chat) mantiqi.

Savol turiga qarab javob manbai tanlanadi (hammasi qonunlar bazasiga asoslangan, o'ylab topilmaydi):
  1. help     — salomlashish / imkoniyatlar haqida savol.
  2. article  — savolda modda raqami bor ("707-modda nima deydi?") -> o'sha modda.
  3. topic    — mavzuli savol ("penya qancha bo'lishi mumkin?") -> qoidalar katalogidagi tayyor, korpusga bog'langan tushuntirish.
  4. analysis — foydalanuvchi shartnoma bandini yozdi -> qoidaviy tahlil (xavf, redline).
  5. search   — qolgan savollar -> BM25 eng yaqin normalar. Ball past bo'lsa "ishonchli norma topilmadi" deyiladi.

Qaytariladigan `speech` — ovozli o'qish uchun qisqa, URL va qavslarsiz matn.
"""

import re
from typing import Any, Dict, List, Optional

from app.analyzer import ClauseIn, analyzer
from app.knowledge_graph import legal_graph
from app.rules import RULES_BY_CODE
from app.text_utils import normalize_text
from app.vector_store import legal_vector_store

MAX_MESSAGE_CHARS = 2000
SEARCH_MIN_SCORE = 9.0      # undan past ballda BM25 natijasi "mavzudan tashqari" deb hisoblanadi
DISCLAIMER = "Bu axborot-tahliliy javob (O'RQ-1115). Yakuniy qaror uchun yurist bilan maslahatlashing."

_GREETING_RE = re.compile(r"^(?:salom\w*|assalomu\s+alaykum|hayrli\s+\w+|hello|hi|qalay\w*)\b|\byordam\b|\bnima qila olasan\b|\bkim san\b|\bimkoniyat\w*\b")
_QUESTION_WORD_RE = re.compile(
    r"\b(?:nima|nimaga|nega|qanday|qancha|necha|qachon|kim|qaysi|qayerda|"
    r"mumkinmi|kerakmi|bormi|haqlimi|majburmi|boladimi|yoqmi|qanaqa)\w*"
)
_ARTICLE_RE = re.compile(r"(?:\b(fk|mk)\s*)?\b(\d{1,4})\s*-?\s*modda")

# mavzu -> (regex normallashtirilgan matnga, qoida kodlari)
_TOPICS = (
    ("Penya va jarima", r"\b(?:penya|neustoyka|jarima|ustama)\w*", ("PENALTY_DISPROPORTIONATE",)),
    ("Shartnomani bekor qilish", r"\bbekor qil\w*|\bvoz kech\w*|\bshartnomani (?:toxtat|tugat)\w*", ("TERM_UNILATERAL_SERVICE", "TERM_UNILATERAL_GENERAL")),
    ("Javobgarlik", r"\bjavobgar\w*", ("LIABILITY_EXCLUSION", "LIABILITY_UNLIMITED_SERVICE")),
    ("Avans (oldindan to'lov)", r"\bavans\w*|\boldindan (?:tolov|haq)\w*|\bpredoplata\w*", ("ADVANCE_PAYMENT_NONREFUNDABLE",)),
    ("Shaxsga doir ma'lumotlar", r"\bshaxsiy malumot\w*|\bshaxsga doir\w*|\bmalumotlarni (?:chet el|xorij)\w*", ("PRIVACY_NO_CONSENT", "PRIVACY_CROSS_BORDER")),
    ("Sinov muddati", r"\bsinov muddat\w*", ("EMP_PROBATION_EXCESS",)),
    ("Intellektual mulk", r"\bmualliflik\w*|\bintellektual\w*", ("IP_FUTURE_WORKS_ASSIGNMENT",)),
    ("Maxfiylik", r"\bmaxfiylik\w*|\bkonfidensial\w*|\btijorat sir\w*", ("CONFIDENTIALITY_PERPETUAL",)),
    ("Iste'molchi huquqlari", r"\bistemolchi\w*", ("CONSUMER_RIGHTS_WAIVER",)),
    ("Ko'chmas mulk bitimi shakli", r"\bnotarial\w*|\bkochmas mulk\w*|\bkvartira\w*", ("FORM_REALESTATE_WRONG_FORM",)),
    ("Narxni o'zgartirish", r"\bnarx\w* ozgartir\w*|\bnarxni oshir\w*", ("PRICE_UNILATERAL_CHANGE",)),
    ("Muhim shartlar", r"\bmuhim shart\w*|\bshartnoma predmet\w*", ("ESSENTIAL_TERMS_VAGUE",)),
    ("Chet el huquqi va arbitraj", r"\bchet el huquqi\b|\bxalqaro arbitraj\w*", ("FOREIGN_LAW_JURISDICTION",)),
)
_TOPICS = tuple((name, re.compile(rx), codes) for name, rx, codes in _TOPICS)

_TAG_RE = re.compile(r"\[\s*(?:OKOZ|SPiT)\s*:[^\]]*\]\s*")
_AMEND_RE = re.compile(r"\((?:[^()]*?(?:tahririda|tahrirda|sonli Qonun|Qonunchilik ma|Qonun hujjatlari)[^()]*)\)")
_TAIL_CUT_RE = re.compile(r"\s(?:mazkur Kodeksning|Qo[ʻ'’]shimcha ma[ʼ'’]lumot uchun|sud amaliyoti\b)")


def clean_article_text(full_text: str, limit: int = 420) -> str:
    """Modda matnidan servis teglari, tahrir izohlari va havolalar dumini olib tashlab, gap chegarasida qisqartiradi."""
    t = _TAG_RE.sub("", full_text or "")
    t = _AMEND_RE.sub("", t)
    m = _TAIL_CUT_RE.search(t)
    if m:
        t = t[: m.start()]
    t = re.sub(r"\s+", " ", t).strip()
    if len(t) <= limit:
        return t
    cut = t[:limit]
    end = max(cut.rfind(". "), cut.rfind("; "))
    return (cut[: end + 1] if end > limit * 0.5 else cut.rstrip() + "…").strip()


def _source(node: Dict[str, Any]) -> Dict[str, str]:
    return {"id": node.get("id", ""), "code": node.get("code", ""), "title": node.get("title", ""), "url": node.get("url", "")}


def _speech(text: str, limit: int = 380) -> str:
    """Ovozli o'qish uchun: URL, emoji va belgilarsiz, gaplar nuqta bilan ajratilgan qisqa matn."""
    t = re.sub(r"https?://\S+", "", text)
    t = re.sub(r"[🔴🟡🟢]", "", t)
    t = re.sub(r"[()«»]", "", t)
    t = re.sub(r"\s*[•\n]+\s*", ". ", t)
    t = re.sub(r"([:;,])\s*\.", r"\1", t)       # ":." -> ":"
    t = re.sub(r"\.\s*(?:\.\s*)+", ". ", t)     # ". ." -> "."
    t = re.sub(r"\s+", " ", t).strip()
    if len(t) <= limit:
        return t
    cut = t[:limit]
    end = cut.rfind(". ")
    return cut[: end + 1] if end > 80 else cut


def _result(intent: str, answer: str, sources=None, findings=None, suggestions=None) -> Dict[str, Any]:
    return {
        "intent": intent,
        "answer": answer,
        "speech": _speech(answer),
        "sources": sources or [],
        "findings": findings or [],
        "suggestions": suggestions or [],
        "disclaimer": DISCLAIMER,
    }


SUGGESTIONS = [
    "707-modda nima deydi?",
    "Penya qancha bo'lishi mumkin?",
    "Shartnomani bir tomonlama bekor qilish mumkinmi?",
    "Shaxsiy ma'lumotlarni chet elga uzatish mumkinmi?",
]


def _help() -> Dict[str, Any]:
    answer = (
        "Assalomu alaykum! Men LexGuard AI yordamchisiman. O'zbekiston qonunchiligi (Lex.uz, 10 ta qonun, 2 058 modda) bo'yicha yordam beraman:\n\n"
        "• Modda haqida so'rang: «707-modda nima deydi?»\n"
        "• Mavzu bo'yicha so'rang: «Penya qancha bo'lishi mumkin?»\n"
        "• Shartnoma bandini yozing, men uni tahlil qilib, xavf va tavsiya etilgan tahrirni ko'rsataman.\n\n"
        "Mikrofon tugmasi orqali ovozli so'rash ham mumkin."
    )
    return _result("help", answer, suggestions=SUGGESTIONS)


def _article_answer(ref: str) -> Optional[Dict[str, Any]]:
    node_id = legal_graph.find_node_id(ref)
    if not node_id:
        return None
    node = legal_graph.nodes[node_id]
    chain = legal_graph.resolve_chain(node_id)
    answer = f"{node['code']} — «{node['title']}»\n\n{clean_article_text(node.get('full_text', ''))}"
    related = [n for n in chain.get("chain", [])[1:4]]
    if related:
        answer += "\n\nBog'liq normalar:\n" + "\n".join(f"• {n['code']} — {n['title']}" for n in related)
    sources = [_source(node)] + [_source(legal_graph.nodes[n["id"]]) for n in related if n["id"] in legal_graph.nodes]
    return _result("article", answer, sources, suggestions=["Penya qancha bo'lishi mumkin?", "Shartnomani bir tomonlama bekor qilish mumkinmi?"])


def _legal_basis(why: str) -> str:
    """Qoida izohidan band-xos gaplarni tashlab, modda havolali (huquqiy asos) gaplarni qoldiradi."""
    sentences = re.split(r"(?<=[.!?])\s+", why.strip())
    kept = [x for x in sentences if "modda" in x]
    return " ".join(kept) if kept else why


def _topic_answer(norm_msg: str) -> Optional[Dict[str, Any]]:
    for name, rx, codes in _TOPICS:
        if not rx.search(norm_msg):
            continue
        parts, sources, seen = [f"{name} bo'yicha:"], [], set()
        for code in codes:
            rule = RULES_BY_CODE[code]
            parts.append(f"• {_legal_basis(rule.why)}\n  Tavsiya: {rule.redline}")
            for node_id in (rule.root, *rule.related[:2]):
                node = legal_graph.nodes.get(node_id)
                if node and node_id not in seen:
                    seen.add(node_id)
                    sources.append(_source(node))
        return _result("topic", "\n\n".join(parts), sources,
                       suggestions=["Shartnoma bandini yozing — men uni tahlil qilaman"])
    return None


def _analysis_answer(message: str) -> Dict[str, Any]:
    report = analyzer.analyze_clause(ClauseIn("chat", "", message), "ANY")
    if not report.findings:
        answer = ("Qoidalarimiz bu bandda aniq xavf topmadi. Bu uning xavfsizligini kafolatlamaydi, "
                  "muhim shartnomani yurist ko'rigidan o'tkazing.")
        sources = []
        if report.related_norms:
            answer += "\n\nBand mavzusiga yaqin normalar:\n" + "\n".join(f"• {n['code']} — {n['title']}" for n in report.related_norms)
            sources = [{"id": n["id"], "code": n["code"], "title": n["title"], "url": n["url"]} for n in report.related_norms]
        return _result("no_findings", answer, sources)

    findings, lines, sources, seen = [], [], [], set()
    for f in report.findings[:3]:
        icon = "🔴" if f.risk_level == "RED" else "🟡"
        # tavsiya etilgan tahrir `findings` da alohida (UI uni yashil blokda ko'rsatadi) — matnda takrorlanmaydi
        explanation = re.sub(r"\s*Bog'liq normalar:.*$", "", f.issue_explanation).strip()  # manbalar chiplarda ko'rsatiladi
        lines.append(f"{icon} {f.issue_title} ({f.cited_article})\n{explanation}")
        findings.append({
            "risk_level": f.risk_level, "issue_title": f.issue_title, "problematic_quote": f.problematic_quote,
            "suggested_redline": f.suggested_redline, "cited_article": f.cited_article,
            "lex_uz_url": f.lex_uz_url, "balance_label": f.balance_label,
        })
        for n in f.multi_hop_chain[:3]:
            if n["id"] not in seen and n["id"] in legal_graph.nodes:
                seen.add(n["id"])
                sources.append(_source(legal_graph.nodes[n["id"]]))
    head = "Bandni tahlil qildim. " + ("Jiddiy xavf topildi." if any(f["risk_level"] == "RED" for f in findings) else "Tijoriy xavf topildi.")
    return _result("analysis", head + "\n\n" + "\n\n".join(lines), sources, findings)


def _search_answer(message: str) -> Dict[str, Any]:
    hits = legal_vector_store.search(message, top_k=3)
    if not hits or hits[0]["score"] < SEARCH_MIN_SCORE:
        return _result(
            "no_match",
            "Bu savol bo'yicha qonunlar bazasidan ishonchli norma topa olmadim. Savolni aniqroq yozing, modda raqamini ayting "
            "(masalan, «707-modda») yoki shartnoma bandini to'liq matn bilan kiriting.",
            suggestions=SUGGESTIONS,
        )
    parts, sources = ["Savolingizga eng yaqin normalar:"], []
    for h in hits:
        node = legal_graph.nodes.get(h["id"])
        if not node:
            continue
        parts.append(f"• {node['code']} — {node['title']}\n  {clean_article_text(node.get('full_text', ''), 260)}")
        sources.append(_source(node))
    parts.append("Aniq xulosa uchun modda raqamini so'rang, masalan: «" + sources[0]["code"].split(" ", 1)[-1] + " nima deydi?»")
    return _result("search", "\n\n".join(parts), sources)


def answer_chat(message: str) -> Dict[str, Any]:
    msg = (message or "").strip()[:MAX_MESSAGE_CHARS]
    if not msg:
        return _help()
    norm = normalize_text(msg)

    m = _ARTICLE_RE.search(norm)
    if m:
        ref = f"{m.group(1)} {m.group(2)}" if m.group(1) else f"{m.group(2)}-modda"
        res = _article_answer(ref)
        if res:
            return res

    if len(norm) < 40 and _GREETING_RE.search(norm):
        return _help()

    is_question = "?" in msg or bool(_QUESTION_WORD_RE.search(norm)) or len(norm) < 45
    if is_question:
        res = _topic_answer(norm)
        if res:
            return res
        return _search_answer(msg)

    return _analysis_answer(msg)
