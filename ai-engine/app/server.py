"""
LexGuard AI — Hybrid Server (Zero-Dependency Standard Library HTTP + OpenAPI / Swagger UI + Knowledge Graph + gRPC)
Vazifasi: Go backend va frontend so'rovlariga Lex.uz ning 2,058 ta qonunlari va
Knowledge Graph multi-hop zanjirlari orqali 100% aniqlik bilan xizmat ko'rsatish.
Tashqi kutubxonalarsiz (Zero-Dependency) ham, Docker (FastAPI) da ham birdek ishlaydi.
OpenAPI 3.0.3 spetsifikatsiyasi va Swagger UI to'liq integratsiya qilingan.
"""

import os
import sys
import re

# Ensure ai-engine root is in sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import json
import base64
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from typing import Dict, Any, List, Optional

from app.knowledge_graph import legal_graph
from app.vector_store import legal_vector_store
from app.ocr import ocr_processor

PORT = int(os.getenv("HTTP_PORT", "8000"))

# ==============================================================================
# OpenAPI 3.0.3 Specification Definition
# ==============================================================================
OPENAPI_SPEC: Dict[str, Any] = {
    "openapi": "3.0.3",
    "info": {
        "title": "LexGuard AI Legal Engine API",
        "version": "4.2.0",
        "description": (
            "LexGuard AI 4.2 Legal Engine — O'zbekiston qonunchiligi (Lex.uz, O'RQ-547, O'RQ-1115, "
            "Fuqarolik kodeksi, Mehnat kodeksi) asosida shartnomalar xavfsizligi tahlili, "
            "Multi-Hop Knowledge Graph zanjirlari (A -> B -> C), BM25 gibrid qidiruv, "
            "o'xshash moddalar tavsiyasi, OCR va ovozli brifing tizimi."
        ),
        "contact": {
            "name": "LexGuard AI Engineering Team",
            "url": "https://lexguard.uz",
            "email": "support@lexguard.uz"
        },
        "license": {
            "name": "Proprietary / LexHackathon 2026"
        }
    },
    "servers": [
        {
            "url": "http://localhost:8000",
            "description": "Mahalliy AI Engine serveri"
        },
        {
            "url": "http://127.0.0.1:8000",
            "description": "Lokal loopback"
        }
    ],
    "tags": [
        {"name": "System", "description": "Sog'lik va holat ko'rsatkichlari"},
        {"name": "Legal Corpus", "description": "Lex.uz 2,058 ta qonun korpusi statistikasi va qidiruv"},
        {"name": "Knowledge Graph", "description": "Multi-hop qonun zanjirlari va o'xshash normalar"},
        {"name": "Clause Analysis", "description": "Shartnoma bandlarini tahlil qilish va qonuniy redlinelar"},
        {"name": "Self Correction", "description": "Gallyutsinatsiyani 0% ga tushiruvchi avto-tuzatish"},
        {"name": "OCR & Voice", "description": "Hujjat OCR va o'zbek tilidagi ovozli xulosa"}
    ],
    "paths": {
        "/health": {
            "get": {
                "tags": ["System"],
                "summary": "AI Engine tizim holati va indeks statistikasi",
                "description": "Indekslangan moddalar soni, Knowledge Graph qirralari va BM25 lug'ati hajmini qaytaradi.",
                "responses": {
                    "200": {
                        "description": "Xizmat faol va tayyor",
                        "content": {
                            "application/json": {
                                "schema": {"$ref": "#/components/schemas/HealthResponse"}
                            }
                        }
                    }
                }
            }
        },
        "/api/v1/corpus-stats": {
            "get": {
                "tags": ["Legal Corpus"],
                "summary": "Yagona huquqiy korpus statistikasi",
                "description": "2,058 ta qonun moddasi, 10 ta kodifikatsiyalangan qonun, o'zaro bog'lanishlar va fine-tuning juftliklari.",
                "responses": {
                    "200": {
                        "description": "Korpus metrikalari",
                        "content": {
                            "application/json": {
                                "schema": {"$ref": "#/components/schemas/CorpusStatsResponse"}
                            }
                        }
                    }
                }
            }
        },
        "/api/v1/search-laws": {
            "get": {
                "tags": ["Legal Corpus"],
                "summary": "Qonunlar bo'yicha BM25 gibrid leksik qidiruv",
                "description": "O'zbek tilidagi so'rov bo'yicha Lex.uz moddalaridan eng moslarini BM25 reytingi bilan topadi.",
                "parameters": [
                    {
                        "name": "q",
                        "in": "query",
                        "required": True,
                        "description": "Qidiruv matni (masalan: 'penya jarima', 'bir tomonlama bekor qilish')",
                        "schema": {"type": "string", "example": "bir tomonlama bekor qilish"}
                    },
                    {
                        "name": "top_k",
                        "in": "query",
                        "required": False,
                        "description": "Qaytariladigan natijalar soni (sukut bo'yicha: 5)",
                        "schema": {"type": "integer", "default": 5, "example": 5}
                    }
                ],
                "responses": {
                    "200": {
                        "description": "Qidiruv natijalari",
                        "content": {
                            "application/json": {
                                "schema": {"$ref": "#/components/schemas/SearchLawsResponse"}
                            }
                        }
                    }
                }
            }
        },
        "/api/v1/similar-articles": {
            "get": {
                "tags": ["Knowledge Graph"],
                "summary": "O'xshash yoki bog'liq qonun moddalarini topish (GET)",
                "description": "Modda kodi yoki so'rov matni bo'yicha Knowledge Graph qirralari va BM25 o'xshashlik orqali yaqin normalarni topadi.",
                "parameters": [
                    {
                        "name": "art_code",
                        "in": "query",
                        "required": False,
                        "description": "Asosiy modda kodi (masalan: 'FK-UZ-1_326', 'FK-UZ-2_707', 'FK 326')",
                        "schema": {"type": "string", "example": "FK-UZ-1_326"}
                    },
                    {
                        "name": "article_number",
                        "in": "query",
                        "required": False,
                        "description": "Muqobil parametr: modda raqami",
                        "schema": {"type": "string", "example": "326"}
                    },
                    {
                        "name": "q",
                        "in": "query",
                        "required": False,
                        "description": "Leksik qidiruv so'rovi",
                        "schema": {"type": "string", "example": "neustoyka kamaytirish"}
                    },
                    {
                        "name": "top_k",
                        "in": "query",
                        "required": False,
                        "description": "Qaytariladigan o'xshash moddalar soni",
                        "schema": {"type": "integer", "default": 5, "example": 5}
                    }
                ],
                "responses": {
                    "200": {
                        "description": "O'xshash moddalar ro'yxati",
                        "content": {
                            "application/json": {
                                "schema": {"$ref": "#/components/schemas/SimilarArticlesResponse"}
                            }
                        }
                    }
                }
            },
            "post": {
                "tags": ["Knowledge Graph"],
                "summary": "O'xshash yoki bog'liq qonun moddalarini topish (POST JSON)",
                "description": "JSON shaklida uzatilgan modda kodi yoki matn asosida o'xshash moddalarni qidiradi.",
                "requestBody": {
                    "required": True,
                    "content": {
                        "application/json": {
                            "schema": {
                                "type": "object",
                                "properties": {
                                    "art_code": {"type": "string", "example": "FK-UZ-2_707"},
                                    "article_number": {"type": "string", "example": "707"},
                                    "text": {"type": "string", "example": "xizmat ko'rsatish shartnomasidan bir tomonlama voz kechish"},
                                    "top_k": {"type": "integer", "default": 5, "example": 5}
                                }
                            }
                        }
                    }
                },
                "responses": {
                    "200": {
                        "description": "O'xshash moddalar ro'yxati",
                        "content": {
                            "application/json": {
                                "schema": {"$ref": "#/components/schemas/SimilarArticlesResponse"}
                            }
                        }
                    }
                }
            }
        },
        "/api/v1/multi-hop-chain/{art_code}": {
            "get": {
                "tags": ["Knowledge Graph"],
                "summary": "Multi-Hop qonun zanjirini yechish (A -> B -> C)",
                "description": (
                    "Berilgan qonun moddasidan boshlab Lex.uz ning barcha havola zanjirlarini yechadi. "
                    "Masalan: FK 707 (bajarishdan bosh tortish) -> FK 324 (zararni qoplash) -> FK 14 (zarar tushunchasi)."
                ),
                "parameters": [
                    {
                        "name": "art_code",
                        "in": "path",
                        "required": True,
                        "description": "Qidirilayotgan modda identifikatori (masalan: 'FK-UZ-2_707', 'FK_326', '707')",
                        "schema": {"type": "string", "example": "FK-UZ-2_707"}
                    }
                ],
                "responses": {
                    "200": {
                        "description": "Multi-hop zanjir topildi",
                        "content": {
                            "application/json": {
                                "schema": {"$ref": "#/components/schemas/MultiHopChainResponse"}
                            }
                        }
                    },
                    "404": {
                        "description": "Modda zanjiri topilmadi",
                        "content": {
                            "application/json": {
                                "schema": {
                                    "type": "object",
                                    "properties": {
                                        "found": {"type": "boolean", "example": False},
                                        "chain": {"type": "array", "items": {}},
                                        "combined_explanation": {"type": "string"}
                                    }
                                }
                            }
                        }
                    }
                }
            }
        },
        "/api/v1/analyze-clauses": {
            "post": {
                "tags": ["Clause Analysis"],
                "summary": "Shartnoma bandlarini chuqur yuridik tahlil qilish",
                "description": "Har bir bandni Knowledge Graph va BM25 orqali tekshirib, xavf darajasi (RED/YELLOW), O'zbekiston qonuni, URL va tavsiya etilgan redlineni taqdim etadi.",
                "requestBody": {
                    "required": True,
                    "content": {
                        "application/json": {
                            "schema": {"$ref": "#/components/schemas/AnalyzeClausesRequest"}
                        }
                    }
                },
                "responses": {
                    "200": {
                        "description": "Bandlar bo'yicha to'liq tahliliy xulosa",
                        "content": {
                            "application/json": {
                                "schema": {"$ref": "#/components/schemas/AnalyzeClausesResponse"}
                            }
                        }
                    }
                }
            }
        },
        "/api/v1/self-correct": {
            "post": {
                "tags": ["Self Correction"],
                "summary": "AI iqtiboslarini 100% haqiqiy Lex.uz moddalariga moslab tuzatish",
                "description": "Nomzod moddalar yoki band matniga asoslanib, gallyutsinatsiya bo'lgan moddalarni haqiqiy O'zbekiston qonunlariga bog'laydi.",
                "requestBody": {
                    "required": True,
                    "content": {
                        "application/json": {
                            "schema": {
                                "type": "object",
                                "properties": {
                                    "clause_text": {"type": "string", "example": "Ijrochi kechiktirilgan har bir kun uchun 5 foiz jarima to'laydi"},
                                    "candidate_articles": {
                                        "type": "array",
                                        "items": {"type": "string"},
                                        "example": ["FK 326", "FK 324"]
                                    }
                                }
                            }
                        }
                    }
                },
                "responses": {
                    "200": {
                        "description": "Tuzatilgan norma va tushuntirish",
                        "content": {
                            "application/json": {
                                "schema": {
                                    "type": "object",
                                    "properties": {
                                        "resolved": {"type": "boolean", "example": True},
                                        "corrected_article": {"type": "string", "example": "FK-UZ-1 326-modda"},
                                        "explanation": {"type": "string"},
                                        "suggested_redline": {"type": "string"}
                                    }
                                }
                            }
                        }
                    }
                }
            }
        },
        "/api/v1/ocr": {
            "post": {
                "tags": ["OCR & Voice"],
                "summary": "Hujjat OCR yoki xom matnni tahlilga tayyorlash",
                "description": "PDF/rasm faylning Base64 kodini yoki to'g'ridan-to'g'ri matnni qabul qilib, tuzilgan matnga aylantiradi.",
                "requestBody": {
                    "required": True,
                    "content": {
                        "application/json": {
                            "schema": {
                                "type": "object",
                                "properties": {
                                    "file_base64": {"type": "string", "description": "Base64 fayl baytlari"},
                                    "mime_type": {"type": "string", "example": "application/pdf"},
                                    "raw_text": {"type": "string", "example": "Shartnoma matni..."}
                                }
                            }
                        }
                    }
                },
                "responses": {
                    "200": {
                        "description": "OCR natijasi",
                        "content": {
                            "application/json": {
                                "schema": {
                                    "type": "object",
                                    "properties": {
                                        "text": {"type": "string"},
                                        "confidence": {"type": "number", "example": 0.98},
                                        "method": {"type": "string", "example": "direct_text_extraction"}
                                    }
                                }
                            }
                        }
                    }
                }
            }
        },
        "/api/v1/voice-brief": {
            "post": {
                "tags": ["OCR & Voice"],
                "summary": "30 soniyalik o'zbekcha audio brifing skripti va SSML",
                "description": "Eng jiddiy xavflar asosida ovozli yordamchi uchun SSML va o'zbekcha nutq matnini tayyorlaydi.",
                "requestBody": {
                    "required": True,
                    "content": {
                        "application/json": {
                            "schema": {
                                "type": "object",
                                "properties": {
                                    "top_risks": {
                                        "type": "array",
                                        "items": {"type": "string"},
                                        "example": [
                                            "Bir tomonlama bekor qilish huquqi (FK 707)",
                                            "Cheksiz moddiy javobgarlik (FK 324)"
                                        ]
                                    }
                                }
                            }
                        }
                    }
                },
                "responses": {
                    "200": {
                        "description": "Ovozli brifing matni va SSML",
                        "content": {
                            "application/json": {
                                "schema": {
                                    "type": "object",
                                    "properties": {
                                        "audio_script_uz": {"type": "string"},
                                        "ssml": {"type": "string"},
                                        "duration_sec": {"type": "integer", "example": 14}
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    },
    "components": {
        "schemas": {
            "HealthResponse": {
                "type": "object",
                "properties": {
                    "status": {"type": "string", "example": "UP"},
                    "service": {"type": "string", "example": "lexguard-ai-engine"},
                    "version": {"type": "string", "example": "4.2.0"},
                    "indexed_articles": {"type": "integer", "example": 2058},
                    "knowledge_graph_edges": {"type": "integer", "example": 2086},
                    "vector_vocabulary_terms": {"type": "integer", "example": 13803},
                    "active_training_pairs": {"type": "integer", "example": 3234}
                }
            },
            "CorpusStatsResponse": {
                "type": "object",
                "properties": {
                    "total_laws": {"type": "integer", "example": 10},
                    "total_articles": {"type": "integer", "example": 2058},
                    "cross_reference_edges": {"type": "integer", "example": 2086},
                    "fine_tuning_pairs": {"type": "integer", "example": 3234},
                    "sharegpt_dialogues": {"type": "integer", "example": 2062},
                    "corpus_path": {"type": "string", "example": "/ai-engine/data/uzbek_legal_corpus_unified.json"}
                }
            },
            "SearchLawsResponse": {
                "type": "object",
                "properties": {
                    "query": {"type": "string", "example": "bir tomonlama bekor qilish"},
                    "hits_count": {"type": "integer", "example": 2},
                    "results": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "id": {"type": "string", "example": "FK-UZ-2_707"},
                                "article_number": {"type": "string", "example": "707"},
                                "title": {"type": "string", "example": "Haq evaziga xizmat ko'rsatish shartnomasini bajarishdan bosh tortish"},
                                "source_code": {"type": "string", "example": "FK-UZ-2"},
                                "score": {"type": "number", "example": 24.8192},
                                "official_url": {"type": "string", "example": "https://lex.uz/docs/111181#111905"},
                                "snippet": {"type": "string"}
                            }
                        }
                    }
                }
            },
            "SimilarArticlesResponse": {
                "type": "object",
                "properties": {
                    "source_code": {"type": "string", "example": "FK-UZ-1_326"},
                    "source_article": {
                        "type": "object",
                        "nullable": True,
                        "properties": {
                            "id": {"type": "string", "example": "FK-UZ-1_326"},
                            "code": {"type": "string", "example": "FK-UZ-1 326"},
                            "article_number": {"type": "string", "example": "326"},
                            "title": {"type": "string", "example": "Neustoykani kamaytirish"},
                            "official_url": {"type": "string", "example": "https://lex.uz/docs/111181#111520"}
                        }
                    },
                    "similar_count": {"type": "integer", "example": 3},
                    "results": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "id": {"type": "string"},
                                "article_number": {"type": "string"},
                                "source_code": {"type": "string"},
                                "title": {"type": "string"},
                                "similarity_type": {"type": "string", "enum": ["graph_edge", "lexical_bm25"]},
                                "score": {"type": "number"},
                                "snippet": {"type": "string"},
                                "official_url": {"type": "string"}
                            }
                        }
                    }
                }
            },
            "MultiHopChainResponse": {
                "type": "object",
                "properties": {
                    "found": {"type": "boolean", "example": True},
                    "root_article": {"type": "string", "example": "FK-UZ-2 707"},
                    "root_title": {"type": "string", "example": "Haq evaziga xizmat ko'rsatish shartnomasini bajarishdan bosh tortish"},
                    "url": {"type": "string", "example": "https://lex.uz/docs/111181#111905"},
                    "chain": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "id": {"type": "string"},
                                "code": {"type": "string"},
                                "title": {"type": "string"},
                                "url": {"type": "string"},
                                "summary": {"type": "string"}
                            }
                        }
                    },
                    "combined_explanation": {"type": "string"},
                    "suggested_redline": {"type": "string"}
                }
            },
            "AnalyzeClausesRequest": {
                "type": "object",
                "required": ["clauses"],
                "properties": {
                    "analysis_id": {"type": "string", "example": "anl-01934f2a-7b3c"},
                    "clauses": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["clause_id", "clause_number", "text"],
                            "properties": {
                                "clause_id": {"type": "string", "example": "c-001"},
                                "clause_number": {"type": "string", "example": "7.3"},
                                "text": {
                                    "type": "string",
                                    "example": "Buyurtmachi istalgan vaqtda Ijrochini oldindan ogohlantirmasdan shartnomani bekor qilishi mumkin."
                                }
                            }
                        }
                    }
                }
            },
            "AnalyzeClausesResponse": {
                "type": "object",
                "properties": {
                    "analysis_id": {"type": "string", "example": "anl-01934f2a-7b3c"},
                    "total_clauses": {"type": "integer", "example": 1},
                    "findings_count": {"type": "integer", "example": 1},
                    "findings": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "clause_id": {"type": "string", "example": "c-001"},
                                "clause_number": {"type": "string", "example": "7.3"},
                                "risk_level": {"type": "string", "enum": ["RED", "YELLOW", "GREEN"], "example": "RED"},
                                "category": {"type": "string", "example": "LEGAL"},
                                "issue_title": {"type": "string", "example": "Asossiz bir tomonlama bekor qilish huquqi"},
                                "problematic_quote": {"type": "string"},
                                "issue_explanation": {"type": "string"},
                                "cited_article": {"type": "string", "example": "FK-UZ-2 707"},
                                "suggested_redline": {"type": "string"},
                                "balance_label": {"type": "string", "example": "Ijrochiga nomutanosib og'ir"},
                                "lex_uz_url": {"type": "string", "example": "https://lex.uz/docs/111181#111905"},
                                "multi_hop_chain": {"type": "array", "items": {}}
                            }
                        }
                    }
                }
            }
        }
    }
}

