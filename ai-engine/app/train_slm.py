"""
LexGuard AI — Optimal Drift-Proof Legal SLM Fine-Tuning Pipeline (RAFT + LoRA/QLoRA)
Xususiyatlari (Model chalg'imasligi va aldanmasligi uchun):
  1. Pre-Training Quality Gate: Har bir train/eval namunani JSON sxemasi, taqiqlangan
     so'zlar ('100%', 'xavfsiz', 'bu bitim haqiqiy emas'), Lex.uz 2,058 modda allowlisti
     va train/eval contract_id sizib chiqmasligi (zero leakage) bo'yicha qat'iy tekshiradi.
  2. RAFT (Retrieval-Augmented Fine-Tuning): Model <legal_context> blokidagi rasmiy Lex.uz
     manbasiga tayanib, faqat qat'iy JSON formatda javob berishga o'rgatiladi.
  3. Assistant-Only Loss Masking: System + User + shartnoma matni tokenlari -100 bilan
     niqoblanadi — loss FAQAT assistant JSON javobiga hisoblanadi (promptga overfit bo'lmaydi!).
  4. Full-Linear LoRA / 4-bit QLoRA (q/k/v/o/gate/up/down_proj), cosine LR, NEFTune,
     gradient checkpointing va Early Stopping bilan eng yaxshi checkpointni saqlaydi.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

BASE_DIR = Path(__file__).resolve().parent.parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

from app.knowledge_graph import legal_graph

_CONTRACT_TRAIN = BASE_DIR / "data" / "contract_audit_train.jsonl"
_CONTRACT_EVAL = BASE_DIR / "data" / "contract_audit_eval.jsonl"
DEFAULT_TRAIN_DATASET = _CONTRACT_TRAIN if _CONTRACT_TRAIN.exists() else (BASE_DIR / "data" / "legal_instructions_train.jsonl")
DEFAULT_EVAL_DATASET = _CONTRACT_EVAL if _CONTRACT_EVAL.exists() else (BASE_DIR / "data" / "legal_cross_ref_eval.jsonl")
DEFAULT_OUTPUT_DIR = BASE_DIR / "models" / "lexguard-slm-lora"

VALID_RISK_LEVELS = {"RED", "YELLOW", "GREEN", "UNKNOWN"}
FORBIDDEN_OUTPUT_PHRASES = (
    "100%",
    "xavfsiz",
    "bu bitim haqiqiy emas",
)

SYSTEM_PROMPT = (
    "Siz O'zbekiston Respublikasi qonunchiligi bo'yicha huquqiy-tahliliy yordamchi — LexGuard AI siz. "
    "Faqat berilgan <legal_context> va O'zbekiston qonunchiligiga tayaning. "
    "Javobni FAQAT qat'iy JSON formatida qaytaring. "
    "3 rang (RED — qonunga zid, YELLOW — qonunga mos lekin e'tibor kerak, GREEN — muammo topilmadi) "
    "yoki manba topilmasa UNKNOWN («0» — Tekshirilmadi) bering. "
    "Hech qachon modda to'qimang va taqiqlangan iboralarni ishlatmang."
)

ALL_LINEAR_LORA_MODULES = [
    "q_proj",
    "k_proj",
    "v_proj",
    "o_proj",
    "gate_proj",
    "up_proj",
    "down_proj",
]


def load_jsonl(path: Path) -> List[Dict[str, Any]]:
    samples: List[Dict[str, Any]] = []
    if not path.exists():
        return samples
    with path.open("r", encoding="utf-8") as f:
        for line_no, raw in enumerate(f, start=1):
            raw = raw.strip()
            if not raw:
                continue
            try:
                item = json.loads(raw)
                if isinstance(item, dict):
                    samples.append(item)
            except json.JSONDecodeError as exc:
                print(f"[WARN] {path.name}:{line_no} JSON xatosi o'tkazib yuborildi: {exc}")
    return samples


def _extract_fields(item: Dict[str, Any]) -> Tuple[str, str, str]:
    inst = str(item.get("instruction") or item.get("prompt") or "").strip()
    inp = str(item.get("input") or item.get("context") or "").strip()
    raw_out = item.get("output")
    if raw_out is None and "expected_references" in item:
        refs = item.get("expected_references") or []
        raw_out = "Bog'liq moddalar: " + ", ".join(str(r) for r in refs)
    out = str(raw_out or "").strip()
    return inst, inp, out


def format_prompt_parts(sample: Dict[str, Any]) -> Tuple[str, str]:
    """
    Prompt (system + user + assistant header) va Assistant javobini alohida qaytaradi.
    Bu Assistant-Only Loss Masking uchun zarur.
    """
    inst, inp, out = _extract_fields(sample)
    user_block = f"{inst}\n\n{inp}" if inp else inst
    prompt_prefix = (
        "<|im_start|>system\n"
        f"{SYSTEM_PROMPT}<|im_end|>\n"
        "<|im_start|>user\n"
        f"{user_block}<|im_end|>\n"
        "<|im_start|>assistant\n"
    )
    assistant_target = f"{out}<|im_end|>"
    return prompt_prefix, assistant_target


def format_prompt_sample(sample: Dict[str, Any]) -> str:
    prefix, target = format_prompt_parts(sample)
    return prefix + target


def build_assistant_only_labels(input_ids: List[int], prompt_token_len: int, pad_token_id: Optional[int] = None) -> List[int]:
    """
    Prompt tokenlari (0..prompt_token_len-1) va pad tokenlarni -100 bilan niqoblaydi.
    Loss faqat assistant JSON javobiga hisoblanadi — model promptga chalg'imaydi!
    """
    labels = list(input_ids)
    mask_end = min(prompt_token_len, len(labels))
    for i in range(mask_end):
        labels[i] = -100
    if pad_token_id is not None:
        for i in range(mask_end, len(labels)):
            if labels[i] == pad_token_id:
                labels[i] = -100
    return labels


def validate_sft_dataset(
    samples: List[Dict[str, Any]],
    label: str = "TRAIN",
    strict_json: bool = True,
) -> Dict[str, Any]:
    """
    Pre-Training Quality Gate:
    - Har bir output JSON yaroqliligini tekshiradi
    - Taqiqlangan so'zlar ('100%', 'xavfsiz', 'bu bitim haqiqiy emas') yo'qligini tekshiradi
    - Har bir cited_article rasmiy Lex.uz allowlistida (2,058 modda) mavjudligini tasdiqlaydi
    - Iqtibossiz RED namunalar yo'qligini tekshiradi
    """
    errors: List[str] = []
    risk_counts: Counter[str] = Counter()
    task_counts: Counter[str] = Counter()
    verified_citations = 0

    for idx, item in enumerate(samples):
        _, _, out = _extract_fields(item)
        out_lower = out.lower()

        for bad in FORBIDDEN_OUTPUT_PHRASES:
            if bad in out_lower:
                errors.append(f"[{label} #{idx}] Taqiqlangan ibora topildi: '{bad}'")

        if not strict_json:
            continue

        try:
            parsed = json.loads(out)
        except json.JSONDecodeError as exc:
            errors.append(f"[{label} #{idx}] Output yaroqli JSON emas: {exc}")
            continue

        if not isinstance(parsed, dict):
            errors.append(f"[{label} #{idx}] Output JSON obyekt emas")
            continue

        risk = str(parsed.get("risk_level", ""))
        task = str(parsed.get("task", "unknown"))
        cited = str(parsed.get("cited_article", "")).strip()

        if risk not in VALID_RISK_LEVELS:
            errors.append(f"[{label} #{idx}] Noto'g'ri risk_level: '{risk}'")
        else:
            risk_counts[risk] += 1
        task_counts[task] += 1

        if risk == "RED" and not cited:
            errors.append(f"[{label} #{idx}] QIZIL (RED) namuna bo'sh cited_article bilan kelgan!")

        if cited:
            if legal_graph.verify_citation(cited):
                verified_citations += 1
            else:
                errors.append(f"[{label} #{idx}] Allowlistda yo'q soxta modda: '{cited}'")

    return {
        "label": label,
        "total_samples": len(samples),
        "valid": len(errors) == 0,
        "error_count": len(errors),
        "sample_errors": errors[:10],
        "risk_distribution": dict(risk_counts),
        "task_distribution": dict(task_counts),
        "verified_citations": verified_citations,
    }


def check_contract_leakage(train_samples: List[Dict[str, Any]], eval_samples: List[Dict[str, Any]]) -> List[str]:
    train_ids = {str(s["contract_id"]) for s in train_samples if s.get("contract_id")}
    eval_ids = {str(s["contract_id"]) for s in eval_samples if s.get("contract_id")}
    return sorted(train_ids.intersection(eval_ids))


def inspect_dataset_stats(dataset_path: Path, label: str = "TRAIN") -> List[Dict[str, Any]]:
    print("\n=======================================================")
    print(f"DATASET STATISTIKASI ({label}): {dataset_path}")
    print("=======================================================")

    if not dataset_path.exists():
        print(f"[ERROR] Dataset topilmadi: {dataset_path}")
        return []

    samples = load_jsonl(dataset_path)
    if not samples:
        print("[ERROR] Dataset bo'sh!")
        return []

    total_tokens_approx = 0
    instructions_len: List[int] = []
    inputs_len: List[int] = []
    outputs_len: List[int] = []

    for item in samples:
        inst, inp, out = _extract_fields(item)
        instructions_len.append(len(inst.split()))
        inputs_len.append(len(inp.split()))
        outputs_len.append(len(out.split()))
        total_tokens_approx += (len(inst) + len(inp) + len(out)) // 4

    print(f"Jami namunalar: {len(samples)}")
    print(f"Taxminiy tokenlar hajmi: ~{total_tokens_approx:,}")
    print(f"O'rtacha instruction uzunligi: {sum(instructions_len) // len(instructions_len)} so'z")
    print(f"O'rtacha input uzunligi: {sum(inputs_len) // len(inputs_len)} so'z")
    print(f"O'rtacha output uzunligi: {sum(outputs_len) // len(outputs_len)} so'z")
    print(f"Maksimal output: {max(outputs_len)} so'z")
    return samples


def run_fine_tuning(
    model_name: str = "Qwen/Qwen2.5-1.5B-Instruct",
    dataset_path: Path = DEFAULT_TRAIN_DATASET,
    eval_path: Path = DEFAULT_EVAL_DATASET,
    output_dir: Path = DEFAULT_OUTPUT_DIR,
    epochs: int = 3,
    batch_size: int = 4,
    learning_rate: float = 1.5e-4,
    max_seq_len: int = 1024,
    lora_r: int = 16,
    lora_alpha: int = 32,
    use_qlora: bool = False,
    dry_run: bool = False,
) -> Dict[str, Any]:
    print("\n=======================================================")
    print("LEXGUARD LEGAL AI — OPTIMAL RAFT + LoRA/QLoRA PIPELINE")
    print("=======================================================")
    print(f"Asosiy model:   {model_name}")
    print(f"Train dataset:  {dataset_path}")
    print(f"Eval dataset:   {eval_path}")
    print(f"Output dir:     {output_dir}")
    print(f"Epochs: {epochs} | Batch: {batch_size} | LR: {learning_rate} | MaxLen: {max_seq_len} | QLoRA 4-bit: {use_qlora}")
    print(f"Loss Masking:   Assistant-Only (-100 prompt masking) | Target Modules: {len(ALL_LINEAR_LORA_MODULES)} linear")
    print(f"Rejim:          {'DRY RUN (Pre-Training Quality Gate)' if dry_run else 'REAL LoRA/QLoRA TRAINING'}")

    train_samples = inspect_dataset_stats(dataset_path, label="TRAIN")
    if not train_samples:
        raise FileNotFoundError(f"Train dataset mavjud emas yoki bo'sh: {dataset_path}")

    eval_samples = inspect_dataset_stats(eval_path, label="EVAL") if eval_path.exists() else []

    # 1. Pre-Training Quality Gate (Zero Hallucination + Zero Leakage)
    strict_json = dataset_path.name.startswith("contract_audit_")
    train_gate = validate_sft_dataset(train_samples, label="TRAIN", strict_json=strict_json)
    eval_gate = validate_sft_dataset(eval_samples, label="EVAL", strict_json=strict_json) if eval_samples else {"valid": True, "error_count": 0}
    leaked_contracts = check_contract_leakage(train_samples, eval_samples)

    print("\n-------------------------------------------------------")
    print("PRE-TRAINING QUALITY GATE (CHALG'IMASLIK TEKSHIRUVI)")
    print("-------------------------------------------------------")
    print(f"TRAIN Gate: {'PASS' if train_gate['valid'] else 'FAIL'} | Xatolar: {train_gate['error_count']} | Tasdiqlangan iqtiboslar: {train_gate['verified_citations']}")
    print(f"  Sinflar:  {train_gate['risk_distribution']}")
    print(f"  Vazifalar:{train_gate['task_distribution']}")
    if eval_samples:
        print(f"EVAL Gate:  {'PASS' if eval_gate['valid'] else 'FAIL'} | Xatolar: {eval_gate['error_count']} | Tasdiqlangan iqtiboslar: {eval_gate.get('verified_citations', 0)}")
        print(f"  Sinflar:  {eval_gate.get('risk_distribution', {})}")
    print(f"Train/Eval Data Leakage: {len(leaked_contracts)} ta kesishgan shartnoma")

    if not train_gate["valid"] or not eval_gate["valid"] or leaked_contracts:
        raise ValueError(
            f"Quality Gate o'tmadi! train_errors={train_gate.get('sample_errors')}, "
            f"eval_errors={eval_gate.get('sample_errors')}, leaked={leaked_contracts[:5]}"
        )

    preview = format_prompt_sample(train_samples[0])
    print("\n[Namuna RAFT + JSON Prompt (ChatML)]:")
    print(preview[:520] + "\n... [davomi bor]")

    output_dir.mkdir(parents=True, exist_ok=True)
    metadata = {
        "base_model": model_name,
        "finetuned_task": "Uzbek Law RAFT Contract Audit (Strict JSON + 3-Color + Notarial Classifier + Anti-Hallucination)",
        "train_samples": len(train_samples),
        "eval_samples": len(eval_samples),
        "risk_distribution_train": train_gate["risk_distribution"],
        "task_distribution_train": train_gate["task_distribution"],
        "verified_citations_train": train_gate["verified_citations"],
        "data_leakage_contracts": len(leaked_contracts),
        "assistant_only_loss_masking": True,
        "qlora_4bit": use_qlora,
        "epochs": epochs,
        "batch_size": batch_size,
        "learning_rate": learning_rate,
        "lr_scheduler": "cosine",
        "neftune_noise_alpha": 5.0,
        "max_seq_len": max_seq_len,
        "lora_r": lora_r,
        "lora_alpha": lora_alpha,
        "target_modules": ALL_LINEAR_LORA_MODULES,
    }

    if dry_run:
        metadata["status"] = "quality_gate_passed_ready_for_gpu"
        cfg_file = output_dir / "training_metadata.json"
        cfg_file.write_text(json.dumps(metadata, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"\n[OK] DRY RUN + QUALITY GATE muvaffaqiyatli o'tdi! Metadata: {cfg_file}")
        return metadata

    try:
        import torch
        from torch.utils.data import Dataset
        from transformers import (
            AutoModelForCausalLM,
            AutoTokenizer,
            EarlyStoppingCallback,
            Trainer,
            TrainingArguments,
        )
        from peft import LoraConfig, TaskType, get_peft_model, prepare_model_for_kbit_training
    except ImportError as exc:
        print(f"[WARN] GPU fine-tuning kutubxonalari topilmadi ({exc}).")
        print("O'rnatish: pip install torch transformers peft accelerate bitsandbytes")
        metadata["status"] = "missing_training_dependencies"
        return metadata

    device = "cuda" if torch.cuda.is_available() else ("mps" if torch.backends.mps.is_available() else "cpu")
    print(f"[INFO] Device aniqlandi: {device}")

    tokenizer = AutoTokenizer.from_pretrained(model_name, trust_remote_code=True)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
    tokenizer.padding_side = "right"

    dtype = torch.bfloat16 if (device == "cuda" and torch.cuda.is_bf16_supported()) else (
        torch.float16 if device in ("cuda", "mps") else torch.float32
    )

    load_kwargs: Dict[str, Any] = {
        "trust_remote_code": True,
        "device_map": "auto" if device == "cuda" else None,
    }
    if use_qlora and device == "cuda":
        from transformers import BitsAndBytesConfig
        load_kwargs["quantization_config"] = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_use_double_quant=True,
            bnb_4bit_compute_dtype=dtype,
        )
    else:
        load_kwargs["torch_dtype"] = dtype

    model = AutoModelForCausalLM.from_pretrained(model_name, **load_kwargs)
    model.config.use_cache = False
    if use_qlora and device == "cuda":
        model = prepare_model_for_kbit_training(model)

    lora_cfg = LoraConfig(
        task_type=TaskType.CAUSAL_LM,
        r=lora_r,
        lora_alpha=lora_alpha,
        lora_dropout=0.05,
        bias="none",
        target_modules=ALL_LINEAR_LORA_MODULES,
    )
    model = get_peft_model(model, lora_cfg)
    model.print_trainable_parameters()

    class AssistantOnlyLegalDataset(Dataset):
        """Har bir namunada prompt tokenlarini -100 bilan niqoblaydi (Loss faqat JSON javobga!)."""

        def __init__(self, rows: List[Dict[str, Any]]):
            self.items: List[Dict[str, List[int]]] = []
            for row in rows:
                prefix, target = format_prompt_parts(row)
                prompt_ids = tokenizer(prefix, add_special_tokens=False)["input_ids"]
                target_ids = tokenizer(target, add_special_tokens=False)["input_ids"]
                full_ids = (prompt_ids + target_ids)[:max_seq_len]
                labels = build_assistant_only_labels(full_ids, len(prompt_ids))
                self.items.append({
                    "input_ids": full_ids,
                    "attention_mask": [1] * len(full_ids),
                    "labels": labels,
                })

        def __len__(self) -> int:
            return len(self.items)

        def __getitem__(self, idx: int) -> Dict[str, List[int]]:
            return self.items[idx]

    class AssistantOnlyDynamicCollator:
        """Batch ichida dinamik pad qiladi va -100 label niqobini buzmaydi."""

        def __init__(self, pad_id: int):
            self.pad_id = pad_id

        def __call__(self, features: List[Dict[str, List[int]]]) -> Dict[str, Any]:
            max_len = max(len(f["input_ids"]) for f in features)
            batch_ids, batch_mask, batch_labels = [], [], []
            for f in features:
                pad_len = max_len - len(f["input_ids"])
                batch_ids.append(f["input_ids"] + [self.pad_id] * pad_len)
                batch_mask.append(f["attention_mask"] + [0] * pad_len)
                batch_labels.append(f["labels"] + [-100] * pad_len)
            return {
                "input_ids": torch.tensor(batch_ids, dtype=torch.long),
                "attention_mask": torch.tensor(batch_mask, dtype=torch.long),
                "labels": torch.tensor(batch_labels, dtype=torch.long),
            }

    train_ds = AssistantOnlyLegalDataset(train_samples)
    eval_ds = AssistantOnlyLegalDataset(eval_samples) if eval_samples else None

    train_args = TrainingArguments(
        output_dir=str(output_dir),
        num_train_epochs=epochs,
        per_device_train_batch_size=batch_size,
        per_device_eval_batch_size=batch_size,
        gradient_accumulation_steps=4,
        learning_rate=learning_rate,
        lr_scheduler_type="cosine",
        warmup_ratio=0.06,
        weight_decay=0.01,
        max_grad_norm=1.0,
        neftune_noise_alpha=5.0,
        gradient_checkpointing=(device == "cuda"),
        logging_steps=20,
        save_strategy="epoch",
        eval_strategy="epoch" if eval_ds is not None else "no",
        load_best_model_at_end=(eval_ds is not None),
        metric_for_best_model="eval_loss" if eval_ds is not None else None,
        greater_is_better=False,
        save_total_limit=2,
        bf16=(dtype == torch.bfloat16),
        fp16=(dtype == torch.float16),
        seed=42,
        report_to="none",
    )

    callbacks = [EarlyStoppingCallback(early_stopping_patience=2)] if eval_ds is not None else []
    trainer = Trainer(
        model=model,
        args=train_args,
        train_dataset=train_ds,
        eval_dataset=eval_ds,
        data_collator=AssistantOnlyDynamicCollator(tokenizer.pad_token_id),
        callbacks=callbacks,
    )

    trainer.train()
    model.save_pretrained(str(output_dir))
    tokenizer.save_pretrained(str(output_dir))
    metadata["status"] = "trained"
    (output_dir / "training_metadata.json").write_text(
        json.dumps(metadata, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(f"\n[OK] Drift-Proof LoRA adapter muvaffaqiyatli o'qitildi va saqlandi: {output_dir}")
    return metadata


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="LexGuard Optimal Legal SLM LoRA/QLoRA Fine-Tuning")
    parser.add_argument("--model", type=str, default="Qwen/Qwen2.5-1.5B-Instruct")
    parser.add_argument("--dataset", type=Path, default=DEFAULT_TRAIN_DATASET)
    parser.add_argument("--eval-dataset", type=Path, default=DEFAULT_EVAL_DATASET)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--epochs", type=int, default=3)
    parser.add_argument("--batch-size", type=int, default=4)
    parser.add_argument("--lr", type=float, default=1.5e-4)
    parser.add_argument("--max-seq-len", type=int, default=1024)
    parser.add_argument("--lora-r", type=int, default=16)
    parser.add_argument("--lora-alpha", type=int, default=32)
    parser.add_argument("--qlora", action="store_true", help="4-bit NF4 QLoRA yoqish (CUDA GPU uchun)")
    parser.add_argument("--dry-run", action="store_true", help="Faqat Pre-Training Quality Gate va konfiguratsiyani tekshirish")

    args = parser.parse_args()
    run_fine_tuning(
        model_name=args.model,
        dataset_path=args.dataset,
        eval_path=args.eval_dataset,
        output_dir=args.output,
        epochs=args.epochs,
        batch_size=args.batch_size,
        learning_rate=args.lr,
        max_seq_len=args.max_seq_len,
        lora_r=args.lora_r,
        lora_alpha=args.lora_alpha,
        use_qlora=args.qlora,
        dry_run=args.dry_run,
    )
