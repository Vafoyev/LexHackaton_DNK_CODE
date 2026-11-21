"""
LexGuard AI — Drift-Proof SLM Runtime Bridge (LoRA Adapter + Closed-World Verifier)
Vazifasi:
  - Agar o'qitilgan LoRA adapter (ai-engine/models/lexguard-slm-lora/adapter_config.json)
    mavjud bo'lsa, uni deterministic (do_sample=False) rejimda ishga tushiradi.
  - Har bir SLM chiqishini qat'iy JSON parser + Taqiqlangan so'z filtri +
    Lex.uz 2,058 modda Allowlist Verifier orqali o'tkazadi.
  - Agar model noto'g'ri/soxta modda keltirsa, QIZIL (RED) chiqishiga YO'L QO'YMAYDI
    va fail-closed UNKNOWN («Tekshirilmadi») ga tushiradi.
"""

from __future__ import annotations

import json
import os
import re
from pathlib import Path
from typing import Any, Dict, Optional

from app.knowledge_graph import legal_graph
from app.vector_store import legal_vector_store

_DEFAULT_ADAPTER_DIR = Path(
    os.getenv(
        "SLM_ADAPTER_DIR",
        Path(__file__).resolve().parent.parent / "models" / "lexguard-slm-lora",
    )
)

_VALID_RISKS = {"RED", "YELLOW", "GREEN", "UNKNOWN"}
_FORBIDDEN_REPLACEMENTS = (
    (re.compile(r"100\s*%", re.IGNORECASE), "yuqori darajada"),
    (re.compile(r"\bxavfsiz\b", re.IGNORECASE), "muammo topilmadi"),
    (re.compile(r"bu bitim haqiqiy emas", re.IGNORECASE), "bitim qonun talablariga zid kelishi xavfi mavjud"),
)


def _sanitize_text(val: str) -> str:
    out = (val or "").strip()
    for pattern, repl in _FORBIDDEN_REPLACEMENTS:
        out = pattern.sub(repl, out)
    return out


def _extract_json_block(raw_text: str) -> Optional[Dict[str, Any]]:
    text = (raw_text or "").strip()
    if not text:
        return None
    # Strip markdown code fences if present
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        obj = json.loads(text)
        return obj if isinstance(obj, dict) else None
    except json.JSONDecodeError:
        match = re.search(r"\{.*\}", text, flags=re.DOTALL)
        if not match:
            return None
        try:
            obj = json.loads(match.group(0))
            return obj if isinstance(obj, dict) else None
        except json.JSONDecodeError:
            return None


def verify_and_sanitize_slm_output(raw_text: str) -> Optional[Dict[str, Any]]:
    """
    SLM chiqargan xom JSON matnini Closed-World Verifier orqali tekshiradi:
      1. Yaroqli JSON bo'lmasa -> None (fallback/UNKNOWN).
      2. Taqiqlangan so'zlarni ('100%', 'xavfsiz', 'bu bitim haqiqiy emas') tozalaydi.
      3. cited_article ni Lex.uz 2,058 modda bazasida tekshiradi.
      4. Soxta/tasdiqlanmagan moddali RED/YELLOW -> qat'iy UNKNOWN («0») ga tushiriladi.
      5. URL har doim rasmiy legal_graph dan olinadi (model URL to'qiy olmaydi!).
    """
    parsed = _extract_json_block(raw_text)
    if parsed is None:
        return None

    risk = str(parsed.get("risk_level", "UNKNOWN")).upper().strip()
    if risk not in _VALID_RISKS:
        risk = "UNKNOWN"

    cited = str(parsed.get("cited_article", "")).strip()
    official_url = ""
    verified = False

    if cited:
        chain = legal_graph.resolve_chain(cited)
        if chain.get("found"):
            cited = chain.get("root_article", cited)
            official_url = chain.get("url", "")
            verified = True
        else:
            # Hallucinated citation! Block it strictly (fail-closed)
            cited = ""
            official_url = ""
            verified = False
            if risk in ("RED", "YELLOW"):
                risk = "UNKNOWN"

    # RED is NEVER allowed without a verified Lex.uz citation
    if risk == "RED" and not verified:
        risk = "UNKNOWN"
        cited = ""
        official_url = ""

    return {
        "task": str(parsed.get("task", "clause_audit")),
        "risk_level": risk,
        "category": str(parsed.get("category", "UNKNOWN" if risk == "UNKNOWN" else "LEGAL")),
        "cited_article": cited,
        "lex_uz_url": official_url,
        "issue_title": _sanitize_text(str(parsed.get("issue_title", ""))),
        "explanation": _sanitize_text(str(parsed.get("explanation", ""))),
        "suggested_redline": _sanitize_text(str(parsed.get("suggested_redline", ""))),
        "verified_by_lexuz": verified if risk in ("RED", "YELLOW") else (risk == "GREEN"),
    }


