/** Namunaviy shartnomalar: haqiqiy tahlil quvuriga matn sifatida yuboriladi (uchala namuna turlicha). */
export interface SampleContract {
  id: 'it' | 'ijara' | 'olish';
  filename: string;
  documentType: string;
  text: string;
}

export const SAMPLE_CONTRACTS: Record<SampleContract['id'], SampleContract> = {
  it: {
    id: 'it',
    filename: 'IT_autsorsing_shartnomasi.txt',
    documentType: 'B2B_SERVICE',
    text: `IT AUTSORSING XIZMATLARI SHARTNOMASI

1. Shartnoma predmeti
1.1. Ijrochi Buyurtmachi topshirig'iga binoan dasturiy ta'minot ishlab chiqish xizmatlarini ko'rsatadi, Buyurtmachi esa xizmatlar uchun haq to'laydi.

2. To'lov tartibi
2.1. Xizmatlar narxi 120 000 000 so'm. To'lov xizmat qabul qilingandan keyin 90 kun ichida amalga oshiriladi.
2.2. Buyurtmachi to'lovni kechiktirgan taqdirda Ijrochiga hech qanday penya to'lanmaydi.

3. Javobgarlik
3.1. Ijrochi muddatni buzgan taqdirda kechiktirilgan har bir kun uchun shartnoma summasining 1 foizi miqdorida penya to'laydi.
3.2. Ijrochining javobgarligi cheklanmagan bo'lib, Buyurtmachining barcha bilvosita zararlari va boy berilgan foydasini qoplashni o'z ichiga oladi.

4. Bekor qilish
4.1. Buyurtmachi istalgan vaqtda Ijrochini oldindan ogohlantirmasdan va sarflangan xarajatlarni qoplamasdan shartnomani bir tomonlama bekor qilish huquqiga ega.

5. O'zgartirishlar
5.1. Buyurtmachi shartnoma narxi va shartlarini bir tomonlama o'zgartirishi mumkin, Ijrochi bunga rozilik bergan hisoblanadi.

6. Maxfiylik
6.1. Ijrochi shartnoma shartlarini va Buyurtmachi ma'lumotlarini muddatsiz maxfiy saqlashga majbur.
`,
  },
  ijara: {
    id: 'ijara',
    filename: 'Uy_ijarasi_shartnomasi.txt',
    documentType: 'B2C_LEASE',
    text: `UY-JOY IJARASI SHARTNOMASI

1. Shartnoma predmeti
1.1. Ijaraga beruvchi o'ziga tegishli xonadonni Ijarachiga vaqtincha foydalanish uchun beradi, Ijarachi ijara haqini to'laydi.

2. Ijara haqi
2.1. Oylik ijara haqi 4 000 000 so'm bo'lib, har oyning 5-kunigacha to'lanadi.
2.2. Ijaraga beruvchi ijara haqini istalgan vaqtda Ijarachini ogohlantirmasdan oshirishi mumkin.

3. Jarimalar
3.1. Ijarachi to'lovni kechiktirgan taqdirda kechiktirilgan har bir kun uchun to'lanmagan summaning 1 foizi miqdorida penya to'laydi.
3.2. Ijaraga beruvchi shartnomani buzgan taqdirda hech qanday javobgarlikka tortilmaydi.

4. Bekor qilish
4.1. Ijaraga beruvchi shartnomani istalgan vaqtda ogohlantirmasdan bir tomonlama bekor qilishi va Ijarachini xonadondan chiqarishi mumkin.
4.2. Ijarachi shartnomani bekor qilmoqchi bo'lsa, 3 oylik ijara haqini jarima sifatida to'laydi.

5. Depozit
5.1. Ijarachi 8 000 000 so'm depozit to'laydi, depozit shartnoma tugagach qaytarilmaydi.
`,
  },
  olish: {
    id: 'olish',
    filename: 'Oldi_sotdi_shartnomasi.txt',
    documentType: 'B2C_SALE',
    text: `AVTOMOBIL OLDI-SOTDI SHARTNOMASI

1. Shartnoma predmeti
1.1. Sotuvchi avtomobilni Xaridorga sotadi, Xaridor uni qabul qilib, narxini to'laydi.

2. Narx va to'lov
2.1. Avtomobil narxi 250 000 000 so'm. Xaridor narxning 100 foizini oldindan to'laydi.
2.2. Sotuvchi narxni istalgan vaqtda bir tomonlama o'zgartirishi mumkin.

3. Sifat va kafolat
3.1. Sotuvchi avtomobilning yashirin nuqsonlari uchun javobgar emas, Xaridor barcha nuqsonlar xavfini o'z zimmasiga oladi.

4. Javobgarlik
4.1. Sotuvchi avtomobilni topshirishni kechiktirsa, hech qanday penya to'lamaydi.
4.2. Xaridor to'lovni kechiktirsa, har bir kun uchun to'lanmagan summaning 1 foizi miqdorida penya to'laydi.

5. Bekor qilish
5.1. Sotuvchi shartnomani istalgan vaqtda bekor qilishi mumkin, Xaridorning to'lagan mablag'i qaytarilmaydi.
`,
  },
};
