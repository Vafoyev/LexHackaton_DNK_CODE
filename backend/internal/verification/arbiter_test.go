package verification_test

import (
	"context"
	"testing"
	"time"

	"github.com/lexguard/backend/internal/ai"
	"github.com/lexguard/backend/internal/legalcorpus"
	"github.com/lexguard/backend/internal/rules"
	"github.com/lexguard/backend/internal/verification"
)

func TestArbiter_AntiHallucinationVectors(t *testing.T) {
	repo := legalcorpus.NewRepository(nil)
	arbiter := verification.NewArbiter(repo)
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
				if !v.AuditVectors["1"] {
					t.Errorf("Vector 1 true bo'lishi kerak edi (FK 707 mavjud)")
				}
				if !v.AuditVectors["8"] {
					t.Errorf("Vector 8 true bo'lishi kerak edi (Go rules priority)")
				}
				if !v.AuditVectors["10"] {
					t.Errorf("Vector 10 true bo'lishi kerak edi (O'RQ-1115 disclaimer)")
				}
			}
		}
		if !foundRed {
			t.Errorf("Go Rules RED prioriteti bajarilmadi!")
		}
	})

	// Vector 2 Test: Temporal Validity Gate
	t.Run("Vector2_TemporalValidityGate", func(t *testing.T) {
		clauseNum := "2.1"
		clauseText := "Xodimga 6 oy sinov muddati belgilanadi."
		// Shartnoma 2022-yilda tuzilgan
		pastContractDate := time.Date(2022, 5, 1, 0, 0, 0, 0, time.UTC)

		// Model Yangi Mehnat kodeksini (2023-yilgi) ko'rsatmoqda, lekin 2022-yilda u amalda emas edi!
		llmDraft := &ai.DraftSuggestion{
			RuleCode:          "LABOR_PROBATION_EXCESSIVE",
			RiskCategory:      "LABOR",
			Severity:          "RED",
			OriginalQuote:     "6 oy sinov muddati",
			SuggestedRevision: "3 oylik sinov",
			CitedLawCode:      "MK-2022",
			CitedArticle:      "130-modda",
			OfficialURL:       "https://lex.uz/docs/6257288#6258020",
			Explanation:       "Sinov muddati oshirilgan",
			ConfidenceScore:   0.95,
		}

		verified := arbiter.Arbitrate(ctx, clauseNum, clauseText, pastContractDate, 0.95, nil, llmDraft)
		if len(verified) == 0 {
			t.Fatalf("Verified findings bo'sh qaytdi")
		}

		f := verified[0]
		// Vector 2 must fail because MK-2022 was not in force in May 2022!
		if f.AuditVectors["2"] != false {
			t.Errorf("2022-yilgi shartnoma uchun MK-2022 bo'yicha Vector 2 false bo'lishi kerak edi")
		}
		if f.VerificationStatus != verification.StatusReviewRequired {
			t.Errorf("Temporal nomutanosiblik REVIEW_REQUIRED ga tushishi kerak edi, lekin: %s", f.VerificationStatus)
		}
		if f.TemporalNote == "" {
			t.Errorf("Temporal izoh (TemporalNote) bo'sh bo'lmasligi kerak edi")
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
			CitedLawCode:      "FK-UZ",
			CitedArticle:      "707-modda",
			OfficialURL:       "https://lex.uz/docs/180552#181540",
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

	// Vector 4 Test: Dispositive Norm Downgrade
	t.Run("Vector4_DispositiveDowngrade", func(t *testing.T) {
		clauseNum := "7.1"
		clauseText := "Kechiktirilgan har bir kun uchun 0.5% penya to'lanadi."

		// FK 326 is DISPOSITIVE, so model trying to make it RED must be downgraded to YELLOW
		llmDraft := &ai.DraftSuggestion{
			RuleCode:          "SVC_PENALTY_FORM_RISK",
			RiskCategory:      "LEGAL",
			Severity:          "RED", // Wrongly marked as RED
			OriginalQuote:     "0.5% penya",
			SuggestedRevision: "0.1% penya",
			CitedLawCode:      "FK-UZ",
			CitedArticle:      "326-modda",
			OfficialURL:       "https://lex.uz/docs/111181#111580",
			Explanation:       "Penya kamaytirish",
			ConfidenceScore:   0.95,
		}

		verified := arbiter.Arbitrate(ctx, clauseNum, clauseText, contractDate, 0.95, nil, llmDraft)
		if len(verified) == 0 {
			t.Fatalf("Verified findings bo'sh qaytdi")
		}

		f := verified[0]
		if f.Severity != "YELLOW" {
			t.Errorf("Dispozitiv norma RED dan YELLOW ga pasaytirilishi kerak edi, lekin: %s", f.Severity)
		}
		if f.AuditVectors["4"] != false {
			t.Errorf("Vector 4 false bo'lishi kerak edi (qayta muvozanatlandi)")
		}
	})

	// Vector 6 & 7 Test: Zero-Hallucination Fallback & Canonical URL
	t.Run("Vector6_7_ZeroHallucination_CanonicalURL", func(t *testing.T) {
		clauseNum := "8.1"
		clauseText := "Shartnomaning maxfiy bandi."

		// Fabricated law citation
		llmDraft := &ai.DraftSuggestion{
			RuleCode:          "CUSTOM_RISK",
			RiskCategory:      "LEGAL",
			Severity:          "RED",
			OriginalQuote:     "maxfiy bandi",
			SuggestedRevision: "tahrir",
			CitedLawCode:      "FAKE-LAW",
			CitedArticle:      "9999-modda",
			OfficialURL:       "https://fakeurl.com/something", // not lex.uz!
			ConfidenceScore:   0.8,
		}

		verified := arbiter.Arbitrate(ctx, clauseNum, clauseText, contractDate, 0.95, nil, llmDraft)
		if len(verified) == 0 {
			t.Fatalf("Verified findings bo'sh qaytdi")
		}

		f := verified[0]
		if f.VerificationStatus != verification.StatusUnverified {
			t.Errorf("Mavjud bo'lmagan qonun UNVERIFIED bo'lishi kerak edi, lekin: %s", f.VerificationStatus)
		}
		if f.AuditVectors["1"] != false {
			t.Errorf("Vector 1 false bo'lishi kerak edi")
		}
		if f.AuditVectors["7"] != false {
			t.Errorf("Soxta URL uchun Vector 7 false bo'lishi kerak edi")
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
				LegalSource: rules.LegalReference{
					Code:        "FK-UZ",
					Article:     "364-modda",
					NormNature:  "IMPERATIVE",
					OfficialURL: "https://lex.uz/docs/111181#111650",
				},
				ConfidenceScore: 0.9,
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