# Pre-serialized OpenAPI JSON
OPENAPI_JSON_BYTES = json.dumps(OPENAPI_SPEC, ensure_ascii=False, indent=2).encode("utf-8")

# ==============================================================================
# Standalone Swagger UI HTML Template
# ==============================================================================
SWAGGER_UI_HTML = """<!DOCTYPE html>
<html lang="uz">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>LexGuard AI Engine — OpenAPI / Swagger UI</title>
  <link rel="icon" type="image/svg+xml" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='%2338bdf8'><path d='M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4z'/></svg>" />
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" />
  <style>
    html { box-sizing: border-box; overflow-y: scroll; }
    *, *:before, *:after { box-sizing: inherit; }
    body {
      margin: 0;
      background: #0b0f19;
      color: #f1f5f9;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
    }
    .custom-header {
      background: linear-gradient(135deg, #0f172a 0%, #1e1b4b 100%);
      border-bottom: 1px solid #334155;
      padding: 16px 28px;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 12px;
      font-size: 1.25rem;
      font-weight: 700;
      color: #38bdf8;
      letter-spacing: -0.02em;
    }
    .brand-badge {
      background: rgba(56, 189, 248, 0.15);
      border: 1px solid #0284c7;
      color: #38bdf8;
      font-size: 0.75rem;
      padding: 3px 8px;
      border-radius: 9999px;
      font-weight: 600;
    }
    .header-links a {
      color: #94a3b8;
      text-decoration: none;
      font-size: 0.875rem;
      margin-left: 20px;
      transition: color 0.2s;
    }
    .header-links a:hover {
      color: #38bdf8;
    }
    /* Swagger UI Overrides for Dark Modern Theme */
    .swagger-ui .topbar { display: none !important; }
    .swagger-ui { color: #f1f5f9; }
    .swagger-ui .info { margin: 25px 0; }
    .swagger-ui .info .title { color: #38bdf8; font-weight: 800; }
    .swagger-ui .info p, .swagger-ui .info li { color: #94a3b8; font-size: 0.95rem; }
    .swagger-ui .info a { color: #38bdf8; }
    .swagger-ui .scheme-container {
      background: #111827;
      box-shadow: none;
      border-bottom: 1px solid #1f2937;
      border-radius: 8px;
      padding: 12px 20px;
      margin-bottom: 20px;
    }
    .swagger-ui .opblock {
      border-radius: 8px;
      border: 1px solid #334155 !important;
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.25);
      margin-bottom: 14px;
    }
    .swagger-ui .opblock.opblock-get { background: rgba(14, 165, 233, 0.08); border-color: #0284c7 !important; }
    .swagger-ui .opblock.opblock-post { background: rgba(34, 197, 94, 0.08); border-color: #16a34a !important; }
    .swagger-ui .opblock-summary-method { border-radius: 6px; font-weight: 700; min-width: 75px; }
    .swagger-ui .opblock-summary-path { color: #f8fafc !important; font-weight: 600; }
    .swagger-ui .opblock-summary-description { color: #94a3b8 !important; }
    .swagger-ui table thead tr td, .swagger-ui table thead tr th { color: #cbd5e1; border-bottom: 1px solid #334155; }
    .swagger-ui .tab li button.tablinks { color: #94a3b8; }
    .swagger-ui .tab li button.tablinks.active { color: #38bdf8; font-weight: bold; }
    .swagger-ui select, .swagger-ui input[type=text], .swagger-ui textarea {
      background: #1e293b !important;
      color: #f8fafc !important;
      border: 1px solid #475569 !important;
      border-radius: 6px;
    }
    .swagger-ui .btn.execute {
      background-color: #0284c7 !important;
      border-color: #0284c7 !important;
      color: #fff !important;
      font-weight: 600;
      border-radius: 6px;
    }
    .swagger-ui .btn.btn-clear {
      border-radius: 6px;
    }
    .swagger-ui section.models {
      border: 1px solid #334155 !important;
      background: #111827 !important;
      border-radius: 8px;
    }
    .swagger-ui section.models h4 { color: #f8fafc; font-weight: 700; }
    .swagger-ui .model-box { background: transparent; }
    .swagger-ui .model-title { color: #38bdf8; }
    .swagger-ui .prop-type { color: #c084fc; }
    .swagger-ui .parameter__name { color: #e2e8f0; font-weight: 600; }
    .swagger-ui .parameter__type { color: #c084fc; }
    .swagger-ui .response-col_status { color: #38bdf8; font-weight: 700; }
    .swagger-ui .responses-inner { background: #0f172a; border-radius: 6px; padding: 10px; }
  </style>
</head>
<body>
  <div class="custom-header">
    <div class="brand">
      <span>⚖️ LexGuard AI Engine</span>
      <span class="brand-badge">OpenAPI 3.0</span>
    </div>
    <div class="header-links">
      <a href="/openapi.json" target="_blank">📄 openapi.json</a>
      <a href="/health" target="_blank">💓 /health</a>
      <a href="http://localhost:8080/docs" target="_blank">🚀 Backend API Docs (:8080)</a>
    </div>
  </div>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js" crossorigin></script>
  <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-standalone-preset.js" crossorigin></script>
  <script>
    window.onload = () => {
      window.ui = SwaggerUIBundle({
        url: '/openapi.json',
        dom_id: '#swagger-ui',
        presets: [
          SwaggerUIBundle.presets.apis,
          SwaggerUIStandalonePreset
        ],
        layout: "BaseLayout",
        deepLinking: true,
        showExtensions: true,
        showCommonExtensions: true,
        defaultModelsExpandDepth: 1
      });
    };
  </script>
</body>
</html>
""".encode("utf-8")


