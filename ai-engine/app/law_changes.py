"""
LexGuard AI — O'zgargan normalar tasmasi (korpusdagi Lex.uz tahrir izohlaridan).

Korpus matnlarida har bir modda uchun tahrir izohlari saqlangan, masalan:
  "(2-moddaning beshinchi qismi Oʻzbekiston Respublikasining 2025-yil 23-iyundagi OʻRQ-1070-sonli Qonuni tahririda — ...
   Kuchga kirish sanasi — 2025-yil 25-sentabr)"
Bu modul shu izohlarni tahlil qilib, qaysi modda qaysi qonun bilan va qachon o'zgartirilganini qaytaradi.

Cheklov: bu — korpus nusxasi (snapshot) ichidagi izohlar, jonli Lex.uz oqimi emas. `snapshot_latest` korpusdagi eng so'nggi
o'zgarish sanasini ko'rsatadi, ma'lumot shu sanadan keyin yangilanmagan bo'lishi mumkin.
"""

import re
from dataclasses import dataclass
from datetime import date
from typing import Any, Dict, List, Optional, Set, Tuple

from app.chat import clean_article_text
from app.knowledge_graph import legal_graph
from app.rules import RULES

_NOTE_RE = re.compile(r"\(([^()]*?sonli[^()]*?(?:tahririda|tahrirda)[^()]*)\)")
_DATE_RE = re.compile(r"(\d{4})-yil\s+(\d{1,2})-([A-Za-zʻʼ'’]+)")
_NUMERIC_DATE_RE = re.compile(r"(\d{1,2})\.(\d{1,2})\.(\d{4})-y")
# "OʻRQ-1070-sonli", "OʻRQ 1154-sonli" (bo'shliq bilan), eski shakl "832-I-sonli"
_LAW_NO_RE = re.compile(r"((?:[A-ZʻʼO'’]{2,5}[\s-]\d+)|(?:\d+-[IVX]+))-sonli\s+([A-Za-zʻʼ'’ ]+?)\s+(?:tahririda|tahrirda)")
_KIND_NORMAL = {"Qonuni": "Qonun", "Farmoni": "Farmon", "Qarori": "Qaror", "Konstitutsiyaviy Qonuni": "Konstitutsiyaviy qonun"}
_PART_RE = re.compile(r"^\s*(\d+-modda\w*(?:\s+[a-zʻʼ'’]+\s+qismi)?)")
_EFFECTIVE_RE = re.compile(r"Kuchga kirish sanasi\s*[—-]\s*(\d{4})-yil\s+(\d{1,2})-([A-Za-zʻʼ'’]+)")

_MONTH_PREFIX = (
    ("yan", 1), ("fev", 2), ("mar", 3), ("apr", 4), ("may", 5), ("iyun", 6), ("iyul", 7),
    ("avg", 8), ("sen", 9), ("okt", 10), ("noy", 11), ("dek", 12),
)


def _month(word: str) -> Optional[int]:
    w = word.lower()
    for prefix, num in _MONTH_PREFIX:
        if w.startswith(prefix):
            return num
    return None


def _to_date(year: str, day: str, month_word: str) -> Optional[date]:
    m = _month(month_word)
    if not m:
        return None
    try:
        return date(int(year), m, int(day))
    except ValueError:
        return None


@dataclass(frozen=True)
class Amendment:
    changed_on: date                 # o'zgartirgan qonun qabul qilingan sana
    amended_by: str                  # masalan "OʻRQ-1070"
    amended_by_kind: str             # "Qonun", "Konstitutsiyaviy Qonun", ...
    effective_from: Optional[date]
    part: str                        # "2-moddaning beshinchi qismi"


