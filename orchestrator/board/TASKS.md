# 📋 LexGuard AI 3.0 — Yangilangan Sprint Topshiriqlar Taxtasi & DoD (TASKS.md)

**Loyiha**: LexGuard AI (LexHackathon 2026, 1-trek: Huquqiy xizmatlar)  
**Tizim**: 8-Profil Avtonom Ko'p Agentli Klaster  
**Boshqaruv Hujjati**: `orchestrator/board/ARCHITECTURE_BLUEPRINT.md` (v4.0.0)  
**Belgilar**: `[ ] TODO` | `[~] IN_PROGRESS` | `[?] REVIEW` | `[x] DONE`

---

## 🎯 Global Definition of Done (DoD)
1. **Arxitektura Invariantlari**: `ARCHITECTURE_BLUEPRINT.md` (v4.0.0) talablariga 100% muvofiqlik.
2. **gRPC va API Kontrakti**: `proto/legal_ai.proto` va `CONTRACTS.md` spetsifikatsiyalari bo'yicha qat'iy tiplash.
3. **Anti-Gallyutsinatsiya & Active Self-Correction**: Lex.uz bazasi bilan tasdiqlanmagan moddalar 0%; AI xato qilsa verifikator qayta qidiruv bilan AI ga tuzatish berishi shart.
4. **Chuqur Xavfsizlik**: O'RQ-547 PII maskalash, OWASP MASVS-L2 mobil xavfsizlik, FLAG_SECURE.
5. **UI/UX Standarti**: Webda Robin AI / Harvey uslubidagi Studio (Inline highlights + Inspector + 1-click diff); Mobilda Soliq Glassmorphism (Dual-theme Sapphire/Emerald + FAB skaner + Draggable BottomSheet).
6. **Bitta Skript Bilan Ishga Tushish**: `./scripts/run_dev.sh` orqali butun stack (Go + Python AI + Web + Mobile + Admin + DB + Redis + MinIO) bir martada ko'tarilishi.

---

## 👑 0. Orchestrator & Boshqaruv (`agy1` — 0-ORCHESTRATOR)
- [x] **TASK-001**: 8 ta mustaqil agent profillari va koordinatsiyani sozlash.
- [x] **TASK-002**: To'liq Bosh Arxitektura Spetsifikatsiyasini tasdiqlash (`ARCHITECTURE_BLUEPRINT.md` v4.0.0).
- [x] **TASK-003**: gRPC Protobuf shartnomasini kiritish (`proto/legal_ai.proto`).
- [~] **TASK-004**: Faza 1 va Faza 2 agentlararo bog'liqliklarini boshqarish va blokerlarni yo'q qilish.
- [ ] **TASK-005**: Yakuniy integratsion audit va MVP qabul qilish komissiyasi tekshiruvi.

---

