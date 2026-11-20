import { AnalysisResult } from '../types/contract';

export const SAMPLE_IT_SERVICE_CONTRACT: AnalysisResult = {
  id: "01934f2a-7b3c-7000-8000-000000000200",
  document: {
    id: "01934f2a-7b3c-7000-8000-000000000100",
    filename: "B2B_IT_Xizmat_Korsatish_Shartnomasi_2026.docx",
    sha256: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    contract_date: "2026-05-15",
    document_type: "B2B_SERVICE",
    file_size: 245760,
    parse_confidence: 0.98
  },
  summary: {
    total_clauses: 18,
    red_count: 2,
    yellow_count: 4,
    green_count: 11,
    gray_count: 1,
    balance_label: "Buyurtmachiga og'ir (Asimmetrik)",
    risk_score: 68,
    top_risks: [
      "Buyurtmachi shartnomani 0 kunlik ogohlantirishsiz va sarflangan xarajatlarni qoplamasdan bekor qilishi mumkin (FK 707-m)",
      "Ijrochi zimmasiga shartnoma qiymatidan oshuvchi cheksiz moddiy javobgarlik yuklangan (FK 324, 333-m)",
      "Kunlik 1% (yillik 365%) asossiz yuqori penya belgilangan (FK 326-m)",
      "Qabul qilish dalolatnomasi bo'yicha e'tiroz bildirish tartibi va muddati ko'rsatilmagan (FK 703-706-m)"
    ]
  },
  findings: [
    {
      id: "f-01",
      clause_id: "c-07",
      clause_number: "7.3",
      original_quote: "Buyurtmachi istalgan vaqtda Ijrochini oldindan ogohlantirmasdan va sarflangan xarajatlarni qoplamasdan shartnomani bir tomonlama bekor qilish huquqiga ega.",
      risk_level: "RED",
      category: "LEGAL",
      verification_status: "VERIFIED",
      rule_id: "SVC_UNILATERAL_TERMINATION",
      issue_title: "Asossiz bir tomonlama bekor qilish huquqi",
      issue_explanation: "O‘zbekiston Respublikasi Fuqarolik Kodeksining 707-moddasiga ko‘ra, xizmat ko‘rsatish shartnomasidan bir tomonlama voz kechilganda, Buyurtmachi Ijrochiga u qilgan haqiqiy xarajatlarni to‘lashi shart. Xarajatlarni qoplamaslik to'g'risidagi band imperativ qoidaga ziddir.",
      legal_basis: {
        source_title: "O‘zbekiston Respublikasi Fuqarolik Kodeksi",
        article: "707-modda (Haq evaziga xizmat ko‘rsatish shartnomasini bajarishdan bosh tortish)",
        lex_uz_url: "https://lex.uz/docs/111181#111905",
        norm_nature: "IMPERATIVE",
        effective_from: "1997-03-01"
      },
      suggested_redline: "Buyurtmachi shartnomani bekor qilishdan kamida 15 (o‘n besh) ish kuni oldin Ijrochini yozma xabardor qiladi hamda Ijrochi tomonidan amalda bajarilgan xizmatlar haqini va asoslangan haqiqiy xarajatlarini to‘liq qoplaydi.",
      redline_reasoning: "Ijrochining kutilmagan moliyaviy yo'qotishlarini oldini oladi va FK 707-moddasiga 100% muvofiqlashtiradi."
    },
    {
      id: "f-02",
      clause_id: "c-08",
      clause_number: "8.2",
      original_quote: "Ijrochi har qanday xato yoki uzilish uchun Buyurtmachiga yetkazilgan barcha to'g'ridan-to'g'ri va bilvosita zararlarni, shu jumladan boy berilgan foydani to'liq hajmda cheklovlarsiz qoplaydi.",
      risk_level: "YELLOW",
      category: "COMMERCIAL",
      verification_status: "VERIFIED",
      rule_id: "SVC_UNLIMITED_LIABILITY",
      issue_title: "Cheksiz moddiy javobgarlik (Boy berilgan foyda)",
      issue_explanation: "IT xizmatlari shartnomasida javobgarlik chegarasi (Cap of Liability) belgilanmagan. Bu ijrochi uchun korxonaning butun aktivlariga tahdid soluvchi og'ir moliyaviy asimmetriyani keltirib chiqaradi.",
      legal_basis: {
        source_title: "O‘zbekiston Respublikasi Fuqarolik Kodeksi",
        article: "324 va 333-moddalar (Zararni to'lash majburiyati va Javobgarlik asoslari)",
        lex_uz_url: "https://lex.uz/docs/111181#111516",
        norm_nature: "DISPOSITIVE",
        effective_from: "1997-03-01"
      },
      suggested_redline: "Ijrochining shartnoma bo‘yicha umumiy moddiy javobgarligi oxirgi 3 (uch) oy davomida amalda to‘langan xizmat haqi miqdori bilan cheklanadi. Bilvosita zararlar va boy berilgan foyda qoplanmaydi.",
      redline_reasoning: "Bozor amaliyotiga mos holda javobgarlikni shartnoma qiymatiga mutanosib ravishda cheklaydi."
    },
    {
      id: "f-03",
      clause_id: "c-09",
      clause_number: "9.1",
      original_quote: "Ijrochi xizmat ko'rsatish muddatini kechiktirgan har bir kun uchun shartnoma umumiy summasining 1% miqdorida penya to'laydi.",
      risk_level: "YELLOW",
      category: "COMMERCIAL",
      verification_status: "VERIFIED",
      rule_id: "SVC_PENALTY_FORM_RISK",
      issue_title: "Nomutanosib yuqori penya miqdori (kuniga 1%)",
      issue_explanation: "Bozor amaliyotida penya sutkasiga 0.1% - 0.2% dan oshmasligi tavsiya etiladi. Kuniga 1% (oyiga 30%) asossiz yuqori hisoblanib, FK 326-moddasi bo'yicha sud orqali kamaytirilishi mumkin.",
      legal_basis: {
        source_title: "O‘zbekiston Respublikasi Fuqarolik Kodeksi",
        article: "326-modda (Neustoykani kamaytirish)",
        lex_uz_url: "https://lex.uz/docs/111181#111520",
        norm_nature: "DISPOSITIVE",
        effective_from: "1997-03-01"
      },
      suggested_redline: "Ijrochi har bir kechiktirilgan ish kuni uchun kechiktirilgan xizmat summasining 0.1% miqdorida, lekin umumiy shartnoma summasining 10% idan oshmagan miqdorda penya to'laydi.",
      redline_reasoning: "Tijoriy xavfni cheklaydi, yuqori chegara (cap) o'rnatadi va adolatli balans ta'minlaydi."
    },
    {
      id: "f-04",
      clause_id: "c-04",
      clause_number: "4.4",
      original_quote: "Buyurtmachi xizmatlarni qabul qilish dalolatnomasini ko'rib chiqish muddati bilan cheklanmaydi va to'lov faqat uning xohishiga ko'ra imzolanadi.",
      risk_level: "RED",
      category: "LEGAL",
      verification_status: "VERIFIED",
      rule_id: "SVC_NO_ACCEPTANCE_ACT",
      issue_title: "Qabul qilish akti bo'yicha noaniqlik va to'lovni paysalga solish",
      issue_explanation: "Xizmat natijasini qabul qilish va asoslangan e'tiroz bildirishning aniq muddati bo'lmasligi ijrochining qonuniy to'lov olish huquqini buzadi (FK 703, 705-moddalar).",
      legal_basis: {
        source_title: "O‘zbekiston Respublikasi Fuqarolik Kodeksi",
        article: "703 va 705-moddalar (Haq evaziga xizmat ko'rsatish shartnomasi va haq to'lash)",
        lex_uz_url: "https://lex.uz/docs/111181#111899",
        norm_nature: "IMPERATIVE",
        effective_from: "1997-03-01"
      },
      suggested_redline: "Buyurtmachi dalolatnoma taqdim etilgan kundan boshlab 5 (besh) ish kuni ichida uni imzolaydi yoki asoslangan yozma e'tiroz bildiradi. Ushbu muddatda javob berilmasa, xizmatlar to'liq va sifatli qabul qilingan deb hisoblanadi.",
      redline_reasoning: "To'lovlarni sun'iy ushlab qolish xavfini bartaraf etadi va sukut bo'yicha qabul qilish mexanizmini kiritadi."
    },
    {
      id: "f-05",
      clause_id: "c-12",
      clause_number: "12.2",
      original_quote: "Shartnoma bo'yicha yuzaga keladigan barcha nizolar Buyurtmachi tanlagan sudda ko'rib chiqiladi, tomonlar muzokaralar o'tkazishi shart emas.",
      risk_level: "YELLOW",
      category: "COMMERCIAL",
      verification_status: "VERIFIED",
      rule_id: "SVC_DISPUTE_ONE_SIDED",
      issue_title: "Bir tomonlama noqulay sudlovlik (Sudlovlik asimmetriyasi)",
      issue_explanation: "Nizolarni hal qilishda majburiy talabnoma (pretenziya) tartibi bo'lmasligi to'g'ridan-to'g'ri sud xarajatlariga olib keladi.",
      legal_basis: {
        source_title: "O‘zbekiston Respublikasi Iqtisodiy protsessual kodeksi",
        article: "IPK 148-modda (Nizoni sudgacha hal qilish tartibi)",
        lex_uz_url: "https://lex.uz/docs/3517337",
        norm_nature: "DISPOSITIVE",
        effective_from: "2018-04-01"
      },
      suggested_redline: "Barcha kelishmovchiliklar avval 15 kunlik yozma talabnoma tartibida muzokara yo'li bilan hal qilinadi. Kelishuvga erishilmagan taqdirda, nizo javobgar joylashgan iqtisodiy sudda ko'rib chiqiladi.",
      redline_reasoning: "Sudgacha hal etish orqali tomonlarning vaqt va davlat boji xarajatlarini tejaydi."
    },
    {
      id: "f-06",
      clause_id: "c-14",
      clause_number: "14.1",
      original_quote: "Tomonlar har qanday fors-major holatlari yuz berganda majburiyatlardan to'liq ozod etiladilar.",
      risk_level: "GRAY",
      category: "UNKNOWN",
      verification_status: "REVIEW_REQUIRED",
      rule_id: "SVC_FORCE_MAJEURE_MISSING",
      issue_title: "Fors-major bandi haddan tashqari umumiy va xabarnoma mexanizmi yo'q",
      issue_explanation: "Qaysi organ ma'lumotnomasi talab qilinishi (masalan, Savdo-sanoat palatasi sertifikati) va necha kunda xabar berilishi ko'rsatilmagan. Mutaxassis (advokat) ko'rigi talab etiladi.",
      legal_basis: {
        source_title: "O‘zbekiston Respublikasi Fuqarolik Kodeksi",
        article: "333-modda 3-qism (Yengib bo'lmas kuch holatlari)",
        lex_uz_url: "https://lex.uz/docs/111181#111530",
        norm_nature: "DISPOSITIVE",
        effective_from: "1997-03-01"
      },
      suggested_redline: "Fors-major yuz berganda taraf 3 kun ichida yozma xabar berishi va 15 kun ichida Savdo-sanoat palatasining tasdiqlovchi sertifikatini taqdim etishi shart.",
      redline_reasoning: "Soxta fors-major bahonalaridan himoya qiladi."
    },
    {
      id: "f-07",
      clause_id: "c-15",
      clause_number: "15.3",
      original_quote: "Ijrochi Buyurtmachi tizimlaridagi foydalanuvchilar ma'lumotlarini o'z serverlarida saqlashi va o'rganishi mumkin.",
      risk_level: "YELLOW",
      category: "COMMERCIAL",
      verification_status: "VERIFIED",
      rule_id: "SVC_CONFIDENTIALITY_IP_GAP",
      issue_title: "Shaxsiy ma'lumotlar xavfsizligi va maxfiylik cheklovlari yetarli emas",
      issue_explanation: "O‘zbekiston Respublikasining 'Shaxsiy ma'lumotlar to'g'risida'gi O‘RQ-547-son Qonuniga muvofiq, ma'lumotlarni noqonuniy qayta ishlash yoki uzatish qat'iy javobgarlikka sabab bo'ladi.",
      legal_basis: {
        source_title: "O'zbekiston Respublikasi Qonuni",
        article: "O‘RQ-547-son Qonun (Shaxsiy ma'lumotlar to'g'risida)",
        lex_uz_url: "https://lex.uz/docs/4396428",
        norm_nature: "IMPERATIVE",
        effective_from: "2019-10-01"
      },
      suggested_redline: "Ijrochi taqdim etilgan shaxsiy ma'lumotlarni faqat ushbu shartnoma doirasida qayta ishlaydi, O'RQ-547 talablariga qat'iy rioya etadi va uchinchi shaxslarga uzatmaydi.",
      redline_reasoning: "Qonuniy talablarga muvofiqlashtiradi va jarima xavfidan saqlaydi."
    }
  ],
  clauses: [
    {
      id: "c-01",
      clause_number: "1.1",
      title: "Shartnoma Predmeti",
      original_text: "1.1. Ijrochi Buyurtmachining buyurtmasiga binoan axborot tizimlarini ishlab chiqish va texnik qo'llab-quvvatlash xizmatlarini ko'rsatish majburiyatini oladi.",
      risk_level: "GREEN"
    },
    {
      id: "c-02",
      clause_number: "2.1",
      title: "Xizmat Ko'rsatish Muddati",
      original_text: "2.1. Xizmatlar ushbu shartnoma imzolangan kundan boshlab 6 (olti) oy muddatda bosqichma-bosqich amalga oshiriladi.",
      risk_level: "GREEN"
    },
    {
      id: "c-03",
      clause_number: "3.1",
      title: "Xizmatlar Narxi va Hisob-kitob",
      original_text: "3.1. Shartnomaning umumiy qiymati tomonlar kelishuvi bilan tasdiqlangan ilovada belgilanadi va O'zbekiston so'mida to'lanadi.",
      risk_level: "GREEN"
    },
    {
      id: "c-04",
      clause_number: "4.4",
      title: "Dalolatnomani Ko'rib Chiqish",
      original_text: "4.4. Buyurtmachi xizmatlarni qabul qilish dalolatnomasi bo'yicha ko'rib chiqish muddati bilan cheklanmaydi va to'lov faqat uning xohishiga ko'ra imzolanadi.",
      risk_level: "RED"
    },
    {
      id: "c-05",
      clause_number: "5.1",
      title: "Ijrochining Asosiy Majburiyatlari",
      original_text: "5.1. Ijrochi xizmatlarni tegishli sifatda, texnik topshiriq talablariga muvofiq bajarish majburiyatini oladi.",
      risk_level: "GREEN"
    },
    {
      id: "c-06",
      clause_number: "6.1",
      title: "Buyurtmachining Majburiyatlari",
      original_text: "6.1. Buyurtmachi xizmat ko'rsatish uchun zarur bo'lgan ma'lumotlar va texnik muhitga kirish huquqini taqdim etadi.",
      risk_level: "GREEN"
    },
    {
      id: "c-07",
      clause_number: "7.3",
      title: "Bir Tomonlama Bekor Qilish",
      original_text: "7.3. Buyurtmachi istalgan vaqtda Ijrochini oldindan ogohlantirmasdan va sarflangan xarajatlarni qoplamasdan shartnomani bir tomonlama bekor qilish huquqiga ega.",
      risk_level: "RED"
    },
    {
      id: "c-08",
      clause_number: "8.2",
      title: "Zararni Qoplash va Cheklovlar",
      original_text: "8.2. Ijrochi har qanday xato yoki uzilish uchun Buyurtmachiga yetkazilgan barcha to'g'ridan-to'g'ri va bilvosita zararlarni, shu jumladan boy berilgan foydani to'liq hajmda cheklovlarsiz qoplaydi.",
      risk_level: "YELLOW"
    },
    {
      id: "c-09",
      clause_number: "9.1",
      title: "Penyalar va Jarimalar",
      original_text: "9.1. Ijrochi xizmat ko'rsatish muddatini kechiktirgan har bir kun uchun shartnoma umumiy summasining 1% miqdorida penya to'laydi.",
      risk_level: "YELLOW"
    },
    {
      id: "c-10",
      clause_number: "10.1",
      title: "Mualliflik va Intellektual Mulk",
      original_text: "10.1. Yaratilgan dasturiy ta'minotga bo'lgan mulkiy huquqlar to'lov to'liq amalga oshirilgandan so'ng Buyurtmachiga o'tadi.",
      risk_level: "GREEN"
    },
    {
      id: "c-11",
      clause_number: "11.1",
      title: "Maxfiylik Shartlari (NDA)",
      original_text: "11.1. Tomonlar shartnoma doirasida olingan barcha tijorat sirlarini uchinchi shaxslarga oshkor qilmaslik majburiyatini oladilar.",
      risk_level: "GREEN"
    },
    {
      id: "c-12",
      clause_number: "12.2",
      title: "Nizolarni Hal Qilish",
      original_text: "12.2. Shartnoma bo'yicha yuzaga keladigan barcha nizolar Buyurtmachi tanlagan sudda ko'rib chiqiladi, tomonlar muzokaralar o'tkazishi shart emas.",
      risk_level: "YELLOW"
    },
    {
      id: "c-13",
      clause_number: "13.1",
      title: "Shartnomaning Amal Qilish Muddati",
      original_text: "13.1. Shartnoma imzolangan paytdan kuchga kiradi va tomonlar o'z majburiyatlarini to'liq bajarguniga qadar amalda bo'ladi.",
      risk_level: "GREEN"
    },
    {
      id: "c-14",
      clause_number: "14.1",
      title: "Fors-Major Holatlari",
      original_text: "14.1. Tomonlar har qanday fors-major holatlari yuz berganda majburiyatlardan to'liq ozod etiladilar.",
      risk_level: "GRAY"
    },
    {
      id: "c-15",
      clause_number: "15.3",
      title: "Ma'lumotlar Xavfsizligi",
      original_text: "15.3. Ijrochi Buyurtmachi tizimlaridagi foydalanuvchilar ma'lumotlarini o'z serverlarida saqlashi va o'rganishi mumkin.",
      risk_level: "YELLOW"
    },
    {
      id: "c-16",
      clause_number: "16.1",
      title: "O'zgartirishlar Kiritish Tartibi",
      original_text: "16.1. Shartnomaga kiritiladigan barcha o'zgartirish va qo'shimchalar faqat yozma shaklda, vakolatli shaxslar tomonidan imzolanganda yuridik kuchga ega bo'ladi.",
      risk_level: "GREEN"
    },
    {
      id: "c-17",
      clause_number: "17.1",
      title: "Elektron Hujjat va ERI Kuchliligi",
      original_text: "17.1. Tomonlar elektron hujjat aylanishi tizimi orqali E-IMZO bilan imzolangan hujjatlarni asl nusxaga teng deb tan oladilar.",
      risk_level: "GREEN"
    },
    {
      id: "c-18",
      clause_number: "18.1",
      title: "Rekvizitlar va Yakuniy Qoidalar",
      original_text: "18.1. Shartnoma o'zbek tilida, ikki nusxada tuzilgan bo'lib, har ikki nusxa bir xil yuridik kuchga ega.",
      risk_level: "GREEN"
    }
  ],
  disclaimer: "DIQQAT: Ushbu tahlil avtomatlashtirilgan axborot-tahliliy vosita (AI) tomonidan O'zbekiston Respublikasi qonunchiligi asosida tayyorlangan bo'lib, rasmiy yuridik xulosa hisoblanmaydi. Murakkab va ziddiyatli holatlarda malakali advokat bilan maslahatlashish tavsiya etiladi (O‘RQ-1115)."
};

// Shuningdek boshqa shablonlar (Yetkazib berish va Tijoriy Ijara)
export const SAMPLE_COMMERCIAL_LEASE_CONTRACT: Partial<AnalysisResult> = {
  document: {
    id: "01934f2a-7b3c-7000-8000-000000000101",
    filename: "Tijoriy_Bino_Ijarasi_Shartnomasi.docx",
    sha256: "b6d2a71f893e...",
    contract_date: "2026-06-01",
    document_type: "COMMERCIAL_LEASE",
    file_size: 198000,
    parse_confidence: 0.99
  },
  summary: {
    total_clauses: 14,
    red_count: 1,
    yellow_count: 3,
    green_count: 9,
    gray_count: 1,
    balance_label: "Ijaraga beruvchiga og'ir",
    risk_score: 55,
    top_risks: [
      "Ijaraga beruvchi xabarsiz ijara haqini 30% oshirish huquqini saqlab qolgan",
      "Garov depozitini qaytarish tartibi va muddati ko'rsatilmagan"
    ]
  }
};
