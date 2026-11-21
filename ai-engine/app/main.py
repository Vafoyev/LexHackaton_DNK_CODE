"""
LexGuard AI — AI Engine Server (FastAPI + gRPC + Legal Knowledge Graph + Vector Store)
Muallif: AI & Legal Engineering Group
Vazifasi: Lex.uz 2,058 ta qonunlari zanjiri (Knowledge Graph), BM25 qidiruv va Active Self-Correction servisi
"""

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import uvicorn
import logging
from app.knowledge_graph import legal_graph
from app.vector_store import legal_vector_store

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ai-engine")

app = FastAPI(
    title="LexGuard AI Engine API",
    description="Legal Knowledge Graph, 2,058 Laws Index, Multi-Hop Law Resolution and Active Self-Correction",
    version="4.2.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ClauseInput(BaseModel):
    clause_id: str
    clause_number: str
    text: str

class AnalysisRequest(BaseModel):
    analysis_id: str
    document_type: str = "B2B_SERVICE"
    contract_date: str = "2026-11-21"
    clauses: List[ClauseInput]

class FindingOutput(BaseModel):
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
    multi_hop_chain: List[Dict[str, Any]] = []

class SelfCorrectionRequest(BaseModel):
    clause_text: str
    previous_cited_article: str
    verification_error: str
    candidate_articles: List[str] = []

@app.get("/health")
def health_check():
    total_edges = sum(len(edges) for edges in legal_graph.edges.values())
    return {
        "status": "UP",
        "service": "lexguard-ai-engine",
        "version": "4.2.0",
        "indexed_articles": len(legal_graph.nodes),
        "knowledge_graph_edges": total_edges,
        "vector_vocabulary_terms": len(legal_vector_store.doc_freqs),
        "active_training_pairs": 3234
    }

@app.get("/api/v1/corpus-stats")
def corpus_stats():
    return {
        "total_laws": 10,
        "total_articles": len(legal_graph.nodes),
        "cross_reference_edges": sum(len(edges) for edges in legal_graph.edges.values()),
        "fine_tuning_pairs": 3234,
        "sharegpt_dialogues": 2062,
        "sources": [
            {"code": "FK-UZ-1", "name": "Fuqarolik Kodeksi (1-qism)", "articles": 375},
            {"code": "FK-UZ-2", "name": "Fuqarolik Kodeksi (2-qism)", "articles": 803},
            {"code": "MK-2022", "name": "Mehnat Kodeksi (Yangi tahrir)", "articles": 580},
            {"code": "670-I", "name": "Shartnomaviy-huquqiy baza to'g'risida Qonun", "articles": 36},
            {"code": "221-I", "name": "Iste'molchilarning huquqlarini himoya qilish", "articles": 30},
            {"code": "ORQ-547", "name": "Shaxsga doir ma'lumotlar to'g'risida", "articles": 36},
            {"code": "ORQ-482", "name": "Mediatsiya to'g'risida", "articles": 33},
            {"code": "ORQ-792", "name": "Elektron tijorat to'g'risida", "articles": 33},
            {"code": "ORQ-850", "name": "Raqobat to'g'risida", "articles": 47},
            {"code": "ORQ-684", "name": "Davlat xaridlari to'g'risida", "articles": 85}
        ]
    }

@app.get("/api/v1/search-laws")
def search_laws(q: str = Query(..., description="Qidiruv so'rovi yoki shartnoma bandi matni"), top_k: int = 5):
    """
    2,058 ta moddalar bo'yicha BM25 gibrid qidiruv.
    """
    results = legal_vector_store.search(q, top_k=top_k)
    return {
        "query": q,
        "hits_count": len(results),
        "results": results
    }

@app.get("/api/v1/multi-hop-chain/{article_code}")
def get_multi_hop_chain(article_code: str):
    """
    Moddalar zanjirini (Multi-hop cross references) yechish.
    """
    res = legal_graph.resolve_chain(article_code)
    if not res.get("found"):
        raise HTTPException(status_code=404, detail=f"'{article_code}' bo'yicha norma zanjiri topilmadi.")
    return res

@app.post("/api/v1/analyze-clauses")
def analyze_clauses(req: AnalysisRequest):
    """
    Shartnoma bandlarini Legal Knowledge Graph va Vector Store orqali
    ko'p bosqichli tahlil qilish (Red/Green Redlines + Multi-Hop Cross-References).
    """
    findings = []
    
    for c in req.clauses:
        # 1. Ekspert Knowledge Graph orqali tekshirish
        eval_res = legal_graph.evaluate_clause_text(c.text)
        
        # 2. Agar bevosita ekspert qoidasiga tushmasa, BM25 Vector Store orqali qidirish
        if not eval_res or not eval_res.get("found"):
            hits = legal_vector_store.search(c.text, top_k=1)
            if hits and hits[0]["score"] > 18.0:
                top_hit = hits[0]
                chain_res = legal_graph.resolve_chain(top_hit["article_number"])
                eval_res = {
                    "found": True,
                    "root_article": f"{top_hit['source_code']} {top_hit['article_number']}",
                    "root_title": top_hit["title"],
                    "url": top_hit["official_url"],
                    "risk_level": "YELLOW",
                    "category": "COMPLIANCE",
                    "issue_title": f"{top_hit['title']} talablariga nomuvofiqlik ehtimoli",
                    "combined_explanation": f"Ushbu band {top_hit['source_code']} {top_hit['article_number']} («{top_hit['title']}») doirasidagi imperativ talablarga mos kelishi tekshirilishi lozim. {top_hit['snippet']}",
                    "suggested_redline": f"Band matni O'zbekiston qonunchiligining {top_hit['article_number']} talablariga muvofiqlashtirilishi tavsiya etiladi.",
                    "chain": chain_res.get("chain", [])
                }

        if eval_res and eval_res.get("found"):
            findings.append(FindingOutput(
                clause_id=c.clause_id,
                clause_number=c.clause_number,
                risk_level=eval_res.get("risk_level", "YELLOW"),
                category=eval_res.get("category", "LEGAL"),
                issue_title=eval_res.get("issue_title", "Qonuniy nomutanosiblik"),
                problematic_quote=c.text,
                issue_explanation=eval_res.get("combined_explanation", ""),
                cited_article=eval_res.get("root_article", ""),
                suggested_redline=eval_res.get("suggested_redline", ""),
                balance_label="Ijrochiga nomutanosib og'ir",
                lex_uz_url=eval_res.get("url", "https://lex.uz"),
                multi_hop_chain=eval_res.get("chain", [])
            ))

    return {
        "analysis_id": req.analysis_id,
        "total_clauses": len(req.clauses),
        "findings_count": len(findings),
        "findings": findings
    }

@app.post("/api/v1/self-correct")
def self_correct(req: SelfCorrectionRequest):
    """
    Active Self-Correction: Agar modda verifikatsiyadan o'tmasa,
    AI Knowledge Graph orqali yangi moddalar bilan qayta tahlil qiladi.
    """
    eval_res = legal_graph.evaluate_clause_text(req.clause_text)
    if eval_res and eval_res.get("found"):
        return {
            "resolved": True,
            "corrected_article": eval_res.get("root_article"),
            "explanation": eval_res.get("combined_explanation"),
            "suggested_redline": eval_res.get("suggested_redline")
        }
    
    # Vector store orqali eng yaqin qonunni topish
    hits = legal_vector_store.search(req.clause_text, top_k=1)
    if hits:
        hit = hits[0]
        return {
            "resolved": True,
            "corrected_article": f"{hit['source_code']} {hit['article_number']}",
            "explanation": f"Leksik tahlil asosida muqobil norma topildi: {hit['title']}. {hit['snippet']}",
            "suggested_redline": "Band matnini ushbu norma talablariga moslashtirish tavsiya etiladi."
        }
    
    return {
        "resolved": False,
        "message": "Bog'langan qonun topilmadi, huquqshunos ko'rigi talab etiladi (UNKNOWN)."
    }

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
