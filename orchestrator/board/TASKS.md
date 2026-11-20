# 📋 Sprint Topshiriqlar Taxtasi (Tasks Backlog)

Holatlar: `[ ] TODO` | `[~] IN_PROGRESS` | `[?] REVIEW` | `[x] DONE`

---

### 👑 0. Orchestrator & Boshqaruv
- [x] Multi-agent tmux arxitekturasini tuzish va 8 profilni ajratish
- [ ] Barcha agentlar ishini muvofiqlashtirish va sprint rejasi tasdig'i

### ⚙️ 1. Go Backend (`backend/`)
- [ ] `go.mod` va modular monolit paket tuzilmasini yaratish (`cmd/api`, `internal/`)
- [ ] PostgreSQL + pgvector migratsiyalari va DB layer
- [ ] `/api/v1/auth`, `/api/v1/contracts`, `/api/v1/analysis` endpointlari
- [ ] 10-vektorli anti-gallyutsinatsiya filtri

### 📱 2. Flutter Mobile (`mobile/`)
- [ ] Flutter loyihasi va Clean Architecture tuzilmasini sozlash
- [ ] Material 3 LegalTech mavzusi (Light / Dark mode)
- [ ] Shartnoma skaner / yuklash ekrani (PDF / DOCX)
- [ ] Tahlil natijalarini ko'rsatish (Risk darajalari)

### 🌐 3. Web Frontend (`front/`)
- [ ] React + Vite + Tailwind CSS shablonini ko'tarish
- [ ] Shartnoma taqqoslash (Side-by-side diff viewer)
- [ ] Three.js 3D Risk visualizatsiyasi

### 📊 4. Admin Portal (`admin/`)
- [ ] Enterprise B2B boshqaruv paneli shabloni
- [ ] Shartnomalar monitoringi va bo'limlar statistikasi
- [ ] Obuna va limitlar ko'rinishi

### ⚖️ 5. Legal AI & RAG (`backend/internal/rag`)
- [ ] O‘RQ-547, O‘RQ-1115, O‘RQ-1125 normalari datasetini tayyorlash
- [ ] Temporal RAG qidiruv va kontekst qatlamini yaratish
- [ ] Aniq Lex.uz moddalarini iqtibos keltiruvchi prompt shablonlari

### 🛡️ 6. QA & Security (`tests/`)
- [ ] OWASP MASVS-L2 va Top 10 talablari tekshiruv ro'yxati
- [ ] MIME-type va fayl xavfsizligi unit testlari
- [ ] API integratsion testlari

### 🚀 7. DevOps & Infra (`deploy/`)
- [ ] `docker-compose.yml` (PostgreSQL, pgvector, Redis, MinIO)
- [ ] Yagona start skripti (`scripts/run_dev.sh`)
- [ ] GitHub Actions CI workflow
