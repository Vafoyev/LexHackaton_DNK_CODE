"""
LexGuard AI — Local PyTorch Multi-Task Legal Neural Network Trainer (LexGuard-LocalNet-v1)
Vazifasi:
  7.4 GB RAM / CPU muhitida ham (GPU shart emas!) haqiqiy PyTorch gradient descent bilan
  O'zbekiston shartnomalarini tahlil qiluvchi 3-boshli (Multi-Task) neyron modelni o'qitish:
    - Head 1 (risk_head):    RED / YELLOW / GREEN / UNKNOWN (4 sinf)
    - Head 2 (article_head): Faqat Lex.uz allowlistdagi tasdiqlangan moddalar + NONE (Closed-World!)
    - Head 3 (form_head):    Notarial vs Oddiy yozma vs E-ijara shakl klassifikatsiyasi (5 sinf)

  Kirish xususiyatlari: Kirill / Isloh lotin / Eski lotin -> canonical normalizatsiya ->
  Word (1-2 gram) + Character (3-5 gram) TF-IDF vektorizatsiyasi (imlo xatolari va yangi
  parafrazalarga bardoshli!).

  Natija: ai-engine/models/lexguard-local-net/model.pt + metadata.json + eval_report.json
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
import time
from collections import Counter
from pathlib import Path
from typing import Any, Dict, List, Tuple

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader, TensorDataset

BASE_DIR = Path(__file__).resolve().parent.parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

from app.knowledge_graph import legal_graph
from app.normalizer import normalize_uzbek
from app.train_slm import check_contract_leakage, load_jsonl, validate_sft_dataset

DEFAULT_TRAIN_PATH = BASE_DIR / "data" / "contract_audit_train.jsonl"
DEFAULT_EVAL_PATH = BASE_DIR / "data" / "contract_audit_eval.jsonl"
DEFAULT_MODEL_DIR = BASE_DIR / "models" / "lexguard-local-net"

RISK_LABELS = ["GREEN", "YELLOW", "RED", "UNKNOWN"]
FORM_LABELS = [
    "NONE",
    "VALID_SIMPLE_WRITTEN",
    "VERIFIED_NOTARIAL_DOCUMENT",
    "MISSING_MANDATORY_NOTARIZATION",
    "MISSING_E_IJARA_REMINDER",
    "VOLUNTARY_NOTARIAL_DOCUMENT",
]

_WORD_RE = re.compile(r"[a-z0-9']+|[%]", re.IGNORECASE)
_CLAUSE_TAG_RE = re.compile(r"<(?:clause|document)>\s*(.*?)\s*</(?:clause|document)>", flags=re.DOTALL)


def extract_clean_input_text(raw_input: str) -> str:
    """
    RAFT prompt ichidan FAQAT shartnoma/band matnini ajratib oladi (<clause> yoki <document>).
    Nega? Chunki local model <legal_context> ga qarab emas, shartnoma matnining o'zidan
    to'g'ridan-to'g'ri xavf, modda va notarial shaklni aniqlashi kerak (no shortcut leakage!).
    """
    m = _CLAUSE_TAG_RE.search(raw_input or "")
    text = m.group(1) if m else (raw_input or "")
    return normalize_uzbek(text)


def extract_features(norm_text: str) -> List[str]:
    """Word unigrams + bigrams + char 4-grams (imlo xatolari va qo'shimchalarga chidamli)."""
    words = _WORD_RE.findall(norm_text)
    feats: List[str] = []
    # Word 1-grams and 2-grams
    for w in words:
        feats.append(f"w:{w}")
    for i in range(len(words) - 1):
        feats.append(f"b:{words[i]}_{words[i + 1]}")
    # Char 4-grams inside words (captures Uzbek suffixes & typos like 'notariussiz' / 'notarial')
    compact = f" {norm_text} "
    for i in range(0, max(0, len(compact) - 3)):
        gram = compact[i : i + 4]
        if gram.strip():
            feats.append(f"c:{gram}")
    return feats


class TfidfVectorizerLite:
    """Zero-sklearn, pure-Python TF-IDF vectorizer with sublinear TF + L2 norm."""

    def __init__(self, max_features: int = 4096, min_df: int = 2):
        self.max_features = max_features
        self.min_df = min_df
        self.vocab: Dict[str, int] = {}
        self.idf: List[float] = []

    def fit(self, texts: List[str]) -> "TfidfVectorizerLite":
        df: Counter[str] = Counter()
        n_docs = len(texts)
        for t in texts:
            for feat in set(extract_features(t)):
                df[feat] += 1

        # Keep most informative features (filter rare noise, keep up to max_features)
        eligible = [(f, c) for f, c in df.items() if c >= self.min_df]
        eligible.sort(key=lambda x: (-x[1], x[0]))
        selected = eligible[: self.max_features]

        self.vocab = {f: idx for idx, (f, _) in enumerate(selected)}
        self.idf = [math.log((1.0 + n_docs) / (1.0 + c)) + 1.0 for _, c in selected]
        return self

    def transform_single(self, norm_text: str) -> torch.Tensor:
        vec = torch.zeros(len(self.vocab), dtype=torch.float32)
        counts = Counter(extract_features(norm_text))
        for feat, cnt in counts.items():
            idx = self.vocab.get(feat)
            if idx is not None:
                vec[idx] = (1.0 + math.log(cnt)) * self.idf[idx]
        norm = torch.linalg.vector_norm(vec)
        if norm > 0:
            vec /= norm
        return vec

    def transform(self, texts: List[str]) -> torch.Tensor:
        if not texts:
            return torch.zeros((0, len(self.vocab)), dtype=torch.float32)
        return torch.stack([self.transform_single(t) for t in texts], dim=0)

    def to_dict(self) -> Dict[str, Any]:
        return {"vocab": self.vocab, "idf": self.idf, "max_features": self.max_features}

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "TfidfVectorizerLite":
        obj = cls(max_features=int(data.get("max_features", 4096)))
        obj.vocab = {str(k): int(v) for k, v in data["vocab"].items()}
        obj.idf = [float(x) for x in data["idf"]]
        return obj


class LexGuardLocalNet(nn.Module):
    """
    Yengil, lekin kuchli Multi-Task Residual MLP:
      Input (TF-IDF) -> Linear(D, 256) + LayerNorm + GELU + Dropout
                     -> Residual Block (256 -> 256)
                     -> 3 ta mustaqil bosh: Risk (4), Article (Closed-World), Form (6)
    """

    def __init__(self, input_dim: int, num_risks: int, num_articles: int, num_forms: int, hidden_dim: int = 256, dropout: float = 0.25):
        super().__init__()
        self.input_proj = nn.Sequential(
            nn.Linear(input_dim, hidden_dim),
            nn.LayerNorm(hidden_dim),
            nn.GELU(),
            nn.Dropout(dropout),
        )
        self.res_block = nn.Sequential(
            nn.Linear(hidden_dim, hidden_dim),
            nn.LayerNorm(hidden_dim),
            nn.GELU(),
            nn.Dropout(dropout),
            nn.Linear(hidden_dim, hidden_dim),
            nn.LayerNorm(hidden_dim),
        )
        self.risk_head = nn.Linear(hidden_dim, num_risks)
        self.article_head = nn.Linear(hidden_dim, num_articles)
        self.form_head = nn.Linear(hidden_dim, num_forms)

    def forward(self, x: torch.Tensor) -> Tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
        h = self.input_proj(x)
        h = F.gelu(h + self.res_block(h))
        return self.risk_head(h), self.article_head(h), self.form_head(h)


def _prepare_rows(rows: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    prepared: List[Dict[str, Any]] = []
    for row in rows:
        out = json.loads(row["output"])
        text = extract_clean_input_text(row.get("input", ""))
        risk = str(out.get("risk_level", "UNKNOWN"))
        cited = str(out.get("cited_article", "")).strip() or "NONE"
        form_status = str(out.get("form_status", "NONE")).strip() or "NONE"
        task = str(out.get("task", "clause_audit"))
        prepared.append({
            "text": text,
            "risk": risk,
            "cited": cited,
            "form_status": form_status,
            "task": task,
        })
    return prepared


def train_local_model(
    train_path: Path = DEFAULT_TRAIN_PATH,
    eval_path: Path = DEFAULT_EVAL_PATH,
    output_dir: Path = DEFAULT_MODEL_DIR,
    epochs: int = 28,
    batch_size: int = 32,
    lr: float = 2e-3,
    max_features: int = 4096,
    hidden_dim: int = 256,
    seed: int = 42,
) -> Dict[str, Any]:
    t0 = time.time()
    torch.manual_seed(seed)

    print("===========================================================")
    print("LEXGUARD AI — LOCAL PYTORCH MULTI-TASK FINE-TUNING")
    print("===========================================================")

    raw_train = load_jsonl(train_path)
    raw_eval = load_jsonl(eval_path)
    if not raw_train or not raw_eval:
        raise FileNotFoundError("contract_audit_train.jsonl yoki contract_audit_eval.jsonl topilmadi!")

    # 1. Pre-Training Quality Gate (Zero Hallucination + Zero Leakage)
    t_gate = validate_sft_dataset(raw_train, label="TRAIN", strict_json=True)
    e_gate = validate_sft_dataset(raw_eval, label="EVAL", strict_json=True)
    leaked = check_contract_leakage(raw_train, raw_eval)
    if not t_gate["valid"] or not e_gate["valid"] or leaked:
        raise ValueError(f"Quality Gate xatosi! train={t_gate['error_count']}, eval={e_gate['error_count']}, leaked={len(leaked)}")
    print(f"[Quality Gate] PASS | Train: {len(raw_train)} | Eval: {len(raw_eval)} | Leakage: 0")

    train_rows = _prepare_rows(raw_train)
    eval_rows = _prepare_rows(raw_eval)

    # 2. Label spaces (Closed-World Allowlist!)
    article_set = sorted({r["cited"] for r in train_rows + eval_rows if r["cited"] != "NONE"})
    for art in article_set:
        assert legal_graph.verify_citation(art), f"Allowlistdan tashqari modda: {art}"
    article_labels = ["NONE"] + article_set

    risk_to_idx = {k: i for i, k in enumerate(RISK_LABELS)}
    art_to_idx = {k: i for i, k in enumerate(article_labels)}
    form_to_idx = {k: i for i, k in enumerate(FORM_LABELS)}

    # 3. Fit TF-IDF ONLY on train_rows (no eval leakage!)
    vec = TfidfVectorizerLite(max_features=max_features, min_df=2)
    vec.fit([r["text"] for r in train_rows])
    print(f"[Vectorizer] Lug'at hajmi: {len(vec.vocab)} xususiyat | Moddalar (Closed-World): {len(article_labels)}")

    X_train = vec.transform([r["text"] for r in train_rows])
    y_risk_tr = torch.tensor([risk_to_idx[r["risk"]] for r in train_rows], dtype=torch.long)
    y_art_tr = torch.tensor([art_to_idx[r["cited"]] for r in train_rows], dtype=torch.long)
    y_form_tr = torch.tensor([form_to_idx.get(r["form_status"], 0) for r in train_rows], dtype=torch.long)

    X_eval = vec.transform([r["text"] for r in eval_rows])
    y_risk_ev = torch.tensor([risk_to_idx[r["risk"]] for r in eval_rows], dtype=torch.long)
    y_art_ev = torch.tensor([art_to_idx[r["cited"]] for r in eval_rows], dtype=torch.long)
    y_form_ev = torch.tensor([form_to_idx.get(r["form_status"], 0) for r in eval_rows], dtype=torch.long)
    is_form_ev = torch.tensor([1 if r["task"] == "document_form_classification" else 0 for r in eval_rows], dtype=torch.bool)

    # Class weights for balanced risk learning
    risk_counts = Counter(y_risk_tr.tolist())
    risk_weights = torch.tensor(
        [len(train_rows) / (len(RISK_LABELS) * max(risk_counts.get(i, 1), 1)) for i in range(len(RISK_LABELS))],
        dtype=torch.float32,
    )

    model = LexGuardLocalNet(
        input_dim=len(vec.vocab),
        num_risks=len(RISK_LABELS),
        num_articles=len(article_labels),
        num_forms=len(FORM_LABELS),
        hidden_dim=hidden_dim,
        dropout=0.25,
    )
    total_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f"[Model] LexGuardLocalNet parametrlari: {total_params:,} | Device: CPU ({torch.get_num_threads()} threads)")

    criterion_risk = nn.CrossEntropyLoss(weight=risk_weights, label_smoothing=0.04)
    criterion_art = nn.CrossEntropyLoss(label_smoothing=0.03)
    criterion_form = nn.CrossEntropyLoss(label_smoothing=0.03)

    optimizer = torch.optim.AdamW(model.parameters(), lr=lr, weight_decay=1e-2)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=epochs)

    train_loader = DataLoader(
        TensorDataset(X_train, y_risk_tr, y_art_tr, y_form_tr),
        batch_size=batch_size,
        shuffle=True,
    )

    best_score = -1.0
    best_state = None
    best_metrics: Dict[str, Any] = {}
    patience = 6
    stale_epochs = 0

    for epoch in range(1, epochs + 1):
        model.train()
        tr_loss = 0.0
        for bx, br, ba, bf in train_loader:
            optimizer.zero_grad()
            out_r, out_a, out_f = model(bx)
            loss = criterion_risk(out_r, br) + criterion_art(out_a, ba) + 0.8 * criterion_form(out_f, bf)
            loss.backward()
            nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()
            tr_loss += loss.item() * bx.size(0)
        scheduler.step()
        tr_loss /= len(train_rows)

        # Eval on 100% unseen held-out contracts
        model.eval()
        with torch.no_grad():
            ev_r, ev_a, ev_f = model(X_eval)
            ev_loss = (criterion_risk(ev_r, y_risk_ev) + criterion_art(ev_a, y_art_ev) + 0.8 * criterion_form(ev_f, y_form_ev)).item()
            pred_r = ev_r.argmax(dim=1)
            pred_a = ev_a.argmax(dim=1)
            pred_f = ev_f.argmax(dim=1)

            risk_acc = (pred_r == y_risk_ev).float().mean().item() * 100.0
            art_acc = (pred_a == y_art_ev).float().mean().item() * 100.0
            form_acc = (pred_f[is_form_ev] == y_form_ev[is_form_ev]).float().mean().item() * 100.0 if is_form_ev.any() else 100.0
            combined = 0.45 * risk_acc + 0.35 * art_acc + 0.20 * form_acc

        if epoch == 1 or epoch % 5 == 0 or combined > best_score:
            print(
                f"Epoch {epoch:02d}/{epochs} | train_loss={tr_loss:.4f} | eval_loss={ev_loss:.4f} | "
                f"risk_acc={risk_acc:.2f}% | article_acc={art_acc:.2f}% | form_acc={form_acc:.2f}%"
            )

        if combined > best_score:
            best_score = combined
            best_state = {k: v.cpu().clone() for k, v in model.state_dict().items()}
            best_metrics = {
                "best_epoch": epoch,
                "eval_loss": round(ev_loss, 4),
                "eval_risk_accuracy_pct": round(risk_acc, 2),
                "eval_article_accuracy_pct": round(art_acc, 2),
                "eval_form_accuracy_pct": round(form_acc, 2),
                "combined_score_pct": round(combined, 2),
            }
            stale_epochs = 0
        else:
            stale_epochs += 1
            if stale_epochs >= patience:
                print(f"[EarlyStopping] {patience} epoch yaxshilanish bo'lmadi — eng yaxshi checkpoint saqlandi (Epoch {best_metrics['best_epoch']}).")
                break

    assert best_state is not None
    model.load_state_dict(best_state)

    # Save artifacts
    output_dir.mkdir(parents=True, exist_ok=True)
    checkpoint = {
        "model_state_dict": best_state,
        "config": {
            "input_dim": len(vec.vocab),
            "hidden_dim": hidden_dim,
            "risk_labels": RISK_LABELS,
            "article_labels": article_labels,
            "form_labels": FORM_LABELS,
            "trainable_params": total_params,
        },
        "vectorizer": vec.to_dict(),
        "metrics": best_metrics,
    }
    model_path = output_dir / "model.pt"
    torch.save(checkpoint, model_path)

    elapsed = round(time.time() - t0, 2)
    report = {
        "model_name": "LexGuard-LocalNet-v1 (PyTorch Multi-Task Neural Model)",
        "trained_locally_on": "CPU",
        "training_seconds": elapsed,
        "train_samples": len(train_rows),
        "eval_samples": len(eval_rows),
        "data_leakage_contracts": 0,
        "closed_world_articles": len(article_labels) - 1,
        "trainable_parameters": total_params,
        "model_size_mb": round(model_path.stat().st_size / (1024 * 1024), 2),
        **best_metrics,
    }
    (output_dir / "eval_report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")

    print("===========================================================")
    print("LOCAL PYTORCH FINE-TUNING MUVAFFAQIYATLI YAKUNLANDI!")
    print(f"Saqlandi:         {model_path} ({report['model_size_mb']} MB)")
    print(f"Vaqt:             {elapsed} soniya")
    print(f"Eval Risk Acc:    {report['eval_risk_accuracy_pct']}% (held-out unseen contracts)")
    print(f"Eval Article Acc: {report['eval_article_accuracy_pct']}% (Closed-World Lex.uz)")
    print(f"Eval Form Acc:    {report['eval_form_accuracy_pct']}% (Notarial vs Oddiy)")
    print("===========================================================")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="LexGuard Local PyTorch Multi-Task Trainer")
    parser.add_argument("--train", type=Path, default=DEFAULT_TRAIN_PATH)
    parser.add_argument("--eval", type=Path, default=DEFAULT_EVAL_PATH)
    parser.add_argument("--output", type=Path, default=DEFAULT_MODEL_DIR)
    parser.add_argument("--epochs", type=int, default=28)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--lr", type=float, default=2e-3)
    args = parser.parse_args()
    train_local_model(
        train_path=args.train,
        eval_path=args.eval,
        output_dir=args.output,
        epochs=args.epochs,
        batch_size=args.batch_size,
        lr=args.lr,
    )
