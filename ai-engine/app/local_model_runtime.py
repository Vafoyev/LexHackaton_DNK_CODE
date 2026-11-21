"""
LexGuard AI — Local Neural Model Runtime (LexGuard-LocalNet-v1 + Closed-World Verifier)
Vazifasi:
  Local PyTorch bilan o'qitilgan ai-engine/models/lexguard-local-net/model.pt modelini
  xotiraga yuklab (< 50 ms), yangi/parafraza shartnoma bandlarini < 2 ms ichida baholaydi.
  Xavfsizlik kafolati:
    - Faqat yuqori ishonchda (confidence >= 0.78) javob beradi.
    - Xorijiy qonun / arbitraj aniqlansa fail-closed UNKNOWN qaytaradi.
    - Har bir modda havolasi Lex.uz 2,058 modda allowlisti (legal_graph.verify_citation)
      bilan qayta tasdiqlanadi — iqtibossiz RED hech qachon chiqmaydi!
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any, Dict, Optional

from app.knowledge_graph import legal_graph
from app.normalizer import is_foreign_law_clause, normalize_uzbek

_DEFAULT_MODEL_PATH = Path(
    os.getenv(
        "LOCAL_NEURAL_MODEL_PATH",
        Path(__file__).resolve().parent.parent / "models" / "lexguard-local-net" / "model.pt",
    )
)


class LocalNeuralLegalRuntime:
    def __init__(self, model_path: Path = _DEFAULT_MODEL_PATH):
        self.model_path = model_path
        self._loaded = False
        self._load_attempted = False
        self._model = None
        self._vectorizer = None
        self._risk_labels = []
        self._article_labels = []
        self._form_labels = []
        self._metrics: Dict[str, Any] = {}

    @property
    def is_ready(self) -> bool:
        return self.model_path.exists()

    @property
    def eval_metrics(self) -> Dict[str, Any]:
        if not self._loaded and self.is_ready:
            self._ensure_loaded()
        return self._metrics

    def _ensure_loaded(self) -> bool:
        if self._loaded:
            return True
        if self._load_attempted or not self.is_ready:
            return False
        self._load_attempted = True
        try:
            import torch
            from app.train_local_model import LexGuardLocalNet, TfidfVectorizerLite

            ckpt = torch.load(self.model_path, map_location="cpu", weights_only=False)
            cfg = ckpt["config"]
            self._risk_labels = cfg["risk_labels"]
            self._article_labels = cfg["article_labels"]
            self._form_labels = cfg["form_labels"]
            self._metrics = ckpt.get("metrics", {})
            self._vectorizer = TfidfVectorizerLite.from_dict(ckpt["vectorizer"])

            model = LexGuardLocalNet(
                input_dim=int(cfg["input_dim"]),
                num_risks=len(self._risk_labels),
                num_articles=len(self._article_labels),
                num_forms=len(self._form_labels),
                hidden_dim=int(cfg["hidden_dim"]),
                dropout=0.0,
            )
            model.load_state_dict(ckpt["model_state_dict"])
            model.eval()
            self._model = model
            self._loaded = True
            return True
        except Exception:
            return False

    def predict_clause(self, text: str, min_confidence: float = 0.78) -> Optional[Dict[str, Any]]:
        """
        Parafraza qilingan yoki qoidalarga to'g'ridan-to'g'ri tushmagan bandni
        o'qitilgan PyTorch neyron modeli orqali baholaydi + Lex.uz allowlist bilan tasdiqlaydi.
        """
        if not text or not text.strip():
            return None
        if is_foreign_law_clause(text):
            return {
                "found": True,
                "source": "local_neural_fail_closed",
                "risk_level": "UNKNOWN",
                "category": "UNKNOWN",
                "root_article": "",
                "url": "",
                "confidence": 1.0,
                "balance_label": "Aniqlanmadi",
                "issue_title": "Xorijiy qonun yoki arbitraj bandi (Tekshirilmadi)",
                "combined_explanation": "Band O'zbekiston qonunchiligi qamrovidan tashqarida — tizim taxmin qilmaydi («0»).",
                "suggested_redline": "O'zbekiston qonunchiligini ko'rsating yoki hamkor advokatga murojaat qiling.",
                "chain": [],
            }

        if not self._ensure_loaded():
            return None

        import torch
        import torch.nn.functional as F

        norm = normalize_uzbek(text)
        x = self._vectorizer.transform_single(norm).unsqueeze(0)
        with torch.no_grad():
            r_logits, a_logits, f_logits = self._model(x)
            r_probs = F.softmax(r_logits, dim=-1)[0]
            a_probs = F.softmax(a_logits, dim=-1)[0]
            f_probs = F.softmax(f_logits, dim=-1)[0]

            r_conf, r_idx = torch.max(r_probs, dim=0)
            a_conf, a_idx = torch.max(a_probs, dim=0)
            f_conf, f_idx = torch.max(f_probs, dim=0)

        risk_level = self._risk_labels[int(r_idx)]
        article = self._article_labels[int(a_idx)]
        form_status = self._form_labels[int(f_idx)]
        risk_confidence = float(r_conf.item())
        art_confidence = float(a_conf.item())

        # Ishonch past bo'lsa, taxmin qilmaymiz!
        if risk_confidence < min_confidence:
            return None

        # GREEN bo'lsa, muammo yo'q (xavf sifatida chiqarmaymiz)
        if risk_level == "GREEN":
            return {
                "found": False,
                "source": "local_neural_model",
                "risk_level": "GREEN",
                "form_status": form_status,
                "confidence": round(risk_confidence, 4),
            }

        if risk_level == "UNKNOWN":
            return {
                "found": True,
                "source": "local_neural_model",
                "risk_level": "UNKNOWN",
                "category": "UNKNOWN",
                "root_article": "",
                "url": "",
                "confidence": round(risk_confidence, 4),
                "form_status": form_status,
                "balance_label": "Aniqlanmadi",
                "issue_title": "Qamrovdan tashqari yoki noaniq huquqiy band (Tekshirilmadi)",
                "combined_explanation": "O'qitilgan neyron model ushbu bandni O'zbekiston qonunchiligi qamrovidan tashqarida deb baholadi («0» xulosa).",
                "suggested_redline": "Hamkor advokat ko'rigidan o'tkazish tavsiya etiladi.",
                "chain": [],
            }

        # RED / YELLOW uchun: Closed-World Allowlist Verifier majburiy!
        cited = "" if article == "NONE" else article
        chain_res = legal_graph.resolve_chain(cited) if cited else {"found": False}
        if not chain_res.get("found") or art_confidence < 0.60:
            # Iqtibossiz RED hech qachon chiqmaydi!
            if risk_level == "RED":
                return {
                    "found": True,
                    "source": "local_neural_model",
                    "risk_level": "UNKNOWN",
                    "category": "UNKNOWN",
                    "root_article": "",
                    "url": "",
                    "confidence": round(risk_confidence, 4),
                    "balance_label": "Aniqlanmadi",
                    "issue_title": "Aniq modda tasdiqlanmadi (Tekshirilmadi)",
                    "combined_explanation": "Neyron model xavf ehtimolini sezdi, biroq aniq Lex.uz moddasi yetarli ishonch bilan tasdiqlanmadi («0» xulosa).",
                    "suggested_redline": "Hamkor advokat ko'rigidan o'tkazing.",
                    "chain": [],
                }
            return None

        root_art = chain_res.get("root_article", cited)
        return {
            "found": True,
            "source": "local_neural_model",
            "risk_level": risk_level,
            "category": "LEGAL" if risk_level == "RED" else "COMMERCIAL",
            "root_article": root_art,
            "root_title": chain_res.get("root_title", ""),
            "url": chain_res.get("url", ""),
            "confidence": round(risk_confidence, 4),
            "article_confidence": round(art_confidence, 4),
            "form_status": form_status,
            "balance_label": "Ijrochiga og'ir" if risk_level == "RED" else "Muvozanatli",
            "issue_title": f"{chain_res.get('root_title', root_art)} bo'yicha nomuvofiqlik ({'Qonunga zid' if risk_level == 'RED' else 'E’tibor kerak'})",
            "combined_explanation": chain_res.get("combined_explanation", ""),
            "suggested_redline": chain_res.get("suggested_redline", ""),
            "chain": chain_res.get("chain", []),
        }


local_neural_runtime = LocalNeuralLegalRuntime()
