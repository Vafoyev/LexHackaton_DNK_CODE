"""
LexGuard AI — AI Engine Server (FastAPI + gRPC + Legal Knowledge Graph + BM25)
Vazifasi: Lex.uz qonunlari zanjiri (Knowledge Graph), qoidaviy shartnoma tahlili, BM25 qidiruv,
Active Self-Correction, OCR va gRPC servisi.
"""

import logging
import os
from contextlib import asynccontextmanager
from typing import Any, Dict, List, Optional

import uvicorn
from fastapi import FastAPI, File, Form, HTTPException, Query, UploadFile
from fastapi.concurrency import run_in_threadpool
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from app import config, service
from app.chat import MAX_MESSAGE_CHARS, answer_chat
from app.analyzer import analyzer
from app.grpc_server import serve_grpc
from app.knowledge_graph import legal_graph
from app.ocr import ocr_processor
from app.vector_store import legal_vector_store
from app.voice import answer_voice_query, build_voice_brief

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ai-engine")

MAX_UPLOAD_BYTES = 15 * 1024 * 1024  # backend BodyLimit (15MB) bilan mos

grpc_server_instance = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global grpc_server_instance
    grpc_port = int(os.getenv("GRPC_PORT", "50051"))
    try:
        grpc_server_instance = serve_grpc(grpc_port)
        logger.info("Background gRPC server port %s da faollashtirildi.", grpc_port)
    except Exception as e:
        logger.error("gRPC serverni ishga tushirishda xatolik: %s", e)

    yield

    if grpc_server_instance:
        logger.info("gRPC server to'xtatilmoqda...")
        grpc_server_instance.stop(0)


app = FastAPI(
    title="LexGuard AI Engine API",
    description="Legal Knowledge Graph, Multi-Hop Law Resolution, qoidaviy shartnoma tahlili, Active Self-Correction & gRPC Service",
    version="5.0.0",
    lifespan=lifespan,
)

# CORS: production'da faqat aniq ro'yxat (CORS_ORIGINS); dev'da "*" (credentials'siz)
if config.CORS_ORIGINS:
    _cors = dict(allow_origins=config.CORS_ORIGINS, allow_credentials=True)
elif config.APP_ENV == "production":
    _cors = dict(allow_origins=[], allow_credentials=False)
else:
    _cors = dict(allow_origins=["*"], allow_credentials=False)
app.add_middleware(CORSMiddleware, allow_methods=["*"], allow_headers=["*"], **_cors)


class ClauseInput(BaseModel):
    clause_id: str
    clause_number: str = ""
    text: str


class AnalysisRequest(BaseModel):
    analysis_id: str
    document_type: str = "B2B_SERVICE"
    contract_date: str = ""
    party_role: str = ""  # EXECUTOR | CUSTOMER | NEUTRAL
    use_local_slm_only: bool = False
    clauses: List[ClauseInput]


class SelfCorrectionRequest(BaseModel):
    clause_text: str
    previous_cited_article: str = ""
    verification_error: str = ""
    candidate_articles: List[str] = []
    document_type: str = ""
    party_role: str = ""


class VoiceBriefRequestModel(BaseModel):
    analysis_id: str
    summary_text: str = ""
    top_risks: List[Dict[str, Any]] = []


class BalanceRequest(BaseModel):
    document_type: str = ""
    party_role: str = ""
    clauses: List[ClauseInput]


class VoiceQueryRequest(BaseModel):
    query: str


class ChatRequest(BaseModel):
    message: str


def _llm_allowed(use_local_only: bool) -> bool:
    refiner = analyzer.refiner
    return refiner is not None and (not use_local_only or refiner.is_local)


@app.get("/health")
def health_check():
    return {**service.health(), "grpc_active": grpc_server_instance is not None}


@app.get("/api/v1/corpus-stats")
def corpus_stats():
    return service.corpus_stats()


@app.get("/api/v1/rules")
def rules_catalog():
    """Faol qoidalar katalogi (shaffoflik va admin ko'rigi uchun)."""
    rules = service.rules_catalog()
    return {"count": len(rules), "rules": rules}


@app.get("/api/v1/search-laws")
def search_laws(q: str = Query(..., description="Qidiruv so'rovi yoki shartnoma bandi matni"), top_k: int = Query(5, ge=1, le=50)):
    results = legal_vector_store.search(q, top_k=top_k)
    return {"query": q, "hits_count": len(results), "results": results}


@app.get("/api/v1/multi-hop-chain/{article_code}")
def get_multi_hop_chain(article_code: str):
    res = legal_graph.resolve_chain(article_code)
    if not res.get("found"):
        raise HTTPException(status_code=404, detail=f"'{article_code}' bo'yicha norma zanjiri topilmadi.")
    return res


@app.post("/api/v1/analyze-clauses")
def analyze_clauses(req: AnalysisRequest):
    """
    Bandlarni qoidalar katalogi + Knowledge Graph orqali tahlil qiladi (Red/Green Redline + Multi-Hop).
    BM25 natijalari taxminiy xavf sifatida emas, `clause_reports[].related_norms` sifatida qaytariladi.
    """
    return service.analyze_request(
        req.analysis_id, [c.model_dump() for c in req.clauses], req.document_type, req.party_role,
        use_llm=_llm_allowed(req.use_local_slm_only),
    )


