# LexGuard AI — AI Engine, RAG, Fine-Tuning & Anti-Hallucination Architecture

## 1. Umumiy Arxitektura (4-Qatlamli Gibrid Zanjir)

LexGuard AI oddiy LLM wrapper emas. Har bir shartnoma va band quyidagi 4 qatlamdan o‘tadi:

1. **O‘zbek tili Normalizatori (`app/normalizer.py`)**
   - Kirill (`ў/қ/ғ/ҳ/ш/ч`), Isloh qilingan lotin (`ö/ğ/ş/ç`) va Eski lotin (`o'/g'/sh/ch`) yozuvlarini bitta kanonik shaklga keltiradi.
   - Xorijiy yurisdiksiya detektori (`English law`, `LCIA`, `ICC`, `SIAC`, `Delaware`, `DIFC`, `Swiss law`, `ГК РФ`) ishlaydi — topilsa tizim taxmin qilmaydi (`UNKNOWN` / «Tekshirilmadi»).

2. **3-Qavatli Notarial vs Oddiy Shartnoma Klassifikatori (`app/notarial_classifier.py`)**
   - **1-qavat (Qonun talabi):** Majburiy notarial (`FK 110, 112, 271, 138`: ko‘chmas mulk/avto oldi-sotdi/hadya, ipoteka, nikoh, vasiyatnoma, qayta ishonish) vs E-ijara (`FK 574`: ofis/turar joy ijarasi — notarius shart emas, `ijara.soliq.uz` kerak) vs Oddiy yozma (`B2B xizmat, pudrat, yetkazib berish, mehnat, qarz, NDA`).
   - **2-qavat (Notarial rekvizitlar ball tizimi):** Inkor detektori (`notariussiz`, `notarial tasdiqlashsiz`) + notarius ustxati (`+3`), `e-notarius.uz` / reyestr raqami (`+3`), gerbli blanka/boj (`+2`), QR-kod (`+2`).
   - **3-qavat (Butun hujjat konteksti):** `MISSING_MANDATORY_NOTARIZATION` (Qizil), `VERIFIED_NOTARIAL_DOCUMENT` (Yashil), `MISSING_E_IJARA_REMINDER` (Sariq), `VALID_SIMPLE_WRITTEN` / `VOLUNTARY_NOTARIAL_DOCUMENT` (Yashil).

3. **RAG + Multi-Hop Knowledge Graph (`app/knowledge_graph.py`, `app/vector_store.py`)**
   - **Rasmiy Korpus (`data/uzbek_legal_corpus_unified.json`):** Lex.uz’ning 10 ta asosiy qonuni — **2,058 ta modda**, **2,086 ta cross-reference bog‘lanish** (`FK 707 -> FK 354, FK 324`), **13,794 ta BM25 leksik termin**.
   - **Closed-World Allowlist Verifier (`GET /api/v1/verify-citation`):** Tasdiqlanmagan modda bilan `RED` hech qachon chiqmaydi (`UNKNOWN` ga tushiriladi). Active Self-Correction (`POST /api/v1/self-correct`) faqat BM25 `>= 12.0` + allowlist tasdiqi bo‘lgandagina tuzatadi.

4. **2-Darajali Fine-Tuning (Local PyTorch + Cloud GPU QLoRA)**
   - **Local o‘qitilgan model (`app/train_local_model.py` + `app/local_model_runtime.py`):**
     - `LexGuard-LocalNet-v1` (PyTorch Multi-Task Residual MLP, **1,188,377 parametr**, `4.66 MB` — `models/lexguard-local-net/model.pt`).
     - 3 ta mustaqil bosh: **Risk (4 sinf)**, **Closed-World Article (Lex.uz allowlist)**, **Notarial Form (6 sinf)**.
     - CPU’da inference `< 2 ms`, faqat `confidence >= 0.78` va `legal_graph.verify_citation` tasdiqi bilan javob beradi.
   - **Cloud GPU SLM QLoRA (`app/train_slm.py` + `app/slm_runtime.py`):**
     - `Qwen/Qwen2.5-1.5B-Instruct` uchun **RAFT + Qat’iy JSON**, **Assistant-Only Loss Masking (`-100`)**, **Pre-Training Quality Gate**, 7 ta linear LoRA qatlami + 4-bit NF4 `--qlora`, `NEFTune`, `EarlyStopping`.

---

## 2. Dataset va Benchmark Natijalari (`app/contract_dataset_builder.py`)

- **Benchmark (`data/contracts_benchmark_600.jsonl`):** 600 ta to‘liq shartnoma (240 Yashil + 300 Qizil/Sariq + 60 Xorijiy Fail-Closed), **124 ta noyob xato senariysi** (15 yuridik oila, 3 yozuvda).
- **SFT Train / Eval (`data/contract_audit_train.jsonl`, `data/contract_audit_eval.jsonl`):** `1,524` train / `590` held-out eval (**0 ta contract_id kesishuvi — zero data leakage**), adversarial prompt-injection va soxta modda rad etish namunalari bilan.

| Metrika | Natija |
|---|---|
| Notarial vs Oddiy aniqligi (600 shartnoma) | **100.0% (600/600)** |
| Xato bandlarni topish — Recall (124 senariy) | **100.0% (400/400)** |
| To‘g‘ri (Yashil) shartnomalarda False Positive | **0.0% (240/240 toza)** |
| Xorijiy qonun Fail-Closed (`UNKNOWN`) | **100.0% (60/60)** |
| Lex.uz Allowlist tasdiqi | **100.0% (400/400)** |
| Local PyTorch Eval (590 unseen samples) | **Risk 100.0% · Article 100.0% · Form 100.0%** |

---

## 3. Ishga Tushirish Buyruqlari

```bash
# 1. 600 ta shartnoma benchmarki va SFT dataset generatsiyasi
python ai-engine/app/contract_dataset_builder.py

# 2. Local PyTorch Multi-Task modelini o'qitish (CPU, ~17 soniya)
python ai-engine/app/train_local_model.py

# 3. GPU QLoRA SLM Pre-Training Quality Gate (yoki GPU'da real trening)
python ai-engine/app/train_slm.py --dry-run
# GPU: python ai-engine/app/train_slm.py --model Qwen/Qwen2.5-1.5B-Instruct --qlora --epochs 3

# 4. Barcha 11 ta avtomatik testni ishga tushirish
python ai-engine/test_ai_engine.py
```
