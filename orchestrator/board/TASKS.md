# 📋 Sprint Topshiriqlar Taxtasi & Definition of Done (TASKS.md)
**Loyiha**: LexGuard AI (LexHackathon 2026, 1-trek: Huquqiy xizmatlar)  
**Tizim**: 8-Profil Avtonom Ko'p Agentli Klaster  
**Holati**: Sprint 1 (MVP Ishga Tushirish)  
**Belgilar**: `[ ] TODO` | `[~] IN_PROGRESS` | `[?] REVIEW` | `[x] DONE`

---

## 🎯 Global Definition of Done (DoD) — Qabul Qilishning Qat'iy Shartlari

Har qanday modul yoki vazifa faqat quyidagi 6 ta filtrdan o'tgandagina `DONE` deb hisoblanadi:
1. **Arxitektura va Bog'liqlik Invariantlari**: `LexGuard_AI_Backend_Architecture.docx` (D-01..D-10) va Clean Architecture qoidalariga 100% muvofiqlik. Domendan tashqariga qaramaslik.
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
- [x] **TASK-004 [P0]**: Agentlararo bog'liqliklarni boshqarish va blokerlarni yo'q qilish (Doimiy).
- [x] **TASK-005 [P0]**: Pro Glanceable UI/UX, 3D Visualizer va Live Voice Assistant spetsifikatsiyasini tasdiqlash (D-10).
- [~] **TASK-006 [P1]**: Yakuniy integratsion auditi va MVP qabul qilish komissiyasi tekshiruvi.

---

## ⚙️ 1. Go Backend Modular Monolith (`agy2` — 1-BACKEND-GO)
*Go 1.23+, chi/v5, pgx/v5, PostgreSQL 16 + pgvector, Modular Monolith (12 bounded context).*

- [x] **TASK-101 [P0]**: Go loyihasi strukturasi (`cmd/server`, `internal/api`, `internal/identity`, `internal/documents`, `internal/rules`, `internal/verification`, `internal/analysis`) va `go.mod` ni yaratish.
- [x] **TASK-102 [P0]**: PostgreSQL 16 sxemasi va migratsiyalari (`migrations/0001_init.sql` — 19 ta jadval: users, orgs, documents, clauses, legal_sources, analyses, findings, quotas, audit_events va hk).
- [x] **TASK-103 [P0]**: 10 ta Deterministik Go B2B qoidalar dvigateli (`internal/rules/service.go`).
- [x] **TASK-104 [P0]**: REST API endpointlari va RFC 7807 xatolar qatlami (`internal/api/`): `/healthz`, `/readyz`, `/api/v1/integrations/status`, `/api/v1/documents`, `/api/v1/analyses`.
- [x] **TASK-105 [P0]**: SSE Real-Time hodisalar oqimi (`/api/v1/analyses/{id}/events`).
- [x] **TASK-106 [P0]**: AI Live Voice Assistant API endpointlari (`/api/v1/analyses/{id}/voice-brief` va `/api/v1/analyses/{id}/voice-query`).
- [x] **TASK-107 [P1]**: Verifikatsiya va Gallyutsinatsiyalarga qarshi qatlam (`internal/verification/`).
- [x] **TASK-108 [P1]**: DOCX va PDF hisobot eksporti generatori (`internal/report/`).

---

## 📱 2. Flutter Mobile Client (`agy3` — 2-MOBILE-FLUTTER)
*Flutter 3.38+, Dart 3.10+, Impeller 60/120 FPS, Feature-First Clean Architecture, Soliq-Style iOS Glassmorphism UI.*

- [x] **TASK-201 [P0]**: Flutter loyihasi va 6-platformali Feature-First Clean Architecture poydevorini qurish.
- [x] **TASK-202 [P0]**: Soliq App uslubidagi Dual-Role Mavzulari (Sapphire Individual & Emerald Business) va Glassmorphism.
- [x] **TASK-203 [P0]**: Hujjat tanlash va yuklash oqimi (`features/scanner_upload`): MIME tekshiruvi, PII maskalash.
- [x] **TASK-204 [P0]**: 3D Effect Radial Health Gauge (`GlanceableRiskGauge`): 0-100 xavfsizlik o'lchagichi va DNA Barcode Heatmap lentasi.
- [x] **TASK-205 [P0]**: Mobile AI Live Voice Assistant Bar (`MobileVoiceAssistantBar`): 30s Audio brifing pleyeri va jonli animatsiyali audio to'lqinlar (waveform).
- [x] **TASK-206 [P0]**: Avtotestlar: Barcha 6 ta unit/widget testlar (PII redaction, Soliq UI, ContractsCubit) yashil o'tishi.
- [~] **TASK-207 [P1]**: Shifrlangan Offline Kesh (`local_demo_lexguard_repository.dart`).

