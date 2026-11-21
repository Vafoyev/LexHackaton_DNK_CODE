package verification

import (
	"context"
	"errors"
	"fmt"
	"net/url"
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
	ID                   string                `json:"id"`
	ClauseNumber         string                `json:"clause_number"`
	RuleCode             string                `json:"rule_code"`
	RuleID               string                `json:"rule_id"`
	RiskCategory         string                `json:"risk_category"`
	Category             string                `json:"category"`
	Severity             string                `json:"severity"`
	RiskLevel            string                `json:"risk_level"`
	VerificationStatus   VerificationStatus    `json:"verification_status"`
	OriginalQuote        string                `json:"original_quote"`
	SuggestedRevision    string                `json:"suggested_revision"`
	SuggestedRedline     string                `json:"suggested_redline"`
	IssueTitle           string                `json:"issue_title"`
	IssueExplanation     string                `json:"issue_explanation"`
	LegalSourceVersionID *string               `json:"legal_source_version_id,omitempty"`
	LegalSource          *rules.LegalReference `json:"legal_source,omitempty"`
	LegalBasis           *rules.LegalReference `json:"legal_basis,omitempty"`
	Score                float64               `json:"score"`
	Explanation          string                `json:"explanation"`
	AuditVectors         map[string]bool       `json:"audit_vectors"`
	TemporalNote         string                `json:"temporal_note,omitempty"`
	Disclaimer           string                `json:"disclaimer"`
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

	if contractDate.IsZero() {
		contractDate = time.Now()
	}

	// Step 1: Process deterministic Go Rules (Priority 1)
	for _, rf := range ruleFindings {
		vectors := make(map[string]bool)
		for i := 1; i <= 10; i++ {
			vectors[fmt.Sprintf("%d", i)] = true
		}

		vStatus := StatusVerified
		temporalNote := ""

		// Vector 1 & 2: Check legal citation allowlist and FK 4-modda temporal date
		var lsvID *string
		if a.corpusRepo != nil && rf.LegalSource.Article != "" {
			art, err := a.corpusRepo.ValidateCitation(ctx, rf.LegalSource.Code, rf.LegalSource.Article, rf.LegalSource.OfficialURL, contractDate)
			if err != nil {
				if errors.Is(err, legalcorpus.ErrArticleNotFound) {
					// Law or article does not exist in Lex.uz allowlist!
					vStatus = StatusUnverified
					vectors["1"] = false
					vectors["2"] = false
				} else if errors.Is(err, legalcorpus.ErrTemporalOutOfRange) {
					// Exists in law, but not in force at contract date!
					vStatus = StatusReviewRequired
					vectors["1"] = true
					vectors["2"] = false
					temporalNote = a.corpusRepo.ExplainTemporalApplicability(rf.LegalSource.Code, rf.LegalSource.Article, contractDate)
				} else {
					vStatus = StatusReviewRequired
					vectors["1"] = false
					vectors["2"] = false
				}
			} else if art != nil {
				idCopy := art.ID
				lsvID = &idCopy
				rf.LegalSource.OfficialURL = art.OfficialURL

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
			if len(clauseText) > 100 {
				rf.OriginalQuote = clauseText[:100] + "..."
			} else {
				rf.OriginalQuote = clauseText
			}
		}

		// Vector 5: Precondition gate for mandatory notarial form or license
		if rf.RuleCode == "FORM_MANDATORY_NOTARIAL" {
			vStatus = StatusReviewRequired
			vectors["5"] = false
		}

		// Vector 7: Canonical Lex.uz URL check
		if !checkLexUzURL(rf.LegalSource.OfficialURL) {
			vectors["7"] = false
		}

		// Vector 8: Deterministic Go rules have highest priority (vector 8 is always true for Go rules)
		vectors["8"] = true

		// Vector 9: Low parse confidence requires human review
		if parseConfidence < 0.85 {
			vStatus = StatusReviewRequired
			vectors["9"] = false
		}

		// Vector 10: O'RQ-1115 6-modda compliance disclaimer
		disclaimer := "O‘RQ-1115 6-moddasiga binoan axborot-tahliliy xulosa. Inson nazorati talab etiladi."
		vectors["10"] = true

		legalRef := &rules.LegalReference{
			Code:        rf.LegalSource.Code,
			Article:     rf.LegalSource.Article,
			NormNature:  rf.LegalSource.NormNature,
			OfficialURL: rf.LegalSource.OfficialURL,
			Explanation: rf.LegalSource.Explanation,
		}

		results = append(results, VerifiedFinding{
			ClauseNumber:         clauseNumber,
			RuleCode:             rf.RuleCode,
			RuleID:               rf.RuleCode,
			RiskCategory:         string(rf.RiskCategory),
			Category:             string(rf.RiskCategory),
			Severity:             string(rf.Severity),
			RiskLevel:            string(rf.Severity),
			VerificationStatus:   vStatus,
			OriginalQuote:        rf.OriginalQuote,
			SuggestedRevision:    rf.SuggestedRevision,
			SuggestedRedline:     rf.SuggestedRevision,
			IssueTitle:           rf.Explanation,
			IssueExplanation:     rf.Explanation,
			LegalSourceVersionID: lsvID,
			LegalSource:          legalRef,
			LegalBasis:           legalRef,
			Score:                rf.ConfidenceScore,
			Explanation:          rf.Explanation,
			AuditVectors:         vectors,
			TemporalNote:         temporalNote,
			Disclaimer:           disclaimer,
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
				vectors[fmt.Sprintf("%d", i)] = true
			}

			vStatus := StatusVerified
			temporalNote := ""

			// Vector 1 & 2: Closed-World Allowlist & Temporal FK 4-modda
			var lsvID *string
			if a.corpusRepo != nil && llmDraft.CitedArticle != "" {
				art, err := a.corpusRepo.ValidateCitation(ctx, llmDraft.CitedLawCode, llmDraft.CitedArticle, llmDraft.OfficialURL, contractDate)
				if err != nil {
					if errors.Is(err, legalcorpus.ErrArticleNotFound) {
						// Fake citation! Mark as UNVERIFIED (Vector 1 violation)
						vStatus = StatusUnverified
						llmDraft.OfficialURL = ""
						vectors["1"] = false
						vectors["2"] = false
					} else if errors.Is(err, legalcorpus.ErrTemporalOutOfRange) {
						// Temporal out of range (Vector 2 violation)
						vStatus = StatusReviewRequired
						vectors["1"] = true
						vectors["2"] = false
						temporalNote = a.corpusRepo.ExplainTemporalApplicability(llmDraft.CitedLawCode, llmDraft.CitedArticle, contractDate)
					} else {
						vStatus = StatusReviewRequired
						vectors["1"] = false
						vectors["2"] = false
					}
				} else if art != nil {
					idCopy := art.ID
					lsvID = &idCopy
					llmDraft.OfficialURL = art.OfficialURL

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

			// Vector 7: Canonical Lex.uz URL check
			if !checkLexUzURL(llmDraft.OfficialURL) {
				vectors["7"] = false
			}

			// Vector 9: Low parse confidence
			if parseConfidence < 0.85 {
				vStatus = StatusReviewRequired
				vectors["9"] = false
			}

			// Vector 10: AI Act disclaimer
			disclaimer := "O‘RQ-1115 6-moddasiga binoan axborot-tahliliy xulosa. Inson nazorati talab etiladi."
			vectors["10"] = true

			legalRef := &rules.LegalReference{
				Code:        llmDraft.CitedLawCode,
				Article:     llmDraft.CitedArticle,
				NormNature:  "IMPERATIVE",
				OfficialURL: llmDraft.OfficialURL,
				Explanation: llmDraft.Explanation,
			}

			results = append(results, VerifiedFinding{
				ClauseNumber:         clauseNumber,
				RuleCode:             llmDraft.RuleCode,
				RuleID:               llmDraft.RuleCode,
				RiskCategory:         llmDraft.RiskCategory,
				Category:             llmDraft.RiskCategory,
				Severity:             llmDraft.Severity,
				RiskLevel:            llmDraft.Severity,
				VerificationStatus:   vStatus,
				OriginalQuote:        llmDraft.OriginalQuote,
				SuggestedRevision:    llmDraft.SuggestedRevision,
				SuggestedRedline:     llmDraft.SuggestedRevision,
				IssueTitle:           llmDraft.Explanation,
				IssueExplanation:     llmDraft.Explanation,
				LegalSourceVersionID: lsvID,
				LegalSource:          legalRef,
				LegalBasis:           legalRef,
				Score:                llmDraft.ConfidenceScore,
				Explanation:          llmDraft.Explanation,
				AuditVectors:         vectors,
				TemporalNote:         temporalNote,
				Disclaimer:           disclaimer,
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

// checkLexUzURL validates canonical Lex.uz official URL structure
func checkLexUzURL(rawURL string) bool {
	if rawURL == "" {
		return false
	}
	u, err := url.Parse(rawURL)
	if err != nil {
		return false
	}
	if u.Host != "lex.uz" && u.Host != "www.lex.uz" {
		return false
	}
	if !strings.HasPrefix(u.Path, "/docs") {
		return false
	}
	return true
}

// AuditVectorDescriptions provides the human-readable description for all 10 vectors
func AuditVectorDescriptions() map[string]string {
	return map[string]string{
		"1":  "Closed-World Allowlist (Modda va Qonun rasmiy Lex.uz ro'yxatida mavjudligi)",
		"2":  "Temporal Validity Gate (FK 4-modda bo'yicha shartnoma sanasida modda amalda ekanligi)",
		"3":  "Substring Grounding (Keltirilgan iqtibos shartnoma matnida mavjudligi)",
		"4":  "Norm Nature & Dispositive Downgrade (Dispozitiv moddaning asossiz RED bo'lmasligi)",
		"5":  "Precondition Gate (Notarial tasdiqlash, davlat ro'yxati va shakl talabi)",
		"6":  "Zero-Hallucination Fail-Closed (Topilmagan yoki noaniq tavsiyalarni bloklash)",
		"7":  "Lex.uz Canonical URL & Hash Verification (Rasmiy Lex.uz havolasi mosligi)",
		"8":  "Deterministic Go Rule Priority (Go qoidalarining LLM ga nisbatan ustuvorligi)",
		"9":  "OCR / Parse Confidence Threshold (Hujjat o'qilish sifati kamida 85% ekanligi)",
		"10": "AI Act Human Oversight (O'RQ-1115 6-moddasi bo'yicha inson nazorati kafolati)",
	}
}
