# 🤝 LexGuard AI — Tizimlararo API & Data Shartnomalari (API Contracts)
**Hujjat versiyasi**: 3.2.0 (Yakuniy Jamoa Kelishuvi va Backend Arxitekturasi asosida)  
**Holati**: `ACTIVE / APPROVED` (Barcha 8 ta agent uchun majburiy)  
**Asosiy Manbalar**:
- `backend/LexGuard_AI_Backend_Architecture.docx` (D-01 .. D-09 qarorlar, 12 bounded context)
- `mobile/LexGuard_AI_Mobile_Flutter_Architecture.docx` (Clean Arch, Impeller, MASVS-L2)
- `presentation/LexGuard_AI_3_2_Jamoa_Kelishuvi.docx` (4-rangli risk matritsasi, B2B MVP)

---

## 1. Asosiy API Standartlari va Umumiy Konvensiyalar

- **Protokol**: HTTP/1.1 va HTTP/2 (TLS 1.3 shifrlash)
- **Base URL**: `http://localhost:8080/api/v1` (Lokal dev) / `https://api.lexguard.uz/api/v1` (Prod)
- **Format**: JSON (`Content-Type: application/json; charset=utf-8`)
- **Fayl yuklash**: `multipart/form-data` (DOCX, PDF, TXT)
- **Real-Time Stream**: Server-Sent Events (SSE) — `text/event-stream`
- **Vaqt formati**: ISO 8601 UTC (`YYYY-MM-DDTHH:mm:ssZ`)
- **Identifikatorlar**: UUIDv7 (Vaqt bo'yicha saralanadigan 128-bitli identifikatorlar)

### 1.1. Majburiy HTTP Sarlavhalari (Headers)
| Sarlavha | Talab | Misol | Tavsif |
| :--- | :--- | :--- | :--- |
| `Authorization` | Shart (himoyalangan yo'llarda) | `Bearer eyJhbGciOi...` | JWT Access Token |
| `X-Tenant-Id` | Shart (B2B multi-tenant) | `01934f2a-7b3c-7000-8000-000000000001` | Tashkilot UUIDv7 |
| `X-Client-Type` | Shart | `web` \| `mobile` \| `admin` | So'rov yuborgan mijoz platformasi |
| `X-Request-Id` | Shart (yoki backend generatsiya qiladi) | `01934f2a-7b3c-7000-8000-000000000002` | Taqsimlangan tracing (distributed trace) |
| `Idempotency-Key` | Shart (POST mutatsiyalarida) | `01934f2a-7b3c-7000-8000-000000000003` | Takroriy to'lov/tahlil yuklashdan himoya |

---

## 2. Yagona Xato Formati (RFC 7807 Compliant)

Barcha xato javoblari yagona `application/problem+json` strukturasiga ega:

```json
{
  "type": "https://api.lexguard.uz/v1/errors/VALIDATION_ERROR",
  "title": "So'rov ma'lumotlarida xatolik aniqlandi",
  "status": 400,
  "code": "VALIDATION_ERROR",
  "detail": "Yuklangan fayl formati qo'llab-quvvatlanmaydi. Faqat DOCX, PDF va TXT ruxsat etilgan.",
  "instance": "/api/v1/documents",
  "invalid_params": [
    {
      "name": "file",
      "reason": "MIME turi application/x-dosexec qabul qilinmaydi"
    }
  ],
  "request_id": "01934f2a-7b3c-7000-8000-000000000002",
  "timestamp": "2026-11-21T03:15:00Z"
}
```

### Standart Xato Kodlari Matritsasi:
| HTTP Status | Xato Kodi (`code`) | Qachon Qaytariladi |
| :---: | :--- | :--- |
| `400` | `VALIDATION_ERROR` | Maydonlar noto'g'ri, JSON strukturasi buzilgan, fayl hajmi katta |
| `401` | `UNAUTHORIZED` | Token muddati o'tgan, imzo noto'g'ri yoki yo'q |
| `403` | `FORBIDDEN_TENANT` | Foydalanuvchi boshqa tashkilot ma'lumotlariga kirishga uringanda |
| `403` | `CONSENT_REQUIRED` | O'RQ-547/1125 bo'yicha tashqi AI tahliliga foydalanuvchi roziligi berilmagan |
| `404` | `NOT_FOUND` | Hujjat, tahlil yoki manba topilmadi |
| `413` | `PAYLOAD_TOO_LARGE` | Hujjat 25MB (PDF) yoki 15MB (DOCX) limitidan oshib ketgan |
| `415` | `UNSUPPORTED_MEDIA_TYPE` | Magic bytes tekshiruvidan o'tmagan fayl turi |
| `402` | `QUOTA_EXCEEDED` | B2B/B2C tahlillar kvotasi tugagan (Freemium 3 ta yoki tarif limiti) |
| `429` | `RATE_LIMITED` | Daqiqalik yoki sekundlik so'rovlar limiti oshib ketganda |
| `503` | `INTEGRATION_UNAVAILABLE` | Davlat yoki tashqi xizmatlar (Lex.uz, ERI) ishlamay qolganda |

---

## 3. Tahlil Natijalari va 4-Rangli Risk Matritsasi

Jamoa Kelishuvi 3.2 va Backend Arxitektura D-04 ga muvofiq, tizimda 4 xil rang va kategoriyalar qat'iy standartlashtirilgan:

### 3.1. Ranglar va Huquqiy Ma'nolar
| Rang Koding | Backend Kategoriya | Tavsif | Misollar |
| :--- | :--- | :--- | :--- |
| **QIZIL (`RED`)** | `LEGAL` | Qonunga to'g'ridan-to'g'ri zid, bitimning haqiqiy emasligi (haqiqiy emaslik oqibati) yoki jiddiy huquqiy buzulish. | Shartnoma predmeti yo'q (FK 364), Majburiy notarial shakl buzilgan (FK 110), Bir tomonlama asossiz bekor qilish (FK 707). |
| **SARIQ (`YELLOW`)** | `COMMERCIAL` | Tijoriy, moliyaviy yoki operatsion asimmetriya; bir tomon uchun og'ir yoki noqulay shartlar. | Haddan tashqari yuqori penya (FK 326), Fors-major yo'qligi, Cheksiz javobgarlik yuklash, Sudlovlik faqat bir taraf foydasiga. |
| **YASHIL (`GREEN`)** | `BALANCED` | Qonunchilik va bozor standartlariga muvofiq, ikki tomon manfaatlarini teng ifodalovchi bandlar. *Ogohlantirish: Yashil "mutlaq 100% xavfsiz" degani emas!* | Qonuniy da'vo muddatlari, standart topshirish-qabul qilish dalolatnomasi, o'zaro teng javobgarlik. |
| **KULRANG (`GRAY`)** | `UNKNOWN` / `REVIEW_REQUIRED` | AI ishonchsiz tahlil qilgan, OCR sifati past, yoki Go qoidalari va LLM xulosasi zid kelgan, inson (advokat) ko'rigi shart bo'lgan bandlar. | Xorijiy huquqqa havola qilingan band, noaniq skanlangan matn, dispozitiv huquqiy noaniqliklar. |

### 3.2. Verifikatsiya Holat Mashinasi (`VerificationStatus`)
Har bir topilma (`finding`) backend verifikatsiya qatlamidan o'tgach quyidagi 5 holatdan birini oladi:
1. `VERIFIED`: Modda Lex.uz bazasida mavjud, tahrir sanasi shartnoma sanasiga mos (FK 4-modda), sitata asl matndan 90%+ mos.
2. `REVIEW_REQUIRED`: Deterministik Go qoidasi bilan LLM xulosasi zid kelgan yoki majburiy shakl shubhali.
3. `UNVERIFIED`: Iqtibos qilingan modda bazada yo'q yoki LLM to'qib chiqargan (gallyutsinatsiya filtri bloklagan).
4. `UNKNOWN`: Qamrovdan tashqari yoki sifat yetarli emas.
5. `REJECTED`: Verifier tomonidan rad etilgan topilma (mijozga ko'rsatilmaydi).

---

## 4. MVP B2B Shartnomalari uchun 10 ta Deterministik Go Qoidalari

Backend rules dvigateli quyidagi qoida identifikatorlari (`rule_id`) bilan natija ishlab chiqaradi:

1. `SVC_MISSING_SUBJECT_SCOPE`: Xizmat predmeti, hajmi yoki natija mezoni noaniq. (`LEGAL` / `RED`, FK 364, 703-m)
2. `SVC_UNILATERAL_TERMINATION`: Asossiz va xarajatlarni qoplamasdan bir tomonlama bekor qilish. (`LEGAL` / `RED`, FK 707-m)
3. `SVC_UNLIMITED_LIABILITY`: Shartnoma qiymatidan oshuvchi cheksiz zarar undirish talabi. (`COMMERCIAL` / `YELLOW`, FK 324, 333-m)
4. `SVC_PENALTY_FORM_RISK`: Haddan tashqari yuqori jarima/penya (kuniga 0.5% dan yuqori). (`COMMERCIAL` / `YELLOW`, FK 260-263, 326-m)
5. `SVC_PAYMENT_TERMS_AMBIGUOUS`: To'lov shartlari, muddati yoki valyutasi ko'rsatilmagan. (`COMMERCIAL` / `YELLOW`, FK 705-m)
6. `SVC_NO_ACCEPTANCE_ACT`: Qabul qilish dalolatnomasi va e'tiroz bildirish muddati mavjud emas. (`COMMERCIAL` / `YELLOW`, FK 703-706-m)
7. `SVC_FORCE_MAJEURE_MISSING`: Fors-major holatlari va xabardor qilish muddati belgilanmagan. (`COMMERCIAL` / `YELLOW`, FK 333-m 3-qism)
8. `SVC_DISPUTE_ONE_SIDED`: Muzokarasiz to'g'ridan-to'g'ri noqulay sudlovga yuklash. (`COMMERCIAL` / `YELLOW`, IPK me'yorlari)
9. `SVC_CONFIDENTIALITY_IP_GAP`: Tijorat siri va natijaviy IP huquqi o'tish tartibi yo'q. (`COMMERCIAL` / `YELLOW`, FK IV bo'lim, O'RQ-547)
10. `FORM_MANDATORY_NOTARIAL`: Notarial tasdiqlash talab qilinuvchi bitimlar uchun ogohlantirish. (`LEGAL` / `RED`, FK 110-112-m)

---

## 5. To'liq API Endpointlar va Ma'lumotlar Shartnomasi

### 5.1. System & Health
#### `GET /healthz` & `GET /readyz`
- **Javob**:
```json
{
  "status": "UP",
  "database": "UP",
  "pgvector": "UP",
  "redis": "UP",
  "version": "1.0.0"
}
```

#### `GET /api/v1/integrations/status`
Davlat va tashqi xizmatlar holati (Anti-Corruption Mock/Sandbox qatlami):
```json
{
  "integrations": [
    {
      "name": "lex_uz",
      "mode": "MOCK", // MOCK | SANDBOX | PROD
      "description": "Lex.uz Qonunchilik ma'lumotlar bazasi (Offline Vector Corpus)",
      "is_active": true
    },
    {
      "name": "one_id",
      "mode": "MOCK",
      "description": "Yagona identifikatsiya tizimi (Sandbox Test Adapter)",
      "is_active": true
    },
    {
      "name": "e_imzo",
      "mode": "MOCK",
      "description": "E-IMZO Elektron Raqamli Imzo tekshiruvi (O‘RQ-793 Mock)",
      "is_active": true
    }
  ]
}
```

---

### 5.2. Autentifikatsiya va Consent (`/api/v1/auth`)

#### `POST /api/v1/auth/demo-session`
Hech qanday ro'yxatdan o'tmasdan zudlik bilan sinab ko'rish (14 kun / 3 tahlil limitli mehmon sessiyasi):
- **Request**:
```json
{
  "client_fingerprint": "fp_web_987654"
}
```
- **Response** (`200 OK`):
```json
{
  "token_type": "Bearer",
  "access_token": "eyJhbGciOi...",
  "refresh_token": "rt_847382910...",
  "expires_in": 3600,
  "user": {
    "id": "01934f2a-7b3c-7000-8000-000000000010",
    "role": "GUEST",
    "organization_id": "01934f2a-7b3c-7000-8000-000000000001",
    "quota": {
      "plan": "DEMO",
      "analyses_used": 0,
      "analyses_limit": 3,
      "remaining": 3
    }
  }
}
```

#### `POST /api/v1/auth/consents`
O'RQ-547 va O'RQ-1125 bo'yicha Shaxsiy Ma'lumotlarni qayta ishlash va tashqi AI ga maskalangan uzatishga rozilik:
- **Request**:
```json
{
  "consent_type": "EXTERNAL_AI_PROCESSING",
  "version": "1.0",
  "accepted": true
}
```
- **Response** (`200 OK`):
```json
{
  "consent_id": "01934f2a-7b3c-7000-8000-000000000020",
  "accepted_at": "2026-11-21T03:15:30Z"
}
```

---

### 5.3. Hujjatlarni Yuklash (`/api/v1/documents`)

#### `POST /api/v1/documents`
- **Content-Type**: `multipart/form-data`
- **Parametrlar**:
  - `file`: Binar fayl (DOCX, PDF, TXT)
  - `title`: Ixtiyoriy hujjat nomi (masalan: "IT Xizmat Shartnomasi.docx")
  - `document_type`: `B2B_SERVICE` | `SUPPLY_SALE` | `COMMERCIAL_LEASE` | `UNKNOWN`
- **Response** (`201 Created`):
```json
{
  "id": "01934f2a-7b3c-7000-8000-000000000100",
  "filename": "IT_Xizmat_Shartnomasi.docx",
  "file_size": 245760,
  "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "data_classification": "CONFIDENTIAL",
  "parse_confidence": 0.98,
  "total_clauses": 18,
  "created_at": "2026-11-21T03:16:00Z"
}
```

---

### 5.4. Tahlil Boshlash va Real-Time Kuzatuv (`/api/v1/analyses`)

#### `POST /api/v1/analyses`
- **Request**:
```json
{
  "document_id": "01934f2a-7b3c-7000-8000-000000000100",
  "contract_date": "2026-05-15",
  "my_party_role": "EXECUTOR", // EXECUTOR | CUSTOMER | NEUTRAL
  "execution_mode": "HYBRID_RULES_AI" // RULES_ONLY | HYBRID_RULES_AI
}
```
- **Response** (`202 Accepted`):
```json
{
  "analysis_id": "01934f2a-7b3c-7000-8000-000000000200",
  "status": "PROCESSING",
  "stream_url": "/api/v1/analyses/01934f2a-7b3c-7000-8000-000000000200/events"
}
```

#### `GET /api/v1/analyses/{id}/events` (SSE Stream)
Server real vaqt rejimida bosqichlarni uzatadi:

1. **Bosqich o'zgarishi** (`event: stage_changed`):
```json
{
  "stage": "EXTRACTING_CLAUSES", // PARSING -> PII_REDACTION -> RULES_ENGINE -> RAG_RETRIEVAL -> VERIFICATION -> DONE
  "progress_pct": 20
}
```

2. **Alohida topilma darhol qaytishi** (`event: partial_finding`):
```json
{
  "finding_id": "01934f2a-7b3c-7000-8000-000000000301",
  "clause_number": "7.3",
  "risk_level": "RED",
  "category": "LEGAL",
  "rule_id": "SVC_UNILATERAL_TERMINATION",
  "title": "Asossiz bir tomonlama bekor qilish huquqi"
}
```

3. **Tahlil yakunlanishi** (`event: completed`):
```json
{
  "analysis_id": "01934f2a-7b3c-7000-8000-000000000200",
  "status": "COMPLETED",
  "completed_at": "2026-11-21T03:16:15Z"
}
```

---

### 5.5. Shartnoma Tahlilining To'liq Natijasi (`GET /api/v1/analyses/{id}`)

Frontend (React), Mobile (Flutter) va Admin panellar ushbu yagona sxemadan foydalanadi:

```json
{
  "id": "01934f2a-7b3c-7000-8000-000000000200",
  "document": {
    "id": "01934f2a-7b3c-7000-8000-000000000100",
    "filename": "IT_Xizmat_Shartnomasi.docx",
    "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "contract_date": "2026-05-15",
    "document_type": "B2B_SERVICE"
  },
  "summary": {
    "total_clauses": 18,
    "red_count": 2,
    "yellow_count": 4,
    "green_count": 11,
    "gray_count": 1,
    "balance_label": "Buyurtmachiga og'ir", // Muvozanatli | [Taraf A]ga og'ir | [Taraf B]ga og'ir
    "top_risks": [
      "Buyurtmachi shartnomani 0 kunlik ogohlantirishsiz bekor qilishi mumkin (FK 707)",
      "Ijrochi zimmasiga cheksiz moddiy javobgarlik yuklangan (FK 324)",
      "Qabul qilish dalolatnomasi bo'yicha e'tiroz muddati belgilanmagan"
    ]
  },
  "findings": [
    {
      "id": "01934f2a-7b3c-7000-8000-000000000301",
      "clause_id": "01934f2a-7b3c-7000-8000-000000000115",
      "clause_number": "7.3",
      "original_quote": "Buyurtmachi istalgan vaqtda Ijrochini oldindan ogohlantirmasdan va sarflangan xarajatlarni qoplamasdan shartnomani bir tomonlama bekor qilish huquqiga ega.",
      "risk_level": "RED",
      "category": "LEGAL",
      "verification_status": "VERIFIED",
      "rule_id": "SVC_UNILATERAL_TERMINATION",
      "issue_title": "Asossiz bir tomonlama bekor qilish huquqi",
      "issue_explanation": "O‘zbekiston Respublikasi Fuqarolik Kodeksining 707-moddasiga ko‘ra, xizmat ko‘rsatish shartnomasidan bir tomonlama voz kechilganda, Buyurtmachi Ijrochiga u qilgan haqiqiy xarajatlarni to‘lashi shart.",
      "legal_basis": {
        "source_title": "O‘zbekiston Respublikasi Fuqarolik Kodeksi",
        "article": "707-modda (Haq evaziga xizmat ko‘rsatish shartnomasini bajarishdan bosh tortish)",
        "lex_uz_url": "https://lex.uz/docs/111181#111905",
        "norm_nature": "IMPERATIVE",
        "effective_from": "1997-03-01"
      },
      "suggested_redline": "Buyurtmachi shartnomani bekor qilishdan kamida 15 (o‘n besh) kun oldin Ijrochini yozma xabardor qiladi hamda Ijrochi tomonidan amalda bajarilgan xizmatlar haqini va asoslangan xarajatlarini to‘liq qoplaydi.",
      "redline_reasoning": "Ijrochining kutilmagan moliyaviy yo'qotishlarini oldini oladi va FK 707-moddasiga to'liq mos keladi."
    },
    {
      "id": "01934f2a-7b3c-7000-8000-000000000302",
      "clause_id": "01934f2a-7b3c-7000-8000-000000000118",
      "clause_number": "9.1",
      "original_quote": "Ijrochi har bir kechiktirilgan kun uchun shartnoma umumiy summasining 1% miqdorida penya to'laydi.",
      "risk_level": "YELLOW",
      "category": "COMMERCIAL",
      "verification_status": "VERIFIED",
      "rule_id": "SVC_PENALTY_FORM_RISK",
      "issue_title": "Nomutanosib yuqori penya miqdori",
      "issue_explanation": "Bozor amaliyotida penya sutkasiga 0.1% - 0.2% dan oshmasligi tavsiya etiladi. Shuningdek, FK 326-moddasi asossiz yuqori neustoykani sud orqali kamaytirish huquqini beradi.",
      "legal_basis": {
        "source_title": "O‘zbekiston Respublikasi Fuqarolik Kodeksi",
        "article": "326-modda (Neustoykani kamaytirish)",
        "lex_uz_url": "https://lex.uz/docs/111181#111520",
        "norm_nature": "DISPOSITIVE",
        "effective_from": "1997-03-01"
      },
      "suggested_redline": "Ijrochi har bir kechiktirilgan kun uchun bajarilmagan majburiyat summasining 0.1% miqdorida, lekin umumiy shartnoma summasining 10% idan oshmagan miqdorda penya to'laydi.",
      "redline_reasoning": "Tijoriy xavfni cheklaydi va ikki tomonlama adolatli limit o'rnatadi."
    }
  ],
  "disclaimer": "DIQQAT: Ushbu tahlil avtomatlashtirilgan axborot-tahliliy vosita (AI) tomonidan tayyorlangan bo'lib, rasmiy yuridik xulosa hisoblanmaydi. Murakkab va ziddiyatli holatlarda malakali advokat bilan maslahatlashish tavsiya etiladi (O‘RQ-1115)."
}
```

---

### 5.6. Hisobot Eksporti (`GET /api/v1/analyses/{id}/report`)

- **Formatlar**: `?format=docx` (Takliflar bilan DOCX) | `?format=pdf` (Audit bayonnomasi) | `?format=json`
- **Tarkibi**:
  - Hujjat rekvizitlari va sha256 checksum
  - 4 rangli xavflar tahlili jadvali
  - Har bir xavf bandining qonuniy asosi va Lex.uz havolasi
  - Taklif etilgan yuridik tuzatishlar (redline)
  - Kelishmovchiliklar bayonnomasi (Protokol raznoglasiy)

---

## 6. Frontend va Mobile uchun Mocking & Tejamkor Sinov Rejimi

Go backend to'liq ishga tushguncha Frontend, Mobile va Admin jamoalari bloklanmasligi uchun:
1. `GET /api/v1/mock/analysis-sample`: Yuqoridagi to'liq 4-rangli tahlil natijasini qaytaradi.
2. Har bir so'rovga `X-Mock: true` headeri yuborilganda backend avtomatik deterministik soxta ma'lumot qaytaradi.
