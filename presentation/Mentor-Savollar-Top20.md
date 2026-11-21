# LexGuard AI — mentorlarning eng noqulay 20 ta savoli

Har javob — **30 soniyagacha**. Avval qisqa javob, keyin bitta dalil. Bilmagan narsani “o'lchamadik, rejamiz shu” deb ochiq ayting.

**Hech qachon aytmang:** “100%”, “xato qilmaydi”, “xavfsiz”, “OneID bilan ishlaydi”, “bu bitim haqiqiy emas”, o'lchanmagan raqam.

---

## Texnik mentor (7)

### 1. “Bu shunchaki ChatGPT'ga o'ralgan wrapper emasmi?”
**Javob:** Yo'q. Xavfni Go'dagi deterministik qoidalar topadi. LLM faqat bandni strukturaga ajratadi va oddiy tilda tushuntiradi. Verifier iqtibosni korpusdan tekshiradi.
**Dalil:** LLM o'chsa ham tizim `RULE_ONLY` rejimida ishlayveradi — backendda 10 ta qoida va unit testlar bor.

### 2. “AI uydirma modda keltirsa-chi? Gallyutsinatsiya bo'lsa?”
**Javob:** Har iqtibos verifier'dan o'tadi: modda korpusda bormi, tahrir sanasi shartnoma sanasiga mosmi. Tasdiqlanmasa — xulosa chiqmaydi, band kulrang “tekshirilmadi” bo'ladi.
**Aytmang:** “0% xato”. **Ayting:** “tasdiqlanmagan xulosani tasdiqlangan qilib ko'rsatmaymiz”.

### 3. “Aniqligingiz qancha? Precision/recall?”
**Javob:** Hozir 15 ta sintetik test keys bor — bu qoidalarning ishlashini tekshiradi, aniqlikni emas. Haqiqiy aniqlikni huquqiy pilotda 30–50 ta ekspert belgilagan shartnomada o'lchaymiz.
**Muhim:** raqam to'qimang. “15 tadan N tasida topdi” shaklida, faqat o'lchangan bo'lsa.

### 4. “lex.uz'ning ochiq API'si yo'q. Ma'lumotni qayerdan olasiz?”
**Javob:** Hozir lex.uz'dagi amaldagi tahrirdan qo'lda tayyorlangan, versiyalangan korpus — har moddada rasmiy havola va sana. Integratsiya adapteri tayyor, lekin operator ruxsatisiz ulanmaymiz. So'rovimiz aynan shu — lex.uz ma'lumotlariga rasmiy kirish.

### 5. “Shartnomadagi pasport, JSHSHIR tashqi AI serveriga ketadi-ku?”
**Javob:** Yo'q. Pasport, JSHSHIR, karta, hisob raqami, STIR AI'ga yuborishdan oldin lokal yashiriladi — mobil ilovada qurilmaning o'zida. Tashqi modelga faqat yashirilgan matn boradi (O'RQ-547/1125). P2 da — O'zbekistondagi mahalliy LLM server.

### 6. “Telefonda yomon olingan rasm bo'lsa?”
**Javob:** O'qish ishonchliligi past bo'lsa, ilova rasmni qayta olishni so'raydi, noaniq band alohida belgilanadi va u bo'yicha xulosa chiqarilmaydi.

### 7. “Qonun o'zgarsa-chi? Eski tahrir bilan tekshirib qo'ysangiz?”
**Javob:** Korpus versiyalangan: har moddada amal qilish boshlanish va tugash sanasi bor, tekshiruv shartnoma tuzilgan sanadagi tahrir bo'yicha (FK 4-modda). Bu filtrning to'liq testlari hozir yozilmoqda — buni ochiq aytamiz.

---

## Huquqiy (soha) mentor (7)

### 8. “Bu yuridik maslahat-ku. Sizda litsenziya yo'q.”
**Javob:** Biz axborot-tahliliy dasturmiz (VM 675) — maslahat bermaymiz, norma va oqibatni ko'rsatamiz. Har natijada “yuridik xulosa emas” ogohlantirishi bor, yakuniy qaror insonda (O'RQ-1115).

### 9. “Tavsiyangiz noto'g'ri chiqib, mijoz zarar ko'rsa — kim javob beradi?”
**Javob:** Qaror foydalanuvchida, biz tekshiruv qamrovini ochiq ko'rsatamiz: qaysi qoidalar tekshirildi, qaysi biri yo'q. Murakkab yoki tasdiqlanmagan band hamkor advokatga yo'naltiriladi. Tizim taxmin qilmaydi — manba bo'lmasa, xulosa yo'q.

### 10. “Jamoada huquqshunos yo'q. Qoidalarni kim yozdi?”
**Javob:** Qoidalar Fuqarolik kodeksi va lex.uz'dagi amaldagi tahrirdan olingan. Modda raqamlari va notarial jadvalni hamkor advokat yoki mentor tasdiqlaydi; tasdiqlanmagan qoida bo'yicha xulosa chiqmaydi. Pilotdagi birinchi ish — ekspert ko'rigi.

