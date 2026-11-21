"""
LexGuard AI — 3-Layer Notarial vs Oddiy Shartnoma Aniqlash Arxitekturasi
Vazifasi:
  1-qavat (Qonun talabi): Bitim turi O'zbekiston qonunchiligiga ko'ra majburiy notarial
          tasdiqlashni (FK 110, 112, 271, 479, 504, 539; Oila kodeksi 30) talab qiladimi,
          yoki oddiy yozma shakl / E-ijara yetarlimi — shuni aniqlaydi.
  2-qavat (Hujjat rekvizitlari): Hujjat matnida haqiqiy notarial tasdiq belgilari
          (E-Notarius reyestr raqami, notarius tasdiqlovchi ustxati, gerbli blanka, QR-kod)
          mavjudligini yoki aksincha «notariussiz» inkor iborasi borligini ball tizimida tekshiradi.
  3-qavat (Qaror matritsasi): 100% deterministik xulosa:
          - MISSING_MANDATORY_NOTARIZATION -> RED (FK-UZ-1 110-modda)
          - VERIFIED_NOTARIAL_DOCUMENT     -> GREEN (Notarial rekvizitlar aniqlandi)
          - VOLUNTARY_NOTARIAL_DOCUMENT    -> GREEN (Ixtiyoriy notarial tasdiqlangan)
          - VALID_SIMPLE_WRITTEN           -> GREEN (Oddiy yozma shakl qonunga mos)
          - MISSING_E_IJARA_REMINDER       -> YELLOW (Notarius shart emas, E-ijara kerak)
"""

import re
from typing import Any, Dict, List

from app.normalizer import normalize_uzbek


# 1-qavat: Majburiy notarial tasdiq talab qiladigan bitimlar (O'zR qonunchiligi)
_MANDATORY_NOTARIAL_PATTERNS = [
    (
        "REAL_ESTATE_ALIENATION",
        "Ko'chmas mulk (kvartira, uy-joy, bino, yer) oldi-sotdi/hadya/ayirboshlash",
        ["ko'chmas mulk", "kvartira", "uy-joy", "turar joy", "bino", "hovli", "yer uchastka", "nedvijimost"],
        ["oldi-sotdi", "sotib olish", "sotib oladi", "sotish", "sotadi", "sotiladi", "hadya", "sovg'a", "ayirboshlash", "ayirboshlaydi", "almashtirish", "umrbod ta'minlash", "renta", "mulk huquqini o'tkazish"],
        "FK-UZ-1_110",
    ),
    (
        "VEHICLE_ALIENATION",
        "Avtomototransport vositasi oldi-sotdi / hadya / ayirboshlash",
        ["avtomobil", "avtotransport", "transport vositasi", "mashina", "yengil avto", "yuk mashinasi"],
        ["oldi-sotdi", "sotib olish", "sotib oladi", "sotish", "sotadi", "sotiladi", "hadya", "ayirboshlash", "tasarruf etish", "boshqarish ishonchnoma"],
        "FK-UZ-1_110",
    ),
    (
        "REAL_ESTATE_MORTGAGE",
        "Ko'chmas mulk ipotekasi / notarial garov shartnomasi",
        ["ipoteka", "ko'chmas mulk garov", "kvartira garov", "uy-joy garov", "bino garov"],
        ["garov", "ipoteka", "ta'minot", "kredit"],
        "FK-UZ-1_271",
    ),
    (
        "MARRIAGE_CONTRACT",
        "Nikoh shartnomasi",
        ["nikoh shartnomasi", "er-xotin mulkiy"],
        ["nikoh", "er-xotin", "mulk"],
        "FK-UZ-1_110",
    ),
    (
        "NOTARIAL_POWER_OF_ATTORNEY",
        "Ko'chmas mulk yoki qayta ishonish (peretoverennost) ishonchnomasi",
        ["ishonchnoma", "qayta ishonish", "bosh ishonchnoma"],
        ["ko'chmas mulk", "kvartira", "avtomobil", "qayta ishonish", "sotish huquqi"],
        "FK-UZ-1_138",
    ),
    (
        "WILL_TESTAMENT",
        "Vasiyatnoma",
        ["vasiyatnoma", "meros qoldiruvchi"],
        ["vasiyat", "meros"],
        "FK-UZ-1_110",
    ),
]

