"""
LexGuard AI — Yagona shartnoma tahlil yadrosi.

REST (FastAPI), gRPC va stdlib server bir xil mantiqdan foydalanadi:
  1. Bandni gaplarga ajratish (asl matn saqlanadi — iqtibos aynan substring bo'ladi).
  2. Qoidalar katalogi (rules.py) shartnoma turiga mos ravishda qo'llanadi.
  3. Har bir topilma Knowledge Graph zanjiri (multi-hop) va rasmiy Lex.uz havolasi bilan boyitiladi.
  4. BM25 faqat "bog'liq normalar" sifatida qaytariladi (taxminiy xavf sifatida EMAS).
  5. Ixtiyoriy LLM (llm.py) faqat tushuntirish/redline ni sayqallaydi, moddalarni o'ylab topa olmaydi.
"""

import logging
import re
from dataclasses import dataclass, field, asdict
from typing import Any, Dict, Iterable, List, Optional, Tuple

from app.config import RELATED_NORM_MIN_SCORE
from app.rules import (
    CONTRACT_WORK, EMPLOYMENT, GENERAL, LEASE, RULES, RULES_BY_CODE, SALE, SERVICE, Rule, canonical_doc_type,
)
from app.parties import BOTH, PROVIDER, RECIPIENT, PROVIDER_RE, RECIPIENT_RE, has_prohibition, other, side_pair
from app.text_utils import normalize_text, split_sentences

logger = logging.getLogger("ai-engine-analyzer")

_SEVERITY_ORDER = {"RED": 0, "YELLOW": 1, "GREEN": 2, "GRAY": 3}

_SIDE_LABELS = {
    SERVICE: ("Ijrochiga", "Buyurtmachiga"),
    CONTRACT_WORK: ("Pudratchiga", "Buyurtmachiga"),
    SALE: ("Sotuvchiga", "Xaridorga"),
    LEASE: ("Ijaraga beruvchiga", "Ijarachiga"),
    EMPLOYMENT: ("Xodimga", "Ish beruvchiga"),
    GENERAL: ("Ijrochiga", "Buyurtmachiga"),
}
# Bosh kelishikdagi nomlar ("Ijrochi tomoniga og'ir")
SIDE_NAMES = {
    SERVICE: ("Ijrochi", "Buyurtmachi"),
    CONTRACT_WORK: ("Pudratchi", "Buyurtmachi"),
    SALE: ("Sotuvchi", "Xaridor"),
    LEASE: ("Ijaraga beruvchi", "Ijarachi"),
    EMPLOYMENT: ("Xodim", "Ish beruvchi"),
    GENERAL: ("Ijrochi", "Buyurtmachi"),
}
# Qarama-qarshilik bildiruvchi bog'lovchi bor gapda inkor butun gapni bekor qilmaydi ("... mumkin, ammo ... mumkin emas")
_CONTRAST_RE = re.compile(r"\bammo\b|\bbiroq\b|\blekin\b")
_ROLE_TO_SIDE = {"EXECUTOR": "PROVIDER", "CUSTOMER": "RECIPIENT"}


@dataclass
class ClauseIn:
    clause_id: str
    clause_number: str
    text: str


@dataclass
class Finding:
    clause_id: str
    clause_number: str
    risk_level: str
    category: str
    issue_title: str
    problematic_quote: str
    issue_explanation: str
    cited_article: str
    suggested_redline: str
    balance_label: str
    lex_uz_url: str
    multi_hop_chain: List[Dict[str, Any]] = field(default_factory=list)
    rule_code: str = ""
    norm_nature: str = "IMPERATIVE"
    confidence: float = 0.9
    source: str = "RULE"  # RULE | RULE+LLM | LLM_TRIAGE
    # Yuk qaysi tomonda: PROVIDER | RECIPIENT | BOTH (ikki tomonga teng) | None (aniqlanmadi yoki tomonga bog'liq emas)
    burdened_side: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class ClauseReport:
    clause_id: str
    clause_number: str
    status: str  # RULE_MATCHED | NO_RULE_MATCH
    findings: List[Finding] = field(default_factory=list)
    related_norms: List[Dict[str, Any]] = field(default_factory=list)


@dataclass
class _Hit:
    rule: Rule
    quote: str
    sentence_norm: str
    overrides: Dict[str, Any]
    single_sentence: bool


def slim_node(node: Dict[str, Any], relation: str = "", note: str = "") -> Dict[str, Any]:
    return {
        "id": node.get("id", ""),
        "code": node.get("code", ""),
        "title": node.get("title", ""),
        "law": node.get("law", ""),
        "url": node.get("url", ""),
        "summary": node.get("summary", ""),
        "relation": relation or node.get("relation", ""),
        "note": note or node.get("note", ""),
    }


