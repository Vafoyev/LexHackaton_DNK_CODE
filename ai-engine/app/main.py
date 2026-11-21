"""
LexGuard AI — AI Engine Server (FastAPI + gRPC + Legal Knowledge Graph + Vector Store)
Muallif: AI & Legal Engineering Group
Vazifasi: Lex.uz 2,058 ta qonunlari zanjiri (Knowledge Graph), BM25 qidiruv, Active Self-Correction va gRPC servisi
"""

import os
import sys
import logging
import threading
from contextlib import asynccontextmanager
from typing import List, Optional, Dict, Any

from fastapi import FastAPI, HTTPException, Query, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

from app.knowledge_graph import legal_graph
from app.local_model_runtime import local_neural_runtime
from app.notarial_classifier import classify_document_form
from app.slm_runtime import slm_runtime
from app.vector_store import legal_vector_store
from app.ocr import ocr_processor
from app.grpc_server import serve_grpc

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ai-engine")

grpc_server_instance = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Start gRPC server on port 50051 in background thread
    global grpc_server_instance
    grpc_port = int(os.getenv("GRPC_PORT", "50051"))
    try:
        grpc_server_instance = serve_grpc(grpc_port)
        logger.info(f"✅ Background gRPC Server port {grpc_port} da faollashtirildi.")
    except Exception as e:
        logger.error(f"⚠️ gRPC serverni ishga tushirishda xatolik: {e}")

    yield

    # Shutdown: Stop gRPC server
    if grpc_server_instance:
        logger.info("gRPC server to'xtatilmoqda...")
        grpc_server_instance.stop(0)

