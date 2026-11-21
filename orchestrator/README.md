# 🛰️ LexGuard AI — Multi-Agent Swarm Orchestrator (8 Profiles)

Ushbu tizim **LexHackathon 2026** (1-trek: *Huquqiy xizmatlarni ko‘rsatish*) doirasida **LexGuard AI** loyihasini 8 ta ixtisoslashgan Antigravity (agy) agent profillari orqali parallel ravishda avtonom boshqarish va ishlab chiqish uchun yaratilgan.

---

## 🏗️ 8 Ta Agent Arxitekturasi va Taqsimoti

| Oyna | Profil | Agent Nomi | Roli | Qat'iy Chat ID | Asosiy Skills |
| :---: | :---: | :--- | :--- | :--- | :--- |
| **0** | `agy1` | `👑 0-ORCHESTRATOR` | **Boshqaruvchi & Tizim Arxitektori** | `11111111-1111-4111-8111-111111111111` | `spec-driven-dev`, `planning`, `doubt-driven-dev`, `doc-coauthoring`, `agy-council` |
| **1** | `agy2` | `⚙️ 1-BACKEND-GO` | **Senior Go & RAG Muhandisi** | `22222222-2222-4222-8222-222222222222` | `source-driven-dev`, `api-design`, `tdd`, `security`, `debugging` |
| **2** | `agy3` | `📱 2-MOBILE-FLUTTER` | **Senior Flutter Lead** | `33333333-3333-4333-8333-333333333333` | `flutter-dart-ui-expert`, `frontend-ui-engineering`, `api-design` |
| **3** | `agy4` | `🌐 3-WEB-FRONT` | **Senior Frontend & WebGL Lead** | `44444444-4444-4444-8444-444444444444` | `frontend-ui-engineering`, `frontend-design`, `web-artifacts-builder` |
| **4** | `agy5` | `📊 4-ADMIN-PORTAL` | **Enterprise Admin & Analytics Lead** | `55555555-5555-4555-8555-555555555555` | `building-data-apps`, `frontend-ui-engineering`, `api-design` |
| **5** | `agy6` | `⚖️ 5-LEGAL-RAG-AI` | **LegalTech AI & Prompt Engineer** | `66666666-6666-4666-8666-666666666666` | `claude-api`, `context-engineering`, `ml-best-practices`, `docx`, `pdf` |
| **6** | `agy7` | `🛡️ 6-QA-SECURITY` | **Security Audit & QA Lead** | `77777777-7777-4777-8777-777777777777` | `security-and-hardening`, `tdd`, `debugging`, `webapp-testing` |
| **7** | `agy8` | `🚀 7-DEVOPS-INFRA` | **DevOps & CI/CD Lead** | `88888888-8888-4888-8888-888888888888` | `ci-cd-and-automation`, `observability`, `shipping-and-launch` |

---

## 🔒 Chatlar Aralashib Ketishining Oldini Olish (Chat Isolation)

Har bir profil quyidagi mexanizmlar orqali 100% to'liq izolyatsiya qilingan:
1. **Shaxsiy Ma'lumotlar Bazasi va Katalog**: Har bir profil (`~/.agy-profiles/1..8`) o'zining mustaqil `conversations/` katalogiga va shaxsiy `conversation_summaries.db` bazasiga ega. Birlashgan symlinklar uzilgan, bu SQLite `database is locked` va chatlar aralashib ketishi xavfini butunlay yo'q qiladi.
2. **Qat'iy Chat ID (UUID v4)**: Har bir agent ishga tushishida unga biriktirilgan o'zgarmas UUID (`11111111-...` dan `88888888-...` gacha) uzatiladi.
3. **Mustaqil Ishchi Kataloglar**: Har bir agent o'zining tegishli papkasida (`backend/`, `mobile/`, `front/`, `admin/`) ishlaydi.

---

## 🛠️ Boshqaruv Buyruqlari (CLI Scripts)

### 1. Swarm Klasterini Ishga Tushirish
```bash
./orchestrator/bin/orchestrator-start
```
*Barcha 8 ta profil uchun tmux oynalarini ochadi, chat ID larni bog'laydi va agentlarni ishga tushiradi.*

### 2. Holatni Kuzatish (Dashboard)
```bash
./orchestrator/bin/orchestrator-status
```
*8 ta profilning Google akkaunti, kvotasi, modeli, chat ID'si va tmux faolligini ko'rsatadi.*

### 3. Tmux Sessiyasiga Ulanish
```bash
# Boshqaruvchi (Orchestrator) oynasiga ulanish:
./orchestrator/bin/orchestrator-attach 0

# Ma'lum modul oynasiga ulanish:
./orchestrator/bin/orchestrator-attach backend
./orchestrator/bin/orchestrator-attach flutter
./orchestrator/bin/orchestrator-attach web
./orchestrator/bin/orchestrator-attach admin
```

### 4. Agentga Buyruq / Vazifa Yuborish
```bash
./orchestrator/bin/orchestrator-send backend "REST API DTO strukturasini tuzib chiq"
./orchestrator/bin/orchestrator-send flutter "Material 3 mavzusi ranglarini jamoa kelishuviga mosla"
```

### 5. Svarmini To'xtatish
```bash
./orchestrator/bin/orchestrator-stop
```

---

## 📋 Jamoa Muloqot Taxtalari (`orchestrator/board/`)
- `BOARD.md` — Umumiy muhim xabarlar va qarorlar
- `TASKS.md` — Sprint vazifalari va Definition of Done nazorati
- `CONTRACTS.md` — Backend va Frontend o'rtasidagi API shartnomalari
- `STATUS.md` — Real vaqtdagi holat hisoboti
