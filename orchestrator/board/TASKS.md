# 📋 Sprint Topshiriqlar Taxtasi & Definition of Done (TASKS.md)
**Loyiha**: LexGuard AI (LexHackathon 2026, 1-trek: Huquqiy xizmatlar)  
**Tizim**: 8-Profil Avtonom Ko'p Agentli Klaster  
**Holati**: Sprint 1 (MVP Ishga Tushirish)  
**Belgilar**: `[ ] TODO` | `[~] IN_PROGRESS` | `[?] REVIEW` | `[x] DONE`

---

## 🎯 Global Definition of Done (DoD) — Qabul Qilishning Qat'iy Shartlari

Har qanday modul yoki vazifa faqat quyidagi 6 ta filtrdan o'tgandagina `DONE` deb hisoblanadi:
1. **Arxitektura va Bog'liqlik Invariantlari**: `LexGuard_AI_Backend_Architecture.docx` (D-01..D-09) va Clean Architecture qoidalariga 100% muvofiqlik. Domendan tashqariga qaramaslik.
2. **API Shartnomasiga To'liq Moslik**: Barcha DTO va endpointlar `orchestrator/board/CONTRACTS.md` spetsifikatsiyasi bilan 100% bir xil bo'lishi.
3. **10-Vektorli Anti-Gallyutsinatsiya Himoyasi**: Soxta moddalar, uydirma URL yoki xato tahrirlar 0% bo'lishi. Barcha iqtiboslar Verifier orqali `VERIFIED` maqomini olishi.
4. **Chuqur Xavfsizlik va Maxfiylik**: O‘RQ-547 va O‘RQ-1125 bo'yicha PII maskalash, OWASP MASVS-L2 mobil talablari va magic-byte MIME tekshiruvi.
5. **Avtomatlashtirilgan Testlar**: Unit testlar (kamida 80% qamrov), integratsion testlar va CI pipeline ning yashil o'tishi.
6. **Bitta Bash Skript Bilan Ishga Tushish**: `./scripts/run_dev.sh` orqali butun tizim bir martada sozlanib, to'xtovsiz ko'tarilishi.

---

## 👑 0. Orchestrator & Boshqaruv (`agy1` — 0-ORCHESTRATOR)
*Tizim Bosh Arxitektori, sinxronizatsiya va sifat darvozalari boshqaruvchisi.*

- [x] **TASK-001 [P0]**: 8 ta mustaqil agent profillari va tmux arxitekturasini sozlash (`orchestrator/bin/`).
- [x] **TASK-002 [P0]**: Tizimlararo API va Data shartnomasini tasdiqlash (`orchestrator/board/CONTRACTS.md`).
- [x] **TASK-003 [P0]**: Detallashtirilgan sprint topshiriqlari va DoD talablarini ishlab chiqish (`orchestrator/board/TASKS.md`).
- [~] **TASK-004 [P0]**: Agentlararo bog'liqliklarni boshqarish va blokerlarni yo'q qilish (Doimiy).
- [ ] **TASK-005 [P1]**: Yakuniy integratsion auditi va MVP qabul qilish komissiyasi tekshiruvi.

---

## ⚙️ 1. Go Backend Modular Monolith (`agy2` — 1-BACKEND-GO)
*Go 1.23+, chi/v5, pgx/v5, PostgreSQL 16 + pgvector, Modular Monolith (12 bounded context).*

- [ ] **TASK-101 [P0]**: Go loyihasi strukturasi (`cmd/server`, `internal/platform`, `internal/identity`, `internal/documents`, `internal/rules`, `internal/verification`, `internal/analysis`) va `go.mod` ni yaratish.
  - *DoD*: `go build ./...` xatosiz o'tishi, Hexagonal arxitektura papkalari ajratilgan.
- [ ] **TASK-102 [P0]**: PostgreSQL 16 sxemasi va migratsiyalari (`migrations/0001_init.sql` — 19 ta jadval: users, orgs, documents, clauses, legal_sources, analyses, findings, quotas, audit_events va hk).
  - *DoD*: Migratsiya idempotent ishlaydi, UUIDv7 PK, GIN va pgvector indekslari o'rnatilgan.
- [ ] **TASK-103 [P0]**: 10 ta Deterministik Go B2B qoidalar dvigateli (`internal/rules/service.go`).
  - *DoD*: `SVC_MISSING_SUBJECT_SCOPE`, `SVC_UNILATERAL_TERMINATION`, `SVC_PENALTY_FORM_RISK` va boshqa 7 ta qoida testlar bilan qoplangan.
