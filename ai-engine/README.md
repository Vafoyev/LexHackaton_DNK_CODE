# LexGuard AI Engine

Shartnomalarni O'zbekiston qonunchiligi (Lex.uz, 10 ta qonun / 2 058 modda) bo'yicha tahlil qiluvchi Python xizmati.
Go backend bilan HTTP (`/api/v1/*`) va gRPC (`proto/legal_ai.proto`) orqali gaplashadi.

## Arxitektura

```
shartnoma bandi ──► text_utils (lotin/kirill, apostrof, gaplarga ajratish)
                        │
                        ▼
                 rules.py (20 qoida, shartnoma turiga mos)  ──► topilma: RED/YELLOW + aynan iqtibos
                        │                                           │
                        ▼                                           ▼
        knowledge_graph.py (multi-hop zanjir, Lex.uz URL)      llm.py (ixtiyoriy sayqallash,
                        │                                       citation guard)
                        ▼
        vector_store.py (BM25) ──► faqat "bog'liq normalar" (taxminiy xavf EMAS)
```

| Modul | Vazifasi |
|---|---|
| `analyzer.py` | Yagona tahlil yadrosi: REST, gRPC va stdlib server bir xil mantiqdan foydalanadi |
| `rules.py` | Qoidalar katalogi. Har bir qoida korpusdagi **haqiqiy** moddaga bog'langan (testlar tekshiradi) |
| `knowledge_graph.py` | 2 058 modda, 2 086 bog'lanish, BFS zanjir (`resolve_chain`), aniq modda qidiruvi (`find_node_id`) |
| `vector_store.py` | BM25 inverted index (stemming + apostrof/kirill normalizatsiyasi) |
| `llm.py` | Ixtiyoriy LLM (OpenAI-compatible). Hallyutsinatsiyaga qarshi **citation guard** |
| `balance.py` | Hujjat darajasidagi tomonlar balansi (daftar + ballar), `parties.py` — tomonlarni aniqlash |
| `chat.py` | Suhbat mantiqi: savol turiga qarab modda / mavzu kartasi / band tahlili / BM25 qidiruv (mavzudan tashqari savolga "topa olmadim" deydi) |
| `voice.py` | Ovozli brifing (SSML) va savol-javob matni |
| `ocr.py` | PDF/DOCX/rasm → matn → bandlarga ajratish |
| `service.py` | Transport qatlamlari uchun umumiy funksiyalar (javob shakllari bir xil) |
| `main.py` / `grpc_server.py` / `server.py` | FastAPI / gRPC / zero-dependency stdlib server |

## Tahlil qanday ishlaydi

1. **Gaplarga ajratish** — iqtibos (`problematic_quote`) har doim asl matnning **aynan substringi**
   (backend `verification` 3-vektori — substring grounding — shuni talab qiladi). Kirill matnda ham asl kirill iqtibos qaytadi.
2. **Qoidalar** shartnoma turiga qarab qo'llanadi: `SERVICE`, `SALE`, `LEASE`, `EMPLOYMENT`, `CONTRACT_WORK`, `GENERAL`
   (backend qiymatlari `B2B_SERVICE`, `SERVICE_AGREEMENT`, `SUPPLY_SALE`, `COMMERCIAL_LEASE` ... avtomatik moslanadi).
   Masalan, FK 707 faqat xizmat shartnomasi uchun; boshqa turlarda umumiy FK 237 qo'llanadi.
3. **Dispozitiv norma hech qachon RED emas** (backend 4-vektori bilan mos).
4. **Tomonlar muvozanati** (`balance_label`) bandning o'zidan aniqlanadi; `party_role` (`EXECUTOR`/`CUSTOMER`) berilsa,
   foydalanuvchi tomoniga zarar bo'lsa "(sizning tomoningizga)" qo'shiladi.
5. **BM25 xavf deb e'lon qilinmaydi.** Qoidaga tushmagan band `NO_RULE_MATCH` statusi va `related_norms` bilan qaytadi
   (aks holda har qanday band "nomuvofiqlik ehtimoli" deb belgilanardi).

## Endpointlar

