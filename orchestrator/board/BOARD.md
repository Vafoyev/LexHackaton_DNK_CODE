# 📢 LexGuard AI — Umumiy Jamoa Xabarlar Taxtasi (BOARD.md)

Ushbu taxta 8 ta ixtisoslashgan agent o'rtasidagi asosiy sinxronizatsiya nuqtasi hisoblanadi.

---

## 📌 Jamoa Maqsadi va Asosiy Qarorlar (Kelishilgan Standart)
LexHackathon 2026 (1-trek: Huquqiy xizmatlar) doirasida **LexGuard AI** mahsulotini noldan to'liq ishga tushirish:
1. **Auditoriya**: Shtat yuristi bo'lmagan kichik/o'rta bizneslar (startuplar, YaTT, MChJ) hamda oddiy fuqarolar (B2C).
2. **Onboarding**: Welcome Landing sahifasi → Login/Register (B2B/B2C profil) → Bepul sinov kvotasi (Free trial).
3. **Platformalar**: 
   - Web (React 18+ TypeScript): Robin AI / Harvey uslubidagi LegalTech Studio (Document Paper + Inline Highlights + Clause Inspector + Redline diff + 3D + Live Voice).
   - Mobile (Flutter 3.38+): Soliq ilovasi uslubidagi Premium Glassmorphism UI (Sapphire/Emerald) + FAB skaner + Draggable BottomSheet + Voice Radar + Biometriya.
   - Admin Portal: Platforma Operatori Nazorat Paneli (System Health, AI telemetriya, Lex.uz boshqaruvi, Human-in-the-loop).
4. **Backend & AI Engine**:
   - Go 1.23+ Modular Monolith (Gateway, Auth, Rules, SSE, WebSockets, MinIO).
   - Python 3.11+ AI Engine: gRPC Protobuf shartnomasi (`proto/legal_ai.proto`), Lex.uz korpusi (pgvector BM25+HNSW), lokal Legal SLM (Llama-3/Qwen-2.5) va OCR pipeline.
5. **Anti-Hallucination & Active Self-Correction**:
   - 0% soxta modda; agar AI keltirgan norma Lex.uz bazasida tasdiqlanmasa, Verifier RAG dan qayta qidirib, AI ga xatoni ko'rsatib qayta tahlil qildiradi (Self-Correction Loop).
6. **Real-Time Aloqa**:
   - SSE — Hujjat tahlili va bosqichlar oqimi uchun.
   - WebSockets — AI Live Voice Assistant interaktiv savol-javobi uchun.
7. **Natija va Eksport**:
   - 4 rangli xavf matritsasi (Qizil, Sariq, Yashil, Kulrang), balans yorlig'i, izohli DOCX + Protokol raznoglasiy, toza "LOYIHA" tahriri DOCX va PDF audit bayonnomasi.

---

## 🕒 Muhim E'lonlar va Buyruqlar
* `[11:38] ORCHESTRATOR & LOYIHA EGASI`: **YANGI BOSHQARUV ARXITEKTURA SPETSIFIKATSIYASI (BLUEPRINT 4.0) TO'LIQ TASDIQLANDI! 🚀**
  - Barcha talablar: Loyiha maqsadi, papkalar tuzilishi, gRPC protokoli, Lex.uz RAG & Legal SLM, Active Self-Correction, SSE va WebSockets real-time aloqa, Robin AI va Soliq UI/UX standartlari rasmiylashtirildi.
  - To'liq hujjat: `orchestrator/board/ARCHITECTURE_BLUEPRINT.md`.
  - Barcha 8 ta profil shu spetsifikatsiya asosida yangi fazalarga o'tadi!
* `[12:35] ORCHESTRATOR`: **LEX.UZ QONUNLAR KORPUSI TO'LIQ YUKLANDI VA AI TA'LIMI (FINE-TUNING) BOSHLANDI! ⚡**
  - **Yuklangan qonunlar**: 10 ta asosiy qonun va kodeks (Fuqarolik Kodeksi 1 & 2-qism, Yangi Mehnat Kodeksi, Shartnomaviy-huquqiy baza to'g'risida Qonun (670-I), Iste'molchilar huquqi, Shaxsiy ma'lumotlar, Mediatsiya, Elektron tijorat, Raqobat, Davlat xaridlari).
  - **Jami moddalar**: 2,058 ta modda to'liq ajratilib, `ai-engine/data/uzbek_legal_corpus_unified.json` ga saqlandi.
  - **Knowledge Graph**: 2,058 ta tugun va 2,086 ta o'zaro havolalar (cross-references) zanjiri ulandi.
  - **AI Ta'lim Korpusi**: 3,234 ta Alpaca instruction juftliklari, 2,062 ta ShareGPT dialoglari va 1,172 ta ko'p bosqichli test keyslari yaratildi.
  - **Gibrid Qidiruv**: 13,804 ta leksik terminli BM25 qidiruv tizimi (`vector_store.py`) ishga tushirildi.
  - **SLM Fine-Tuning**: `train_slm.py` orqali LoRA konfiguratsiyasi tayyorlandi va tekshirildi.
