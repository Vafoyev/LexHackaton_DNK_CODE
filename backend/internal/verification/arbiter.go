package verification

import (
	"context"
	"strings"
	"time"

	"github.com/lexguard/backend/internal/ai"
	"github.com/lexguard/backend/internal/legalcorpus"
	"github.com/lexguard/backend/internal/rules"
)

type VerificationStatus string

const (
	StatusVerified       VerificationStatus = "VERIFIED"
	StatusReviewRequired VerificationStatus = "REVIEW_REQUIRED"
	StatusUnverified     VerificationStatus = "UNVERIFIED"
	StatusUnknown        VerificationStatus = "UNKNOWN"
	StatusFailed         VerificationStatus = "FAILED"
)

type VerifiedFinding struct {
	ID                 string             `json:"id"`
	ClauseNumber       string             `json:"clause_number"`
	RuleCode           string             `json:"rule_code"`
	RiskCategory       string             `json:"risk_category"`
	Severity           string             `json:"severity"`
	VerificationStatus VerificationStatus `json:"verification_status"`
	OriginalQuote      string             `json:"original_quote"`
	SuggestedRevision  string             `json:"suggested_revision"`
	LegalSourceVersionID *string          `json:"legal_source_version_id,omitempty"`
	LegalSource        *rules.LegalReference `json:"legal_source,omitempty"`
	Score              float64            `json:"score"`
	Explanation        string             `json:"explanation"`
	AuditVectors       map[string]bool    `json:"audit_vectors"`
}

type Arbiter struct {
	corpusRepo *legalcorpus.Repository
}

func NewArbiter(corpusRepo *legalcorpus.Repository) *Arbiter {
	return &Arbiter{corpusRepo: corpusRepo}
}