---

## 🌐 3. Web Frontend & Visualizer (`agy4` — 3-WEB-FRONT)
*React 18+, TypeScript, Vite, Tailwind CSS, Three.js 3D Risk Visualizer, Live Voice Assistant.*

- [x] **TASK-301 [P0]**: React + Vite + Tailwind CSS poydevorini ko'tarish (`npm run build` muvaffaqiyatli).
- [x] **TASK-302 [P0]**: Hujjat yuklash maydoni (Drag & Drop + Demo sinov tugmasi, SHA256 hisoblash).
- [x] **TASK-303 [P0]**: Yonma-yon Taqqoslash (Side-by-Side Legal Diff Viewer): 4 rangli xavflar va Lex.uz havolalari.
- [x] **TASK-304 [P0]**: Glanceable Visual Health Gauge (`ContractHealthGauge.tsx`): 0-100 radial speedometer, DNA barcode lentasi, moliyaviy asimmetriya ko'rsatkichi.
- [x] **TASK-305 [P0]**: Three.js WebGL 3D Risk Visualizer (`Contract3DVisualizer.tsx` va `Mini3DVisualizer.tsx`): interaktiv sferik neyron to'r, orbita zarrachalari va klaster tugunlari.
- [x] **TASK-306 [P0]**: Live AI Voice Assistant (`LiveVoiceAssistant.tsx`): Web Speech API audio sintezi, jonli sinusoidal to'lqin kanvasi, real-time ovozli savol-javob.
- [x] **TASK-307 [P1]**: Redline DOCX va Audit PDF eksporti (`front/src/utils/export.ts`).

---

## 📊 4. Admin & B2B Analytics Portal (`agy5` — 4-ADMIN-PORTAL)
*B2B korporativ kabinet, shartnomalar monitoringi, kvota va bo'limlar xavf xaritasi.*

- [x] **TASK-401 [P0]**: Enterprise Admin Portal poydevori va Dashboard shabloni.
- [x] **TASK-402 [P0]**: Korxona Shartnomalari Reestri va Xavflar Xaritasi (Bo'limlar kesimida).
- [~] **TASK-403 [P1]**: Kvotalar, Tariflar va Audit Tarixi (Audit Trail): oylik limitlar va xodimlar harakati jurnali.

---

## ⚖️ 5. Legal AI & Temporal RAG Specialist (`agy6` — 5-LEGAL-RAG-AI)
*O'zbekiston Qonunchiligi (Lex.uz), Temporal RAG, 10-bosqichli Anti-Hallucination bilimlari.*

- [x] **TASK-501 [P0]**: O'zbekiston B2B qonunlari korpusini tayyorlash (`seeds/seed.sql` — FK 364, 707, 326, O‘RQ-547, O‘RQ-1115).
- [x] **TASK-502 [P0]**: Qat'iy Yopiq Dunyo (Closed-World) Yuridik Prompt Shablonlari (0 ta uydirma modda).
- [x] **TASK-503 [P0]**: Shaxsiy Ma'lumotlarni Lokal Anonimizatsiya Qilish (PII Masking O'RQ-547).
- [~] **TASK-504 [P1]**: Temporal Qidiruv Qoidasi (FK 4-modda bo'yicha tarixiy normani tekshirish).

---

## 🛡️ 6. QA & Security Lead (`agy7` — 6-QA-SECURITY)
*OWASP Top 10, OWASP MASVS-L2, yuklama testlari, ma'lumotlar xavfsizligi auditi.*

- [x] **TASK-601 [P0]**: Fayl Xavfsizligi va Sandbox Sanitization Auditi: Magic-byte sniffing, makros xavfsizligi.
- [x] **TASK-602 [P0]**: OWASP MASVS-L2 Mobil Xavfsizlik Tekshiruvi: Skrinshot bloklash, PII himoyasi.
- [x] **TASK-603 [P0]**: Web Speech API va 3D WebGL xotira auditlari (Memory leak 0%).
- [~] **TASK-604 [P1]**: Stress va Pentest ssenariylari (Fuzzing).

---

## 🚀 7. DevOps, SRE & CI/CD Lead (`agy8` — 7-DEVOPS-INFRA)
*Docker, docker-compose, CI/CD konveyeri, yagona idempotent ishga tushirish skripti.*

- [x] **TASK-701 [P0]**: `docker-compose.yml` (PostgreSQL 16 + pgvector, Redis, Go backend, Web front).
- [x] **TASK-702 [P0]**: Idempotent `./scripts/run_dev.sh` yagona start skripti.
- [~] **TASK-703 [P1]**: GitHub Actions CI konveyeri (`.github/workflows/ci.yml`).