class ClauseAnalyzer:
    def __init__(self, graph, store, refiner=None, rules: Tuple[Rule, ...] = RULES):
        self.graph = graph
        self.store = store
        self.refiner = refiner
        self.rules = rules

    # ------------------------------------------------------------------ qoidalarni qo'llash
    def _match_rule(self, rule: Rule, sentences: List[str], sentences_norm: List[str], clause_norm: str) -> Optional[_Hit]:
        def groups_match(text: str) -> bool:
            return all(any(p.search(text) for p in group) for group in rule.groups)

        if rule.mitigations and any(p.search(clause_norm) for p in rule.mitigations):
            if not any(p.search(clause_norm) for p in rule.mitigation_overrides):
                return None

        hit_idx, single = None, True
        for i, sn in enumerate(sentences_norm):
            if groups_match(sn):
                hit_idx = i
                break
        if hit_idx is None:
            # qoida bir necha gapga yoyilgan bo'lishi mumkin — butun band bo'yicha tekshiramiz
            if not groups_match(clause_norm):
                return None
            single = False
            first_group = rule.groups[0]
            for i, sn in enumerate(sentences_norm):
                if any(p.search(sn) for p in first_group):
                    hit_idx = i
                    break
            if hit_idx is None:
                hit_idx = 0

        sentence_norm = sentences_norm[hit_idx] if single else clause_norm
        # "Bir tomonlama bekor qilish taqiqlanadi" — xavfli huquq berilmagan, aksincha cheklangan
        hit_sentence = sentences_norm[hit_idx]
        if rule.kind == "right" and has_prohibition(hit_sentence) and not _CONTRAST_RE.search(hit_sentence):
            return None
        overrides: Dict[str, Any] = {}
        if rule.predicate is not None:
            res = rule.predicate(sentence_norm, clause_norm)
            if res is None:
                return None
            overrides = res
        return _Hit(rule, sentences[hit_idx], sentence_norm, overrides, single)

    def _balance(self, rule: Rule, doc_type: str, sentence_norm: str, party_role: str) -> Tuple[str, Optional[str]]:
        """(balans yorlig'i, yuk ko'taruvchi tomon). Simmetrik band — 'BOTH', tomonga bog'liq bo'lmagan qoida — None."""
        if rule.kind == "neutral":
            return "Muvozanatli", None
        first, symmetric = side_pair(sentence_norm)
        if symmetric:
            return "Muvozanatli (ikki tomonga teng)", BOTH
        if first is None:
            return "Taraflar muvozanati buzilgan", None
        burdened = first if rule.kind == "obligation" else other(first)
        names = _SIDE_LABELS.get(doc_type, _SIDE_LABELS[GENERAL])
        label = f"{names[0] if burdened == PROVIDER else names[1]} og'ir"
        if _ROLE_TO_SIDE.get((party_role or "").upper()) == burdened:
            label += " (sizning tomoningizga)"
        return label, burdened

    # ------------------------------------------------------------------ topilma qurish
    def _build_finding(self, hit: _Hit, clause: ClauseIn, doc_type: str, party_role: str) -> Finding:
        rule = hit.rule
        root_id = rule.root_by_doc.get(doc_type, rule.root)
        chain_res = self.graph.resolve_chain(root_id)
        chain = [slim_node(n) for n in chain_res.get("chain", [])]
        seen = {n["id"] for n in chain}
        for rid in rule.related:
            node = self.graph.nodes.get(rid)
            if node and rid not in seen:
                chain.append(slim_node(node, relation="related", note=node.get("title", "")))
                seen.add(rid)

        root_node = self.graph.nodes.get(root_id, {})
        related_text = "; ".join(f"{n['code']} — {n['title']}" for n in chain[1:5] if n.get("title"))
        explanation = rule.why
        if hit.overrides.get("detail"):
            explanation += " " + hit.overrides["detail"]
        if related_text:
            explanation += f" Bog'liq normalar: {related_text}."

        risk = hit.overrides.get("risk", rule.risk)
        nature = hit.overrides.get("norm_nature", rule.norm_nature)
        if nature == "DISPOSITIVE" and risk == "RED":
            risk = "YELLOW"  # dispozitiv norma buzilishi RED bo'lmaydi

        redline = rule.redline_by_doc.get(doc_type) or rule.redline or root_node.get("remedy_clause", "")
        balance_label, burdened_side = self._balance(rule, doc_type, hit.sentence_norm, party_role)
        return Finding(
            clause_id=clause.clause_id,
            clause_number=clause.clause_number,
            risk_level=risk,
            category=rule.category,
            issue_title=rule.title,
            problematic_quote=hit.quote,
            issue_explanation=explanation,
            cited_article=chain_res.get("root_article") or root_node.get("code", ""),
            suggested_redline=redline,
            balance_label=balance_label,
            burdened_side=burdened_side,
            lex_uz_url=chain_res.get("url") or root_node.get("url", "https://lex.uz"),
            multi_hop_chain=chain,
            rule_code=rule.code,
            norm_nature=nature,
            confidence=0.9 if hit.single_sentence else 0.75,
        )

    # ------------------------------------------------------------------ bandni tahlil qilish
    def analyze_clause(
        self, clause: ClauseIn, doc_type: str = "", party_role: str = "", use_llm: bool = True, collapse_variants: bool = True,
    ) -> ClauseReport:
        doc = canonical_doc_type(doc_type)
        text = clause.text or ""
        sentences = split_sentences(text) or [text]
        sentences_norm = [normalize_text(s) for s in sentences]
        clause_norm = normalize_text(text)

        findings: List[Finding] = []
        for rule in self.rules:
            if not rule.applies(doc):
                continue
            hit = self._match_rule(rule, sentences, sentences_norm, clause_norm)
            if hit:
                findings.append(self._build_finding(hit, clause, doc, party_role))

        findings = self._dedupe(findings, collapse_variants)
        related = self._related_norms(text, exclude={f.cited_article for f in findings})

        if use_llm and self.refiner is not None:
            findings = self._refine(findings, clause, related)
            if not findings and related:
                triage = self.refiner.triage(clause.text, related, self.graph)
                if triage:
                    findings.append(self._finding_from_triage(triage, clause))

        findings.sort(key=lambda f: _SEVERITY_ORDER.get(f.risk_level, 9))
        return ClauseReport(
            clause_id=clause.clause_id,
            clause_number=clause.clause_number,
            status="RULE_MATCHED" if findings else "NO_RULE_MATCH",
            findings=findings,
            related_norms=related,
        )

    @staticmethod
    def _dedupe(findings: List[Finding], collapse_variants: bool = True) -> List[Finding]:
        best: Dict[str, Finding] = {}
        for f in findings:
            cur = best.get(f.cited_article)
            if cur is None or _SEVERITY_ORDER.get(f.risk_level, 9) < _SEVERITY_ORDER.get(cur.risk_level, 9):
                best[f.cited_article] = f
        out = list(best.values())
        if collapse_variants:
            # xizmat-xos qoida topilganda uning umumiy varianti (masalan FK 237) takrorlanmaydi
            superseded = {code for f in out if f.rule_code in RULES_BY_CODE for code in RULES_BY_CODE[f.rule_code].supersedes}
            out = [f for f in out if f.rule_code not in superseded]
        return out

    def _related_norms(self, text: str, exclude: set, top_k: int = 3) -> List[Dict[str, Any]]:
        out = []
        for h in self.store.search(text, top_k=top_k + len(exclude)):
            if h["score"] < RELATED_NORM_MIN_SCORE:
                continue
            code = f"{h['source_code']} {h['article_number']}"
            if code in exclude:
                continue
            out.append({
                "id": h["id"], "code": code, "title": h["title"], "score": h["score"],
                "url": h["official_url"], "snippet": h["snippet"],
            })
            if len(out) >= top_k:
                break
        return out

    # ------------------------------------------------------------------ LLM integratsiyasi
    def _refine(self, findings: List[Finding], clause: ClauseIn, related: List[Dict[str, Any]]) -> List[Finding]:
        for f in findings:
            allowed = {n["code"] for n in f.multi_hop_chain} | {r["code"] for r in related}
            try:
                res = self.refiner.refine(clause.text, f, allowed)
            except Exception as e:  # LLM xatosi tahlilni to'xtatmasligi kerak
                logger.warning("LLM refine xatosi (qoidaviy natija saqlandi): %s", e)
                res = None
            if res:
                f.issue_explanation = res.get("explanation") or f.issue_explanation
                f.suggested_redline = res.get("redline") or f.suggested_redline
                f.source = "RULE+LLM"
        return findings

    def _finding_from_triage(self, triage: Dict[str, Any], clause: ClauseIn) -> Finding:
        node = self.graph.nodes[triage["node_id"]]
        chain_res = self.graph.resolve_chain(triage["node_id"])
        return Finding(
            clause_id=clause.clause_id, clause_number=clause.clause_number,
            risk_level="YELLOW",  # LLM qoida tasdig'isiz RED bera olmaydi
            category="LEGAL",
            issue_title=triage.get("title") or f"{node.get('title', '')} bo'yicha tekshiruv talab etiladi",
            problematic_quote=clause.text[:300],
            issue_explanation=triage.get("explanation", ""),
            cited_article=node.get("code", ""),
            suggested_redline=triage.get("redline", ""),
            balance_label="Muvozanatli",
            lex_uz_url=node.get("url", "https://lex.uz"),
            multi_hop_chain=[slim_node(n) for n in chain_res.get("chain", [])],
            rule_code="LLM_TRIAGE", norm_nature="DISPOSITIVE", confidence=0.6, source="LLM_TRIAGE",
        )

    # ------------------------------------------------------------------ hujjat darajasida
    def analyze(self, clauses: Iterable[ClauseIn], doc_type: str = "", party_role: str = "", use_llm: bool = True) -> List[ClauseReport]:
        return [self.analyze_clause(c, doc_type, party_role, use_llm) for c in clauses]

    # ------------------------------------------------------------------ Active Self-Correction
    def self_correct(
        self, clause_text: str, previous_cited: str = "", verification_error: str = "",
        candidates: Optional[List[str]] = None, doc_type: str = "", party_role: str = "",
    ) -> Optional[Finding]:
        """
        Go verifikatori keltirilgan moddani rad etganda to'g'ri normani topadi:
          1. qoidalar topilmasi (nomzod moddalar bilan kesishsa — ustuvor);
          2. nomzodlar ichidan band matniga leksik jihatdan eng yaqini (BM25);
          3. butun korpus bo'yicha eng yaqin norma.
        Avval rad etilgan modda (previous_cited) nomzodlardan chiqarib tashlanadi.
        """
        prev_id = self.graph.find_node_id(previous_cited) if previous_cited else None
        cand_ids = []
        for c in candidates or []:
            nid = self.graph.find_node_id(c)
            if nid and nid != prev_id and nid not in cand_ids:
                cand_ids.append(nid)

        clause = ClauseIn("self-correct", "", clause_text)
        # shartnoma turi noma'lum bo'lsa barcha qoidalar tekshiriladi, nomzod moddalar esa mosini tanlaydi
        report = self.analyze_clause(clause, doc_type or "ANY", party_role, collapse_variants=False)
        findings = [f for f in report.findings if self.graph.find_node_id(f.cited_article) != prev_id]
        if findings:
            for f in findings:
                if self.graph.find_node_id(f.cited_article) in cand_ids:
                    return f
            return findings[0]

        if cand_ids:
            scored = sorted(((self.store.score_document(clause_text, nid), nid) for nid in cand_ids), reverse=True)
            if scored and scored[0][0] > 0:
                return self._review_finding(clause, scored[0][1], verification_error)

        for h in self.store.search(clause_text, top_k=3):
            if h["id"] != prev_id and h["score"] >= RELATED_NORM_MIN_SCORE / 2:
                return self._review_finding(clause, h["id"], verification_error)
        return None

    def _review_finding(self, clause: ClauseIn, node_id: str, verification_error: str) -> Finding:
        node = self.graph.nodes[node_id]
        chain_res = self.graph.resolve_chain(node_id)
        reason = f" Verifikator xatosi: {verification_error}." if verification_error else ""
        return Finding(
            clause_id=clause.clause_id, clause_number=clause.clause_number,
            risk_level="YELLOW", category="LEGAL",
            issue_title=f"{node.get('title', '')} — huquqshunos ko'rigi tavsiya etiladi",
            problematic_quote=clause.text[:300],
            issue_explanation=(f"Band matniga leksik jihatdan eng yaqin norma: {node.get('code')} («{node.get('title')}»).{reason} "
                               + (chain_res.get("combined_explanation") or node.get("summary", ""))),
            cited_article=node.get("code", ""),
            suggested_redline=chain_res.get("suggested_redline", ""),
            balance_label="Muvozanatli",
            lex_uz_url=node.get("url", "https://lex.uz"),
            multi_hop_chain=[slim_node(n) for n in chain_res.get("chain", [])],
            rule_code="SELF_CORRECT_REVIEW", norm_nature="DISPOSITIVE", confidence=0.55, source="RULE",
        )


# ----------------------------------------------------------------------------------------
# Singleton (graf va indeks bir marta yuklanadi)
# ----------------------------------------------------------------------------------------
from app.knowledge_graph import legal_graph  # noqa: E402
from app.vector_store import legal_vector_store  # noqa: E402
from app.llm import get_refiner  # noqa: E402

analyzer = ClauseAnalyzer(legal_graph, legal_vector_store, refiner=get_refiner())
