package ai

import (
	"context"
	"strings"
	"time"
)

type RedactedClauseRequest struct {
	ClauseNumber      string   `json:"clause_number"`
	RedactedText      string   `json:"redacted_text"`
	ContractDate      string   `json:"contract_date"`
	DocType           string   `json:"doc_type"`
	CandidateArticles []string `json:"candidate_articles"`
}

type DraftSuggestion struct {
	RuleCode          string  `json:"rule_code"`
	RiskCategory      string  `json:"risk_category"` // LEGAL, COMMERCIAL, FORM, LABOR, PRIVACY, AI
	Severity          string  `json:"severity"`      // RED, YELLOW, GREEN
	OriginalQuote     string  `json:"original_quote"`
	SuggestedRevision string  `json:"suggested_revision"`
	CitedLawCode      string  `json:"cited_law_code"`
	CitedArticle      string  `json:"cited_article"`
	OfficialURL       string  `json:"official_url"`
	Explanation       string  `json:"explanation"`
	ConfidenceScore   float64 `json:"confidence_score"`
}

type UsageMetrics struct {
	PromptTokens     int           `json:"prompt_tokens"`
	CompletionTokens int           `json:"completion_tokens"`
	TotalTokens      int           `json:"total_tokens"`
	Duration         time.Duration `json:"duration"`
	ProviderName     string        `json:"provider_name"`
}

type Provider interface {
	AnalyzeClause(ctx context.Context, req RedactedClauseRequest) (*DraftSuggestion, *UsageMetrics, error)
	Name() string
}

// TemporalLegalAIProvider implements Provider with temporal intelligence and closed-world law grounding
type TemporalLegalAIProvider struct {
	name string
}

func NewTemporalLegalAIProvider() *TemporalLegalAIProvider {
	return &TemporalLegalAIProvider{
		name: "LexGuard-LegalAI-Temporal (Deterministic Engine)",
	}
}

func (p *TemporalLegalAIProvider) Name() string {
	return p.name
}

