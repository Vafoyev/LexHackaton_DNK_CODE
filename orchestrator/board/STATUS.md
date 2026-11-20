# 🟢 Real-Vaqt Agentlar Klasteri Holati (Swarm Status)
**Yangilangan vaqt**: 2026-11-21 03:20:00 (Toshkent vaqti)  
**Klaster Sessiyasi**: `lexguard-swarm`  
**Boshqaruvchi**: Bosh Tizim Arxitektori (Profile 1 - Orchestrator)

---

## 🛰️ 8 Profil bo'yicha Holat Matritsasi

| Profil | Agent Nomi | Oyna | Chat ID | Holati | Joriy Vazifasi & Diqqat Markazi |
| :--- | :--- | :---: | :--- | :---: | :--- |
| **agy1** | `👑 0-ORCHESTRATOR` | `0` | `11111111-1111-4111-8111-111111111111` | 🟢 Faol | Shartnomalar (`CONTRACTS.md`) va Vazifalar taxtasi (`TASKS.md`) tasdiqlandi. Agentlar sinxronizatsiyasi boshqarilmoqda. |
| **agy2** | `⚙️ 1-BACKEND-GO` | `1` | `22222222-2222-4222-8222-222222222222` | 🟢 Tayyor | Go Modular Monolith strukturasi, `internal/rules` (10 ta qoida) va PostgreSQL 16 sxemasini qurish. |
| **agy3** | `📱 2-MOBILE-FLUTTER` | `2` | `33333333-3333-4333-8333-333333333333` | 🟢 Tayyor | Flutter Clean Architecture, Material 3 4-rangli risk vizualizatsiyasi va `features/contract_scan` UI. |
| **agy4** | `🌐 3-WEB-FRONT` | `3` | `44444444-4444-4444-8444-444444444444` | 🟢 Tayyor | React + Vite loyihasi, Side-by-side legal diff viewer va drag-and-drop fayl yuklash maydoni. |
| **agy5** | `📊 4-ADMIN-PORTAL` | `4` | `55555555-5555-4555-8555-555555555555` | 🟢 Tayyor | B2B tahlillar monitoringi, tashkilotlar reestri va kvotalar balansi paneli. |
| **agy6** | `⚖️ 5-LEGAL-RAG-AI` | `5` | `66666666-6666-4666-8666-666666666666` | 🟢 Tayyor | O'RQ-547, O'RQ-1115, FK moddalari korpusi (`seeds/legal_corpus.json`) va PII anonimizatsiya qoidasi. |
| **agy7** | `🛡️ 6-QA-SECURITY` | `6` | `77777777-7777-4777-8777-777777777777` | 🟢 Tayyor | Fayl yuklashda MIME magic-byte sniffing filtri va OWASP MASVS-L2 mobil talablari tekshiruv moduli. |
| **agy8** | `🚀 7-DEVOPS-INFRA` | `7` | `88888888-8888-4888-8888-888888888888` | 🟢 Tayyor | `docker-compose.yml` (PG16+pgvector, Redis) va yagona `scripts/run_dev.sh` start skripti. |

---

## 🚦 Blokerlar va Sinxronizatsiya Xabarnomasi

- **Blokerlar**: `0 TA` (Barcha agentlar uchun API shartnomasi va Mock ma'lumotlar sxemasi `CONTRACTS.md` da to'liq tasdiqlangan).
- **Protokol**: Mobil, Veb va Admin jamoalari backendni kutmasdan, to'g'ridan-to'g'ri `CONTRACTS.md` dagi JSON kontraktlari asosida o'z interfeyslarini parallel qurmoqdalar.