## ⚙️ 1. Go Backend Modular Monolith (`agy2` — 1-BACKEND-GO)
- [x] **TASK-101**: Go Modular Monolith poydevori, PostgreSQL 16 migratsiyalari va MinIO integratsiyasi.
- [x] **TASK-102**: PII Redactor (O'RQ-547) va 10 ta deterministik Go qoidalari.
- [~] **TASK-103**: `proto/legal_ai.proto` bo'yicha gRPC Client integratsiyasi (Go → Python `ai-engine`).
- [~] **TASK-104**: Active Self-Correction Verifier Loop (modda mos kelmasa RAG qayta qidiruvi va AI qayta tahlil so'rovi).
- [x] **TASK-105**: Server-Sent Events (SSE) hujjat tahlili streaming endpointlari (`/api/v1/analyses/{id}/events`).
- [~] **TASK-106**: WebSockets server Live Voice Assistant interaktiv savol-javobi uchun (`/api/v1/ws/voice`).
- [x] **TASK-107**: DOCX va PDF hisobot eksporti (Izohli takliflar + "LOYIHA" to'liq tahrir).

---

## ⚖️ 5. Legal AI, Lex.uz RAG & Python Engine (`agy6` — 5-LEGAL-RAG-AI)
- [x] **TASK-501**: O'zbekiston Qonunchilik Korpusi (`seeds/seed.sql` — FK 364, 707, 326, O'RQ-547).
- [~] **TASK-502**: `ai-engine/` Python mikro-servisini qurish (FastAPI + gRPC Server `proto/legal_ai.proto` implementatsiyasi).
- [~] **TASK-503**: Lex.uz Ingestion & pgvector HNSW + BM25 gibrid qidiruv qatlami.
- [~] **TASK-504**: Legal SLM (Llama-3 / Qwen-2.5) uchun O'zbek yuridik dataset pipeline va lokal inferens adapteri.
- [~] **TASK-505**: Skaner qilingan PDF va rasmlar uchun OCR / Vision tahlil moduli.

---

## 🌐 3. Web Frontend & LegalTech Studio (`agy4` — 3-WEB-FRONT)
- [x] **TASK-301**: React 18+ TypeScript + Tailwind poydevori.
- [~] **TASK-302**: Yangi Welcome / Onboarding Landing sahifasi (Qiymat taklifi, B2B/B2C tanlovi, Free trial ro'yxatdan o'tish).
- [~] **TASK-303**: Robin AI / Harvey uslubidagi Contract Studio:
  - Chap panel: Document Paper (4-rangli inline xavf belgilari va sharhlar).
  - O'ng panel: Clause Inspector (Lex.uz iqtibos, 1 tugmali Accept/Reject Redline diff).
- [x] **TASK-304**: Glanceable Health Gauge (0-100 radial speedometer + DNA Barcode heatmap).
- [x] **TASK-305**: Three.js WebGL 3D Risk Visualizer sferasi.
- [~] **TASK-306**: WebSockets orqali jonli sinusoidal to'lqinli Live Voice Assistant.
- [x] **TASK-307**: 2 ta DOCX (izohli takliflar va LOYIHA tahrir) hamda PDF eksporti.

---

## 📱 2. Flutter Mobile Client (`agy3` — 2-MOBILE-FLUTTER)
- [x] **TASK-201**: Flutter 3.38+ Feature-First Clean Architecture poydevori.
- [~] **TASK-202**: Soliq-Style Dual Themes: Sapphire B2C Fuqaro va Emerald B2B Tadbirkor to'liq glassmorphism bilan.
- [~] **TASK-203**: Suzuvchi markaziy FAB skaner/yuklash tugmasi va rasm olish oqimi.
- [~] **TASK-204**: Shartnoma o'quvchi va pastdan ochiluvchi Draggable BottomSheet (yonma-yon redline diff).
- [x] **TASK-205**: Glanceable Risk Gauge va real-time audio waveform Voice Radar.
- [x] **TASK-206**: Biometriya, FLAG_SECURE (skrinshotdan himoya) va Privacy Blur Curtain.
- [~] **TASK-207**: Shifrlangan offline kesh (Drift + SQLCipher).

---

## 📊 4. Admin Platform Operator Portal (`agy5` — 4-ADMIN-PORTAL)
- [~] **TASK-401**: React + TypeScript Platform Operator Dashboard poydevori (`admin/`).
- [~] **TASK-402**: Tizim Salomatligi (System Health: Go, Python AI, Postgres, Redis, MinIO) jonli monitoringi.
- [~] **TASK-403**: AI Telemetriya: tahlillar soni, gRPC latency, tokenlar sarfi.
- [~] **TASK-404**: Lex.uz Qonunchilik Korpusi boshqaruvi va yangi moddalarni yuklash.
- [~] **TASK-405**: Human-in-the-Loop Review: AI ishonchsiz deb topgan (`REVIEW_REQUIRED`) bandlar nazorati.

---

## 🛡️ 6. QA & Security Lead (`agy7` — 6-QA-SECURITY)
- [x] **TASK-601**: Magic-byte MIME sniffing va fayl xavfsizligi auditi.
- [x] **TASK-602**: OWASP MASVS-L2 mobil xavfsizlik tekshiruvlari.
- [~] **TASK-603**: Active Self-Correction siklining aniqlik testi (100% to'g'ri moddalar).
- [~] **TASK-604**: Go va Python gRPC aloqasi stress va fuzzing testlari.

---

## 🚀 7. DevOps, SRE & CI/CD Lead (`agy8` — 7-DEVOPS-INFRA)
- [x] **TASK-701**: `deploy/docker-compose.yml` va tarmoq infratuzilmasi.
- [~] **TASK-702**: Docker Compose ga `ai-engine` (Python gRPC servisi) konteynerini qo'shish va GPU/CPU sozlamalari.
- [~] **TASK-703**: `./scripts/run_dev.sh` ni barcha yangi xizmatlar bilan sinxronlashtirish.
- [x] **TASK-704**: GitHub Actions 7-jobli CI pipeline.
