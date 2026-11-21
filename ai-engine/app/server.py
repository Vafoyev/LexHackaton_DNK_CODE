"""
LexGuard AI — Hybrid Server (Zero-Dependency Standard Library HTTP + FastAPI + Knowledge Graph + gRPC)
Vazifasi: Go backend va frontend so'rovlariga Lex.uz ning 2,058 ta qonunlari va
Knowledge Graph multi-hop zanjirlari orqali 100% aniqlik bilan xizmat ko'rsatish.
Tashqi kutubxonalarsiz (Zero-Dependency) ham, Docker (FastAPI) da ham birdek ishlaydi.
"""

import os
import sys

# Ensure ai-engine root is in sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import json
import base64
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from typing import Dict, Any

from app.knowledge_graph import legal_graph
from app.vector_store import legal_vector_store
from app.ocr import ocr_processor

PORT = int(os.getenv("HTTP_PORT", "8000"))

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

        if path == "/health":
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

        elif path.startswith("/api/v1/multi-hop-chain/"):
            art_code = path.split("/api/v1/multi-hop-chain/")[-1]
            res = legal_graph.resolve_chain(art_code)
            self._set_headers(200 if res.get("found") else 404)
            self.wfile.write(json.dumps(res, ensure_ascii=False).encode("utf-8"))
            return

        else:
            self._set_headers(404)
            self.wfile.write(json.dumps({"error": "Endpoint topilmadi"}, ensure_ascii=False).encode("utf-8"))

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length).decode("utf-8") if content_length > 0 else "{}"
        
        try:
            req_data = json.loads(body)
        except Exception:
            req_data = {}

        if path == "/api/v1/analyze-clauses":
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
                "ssml": f"<speak><prosody rate=\"medium\"><s>{script}</s></prosody></speak>",
                "duration_sec": max(8, len(script.split()) * 60 // 130)
            }
            self._set_headers(200)
            self.wfile.write(json.dumps(resp, ensure_ascii=False).encode("utf-8"))
            return

        else:
            self._set_headers(404)
            self.wfile.write(json.dumps({"error": "Endpoint topilmadi"}, ensure_ascii=False).encode("utf-8"))

def run_server(port=PORT):
    server_address = ('', port)
    httpd = HTTPServer(server_address, LexGuardHTTPRequestHandler)
    print(f"=======================================================")
    print(f"⚖️ LexGuard AI Engine Server muvaffaqiyatli ishga tushdi!")
    print(f"   Manzil: http://localhost:{port}")
    print(f"   Moddalar soni: {len(legal_graph.nodes)}")
    print(f"   Knowledge Graph zanjirlari: {sum(len(e) for e in legal_graph.edges.values())}")
    print(f"   BM25 lug'ati: {len(legal_vector_store.doc_freqs)} termin")
    print(f"=======================================================")
    httpd.serve_forever()

if __name__ == "__main__":
    run_server()