class LegalSLMRuntime:
    def __init__(self, adapter_dir: Path = _DEFAULT_ADAPTER_DIR):
        self.adapter_dir = adapter_dir
        self._model = None
        self._tokenizer = None
        self._load_attempted = False

    @property
    def adapter_ready(self) -> bool:
        return (self.adapter_dir / "adapter_config.json").exists()

    def _lazy_load(self) -> bool:
        if self._model is not None:
            return True
        if self._load_attempted or not self.adapter_ready:
            return False
        self._load_attempted = True
        try:
            import torch
            from peft import AutoPeftModelForCausalLM
            from transformers import AutoTokenizer

            device = "cuda" if torch.cuda.is_available() else "cpu"
            dtype = torch.bfloat16 if (device == "cuda" and torch.cuda.is_bf16_supported()) else (
                torch.float16 if device == "cuda" else torch.float32
            )
            self._tokenizer = AutoTokenizer.from_pretrained(str(self.adapter_dir), trust_remote_code=True)
            self._model = AutoPeftModelForCausalLM.from_pretrained(
                str(self.adapter_dir),
                torch_dtype=dtype,
                device_map="auto" if device == "cuda" else None,
                trust_remote_code=True,
            )
            self._model.eval()
            return True
        except Exception:
            return False

    def analyze_clause_with_slm(self, clause_text: str) -> Optional[Dict[str, Any]]:
        """
        Agar LoRA adapter yuklangan bo'lsa, RAFT <legal_context> bilan qat'iy JSON generatsiya qilib,
        Closed-World Verifier dan o'tkazilgan xulosani qaytaradi.
        """
        if not self._lazy_load():
            return None

        import torch

        hits = legal_vector_store.search(clause_text, top_k=1)
        if hits and hits[0]["score"] >= 12.0:
            h = hits[0]
            ctx = (
                f"MANBA: {h['source_code']} {h['article_number']} — «{h['title']}»\n"
                f"HAVOLA: {h['official_url']}\nMATN: {h['snippet'][:320]}"
            )
        else:
            ctx = "TOPILMADI (Lex.uz bazasidan mos imperativ norma konteksti yo'q)."

        prompt = (
            "<|im_start|>system\n"
            "Siz O'zbekiston Respublikasi qonunchiligi bo'yicha huquqiy-tahliliy yordamchi — LexGuard AI siz. "
            "Faqat berilgan <legal_context> va O'zbekiston qonunchiligiga tayaning. "
            "Javobni FAQAT qat'iy JSON formatida qaytaring.<|im_end|>\n"
            "<|im_start|>user\n"
            "Quyidagi shartnoma bandini faqat berilgan <legal_context> va O'zbekiston qonunchiligi asosida "
            "qat'iy JSON formatida tahlil qiling. Manba topilmasa risk_level='UNKNOWN' qaytaring.\n\n"
            f"<legal_context>\n{ctx}\n</legal_context>\n\n<clause>\n{clause_text}\n</clause><|im_end|>\n"
            "<|im_start|>assistant\n"
        )

        inputs = self._tokenizer(prompt, return_tensors="pt").to(self._model.device)
        with torch.no_grad():
            output_ids = self._model.generate(
                **inputs,
                max_new_tokens=256,
                do_sample=False,
                pad_token_id=self._tokenizer.eos_token_id,
            )
        gen_ids = output_ids[0][inputs["input_ids"].shape[1]:]
        raw_text = self._tokenizer.decode(gen_ids, skip_special_tokens=True)
        return verify_and_sanitize_slm_output(raw_text)


slm_runtime = LegalSLMRuntime()
