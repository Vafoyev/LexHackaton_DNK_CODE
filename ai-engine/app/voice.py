"""
LexGuard AI — Ovozli brifing (SSML) va ovozli savol-javob matnini shakllantirish.
STT/TTS ovoz sintezi klient (Flutter/Web) tomonida; AI engine matn + SSML beradi.
"""

import re
from typing import Any, Dict, Iterable, List
from xml.sax.saxutils import escape

DISCLAIMER_UZ = "Bu axborot-tahliliy xulosa bo'lib, yakuniy qaror yurist ko'rigidan keyin qabul qilinadi."

_ARTICLE_REF_RE = re.compile(r"(?:\b(fk|mk)\s*)?\b(\d{1,4})\s*-?\s*modda", re.IGNORECASE)


def _risk_value(r: Any, key: str) -> str:
    return (r.get(key) if isinstance(r, dict) else getattr(r, key, "")) or ""


def _first_sentence(text: str, limit: int = 200) -> str:
    text = text.strip()
    m = re.search(r"(.+?[.!?])(\s|$)", text)
    s = m.group(1) if m else text
    return s if len(s) <= limit else s[: limit - 1].rstrip() + "…"


def build_voice_brief(top_risks: Iterable[Any], summary_text: str = "") -> Dict[str, Any]:
    """top_risks: dict yoki obyekt (risk_level, issue_title, issue_explanation maydonlari bilan)."""
    risks = list(top_risks)
    red = [r for r in risks if _risk_value(r, "risk_level") == "RED"]
    yellow = [r for r in risks if _risk_value(r, "risk_level") == "YELLOW"]

    sentences: List[str] = [
        "Assalomu alaykum! LexGuard AI tahlil xulosasi tayyor.",
        f"Shartnomada jami {len(risks)} ta e'tibor talab qiladigan band aniqlandi." if risks
        else "Shartnomada e'tibor talab qiladigan band aniqlanmadi.",
    ]
    if summary_text:
        sentences.append(_first_sentence(summary_text, 240))
    if red:
        sentences.append(f"Shulardan {len(red)} tasi qizil darajadagi jiddiy xavf.")
        top = red[0]
        title = _risk_value(top, "issue_title")
        expl = _first_sentence(_risk_value(top, "issue_explanation"))
        sentences.append(f"Eng muhim xavf: {title}. {expl}".strip())
    elif risks:
        sentences.append("Qizil darajadagi jiddiy xavflar aniqlanmadi.")
    if yellow:
        sentences.append(f"Yana {len(yellow)} ta tijoriy muvozanatni tiklashga doir tavsiya bor.")
    if risks:
        sentences.append("Tavsiya etilgan tahrirlarni ekranda ko'rib chiqib, bir tugma bilan qabul qilishingiz mumkin.")
    sentences.append(DISCLAIMER_UZ)

    script = " ".join(sentences)
    ssml_body = "\n".join(
        f"    <s>{escape(s)}</s>" + ('\n    <break time="300ms"/>' if i == 0 else "")
        for i, s in enumerate(sentences)
    )
    ssml = f'<speak>\n  <prosody rate="medium">\n{ssml_body}\n  </prosody>\n</speak>'
    return {
        "audio_script_uz": script,
        "ssml": ssml,
        "duration_sec": max(8, len(script.split()) * 60 // 130),
    }


def answer_voice_query(query: str, graph, store) -> str:
    """
    Savolga qonunlar bazasidan asoslangan javob matni:
      - savolda aniq modda havolasi bo'lsa ("707-modda nima deydi?") — o'sha modda;
      - aks holda BM25 bo'yicha eng yaqin modda.
    """
    q = query.strip()
    if not q:
        return ""

    node = None
    m = _ARTICLE_REF_RE.search(q)
    if m:
        ref = f"{m.group(1)} {m.group(2)}" if m.group(1) else f"{m.group(2)}-modda"
        nid = graph.find_node_id(ref)
        node = graph.nodes.get(nid) if nid else None

    if node:
        return (f"{node['code']} («{node['title']}») bo'yicha: {node['summary']} "
                f"Batafsil: {node['url']}. {DISCLAIMER_UZ}")

    hits = store.search(q, top_k=1)
    if not hits:
        return "Ushbu savol bo'yicha qonunlar bazasidan ma'lumot topilmadi. Yurist maslahati tavsiya etiladi."
    h = hits[0]
    return (f"O'zbekiston Respublikasi {h['source_code']} {h['article_number']} («{h['title']}») bo'yicha: "
            f"{h['snippet'][:300]}. {DISCLAIMER_UZ}")


def chunk_words(text: str, size: int = 4) -> List[str]:
    words = text.split()
    return [" ".join(words[i:i + size]) + " " for i in range(0, len(words), size)]
