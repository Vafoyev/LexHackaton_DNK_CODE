package rules

import (
	"regexp"
	"strings"
)

type Severity string

const (
	SeverityRed    Severity = "RED"
	SeverityYellow Severity = "YELLOW"
	SeverityGreen  Severity = "GREEN"
)

type RiskCategory string

const (
	CategoryLegal      RiskCategory = "LEGAL"
	CategoryCommercial RiskCategory = "COMMERCIAL"
	CategoryForm       RiskCategory = "FORM"
	CategoryLabor      RiskCategory = "LABOR"
	CategoryPrivacy    RiskCategory = "PRIVACY"
	CategoryAI         RiskCategory = "AI"
)

type LegalReference struct {
	Code        string `json:"code"`
	Article     string `json:"article"`
	NormNature  string `json:"norm_nature"` // IMPERATIVE, DISPOSITIVE
	OfficialURL string `json:"official_url"`
	Explanation string `json:"explanation"`
}

type RuleFinding struct {
	RuleCode          string         `json:"rule_code"`
	RiskCategory      RiskCategory   `json:"risk_category"`
	Severity          Severity       `json:"severity"`
	ClauseNumber      string         `json:"clause_number"`
	OriginalQuote     string         `json:"original_quote"`
	SuggestedRevision string         `json:"suggested_revision"`
	LegalSource       LegalReference `json:"legal_source"`
	Explanation       string         `json:"explanation"`
	ConfidenceScore   float64        `json:"confidence_score"`
}

type RuleDefinition struct {
	Code        string
	Category    RiskCategory
	Severity    Severity
	Name        string
	LegalSource LegalReference
	CheckFunc   func(clauseNumber, text string, fullDocText string) *RuleFinding
}

type RulesEngine struct {
	rules []RuleDefinition
}

func NewRulesEngine() *RulesEngine {
	e := &RulesEngine{}
	e.initRules()
	return e
}

func (e *RulesEngine) GetActiveRules() []RuleDefinition {
	return e.rules
}

func (e *RulesEngine) AnalyzeClause(clauseNumber, clauseText string, fullDocText string) []RuleFinding {
	findings := make([]RuleFinding, 0)
	for _, rule := range e.rules {
		if f := rule.CheckFunc(clauseNumber, clauseText, fullDocText); f != nil {
			findings = append(findings, *f)
		}
	}
	return findings
}