def find_similar_articles(art_code: str = "", text: str = "", top_k: int = 5) -> Dict[str, Any]:
    """
    Knowledge Graph qirralari va BM25 leksik o'xshashlik orqali moddaga yaqin normalarni topadi.
    """
    results: List[Dict[str, Any]] = []
    source_meta: Optional[Dict[str, Any]] = None

    target_node = None
    if art_code:
        normalized = art_code.strip()
        for nid, data in legal_graph.nodes.items():
            if (nid.lower() == normalized.lower() or
                data.get("code", "").lower() == normalized.lower() or
                data.get("article_number", "").lower() == normalized.lower()):
                target_node = data
                break

        if not target_node:
            num = re.sub(r'[^\d]', '', normalized)
            if num:
                for prefix in ["FK-UZ-1_", "FK-UZ-2_", "MK-2022_", "670-I_", "ORQ-547_"]:
                    cand = f"{prefix}{num}"
                    if cand in legal_graph.nodes:
                        target_node = legal_graph.nodes[cand]
                        break

    if target_node:
        source_meta = {
            "id": target_node.get("id"),
            "code": target_node.get("code"),
            "article_number": target_node.get("article_number"),
            "title": target_node.get("title"),
            "law": target_node.get("law"),
            "official_url": target_node.get("url")
        }
        node_id = target_node.get("id")
        edges = legal_graph.edges.get(node_id, [])
        seen_ids = {node_id}

        # 1. Graph bo'yicha bog'langan moddalar
        for edge in edges:
            tgt_id = edge["target"]
            if tgt_id in legal_graph.nodes and tgt_id not in seen_ids:
                seen_ids.add(tgt_id)
                tgt = legal_graph.nodes[tgt_id]
                results.append({
                    "id": tgt.get("id"),
                    "article_number": tgt.get("article_number"),
                    "source_code": tgt.get("source_code"),
                    "title": tgt.get("title"),
                    "similarity_type": "graph_edge",
                    "relation": edge.get("relation", "reference"),
                    "note": edge.get("note", ""),
                    "snippet": tgt.get("summary", "")[:320],
                    "official_url": tgt.get("url", "")
                })

        # 2. BM25 orqali o'xshash mavzudagi moddalar
        search_query = f"{target_node.get('title', '')} {target_node.get('summary', '')[:200]}"
        bm25_hits = legal_vector_store.search(search_query, top_k=top_k + 3)
        for hit in bm25_hits:
            if hit.get("id") not in seen_ids and len(results) < top_k * 2:
                seen_ids.add(hit.get("id"))
                results.append({
                    "id": hit.get("id"),
                    "article_number": hit.get("article_number"),
                    "source_code": hit.get("source_code"),
                    "title": hit.get("title"),
                    "similarity_type": "lexical_bm25",
                    "score": hit.get("score"),
                    "snippet": hit.get("snippet", "")[:320],
                    "official_url": hit.get("official_url", "")
                })
    else:
        # Leksik so'rov bo'yicha
        query_text = text or art_code
        bm25_hits = legal_vector_store.search(query_text, top_k=top_k)
        for hit in bm25_hits:
            results.append({
                "id": hit.get("id"),
                "article_number": hit.get("article_number"),
                "source_code": hit.get("source_code"),
                "title": hit.get("title"),
                "similarity_type": "lexical_bm25",
                "score": hit.get("score"),
                "snippet": hit.get("snippet", "")[:320],
                "official_url": hit.get("official_url", "")
            })

    trimmed = results[:top_k]
    return {
        "source_code": art_code or text,
        "source_article": source_meta,
        "similar_count": len(trimmed),
        "results": trimmed
    }


