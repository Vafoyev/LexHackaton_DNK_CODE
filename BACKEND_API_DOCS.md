# LexGuard AI 3.0 & 4.2 — Comprehensive Backend & AI Engine API Documentation

> **Status:** Production-Ready / LexHackathon 2026  
> **Backend Base URL:** `http://localhost:8080` (Go Modular Monolith)  
> **AI Engine Base URL:** `http://localhost:8000` (Python Knowledge Graph & Hybrid RAG)  
> **Interactive Swagger UI:**
> - Go Backend: [http://localhost:8080/docs](http://localhost:8080/docs) (`/api/openapi.yaml`)
> - AI Legal Engine: [http://localhost:8000/docs](http://localhost:8000/docs) (`/openapi.json`)

---

## 1. Arxitektura va Tizim Umumiy Ko'rinishi

LexGuard AI shartnomalarni O'zbekiston Respublikasi qonunlari (Lex.uz, Fuqarolik kodeksi, Mehnat kodeksi, O'RQ-547 "Shaxsga doir ma'lumotlar to'g'risida", O'RQ-1115 "Sun'iy intellekt xavfsizligi") asosida chuqur tahlil qiluvchi, 10-vektorli xavf verifikatsiyasi va 0% gallyutsinatsiya kafolati bilan ishlaydigan milliy yuridik xavfsizlik platformasidir.

```
┌────────────────────────────────────────────────────────────────────────┐
│                   Mijoz Ilovalari (Clients)                           │
│     Web Studio (React + 3D)  │  Mobile App (Flutter)  │  Admin Portal  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ HTTP / SSE / WS
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│           LexGuard Go Modular Monolith Backend (:8080)                 │
│  - Identity & JWT Auth             - 10-Vector Arbiter Verifier        │
│  - Contract Upload & PII Redactor  - Postgres Worker Pool (SKIP LOCKED)│
│  - SSE Streaming & Voice Debrief   - E-IMZO SHA-256 Digital Signatures │
│  - Interactive Swagger UI: http://localhost:8080/docs                  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ HTTP / gRPC
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│             LexGuard AI Legal Engine (:8000)                           │
│  - 2,058 ta Lex.uz Qonun Moddalari (Unified Uzbek Legal Corpus)        │
│  - Multi-Hop Knowledge Graph (A -> B -> C havola zanjirlari)           │
│  - BM25 Gibrid Leksik & Vektor Qidiruv (13,803 ta termin)              │
│  - Moddalar bo'yicha o'xshashlik tavsiyasi (/similar-articles)         │
│  - Self-Correction & OCR Extraction                                    │
│  - Interactive Swagger UI: http://localhost:8000/docs                  │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Autentifikatsiya va Xavfsizlik

Barcha himoyalangan backend yo'nalishlari HTTP `Authorization` sarlavhasida JWT Bearer tokenni talab qiladi:

```http
Authorization: Bearer <access_token>
```

### Tezkor Demo Sessiya (Instant Demo Session)
Frontend va Mobile dasturchilar uchun hisob ochmasdan bir zumda token olish:

```bash
curl -X POST http://localhost:8080/api/v1/auth/demo-session \
  -H "Content-Type: application/json" \
  -d '{"role": "lawyer", "client_type": "web"}'
```

Javob:
```json
{
  "success": true,
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsIn...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsIn...",
    "token_type": "Bearer",
    "expires_in": 900,
    "user": {
      "id": "55555555-0000-0000-0000-000000000001",
      "email": "lawyer@lexguard.uz",
      "full_name": "Alisher Navoiy (Bosh Yurist)",
      "role": "lawyer",
      "organization_id": "44444444-0000-0000-0000-000000000001",
      "org_name": "Adolat Yuridik Firmasi"
    }
  }
}
```

---

## 3. AI Legal Engine API (`http://localhost:8000`)

### 3.1. Tizim Sog'ligi (`/health`)
AI engine xizmatining umumiy holati, indekslangan moddalar soni, graf qirralari va BM25 lug'atini tekshirish.

- **Method:** `GET`
- **URL:** `http://localhost:8000/health`
- **CURL:**
```bash
curl -s http://localhost:8000/health
```
- **Response (200 OK):**
```json
{
  "status": "UP",
  "service": "lexguard-ai-engine",
  "version": "4.2.0",
  "indexed_articles": 2058,
  "knowledge_graph_edges": 2086,
  "vector_vocabulary_terms": 13803,
  "active_training_pairs": 3234
}
```

---

### 3.2. Swagger UI va OpenAPI Sxemasi (`/docs`, `/openapi.json`)
Standalone Swagger UI sahifasi va to'liq OpenAPI 3.0.3 JSON spetsifikatsiyasi.

- **Swagger UI HTML:** `GET http://localhost:8000/docs` yoki `http://localhost:8000/api/docs`
- **OpenAPI JSON:** `GET http://localhost:8000/openapi.json`
- **CURL:**
```bash
# HTML Swagger UI
curl -s http://localhost:8000/docs | head -n 15

# OpenAPI 3.0.3 JSON
curl -s http://localhost:8000/openapi.json | jq .info
```

---

### 3.3. Huquqiy Korpus Statistikasi (`/api/v1/corpus-stats`)
Yagona huquqiy korpusdagi qonunlar, moddalar, fine-tuning va ShareGPT dialoglari soni.

- **Method:** `GET`
- **URL:** `http://localhost:8000/api/v1/corpus-stats`
- **CURL:**
```bash
curl -s http://localhost:8000/api/v1/corpus-stats
```
- **Response (200 OK):**
```json
{
  "total_laws": 10,
  "total_articles": 2058,
  "cross_reference_edges": 2086,
  "fine_tuning_pairs": 3234,
  "sharegpt_dialogues": 2062,
  "corpus_path": "/ai-engine/data/uzbek_legal_corpus_unified.json"
}
```

---

### 3.4. Qonunlar bo'yicha BM25 Gibrid Qidiruv (`/api/v1/search-laws`)
O'zbek tilidagi erkin so'rov bo'yicha Lex.uz moddalarini BM25 reytingi asosida topish.

- **Method:** `GET`
- **URL:** `http://localhost:8000/api/v1/search-laws?q={so'rov}&top_k={soni}`
- **Parameters:**
  - `q` (string, majburiy): Qidiruv jumlasi (masalan: `penya jarima`, `bir tomonlama bekor qilish`)
  - `top_k` (integer, ixtiyoriy, default: 5): Natijalar soni
- **CURL:**
```bash
curl -s "http://localhost:8000/api/v1/search-laws?q=bir%20tomonlama%20bekor%20qilish&top_k=2"
```
- **Response (200 OK):**
```json
{
  "query": "bir tomonlama bekor qilish",
  "hits_count": 2,
  "results": [
    {
      "id": "FK-UZ-2_707",
      "article_number": "707-modda",
      "title": "Haq evaziga xizmat ko'rsatish shartnomasini bajarishdan bosh tortish",
      "source_code": "FK-UZ-2",
      "score": 24.8192,
      "official_url": "https://lex.uz/docs/-111181#-111905",
      "snippet": "Buyurtmachi ijrochiga uning qilgan haqiqiy xarajatlarini to'lagan taqdirda...",
      "cross_references": ["324-modda", "14-modda"]
    }
  ]
}
```

---

### 3.5. O'xshash yoki Bog'liq Qonun Moddalari (`/api/v1/similar-articles`)
Modda kodi yoki matn bo'yicha Knowledge Graph qirralari va BM25 leksik yaqinlik orqali o'xshash normalarni aniqlash.

- **Method:** `GET` yoki `POST`
- **URL:** `http://localhost:8000/api/v1/similar-articles`
- **Query / JSON Parameters:**
  - `art_code` (string): Modda identifikatori (masalan: `FK-UZ-1_326`, `FK-UZ-2_707`)
  - `q` yoki `text` (string): Matnli so'rov
  - `top_k` (integer, default: 5): Chiqish soni
- **CURL (GET):**
```bash
curl -s "http://localhost:8000/api/v1/similar-articles?art_code=FK-UZ-1_326&top_k=2"
```
- **CURL (POST):**
```bash
curl -s -X POST http://localhost:8000/api/v1/similar-articles \
  -H "Content-Type: application/json" \
  -d '{"art_code": "FK-UZ-2_707", "top_k": 3}'
```
- **Response (200 OK):**
```json
{
  "source_code": "FK-UZ-1_326",
  "source_article": {
    "id": "FK-UZ-1_326",
    "code": "FK-UZ-1 326-modda",
    "article_number": "326-modda",
    "title": "Neustoykani kamaytirish",
    "law": "O'zbekiston Respublikasi Fuqarolik Kodeksi (1-qism)",
    "official_url": "https://lex.uz/docs/-111189#-155297"
  },
  "similar_count": 2,
  "results": [
    {
      "id": "FK-UZ-1_339",
      "article_number": "339-modda",
      "source_code": "FK-UZ-1",
      "title": "Ijroning kechiktirib yuborilganligi uchun kreditorni javobgarlikdan ozod qilish",
      "similarity_type": "graph_edge",
      "relation": "internal_reference",
      "note": "326-modda matnida 339-moddaga havola mavjud",
      "official_url": "https://lex.uz/docs/-111189#-155367"
    },
    {
      "id": "670-I_25",
      "article_number": "25-modda",
      "source_code": "670-I",
      "title": "Tovarlarni yetkazib berish muddatlarini kechiktirib yuborganlik uchun javobgarlik",
      "similarity_type": "graph_edge",
      "relation": "statutory_penalty_cap",
      "note": "Xo'jalik shartnomalari to'g'risidagi qonunning 25-moddasiga muvofiq penyaning umumiy summasi 50 foizdan oshmasligi shart.",
      "official_url": "https://lex.uz/docs/-18942#-20210"
    }
  ]
}
```

---

### 3.6. Multi-Hop Zanjirli Havolalar (`/api/v1/multi-hop-chain/{art_code}`)
Qonunlar orasidagi ko'p bosqichli bog'lanishlarni (A -> B -> C) yechish.

- **Method:** `GET`
- **URL:** `http://localhost:8000/api/v1/multi-hop-chain/{art_code}`
- **CURL:**
```bash
curl -s http://localhost:8000/api/v1/multi-hop-chain/FK-UZ-2_707
```
- **Response (200 OK):**
```json
{
  "found": true,
  "root_article": "FK-UZ-2 707-modda",
  "root_title": "Haq evaziga xizmat koʻrsatish shartnomasini bajarishdan bosh tortish",
  "url": "https://lex.uz/docs/-111181#-111905",
  "chain": [
    {
      "id": "FK-UZ-2_707",
      "code": "FK-UZ-2 707-modda",
      "title": "Haq evaziga xizmat koʻrsatish shartnomasini bajarishdan bosh tortish",
      "url": "https://lex.uz/docs/-111181#-111905"
    },
    {
      "id": "FK-UZ-1_324",
      "code": "FK-UZ-1 324-modda",
      "title": "Qarzdorning zararni toʻlash majburiyati",
      "url": "https://lex.uz/docs/-111189#-155280"
    }
  ],
  "combined_explanation": "FK-UZ-2 707-modda: Buyurtmachi ijrochiga haqiqiy xarajatlarni to'lashi shart. Bog'liq norma (FK-UZ-1 324-modda): Majburiyat buzilganda yetkazilgan zararlar to'liq hajmda qoplanadi.",
  "suggested_redline": "Buyurtmachi shartnomani bekor qilishdan kamida 15 kun oldin Ijrochini yozma xabardor qiladi hamda uning haqiqiy xarajatlarini to'liq qoplaydi."
}
```

---

### 3.7. Shartnoma Bandlarini Chuqur Tahlil Qilish (`/api/v1/analyze-clauses`)
Go backend tahlilchi ishchilari tomonidan chaqiriluvchi asosiy AI yadro qatlam.

- **Method:** `POST`
- **URL:** `http://localhost:8000/api/v1/analyze-clauses`
- **CURL:**
```bash
curl -s -X POST http://localhost:8000/api/v1/analyze-clauses \
  -H "Content-Type: application/json" \
  -d '{
    "analysis_id": "anl-001",
    "clauses": [
      {
        "clause_id": "c1",
        "clause_number": "7.3",
        "text": "Buyurtmachi istalgan vaqtda Ijrochini oldindan ogohlantirmasdan va sarflangan xarajatlarni qoplamasdan shartnomani bekor qilishi mumkin."
      }
    ]
  }'
```
- **Response (200 OK):**
```json
{
  "analysis_id": "anl-001",
  "total_clauses": 1,
  "findings_count": 1,
  "findings": [
    {
      "clause_id": "c1",
      "clause_number": "7.3",
      "risk_level": "RED",
      "category": "LEGAL",
      "issue_title": "Asossiz bir tomonlama bekor qilish huquqi",
      "problematic_quote": "Buyurtmachi istalgan vaqtda Ijrochini oldindan ogohlantirmasdan va sarflangan xarajatlarni qoplamasdan shartnomani bekor qilishi mumkin.",
      "issue_explanation": "FK 707-moddasiga asosan bir tomonlama bekor qilinganda buyurtmachi ijrochining barcha haqiqiy xarajatlarini qoplashi shart.",
      "cited_article": "FK-UZ-2 707-modda",
      "suggested_redline": "Buyurtmachi shartnomani bekor qilishdan kamida 15 kun oldin Ijrochini yozma xabardor qiladi hamda uning haqiqiy xarajatlarini to'liq qoplaydi.",
      "balance_label": "Ijrochiga nomutanosib og'ir",
      "lex_uz_url": "https://lex.uz/docs/-111181#-111905",
      "multi_hop_chain": []
    }
  ]
}
```

---

### 3.8. Gallyutsinatsiyani Tuzatish (`/api/v1/self-correct`)
Nomzod moddalar yoki band matniga tayanib, xato iqtiboslarni to'g'ri Lex.uz moddasiga almashtirish.

- **Method:** `POST`
- **URL:** `http://localhost:8000/api/v1/self-correct`
- **CURL:**
```bash
curl -s -X POST http://localhost:8000/api/v1/self-correct \
  -H "Content-Type: application/json" \
  -d '{
    "clause_text": "Kechiktirilgan har bir kun uchun 5 foiz jarima undiriladi",
    "candidate_articles": ["FK 326"]
  }'
```

---

### 3.9. Ovozli Brifing Skripti va SSML (`/api/v1/voice-brief`)
Tahlil natijasida aniqlangan jiddiy xavflar asosida 30 soniyalik o'zbekcha nutq skripti va SSML shakllantirish.

- **Method:** `POST`
- **URL:** `http://localhost:8000/api/v1/voice-brief`
- **CURL:**
```bash
curl -s -X POST http://localhost:8000/api/v1/voice-brief \
  -H "Content-Type: application/json" \
  -d '{
    "top_risks": [
      "Bir tomonlama bekor qilish huquqi (FK 707)",
      "Nomutanosib penya miqdori (FK 326)"
    ]
  }'
```

---

## 4. Go Modular Monolith Backend API (`http://localhost:8080`)

### 4.1. Tizim va Hujjatlar (System & Docs)

| Method | Endpoint | Tavsif | Autentifikatsiya |
|---|---|---|---|
| `GET` | `/healthz` | Liveness probe (200 OK) | Ochiq |
| `GET` | `/readyz` | Readiness probe (DB, Storage, Worker holati) | Ochiq |
| `GET` | `/metrics` | Prometheus formatidagi metrikalar | Ochiq |
| `GET` | `/docs` | Standalone Swagger UI HTML sahifasi | Ochiq |
| `GET` | `/api/docs` | Swagger UI muqobil havolasi | Ochiq |
| `GET` | `/api/openapi.yaml` | To'liq OpenAPI 3.1 YAML spetsifikatsiyasi | Ochiq |

#### Misol: `/readyz`
```bash
curl -s http://localhost:8080/readyz
```
```json
{
  "success": true,
  "data": {
    "database": "CONNECTED",
    "status": "READY",
    "storage": "READY",
    "workers": 4
  }
}
```

---

### 4.2. Ochiq Qoidalar va Manbalar (Public Endpoints)

#### `GET /api/v1/rules`
Barcha faol deterministik tekshiruv qoidalarini olish:
```bash
curl -s http://localhost:8080/api/v1/rules
```

#### `GET /api/v1/legal-sources`
Qonunchilik manbalari ro'yxatini olish (Lex.uz, Kodekslar):
```bash
curl -s http://localhost:8080/api/v1/legal-sources
```

#### `GET /api/v1/mock/analysis-sample`
Frontend va Mobile dasturchilar uchun tayyor namuna tahlil natijasini olish:
```bash
curl -s http://localhost:8080/api/v1/mock/analysis-sample
```

---

### 4.3. Shartnomalar va Hujjatlar (Contracts & Documents)

#### `POST /api/v1/contracts` (Hujjat yuklash)
Fayl (PDF, DOCX, TXT) yoki to'g'ridan-to'g'ri matnni yuklash. Tizim avtomatik tarzda O'RQ-547 talablariga binoan shaxsiy ma'lumotlarni (PII) anonimizatsiya qiladi va bandlarga ajratadi.

```bash
# JSON orqali yuklash
curl -s -X POST http://localhost:8080/api/v1/contracts \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "Xizmat_shartnomasi.docx",
    "text": "1. Shartnoma predmeti...\n2. Tomonlarning huquqlari...\n7.3. Buyurtmachi istalgan vaqtda shartnomani bekor qilishi mumkin."
  }'

# Multipart fayl yuklash
curl -s -X POST http://localhost:8080/api/v1/contracts \
  -H "Authorization: Bearer <token>" \
  -F "file=@/path/to/contract.docx"
```

#### `GET /api/v1/contracts`
Yuklangan shartnomalar ro'yxatini olish.

#### `GET /api/v1/contracts/{id}`
Shartnoma tafsilotlari, bandlari va SHA-256 xeshini olish.

---

### 4.4. Yuridik Tahlil (Legal Analysis)

#### `POST /api/v1/analyses` (Tahlilni boshlash)
Asinxron yuridik tahlilni navbatga qo'yish (PostgreSQL `FOR UPDATE SKIP LOCKED` konveyeri):

```bash
curl -s -X POST http://localhost:8080/api/v1/analyses \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "contract_id": "<contract_uuid>",
    "contract_date": "2026-05-15",
    "doc_type": "SERVICE_AGREEMENT",
    "execution_mode": "HYBRID_AI"
  }'
```
- **Response (202 Accepted):**
```json
{
  "success": true,
  "data": {
    "analysis_id": "01934f2a-7b3c-7000-8000-000000000200",
    "status": "QUEUED",
    "message": "Tahlil qabul qilindi va navbatga qo'yildi"
  }
}
```

#### `GET /api/v1/analyses/{id}` (Tahlil natijasi)
10-vektorli tekshirilgan xulosalar, qonuniy havolalar va qizil/sariq/yashil xavf indikatorlari:

```bash
curl -s http://localhost:8080/api/v1/analyses/<analysis_uuid> \
  -H "Authorization: Bearer <token>"
```

#### `GET /api/v1/analyses/{id}/events` (Server-Sent Events Real-Time Oqim)
Tahlil bosqichlari (`stage_changed`), oraliq topilmalar (`partial_finding`) va yakunlanishini jonli kuzatish:

```bash
curl -N -H "Authorization: Bearer <token>" \
  http://localhost:8080/api/v1/analyses/<analysis_uuid>/events
```

#### `GET /api/v1/analyses/{id}/report` (Audit Hisobotini Yuklab Olish)
Hisobotni rasmiy DOCX, PDF, TXT yoki JSON formatida eksport qilish:

```bash
# DOCX formatida yuklab olish
curl -s -O http://localhost:8080/api/v1/analyses/<analysis_uuid>/report?format=docx \
  -H "Authorization: Bearer <token>"
```

#### `POST /api/v1/analyses/{id}/findings/{fid}/decision` (Yurist Qarori)
Human-in-the-loop yondashuvi: topilgan xavfni yurist tomonidan qabul qilish (`ACCEPTED`), rad etish (`REJECTED`) yoki o'zgartirish (`MODIFIED`).

---

### 4.5. D-10 Live Voice & 3D Immersion (Spesifik Funksiyalar)

#### `GET /api/v1/analyses/{id}/voice-brief`
30 soniyalik o'zbekcha audio brifing matni, SSML va asosiy xavflar:
```bash
curl -s http://localhost:8080/api/v1/analyses/mock-test-id/voice-brief \
  -H "Authorization: Bearer <token>"
```
```json
{
  "success": true,
  "data": {
    "analysis_id": "mock-test-id",
    "audio_text": "Assalomu alaykum! LexGuard AI tahlil xulosasi tayyor...",
    "ssml": "<speak><prosody rate=\"medium\"><s>Assalomu alaykum!</s></prosody></speak>",
    "duration_sec": 14,
    "top_risks": [
      "Buyurtmachi shartnomani 0 kunlik ogohlantirishsiz bekor qilishi mumkin (FK 707)",
      "Ijrochi zimmasiga cheksiz moddiy javobgarlik yuklangan (FK 324)"
    ]
  }
}
```

#### `GET /api/v1/analyses/{id}/glanceable-matrix`
3D Immersion WebGL visual koordinata matritsasi (fazoviy sferalar, xavf zonalari va muvozanat ko'rsatkichi):
```bash
curl -s http://localhost:8080/api/v1/analyses/mock-test-id/glanceable-matrix \
  -H "Authorization: Bearer <token>"
```

#### `POST /api/v1/analyses/{id}/voice-query`
Shartnoma bo'yicha interaktiv ovozli savol-javob (AI Live Voice Q&A):
```bash
curl -s -X POST http://localhost:8080/api/v1/analyses/mock-test-id/voice-query \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"query": "Ushbu shartnomada penya miqdori bozor talabiga mosmi?"}'
```

---

### 4.6. E-IMZO Raqamli Imzolar (Digital Signatures)

#### `POST /api/v1/signatures/challenge`
Hujjatning SHA-256 xeshini tasdiqlovchi bir martalik imzolash chaqiruvini (challenge nonce) yaratish:
```bash
curl -s -X POST http://localhost:8080/api/v1/signatures/challenge \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"doc_sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"}'
```

#### `POST /api/v1/signatures/verify`
E-IMZO PKCS#7 / CMS ajratilgan raqamli imzoni tekshirish va audit jurnaliga kiritish:
```bash
curl -s -X POST http://localhost:8080/api/v1/signatures/verify \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "document_id": "<document_uuid>",
    "doc_sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "signature_hex": "308203...",
    "signer_inn": "123456789",
    "signer_name": "Alisher Navoiy"
  }'
```

---

## 5. Sinov va Tekshiruv Natijalari (Verification Proof)

Quyidagi jadvalda barcha asosiy endpointlarning haqiqiy ishchi serverlarda sinovdan o'tganligi keltirilgan:

| # | Endpoint | Xizmat | HTTP Status | Natija |
|---|---|---|---|---|
| 1 | `http://localhost:8000/docs` | AI Engine | **200 OK** | Swagger UI HTML muvaffaqiyatli yuklandi |
| 2 | `http://localhost:8000/api/docs` | AI Engine | **200 OK** | Swagger UI HTML muvaffaqiyatli yuklandi |
| 3 | `http://localhost:8000/openapi.json` | AI Engine | **200 OK** | To'liq OpenAPI 3.0.3 JSON qaytdi |
| 4 | `http://localhost:8000/health` | AI Engine | **200 OK** | 2058 ta modda, 2086 ta bog'lanish |
| 5 | `http://localhost:8000/api/v1/corpus-stats` | AI Engine | **200 OK** | 10 ta qonun, 3234 juftlik |
| 6 | `http://localhost:8000/api/v1/search-laws?q=penya` | AI Engine | **200 OK** | BM25 natijalari qaytdi |
| 7 | `http://localhost:8000/api/v1/similar-articles?art_code=FK-UZ-1_326` | AI Engine | **200 OK** | FK-UZ-1_339 va 670-I_25 topildi |
| 8 | `http://localhost:8000/api/v1/multi-hop-chain/FK-UZ-2_707` | AI Engine | **200 OK** | FK 707 -> FK 324 zanjiri topildi |
| 9 | `http://localhost:8080/docs` | Go Backend | **200 OK** | Backend Swagger UI HTML yuklandi |
| 10 | `http://localhost:8080/api/openapi.yaml` | Go Backend | **200 OK** | To'liq OpenAPI 3.1 YAML yuklandi |
| 11 | `http://localhost:8080/healthz` | Go Backend | **200 OK** | Server faol |
| 12 | `http://localhost:8080/readyz` | Go Backend | **200 OK** | DB Connected, Storage Ready |
| 13 | `http://localhost:8080/api/v1/auth/demo-session` | Go Backend | **200 OK** | JWT tokenlar yaratildi |
| 14 | `http://localhost:8080/api/v1/rules` | Go Backend | **200 OK** | 12 ta faol qoida qaytdi |
| 15 | `http://localhost:8080/api/v1/mock/analysis-sample` | Go Backend | **200 OK** | Namuna tahlil ma'lumotlari qaytdi |

---

## 6. Foydali Buyruqlar (Cheat Sheet)

```bash
# 1. Barcha servislarning sog'ligini tekshirish
curl -s http://localhost:8000/health | jq
curl -s http://localhost:8080/healthz | jq
curl -s http://localhost:8080/readyz | jq

# 2. Go Backend testlarini yurgizish
cd backend && go test -v ./internal/api

# 3. AI Engine qidiruvini testlash
curl -s "http://localhost:8000/api/v1/search-laws?q=ijara%20shartnomasi" | jq .results[0]

# 4. Multi-hop zanjirini tekshirish
curl -s "http://localhost:8000/api/v1/multi-hop-chain/FK-UZ-2_707" | jq .chain
```
