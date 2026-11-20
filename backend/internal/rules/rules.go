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
)

type LegalReference struct {
	Code         string `json:"code"`
	Article      string `json:"article"`
	NormNature   string `json:"norm_nature"` // IMPERATIVE, DISPOSITIVE
	OfficialURL  string `json:"official_url"`
	Explanation  string `json:"explanation"`
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
	Code              string
	Category          RiskCategory
	Severity          Severity
	Name              string
	LegalSource       LegalReference
	CheckFunc         func(clauseNumber, text string, fullDocText string) *RuleFinding
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

	// Document-level missing clause checks (e.g., missing force majeure, missing acceptance act)
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
				Article:     "333-modda 3-qism",
				NormNature:  "DISPOSITIVE",
				OfficialURL: "https://lex.uz/docs/111181#111600",
				Explanation: "Favqulodda va oldini olib bo'lmaydigan holatlarda javobgarlikdan ozod etish tartibi shartnomada belgilanishi maqsadga muvofiq.",
			},
			Explanation:     "Fors-major bandi yo'qligi sababli kutilmagan favqulodda vaziyatlarda to'liq javobgarlik xavfi mavjud.",
			ConfidenceScore: 0.95,
		})
	}

	return allFindings
}

func (e *RulesEngine) initRules() {
	// 1. SVC_UNILATERAL_TERMINATION
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

	// 2. SVC_UNLIMITED_LIABILITY
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

	// 3. SVC_PENALTY_FORM_RISK
	reHighPenalty := regexp.MustCompile(`(?i)(kuniga\s+[1-9]\s*%|kuniga\s+0\.[6-9]\s*%|penya\s+[2-9][0-9]\s*%|jarima\s+50\s*%|jarima\s+100\s*%)`)
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

	// 4. SVC_MISSING_SUBJECT_SCOPE
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

	// 5. SVC_PAYMENT_TERMS_AMBIGUOUS
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

	// 6. SVC_DISPUTE_ONE_SIDED
	reDisputeOneSided := regexp.MustCompile(`(?i)(faqat\s+buyurtmachi\s+joylashgan\s+sud|da['‘]vo\s+qilish\s+huquqisiz|pretenziya\s+tartibisiz\s+darhol)`)
	e.rules = append(e.rules, RuleDefinition{
		Code:     "SVC_DISPUTE_ONE_SIDED",
		Category: CategoryCommercial,
		Severity: SeverityYellow,
		Name:     "Bir tomonlama sudlovlik va da'vo cheklovi",
		LegalSource: LegalReference{
			Code:        "IPK-UZ",
			Article:     "32-modda",
			NormNature:  "DISPOSITIVE",
			OfficialURL: "https://lex.uz/docs/3518384",
			Explanation: "Nizolarni hal etishda taraflar teng huquqqa ega.",
		},
		CheckFunc: func(clauseNum, text, fullDoc string) *RuleFinding {
			if loc := reDisputeOneSided.FindString(text); loc != "" {
				return &RuleFinding{
					RuleCode:          "SVC_DISPUTE_ONE_SIDED",
					RiskCategory:      CategoryCommercial,
					Severity:          SeverityYellow,
					ClauseNumber:      clauseNum,
					OriginalQuote:     extractQuoteAround(text, loc),
					SuggestedRevision: "Barcha kelishmovchiliklar muzokaralar va 15 kunlik yozma pretenziya tartibida hal etiladi. Kelishuvga erishilmagan taqdirda nizo Iqtisodiy sudda O‘zbekiston Respublikasi qonunchiligiga binoan ko‘rib chiqiladi.",
					LegalSource: LegalReference{
						Code:        "IPK-UZ",
						Article:     "32-modda",
						NormNature:  "DISPOSITIVE",
						OfficialURL: "https://lex.uz/docs/3518384",
						Explanation: "Iqtisodiy protsessual kodeks nizolarni sudgacha hal etish va sudlovlik qoidalarini belgilaydi.",
					},
					Explanation:     "Nizolarni hal qilishda bir tarafning huquqlari asossiz ustun qo'yilgan.",
					ConfidenceScore: 0.89,
				}
			}
			return nil
		},
	})

	// 7. SVC_CONFIDENTIALITY_IP_GAP
	reConfidentialGap := regexp.MustCompile(`(?i)(intellektual\s+mulk\s+o['‘]tmaydi|mualliflik\s+huquqi\s+noaniq|maxfiylik\s+saqlanmaydi)`)
	e.rules = append(e.rules, RuleDefinition{
		Code:     "SVC_CONFIDENTIALITY_IP_GAP",
		Category: CategoryCommercial,
		Severity: SeverityYellow,
		Name:     "Intellektual mulk va maxfiylik himoyasining yetarli emasligi",
		LegalSource: LegalReference{
			Code:        "FK-UZ",
			Article:     "1031-modda",
			NormNature:  "DISPOSITIVE",
			OfficialURL: "https://lex.uz/docs/180552",
			Explanation: "Xizmatlar natijasida yaratilgan intellektual mulk huquqlarining o'tish tartibi shartnomada belgilanishi shart.",
		},
		CheckFunc: func(clauseNum, text, fullDoc string) *RuleFinding {
			if loc := reConfidentialGap.FindString(text); loc != "" {
				return &RuleFinding{
					RuleCode:          "SVC_CONFIDENTIALITY_IP_GAP",
					RiskCategory:      CategoryCommercial,
					Severity:          SeverityYellow,
					ClauseNumber:      clauseNum,
					OriginalQuote:     extractQuoteAround(text, loc),
					SuggestedRevision: "Xizmat ko‘rsatish jarayonida yaratilgan barcha mulkiy va mualliflik huquqlari to‘liq haq to‘langandan so‘ng Buyurtmachiga o‘tadi. Taraflar tijorat siri va maxfiy axborotni 3 yil davomida oshkor qilmaslik majburiyatini oladi.",
					LegalSource: LegalReference{
						Code:        "FK-UZ",
						Article:     "1031-modda",
						NormNature:  "DISPOSITIVE",
						OfficialURL: "https://lex.uz/docs/180552",
						Explanation: "Intellektual mulk obyektlariga bo'lgan huquqlar xizmat shartnomasida to'liq aks ettirilishi lozim.",
					},
					Explanation:     "Intellektual mulk egaligi va konfidensial axborot bo'yicha himoya mexanizmi yo'q.",
					ConfidenceScore: 0.90,
				}
			}
			return nil
		},
	})

	// 8. FORM_MANDATORY_NOTARIAL (Precondition check)
	reNotarial := regexp.MustCompile(`(?i)(ko['‘]chmas\s+mulkni\s+boshqa\s+shaxsga\s+o['‘tkazish]|avtotransport\s+oldi-sotdi|nikoh\s+shartnomasi)`)
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
