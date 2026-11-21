package rules_test

import (
	"testing"

	"github.com/lexguard/backend/internal/rules"
)

func TestRulesEngine_B2BRules(t *testing.T) {
	engine := rules.NewRulesEngine()

	// 1. Test SVC_UNILATERAL_TERMINATION
	t.Run("SVC_UNILATERAL_TERMINATION", func(t *testing.T) {
		clauseText := "Buyurtmachi istalgan paytda to'lovsiz shartnomani bekor qilishi mumkin."
		findings := engine.AnalyzeClause("4.2", clauseText, clauseText)
		if len(findings) == 0 {
			t.Fatalf("SVC_UNILATERAL_TERMINATION aniqlanmadi")
		}
		f := findings[0]
		if f.RuleCode != "SVC_UNILATERAL_TERMINATION" {
			t.Errorf("Kutilgan RuleCode: SVC_UNILATERAL_TERMINATION, topildi: %s", f.RuleCode)
		}
		if f.Severity != rules.SeverityRed {
			t.Errorf("Qonuniy xavf RED bo'lishi kerak, lekin %s", f.Severity)
		}
		if f.LegalSource.Article != "707-modda" {
			t.Errorf("Asos 707-modda bo'lishi kerak, lekin %s", f.LegalSource.Article)
		}
	})

	// 2. Test SVC_UNLIMITED_LIABILITY
	t.Run("SVC_UNLIMITED_LIABILITY", func(t *testing.T) {
		clauseText := "Ijrochi shartnoma yuzasidan yuzaga kelgan barcha to'g'ridan-to'g'ri va bilvosita zararlar uchun cheksiz moddiy javobgarlikni zimmasiga oladi."
		findings := engine.AnalyzeClause("6.1", clauseText, clauseText)
		if len(findings) == 0 {
			t.Fatalf("SVC_UNLIMITED_LIABILITY aniqlanmadi")
		}
		if findings[0].Severity != rules.SeverityYellow {
			t.Errorf("Tijoriy xavf YELLOW bo'lishi kerak")
		}
	})

	// 3. Test SVC_PENALTY_FORM_RISK
	t.Run("SVC_PENALTY_FORM_RISK", func(t *testing.T) {
		clauseText := "Har bir kechiktirilgan kun uchun 1% miqdorida penya hisoblanadi."
		findings := engine.AnalyzeClause("7.3", clauseText, clauseText)
		if len(findings) == 0 {
			t.Fatalf("SVC_PENALTY_FORM_RISK aniqlanmadi")
		}
		if findings[0].LegalSource.Article != "326-modda" {
			t.Errorf("Kutilgan: 326-modda, topildi: %s", findings[0].LegalSource.Article)
		}
	})

	// 4. Test FORM_MANDATORY_NOTARIAL
	t.Run("FORM_MANDATORY_NOTARIAL", func(t *testing.T) {
		clauseText := "Ushbu shartnoma ko'chmas mulkni boshqa shaxsga o'tkazish bo'yicha oddiy yozma shaklda tuzildi."
		findings := engine.AnalyzeClause("1.1", clauseText, clauseText)
		if len(findings) == 0 {
			t.Fatalf("FORM_MANDATORY_NOTARIAL aniqlanmadi")
		}
		if findings[0].Severity != rules.SeverityRed {
			t.Errorf("Notarial talab buzilishi RED bo'lishi kerak")
		}
	})

	// 5. Test Document Level Missing Clauses (Acceptance Act & Force Majeure)
	t.Run("MissingClauses", func(t *testing.T) {
		minimalDoc := `
			1. Shartnoma predmeti: Dasturiy ta'minot yaratish.
			2. Narxi: 10,000,000 so'm.
			3. Taraflar imzolari.
		`
		clauses := map[string]string{
			"1": "1. Shartnoma predmeti: Dasturiy ta'minot yaratish.",
			"2": "2. Narxi: 10,000,000 so'm.",
			"3": "3. Taraflar imzolari.",
		}

		allFindings := engine.AnalyzeDocument(clauses, minimalDoc)
		foundAkt := false
		foundForsMajor := false
		for _, f := range allFindings {
			if f.RuleCode == "SVC_NO_ACCEPTANCE_ACT" {
				foundAkt = true
			}
			if f.RuleCode == "SVC_FORCE_MAJEURE_MISSING" {
				foundForsMajor = true
			}
		}

		if !foundAkt {
			t.Errorf("Dalolatnoma yo'qligi aniqlanmadi (SVC_NO_ACCEPTANCE_ACT)")
		}
		if !foundForsMajor {
			t.Errorf("Fors-major yo'qligi aniqlanmadi (SVC_FORCE_MAJEURE_MISSING)")
		}
	})
}