def parse_notes(full_text: str) -> List[Amendment]:
    """Modda matnidagi tahrir izohlarini ajratib oladi (tahlil qilib bo'lmaydigan izohlar tashlanadi)."""
    out: List[Amendment] = []
    for note in _NOTE_RE.findall(full_text or ""):
        d = _DATE_RE.search(note)
        changed = _to_date(*d.groups()) if d else None
        if changed is None:
            n = _NUMERIC_DATE_RE.search(note)
            if n:
                try:
                    changed = date(int(n.group(3)), int(n.group(2)), int(n.group(1)))
                except ValueError:
                    changed = None
        law = _LAW_NO_RE.search(note)
        if changed is None or law is None:
            continue
        eff = _EFFECTIVE_RE.search(note)
        part = _PART_RE.match(note)
        out.append(Amendment(
            changed_on=changed,
            amended_by=re.sub(r"\s+", "-", law.group(1).strip()),
            amended_by_kind=_KIND_NORMAL.get(law.group(2).strip(), law.group(2).strip()),
            effective_from=_to_date(*eff.groups()) if eff else None,
            # kesilgan yoki noaniq matnlar ("398-moddaning") ko'rsatilmaydi; faqat "... qismi" aniq bo'lsa
            part=part.group(1).strip() if part and "qism" in part.group(1) else "",
        ))
    return out


def _build_index() -> Tuple[List[Dict[str, Any]], Optional[date]]:
    used: Set[str] = set()
    for r in RULES:
        used.add(r.root)
        used.update(r.related)
        used.update(r.root_by_doc.values())

    items: List[Dict[str, Any]] = []
    for node_id, node in legal_graph.nodes.items():
        amendments = parse_notes(node.get("full_text", ""))
        if not amendments:
            continue
        latest = max(amendments, key=lambda a: a.changed_on)
        parts = sorted({a.part for a in amendments if a.part and a.changed_on == latest.changed_on and a.amended_by == latest.amended_by})
        items.append({
            "id": node_id,
            "code": node["code"],
            "source_code": node["source_code"],
            "law": node.get("law", ""),
            "title": node.get("title", ""),
            "changed_on": latest.changed_on.isoformat(),
            "amended_by": latest.amended_by,
            "amended_by_kind": latest.amended_by_kind,
            "effective_from": latest.effective_from.isoformat() if latest.effective_from else None,
            "changed_parts": parts,
            "changes_total": len(amendments),
            "used_in_analysis": node_id in used,
            "url": node.get("url", ""),
            "snippet": clean_article_text(node.get("full_text", ""), 180),
        })
    items.sort(key=lambda i: (i["changed_on"], i["id"]), reverse=True)
    snapshot = date.fromisoformat(items[0]["changed_on"]) if items else None
    return items, snapshot


_ITEMS, _SNAPSHOT_LATEST = _build_index()


def list_changes(limit: int = 20, source: str = "", since: Optional[date] = None, only_used: bool = False) -> Dict[str, Any]:
    """
    Eng so'nggi o'zgargan normalar (har bir modda bir marta, eng oxirgi o'zgarishi bilan) va o'zgartirgan qonunlar bo'yicha guruhlar.
    """
    limit = max(1, min(int(limit), 100))
    items = _ITEMS
    if source:
        items = [i for i in items if i["source_code"].lower() == source.lower()]
    if since:
        items = [i for i in items if i["changed_on"] >= since.isoformat()]
    if only_used:
        items = [i for i in items if i["used_in_analysis"]]

    groups: Dict[Tuple[str, str], Dict[str, Any]] = {}
    for i in items:
        g = groups.setdefault((i["amended_by"], i["changed_on"]), {
            "amended_by": i["amended_by"], "kind": i["amended_by_kind"], "changed_on": i["changed_on"],
            "effective_from": i["effective_from"], "articles_count": 0, "sample": [],
        })
        g["articles_count"] += 1
        if len(g["sample"]) < 3:
            g["sample"].append(i["code"])
    laws = sorted(groups.values(), key=lambda g: (g["changed_on"], g["amended_by"]), reverse=True)[:10]

    return {
        "snapshot_latest": _SNAPSHOT_LATEST.isoformat() if _SNAPSHOT_LATEST else None,
        "total_changed_articles": len(items),
        "affecting_analysis": sum(1 for i in items if i["used_in_analysis"]),
        "items": items[:limit],
        "laws": laws,
        "source_note": "Ma’lumot korpusdagi Lex.uz tahrir izohlaridan olingan (nusxa sanasigacha); jonli yangilanish emas.",
    }