| Endpoint | Tavsif |
|---|---|
| `GET /health`, `GET /api/v1/corpus-stats` | Holat va statistika (graf va fayllardan hisoblanadi) |
| `POST /api/v1/analyze-clauses` | Bandlar tahlili (`document_type`, `party_role`, `use_local_slm_only`) |
| `POST /api/v1/analyze-document` | Fayl → OCR → bandlarga ajratish → tahlil (bitta so'rovda) |
| `POST /api/v1/self-correct` | Rad etilgan modda o'rniga to'g'ri normani topish |
| `GET /api/v1/rules` | Faol qoidalar katalogi |
| `GET /api/v1/search-laws?q=` | BM25 qidiruv |
| `GET /api/v1/multi-hop-chain/{kod}` | Norma zanjiri (`FK 707`, `707-modda`, `FK-UZ-2_707`) |
| `POST /api/v1/balance` | Tomonlar balansi: hukm, yuk ulushi, tengsiz mavzular va ikki tomonga teng tahrirlar |
| `POST /api/v1/chat` | Suhbat: modda, mavzu, band tahlili yoki qidiruv (`intent`, `answer`, `speech`, `sources`, `findings`) |
| `POST /api/v1/voice-brief`, `POST /api/v1/voice-query` | Ovozli xulosa (SSML) va savol-javob |
| `POST /api/v1/ocr` | OCR + segmentatsiya |

gRPC: `ProcessDocumentOCR`, `AnalyzeClauses` (har bir band uchun progress eventi, mijoz uzilsa to'xtaydi),
`SelfCorrectFinding`, `GenerateVoiceBrief`, `StreamVoiceQuery`.

## Suhbat (chat)

`POST /api/v1/chat {"message": "..."}` — frontend `AI` bo'limi Go backend (`POST /api/v1/ai/chat`, JWT talab qiladi) orqali shu endpointga murojaat qiladi.
Javob manbai savol turiga qarab tanlanadi: `help` | `article` (modda raqami) | `topic` (qoidalar katalogidagi tayyor tushuntirish) |
`analysis` (foydalanuvchi shartnoma bandini yozdi) | `search` (BM25) | `no_match`. Hammasi korpusga asoslangan; LLM ishlatilmaydi.
`speech` maydoni brauzerda ovoz chiqarib o'qish uchun (URL va emojisiz, qisqa).

## Tomonlar balansi

`POST /api/v1/balance {"clauses": [{"clause_number","text"}], "document_type", "party_role"}` (frontend `Studio -> Balans`, Go: `POST /api/v1/ai/balance`).

1. **Daftar:** har bir gap bo'yicha 6 mavzu (bekor qilish huquqi, penya, javobgarlik, javobgarlikdan ozod qilish, narx/shartni o'zgartirish,
   maxfiylik) uchun HUQUQ yoki MAJBURIYAT kimda ekani yoziladi. Tomon — gap egasi (birinchi tilga olingan), `taraflardan har biri` kabi
   iboralar simmetrik, `taqiqlanadi` kabi inkorlar huquq emas.
2. **Mavzu holati:** ikkala tomonda bor — `BALANCED`; faqat bir tomonda — `ONE_SIDED`; penya stavkalari 2 baravar farq qilsa — `UNEQUAL`.
3. **Ballar:** qoidalar topilmasi yuk ko'taruvchi tomonga (qizil 3, sariq 1), daftar tengsizligi +2 (bir band ikki marta sanalmaydi — katta hissa olinadi).
4. **Hukm:** `BALANCED` | `BALANCED_HEAVY` (ikki tomonga ham og'ir: har ikkala tomon >= 5 ball) | `ONE_SIDED_PROVIDER|RECIPIENT`.
   Umumiy ball 2 dan kam bo'lsa (bitta kichik xavf) shartnoma "bir tomonlama" deb belgilanmaydi.
5. **Teng tahrir:** har bir tengsiz mavzu uchun ikki tomonga teng matn (`recommendations`).

Ball og'irliklari va chegaralar (`balance.py` boshidagi konstantalar) tajriba bilan emas, mantiqiy tanlangan; real shartnomalarda
yurist bilan kalibrovka qilinishi kerak. Balans qonuniy talab emas (FK 354), shuning uchun `limitations` doim qaytariladi.

## Yangi qoida qo'shish

`app/rules.py` dagi `RULES` ga `Rule(...)` qo'shing:

- `groups` — har bir guruhdan kamida bitta regex mos kelishi kerak. Regex **normallashtirilgan** matnga yoziladi
  (kichik harf, apostrofsiz, lotin): `o'zgartir` → `ozgartir`, `to'lov` → `tolov`.
- `root` / `related` — faqat korpusda mavjud ID lar (`FK-UZ-2_707`). `tests/test_analyzer.py` mavjudligini tekshiradi.
- `norm_nature="DISPOSITIVE"` bo'lsa `risk="YELLOW"` bo'lishi shart (test majbur qiladi).
- `predicate` — raqamli tekshiruv uchun (masalan, kunlik penya > 0,5%).
- Rasmiy matnni `data/uzbek_legal_corpus_unified.json` dan o'qib, `why` va `redline` ni shu matnga asoslang.

## Ixtiyoriy LLM

Standart holatda o'chirilgan (`LLM_PROVIDER=none`), tahlil to'liq deterministik. Yoqish:

```bash
LLM_PROVIDER=openai_compat
LLM_BASE_URL=http://localhost:11434/v1   # Ollama / vLLM / llama.cpp / OpenAI
LLM_MODEL=lexguard-slm
LLM_API_KEY=                              # kerak bo'lsa
```

- `refine`: qoida topgan xavf uchun tushuntirish va redline ni sayqallaydi.
- `triage`: qoidaga tushmagan, lekin BM25 nomzod moddalari bor bandda xavfni baholaydi (natija **YELLOW** bilan cheklanadi).
- **Citation guard**: model ruxsat etilgan moddalar (zanjir + nomzodlar) tashqarisida modda keltirsa, javob tashlanadi
  va qoidaviy natija saqlanadi. LLM xatosi/timeout tahlilni to'xtatmaydi.
- `use_local_slm_only=true` (gRPC/REST) bo'lsa, `LLM_BASE_URL` lokal bo'lmagan (`localhost`/`127.0.0.1`) holatda LLM chaqirilmaydi.

> `models/lexguard-slm-lora/` da faqat `adapter_config.json` bor, **adapter og'irliklari repoda yo'q**.
> Fine-tuned modelni ishlatish uchun `app/train_slm.py` bilan o'qitib, vLLM/Ollama orqali serve qiling va yuqoridagi env ga ulang.

## Sozlamalar

| Env | Default | Izoh |
|---|---|---|
| `LEXGUARD_DATA_DIR` / `LEXGUARD_CORPUS_PATH` | `ai-engine/data` | Korpus joylashuvi |
| `HTTP_PORT` / `GRPC_PORT` | `8000` / `50051` | |
| `CORS_ORIGINS` | bo'sh | Vergul bilan. Bo'sh: dev'da `*` (credentials'siz), `APP_ENV=production` da yopiq |
| `RELATED_NORM_MIN_SCORE` | `18.0` | `related_norms` uchun BM25 chegarasi |
| `LLM_*` | yuqoriga qarang | |

## Testlar

```bash
cd ai-engine
python -m unittest discover -s tests -v   # qoidalar, OCR, gRPC, REST, LLM guard, chat, balans (158 test)
python -m unittest test_ai_engine -v      # umumiy integratsiya (5 test)
```

## Cheklovlar

- Qoidalar **band darajasida** ishlaydi. Hujjatda biror band *yo'qligi* (masalan, fors-major yo'q) tekshiruvi Go `rules` modulida.
- Qoidalar katalogi chekli (20 ta). Qoidaga tushmagan xavflar `NO_RULE_MATCH` bo'ladi, bu "xavf yo'q" degani emas.
- Matn o'zbek tilida (lotin/kirill) tahlil qilinadi; rus tilidagi shartnomalar qoidalarga tushmaydi.
- Temporal qo'llanish (shartnoma sanasiga ko'ra amaldagi norma) backend `verification` da tekshiriladi.
- OCR rasm/skaner uchun Tesseract binary va `uzb`, `rus`, `eng` til paketlarini talab qiladi (Docker image'da o'rnatiladi,
  lokal mashinada alohida o'rnatish kerak).
- Natija axborot-tahliliy xarakterda (O'RQ-1115, 6-modda); yakuniy qaror yurist zimmasida.
