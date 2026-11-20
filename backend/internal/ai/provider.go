package ai

import (
	"context"
	"fmt"
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
	RiskCategory      string  `json:"risk_category"` // LEGAL, COMMERCIAL, FORM
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

// NoopRuleOnlyProvider implements Provider deterministically without external LLM calls
type NoopRuleOnlyProvider struct{}

func NewNoopProvider() *NoopRuleOnlyProvider {
	return &NoopRuleOnlyProvider{}
}

func (p *NoopRuleOnlyProvider) Name() string {
	return "NoopRuleOnlyProvider (Baseline)"
}

func (p *NoopRuleOnlyProvider) AnalyzeClause(ctx context.Context, req RedactedClauseRequest) (*DraftSuggestion, *UsageMetrics, error) {
	// Pure deterministic fallback logic
	textLower := strings.ToLower(req.RedactedText)

	var draft *DraftSuggestion
	if strings.Contains(textLower, "istalgan paytda") || strings.Contains(textLower, "ogohlantirmasdan bekor") {
		draft = &DraftSuggestion{
			RuleCode:          "SVC_UNILATERAL_TERMINATION",
			RiskCategory:      "LEGAL",
			Severity:          "RED",
			OriginalQuote:     "istalgan paytda to'lovsiz shartnomani bekor qilishi mumkin",
			SuggestedRevision: "Buyurtmachi Ijrochiga amalda qilingan xarajatlarni to‘lash sharti bilan 30 kun oldin yozma xabardor qilib bekor qilishi mumkin.",
			CitedLawCode:      "FK-UZ",
			CitedArticle:      "707-modda",
			OfficialURL:       "https://lex.uz/docs/180552#181540",
			Explanation:       "FK 707-moddasi bo'yicha bir tomonlama bekor qilish faqat xarajatlarni qoplash sharti bilan amalga oshiriladi.",
			ConfidenceScore:   0.95,
		}
	} else if strings.Contains(textLower, "penya") && (strings.Contains(textLower, "1%") || strings.Contains(textLower, "2%")) {
		draft = &DraftSuggestion{
			RuleCode:          "SVC_PENALTY_FORM_RISK",
			RiskCategory:      "COMMERCIAL",
			Severity:          "YELLOW",
			OriginalQuote:     "har bir kechiktirilgan kun uchun 1% miqdorida penya",
			SuggestedRevision: "Kechiktirilgan har bir kun uchun 0.1% penya (jami kechiktirilgan to‘lovning 10% idan oshmagan holda).",
			CitedLawCode:      "FK-UZ",
			CitedArticle:      "326-modda",
			OfficialURL:       "https://lex.uz/docs/111181#111580",
			Explanation:       "Nomutanosib yuqori penya sud tomonidan kamaytirilishi mumkin (FK 326).",
			ConfidenceScore:   0.90,
		}
	}

	metrics := &UsageMetrics{
		PromptTokens:     len(req.RedactedText) / 4,
		CompletionTokens: 50,
		TotalTokens:      len(req.RedactedText)/4 + 50,
		Duration:         5 * time.Millisecond,
		ProviderName:     p.Name(),
	}

	return draft, metrics, nil
}

// ProviderFactory creates the appropriate provider based on config
func NewProvider(providerName string) Provider {
	switch strings.ToLower(providerName) {
	case "noop", "":
		return NewNoopProvider()
	default:
		// Default to Noop for safe offline zero-dependency operation
		fmt.Printf("[INFO] Initializing default Provider: NoopRuleOnlyProvider\n")
		return NewNoopProvider()
	}
}