# E-ijara (ijara.soliq.uz) talab qilinadigan ko'chmas mulk ijarasi (NOTARIUS SHART EMAS!)
_LEASE_SUBJECT_WORDS = [
    "ijara", "ijaraga berish", "ijaraga olish", "arendaga", "ofis xonasi",
    "noturar joy", "omborxona", "do'kon ijarasi", "kvartira ijarasi", "uy ijarasi",
]
_LEASE_REAL_ESTATE_WORDS = [
    "ofis", "noturar", "turar joy", "kvartira", "uy-joy", "bino", "xona", "ombor", "do'kon", "ko'chmas mulk",
]

# Oddiy yozma shakl to'liq yetarli bo'lgan tijoriy / fuqarolik bitimlar
_SIMPLE_WRITTEN_TYPES = [
    ("B2B_SERVICE", ["xizmat ko'rsatish", "haq evaziga xizmat", "konsalting", "marketing xizmat", "it xizmat", "dasturiy ta'minot"]),
    ("SUPPLY_GOODS", ["yetkazib berish", "tovar yetkazib", "uskuna yetkazib", "ulgurji savdo", "mahsulot yetkazib"]),
    ("CONSTRUCTION_WORK", ["pudrat", "qurilish-ta'mirlash", "ta'mirlash ishlari", "montaj ishlari"]),
    ("EMPLOYMENT", ["mehnat shartnomasi", "ish beruvchi", "xodim", "oylik maosh", "shtat"]),
    ("LOAN_SIMPLE", ["qarz shartnomasi", "qarz oluvchi", "qarz beruvchi", "tilxat"]),
    ("NDA_CONFIDENTIALITY", ["maxfiylik shartnomasi", "oshkor etmaslik", "nda"]),
    ("ECOMMERCE_OFFER", ["ommaviy oferta", "elektron tijorat", "onlayn do'kon", "foydalanuvchi kelishuvi"]),
]

# 2-qavat: Hujjatda haqiqiy notarial tasdiq mavjudligini ko'rsatuvchi rekvizitlar
_EXPLICIT_WITHOUT_NOTARY_PHRASES = [
    "notarial tasdiqlashsiz",
    "notarial tasdiqsiz",
    "notariussiz",
    "notarius ishtirokisiz",
    "notarial rasmiylashtirishsiz",
    "notarial rasmiylashtirmasdan",
    "notariusga bormasdan",
    "notarius tasdiqisiz",
    "oddiy yozma shaklda kuchga kiradi",
]

_NOTARIAL_STRONG_MARKERS = [
    ("notarius_attestation", 3, [
        "notarius tomonidan tasdiqlandi",
        "xususiy amaliyot bilan shug'ullanuvchi notarius",
        "davlat notarial idorasi",
        "ushbu shartnoma men",
        "notarial tasdiqlash yozuvi",
        "notarial harakat",
    ]),
    ("registry_number", 3, [
        "reyestrda qayd etildi",
        "reestrga kiritildi",
        "reyestr raqami",
        "reestr no",
        "reyestr no",
        "e-notarius",
        "notarius.uz",
    ]),
    ("official_blank_and_fee", 2, [
        "gerbli blanka",
        "davlat boji undirildi",
        "notarial idora muhri",
        "imzolar haqiqiyligi tasdiqlandi",
        "tomonlarning shaxsi va muomala layoqati tekshirildi",
    ]),
    ("qr_verification", 2, [
        "qr-kod",
        "qr kod",
        "qr code",
        "elektron notarial",
    ]),
]

_E_IJARA_MARKERS = [
    "e-ijara", "ijara.soliq.uz", "soliq organlarida hisobga", "soliq qo'mitasi", "hisobga qo'yiladi",
]


def _has_registry_regex(norm_text: str) -> bool:
    """'reyestr № 1234' yoki 'reestr 2026/441' kabi naqshlarni aniqlaydi."""
    return bool(re.search(r"(?:reyestr|reestr)\s*(?:no|n|raqami|#|:)?\s*[\d/-]{2,}", norm_text))


