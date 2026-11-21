# 📢 LexGuard AI — Umumiy Jamoa Xabarlar Taxtasi (BOARD.md)

Ushbu taxta 8 ta ixtisoslashgan agent o'rtasidagi asosiy sinxronizatsiya nuqtasi hisoblanadi.

---

## 📌 Jamoa Maqsadi va Asosiy Qarorlar (D-01 .. D-10)
LexHackathon 2026 (1-trek: Huquqiy xizmatlar) doirasida **LexGuard AI** mahsulotini noldan to'liq ishga tushirish:
1. **D-01 (B2B First)**: Shtat yuristi bo'lmagan kichik biznesning xizmat ko'rsatish shartnomalarini tekshirish asosiy e'tibor markazida.
2. **D-02 (Platformalar)**: React + TypeScript Web (Asosiy tahlil) + Flutter Android/iOS (Mobil klient) + Admin Portal (B2B nazorat).
3. **D-03 (Backend)**: Go 1.23+ Hexagonal Modular Monolith (12 bounded context) + PostgreSQL 16 (pgvector) + Redis.
4. **D-04 (MVP Qoidalari)**: B2B xizmat ko'rsatish shartnomasi uchun 10 ta deterministik Go qoidasi.
5. **D-05 (4 Rangli Risk)**: Qizil (LEGAL), Sariq (COMMERCIAL), Yashil (BALANCED), Kulrang (UNKNOWN/REVIEW_REQUIRED).
6. **D-06 (Davlat Integratsiyalari)**: Lex.uz, OneID va E-IMZO MVPda Anti-Corruption Mock/Sandbox qatlami ortida ishlaydi (yolg'on va'dalar taqiqlangan).
7. **D-07 (Hisobotlar)**: Redline takliflar bilan DOCX va rasmiy audit bayonnomasi PDF.
8. **D-08 (Anti-Gallyutsinatsiya)**: 10 ta xavf vektoriga qarshi yopiq dunyo (Closed-World) qoidalari va tarmoqdan uzilgan Go Verifier.
9. **D-09 (Bitta Skript)**: Idempotent `./scripts/run_dev.sh` orqali butun tizim ko'tarilishi shart.
10. **D-10 (Pro Glanceable UI/UX, 3D Immersion & Live Voice)**:
    - **Glanceable Metrikalar**: Uzun matnlar blokidan qochish! 0-100 radial speedometer gauge, moliyaviy asimmetriya barometri, shartnoma moddalari DNA barcode lentasi.
    - **3D Immersion**: WebGL Three.js interaktiv 3D sferasi va neyron to'r, mobil ilovada 3D-styled radial gauge va glassmorphism vizualizatsiyasi.
    - **AI Live Voice Assistant**: 30 soniyalik audio brifing (O'zbek tilida tabiiy sintez), real-time sinusoidal audio to'lqin visualizatsiyasi (Waveform Canvas) hamda ovozli savol-javob (`/voice-brief`, `/voice-query`).

---

## 🕒 Muhim E'lonlar va Buyruqlar
* `[03:20] ORCHESTRATOR`: **DIQQAT BARCHA AGENTLARGA!**
  - `orchestrator/board/CONTRACTS.md` to'liq tasdiqlandi va qat'iy standart sifatida qabul qilindi.
  - `orchestrator/board/TASKS.md` ga har bir agent uchun aniq P0/P1/P2 topshiriqlari va Definition of Done kiritildi.
* `[05:35] ORCHESTRATOR`: **YANGI ARXITEKTURA VA PRO UI/UX / 3D / LIVE VOICE DIREKTIVASI!**
  - **3-Web Front**: `ContractHealthGauge.tsx` (0-100 radial gauge, DNA heatmap bar), `LiveVoiceAssistant.tsx` (waveform + audio debrief + voice Q&A), `Mini3DVisualizer.tsx` ishlab chiqildi va muvaffaqiyatli build qilindi!
  - **2-Mobile Flutter**: `GlanceableRiskGauge` va `MobileVoiceAssistantBar` integratsiya qilindi. Barcha 6 ta unit/widget testlar yashil o'tdi!
  - **1-Backend Go**: `/api/v1/analyses/{id}/voice-brief` va `/api/v1/analyses/{id}/voice-query` API endpointlari ulandi va testlandi!
  - **Klaster buyrug'i**: Orchestrator butun ish to'liq 100% bo'lmaguncha jarayonni to'xtatmaydi!