@app.post("/api/v1/analyze-document")
async def analyze_document(
    file: UploadFile = File(...),
    document_type: str = Form("B2B_SERVICE"),
    party_role: str = Form(""),
    analysis_id: str = Form("doc-analysis"),
):
    """Hujjat -> OCR -> bandlarga ajratish -> tahlil (bitta so'rovda)."""
    content = await file.read(MAX_UPLOAD_BYTES + 1)
    if len(content) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Fayl hajmi 15MB dan oshmasligi kerak.")
    ocr = await run_in_threadpool(ocr_processor.process_document, content, file.content_type)
    clauses = [{"clause_id": c["clause_id"], "clause_number": c["clause_number"], "text": c["text"]} for c in ocr["clauses"]]
    result = await run_in_threadpool(service.analyze_request, analysis_id, clauses, document_type, party_role)
    result.update({
        "filename": file.filename,
        "ocr_confidence": ocr["confidence_score"],
        "needs_human_review": ocr["confidence_score"] < 0.85,
    })
    return result


@app.get("/api/v1/law-changes")
def law_changes_feed(
    limit: int = Query(10, ge=1, le=100),
    source: str = Query("", max_length=16, pattern=r"^[A-Za-z0-9-]*$"),
    since: str = Query("", description="YYYY-MM-DD"),
    only_used: bool = Query(False, description="Faqat tahlil qoidalarida ishlatiladigan moddalar"),
):
    """Lex.uz tahrir izohlariga asoslangan eng so'nggi o'zgargan normalar (korpus nusxasi doirasida)."""
    try:
        return service.law_changes_request(limit, source, since, only_used)
    except ValueError:
        raise HTTPException(status_code=422, detail="since: YYYY-MM-DD formatida bo'lishi kerak.")


@app.post("/api/v1/balance")
async def balance(req: BalanceRequest):
    """
    Tomonlar balansi: shartnoma ikki tomondan biriga og'ir tushmayaptimi, tengsiz mavzular va ikki tomonga teng tahrir takliflari.
    """
    if not req.clauses:
        raise HTTPException(status_code=422, detail="Kamida bitta band kerak.")
    if len(req.clauses) > 500:
        raise HTTPException(status_code=413, detail="Bandlar soni 500 dan oshmasligi kerak.")
    return await run_in_threadpool(
        service.balance_request, [c.model_dump() for c in req.clauses], req.document_type, req.party_role,
    )


@app.post("/api/v1/self-correct")
def self_correct(req: SelfCorrectionRequest):
    """
    Active Self-Correction: Go verifikatori moddani rad etganda to'g'ri normani topadi.
    Rad etilgan modda (previous_cited_article) nomzodlardan chiqarib tashlanadi.
    """
    return service.self_correct_request(
        req.clause_text, req.previous_cited_article, req.verification_error,
        req.candidate_articles, req.document_type, req.party_role,
    )


@app.post("/api/v1/ocr")
async def ocr_document(file: UploadFile = File(...)):
    """Hujjatni (PDF, DOCX, rasm) OCR qilib, bandlarga ajratish."""
    content = await file.read(MAX_UPLOAD_BYTES + 1)
    if len(content) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Fayl hajmi 15MB dan oshmasligi kerak.")
    res = await run_in_threadpool(ocr_processor.process_document, content, file.content_type)
    return {
        "filename": file.filename,
        "confidence_score": res["confidence_score"],
        "total_clauses": len(res["clauses"]),
        "clauses": res["clauses"],
        "full_text_sample": res["full_text"][:500],
    }


@app.post("/api/v1/voice-brief")
def voice_brief(req: VoiceBriefRequestModel):
    """Ovozli xulosa va SSML."""
    brief = build_voice_brief(req.top_risks, req.summary_text)
    return {"analysis_id": req.analysis_id, **brief}


@app.post("/api/v1/voice-query")
def voice_query(req: VoiceQueryRequest):
    """Ovozli savolga qonunlar bazasidan asoslangan javob matni."""
    answer = answer_voice_query(req.query, legal_graph, legal_vector_store)
    if not answer:
        raise HTTPException(status_code=422, detail="Savol bo'sh bo'lmasligi kerak.")
    return {"query": req.query, "answer": answer}


@app.post("/api/v1/chat")
async def chat(req: ChatRequest):
    """
    Suhbat: modda, mavzu, shartnoma bandi tahlili yoki qidiruv (qarang: app/chat.py).
    Javobdagi `speech` ovozli o'qish uchun mo'ljallangan.
    """
    if not req.message.strip():
        raise HTTPException(status_code=422, detail="Xabar bo'sh bo'lmasligi kerak.")
    if len(req.message) > MAX_MESSAGE_CHARS:
        raise HTTPException(status_code=413, detail=f"Xabar {MAX_MESSAGE_CHARS} belgidan oshmasligi kerak.")
    return await run_in_threadpool(answer_chat, req.message)


if __name__ == "__main__":
    port = int(os.getenv("HTTP_PORT", "8000"))
    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=False)