func (e *RulesEngine) AnalyzeDocument(clauses map[string]string, fullDocText string) []RuleFinding {
	allFindings := make([]RuleFinding, 0)

	// Check each clause individually
	for num, text := range clauses {
		fs := e.AnalyzeClause(num, text, fullDocText)
		allFindings = append(allFindings, fs...)
	}

	docLower := strings.ToLower(fullDocText)

	// 1. SVC_NO_ACCEPTANCE_ACT (if whole doc has no mention of dalolatnoma / akt)
	if !strings.Contains(docLower, "dalolatnoma") && !strings.Contains(docLower, "ijro akti") && !strings.Contains(docLower, "qabul qilish") {
		allFindings = append(allFindings, RuleFinding{
			RuleCode:          "SVC_NO_ACCEPTANCE_ACT",
			RiskCategory:      CategoryCommercial,
			Severity:          SeverityYellow,
			ClauseNumber:      "UMUMIY",
			OriginalQuote:     "Shartnomada xizmatlarni topshirish-qabul qilish dalolatnomasi nazarda tutilmagan.",
			SuggestedRevision: "Xizmatlar ko‘rsatilgach, Ijrochi 3 bank kuni ichida topshirish-qabul qilish dalolatnomasini taqdim etadi. Buyurtmachi 5 bank kuni ichida uni imzolaydi yoki asoslantirilgan e’tiroz bildiradi.",
			LegalSource: LegalReference{
				Code:        "FK-UZ",
				Article:     "706-modda",
				NormNature:  "DISPOSITIVE",
				OfficialURL: "https://lex.uz/docs/180552#181530",
				Explanation: "Xizmat natijalari dalolatnoma bilan qabul qilinishi va e'tiroz muddatlari belgilanishi tavsiya etiladi.",
			},
			Explanation:     "Qabul qilish dalolatnomasi (akt) va e'tiroz muddati yo'qligi sababli kelgusida to'lov bo'yicha nizolar yuzaga kelishi mumkin.",
			ConfidenceScore: 0.95,
		})
	}

	// 2. SVC_FORCE_MAJEURE_MISSING (if whole doc has no mention of fors-major / yengib bo'lmas kuch)
	if !strings.Contains(docLower, "fors-major") && !strings.Contains(docLower, "fors major") && !strings.Contains(docLower, "yengib bo‘lmas") && !strings.Contains(docLower, "yengib bolmas") {
		allFindings = append(allFindings, RuleFinding{
			RuleCode:          "SVC_FORCE_MAJEURE_MISSING",
			RiskCategory:      CategoryCommercial,
			Severity:          SeverityYellow,
			ClauseNumber:      "UMUMIY",
			OriginalQuote:     "Shartnomada fors-major (yengib bo‘lmas kuch) holatlari va xabardor qilish tartibi mavjud emas.",
			SuggestedRevision: "Taraflar ixtiyoriga bog‘liq bo‘lmagan yengib bo‘lmas kuch (fors-major) holatlari yuz berganda majburiyatlarni bajarish muddati ushbu holatlar davom etgan vaqtga mutanosib ravishda kechiktiriladi. Jabrlangan taraf 3 kun ichida yozma xabar berishi shart.",
			LegalSource: LegalReference{
				Code:        "FK-UZ",
				Article:     "333-modda",
				NormNature:  "DISPOSITIVE",
				OfficialURL: "https://lex.uz/docs/111181#111600",
				Explanation: "Favqulodda va oldini olib bo'lmaydigan holatlarda javobgarlikdan ozod etish tartibi shartnomada belgilanishi maqsadga muvofiq.",
			},
			Explanation:     "Fors-major bandi yo'qligi sababli kutilmagan favqulodda vaziyatlarda to'liq javobgarlik xavfi mavjud.",
			ConfidenceScore: 0.95,
		})
	}

	// 3. PRIVACY_CONSENT_MISSING (if document involves personal data but has no consent clause)
	if (strings.Contains(docLower, "pasport") || strings.Contains(docLower, "jshshir") || strings.Contains(docLower, "shaxsiy ma'lumot") || strings.Contains(docLower, "shaxsiy ma’lumot")) &&
		!strings.Contains(docLower, "rozilik") && !strings.Contains(docLower, "ishlov berishga rozilik") {
		allFindings = append(allFindings, RuleFinding{
			RuleCode:          "PRIVACY_CONSENT_MISSING",
			RiskCategory:      CategoryPrivacy,
			Severity:          SeverityYellow,
			ClauseNumber:      "UMUMIY",
			OriginalQuote:     "Hujjatda shaxsiy ma'lumotlar mavjud, biroq ularga ishlov berish bo'yicha subyektning yozma roziligi kiritilmagan.",
			SuggestedRevision: "Tomonlar ushbu shartnoma majburiyatlarini bajarish doirasida taqdim etilgan shaxsiy ma’lumotlarni O‘zbekiston Respublikasining O‘RQ-547-sonli Qonuni talablariga muvofiq qayta ishlashga, saqlashga va foydalanishga o‘zlarining to‘liq roziligini beradilar.",
			LegalSource: LegalReference{
				Code:        "ORQ-547",
				Article:     "15-modda",
				NormNature:  "IMPERATIVE",
				OfficialURL: "https://lex.uz/docs/4396428#4397000",
				Explanation: "Shaxsiy ma'lumotlarga ishlov berish faqat subyektning aniq roziligi bilan amalga oshiriladi.",
			},
			Explanation:     "O‘RQ-547 15-moddasiga ko'ra shaxsiy ma'lumotlarni qayta ishlash faqat subyektning qonuniy roziligi bo'lgandagina amalga oshirilishi mumkin.",
			ConfidenceScore: 0.93,
		})
	}

	// 4. DATA_BREACH_NOTIFICATION_MISSING (if confidentiality/data processing exists but no breach notification)
	if (strings.Contains(docLower, "maxfiylik") || strings.Contains(docLower, "axborot xavfsizligi") || strings.Contains(docLower, "shaxsiy ma'lumot")) &&
		!strings.Contains(docLower, "24 soat") && !strings.Contains(docLower, "sizib chiqishi") && !strings.Contains(docLower, "xavfsizlik buzilishi") {
		allFindings = append(allFindings, RuleFinding{
			RuleCode:          "DATA_BREACH_NOTIFICATION_MISSING",
			RiskCategory:      CategoryPrivacy,
			Severity:          SeverityYellow,
			ClauseNumber:      "UMUMIY",
			OriginalQuote:     "Shartnomada kiberxavfsizlik buzilishi yoki ma'lumotlar sizib chiqishi (data breach) holatida 24 soatlik xabardor qilish tartibi mavjud emas.",
			SuggestedRevision: "Axborot xavfsizligi hodisasi yoki ma’lumotlar sizib chiqishi aniqlangan taqdirda, aybdor taraf ikkinchi tarafni va vakolatli organni 24 soat ichida yozma yoki elektron tarzda xabardor qilishi shart.",
			LegalSource: LegalReference{
				Code:        "ORQ-1125",
				Article:     "18-modda",
				NormNature:  "IMPERATIVE",
				OfficialURL: "https://lex.uz/docs/orq-1125#art18",
				Explanation: "Kiberxavfsizlik va maxfiylikni kuchaytirish to'g'risidagi qonun bo'yicha breach haqida 24 soat ichida xabar berish majburiy.",
			},
			Explanation:     "O‘RQ-1125 18-moddasiga ko'ra konfidensial axborot yoki shaxsiy ma'lumotlar sizib chiqqanda 24 soatlik xabardor qilish tartibi talab etiladi.",
			ConfidenceScore: 0.90,
		})
	}

	// 5. AI_HUMAN_OVERSIGHT_MISSING (if doc mentions AI/ML algorithms but lacks human oversight disclaimer)
	if (strings.Contains(docLower, "sun'iy intellekt") || strings.Contains(docLower, "sun’iy intellekt") || strings.Contains(docLower, "ai algoritmlari") || strings.Contains(docLower, "avtomatlashtirilgan xulosa")) &&
		!strings.Contains(docLower, "inson nazorati") && !strings.Contains(docLower, "disklaymer") && !strings.Contains(docLower, "axborot-tahliliy") {
		allFindings = append(allFindings, RuleFinding{
			RuleCode:          "AI_HUMAN_OVERSIGHT_MISSING",
			RiskCategory:      CategoryAI,
			Severity:          SeverityYellow,
			ClauseNumber:      "UMUMIY",
			OriginalQuote:     "Sun'iy intellekt tizimlari qo'llanilishi qayd etilgan, biroq inson nazorati (Human-in-the-loop) va axborot-tahliliy disklaymer belgilanmagan.",
			SuggestedRevision: "Sun’iy intellekt texnologiyalari vositasida chiqarilgan barcha tahlillar axborot-maslahat xarakteriga ega bo‘lib, inson huquqlariga daxldor yakuniy qarorlar vakolatli inson-mutaxassis nazorati ostida qabul qilinadi.",
			LegalSource: LegalReference{
				Code:        "ORQ-1115",
				Article:     "6-modda",
				NormNature:  "IMPERATIVE",
				OfficialURL: "https://lex.uz/docs/orq-1115#art6",
				Explanation: "AI tizimlari faoliyatida inson huquqlari ustuvorligi va inson nazorati shartnoma darajasida kafolatlanishi shart.",
			},
			Explanation:     "O‘RQ-1115 6-moddasi AI tavsiyalarida inson nazoratisiz yakuniy yuridik yoki iqtisodiy ahamiyatga ega qarorlar qabul qilinishini taqiqlaydi.",
			ConfidenceScore: 0.96,
		})
	}

	// 6. R5_DISPUTE_MEDIATION_MISSING (Mediatsiya qonuni 16-modda — 10 kunlik sudgacha pretenziya va mediatsiya)
	if !strings.Contains(docLower, "mediatsiya") && !strings.Contains(docLower, "pretenziya") && !strings.Contains(docLower, "медиац") && !strings.Contains(docLower, "претензи") {
		allFindings = append(allFindings, RuleFinding{
			RuleCode:          "R5_DISPUTE_MEDIATION_MISSING",
			RiskCategory:      CategoryCommercial,
			Severity:          SeverityYellow,
			ClauseNumber:      "UMUMIY",
			OriginalQuote:     "Shartnomada nizolarni sudgacha hal qilish (pretenziya) va mediatsiya bosqichi nazarda tutilmagan.",
			SuggestedRevision: "Shartnoma bo‘yicha kelib chiqqan nizolar avvalo 10 kalendar kunlik yozma pretenziya va O‘zbekiston Respublikasining «Mediatsiya to‘g‘risida»gi Qonuniga muvofiq professional mediatsiya tartibida hal qilinadi; kelishuvga erishilmasa, iqtisodiy sudga murojaat qilinadi.",
			LegalSource: LegalReference{
				Code:        "ORQ-482",
				Article:     "16-modda",
				NormNature:  "DISPOSITIVE",
				OfficialURL: "https://lex.uz/docs/3805227",
				Explanation: "Sudgacha pretenziya va mediatsiya bosqichi nizolarni tez va kam xarajat bilan hal qilish imkonini beradi.",
			},
			Explanation:     "Qonunga mos, lekin e'tibor kerak: agar sudgacha 10 kunlik pretenziya va mediatsiya qo'shilmasa, har qanday kichik nizo to'g'ridan-to'g'ri sud xarajati va vaqt yo'qotishiga olib keladi.",
			ConfidenceScore: 0.94,
		})
	}

	return allFindings
}

