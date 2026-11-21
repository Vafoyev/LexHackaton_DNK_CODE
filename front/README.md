# LexGuard AI — Web Client & Interactive 3D Contract Visualizer

**Loyiha**: LexGuard AI (LexHackathon 2026, 1-trek: Huquqiy xizmatlar)  
**Texnologiyalar**: React 18, TypeScript, Vite, Tailwind CSS, Three.js (WebGL), Lucide Icons, docx, jsPDF, Web Speech API.  
**Standart**: Jamoa kelishuvi 3.2 va `CONTRACTS.md` (4-rangli risk matritsasi: Qizil, Sariq, Yashil, Kulrang).

---

## 🌟 Asosiy Imkoniyatlar

### 1. Pro Glanceable UI/UX & Moliyaviy Xatar Simulyatori
- **Contract Health Gauge (0-100)**: Shartnomaning umumiy qonuniy salomatlik indeksini ko'rsatuvchi katta radial speedometer.
- **DNA Barcode Heatmap**: Shartnomaning barcha bandlari xronologik rangli lenta ko'rinishida (ustiga bosganda darhol tegishli bandga o'tish).
- **Interaktiv Moliyaviy Xatar Simulyatori**: Shartnoma summasi va kechikish kunlari slayderi orqali noqonuniy kunlik 1% penya va asossiz bir tomonlama bekor qilish oqibatida kutilayotgan moliyaviy yo'qotish hamda LexGuard redline taklifi bilan tejaladigan mablag'ni hisoblovchi barometr!

### 2. Deep 3D Immersion Risk Visualizer (Three.js WebGL)
- **Markaziy Yadro (Core Risk Orb)**: Shartnomaning umumiy xavf darajasiga qarab ranglanuvchi va nafas oluvchi sferik gologramma.
- **3 xil fazoviy joylashuv rejimi (Layout Modes)**:
  1. `SPHERICAL`: 360° sferik fazoviy joylashuv.
  2. `CLUSTERED`: Xavf darajalari bo'yicha fazoviy qatlamlar (Qizil yuqori kritik qatlamda, Sariq o'rtada, Yashil barqaror asosda).
  3. `HELIX`: Shartnomaning DNK spirali.
- **Dinamik Nur & Spline bog'lamalari**: Kursor harakatiga ergashuvchi dinamik `PointLight`, QuadraticBezier neon egri yo'laklari va 600 ta yulduz/zarralar maydoni.
- **Raycaster Tooltip & Fokus**: Tugun bosilganda to'g'ridan-to'g'ri Side-by-Side Diff Viewer-ga o'tish.
- **To'liq Ekran (Fullscreen)** imkoniyati.

### 3. AI Live Voice Debrief & Web Speech Audio Sintezi
- **30 Soniyalik Ovozli Yuridik Brifing**: O'zbek tilida shartnomaning eng xavfli bandlarini (FK 707, FK 326, cheksiz javobgarlik) va tavsiyalarni o'qib beruvchi audio pleyer.
- **Jonli Audio Waveform**: Sinusoidal to'lqin kanvasi orqali ovoz to'lqinlari jonli tebranadi.
- **Ovozli Q&A**: Web Speech API orqali mikrofon yordamida ovozli savol berish yoki 5 ta tayyor yuridik savol chipi orqali tezkor tahlil olish va tegishli bandga havola olish.
- Ovoz tezligini moslash (1.0x, 1.25x, 1.5x).

### 4. Yonma-yon Taqqoslash (Side-by-Side Legal Diff Viewer)
- Chapda: Asl matn va aniqlangan xavf.
- O'ngda: Redline tuzatish, Lex.uz rasmiy moddasiga giperhavola, me'yor tabiati (`IMPERATIVE`/`DISPOSITIVE`) va qabul qilish/nusxalash tugmalari.

### 5. Rasmiy Eksport
- **Word Redline (.docx)**: Kelishmovchiliklar bayonnomasi (protokol raznoglasiy) bilan shakllantirilgan Word hujjati.
- **Audit PDF (.pdf)**: Rahbariyat va yuristlar uchun rasmiy tahliliy xulosa.

---

## 🚀 Ishga Tushirish

```bash
cd /Users/baxrom/ish_full/LexHackaton_DNK_CODE/front

# Dasturchi rejimida ishga tushirish (Port: 3000)
npm run dev

# Ishlab chiqarish uchun build qilish
npm run build
```