app = FastAPI(
    title="LexGuard AI Engine API",
    description="Legal Knowledge Graph, 2,058 Laws Index, Multi-Hop Law Resolution, Active Self-Correction & gRPC Service",
    version="4.2.0",
    lifespan=lifespan
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

class VoiceBriefRequestModel(BaseModel):
    analysis_id: str
    summary_text: str = ""
    top_risks: List[Dict[str, Any]] = []

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
        "active_training_pairs": 3234,
        "local_neural_model_ready": local_neural_runtime.is_ready,
        "local_neural_eval_metrics": local_neural_runtime.eval_metrics,
        "slm_adapter_ready": slm_runtime.adapter_ready,
        "grpc_active": grpc_server_instance is not None
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

@app.get("/api/v1/verify-citation")
def verify_citation(article: str = Query(..., description="Tekshiriladigan modda kodi (masalan: FK-UZ-2 707-modda)")):
    """
    Closed-World Allowlist Verifier: modda Lex.uz bazamizda haqiqatan mavjudligini tasdiqlaydi.
    """
    chain = legal_graph.resolve_chain(article)
    if not chain.get("found"):
        return {"verified": False, "status": "UNKNOWN", "message": "Manba tasdiqlanmadi («0» xulosa)."}
    return {
        "verified": True,
        "status": "VERIFIED",
        "root_article": chain.get("root_article"),
        "root_title": chain.get("root_title"),
        "url": chain.get("url"),
        "chain_depth": len(chain.get("chain", [])),
    }


class ClassifyFormRequest(BaseModel):
    text: str
    document_type: str = ""


@app.post("/api/v1/classify-form")
def classify_form(req: ClassifyFormRequest):
    """
    3-qavatli Notarial vs Oddiy Shartnoma aniqlash endpointi.
    """
    return classify_document_form(req.text, req.document_type)


@app.post("/api/v1/analyze-clauses")
def analyze_clauses(req: AnalysisRequest):
    """
    Shartnoma bandlarini Legal Knowledge Graph, 3-Layer Notarial Classifier,
    Vector Store va Anti-Hallucination Closed-World Verifier orqali tahlil qilish.
    """
    full_doc_text = "\n".join(c.text for c in req.clauses)
    doc_form = classify_document_form(full_doc_text, req.document_type)
    doc_has_notarial_proof = doc_form["detected_form"] == "NOTARIAL_DOCUMENT"

    findings = []

    for c in req.clauses:
        # 1. Ekspert Knowledge Graph (Kirill/Lotin normalizatsiyasi + Xorijiy qonun fail-closed + Notarial kontekst)
        eval_res = legal_graph.evaluate_clause_text(c.text, doc_has_notarial_proof=doc_has_notarial_proof)

        # 2. Local PyTorch Multi-Task Neural Model (yangi parafraza/imlo xatoli bandlar uchun, Closed-World Verifier bilan!)
        if not eval_res or not eval_res.get("found"):
            nn_res = local_neural_runtime.predict_clause(c.text, min_confidence=0.78)
            if nn_res and nn_res.get("found"):
                eval_res = nn_res

        # 3. Agar ekspert va neyron model ham aniq topmasa, qat'iy chegara (score > 22.0) bilan BM25 + Allowlist Verifier
        if not eval_res or not eval_res.get("found"):
            hits = legal_vector_store.search(c.text, top_k=1)
            if hits and hits[0]["score"] > 22.0:
                top_hit = hits[0]
                cited = f"{top_hit['source_code']} {top_hit['article_number']}"
                if legal_graph.verify_citation(cited):
                    chain_res = legal_graph.resolve_chain(top_hit["id"] or cited)
                    eval_res = {
                        "found": True,
                        "root_article": cited,
                        "root_title": top_hit["title"],
                        "url": top_hit["official_url"],
                        "risk_level": "YELLOW",
                        "category": "COMMERCIAL",
                        "balance_label": "Muvozanatli",
                        "issue_title": f"{top_hit['title']} bo'yicha e'tibor talab etiladi",
                        "combined_explanation": f"Ushbu band {cited} («{top_hit['title']}») talablariga nisbatan tekshirilishi tavsiya etiladi. {top_hit['snippet']}",
                        "suggested_redline": f"Band matnini O'zbekiston qonunchiligining {top_hit['article_number']} talablariga muvofiqlashtirish tavsiya etiladi.",
                        "chain": chain_res.get("chain", []),
                    }

        if eval_res and eval_res.get("found"):
            risk_level = eval_res.get("risk_level", "YELLOW")
            cited_article = eval_res.get("root_article", "")
            # Zero-Hallucination Guard: Iqtibossiz RED hech qachon chiqmaydi (DOCX §4)
            if risk_level == "RED" and not legal_graph.verify_citation(cited_article):
                risk_level = "UNKNOWN"
                cited_article = ""

            findings.append(FindingOutput(
                clause_id=c.clause_id,
                clause_number=c.clause_number,
                risk_level=risk_level,
                category=eval_res.get("category", "LEGAL"),
                issue_title=eval_res.get("issue_title", "Qonuniy nomutanosiblik"),
                problematic_quote=c.text,
                issue_explanation=eval_res.get("combined_explanation", ""),
                cited_article=cited_article,
                suggested_redline=eval_res.get("suggested_redline", ""),
                balance_label=eval_res.get("balance_label", "Muvozanatli"),
                lex_uz_url=eval_res.get("url", "") if cited_article else "",
                multi_hop_chain=eval_res.get("chain", []),
            ))

    return {
        "analysis_id": req.analysis_id,
        "document_form": doc_form,
        "total_clauses": len(req.clauses),
        "findings_count": len(findings),
        "findings": findings,
    }


@app.post("/api/v1/self-correct")
def self_correct(req: SelfCorrectionRequest):
    """
    Active Self-Correction (Fail-Closed):
    Faqat Lex.uz allowlist bazasida mavjud va yuqori moslikka ega modda topilgandagina tuzatadi.
    Aks holda taxmin qilmaydi (resolved=False -> «Tekshirilmadi» -> hamkor advokat).
    """
    # 1. Candidate moddalarni tekshirish
    for cand in req.candidate_articles:
        res = legal_graph.resolve_chain(cand)
        if res.get("found"):
            return {
                "resolved": True,
                "corrected_article": res.get("root_article", cand),
                "explanation": f"Candidate zanjir bo'yicha tasdiqlandi: {res.get('combined_explanation')}",
                "suggested_redline": res.get("suggested_redline"),
            }

    # 2. Matn bo'yicha ekspert graf (xorijiy qonun -> fail-closed!)
    eval_res = legal_graph.evaluate_clause_text(req.clause_text)
    if eval_res and eval_res.get("found"):
        if eval_res.get("risk_level") == "UNKNOWN" or not eval_res.get("root_article"):
            return {
                "resolved": False,
                "message": "Band O'zbekiston qonunchiligi qamrovidan tashqarida (Tekshirilmadi -> hamkor advokat).",
            }
        return {
            "resolved": True,
            "corrected_article": eval_res.get("root_article"),
            "explanation": eval_res.get("combined_explanation"),
            "suggested_redline": eval_res.get("suggested_redline"),
        }

    # 3. BM25 qidiruv — faqat qat'iy ishonch chegarasi (>= 12.0) va allowlist tasdiqi bilan!
    hits = legal_vector_store.search(req.clause_text, top_k=1)
    if hits and hits[0]["score"] >= 12.0:
        hit = hits[0]
        cited = f"{hit['source_code']} {hit['article_number']}"
        if legal_graph.verify_citation(cited):
            chain_res = legal_graph.resolve_chain(hit["id"] or cited)
            return {
                "resolved": True,
                "corrected_article": cited,
                "explanation": f"Leksik tahlil asosida tasdiqlangan norma topildi: {hit['title']}. {chain_res.get('combined_explanation', hit['snippet'])}",
                "suggested_redline": chain_res.get("suggested_redline", f"Band matnini O'zR {hit['article_number']} talablariga moslashtirish tavsiya etiladi."),
            }

    return {
        "resolved": False,
        "message": "Tasdiqlangan qonun manbasi topilmadi — tizim taxmin qilmaydi (Tekshirilmadi -> hamkor advokat).",
    }

@app.post("/api/v1/ocr")
async def ocr_document(file: UploadFile = File(...)):
    """
    Hujjatni (PDF, DOCX, rasm) OCR qilib, strukturalangan bandlarga ajratish.
    """
    content = await file.read()
    res = ocr_processor.process_document(content, file.content_type)
    return {
        "filename": file.filename,
        "confidence_score": res["confidence_score"],
        "total_clauses": len(res["clauses"]),
        "clauses": res["clauses"],
        "full_text": res["full_text"],
        "full_text_sample": res["full_text"][:500]
    }

@app.post("/api/v1/voice-brief")
def voice_brief(req: VoiceBriefRequestModel):
    """
    Ovozli xulosa va SSML generatsiyasi
    """
    risk_count = len(req.top_risks)
    script = f"Assalomu alaykum! LexGuard AI tahlil xulosasi tayyor. Shartnomada jami {risk_count} ta e'tibor qaratilishi zarur bo'lgan huquqiy bandlar aniqlandi."
    ssml = f"<speak><prosody rate=\"medium\"><s>{script}</s></prosody></speak>"
    return {
        "analysis_id": req.analysis_id,
        "audio_script_uz": script,
        "ssml": ssml,
        "duration_sec": max(8, len(script.split()) * 60 // 130)
    }

if __name__ == "__main__":
    port = int(os.getenv("HTTP_PORT", "8000"))
    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=False)