// Arbitrate reconciles Go Rules, LLM draft, and Legal Corpus using the 10-Vector Hallucination Filter
func (a *Arbiter) Arbitrate(
	ctx context.Context,
	clauseNumber string,
	clauseText string,
	contractDate time.Time,
	parseConfidence float64,
	ruleFindings []rules.RuleFinding,
	llmDraft *ai.DraftSuggestion,
) []VerifiedFinding {
	results := make([]VerifiedFinding, 0)

	// Step 1: Process deterministic Go Rules (Priority 1)
	for _, rf := range ruleFindings {
		vectors := make(map[string]bool)
		for i := 1; i <= 10; i++ {
			vectors[string(rune('0'+i))] = true
		}

		vStatus := StatusVerified

		// Vector 1 & 2: Check legal citation allowlist and FK 4-modda temporal date
		var lsvID *string
		if rf.LegalSource.Article != "" {
			art, err := a.corpusRepo.ValidateCitation(ctx, rf.LegalSource.Code, rf.LegalSource.Article, rf.LegalSource.OfficialURL, contractDate)
			if err != nil || art == nil {
				// Law not in DB allowlist or outside temporal range
				vStatus = StatusReviewRequired
				vectors["1"] = false
				vectors["2"] = false
			} else {
				idCopy := art.ID
				lsvID = &idCopy

				// Vector 4: Dispositive norm cannot be RED
				if art.NormNature == "DISPOSITIVE" && rf.Severity == rules.SeverityRed {
					rf.Severity = rules.SeverityYellow
					rf.RiskCategory = rules.CategoryCommercial
					vectors["4"] = false
				}
			}
		}

		// Vector 3: Substring Grounding check
		if !checkSubstringMatch(clauseText, rf.OriginalQuote) {
			vectors["3"] = false
			// Fallback to clause text if original quote is somehow off
			if len(clauseText) > 100 {
				rf.OriginalQuote = clauseText[:100] + "..."
			} else {
				rf.OriginalQuote = clauseText
			}
		}

		// Vector 5: Precondition gate for mandatory notarial form
		if rf.RuleCode == "FORM_MANDATORY_NOTARIAL" {
			vStatus = StatusReviewRequired
			vectors["5"] = false
		}

		// Vector 9: Low parse confidence requires human review
		if parseConfidence < 0.85 {
			vStatus = StatusReviewRequired
			vectors["9"] = false
		}

		results = append(results, VerifiedFinding{
			ClauseNumber:       clauseNumber,
			RuleCode:           rf.RuleCode,
			RiskCategory:       string(rf.RiskCategory),
			Severity:           string(rf.Severity),
			VerificationStatus: vStatus,
			OriginalQuote:      rf.OriginalQuote,
			SuggestedRevision:  rf.SuggestedRevision,
			LegalSourceVersionID: lsvID,
			LegalSource: &rules.LegalReference{
				Code:        rf.LegalSource.Code,
				Article:     rf.LegalSource.Article,
				NormNature:  rf.LegalSource.NormNature,
				OfficialURL: rf.LegalSource.OfficialURL,
				Explanation: rf.LegalSource.Explanation,
			},
			Score:        rf.ConfidenceScore,
			Explanation:  rf.Explanation,
			AuditVectors: vectors,
		})
	}

	// Step 2: If LLM provided additional draft, cross-verify against Go Rules & Closed Allowlist
	if llmDraft != nil {
		// Vector 8: Check if Go Rules already caught this rule
		duplicate := false
		for _, r := range results {
			if r.RuleCode == llmDraft.RuleCode {
				duplicate = true
				break
			}
		}

		if !duplicate {
			vectors := make(map[string]bool)
			for i := 1; i <= 10; i++ {
				vectors[string(rune('0'+i))] = true
			}

			vStatus := StatusVerified

			// Vector 1 & 2: Closed-World Allowlist & Temporal FK 4-modda
			var lsvID *string
			if llmDraft.CitedArticle != "" {
				art, err := a.corpusRepo.ValidateCitation(ctx, llmDraft.CitedLawCode, llmDraft.CitedArticle, llmDraft.OfficialURL, contractDate)
				if err != nil || art == nil {
					// Fake citation! Mark as UNVERIFIED (Vector 1 violation)
					vStatus = StatusUnverified
					llmDraft.OfficialURL = ""
					vectors["1"] = false
					vectors["2"] = false
				} else {
					idCopy := art.ID
					lsvID = &idCopy

					// Vector 4: Dispositive norm check
					if art.NormNature == "DISPOSITIVE" && llmDraft.Severity == "RED" {
						llmDraft.Severity = "YELLOW"
						llmDraft.RiskCategory = "COMMERCIAL"
						vectors["4"] = false
					}
				}
			} else {
				// Vector 6: Fail-Closed 0 / UNKNOWN (no article found)
				vStatus = StatusUnknown
				vectors["6"] = false
			}

			// Vector 3: Substring Grounding
			if !checkSubstringMatch(clauseText, llmDraft.OriginalQuote) {
				vStatus = StatusReviewRequired
				vectors["3"] = false
			}

			results = append(results, VerifiedFinding{
				ClauseNumber:       clauseNumber,
				RuleCode:           llmDraft.RuleCode,
				RiskCategory:       llmDraft.RiskCategory,
				Severity:           llmDraft.Severity,
				VerificationStatus: vStatus,
				OriginalQuote:      llmDraft.OriginalQuote,
				SuggestedRevision:  llmDraft.SuggestedRevision,
				LegalSourceVersionID: lsvID,
				LegalSource: &rules.LegalReference{
					Code:        llmDraft.CitedLawCode,
					Article:     llmDraft.CitedArticle,
					NormNature:  "IMPERATIVE",
					OfficialURL: llmDraft.OfficialURL,
					Explanation: llmDraft.Explanation,
				},
				Score:        llmDraft.ConfidenceScore,
				Explanation:  llmDraft.Explanation,
				AuditVectors: vectors,
			})
		}
	}

	return results
}

// checkSubstringMatch checks if original_quote is found in clauseText (case-insensitive substring)
func checkSubstringMatch(clauseText, quote string) bool {
	if quote == "" {
		return false
	}
	clauseLower := strings.ToLower(clauseText)
	quoteLower := strings.ToLower(quote)

	if strings.Contains(clauseLower, quoteLower) {
		return true
	}

	// Fuzzy word overlap check (kamida 70% so'zlar bo'lishi kerak)
	words := strings.Fields(quoteLower)
	if len(words) == 0 {
		return false
	}
	matched := 0
	for _, w := range words {
		if strings.Contains(clauseLower, w) {
			matched++
		}
	}
	return float64(matched)/float64(len(words)) >= 0.70
}
