"""
LexGuard AI — Shartnoma xavflari qoidalari katalogi.

Har bir qoida:
  - triggers: normallashtirilgan (kichik harf, apostrofsiz, lotin) matnga qo'llanadigan regex guruhlari.
    Qoida ishga tushishi uchun HAR BIR guruhdan kamida bitta pattern mos kelishi kerak.
  - root / related: Knowledge Graph tugun ID lari (korpusdagi HAQIQIY moddalar; testlar tekshiradi).
  - applies_to: shartnoma turlari (bo'sh = barchasi).
  - norm_nature: IMPERATIVE yoki DISPOSITIVE. Dispozitiv norma hech qachon RED bo'lmaydi
    (backend `verification` 4-vektori bilan mos).
"""

import re
from dataclasses import dataclass, field
from typing import Callable, Dict, FrozenSet, Optional, Pattern, Tuple

# Kanonik shartnoma turlari
SERVICE = "SERVICE"
SALE = "SALE"
LEASE = "LEASE"
EMPLOYMENT = "EMPLOYMENT"
CONTRACT_WORK = "CONTRACT_WORK"
GENERAL = "GENERAL"

_DOC_TYPE_MAP = {
    "SERVICE": SERVICE, "B2B_SERVICE": SERVICE, "SERVICE_AGREEMENT": SERVICE, "B2C_SERVICE": SERVICE,
    "SALE": SALE, "SUPPLY_SALE": SALE, "SUPPLY": SALE, "PURCHASE": SALE, "B2C_SALE": SALE,
    "LEASE": LEASE, "COMMERCIAL_LEASE": LEASE, "RENT": LEASE,
    "EMPLOYMENT": EMPLOYMENT, "LABOR": EMPLOYMENT, "LABOUR": EMPLOYMENT,
    "CONTRACT_WORK": CONTRACT_WORK, "WORK_CONTRACT": CONTRACT_WORK, "PUDRAT": CONTRACT_WORK,
}


ANY = "ANY"  # shartnoma turi noma'lum: barcha qoidalar qo'llanadi (self-correct va eski API uchun)


def canonical_doc_type(doc_type: str) -> str:
    key = (doc_type or "").strip().upper()
    return ANY if key == ANY else _DOC_TYPE_MAP.get(key, GENERAL)


def _p(*patterns: str) -> Tuple[Pattern, ...]:
    return tuple(re.compile(p) for p in patterns)


@dataclass(frozen=True)
class Rule:
    code: str
    title: str
    risk: str                      # RED | YELLOW
    category: str                  # LEGAL | COMMERCIAL | FORM | LABOR | PRIVACY
    norm_nature: str               # IMPERATIVE | DISPOSITIVE
    root: str                      # Knowledge Graph node id
    why: str                       # nega xavfli (qonunga havola bilan)
    redline: str                   # tavsiya etilgan tahrir
    groups: Tuple[Tuple[Pattern, ...], ...]
    related: Tuple[str, ...] = ()
    applies_to: FrozenSet[str] = frozenset()
    mitigations: Tuple[Pattern, ...] = ()
    mitigation_overrides: Tuple[Pattern, ...] = ()
    kind: str = "right"            # right: birinchi tilga olingan taraf foyda ko'radi; obligation: yuk ko'taradi; neutral
    predicate: Optional[Callable[[str, str], Optional[Dict]]] = None
    redline_by_doc: Dict[str, str] = field(default_factory=dict)
    root_by_doc: Dict[str, str] = field(default_factory=dict)
    # Shu qoida topilganda takrorlovchi umumiy variantlar (kodlari) chiqarilmaydi (shartnoma turi noma'lum bo'lganda)
    supersedes: Tuple[str, ...] = ()

    def applies(self, doc_type: str) -> bool:
        return not self.applies_to or doc_type == ANY or doc_type in self.applies_to


# --------------------------------------------------------------------------------------
# Predikatlar (raqamli tekshiruvlar)
# --------------------------------------------------------------------------------------
_PCT_RE = re.compile(r"(\d+(?:[.,]\d+)?)\s*(?:%|foiz)")
_DAILY_RE = re.compile(r"\bhar bir (?:kechiktirilgan |kechikkan |kechikish )?(?:kun|kunlik)\w*|\bkunlik\b|\bkuniga\b|\bhar kun\w*")
_CAP_RE = re.compile(r"\boshmaydi\b|\boshmasligi\b|\boshib ketmasligi\b|\bdan oshmagan\b|\bchegar\w+\b|\bmaksimal\b")


def _to_float(s: str) -> float:
    return float(s.replace(",", "."))