func (e *RulesEngine) initRules() {
	// 1. SVC_UNILATERAL_TERMINATION (FK 707)
	reUnilateral := regexp.MustCompile(`(?i)(istalgan\s+paytda\s+to['‘]lovsiz|ogohlantirmasdan\s+bekor\s+qilishi\s+mumkin|bir\s+tomonlama\s+bosh\s+tortish|xarajatlarni\s+qoplamasdan\s+bekor)`)
	e.rules = append(e.rules, RuleDefinition{
		Code:     "SVC_UNILATERAL_TERMINATION",
		Category: CategoryLegal,
		Severity: SeverityRed,
		Name:     "Bir tomonlama asossiz va to'lovsiz bekor qilish xavfi",
		LegalSource: LegalReference{
			Code:        "FK-UZ",
			Article:     "707-modda",
			NormNature:  "IMPERATIVE",
			OfficialURL: "https://lex.uz/docs/180552#181540",
			Explanation: "FK 707-moddasiga ko'ra, Buyurtmachi ijrochining amalda qilgan xarajatlarini to'lash sharti bilangina shartnomani bekor qilishi mumkin.",
		},
		CheckFunc: func(clauseNum, text, fullDoc string) *RuleFinding {
			if loc := reUnilateral.FindString(text); loc != "" {
				return &RuleFinding{
					RuleCode:          "SVC_UNILATERAL_TERMINATION",
					RiskCategory:      CategoryLegal,
					Severity:          SeverityRed,
					ClauseNumber:      clauseNum,
					OriginalQuote:     extractQuoteAround(text, loc),
					SuggestedRevision: "Buyurtmachi Ijrochiga uning amalda qilgan xarajatlarini to‘liq to‘lash va kamida 30 kun oldin yozma xabardor qilish sharti bilan shartnomani bajarishdan bosh tortishi mumkin.",
					LegalSource: LegalReference{
						Code:        "FK-UZ",
						Article:     "707-modda",
						NormNature:  "IMPERATIVE",
						OfficialURL: "https://lex.uz/docs/180552#181540",
						Explanation: "Buyurtmachi amalda qilingan xarajatlarni qoplamasdan shartnomani bir tomonlama bekor qila olmaydi.",
					},
					Explanation:     "Bandda bir tarafga shartnomani ogohlantirmasdan yoki qilingan xarajatlarni to'lamasdan bekor qilish huquqi berilgan, bu FK 707-moddasiga ziddir.",
					ConfidenceScore: 0.98,
				}
			}
			return nil
		},
	})

	// 2. SVC_UNLIMITED_LIABILITY (FK 324)
	reUnlimitedLiab := regexp.MustCompile(`(?i)(cheksiz\s+moddiy\s+javobgarlik|barcha\s+to['‘]g['‘]ridan-to['‘]g['‘]ri\s+va\s+bilvosita\s+zararlar|boy\s+berilgan\s+foydani\s+cheksiz|javobgarlik\s+cheklanmaydi)`)
	e.rules = append(e.rules, RuleDefinition{
		Code:     "SVC_UNLIMITED_LIABILITY",
		Category: CategoryCommercial,
		Severity: SeverityYellow,
		Name:     "Cheksiz moliyaviy javobgarlik xavfi",
		LegalSource: LegalReference{
			Code:        "FK-UZ",
			Article:     "324-modda",
			NormNature:  "DISPOSITIVE",
			OfficialURL: "https://lex.uz/docs/111181#111550",
			Explanation: "Tadbirkorlik munosabatlarida javobgarlik shartnoma qiymati doirasida cheklanishi mumkin.",
		},
		CheckFunc: func(clauseNum, text, fullDoc string) *RuleFinding {
			if loc := reUnlimitedLiab.FindString(text); loc != "" {
				return &RuleFinding{
					RuleCode:          "SVC_UNLIMITED_LIABILITY",
					RiskCategory:      CategoryCommercial,
					Severity:          SeverityYellow,
					ClauseNumber:      clauseNum,
					OriginalQuote:     extractQuoteAround(text, loc),
					SuggestedRevision: "Ijrochining ushbu shartnoma bo‘yicha umumiy javobgarlik miqdori shartnomaning umumiy narxidan oshmasligi belgilansin, boy berilgan foyda qoplanmaydi.",
					LegalSource: LegalReference{
						Code:        "FK-UZ",
						Article:     "324-modda",
						NormNature:  "DISPOSITIVE",
						OfficialURL: "https://lex.uz/docs/111181#111550",
						Explanation: "Zararlarni qoplash shartnoma shartlariga muvofiq oqilona chegaralanishi kerak.",
					},
					Explanation:     "Shartnomada cheksiz yoki mutanosib bo'lmagan javobgarlik belgilangan bo'lib, jiddiy moliyaviy yo'qotishlarga olib kelishi mumkin.",
					ConfidenceScore: 0.92,
				}
			}
			return nil
		},
	})

	// 3. SVC_PENALTY_FORM_RISK (FK 326)
	reHighPenalty := regexp.MustCompile(`(?i)(kun(?:iga|\s+uchun)\s+[0-9.]+\s*%|penya\s+[0-9.]+\s*%|jarima\s+[0-9.]+\s*%|[0-9.]+\s*%\s*miqdorida\s*penya)`)
	e.rules = append(e.rules, RuleDefinition{
		Code:     "SVC_PENALTY_FORM_RISK",
		Category: CategoryCommercial,
		Severity: SeverityYellow,
		Name:     "Nomutanosib yuqori neustoyka (penya/jarima) xavfi",
		LegalSource: LegalReference{
			Code:        "FK-UZ",
			Article:     "326-modda",
			NormNature:  "DISPOSITIVE",
			OfficialURL: "https://lex.uz/docs/111181#111580",
			Explanation: "Sud nomutanosib yuqori neustoykani kamaytirish huquqiga ega.",
		},
		CheckFunc: func(clauseNum, text, fullDoc string) *RuleFinding {
			if loc := reHighPenalty.FindString(text); loc != "" {
				return &RuleFinding{
					RuleCode:          "SVC_PENALTY_FORM_RISK",
					RiskCategory:      CategoryCommercial,
					Severity:          SeverityYellow,
					ClauseNumber:      clauseNum,
					OriginalQuote:     extractQuoteAround(text, loc),
					SuggestedRevision: "Majburiyatlar kechiktirilgan har bir kun uchun 0.1% miqdorida penya to‘lanadi, biroq penyalarning umumiy summasi kechiktirilgan to‘lovning 10% idan oshmasligi shart.",
					LegalSource: LegalReference{
						Code:        "FK-UZ",
						Article:     "326-modda",
						NormNature:  "DISPOSITIVE",
						OfficialURL: "https://lex.uz/docs/111181#111580",
						Explanation: "FK 326-moddasiga ko'ra sud nomutanosib penyani pasaytirishi mumkin, ammo nizolarni oldini olish uchun 0.1%-0.5% chegara tavsiya etiladi.",
					},
					Explanation:     "Kechiktirilgan har bir kun uchun o'rnatilgan penya bozor amaliyoti va O'zR FK 326-moddasi talablariga nisbatan haddan tashqari yuqori.",
					ConfidenceScore: 0.96,
				}
			}
			return nil
		},
	})

	// 4. SVC_MISSING_SUBJECT_SCOPE (FK 364)
	reVagueSubject := regexp.MustCompile(`(?i)(barcha\s+zarur\s+xizmatlar|og['‘]zaki\s+kelishuvga\s+ko['‘]ra|keyinchalik\s+aniqlashtiriladigan|aniq\s+hajmi\s+belgilanmagan)`)
	e.rules = append(e.rules, RuleDefinition{
		Code:     "SVC_MISSING_SUBJECT_SCOPE",
		Category: CategoryLegal,
		Severity: SeverityRed,
		Name:     "Shartnoma predmeti va xizmatlar ko'lamining noaniqligi",
		LegalSource: LegalReference{
			Code:        "FK-UZ",
			Article:     "364-modda",
			NormNature:  "IMPERATIVE",
			OfficialURL: "https://lex.uz/docs/111181#111650",
			Explanation: "FK 364-moddasiga ko'ra shartnoma predmeti bo'yicha aniq kelishuv tuzilmagan shartnoma tuzilmagan hisoblanadi.",
		},
		CheckFunc: func(clauseNum, text, fullDoc string) *RuleFinding {
			if strings.Contains(clauseNum, "1") || strings.Contains(strings.ToLower(text), "predmet") {
				if loc := reVagueSubject.FindString(text); loc != "" {
					return &RuleFinding{
						RuleCode:          "SVC_MISSING_SUBJECT_SCOPE",
						RiskCategory:      CategoryLegal,
						Severity:          SeverityRed,
						ClauseNumber:      clauseNum,
						OriginalQuote:     extractQuoteAround(text, loc),
						SuggestedRevision: "Ijrochi Buyurtmachiga ushbu shartnomaning ajralmas qismi bo‘lgan 1-sonli Ilovada ko‘rsatilgan texnik topshiriq va muddatlar bo‘yicha xizmatlarni to‘liq ko‘rsatadi.",
						LegalSource: LegalReference{
							Code:        "FK-UZ",
							Article:     "364-modda",
							NormNature:  "IMPERATIVE",
							OfficialURL: "https://lex.uz/docs/111181#111650",
							Explanation: "Shartnomaning asosiy sharti hisoblangan predmet va xizmatlar ro'yxati aniq belgilanishi shart.",
						},
						Explanation:     "Xizmatlar ko'lami, natijasi va topshiriq chegaralari noaniq ifodalangan, bu shartnomani haqiqiy emas deb topishga sabab bo'lishi mumkin.",
						ConfidenceScore: 0.94,
					}
				}
			}
			return nil
		},
	})

	// 5. SVC_PAYMENT_TERMS_AMBIGUOUS (FK 705)
	reAmbiguousPayment := regexp.MustCompile(`(?i)(mablag['‘]\s+bo['‘]lganda\s+to['‘]lanadi|imkoniyatga\s+qarab|aniq\s+muddatsiz|muddati\s+ko['‘]rsatilmagan)`)
	e.rules = append(e.rules, RuleDefinition{
		Code:     "SVC_PAYMENT_TERMS_AMBIGUOUS",
		Category: CategoryCommercial,
		Severity: SeverityYellow,
		Name:     "To'lov muddatlari va tartibining noaniqligi",
		LegalSource: LegalReference{
			Code:        "FK-UZ",
			Article:     "705-modda",
			NormNature:  "DISPOSITIVE",
			OfficialURL: "https://lex.uz/docs/180552#181520",
			Explanation: "Xizmatlar uchun to'lov shartnomada belgilangan muddat va tartibda amalga oshirilishi shart.",
		},
		CheckFunc: func(clauseNum, text, fullDoc string) *RuleFinding {
			if loc := reAmbiguousPayment.FindString(text); loc != "" {
				return &RuleFinding{
					RuleCode:          "SVC_PAYMENT_TERMS_AMBIGUOUS",
					RiskCategory:      CategoryCommercial,
					Severity:          SeverityYellow,
					ClauseNumber:      clauseNum,
					OriginalQuote:     extractQuoteAround(text, loc),
					SuggestedRevision: "Buyurtmachi ko‘rsatilgan xizmatlar uchun to‘lovni topshirish-qabul qilish dalolatnomasi imzolangan kundan boshlab 5 bank kuni ichida Ijrochining hisob-raqamiga to‘liq o‘tkazadi.",
					LegalSource: LegalReference{
						Code:        "FK-UZ",
						Article:     "705-modda",
						NormNature:  "DISPOSITIVE",
						OfficialURL: "https://lex.uz/docs/180552#181520",
						Explanation: "To'lov muddati va bank rekvizitlari aniq ko'rsatilishi kerak.",
					},
					Explanation:     "To'lovning noaniq muddati qarzdorlikni undirish jarayonini qiyinlashtiradi.",
					ConfidenceScore: 0.91,
				}
			}
			return nil
		},
	})

	// 6. FORM_MANDATORY_NOTARIAL (FK 110)
	reNotarial := regexp.MustCompile(`(?i)(ko['‘]chmas\s+mulkni\s+boshqa\s+shaxsga\s+o['‘]tkazish|avtotransport\s+oldi-sotdi|nikoh\s+shartnomasi)`)
	e.rules = append(e.rules, RuleDefinition{
		Code:     "FORM_MANDATORY_NOTARIAL",
		Category: CategoryForm,
		Severity: SeverityRed,
		Name:     "Majburiy notarial tasdiqlash talabi",
		LegalSource: LegalReference{
			Code:        "FK-UZ",
			Article:     "110-modda",
			NormNature:  "IMPERATIVE",
			OfficialURL: "https://lex.uz/docs/111181#111300",
			Explanation: "Qonunda belgilangan hollarda bitimlar notarial tasdiqlanishi shart, aks holda ular haqiqiy emas hisoblanadi.",
		},
		CheckFunc: func(clauseNum, text, fullDoc string) *RuleFinding {
			if loc := reNotarial.FindString(text); loc != "" {
				return &RuleFinding{
					RuleCode:          "FORM_MANDATORY_NOTARIAL",
					RiskCategory:      CategoryForm,
					Severity:          SeverityRed,
					ClauseNumber:      clauseNum,
					OriginalQuote:     extractQuoteAround(text, loc),
					SuggestedRevision: "Ushbu shartnoma O‘zbekiston Respublikasi Notariat qonunlariga muvofiq davlat notarial idorasi tomonidan tasdiqlanishi va ro‘yxatdan o‘tkazilishi shart.",
					LegalSource: LegalReference{
						Code:        "FK-UZ",
						Article:     "110-modda",
						NormNature:  "IMPERATIVE",
						OfficialURL: "https://lex.uz/docs/111181#111300",
						Explanation: "Ko'chmas mulk va avtotransportga oid bitimlarning notarial tasdiqlanmasligi ularni o'z-o'zidan haqiqiy emas (FK 112) qiladi.",
					},
					Explanation:     "Hujjat predmeti majburiy notarial tasdiqlashni talab etuvchi bitimlar toifasiga kiradi.",
					ConfidenceScore: 0.99,
				}
			}
			return nil
		},
	})

	// 7. CURRENCY_SETTLEMENT_ILLEGAL (FK 245)
	reCurrency := regexp.MustCompile(`(?i)(to['‘]lov\s+(?:naqd\s+)?(?:aqsh\s+dollarida|usd|evroda|eur)|chet\s+el\s+valyutasida\s+amalga\s+oshiriladi|valyutada\s+naqd\s+to['‘]lanadi)`)
	e.rules = append(e.rules, RuleDefinition{
		Code:     "CURRENCY_SETTLEMENT_ILLEGAL",
		Category: CategoryLegal,
		Severity: SeverityRed,
		Name:     "O'zbekiston hududida xorijiy valyutada to'lov amalga oshirish taqiqi",
		LegalSource: LegalReference{
			Code:        "FK-UZ",
			Article:     "245-modda",
			NormNature:  "IMPERATIVE",
			OfficialURL: "https://lex.uz/docs/111181#111430",
			Explanation: "FK 245-moddasiga ko'ra O'zbekiston Respublikasi hududida pul majburiyatlari so'mda ifodalanishi va bajarilishi shart.",
		},
		CheckFunc: func(clauseNum, text, fullDoc string) *RuleFinding {
			if loc := reCurrency.FindString(text); loc != "" {
				return &RuleFinding{
					RuleCode:          "CURRENCY_SETTLEMENT_ILLEGAL",
					RiskCategory:      CategoryLegal,
					Severity:          SeverityRed,
					ClauseNumber:      clauseNum,
					OriginalQuote:     extractQuoteAround(text, loc),
					SuggestedRevision: "Barcha hisob-kitoblar O‘zbekiston Respublikasining milliy valyutasi — so‘mda to‘lov amalga oshirilgan kundagi Markaziy Bank kursi bo‘yicha amalga oshiriladi.",
					LegalSource: LegalReference{
						Code:        "FK-UZ",
						Article:     "245-modda",
						NormNature:  "IMPERATIVE",
						OfficialURL: "https://lex.uz/docs/111181#111430",
						Explanation: "O'zbekiston hududidagi rezidentlar o'rtasida to'lovlar qat'iy milliy valyutada o'tkazilishi lozim.",
					},
					Explanation:     "Shartnomada O'zR hududida to'g'ridan-to'g'ri chet el valyutasida to'lov qilish ko'rsatilgan, bu FK 245-moddasi va Valyutani tartibga solish to'g'risidagi qonunchilikka ziddir.",
					ConfidenceScore: 0.99,
				}
			}
			return nil
		},
	})

	// 8. LABOR_PROBATION_EXCESSIVE (MK 130-modda / 84-modda)
	reProbationExcessive := regexp.MustCompile(`(?i)(sinov\s+muddati\s+(?:4|5|6|12)\s+oy|(?:4|5|6|12)\s+oy(?:lik)?\s+sinov|sinov\s+muddati\s+1\s+yil|1\s+yillik\s+sinov|homilador.*sinov|sinov.*homilador|yosh\s+bolasi.*sinov|bitiruvchi.*sinov)`)
	e.rules = append(e.rules, RuleDefinition{
		Code:     "LABOR_PROBATION_EXCESSIVE",
		Category: CategoryLabor,
		Severity: SeverityRed,
		Name:     "Sinov muddatining qonuniy me'yordan ortiq belgilanishi",
		LegalSource: LegalReference{
			Code:        "MK-2022",
			Article:     "130-modda",
			NormNature:  "IMPERATIVE",
			OfficialURL: "https://lex.uz/docs/6257288#6258020",
			Explanation: "Mehnat Kodeksiga ko'ra dastlabki sinov muddati 3 oydan (rahbarlar uchun 6 oydan) oshmasligi shart. Homilador va bitiruvchilarga sinov taqiqlanadi.",
		},
		CheckFunc: func(clauseNum, text, fullDoc string) *RuleFinding {
			if loc := reProbationExcessive.FindString(text); loc != "" {
				return &RuleFinding{
					RuleCode:          "LABOR_PROBATION_EXCESSIVE",
					RiskCategory:      CategoryLabor,
					Severity:          SeverityRed,
					ClauseNumber:      clauseNum,
					OriginalQuote:     extractQuoteAround(text, loc),
					SuggestedRevision: "Xodimga 3 oydan oshmagan dastlabki sinov muddati belgilanadi. Homilador ayollar, 3 yoshgacha bolasi borlar va bitiruvchilarga sinov muddati qo‘llanilmaydi.",
					LegalSource: LegalReference{
						Code:        "MK-2022",
						Article:     "130-modda",
						NormNature:  "IMPERATIVE",
						OfficialURL: "https://lex.uz/docs/6257288#6258020",
						Explanation: "Oddiy xodimlar uchun 3 oydan ortiq sinov muddati belgilash qat'iyan taqiqlanadi.",
					},
					Explanation:     "Sinov muddati qonunda ruxsat etilgan maksimal chegaradan oshirib belgilangan yoki sinov taqiqlangan shaxslarga yuklatilgan (MK 130).",
					ConfidenceScore: 0.97,
				}
			}
			return nil
		},
	})

	// 9. LABOR_NO_COMPETE_ILLEGAL (MK 5, 404-modda)
	reNoCompete := regexp.MustCompile(`(?i)(ishdan\s+bo['‘]shagandan\s+so['‘]ng.*(?:ishlamaslik|raqobatchi|shug['‘]ullanmaslik)|raqobatchi\s+kompaniyaga\s+ishga\s+kirmaslik|no-compete|mehnat\s+faoliyatini\s+cheklash)`)
	e.rules = append(e.rules, RuleDefinition{
		Code:     "LABOR_NO_COMPETE_ILLEGAL",
		Category: CategoryLabor,
		Severity: SeverityRed,
		Name:     "Konstitutsiyaviy mehnat erkinligini cheklovchi no-compete sharti",
		LegalSource: LegalReference{
			Code:        "MK-2022",
			Article:     "404-modda",
			NormNature:  "IMPERATIVE",
			OfficialURL: "https://lex.uz/docs/6257288#6259450",
			Explanation: "Mehnat shartnomasi bekor bo'lgach xodimning mehnat qilishini cheklovchi bitimlar o'z-o'zidan haqiqiy emasdir.",
		},
		CheckFunc: func(clauseNum, text, fullDoc string) *RuleFinding {
			if loc := reNoCompete.FindString(text); loc != "" {
				return &RuleFinding{
					RuleCode:          "LABOR_NO_COMPETE_ILLEGAL",
					RiskCategory:      CategoryLabor,
					Severity:          SeverityRed,
					ClauseNumber:      clauseNum,
					OriginalQuote:     extractQuoteAround(text, loc),
					SuggestedRevision: "Xodim mehnat munosabatlari tugagandan so‘ng tijorat siri va maxfiy ma’lumotlarni oshkor qilmaslik majburiyatini oladi. Biroq erkin mehnat qilish va yangi ishga kirish huquqi cheklanmaydi.",
					LegalSource: LegalReference{
						Code:        "MK-2022",
						Article:     "404-modda",
						NormNature:  "IMPERATIVE",
						OfficialURL: "https://lex.uz/docs/6257288#6259450",
						Explanation: "O'zbekiston qonunchiligida fuqaroning keyinchalik raqobatchida ishlashini taqiqlovchi har qanday cheklov o'z-o'zidan haqiqiy emas.",
					},
					Explanation:     "Bandda xodimning ishdan bo'shaganidan keyin mehnat qilish huquqi noqonuniy cheklangan, bu MK 5 va 404-moddalariga ko'ra o'z-o'zidan haqiqiy emasdir.",
					ConfidenceScore: 0.99,
				}
			}
			return nil
		},
	})

	// 10. LABOR_WORKING_HOURS_EXCESSIVE (MK 199, 200-modda)
	reWorkHours := regexp.MustCompile(`(?i)(haftasiga\s+(?:48|50|56|60)\s+soat|dam\s+olish\s+kunlarisiz\s+ish|kuniga\s+(?:10|12|14)\s+soat\s+ish)`)
	e.rules = append(e.rules, RuleDefinition{
		Code:     "LABOR_WORKING_HOURS_EXCESSIVE",
		Category: CategoryLabor,
		Severity: SeverityRed,
		Name:     "Haftalik normal ish vaqti me'yorining oshirilishi",
		LegalSource: LegalReference{
			Code:        "MK-2022",
			Article:     "199-modda",
			NormNature:  "IMPERATIVE",
			OfficialURL: "https://lex.uz/docs/6257288#6258350",
			Explanation: "Ish vaqtining normal davomiyligi haftasiga 40 soatdan ortiq bo'lishi mumkin emas.",
		},
		CheckFunc: func(clauseNum, text, fullDoc string) *RuleFinding {
			if loc := reWorkHours.FindString(text); loc != "" {
				return &RuleFinding{
					RuleCode:          "LABOR_WORKING_HOURS_EXCESSIVE",
					RiskCategory:      CategoryLabor,
					Severity:          SeverityRed,
					ClauseNumber:      clauseNum,
					OriginalQuote:     extractQuoteAround(text, loc),
					SuggestedRevision: "Xodim uchun ish vaqtining normal davomiyligi haftasiga 40 soatdan (5 kunlik ish haftasida kuniga 8 soatdan) oshmasligi belgilansin.",
					LegalSource: LegalReference{
						Code:        "MK-2022",
						Article:     "199-modda",
						NormNature:  "IMPERATIVE",
						OfficialURL: "https://lex.uz/docs/6257288#6258350",
						Explanation: "40 soatdan ortiq ish vaqti kiritilishi xodimning mehnat huquqlarini buzadi va javobgarlikka sabab bo'ladi.",
					},
					Explanation:     "Mehnat shartnomasida qonunda belgilangan haftalik 40 soatlik normal me'yordan ortiq ish vaqti ko'rsatilgan (MK 199).",
					ConfidenceScore: 0.98,
				}
			}
			return nil
		},
	})

	// 11. LABOR_FULL_LIABILITY_ILLEGAL (MK 337, 342, 343-modda)
	reFullLiab := regexp.MustCompile(`(?i)(xodimdan\s+boy\s+berilgan\s+foydani\s+undirish|xodim\s+barcha\s+zararlar\s+uchun\s+to['‘]liq\s+moddiy\s+javobgar|asossiz\s+jarima\s+undirish|ish\s+haqidan\s+cheksiz\s+ushlab\s+qolish)`)
	e.rules = append(e.rules, RuleDefinition{
		Code:     "LABOR_FULL_LIABILITY_ILLEGAL",
		Category: CategoryLabor,
		Severity: SeverityRed,
		Name:     "Xodimga noqonuniy to'liq moddiy javobgarlik va boy berilgan foydani yuklash",
		LegalSource: LegalReference{
			Code:        "MK-2022",
			Article:     "337-modda",
			NormNature:  "IMPERATIVE",
			OfficialURL: "https://lex.uz/docs/6257288#6259100",
			Explanation: "Xodimdan olinmagan daromadlarni (boy berilgan foydani) undirish taqiqlanadi, to'liq javobgarlik faqat maxsus ro'yxat bo'yicha mumkin.",
		},
		CheckFunc: func(clauseNum, text, fullDoc string) *RuleFinding {
			if loc := reFullLiab.FindString(text); loc != "" {
				return &RuleFinding{
					RuleCode:          "LABOR_FULL_LIABILITY_ILLEGAL",
					RiskCategory:      CategoryLabor,
					Severity:          SeverityRed,
					ClauseNumber:      clauseNum,
					OriginalQuote:     extractQuoteAround(text, loc),
					SuggestedRevision: "Xodim faqat bevosita yetkazilgan haqiqiy moddiy zarar uchun o‘rtacha oylik ish haqi doirasida javobgar bo‘ladi. Boy berilgan foydani xodimdan undirishga yo‘l qo‘yilmaydi.",
					LegalSource: LegalReference{
						Code:        "MK-2022",
						Article:     "337-modda",
						NormNature:  "IMPERATIVE",
						OfficialURL: "https://lex.uz/docs/6257288#6259100",
						Explanation: "MK 337-moddasiga binoan xodim yetkazilgan to'g'ridan-to'g'ri haqiqiy zarar uchungina moddiy javobgar bo'ladi.",
					},
					Explanation:     "Xodimga olinmagan foydani qoplash yoki qonunda ko'zda tutilmagan cheksiz moddiy javobgarlik yuklangan, bu qonunga ziddir.",
					ConfidenceScore: 0.97,
				}
			}
			return nil
		},
	})

	// 12. DATA_LOCALIZATION_BREACH (ORQ-547 27-1-modda)
	reDataLoc := regexp.MustCompile(`(?i)(chet\s+el(?:dagi)?\s+serverlarda\s+saqlanadi|serverlar\s+o['‘]zbekiston\s+tashqarisida|ma['‘]lumotlar\s+bazasi\s+xorijda|o['‘]zbekistonda\s+mahalliylashtirmasdan)`)
	e.rules = append(e.rules, RuleDefinition{
		Code:     "DATA_LOCALIZATION_BREACH",
		Category: CategoryPrivacy,
		Severity: SeverityRed,
		Name:     "Shaxsiy ma'lumotlar bazalarini O'zbekistonda mahalliylashtirish talabining buzilishi",
		LegalSource: LegalReference{
			Code:        "ORQ-547",
			Article:     "27-1-modda",
			NormNature:  "IMPERATIVE",
			OfficialURL: "https://lex.uz/docs/4396428#5270100",
			Explanation: "O'zbekiston fuqarolarining shaxsiy ma'lumotlariga ishlov berishda serverlar va ma'lumotlar bazalari O'zbekiston Respublikasi hududida joylashgan bo'lishi shart.",
		},
		CheckFunc: func(clauseNum, text, fullDoc string) *RuleFinding {
			if loc := reDataLoc.FindString(text); loc != "" {
				return &RuleFinding{
					RuleCode:          "DATA_LOCALIZATION_BREACH",
					RiskCategory:      CategoryPrivacy,
					Severity:          SeverityRed,
					ClauseNumber:      clauseNum,
					OriginalQuote:     extractQuoteAround(text, loc),
					SuggestedRevision: "O‘zbekiston Respublikasi fuqarolarining shaxsiy ma’lumotlariga ishlov berishda ularning jismonan O‘zbekiston hududida joylashgan texnik vositalarda va Davlat reyestrida ro‘yxatdan o‘tgan bazalarda saqlanishi ta’minlanadi.",
					LegalSource: LegalReference{
						Code:        "ORQ-547",
						Article:     "27-1-modda",
						NormNature:  "IMPERATIVE",
						OfficialURL: "https://lex.uz/docs/4396428#5270100",
						Explanation: "O‘RQ-547 27-1-moddasi fuqarolar shaxsiy ma'lumotlarini mamlakat hududidagi serverlarda saqlashni majburiy qiladi.",
					},
					Explanation:     "Shaxsiy ma'lumotlarni xorijiy serverlarda O'zbekistonda mahalliylashtirmasdan saqlash O‘RQ-547 27-1-moddasi talabini jiddiy buzadi.",
					ConfidenceScore: 0.99,
				}
			}
			return nil
		},
	})
}

func extractQuoteAround(full, sub string) string {
	idx := strings.Index(full, sub)
	if idx == -1 {
		return sub
	}
	start := idx - 30
	if start < 0 {
		start = 0
	}
	end := idx + len(sub) + 40
	if end > len(full) {
		end = len(full)
	}
	quote := strings.TrimSpace(full[start:end])
	return quote
}