func (p *TemporalLegalAIProvider) AnalyzeClause(ctx context.Context, req RedactedClauseRequest) (*DraftSuggestion, *UsageMetrics, error) {
	textLower := strings.ToLower(req.RedactedText)

	// Parse contract date for temporal routing
	cDate, err := time.Parse("2006-01-02", req.ContractDate)
	if err != nil {
		cDate = time.Now()
	}

	var draft *DraftSuggestion

	// 1. Unilateral Termination (FK 707)
	if strings.Contains(textLower, "istalgan paytda") || strings.Contains(textLower, "ogohlantirmasdan bekor") || strings.Contains(textLower, "bir tomonlama bosh tortish") {
		draft = &DraftSuggestion{
			RuleCode:          "SVC_UNILATERAL_TERMINATION",
			RiskCategory:      "LEGAL",
			Severity:          "RED",
			OriginalQuote:     extractQuote(req.RedactedText, "istalgan paytda"),
			SuggestedRevision: "Buyurtmachi Ijrochiga amalda qilingan xarajatlarni to‘lash sharti bilan kamida 30 kun oldin yozma xabardor qilib shartnomani bekor qilishi mumkin.",
			CitedLawCode:      "FK-UZ",
			CitedArticle:      "707-modda",
			OfficialURL:       "https://lex.uz/docs/180552#181540",
			Explanation:       "FK 707-moddasi bo'yicha buyurtmachi faqat qilingan xarajatlarni to'lash sharti bilan bir tomonlama bekor qilishga haqli.",
			ConfidenceScore:   0.98,
		}
	} else if strings.Contains(textLower, "penya") && (strings.Contains(textLower, "1%") || strings.Contains(textLower, "2%") || strings.Contains(textLower, "0.5%")) {
		// 2. High Penalty (FK 326 - Dispositive -> YELLOW)
		draft = &DraftSuggestion{
			RuleCode:          "SVC_PENALTY_FORM_RISK",
			RiskCategory:      "COMMERCIAL",
			Severity:          "YELLOW",
			OriginalQuote:     extractQuote(req.RedactedText, "penya"),
			SuggestedRevision: "Kechiktirilgan har bir kun uchun 0.1% penya (jami kechiktirilgan to‘lovning 10% idan oshmagan holda).",
			CitedLawCode:      "FK-UZ",
			CitedArticle:      "326-modda",
			OfficialURL:       "https://lex.uz/docs/111181#111580",
			Explanation:       "Nomutanosib yuqori penya sud tomonidan kamaytirilishi mumkin (FK 326).",
			ConfidenceScore:   0.95,
		}
	} else if strings.Contains(textLower, "sinov muddati") || strings.Contains(textLower, "sinov") && strings.Contains(textLower, "oy") {
		// 3. Excessive Probation: Temporal routing between MK-1995 and MK-2022!
		cutoff := time.Date(2023, 4, 30, 0, 0, 0, 0, time.UTC)
		if cDate.Before(cutoff) {
			draft = &DraftSuggestion{
				RuleCode:          "LABOR_PROBATION_EXCESSIVE",
				RiskCategory:      "LABOR",
				Severity:          "RED",
				OriginalQuote:     extractQuote(req.RedactedText, "sinov"),
				SuggestedRevision: "Xodimga 3 oydan oshmagan dastlabki sinov muddati belgilanadi.",
				CitedLawCode:      "MK-1995",
				CitedArticle:      "84-modda",
				OfficialURL:       "https://lex.uz/docs/142859#143000",
				Explanation:       "1995-yilgi Mehnat kodeksi 84-moddasiga ko'ra dastlabki sinov 3 oydan oshmasligi kerak.",
				ConfidenceScore:   0.96,
			}
		} else {
			draft = &DraftSuggestion{
				RuleCode:          "LABOR_PROBATION_EXCESSIVE",
				RiskCategory:      "LABOR",
				Severity:          "RED",
				OriginalQuote:     extractQuote(req.RedactedText, "sinov"),
				SuggestedRevision: "Xodimga 3 oydan (rahbarlar uchun 6 oydan) oshmagan dastlabki sinov muddati belgilanadi.",
				CitedLawCode:      "MK-2022",
				CitedArticle:      "130-modda",
				OfficialURL:       "https://lex.uz/docs/6257288#6258020",
				Explanation:       "Yangi Mehnat kodeksi 130-moddasiga ko'ra sinov muddati 3 oydan oshishi mumkin emas.",
				ConfidenceScore:   0.98,
			}
		}
	} else if strings.Contains(textLower, "raqobatchi") || strings.Contains(textLower, "ishga kirmaslik") || strings.Contains(textLower, "no-compete") {
		// 4. Illegal No-Compete in Labor (MK-2022 404 / 5)
		draft = &DraftSuggestion{
			RuleCode:          "LABOR_NO_COMPETE_ILLEGAL",
			RiskCategory:      "LABOR",
			Severity:          "RED",
			OriginalQuote:     extractQuote(req.RedactedText, "raqobatchi"),
			SuggestedRevision: "Xodim korxona maxfiy ma'lumotlarini saqlash majburiyatini oladi. Biroq erkin mehnat qilish huquqi cheklanmaydi.",
			CitedLawCode:      "MK-2022",
			CitedArticle:      "404-modda",
			OfficialURL:       "https://lex.uz/docs/6257288#6259450",
			Explanation:       "Mehnat kodeksi 404-moddasiga ko'ra ishdan bo'shagandan so'ng mehnat faoliyatini cheklovchi bitimlar o'z-o'zidan haqiqiy emas.",
			ConfidenceScore:   0.99,
		}
	} else if strings.Contains(textLower, "chet el server") || strings.Contains(textLower, "serverlar o'zbekiston tashqarisida") || strings.Contains(textLower, "serverlar o‘zbekiston tashqarisida") {
		// 5. Data Localization Breach (O'RQ-547 27-1)
		locCutoff := time.Date(2021, 4, 15, 0, 0, 0, 0, time.UTC)
		if cDate.After(locCutoff) {
			draft = &DraftSuggestion{
				RuleCode:          "DATA_LOCALIZATION_BREACH",
				RiskCategory:      "PRIVACY",
				Severity:          "RED",
				OriginalQuote:     extractQuote(req.RedactedText, "server"),
				SuggestedRevision: "O‘zbekiston fuqarolarining shaxsiy ma’lumotlari O‘zbekiston hududida joylashgan texnik vositalarda saqlanishi shart.",
				CitedLawCode:      "ORQ-547",
				CitedArticle:      "27-1-modda",
				OfficialURL:       "https://lex.uz/docs/4396428#5270100",
				Explanation:       "O‘RQ-547 27-1-moddasi fuqarolar shaxsiy ma'lumotlarini mamlakat ichidagi serverlarda saqlashni talab qiladi.",
				ConfidenceScore:   0.99,
			}
		}
	} else if strings.Contains(textLower, "aqsh dollarida") || strings.Contains(textLower, "usd") || strings.Contains(textLower, "evroda") {
		// 6. Currency Settlement (FK 245)
		draft = &DraftSuggestion{
			RuleCode:          "CURRENCY_SETTLEMENT_ILLEGAL",
			RiskCategory:      "LEGAL",
			Severity:          "RED",
			OriginalQuote:     extractQuote(req.RedactedText, "dollari"),
			SuggestedRevision: "Barcha to‘lovlar O‘zbekiston milliy valyutasi — so‘mda Markaziy bank kursi bo‘yicha amalga oshiriladi.",
			CitedLawCode:      "FK-UZ",
			CitedArticle:      "245-modda",
			OfficialURL:       "https://lex.uz/docs/111181#111430",
			Explanation:       "FK 245-moddasiga binoan O'zbekiston hududidagi pul majburiyatlari so'mda to'lanishi shart.",
			ConfidenceScore:   0.98,
		}
	}

	promptLen := len(req.RedactedText) / 4
	if promptLen < 15 {
		promptLen = 15
	}
	compLen := 60
	if draft == nil {
		compLen = 15
	}

	metrics := &UsageMetrics{
		PromptTokens:     promptLen,
		CompletionTokens: compLen,
		TotalTokens:      promptLen + compLen,
		Duration:         6 * time.Millisecond,
		ProviderName:     p.Name(),
	}

	return draft, metrics, nil
}

