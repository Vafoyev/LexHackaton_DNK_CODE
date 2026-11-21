"""
LexGuard AI — Leksik qidiruv (BM25, inverted index)
Vazifasi: 2,058 ta Lex.uz moddasi bo'yicha tezkor qidiruv. Matn normalizatsiyasi (apostrof/kirill variantlari)
va yengil stemming (o'zbekcha qo'shimchalar) `text_utils` orqali bajariladi.
"""

import json
import math
import os
from collections import Counter, defaultdict
from typing import Any, Dict, List, Tuple

from app.config import CORPUS_PATH
from app.text_utils import tokenize

K1 = 1.5
B = 0.75


class LegalVectorStore:
    def __init__(self, corpus_path: str = str(CORPUS_PATH)):
        self.corpus_path = corpus_path
        self.documents: List[Dict[str, Any]] = []
        self.doc_index: Dict[str, int] = {}
        self.postings: Dict[str, List[Tuple[int, int]]] = defaultdict(list)  # term -> [(doc_idx, tf)]
        self.doc_freqs: Dict[str, int] = Counter()
        self.doc_lengths: List[int] = []
        self.avg_doc_len: float = 1.0
        self.num_docs: int = 0

        self._build_index()

    def _build_index(self):
        if not os.path.exists(self.corpus_path):
            print(f"[VectorStore] ⚠️ Korpus topilmadi: {self.corpus_path}")
            return

        with open(self.corpus_path, "r", encoding="utf-8") as f:
            self.documents = json.load(f)

        self.num_docs = len(self.documents)
        total_length = 0
        for idx, doc in enumerate(self.documents):
            self.doc_index[doc.get("id")] = idx
            # sarlavhaga 3x vazn beriladi
            title = doc.get("title", "")
            content = f"{doc.get('article_number', '')} {title} {title} {title} {doc.get('full_text', '')}"
            tokens = tokenize(content)
            self.doc_lengths.append(len(tokens))
            total_length += len(tokens)
            for term, tf in Counter(tokens).items():
                self.postings[term].append((idx, tf))
                self.doc_freqs[term] += 1

        self.avg_doc_len = total_length / self.num_docs if self.num_docs else 1.0
        print(f"[VectorStore] {self.num_docs} ta modda, {len(self.doc_freqs)} ta noyob termin indekslandi.")

    def _idf(self, term: str) -> float:
        df = self.doc_freqs[term]
        return math.log(1.0 + (self.num_docs - df + 0.5) / (df + 0.5))

    def _term_score(self, idf: float, tf: int, doc_len: int) -> float:
        return idf * ((tf * (K1 + 1)) / (tf + K1 * (1 - B + B * (doc_len / self.avg_doc_len))))

    def _hit(self, idx: int, score: float) -> Dict[str, Any]:
        doc = self.documents[idx]
        return {
            "id": doc.get("id"),
            "article_number": doc.get("article_number"),
            "title": doc.get("title"),
            "source_code": doc.get("source_code"),
            "score": round(score, 4),
            "official_url": doc.get("official_url"),
            "snippet": doc.get("full_text", "")[:350],
            "cross_references": doc.get("cross_references", []),
        }

    def search(self, query: str, top_k: int = 5) -> List[Dict[str, Any]]:
        """BM25 bo'yicha eng mos moddalar."""
        if self.num_docs == 0:
            return []
        query_tokens = tokenize(query)
        if not query_tokens:
            return []

        scores: Dict[int, float] = defaultdict(float)
        for term in query_tokens:  # takroriy so'rov terminlari og'irlikni oshiradi (avvalgi xatti-harakat bilan bir xil)
            if term not in self.postings:
                continue
            idf = self._idf(term)
            for idx, tf in self.postings[term]:
                scores[idx] += self._term_score(idf, tf, self.doc_lengths[idx])

        ranked = sorted(scores.items(), key=lambda kv: kv[1], reverse=True)[:top_k]
        return [self._hit(idx, sc) for idx, sc in ranked if sc > 0.05]

    def score_document(self, query: str, doc_id: str) -> float:
        """Berilgan bitta modda so'rovga qanchalik mos ekanini (BM25) qaytaradi."""
        idx = self.doc_index.get(doc_id)
        if idx is None:
            return 0.0
        wanted = Counter(tokenize(query))
        score = 0.0
        for term, qtf in wanted.items():
            if term not in self.postings:
                continue
            idf = self._idf(term)
            for d_idx, tf in self.postings[term]:
                if d_idx == idx:
                    score += qtf * self._term_score(idf, tf, self.doc_lengths[idx])
                    break
        return score


# Singleton instance
legal_vector_store = LegalVectorStore()

if __name__ == "__main__":
    test_queries = [
        "Buyurtmachi shartnomani bir tomonlama bekor qilish huquqiga ega",
        "Kechiktirilgan har bir kun uchun 1 foiz penya undiriladi",
        "Ko'chmas mulk oldi-sotdi shartnomasini notariusda tasdiqlash",
        "Xodimni sinov muddati bilan ishga qabul qilish",
        "Shaxsiy ma'lumotlarni chet elga uzatish",
    ]

    for q in test_queries:
        print(f"\nQIDIRUV: '{q}'")
        for h in legal_vector_store.search(q, top_k=2):
            print(f"  [{h['score']}] {h['source_code']} {h['article_number']}: {h['title']}")
            print(f"      Havola: {h['official_url']}")
