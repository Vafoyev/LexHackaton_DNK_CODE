"""
LexGuard AI — Hybrid Vector & Lexical Legal Search Engine
Vazifasi: 2,058 ta Lex.uz moddalari bo'yicha tezkor BM25 qidiruv
(O'zbek kirill, eski lotin va yangi lotin normalizatsiyasi bilan).
"""

import os
import re
import math
import json
from pathlib import Path
from collections import Counter
from typing import List, Dict, Any

from app.normalizer import normalize_uzbek

DEFAULT_CORPUS_PATH = str(
    Path(os.getenv("LEGAL_CORPUS_PATH", Path(__file__).resolve().parent.parent / "data" / "uzbek_legal_corpus_unified.json"))
)

class LegalVectorStore:
    def __init__(self, corpus_path: str = DEFAULT_CORPUS_PATH):
        self.corpus_path = corpus_path
        self.documents: List[Dict[str, Any]] = []
        self.doc_tokens: List[List[str]] = []
        self.doc_freqs: Dict[str, int] = Counter()
        self.doc_lengths: List[int] = []
        self.avg_doc_len: float = 0.0
        self.num_docs: int = 0
        
        self._build_index()

    def _tokenize(self, text: str) -> List[str]:
        norm = normalize_uzbek(text)
        clean = re.sub(r"[^\w\s']", " ", norm)
        tokens = [w.strip("'") for w in clean.split() if len(w.strip("'")) > 2]
        return tokens

    def _build_index(self):
        if not os.path.exists(self.corpus_path):
            print(f"[VectorStore] ⚠️ Korpus topilmadi: {self.corpus_path}")
            return

        with open(self.corpus_path, "r", encoding="utf-8") as f:
            self.documents = json.load(f)

        self.num_docs = len(self.documents)
        print(f"[VectorStore] {self.num_docs} ta qonun moddasi indekslanmoqda...")

        total_length = 0
        for doc in self.documents:
            # Sarlavha, raqam va matnni birlashtirib indekslash (sarlavhaga 3x vazn beriladi)
            full_content = f"{doc.get('article_number', '')} {doc.get('title', '')} {doc.get('title', '')} {doc.get('title', '')} {doc.get('full_text', '')}"
            tokens = self._tokenize(full_content)
            self.doc_tokens.append(tokens)
            doc_len = len(tokens)
            self.doc_lengths.append(doc_len)
            total_length += doc_len

            # DF (Document Frequency) hisoblash
            unique_tokens = set(tokens)
            for t in unique_tokens:
                self.doc_freqs[t] += 1

        self.avg_doc_len = total_length / self.num_docs if self.num_docs > 0 else 1.0
        print(f"[VectorStore] Indekslash tugallandi: {self.num_docs} ta modda, {len(self.doc_freqs)} ta noyob leksik termin!")

    def search(self, query: str, top_k: int = 5) -> List[Dict[str, Any]]:
        """
        BM25 algoritmi bo'yicha eng mos qonun moddalarini qidiradi.
        """
        if self.num_docs == 0:
            return []

        query_tokens = self._tokenize(query)
        if not query_tokens:
            return []

        scores: List[float] = [0.0] * self.num_docs
        k1 = 1.5
        b = 0.75

        for token in query_tokens:
            if token not in self.doc_freqs:
                continue

            # IDF
            df = self.doc_freqs[token]
            idf = math.log(1.0 + (self.num_docs - df + 0.5) / (df + 0.5))

            for idx, d_tokens in enumerate(self.doc_tokens):
                tf = d_tokens.count(token)
                if tf == 0:
                    continue

                d_len = self.doc_lengths[idx]
                score = idf * ((tf * (k1 + 1)) / (tf + k1 * (1 - b + b * (d_len / self.avg_doc_len))))
                scores[idx] += score

        # Top-K natijalarni saralash
        ranked_indices = sorted(range(len(scores)), key=lambda i: scores[i], reverse=True)[:top_k]
        
        results = []
        for idx in ranked_indices:
            if scores[idx] > 0.05:
                doc = self.documents[idx]
                results.append({
                    "id": doc.get("id"),
                    "article_number": doc.get("article_number"),
                    "title": doc.get("title"),
                    "source_code": doc.get("source_code"),
                    "score": round(scores[idx], 4),
                    "official_url": doc.get("official_url"),
                    "snippet": doc.get("full_text", "")[:350],
                    "cross_references": doc.get("cross_references", [])
                })

        return results

# Singleton instance
legal_vector_store = LegalVectorStore()

if __name__ == "__main__":
    test_queries = [
        "Buyurtmachi shartnomani bir tomonlama bekor qilish huquqiga ega",
        "Kechiktirilgan har bir kun uchun 1 foiz penya undiriladi",
        "Ko'chmas mulk oldi-sotdi shartnomasini notariusda tasdiqlash",
        "Xodimni sinov muddati bilan ishga qabul qilish",
        "Shaxsiy ma'lumotlarni chet elga uzatish"
    ]

    for q in test_queries:
        print(f"\nQIDIRUV: '{q}'")
        hits = legal_vector_store.search(q, top_k=2)
        for h in hits:
            print(f"  [{h['score']}] {h['source_code']} {h['article_number']}: {h['title']}")
            print(f"      Havola: {h['official_url']}")