func extractQuote(text, keyword string) string {
	idx := strings.Index(strings.ToLower(text), strings.ToLower(keyword))
	if idx == -1 {
		if len(text) > 80 {
			return text[:80] + "..."
		}
		return text
	}
	start := idx - 20
	if start < 0 {
		start = 0
	}
	end := idx + len(keyword) + 30
	if end > len(text) {
		end = len(text)
	}
	return strings.TrimSpace(text[start:end])
}

// ProviderFactory creates the appropriate provider based on config
func NewProvider(providerName string) Provider {
	switch strings.ToLower(providerName) {
	case "noop":
		return &NoopRuleOnlyProvider{}
	case "engine", "ai-engine", "remote", "grpc", "http":
		return NewEngineClient()
	default:
		return NewTemporalLegalAIProvider()
	}
}

// NoopRuleOnlyProvider baseline fallback
type NoopRuleOnlyProvider struct{}

func (p *NoopRuleOnlyProvider) Name() string {
	return "NoopRuleOnlyProvider (Baseline)"
}

func (p *NoopRuleOnlyProvider) AnalyzeClause(ctx context.Context, req RedactedClauseRequest) (*DraftSuggestion, *UsageMetrics, error) {
	return nil, &UsageMetrics{Duration: 1 * time.Millisecond, ProviderName: p.Name()}, nil
}
