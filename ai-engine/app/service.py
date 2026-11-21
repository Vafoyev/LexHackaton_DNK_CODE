"""
LexGuard AI — Transport qatlamlariga (FastAPI, stdlib HTTP, gRPC) umumiy servis funksiyalari.
Bir xil mantiq bir joyda: javob shakllari REST va gRPC o'rtasida farq qilmaydi.
"""

import functools
from collections import Counter
from typing import Any, Dict, List

from app import config
from app.analyzer import ClauseIn, ClauseReport, analyzer
from app.balance import compute_balance
from app import law_changes
from app.knowledge_graph import legal_graph
from app.rules import RULES
from app.vector_store import legal_vector_store

_SEVERITY_ORDER = {"RED": 0, "YELLOW": 1, "GREEN": 2, "GRAY": 3}


@functools.lru_cache(maxsize=1)
def dataset_counts() -> Dict[str, int]:
    """Fine-tuning dataset hajmlari (fayl qatorlari soni) — qattiq kodlangan raqamlar o'rniga."""
    def lines(name: str) -> int:
        path = config.DATA_DIR / name
        if not path.exists():
            return 0
        with open(path, "rb") as f:
            return sum(1 for ln in f if ln.strip())

    return {
        "fine_tuning_pairs": lines("legal_instructions_train.jsonl"),
        "sharegpt_dialogues": lines("legal_sharegpt_train.jsonl"),
        "cross_ref_eval": lines("legal_cross_ref_eval.jsonl"),
    }


def edge_count() -> int:
    return sum(len(e) for e in legal_graph.edges.values())


def health() -> Dict[str, Any]:
    return {
        "status": "UP",
        "service": "lexguard-ai-engine",
        "version": "5.0.0",
        "indexed_articles": len(legal_graph.nodes),
        "knowledge_graph_edges": edge_count(),
        "vector_vocabulary_terms": len(legal_vector_store.doc_freqs),
        "active_training_pairs": dataset_counts()["fine_tuning_pairs"],
        "rules_loaded": len(RULES),
        "llm_provider": config.LLM_PROVIDER,
        "llm_enabled": analyzer.refiner is not None,
    }


def corpus_stats() -> Dict[str, Any]:
    per_source = Counter(n["source_code"] for n in legal_graph.nodes.values())
    names: Dict[str, str] = {}
    for n in legal_graph.nodes.values():
        names.setdefault(n["source_code"], n.get("law", n["source_code"]))
    counts = dataset_counts()
    return {
        "total_laws": len(per_source),
        "total_articles": len(legal_graph.nodes),
        "cross_reference_edges": edge_count(),
        "fine_tuning_pairs": counts["fine_tuning_pairs"],
        "sharegpt_dialogues": counts["sharegpt_dialogues"],
        "sources": [{"code": c, "name": names[c], "articles": per_source[c]} for c in sorted(per_source)],
    }


def rules_catalog() -> List[Dict[str, Any]]:
    out = []
    for r in RULES:
        root = legal_graph.nodes.get(r.root, {})
        out.append({
            "code": r.code,
            "title": r.title,
            "risk_level": r.risk,
            "category": r.category,
            "norm_nature": r.norm_nature,
            "applies_to": sorted(r.applies_to) or ["ALL"],
            "root_article": root.get("code", r.root),
            "related_articles": [legal_graph.nodes[x]["code"] for x in r.related if x in legal_graph.nodes],
            "url": root.get("url", ""),
        })
    return out


def _report_to_dict(rep: ClauseReport) -> Dict[str, Any]:
    return {
        "clause_id": rep.clause_id,
        "clause_number": rep.clause_number,
        "status": rep.status,
        "findings_count": len(rep.findings),
        "related_norms": rep.related_norms,
    }


def analyze_request(
    analysis_id: str, clauses: List[Dict[str, Any]], document_type: str = "", party_role: str = "",
    use_llm: bool = True,
) -> Dict[str, Any]:
    reports = analyzer.analyze(
        [ClauseIn(c["clause_id"], c.get("clause_number", ""), c["text"]) for c in clauses],
        document_type, party_role, use_llm,
    )
    clause_ins = [ClauseIn(c["clause_id"], c.get("clause_number", ""), c["text"]) for c in clauses]
    findings = [f.to_dict() for rep in reports for f in rep.findings]
    findings.sort(key=lambda f: _SEVERITY_ORDER.get(f["risk_level"], 9))
    counts = Counter(f["risk_level"] for f in findings)
    return {
        "analysis_id": analysis_id,
        "total_clauses": len(clauses),
        "findings_count": len(findings),
        "risk_summary": {"RED": counts.get("RED", 0), "YELLOW": counts.get("YELLOW", 0)},
        "findings": findings,
        "clause_reports": [_report_to_dict(r) for r in reports],
        "balance": compute_balance(clause_ins, reports, document_type, party_role),
    }


def balance_request(clauses: List[Dict[str, Any]], document_type: str = "", party_role: str = "", use_llm: bool = False) -> Dict[str, Any]:
    """Faqat balans tahlili (butun hujjat bandlari bo'yicha)."""
    clause_ins = [ClauseIn(c.get("clause_id") or str(i), c.get("clause_number", ""), c["text"]) for i, c in enumerate(clauses, 1)]
    reports = analyzer.analyze(clause_ins, document_type, party_role, use_llm)
    return compute_balance(clause_ins, reports, document_type, party_role)


def law_changes_request(limit: int = 20, source: str = "", since: str = "", only_used: bool = False) -> Dict[str, Any]:
    """O'zgargan normalar tasmasi. `since` — ISO sana (YYYY-MM-DD); noto'g'ri bo'lsa ValueError."""
    from datetime import date
    since_date = date.fromisoformat(since) if since else None
    return law_changes.list_changes(limit, source, since_date, only_used)


def self_correct_request(
    clause_text: str, previous_cited_article: str = "", verification_error: str = "",
    candidate_articles: List[str] = None, document_type: str = "", party_role: str = "",
) -> Dict[str, Any]:
    f = analyzer.self_correct(
        clause_text, previous_cited_article, verification_error, candidate_articles or [], document_type, party_role,
    )
    if f is None:
        return {"resolved": False, "message": "Bog'langan qonun topilmadi, huquqshunos ko'rigi talab etiladi (UNKNOWN)."}
    return {
        "resolved": True,
        "corrected_article": f.cited_article,
        "explanation": f.issue_explanation,
        "suggested_redline": f.suggested_redline,
        "risk_level": f.risk_level,
        "category": f.category,
        "issue_title": f.issue_title,
        "lex_uz_url": f.lex_uz_url,
        "rule_code": f.rule_code,
    }