def _penalty_predicate(sentence: str, clause: str) -> Optional[Dict]:
    rates = [_to_float(m) for m in _PCT_RE.findall(sentence)]
    daily = bool(_DAILY_RE.search(sentence))
    has_cap = bool(_CAP_RE.search(clause))
    if rates and daily:
        rate = rates[0]
        if rate > 0.5:
            extra = f"Kunlik {rate:g}% penya 670-I 25-modda belgilagan 0,5% dan yuqori"
            if not has_cap:
                extra += " va umumiy summa chegarasi (maksimal limit) ko'rsatilmagan"
            return {"detail": extra + "."}
        if has_cap:
            return None  # 0,5% gacha va chegara bor — qonunga mos
        return {"detail": f"Kunlik {rate:g}% penya uchun umumiy summa chegarasi ko'rsatilmagan."}
    if rates:
        rate = rates[0]
        if rate >= 50 and not has_cap:
            return {"detail": f"{rate:g}% miqdoridagi neustoyka nomutanosib bo'lishi mumkin (FK 326: sud kamaytirishi mumkin)."}
        return None
    return {"detail": "Neustoyka (penya/jarima) miqdori va chegarasi aniq ko'rsatilmagan."}


_MONTHS_NEAR_PROBATION_RE = re.compile(r"\bsinov\w*[^.]{0,60}?(\d+)\s*(?:\(\w+\)\s*)?oy|\b(\d+)\s*(?:\(\w+\)\s*)?oy\w*[^.]{0,30}\bsinov")
_MANAGER_RE = re.compile(r"\brahbar\w*|\bbosh buxgalter\w*|\borinbosar\w*")


def _probation_predicate(sentence: str, clause: str) -> Optional[Dict]:
    m = _MONTHS_NEAR_PROBATION_RE.search(sentence)
    if not m:
        return None
    months = int(m.group(1) or m.group(2))
    limit = 6 if _MANAGER_RE.search(clause) else 3
    if months > limit:
        return {"detail": f"Sinov muddati {months} oy, qonuniy chegara {limit} oy (MK 130-modda)."}
    return None


_QASD_RE = re.compile(r"\bqasd\w*|\bjiddiy beparvo\w*")


def _liability_exclusion_predicate(sentence: str, clause: str) -> Optional[Dict]:
    if _QASD_RE.search(clause):
        return {"risk": "RED", "detail": "Band qasddan yoki jiddiy beparvolik bilan yetkazilgan zarar uchun ham javobgarlikni istisno qiladi."}
    return {}


_VAGUE_CORE_RE = re.compile(r"\bpredmet\w*|\bhajm\w*|\broyxat\w*")


def _vague_terms_predicate(sentence: str, clause: str) -> Optional[Dict]:
    if _VAGUE_CORE_RE.search(sentence):
        return {"risk": "RED"}
    return {"risk": "YELLOW", "norm_nature": "DISPOSITIVE", "detail": "Narx/muddat shartlari keyinga qoldirilgan."}


def _ip_predicate(sentence: str, clause: str) -> Optional[Dict]:
    if re.search(r"\bkelgusida\b|\bkelajakda\b|\bhar qanday (?:kelgusi|keyingi)\b", sentence):
        return {"risk": "RED", "norm_nature": "IMPERATIVE",
                "detail": "Band muallif kelgusida yaratadigan har qanday natijalarga mutlaq huquqlarni berishni yuklaydi; FK 1037-modda bunday shartnomani o'z-o'zidan haqiqiy emas deb belgilaydi."}
    return {}


# --------------------------------------------------------------------------------------
# Umumiy trigger guruhlari
# --------------------------------------------------------------------------------------
_UNILATERAL = _p(
    r"\bbir tomonlama\b",
    r"\bistalgan (?:vaqt|payt|lahza|sana)da\b",
    r"\bsababsiz\b",
    r"\bogohlantirmasdan\b|\bxabardor qilmasdan\b|\bxabar bermasdan\b|\bogohlantirish talab qilinmaydi",
    r"\bhech qanday (?:asos|sabab)siz\b|\basos korsatmasdan\b|\bsababini korsatmasdan\b",
)
_TERMINATE = _p(r"\b(?:bekor|voz kech|rad et|toxtat|tugat)\w*")
_COST_MITIGATION = _p(
    r"\bxarajat\w*[^.]{0,40}\bqopla\w*",
    r"\bqopla\w*[^.]{0,40}\bxarajat\w*",
)
_COST_OVERRIDE = _p(r"\bqoplamasdan\b", r"\bqoplamaydi\b", r"\btolovsiz\b", r"\bjavobgar\w* emas", r"\bjavobgarsiz\b", r"\bhaq tolamasdan\b")

_REALESTATE = _p(r"\bkochmas mulk\w*", r"\bkvartira\w*", r"\buy-joy\b", r"\bturar joy\w*", r"\byer uchastka\w*", r"\bbino\w*")
_SALE_WORDS = _p(r"\boldi-?sotdi\b", r"\bsot(?:ish|iladi|adi|ib|uv|ilishi)\b")