- [ ] **TASK-104 [P0]**: REST API endpointlari va RFC 7807 xatolar qatlami (`internal/api/`):
  - `/healthz`, `/readyz`, `/api/v1/integrations/status`
  - `/api/v1/auth/demo-session`, `/api/v1/auth/consents`
  - `/api/v1/documents` (Multipart streaming yuklash, MIME sniffing)
  - `/api/v1/analyses` (POST boshlash, GET natija olish)
  - *DoD*: `CONTRACTS.md` ga 100% mos JSON qaytaradi, unit testlar mavjud.
- [ ] **TASK-105 [P0]**: SSE Real-Time hodisalar oqimi (`/api/v1/analyses/{id}/events`).
  - *DoD*: `stage_changed`, `partial_finding`, `completed` hodisalari uzatiladi, uzilishda qayta ulanadi.
- [ ] **TASK-106 [P1]**: Verifikatsiya va Gallyutsinatsiyalarga qarshi qatlam (`internal/verification/`).
  - *DoD*: FK 4-modda bo'yicha temporal tekshiruv, modda mavjudligi va iqtibos o'xshashligi (90%+).
- [ ] **TASK-107 [P1]**: DOCX va PDF hisobot eksporti generatori (`internal/report/`).
  - *DoD*: Redline takliflar, moddalar havolasi va xavflar jadvali shakllantirilgan Word hujjati.

---

## 📱 2. Flutter Mobile Client (`agy3` — 2-MOBILE-FLUTTER)
*Flutter 3.24+, Dart 3.5+, Impeller 60/120 FPS, Feature-First Clean Architecture, Material 3 LegalTech.*

- [ ] **TASK-201 [P0]**: Flutter loyihasi va Feature-First Clean Architecture poydevorini qurish:
  - `features/auth/`, `features/contract_scan/`, `features/analysis_report/`, `features/legal_chat/`
  - *DoD*: `flutter analyze` 0 ta warning, BLoC holat boshqaruvi va dependency injection sozlandi.
- [ ] **TASK-202 [P0]**: Material 3 LegalTech mavzusi va UI komponentlar kutubxonasi:
  - Dark / Light mode qo'llab-quvvatlash.
  - 4 xil risk ranglari: Qizil (`#E53935`), Sariq (`#FB8C00`), Yashil (`#43A047`), Kulrang (`#757575`).
  - *DoD*: 60/120 FPS Impeller unumdorligi, ortiqcha frame drop (jank) 0%.
- [ ] **TASK-203 [P0]**: Hujjat tanlash va yuklash oqimi (`features/contract_scan`):
  - Kamera orqali hujjat rasmini olish va PDF/DOCX fayllarni tanlash.
  - MIME xavfsizligi va hajmini mijoz tomonida dastlabki tekshirish.
  - *DoD*: Fayl tanlanganda Activity crash bo'lmaydi (`retrieveLostData` himoyasi).
- [ ] **TASK-204 [P0]**: Real-time Tahlil ekrani va SSE / Polling oqimi (`features/analysis_report`):
  - SSE orqali bosqichma-bosqich yuklanishni ko'rsatish (Lottie animatsiya yoki Shimmer).
  - Internet uzilganda avtomatik exponential-backoff polling fallback.
  - *DoD*: Alohida topilmalar jonli oqib keladi.
- [ ] **TASK-205 [P0]**: Interaktiv Tahlil Natijalari Ko'rinishi (Executive Dashboard):
  - Xavflar xulosasi (Qizil, Sariq, Yashil, Kulrang kartalar).
  - Har bir band bo'yicha qonun moddasi, Lex.uz havolasi va tavsiya qilingan tuzatish (redline).
  - *DoD*: "Yashil = 100% xavfsiz emas" va O'RQ-1115 yuridik ogohlantirishlari mavjud.
- [ ] **TASK-206 [P1]**: Shifrlangan Offline Kesh (`hive` yoki `drift` + SQLCipher):
  - Oldingi ko'rilgan shartnomalar tahlilini offline rejimda ham ko'rsatish.
  - *DoD*: Samolyot rejimida ilova xatosiz ishlaydi.

---

## 🌐 3. Web Frontend & Visualizer (`agy4` — 3-WEB-FRONT)
*React 18+, TypeScript, Vite, Tailwind CSS, Side-by-side Legal Diff Viewer.*