### 11. “‘Bitim haqiqiy emas’ deyish — sudning vakolati.”
**Javob:** To'g'ri, shuning uchun biz buni demaymiz. Biz normani keltiramiz: “Bu turdagi shartnoma notarial tasdiqlanishi SHART [modda]. Hujjatda tasdiq topilmadi. Qonunga ko'ra tasdiqlanmasa — haqiqiy emas [modda].” Bu hukm emas, norma iqtibosi.

### 12. “Siz kimning tarafidasiz — ijrochimi, buyurtmachimi?”
**Javob:** Hech kimning. Tekshiruv qonunga nisbatan. Har band yonida balans yorlig'i: “Muvozanatli” yoki “[taraf]ga og'ir”. Ikki taraf ham bir xil natijani ko'radi.

### 13. “Shartnoma rus tilida yoki xorijiy qonunga bo'ysunsa?”
**Javob:** Rus va ingliz tilini qo'llab-quvvatlaymiz, o'zbekchada uchala yozuvni (kirill, eski va yangi lotin) ham. Shartnoma xorijiy qonunga bo'ysunsa — xulosa chiqarmaymiz, chunki faqat O'zbekiston qonuni bo'yicha tekshiramiz.

### 14. “Advokatlar ishsiz qoladimi?”
**Javob:** Aksincha. Bugun huquqiy muammoda atigi 8.6% yuristga boradi. Biz xavfni ko'rsatamiz, murakkab holatni hamkor advokatga yo'naltiramiz — advokatga ko'proq va tayyorlangan mijoz keladi.

---

## Biznes mentor (6)

### 15. “ChatGPT oyiga $20. Nega biznes sizga 199 ming to'laydi?”
**Javob:** ChatGPT matnni izohlaydi, lekin O'zbekiston qonuniga ixtisoslashmagan va manbani kafolatlamaydi. Biz — modda, tahrir sanasi, lex.uz havolasi, tuzatilgan .docx va hamkorga tayyor xat. Taqqoslash ChatGPT bilan emas, yurist bilan: bitta shartnoma 300 ming – 1 mln, bizda oyiga 30 ta.

### 16. “TAM 1,78 trln — hamma to'laydi deb o'ylaysizmi?”
**Javob:** Yo'q, TAM — bu shift: 746 ming biznes × 199 ming × 12 oy. Biz SOMga tayanamiz: 3 yilda SAMning 1% — 3 700 biznes, yiliga ~8,8 mlrd so'm. Dehqon xo'jaliklarini ataylab chiqarib tashladik.

### 17. “Nechta mijoz bilan gaplashdingiz? Kim to'lashga tayyor?”
**Javob (halol):** [Haqiqiy raqamni yozing: N ta intervyu, kimlar bilan.] Reja: 10–15 intervyu, 5–10 pilot, “qancha to'lashga tayyorsiz” savoli. Narxlar hozir gipoteza.
**Aytmang:** o'tkazilmagan intervyuni “o'tkazdik” deb.

### 18. “Mijozni qanday topasiz? CAC qancha?”
**Javob:** Asosiy kanal — buxgalteriya autsorsing firmalari: bitta firma o'nlab kichik biznesga xizmat qiladi, shuning uchun bitta shartnoma bilan ko'p mijoz. Qo'shimcha: IT Park, tadbirkorlar uyushmalari, banklarning kichik biznes portallari. CAC hali o'lchanmagan — pilotda o'lchaymiz.

### 19. “Adliya o'zi LexAI qilyapti. Katta o'yinchi shuni qilsa-chi?”
**Javob:** LexAI — huquqiy chatbot, hujjat ekspertizasi rejada. Biz bitta tor vazifaga ixtisoslashganmiz: imzodan oldin B2B shartnomani bandma-band tekshirish. Raqobat emas, hamkorlik ko'ramiz — so'rovimiz Adliya tizimida pilot.

### 20. “Tahlil tannarxi 4 000 so'm qayerdan? LLM qimmatlasa?”
**Javob:** Bu gipoteza, 20 ta test hujjatda o'lchaymiz. Zararsizlik chegarasi: Business'da tahlil tannarxi 5 934 so'mdan oshmasin. Himoya: asosiy ishni arzon Go qoidalari qiladi, LLM ishlamasa `RULE_ONLY`, P2 da mahalliy LLM.

---

## Tezkor shpargalka — raqamlar (hamma bir xil aytadi)

| Nima | Raqam |
|---|---|
| Penya misoli | 2 hafta kechikish = summaning 14% |
| Yurist narxi | 300 ming – 1 mln so'm / shartnoma |
| Yuristga murojaat | 8.6% (UNDP, 2025) |
| Advokatlar | 5 665 → 1 advokat / 6 460 aholi |
| Suddan tashqari nizo | 8% (xorijda 40–80%) |
| TAM | 746 000 biznes → 148,5 mlrd/oy → 1,78 trln/yil |
| SAM | 372 700 MChJ → 74,2 mlrd/oy → 890 mlrd/yil |
| SOM (3 yil) | 3 700 biznes → 736 mln/oy → 8,8 mlrd/yil |
| Tariflar | Fuqaro: boshida 3 hujjat bepul (bir martalik), keyin 19 900 · Business 199 000 · Pro 399 000 · +9 900 |
| Test | 15 sintetik keys; aniqlik pilotda o'lchanadi |