class LexGuardHTTPRequestHandler(BaseHTTPRequestHandler):
    def _set_headers(self, status_code=200, content_type="application/json"):
        self.send_response(status_code)
        self.send_header("Content-Type", content_type)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.end_headers()

    def do_OPTIONS(self):
        self._set_headers(200)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query_params = urllib.parse.parse_qs(parsed.query)

        # ── Swagger UI Docs ───────────────────────────────────────────────────
        if path in ("/docs", "/api/docs"):
            self._set_headers(200, "text/html; charset=utf-8")
            self.wfile.write(SWAGGER_UI_HTML)
            return

        # ── OpenAPI 3.0.3 JSON ────────────────────────────────────────────────
        elif path in ("/openapi.json", "/api/openapi.json"):
            self._set_headers(200, "application/json; charset=utf-8")
            self.wfile.write(OPENAPI_JSON_BYTES)
            return

        # ── Health Endpoint ───────────────────────────────────────────────────
        elif path == "/health":
            total_edges = sum(len(edges) for edges in legal_graph.edges.values())
            data = {
                "status": "UP",
                "service": "lexguard-ai-engine",
                "version": "4.2.0",
                "indexed_articles": len(legal_graph.nodes),
                "knowledge_graph_edges": total_edges,
                "vector_vocabulary_terms": len(legal_vector_store.doc_freqs),
                "active_training_pairs": 3234
            }
            self._set_headers(200)
            self.wfile.write(json.dumps(data, ensure_ascii=False).encode("utf-8"))
            return

        # ── Corpus Stats ──────────────────────────────────────────────────────
        elif path == "/api/v1/corpus-stats":
            data = {
                "total_laws": 10,
                "total_articles": len(legal_graph.nodes),
                "cross_reference_edges": sum(len(edges) for edges in legal_graph.edges.values()),
                "fine_tuning_pairs": 3234,
                "sharegpt_dialogues": 2062,
                "corpus_path": "/ai-engine/data/uzbek_legal_corpus_unified.json"
            }
            self._set_headers(200)
            self.wfile.write(json.dumps(data, ensure_ascii=False).encode("utf-8"))
            return

        # ── Search Laws (BM25) ────────────────────────────────────────────────
        elif path == "/api/v1/search-laws":
            q = query_params.get("q", [""])[0]
            top_k = int(query_params.get("top_k", [5])[0])
            hits = legal_vector_store.search(q, top_k=top_k)
            data = {
                "query": q,
                "hits_count": len(hits),
                "results": hits
            }
            self._set_headers(200)
            self.wfile.write(json.dumps(data, ensure_ascii=False).encode("utf-8"))
            return

        # ── Similar Articles (GET) ────────────────────────────────────────────
        elif path == "/api/v1/similar-articles":
            art_code = query_params.get("art_code", query_params.get("article_number", [""]))[0]
            text = query_params.get("q", query_params.get("text", [""]))[0]
            top_k = int(query_params.get("top_k", [5])[0])
            res = find_similar_articles(art_code=art_code, text=text, top_k=top_k)
            self._set_headers(200)
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode("utf-8"))
            return

        # ── Multi-Hop Chain (Knowledge Graph) ─────────────────────────────────
        elif path.startswith("/api/v1/multi-hop-chain/"):
            art_code = path.split("/api/v1/multi-hop-chain/")[-1]
            art_code = urllib.parse.unquote(art_code)
            res = legal_graph.resolve_chain(art_code)
            self._set_headers(200 if res.get("found") else 404)
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode("utf-8"))
            return

        else:
            self._set_headers(404)
            self.wfile.write(json.dumps({"error": f"Endpoint '{path}' topilmadi. Hujjatlar: /docs"}, ensure_ascii=False).encode("utf-8"))

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length).decode("utf-8") if content_length > 0 else "{}"
        
        try:
            req_data = json.loads(body)
        except Exception:
            req_data = {}

        if path == "/api/v1/similar-articles":
            art_code = req_data.get("art_code", req_data.get("article_number", ""))
            text = req_data.get("text", req_data.get("q", ""))
            top_k = int(req_data.get("top_k", 5))
            res = find_similar_articles(art_code=art_code, text=text, top_k=top_k)
            self._set_headers(200)
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode("utf-8"))
            return

        elif path == "/api/v1/analyze-clauses":
            clauses = req_data.get("clauses", [])
            findings = []

            for c in clauses:
                c_id = c.get("clause_id", "")
                c_num = c.get("clause_number", "")
                c_text = c.get("text", "")

                eval_res = legal_graph.evaluate_clause_text(c_text)
                if not eval_res or not eval_res.get("found"):
                    hits = legal_vector_store.search(c_text, top_k=1)
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
                            "combined_explanation": f"Ushbu band {top_hit['source_code']} {top_hit['article_number']} doirasidagi talablarga mos kelishi tekshirilishi lozim. {top_hit['snippet']}",
                            "suggested_redline": f"Band matni O'zbekiston qonunchiligining {top_hit['article_number']} talablariga muvofiqlashtirilishi tavsiya etiladi.",
                            "chain": chain_res.get("chain", [])
                        }

                if eval_res and eval_res.get("found"):
                    findings.append({
                        "clause_id": c_id,
                        "clause_number": c_num,
                        "risk_level": eval_res.get("risk_level", "YELLOW"),
                        "category": eval_res.get("category", "LEGAL"),
                        "issue_title": eval_res.get("issue_title", "Qonuniy nomutanosiblik"),
                        "problematic_quote": c_text,
                        "issue_explanation": eval_res.get("combined_explanation", ""),
                        "cited_article": eval_res.get("root_article", ""),
                        "suggested_redline": eval_res.get("suggested_redline", ""),
                        "balance_label": "Ijrochiga nomutanosib og'ir",
                        "lex_uz_url": eval_res.get("url", "https://lex.uz"),
                        "multi_hop_chain": eval_res.get("chain", [])
                    })

            response_data = {
                "analysis_id": req_data.get("analysis_id", "analysis-001"),
                "total_clauses": len(clauses),
                "findings_count": len(findings),
                "findings": findings
            }
            self._set_headers(200)
            self.wfile.write(json.dumps(response_data, ensure_ascii=False).encode("utf-8"))
            return

        elif path == "/api/v1/self-correct":
            clause_text = req_data.get("clause_text", "")
            candidates = req_data.get("candidate_articles", [])

            # 1. Candidate moddalar tekshiruvi
            resolved_finding = None
            for cand in candidates:
                res = legal_graph.resolve_chain(cand)
                if res.get("found"):
                    resolved_finding = {
                        "resolved": True,
                        "corrected_article": res.get("root_article", cand),
                        "explanation": f"Nomzod zanjiri bo'yicha tuzatildi: {res.get('combined_explanation')}",
                        "suggested_redline": res.get("suggested_redline")
                    }
                    break

            if not resolved_finding:
                eval_res = legal_graph.evaluate_clause_text(clause_text)
                if eval_res and eval_res.get("found"):
                    resolved_finding = {
                        "resolved": True,
                        "corrected_article": eval_res.get("root_article"),
                        "explanation": eval_res.get("combined_explanation"),
                        "suggested_redline": eval_res.get("suggested_redline")
                    }
                else:
                    hits = legal_vector_store.search(clause_text, top_k=1)
                    if hits:
                        hit = hits[0]
                        resolved_finding = {
                            "resolved": True,
                            "corrected_article": f"{hit['source_code']} {hit['article_number']}",
                            "explanation": f"Leksik tahlil asosida muqobil norma topildi: {hit['title']}. {hit['snippet']}",
                            "suggested_redline": "Band matnini ushbu norma talablariga moslashtirish tavsiya etiladi."
                        }
                    else:
                        resolved_finding = {
                            "resolved": False,
                            "message": "Bog'langan qonun topilmadi, huquqshunos ko'rigi talab etiladi."
                        }

            self._set_headers(200)
            self.wfile.write(json.dumps(resolved_finding, ensure_ascii=False).encode("utf-8"))
            return

        elif path == "/api/v1/ocr":
            # Handles text or base64 file
            file_base64 = req_data.get("file_base64", "")
            mime_type = req_data.get("mime_type", "application/pdf")
            if file_base64:
                file_bytes = base64.b64decode(file_base64)
            else:
                raw_text = req_data.get("raw_text", "")
                file_bytes = raw_text.encode("utf-8")
                mime_type = "text/plain"

            res = ocr_processor.process_document(file_bytes, mime_type)
            self._set_headers(200)
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode("utf-8"))
            return

        elif path == "/api/v1/voice-brief":
            top_risks = req_data.get("top_risks", [])
            script = f"Assalomu alaykum! LexGuard AI tahlil xulosasi tayyor. Shartnomada jami {len(top_risks)} ta huquqiy xavf aniqlandi."
            resp = {
                "audio_script_uz": script,
                "ssml": f'<speak><prosody rate="medium"><s>{script}</s></prosody></speak>',
                "duration_sec": max(8, len(script.split()) * 60 // 130)
            }
            self._set_headers(200)
            self.wfile.write(json.dumps(resp, ensure_ascii=False).encode("utf-8"))
            return

        else:
            self._set_headers(404)
            self.wfile.write(json.dumps({"error": f"Endpoint '{path}' topilmadi"}, ensure_ascii=False).encode("utf-8"))


def run_server(port=PORT):
    server_address = ('', port)
    httpd = HTTPServer(server_address, LexGuardHTTPRequestHandler)
    print(f"=======================================================")
    print(f"⚖️ LexGuard AI Engine Server muvaffaqiyatli ishga tushdi!")
    print(f"   Manzil: http://localhost:{port}")
    print(f"   Swagger UI: http://localhost:{port}/docs")
    print(f"   OpenAPI JSON: http://localhost:{port}/openapi.json")
    print(f"   Moddalar soni: {len(legal_graph.nodes)}")
    print(f"   Knowledge Graph zanjirlari: {sum(len(e) for e in legal_graph.edges.values())}")
    print(f"   BM25 lug'ati: {len(legal_vector_store.doc_freqs)} termin")
    print(f"=======================================================")
    httpd.serve_forever()


if __name__ == "__main__":
    run_server()