- [ ] **TASK-301 [P0]**: React + Vite + Tailwind CSS poydevorini ko'tarish:
  - Loyiha strukturasi, router, API mijozi (Axios / Fetch + SSE adapter).
  - *DoD*: `npm run build` muvaffaqiyatli, responsive dizayn poydevori tayyor.
- [ ] **TASK-302 [P0]**: Hujjat yuklash maydoni (Drag & Drop + Demo sinov tugmasi):
  - DOCX, PDF, TXT fayllarni tashlash, yuklash progressi.
  - Demo mehmon sessiyasi orqali darhol 1 ta namunaviy shartnomani sinash imkoniyati.
  - *DoD*: Fayl yuklashda sha256 checksum hisoblanadi.
- [ ] **TASK-303 [P0]**: Yonma-yon Taqqoslash (Side-by-Side Legal Diff Viewer):
  - Chap tomonda: Asl shartnoma matni va belgilangan xavfli bandlar.
  - O'ng tomonda: Tavsiya qilingan qonuniy tahrir (redline) va Lex.uz moddalari.
  - *DoD*: Matnlar qatori sinxron skroll bo'ladi, xavflar 4 rangda belgilanadi.
- [ ] **TASK-304 [P1]**: Interaktiv Risk Metrikalari & Vizualizatsiya:
  - Shartnoma xavf spektri (Qizil, Sariq, Yashil taqsimoti).
  - Taraflar manfaati balansi indikatori ("Buyurtmachiga og'ir" / "Ijrochiga og'ir").
  - *DoD*: Mobil va desktop brauzerlarda yuqori tezlikda render bo'ladi.
- [ ] **TASK-305 [P1]**: Tahlil natijasini DOCX va PDF formatda yuklab olish tugmalari.

---

## 📊 4. Admin & B2B Analytics Portal (`agy5` — 4-ADMIN-PORTAL)
*B2B korporativ kabinet, shartnomalar monitoringi, kvota va foydalanuvchilar boshqaruvi.*

- [ ] **TASK-401 [P0]**: Enterprise Admin Portal poydevori va Dashboard shabloni:
  - B2B tashkilot ma'lumotlari, jami tekshirilgan shartnomalar hisoblagichlari.
  - *DoD*: Toza boshqaruv paneli, yuklanish indikatorlari.
- [ ] **TASK-402 [P0]**: Korxona Shartnomalari Reestri va Xavflar Xaritasi:
  - Bo'limlar (Savdo, Ta'minot, HR, IT) kesimidagi xavf statistikasi.
  - Shartnomalar bo'yicha qidiruv, filtr (Qizil/Sariq/Yashil) va tafsilotlar modali.
  - *DoD*: Jadval kursorli sahifalash bilan ishlaydi.
- [ ] **TASK-403 [P1]**: Kvotalar, Tariflar va Audit Tarixi (Audit Trail):
  - Oylik tahlillar limiti, ishlatilgan miqdor, qo'shimcha paketlar.
  - Qaysi xodim qaysi shartnomani tekshirgani haqida o'zgarmas jurnal.
  - *DoD*: `GET /api/v1/admin/overview` va `quotas` bilan to'liq bog'langan.

---

## ⚖️ 5. Legal AI & Temporal RAG Specialist (`agy6` — 5-LEGAL-RAG-AI)
*O'zbekiston Qonunchiligi (Lex.uz), Temporal RAG, 10-bosqichli Anti-Hallucination bilimlari.*

