package verification_test

import (
	"context"
	"testing"
	"time"

	"github.com/lexguard/backend/internal/ai"
	"github.com/lexguard/backend/internal/rules"
	"github.com/lexguard/backend/internal/verification"
)

func TestArbiter_AntiHallucinationVectors(t *testing.T) {
	// Without DB, ValidateCitation fails gracefully into closed-world check
	arbiter := verification.NewArbiter(nil)
	ctx := context.Background()
	contractDate := time.Date(2026, 11, 21, 0, 0, 0, 0, time.UTC)

	// Vector 1 & 8 Test: Closed-World Allowlist & Go Rules Priority
	t.Run("Vector1_8_ClosedWorld_GoRulesPriority", func(t *testing.T) {
		clauseNum := "4.2"
		clauseText := "Buyurtmachi istalgan paytda to'lovsiz shartnomani bekor qilishi mumkin."

		ruleFindings := []rules.RuleFinding{
			{
				RuleCode:          "SVC_UNILATERAL_TERMINATION",
				RiskCategory:      rules.CategoryLegal,
				Severity:          rules.SeverityRed,
				ClauseNumber:      clauseNum,
				OriginalQuote:     "istalgan paytda to'lovsiz",
				SuggestedRevision: "Xarajatlarni qoplab bekor qilish",
				LegalSource: rules.LegalReference{
					Code:        "FK-UZ",
					Article:     "707-modda",
					NormNature:  "IMPERATIVE",
					OfficialURL: "https://lex.uz/docs/180552#181540",
				},
				ConfidenceScore: 0.98,
			},
		}

		// LLM hallucinating that everything is GREEN
		llmDraft := &ai.DraftSuggestion{
			RuleCode:          "NO_RISK_FOUND",
			RiskCategory:      "COMMERCIAL",
			Severity:          "GREEN",
			OriginalQuote:     "istalgan paytda to'lovsiz",
			SuggestedRevision: "",
			ConfidenceScore:   0.8,
		}

		verified := arbiter.Arbitrate(ctx, clauseNum, clauseText, contractDate, 0.98, ruleFindings, llmDraft)

		if len(verified) == 0 {
			t.Fatalf("Verified findings bo'sh qaytdi")
		}

		// Must have retained the RED risk from Go Rules (Priority 1)
		foundRed := false
		for _, v := range verified {
			if v.RuleCode == "SVC_UNILATERAL_TERMINATION" && v.Severity == "RED" {
				foundRed = true
			}
		}
		if !foundRed {
			t.Errorf("Go Rules RED prioriteti bajarilmadi!")
		}
	})

	// Vector 3 Test: Substring Grounding (Reject made-up quotes)
	t.Run("Vector3_SubstringGrounding", func(t *testing.T) {
		clauseNum := "5.1"
		clauseText := "To'lov topshirish-qabul qilish dalolatnomasi imzolangach amalga oshiriladi."

		llmDraft := &ai.DraftSuggestion{
			RuleCode:          "SVC_UNILATERAL_TERMINATION",
			RiskCategory:      "LEGAL",
			Severity:          "RED",
			OriginalQuote:     "To'lov hech qachon amalga oshirilmaydi va barcha huquqlar bekor qilinadi", // completely fabricated quote!
			SuggestedRevision: "Tahrir",
			ConfidenceScore:   0.9,
		}

		verified := arbiter.Arbitrate(ctx, clauseNum, clauseText, contractDate, 0.98, nil, llmDraft)

		if len(verified) == 0 {
			t.Fatalf("Verified findings bo'sh qaytdi")
		}

		// Audit vector 3 must be false because quote was not in clause text!
		if verified[0].AuditVectors["3"] != false {
			t.Errorf("Soxta quote uchun Vector 3 false bo'lishi kerak edi")
		}
		if verified[0].VerificationStatus != verification.StatusReviewRequired {
			t.Errorf("Soxta quote REVIEW_REQUIRED ga tushishi kerak edi, lekin: %s", verified[0].VerificationStatus)
		}
	})

	// Vector 9 Test: Low Parse Confidence
	t.Run("Vector9_LowParseConfidence", func(t *testing.T) {
		clauseNum := "1.1"
		clauseText := "Xizmatlar ko'rsatish shartnomasi"

		ruleFindings := []rules.RuleFinding{
			{
				RuleCode:          "SVC_MISSING_SUBJECT_SCOPE",
				RiskCategory:      rules.CategoryLegal,
				Severity:          rules.SeverityRed,
				ClauseNumber:      clauseNum,
				OriginalQuote:     "Xizmatlar",
				SuggestedRevision: "Tahrir",
				ConfidenceScore:   0.9,
			},
		}

		// Confidence is 0.60 (< 0.85)
		verified := arbiter.Arbitrate(ctx, clauseNum, clauseText, contractDate, 0.60, ruleFindings, nil)

		if len(verified) == 0 {
			t.Fatalf("Verified findings bo'sh qaytdi")
		}
		if verified[0].VerificationStatus != verification.StatusReviewRequired {
			t.Errorf("Sifatsiz skan / past confidence (0.60) holatida REVIEW_REQUIRED bo'lishi kerak edi, lekin: %s", verified[0].VerificationStatus)
		}
		if verified[0].AuditVectors["9"] != false {
			t.Errorf("Vector 9 false bo'lishi kerak edi")
		}
	})
}