RULES: Tuple[Rule, ...] = (
    # ------------------------------------------------------------------ BEKOR QILISH
    Rule(
        code="TERM_UNILATERAL_SERVICE",
        title="Asossiz bir tomonlama bekor qilish huquqi",
        risk="RED", category="LEGAL", norm_nature="IMPERATIVE",
        root="FK-UZ-2_707",
        related=("FK-UZ-1_354", "FK-UZ-1_324"),
        applies_to=frozenset({SERVICE}),
        supersedes=("TERM_UNILATERAL_GENERAL",),
        groups=(_UNILATERAL, _TERMINATE),
        mitigations=_COST_MITIGATION, mitigation_overrides=_COST_OVERRIDE,
        why=("Band shartnomani ogohlantirishsiz va/yoki ijrochi xarajatlarini qoplamasdan bir tomonlama bekor qilishga imkon beradi. "
             "FK 707-modda buyurtmachiga xizmatlarning belgilangan bahosini to'lash sharti bilan, ijrochiga esa yetkazilgan zararni "
             "to'liq qoplash sharti bilangina shartnomani bekor qilishni talab qilish huquqini beradi."),
        redline=("Buyurtmachi shartnomani bekor qilishdan kamida 15 (o'n besh) kun oldin Ijrochini yozma xabardor qiladi hamda "
                 "Ijrochi tomonidan amalda ko'rsatilgan xizmatlar haqini va asoslangan haqiqiy xarajatlarini to'liq qoplaydi."),
    ),
    Rule(
        code="TERM_UNILATERAL_GENERAL",
        title="Bir tomonlama bekor qilish huquqining muvozanatsizligi",
        risk="YELLOW", category="COMMERCIAL", norm_nature="DISPOSITIVE",
        root="FK-UZ-1_237",
        related=("FK-UZ-1_382", "FK-UZ-1_385"),
        applies_to=frozenset({GENERAL, SALE, LEASE, CONTRACT_WORK}),
        groups=(_UNILATERAL, _TERMINATE),
        mitigations=_COST_MITIGATION, mitigation_overrides=_COST_OVERRIDE,
        why=("Band shartnomani bir tomonlama bekor qilishga imkon beradi. FK 237-modda majburiyatni bajarishdan bir tomonlama bosh tortishga "
             "faqat qonunchilik yoki shartnomada nazarda tutilgan hollardagina yo'l qo'yadi; FK 382-modda shartnomani bekor qilish asoslarini, "
             "385-modda esa oqibatlarini belgilaydi."),
        redline=("Taraflardan har biri shartnomani kamida 30 (o'ttiz) kun oldin yozma ogohlantirib bekor qilishi mumkin; "
                 "bekor qilingunga qadar bajarilgan majburiyatlar va asoslangan xarajatlar to'liq to'lanadi."),
        redline_by_doc={
            LEASE: ("Muddati belgilanmagan ijara shartnomasini taraflardan har biri boshqa tarafni bir oy oldin (ko'chmas mulk ijarasida "
                    "uch oy oldin) yozma ogohlantirib bekor qilishi mumkin (FK 540-modda)."),
        },
    ),
    # ------------------------------------------------------------------ NEUSTOYKA
    Rule(
        code="PENALTY_DISPROPORTIONATE",
        title="Nomutanosib yuqori penya yoki jarima miqdori",
        risk="YELLOW", category="COMMERCIAL", norm_nature="DISPOSITIVE",
        root="FK-UZ-1_326",
        related=("FK-UZ-1_325", "670-I_25"),
        applies_to=frozenset({GENERAL, SALE, LEASE, CONTRACT_WORK, SERVICE}),
        groups=(_p(r"\bpenya\w*", r"\bneustoyka\w*", r"\bjarima\w*", r"\bustama\b"),),
        predicate=_penalty_predicate,
        kind="obligation",
        why=("Neustoyka (penya/jarima) miqdori nomutanosib bo'lishi mumkin. FK 326-modda nomutanosib neustoykani sud tomonidan kamaytirish "
             "imkonini beradi, 670-I qonunning 25-moddasi esa muddat buzilganda kunlik 0,5% penya va umumiy summa 50% dan oshmasligini belgilaydi."),
        redline=("Majburiyat buzilgan har bir kechiktirilgan kun uchun bajarilmagan qism summasining 0,1% miqdorida, lekin umumiy "
                 "shartnoma qiymatining 10% idan oshmagan miqdorda penya to'lanadi."),
    ),
    # ------------------------------------------------------------------ JAVOBGARLIK
    Rule(
        code="LIABILITY_EXCLUSION",
        title="Javobgarlikni to'liq istisno qilish",
        risk="YELLOW", category="LEGAL", norm_nature="IMPERATIVE",
        root="FK-UZ-1_332",
        related=("FK-UZ-1_333", "FK-UZ-1_324"),
        applies_to=frozenset({GENERAL, SALE, LEASE, CONTRACT_WORK, SERVICE}),
        groups=(_p(
            r"\bjavobgar\w* (?:emas|bolmaydi|zimmasiga olmaydi)\b",
            r"\bjavobgarlikdan (?:toliq )?ozod\w*",
            r"\bjavobgarlik\w* (?:istisno|olib tashlan|cheklan)\w*",
            r"\bhech qanday javobgar\w*",
            r"\bzarar\w*[^.]{0,30}\bqoplamaydi\b",
        ),),
        mitigations=_p(r"\bfors-?major\w*", r"\bengib bolmas\w*", r"\bhal qiluvchi kuch\w*", r"\bfavqulodda\b", r"\btabiiy ofat\w*"),
        predicate=_liability_exclusion_predicate,
        why=("Band tomonlardan birini javobgarlikdan to'liq ozod qiladi. FK 333-modda javobgarlik asoslarini belgilaydi, FK 332-modda esa "
             "qo'shilish shartnomasi yoki iste'molchi ishtirokidagi shartnomada javobgarlik hajmini cheklash haqidagi kelishuv haqiqiy emasligi mumkinligini ko'rsatadi."),
        redline=("Taraflar majburiyatlarni buzganlik uchun amaldagi qonunchilikka muvofiq javob beradi; javobgarlik hajmi shartnoma "
                 "bahosi doirasida cheklanishi mumkin, qasddan yoki jiddiy beparvolik bilan buzish holatlari bundan mustasno."),
    ),
    Rule(
        code="LIABILITY_UNLIMITED_SERVICE",
        title="Ijrochining cheksiz moliyaviy javobgarligi",
        risk="YELLOW", category="COMMERCIAL", norm_nature="DISPOSITIVE",
        root="FK-UZ-2_706",
        related=("FK-UZ-1_324", "FK-UZ-1_332"),
        applies_to=frozenset({SERVICE}),
        groups=(
            _p(r"\bijrochi\w*", r"\bxizmat korsatuvchi\w*"),
            _p(r"\bbarcha (?:zarar|yoqotish)\w*", r"\bhamma (?:zarar|yoqotish)\w*", r"\bcheksiz\w* javobgar\w*", r"\bzarar\w*[^.]{0,30}\btoliq (?:hajmda|miqdorda)\b"),
        ),
        kind="obligation",
        why=("Band ijrochini barcha zararlar uchun cheklovsiz javobgar qiladi. FK 706-moddaga ko'ra ijrochi zararni to'liq to'lashi shart, "
             "lekin bu summa xizmatlar bahosining ikki baravaridan oshmaydi; tadbirkorlik faoliyatida kuchaytirilgan javobgarlik shartnomada nazarda tutilishi mumkin."),
        redline=("Ijrochining shartnoma bo'yicha umumiy javobgarligi to'g'ri yetkazilgan zarar bilan cheklanadi va shartnoma bahosining "
                 "ikki baravaridan oshmaydi, qasddan buzish holatlari bundan mustasno."),
    ),
    # ------------------------------------------------------------------ MUHIM SHARTLAR
    Rule(
        code="ESSENTIAL_TERMS_VAGUE",
        title="Shartnomaning muhim shartlari noaniq",
        risk="RED", category="LEGAL", norm_nature="IMPERATIVE",
        root="FK-UZ-1_364",
        related=("FK-UZ-1_356",),
        groups=(_p(
            r"\b(?:predmet|hajm|xizmat\w* royxat|ish\w* hajm|narx|baho|muddat)\w*[^.]{0,60}\b(?:belgilanmagan|aniqlanmagan|keyin(?:chalik)? kelishil\w*|alohida kelishil\w*|keyinroq kelishil\w*)",
        ),),
        predicate=_vague_terms_predicate,
        why=("Shartnomaning muhim shartlari (predmet, hajm, narx, muddat) keyinga qoldirilgan. FK 364-modda muhim shartlar bo'yicha "
             "kelishuvga erishilgan bo'lsagina shartnoma tuzilgan hisoblanishini belgilaydi; narx esa FK 356-moddaga ko'ra taraflar kelishuvi bilan belgilanadi."),
        redline=("Shartnoma predmeti, ko'rsatiladigan xizmatlar ro'yxati, natijani qabul qilish mezonlari, narxi va aniq bajarilish "
                 "muddatlari Taraflar o'rtasida to'liq kelishilgan va shartnomaning 1-ilovasida keltirilgan bo'ladi."),
    ),
    Rule(
        code="PRICE_UNILATERAL_CHANGE",
        title="Narxni bir tomonlama o'zgartirish huquqi",
        risk="YELLOW", category="COMMERCIAL", norm_nature="DISPOSITIVE",
        root="FK-UZ-1_356",
        related=("FK-UZ-1_237",),
        groups=(
            _p(r"\b(?:narx|baho|tarif|stavka|haq)\w*"),
            _p(r"\b(?:ozgartir|oshir|korib chiq)\w*"),
            _p(r"\bbir tomonlama\b", r"\bixtiyori\w*", r"\bozi(?:ning)? xohishi\w*", r"\bogohlantirmasdan\b", r"\bistalgan (?:vaqt|payt)da\b"),
        ),
        mitigations=_p(r"\bikkinchi taraf\w* (?:yozma )?(?:roziligi|kelishuvi)\w*", r"\bqoshimcha kelishuv\w* (?:asosida|bilan)"),
        why=("Band narxni bir tomonlama o'zgartirishga imkon beradi. FK 356-modda tuzilgandan keyin bahoni o'zgartirishga faqat qonunchilik "
             "yoki shartnomada nazarda tutilgan hollarda yo'l qo'yadi; FK 237-modda shartlarni bir tomonlama o'zgartirishni umumiy qoida sifatida taqiqlaydi."),
        redline="Shartnoma narxi faqat Taraflarning yozma qo'shimcha kelishuvi bilan o'zgartiriladi.",
    ),
    Rule(
        code="ADVANCE_PAYMENT_NONREFUNDABLE",
        title="Oldindan to'lovning xavfli shartlari",
        risk="YELLOW", category="COMMERCIAL", norm_nature="DISPOSITIVE",
        root="FK-UZ-2_420",
        related=("FK-UZ-1_324",),
        applies_to=frozenset({GENERAL, SALE, SERVICE, CONTRACT_WORK, LEASE}),
        groups=(
            _p(r"\boldindan (?:tolov|haq)\w*", r"\bavans\w*", r"\bpredoplata\w*", r"\bbonak\w*"),
            _p(r"\bqaytarilmaydi\b", r"\bqaytarib berilmaydi\b", r"\bqaytarish talab qilinmaydi", r"\b100 ?(?:%|foiz)", r"\byuz foiz", r"\btoliq (?:miqdorda|hajmda)\b"),
        ),
        kind="obligation",
        why=("Oldindan to'lov qaytarilmas yoki to'liq miqdorda talab qilinmoqda. Sotuvchi/ijrochi majburiyatni bajarmasa, oldindan to'langan "
             "summani qaytarish va zararni qoplash tartibi FK 420 va 324-moddalarda belgilangan."),
        redline=("Oldindan to'lov miqdori shartnoma bahosining 30% idan oshmaydi. Ijrochi (sotuvchi) majburiyatni bajarmagan taqdirda "
                 "oldindan to'langan summa 5 (besh) bank kuni ichida to'liq qaytariladi va yetkazilgan zarar qoplanadi."),
    ),
    # ------------------------------------------------------------------ SHAKL
    Rule(
        code="FORM_REALESTATE_WRONG_FORM",
        title="Ko'chmas mulk bitimining shakliga rioya qilmaslik",
        risk="RED", category="FORM", norm_nature="IMPERATIVE",
        root="FK-UZ-1_110",
        related=("FK-UZ-2_480", "FK-UZ-2_481", "FK-UZ-2_488"),
        applies_to=frozenset({GENERAL, SALE}),
        groups=(
            _REALESTATE, _SALE_WORDS,
            _p(r"\boddiy yozma\b", r"\bogzaki\b", r"\bnotarial\w* (?:tasdiqlanmaydi|shart emas|talab etilmaydi)"),
        ),
        kind="neutral",
        why=("Ko'chmas mulk oldi-sotdisi oddiy yozma yoki og'zaki shaklda tuzilishi ko'zda tutilgan. FK 480-moddaga ko'ra ko'chmas mulkni sotish "
             "shartnomasi shakliga rioya qilmaslik uning haqiqiy emasligiga sabab bo'ladi; FK 488-modda uy-joyni sotish shartnomasini notarial "
             "tasdiqlash va davlat ro'yxatidan o'tkazishni talab qiladi, FK 110-modda esa notarial tasdiqlash shart bo'lgan hollarni belgilaydi."),
        redline=("Ko'chmas mulkni sotish shartnomasi taraflar imzolagan yozma shakldagi bitta hujjat tarzida tuziladi, notarial tasdiqlanadi "
                 "(qonunda belgilangan hollarda) va mulk huquqining o'tishi davlat ro'yxatidan o'tkaziladi."),
    ),
    Rule(
        code="FORM_REALESTATE_REGISTRATION",
        title="Ko'chmas mulk bitimida notarial/ro'yxat shartlari ko'rsatilmagan",
        risk="YELLOW", category="FORM", norm_nature="IMPERATIVE",
        root="FK-UZ-1_110",
        related=("FK-UZ-2_480", "FK-UZ-2_481", "FK-UZ-2_488"),
        applies_to=frozenset({GENERAL, SALE}),
        groups=(_REALESTATE, _SALE_WORDS),
        mitigations=_p(r"\bnotarial\w*", r"\bdavlat royxat\w*", r"\broyxatdan (?:otkaz|otadi)\w*", r"\bkadastr\w*"),
        kind="neutral",
        why=("Ko'chmas mulk oldi-sotdisi bandida bitimning notarial tasdiqlanishi va mulk huquqini davlat ro'yxatidan o'tkazish tartibi ko'rsatilmagan. "
             "FK 480-moddaga ko'ra shaklga rioya qilmaslik shartnomaning haqiqiy emasligiga olib keladi, FK 481-moddaga ko'ra mulk huquqi davlat ro'yxatidan o'tkazilishi lozim."),
        redline=("Ko'chmas mulkni sotish shartnomasi yozma shakldagi bitta hujjat tarzida tuzilib, notarial tasdiqlanadi va mulk huquqini "
                 "boshqa shaxsga o'tishi davlat ro'yxatidan o'tkaziladi."),
    ),
    # ------------------------------------------------------------------ MAXFIYLIK / SHAXSIY MA'LUMOT
    Rule(
        code="PRIVACY_NO_CONSENT",
        title="Shaxsga doir ma'lumotlarga roziliksiz ishlov berish",
        risk="YELLOW", category="PRIVACY", norm_nature="IMPERATIVE",
        root="ORQ-547_21",
        related=("ORQ-547_15",),
        groups=(
            _p(r"\bshaxsiy malumot\w*", r"\bshaxsga doir malumot\w*", r"\bjshshir\w*"),
            _p(r"\broziligisiz\b", r"\brozilik olmasdan\b", r"\brozilik talab qilinmaydi\b", r"\bistalgan maqsadda\b",
               r"\buchinchi shaxs\w* (?:uzat|topshir|oshkor)\w*", r"\bchegaralanmagan muddat\w*"),
        ),
        why=("Band shaxsga doir ma'lumotlarga subyektning roziligisiz yoki cheklanmagan maqsadda ishlov berishga imkon beradi. "
             "O'RQ-547 21-moddaga ko'ra ishlov berish uchun rozilik olinganligini tasdiqlash imkonini beruvchi shaklda rozilik talab etiladi."),
        redline=("Taraflar shaxsga doir ma'lumotlarga faqat shartnomani bajarish maqsadida va subyektning roziligi asosida ishlov beradi; "
                 "ma'lumotlar uchinchi shaxslarga roziliksiz berilmaydi (O'RQ-547)."),
    ),
    Rule(
        code="PRIVACY_CROSS_BORDER",
        title="Shaxsga doir ma'lumotlarni chet elga uzatish",
        risk="YELLOW", category="PRIVACY", norm_nature="IMPERATIVE",
        root="ORQ-547_15",
        related=("ORQ-547_21",),
        groups=(
            _p(r"\bshaxsiy malumot\w*", r"\bshaxsga doir malumot\w*", r"\bjshshir\w*", r"\bmalumotlar\w*"),
            _p(r"\b(?:chet el|xorij|chet davlat|boshqa davlat)\w*[^.]{0,80}\b(?:uzat|topshir|yubor|saqla|joylashtir)\w*",
               r"\b(?:uzat|topshir|yubor|saqla|joylashtir)\w*[^.]{0,80}\b(?:chet el|xorij|chet davlat)\w*"),
        ),
        why=("Band ma'lumotlarni O'zbekiston hududidan tashqariga uzatishga imkon beradi. O'RQ-547 15-moddaga ko'ra transchegaraviy uzatish "
             "subyektlar huquqlari bir xilda himoya qilinishini ta'minlovchi davlatlar hududiga amalga oshiriladi."),
        redline=("Shaxsga doir ma'lumotlar O'zbekiston hududidan tashqariga faqat subyektlar huquqlari bir xilda himoya qilinishini "
                 "ta'minlovchi davlatlarga va subyektning yozma roziligi bilan uzatiladi (O'RQ-547, 15-modda)."),
    ),
    Rule(
        code="CONFIDENTIALITY_PERPETUAL",
        title="Maxfiylik majburiyatining muddatsizligi",
        risk="YELLOW", category="COMMERCIAL", norm_nature="DISPOSITIVE",
        root="FK-UZ-1_98",
        related=("FK-UZ-2_654",),
        groups=(
            _p(r"\bmaxfiy\w*", r"\bkonfidensial\w*", r"\btijorat sir\w*"),
            _p(r"\bmuddatsiz\b", r"\babadiy\b", r"\bcheksiz muddat\w*", r"\bmuddat\w* (?:cheklanmagan|belgilanmagan)\b", r"\bshartnoma tugagandan (?:keyin|song) ham(?: cheksiz)?\b"),
        ),
        why=("Maxfiylik majburiyati muddat bilan cheklanmagan. FK 98-modda tijorat sirini faqat uni saqlashga doir choralar ko'rilgan hollarda himoya qiladi; "
             "muddatsiz majburiyat bir taraf uchun nomutanosib yuk bo'lishi mumkin."),
        redline="Maxfiylik majburiyati shartnoma muddati davomida va u tugagandan keyin 3 (uch) yil mobaynida amal qiladi.",
    ),
    # ------------------------------------------------------------------ BOSHQA
    Rule(
        code="IP_FUTURE_WORKS_ASSIGNMENT",
        title="Intellektual mulk huquqlarini kengroq o'tkazish",
        risk="YELLOW", category="LEGAL", norm_nature="DISPOSITIVE",
        root="FK-UZ-2_1037",
        related=("FK-UZ-2_1035",),
        groups=(
            _p(r"\bintellektual\w* (?:mulk|faoliyat|huquq)\w*", r"\bmualliflik\w* huquq\w*", r"\bmutlaq huquq\w*"),
            _p(r"\b(?:butunlay|toliq|bepul|abadiy|muddatsiz|barcha|cheklanmagan)\b[^.]{0,60}\b(?:otadi|otkaz\w*|topshir\w*|berad\w*|beriladi)\b",
               r"\b(?:kelgusida|kelajakda) yarat\w*"),
        ),
        predicate=_ip_predicate,
        why=("Band intellektual mulk huquqlarini keng hajmda o'tkazishni nazarda tutadi. FK 1035-modda mulkiy huquqlarni shartnoma bo'yicha o'tkazishga "
             "yo'l qo'yadi, FK 1037-modda esa muallifning kelgusida yaratadigan har qanday natijalariga mutlaq huquqlarni berishni yuklaydigan shartnomani o'z-o'zidan haqiqiy emas deydi."),
        redline=("Ijrochi tomonidan ushbu shartnoma doirasida yaratilgan aniq belgilangan natijaga (1-ilova) mulkiy huquqlar to'lov amalga "
                 "oshirilgandan so'ng Buyurtmachiga o'tadi; Ijrochining kelgusida yaratadigan boshqa natijalari bunga kirmaydi."),
    ),
    Rule(
        code="DEBT_TRANSFER_NO_CONSENT",
        title="Qarzni kreditor roziligisiz boshqa shaxsga o'tkazish",
        risk="RED", category="LEGAL", norm_nature="IMPERATIVE",
        root="FK-UZ-1_322",
        groups=(
            _p(r"\bqarz\w*[^.]{0,80}\b(?:boshqa|uchinchi) shaxs\w*[^.]{0,30}\b(?:otkaz|topshir)\w*",
               r"\bmajburiyat\w*[^.]{0,80}\b(?:boshqa|uchinchi) shaxs\w*[^.]{0,30}\b(?:otkaz|topshir)\w*"),
            _p(r"\broziligisiz\b", r"\brozilik olmasdan\b", r"\bxabardor qilmasdan\b", r"\bogohlantirmasdan\b"),
        ),
        why="FK 322-modda qarzdorning o'z qarzini boshqa shaxsga o'tkazishiga faqat kreditorning roziligi bilan yo'l qo'yadi.",
        redline="Qarzdor o'z majburiyatlarini uchinchi shaxsga faqat kreditorning oldindan yozma roziligi bilan o'tkazishi mumkin.",
    ),
    Rule(
        code="FOREIGN_LAW_JURISDICTION",
        title="Chet el huquqi yoki chet el sudi/arbitraji tanlangan",
        risk="YELLOW", category="COMMERCIAL", norm_nature="DISPOSITIVE",
        root="FK-UZ-2_1158",
        related=("FK-UZ-2_1160",),
        groups=(_p(
            r"\bchet el huquqi\b", r"\b(?:ingliz|rossiya|singapur|angliya) huquqi\b",
            r"\b(?:nizo|kelishmovchilik)\w*[^.]{0,100}\b(?:london|singapur|dubay|moskva|xalqaro tijorat arbitraj\w*|\bicc\b|\blcia\b)\w*",
        ),),
        why=("Nizolarni hal qilish uchun chet el huquqi yoki chet el sudi/arbitraji tanlangan. FK 1158-modda taraflarga qo'llanilishi lozim huquqni "
             "kelishuv asosida belgilash imkonini beradi, lekin bu O'zbekiston tadbirkori uchun qo'shimcha xarajat va ijro xavfini keltirib chiqaradi."),
        redline="Shartnomadan kelib chiqadigan nizolar O'zbekiston Respublikasi qonunchiligiga muvofiq O'zbekiston Respublikasi tegishli sudida hal qilinadi.",
    ),
    Rule(
        code="CONSUMER_RIGHTS_WAIVER",
        title="Iste'molchi huquqlarini cheklash",
        risk="RED", category="LEGAL", norm_nature="IMPERATIVE",
        root="221-I_21",
        related=("221-I_4", "221-I_13"),
        applies_to=frozenset({GENERAL, SALE, SERVICE}),
        groups=(
            _p(r"\bistemolchi\w*", r"\bxaridor\w*", r"\bjismoniy shaxs\w*", r"\bmijoz\w*"),
            _p(r"\bhuquq\w* (?:dan )?(?:voz kech|mahrum)\w*", r"\bvoz kechadi\b", r"\balmashtirilmaydi\b", r"\bqaytarib (?:olinmaydi|berilmaydi)\b",
               r"\bnuqson\w*[^.]{0,40}\bjavobgar\w* (?:emas|bolmaydi)", r"\bgarantiya (?:berilmaydi|taqdim etilmaydi)\b", r"\bshikoyat qilish huquqi\w*"),
        ),
        why=("Band iste'molchining qonuniy huquqlarini cheklaydi. 221-I qonunning 21-moddasiga ko'ra shartnomaning iste'molchi huquqlarini "
             "cheklab qo'yadigan va qonunchilikka zid shartlari haqiqiy emas; nuqsonli tovar bo'yicha huquqlar 13-moddada belgilangan."),
        redline=("Iste'molchining «Iste'molchilarning huquqlarini himoya qilish to'g'risida»gi Qonunda belgilangan huquqlari (jumladan nuqsonli "
                 "tovarni almashtirish, haqini qaytarish) cheklanmaydi."),
    ),
    Rule(
        code="DISGUISED_EMPLOYMENT",
        title="Fuqarolik shartnomasi ostida mehnat munosabatlarini yashirish xavfi",
        risk="RED", category="LABOR", norm_nature="IMPERATIVE",
        root="MK-2022_33",
        related=("MK-2022_11",),
        applies_to=frozenset({SERVICE, CONTRACT_WORK, GENERAL}),
        groups=(
            _p(r"\bish vaqti\w*", r"\bichki mehnat tartib\w*", r"\bintizomiy\w*", r"\btatil\w*", r"\bish jadval\w*", r"\bishga kelish\w*"),
            _p(r"\bxizmat korsatish\w*", r"\bpudrat\w*", r"\bozini ozi band\w*", r"\bfuqarolik-huquqiy\w*"),
        ),
        kind="neutral",
        why=("Fuqarolik-huquqiy shartnomada ish vaqti, intizomiy javobgarlik yoki ta'til kabi mehnat munosabatlari belgilari bor. "
             "MK 33-moddaga ko'ra mehnat munosabatlarini haqiqatda tartibga soluvchi fuqarolik shartnomasi sud tomonidan yakka tartibdagi mehnat munosabatlari deb e'tirof etilishi mumkin."),
        redline=("Ijrochi ishni o'z tashkiliy mustaqilligi asosida bajaradi, ish vaqti va ichki mehnat tartibiga bo'ysunmaydi; "
                 "munosabatlar faqat natijaga yo'naltirilgan. Agar mehnat munosabatlari mavjud bo'lsa — mehnat shartnomasi tuzilsin."),
    ),
    Rule(
        code="EMP_PROBATION_EXCESS",
        title="Sinov muddati qonuniy chegaradan oshgan",
        risk="RED", category="LABOR", norm_nature="IMPERATIVE",
        root="MK-2022_130",
        related=("MK-2022_105",),
        applies_to=frozenset({EMPLOYMENT}),
        groups=(_p(r"\bsinov\w*"),),
        predicate=_probation_predicate,
        kind="neutral",
        why="MK 130-moddaga ko'ra dastlabki sinov muddati uch oydan, tashkilot rahbarlari va ularning o'rinbosarlari, bosh buxgalterlar uchun olti oydan oshmasligi kerak.",
        redline="Xodimga dastlabki sinov muddati 3 (uch) oy belgilanadi.",
    ),
    Rule(
        code="EMP_WORSE_THAN_LAW",
        title="Xodim ahvolini qonunga nisbatan yomonlashtiradigan shart",
        risk="YELLOW", category="LABOR", norm_nature="IMPERATIVE",
        root="MK-2022_105",
        applies_to=frozenset({EMPLOYMENT}),
        groups=(
            _p(r"\bxodim\w*"),
            _p(r"\bjarima\w* (?:undiril|ushlab qolin)\w*", r"\bish haqi\w*[^.]{0,40}\bushlab qol\w*", r"\btatilga chiqish huquqi\w*[^.]{0,30}\byoq\b", r"\bxodim\w* (?:ish haqi|tatil)\w*[^.]{0,30}\bhaqli emas\b"),
        ),
        kind="obligation",
        why="MK 105-moddaga ko'ra xodimning holatini mehnat qonunchiligiga nisbatan yomonlashtiradigan shartlar mehnat shartnomasiga kiritilmasligi kerak, kiritilgan bo'lsa haqiqiy bo'lmaydi.",
        redline="Xodimga nisbatan jarima va ish haqidan asossiz ushlab qolish qo'llanilmaydi; ish haqi va ta'til Mehnat kodeksiga muvofiq beriladi.",
    ),
)

RULES_BY_CODE: Dict[str, Rule] = {r.code: r for r in RULES}