- [ ] **TASK-501 [P0]**: O'zbekiston B2B qonunlari korpusini tayyorlash (`seeds/legal_corpus.json`):
  - Fuqarolik Kodeksi (FK 364, 703, 705, 707, 324, 326, 333, 110-112).
  - O‘RQ-547 (Shaxsiy ma'lumotlar), O‘RQ-1115 (AI nazorati), O‘RQ-1125.
  - *DoD*: Har bir moddada: `title`, `article`, `norm_nature` (IMPERATIVE/DISPOSITIVE), `effective_from`, `lex_uz_url`.
- [ ] **TASK-502 [P0]**: Qat'iy Yopiq Dunyo (Closed-World) Yuridik Prompt Shablonlari:
  - Prompt hech qachon bazada yo'q moddani eslashga yo'l qo'ymaydi.
  - Format faqat `CONTRACTS.md` sxemasiga mos JSON chiqarishi ta'minlangan.
  - *DoD*: 0 ta xayoliy qonun moddasi chiqarishi testlar orqali isbotlangan.
- [ ] **TASK-503 [P0]**: Shaxsiy Ma'lumotlarni Lokal Anonimizatsiya Qilish (PII Masking):
  - F.I.Sh., pasport/JShShIR, telefon raqamlar, bank rekvizitlarini AI ga yuborishdan oldin tozalash.
  - *DoD*: O'RQ-547 talablariga 100% javob beradi, tashqi AI ga PII chiqmaydi.
- [ ] **TASK-504 [P1]**: Temporal Qidiruv Qoidasi (FK 4-modda):
  - Agar shartnoma 2024-yilda tuzilgan bo'lsa, qidiruv 2024-yilgi qonun tahriri bo'yicha cheklanadi.

---

## 🛡️ 6. QA & Security Lead (`agy7` — 6-QA-SECURITY)
*OWASP Top 10, OWASP MASVS-L2, yuklama testlari, ma'lumotlar xavfsizligi auditi.*

- [ ] **TASK-601 [P0]**: Fayl Xavfsizligi va Sandbox Sanitization Auditi:
  - MIME-type sniffing (fayl kengaytmasiga emas, birinchi 512 bayt magic byte'larga qarab tekshirish).
  - Zudlik bilan xavfli makroslar va o'rnatilgan skriptlarni zararsizlantirish.
  - *DoD*: Xavfli `.exe`, `.bat` yoki makrosli docx fayllar 415 xato bilan qaytariladi.
- [ ] **TASK-602 [P0]**: OWASP MASVS-L2 Mobil Xavfsizlik Tekshiruvi:
  - `FLAG_SECURE` (skrinshot olishni taqiqlash), SSL Pinning, Tokenlarni Keystore/Keychain da saqlash.
  - *DoD*: Check-list 100% to'ldirilgan va mobil kodda tasdiqlangan.
- [ ] **TASK-603 [P1]**: Integratsion E2E Testlar va API Stress Testi:
  - Hujjat yuklashdan tahlil natijasini olishgacha bo'lgan to'liq zanjir testi.
  - *DoD*: 50 ta parallel so'rovda tizim buzilmaydi, p95 javob vaqti normada.

---

## 🚀 7. DevOps & Infrastructure Lead (`agy8` — 7-DEVOPS-INFRA)
*Docker-compose, multi-stage Dockerfiles, yagona start skripti, CI konveyeri.*

- [ ] **TASK-701 [P0]**: Yagona Idempotent Start Skripti (`scripts/run_dev.sh` va `scripts/start.sh`):
  - Docker daemonni tekshirish, konteynerlarni ko'tarish, DB migratsiyasini bajarish, seed yuklash va backendni ishga tushirish.
  - *DoD*: Boshqa hech narsa talab qilmasdan bitta buyruq bilan tizim to'liq ko'tariladi.
- [ ] **TASK-702 [P0]**: Multi-Container `docker-compose.yml`:
  - PostgreSQL 16 (pgvector kengaytmasi bilan).
  - Redis 7 (keshlash va rate-limit).
  - Go Backend container.
  - Web Frontend (Nginx static build).
  - *DoD*: `docker compose up -d` xatosiz ko'tariladi, volume'lar saqlanadi.
- [ ] **TASK-703 [P1]**: GitHub Actions CI Workflow (`.github/workflows/ci.yml`):
  - Go lint & test, Web build & lint, Flutter test tekshiruvi.
  - *DoD*: Har bir PR avtomatik tekshiruvdan o'tadi.

---

## 🔗 Agentlararo Bog'liqliklar va Blokerlarni Yechish Matritsasi

```
[CONTRACTS.md] (Orchestrator tomonidan tasdiqlandi)
       │
       ├──► Backend (TASK-101 .. TASK-104) ──┐
       │                                     ▼
       ├──► Web Front (TASK-301 .. 303) ──► E2E Integratsiya (TASK-603)
       │                                     ▲
       ├──► Mobile (TASK-201 .. 205) ────────┤
       │                                     │
       └──► Admin (TASK-401 .. 403) ─────────┘
```

> **MUHIM ESLATMA (Zero Blocker Protocol)**:
> Flutter Mobile, Web Front va Admin Portal jamoalari Go Backend ning to'liq tayyor bo'lishini kutib o'tirmaydi! `CONTRACTS.md` dagi to'liq JSON sxemasi va Mock qatlamidan foydalanib barcha UI va mijoz mantiqini parallel ravishda 100% qurib chiqadilar.