def classify_document_form(text: str, doc_type_hint: str = "") -> Dict[str, Any]:
    """
    Hujjat yoki band matnini 3-qavatli arxitektura orqali baholab,
    notarial shartnoma yoki oddiy yozma shartnoma ekanligini aniq qaytaradi.
    """
    norm = normalize_uzbek(f"{doc_type_hint} {text}")

    # --- 2-qavat: Hujjatda notarial tasdiq rekvizitlari bormi? ---
    explicit_bypass = any(p in norm for p in _EXPLICIT_WITHOUT_NOTARY_PHRASES)

    matched_markers: List[str] = []
    notarial_score = 0
    if not explicit_bypass:
        for marker_name, weight, phrases in _NOTARIAL_STRONG_MARKERS:
            if any(p in norm for p in phrases):
                matched_markers.append(marker_name)
                notarial_score += weight
        if _has_registry_regex(norm) and "registry_number" not in matched_markers:
            matched_markers.append("registry_number_pattern")
            notarial_score += 3
        # Yengil ishora (masalan qisqa bandda "notarius orqali tasdiqlangan" deb yozilgan bo'lsa)
        if notarial_score == 0 and any(
            p in norm
            for p in [
                "notarial tasdiqlangan",
                "notarial tartibda tasdiqlanadi",
                "notarius orqali rasmiylashtiriladi",
                "notarius tomonidan tasdiqlanadi",
            ]
        ):
            matched_markers.append("notarial_clause_commitment")
            notarial_score += 3

    has_notarial_proof = (not explicit_bypass) and (notarial_score >= 3)
    has_e_ijara = any(m in norm for m in _E_IJARA_MARKERS)

    # --- 1-qavat: Qonun talabi (Bitim turi bo'yicha) ---
    # A) Avval ko'chmas mulk / transport ijarasini mulkni o'tkazishdan (oldi-sotdi/hadya) ajratib olamiz!
    is_lease = any(w in norm for w in _LEASE_SUBJECT_WORDS)
    is_real_estate_lease = is_lease and any(w in norm for w in _LEASE_REAL_ESTATE_WORDS)
    is_alienation_verb = any(
        v in norm
        for v in ["oldi-sotdi", "sotib olish", "sotish", "hadya", "sovg'a", "ayirboshlash", "umrbod ta'minlash", "renta", "ipoteka"]
    )

    matched_mandatory = None
    if not (is_real_estate_lease and not is_alienation_verb):
        for code, label, subjects, actions, cited_id in _MANDATORY_NOTARIAL_PATTERNS:
            if any(s in norm for s in subjects) and any(a in norm for a in actions):
                matched_mandatory = {
                    "transaction_code": code,
                    "transaction_label": label,
                    "cited_node_id": cited_id,
                }
                break

    # Agar oddiy yozma turi aniq ko'rinsa
    detected_simple_type = "GENERAL_CONTRACT"
    for stype, kws in _SIMPLE_WRITTEN_TYPES:
        if any(k in norm for k in kws):
            detected_simple_type = stype
            break

    # --- 3-qavat: Deterministik Qaror Matritsasi ---
    if matched_mandatory is not None:
        if has_notarial_proof:
            return {
                "legal_requirement": "NOTARIAL_REQUIRED",
                "detected_form": "NOTARIAL_DOCUMENT",
                "form_status": "VERIFIED_NOTARIAL_DOCUMENT",
                "risk_level": "GREEN",
                "transaction_type": matched_mandatory["transaction_code"],
                "transaction_label": matched_mandatory["transaction_label"],
                "notarial_score": notarial_score,
                "matched_markers": matched_markers,
                "explicit_bypass": False,
                "cited_node_id": matched_mandatory["cited_node_id"],
                "summary_uz": (
                    f"Notarial shartnoma aniqlandi ({matched_mandatory['transaction_label']}). "
                    "Hujjatda notarial tasdiqlash rekvizitlari mavjud; QR-kod va reyestr raqamini e-notarius.uz orqali qo'shimcha tekshirish tavsiya etiladi."
                ),
            }
        return {
            "legal_requirement": "NOTARIAL_REQUIRED",
            "detected_form": "SIMPLE_WRITTEN_DOCUMENT",
            "form_status": "MISSING_MANDATORY_NOTARIZATION",
            "risk_level": "RED",
            "transaction_type": matched_mandatory["transaction_code"],
            "transaction_label": matched_mandatory["transaction_label"],
            "notarial_score": notarial_score,
            "matched_markers": matched_markers,
            "explicit_bypass": explicit_bypass,
            "cited_node_id": matched_mandatory["cited_node_id"],
            "summary_uz": (
                f"Majburiy notarial tasdiq topilmadi ({matched_mandatory['transaction_label']}). "
                "O'zR Fuqarolik kodeksi 110 va 112-moddalariga ko'ra ushbu turdagi bitim notarial tartibda tasdiqlanishi shart, aks holda haqiqiy emas deb topilishi xavfi mavjud."
            ),
        }

    if is_real_estate_lease:
        if has_notarial_proof:
            return {
                "legal_requirement": "REGISTRATION_REQUIRED",
                "detected_form": "NOTARIAL_DOCUMENT",
                "form_status": "VOLUNTARY_NOTARIAL_DOCUMENT",
                "risk_level": "GREEN",
                "transaction_type": "REAL_ESTATE_LEASE",
                "transaction_label": "Ko'chmas mulk (ofis / turar joy) ijarasi",
                "notarial_score": notarial_score,
                "matched_markers": matched_markers,
                "explicit_bypass": False,
                "cited_node_id": "FK-UZ-2_574",
                "summary_uz": "Ijara shartnomasi ixtiyoriy notarial tasdiqlangan. Qo'shimcha ravishda ijara.soliq.uz (E-ijara) hisobini tekshirish yetarli.",
            }
        if not has_e_ijara:
            return {
                "legal_requirement": "REGISTRATION_REQUIRED",
                "detected_form": "SIMPLE_WRITTEN_DOCUMENT",
                "form_status": "MISSING_E_IJARA_REMINDER",
                "risk_level": "YELLOW",
                "transaction_type": "REAL_ESTATE_LEASE",
                "transaction_label": "Ko'chmas mulk (ofis / turar joy) ijarasi",
                "notarial_score": notarial_score,
                "matched_markers": matched_markers,
                "explicit_bypass": False,
                "cited_node_id": "FK-UZ-2_574",
                "summary_uz": (
                    "Oddiy yozma ijara shartnomasi uchun notarius majburiy emas (qonunga mos). "
                    "Biroq ijara shartnomasini ijara.soliq.uz (E-ijara) tizimida hisobga qo'yish talab etiladi — qilmasangiz soliq va jarima oqibati kelib chiqadi."
                ),
            }
        return {
            "legal_requirement": "REGISTRATION_REQUIRED",
            "detected_form": "SIMPLE_WRITTEN_DOCUMENT",
            "form_status": "VALID_SIMPLE_WRITTEN",
            "risk_level": "GREEN",
            "transaction_type": "REAL_ESTATE_LEASE",
            "transaction_label": "Ko'chmas mulk (ofis / turar joy) ijarasi",
            "notarial_score": notarial_score,
            "matched_markers": matched_markers,
            "explicit_bypass": False,
            "cited_node_id": "FK-UZ-2_574",
            "summary_uz": "Oddiy yozma ijara shartnomasi qonunga mos va E-ijara (ijara.soliq.uz) hisobga qo'yish tartibi ko'rsatilgan.",
        }

    if has_notarial_proof:
        return {
            "legal_requirement": "SIMPLE_WRITTEN_ALLOWED",
            "detected_form": "NOTARIAL_DOCUMENT",
            "form_status": "VOLUNTARY_NOTARIAL_DOCUMENT",
            "risk_level": "GREEN",
            "transaction_type": detected_simple_type,
            "transaction_label": "Ixtiyoriy notarial tasdiqlangan shartnoma",
            "notarial_score": notarial_score,
            "matched_markers": matched_markers,
            "explicit_bypass": False,
            "cited_node_id": "",
            "summary_uz": "Ushbu turdagi shartnoma uchun qonun notarial tasdiqni majburiy qilmaydi, lekin taraflar ixtiyoriy ravishda notarial tasdiqlatganlar.",
        }

    return {
        "legal_requirement": "SIMPLE_WRITTEN_ALLOWED",
        "detected_form": "SIMPLE_WRITTEN_DOCUMENT",
        "form_status": "VALID_SIMPLE_WRITTEN",
        "risk_level": "GREEN",
        "transaction_type": detected_simple_type,
        "transaction_label": "Oddiy yozma shartnoma",
        "notarial_score": notarial_score,
        "matched_markers": matched_markers,
        "explicit_bypass": False,
        "cited_node_id": "",
        "summary_uz": "Oddiy yozma shartnoma. O'zbekiston qonunchiligiga ko'ra ushbu bitim uchun majburiy notarial tasdiqlash talab etilmaydi.",
    }
