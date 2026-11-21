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

	// 5. Test CURRENCY_SETTLEMENT_ILLEGAL
	t.Run("CURRENCY_SETTLEMENT_ILLEGAL", func(t *testing.T) {
		clauseText := "Shartnoma bo'yicha barcha to'lov naqd AQSH dollarida to'g'ridan-to'g'ri amalga oshiriladi."
		findings := engine.AnalyzeClause("3.2", clauseText, clauseText)
		if len(findings) == 0 {
			t.Fatalf("CURRENCY_SETTLEMENT_ILLEGAL aniqlanmadi")
		}
		if findings[0].Severity != rules.SeverityRed {
			t.Errorf("Valyuta buzilishi RED bo'lishi kerak")
		}
		if findings[0].LegalSource.Article != "245-modda" {
			t.Errorf("Kutilgan: 245-modda, topildi: %s", findings[0].LegalSource.Article)
		}
	})

	// 6. Test LABOR_PROBATION_EXCESSIVE
	t.Run("LABOR_PROBATION_EXCESSIVE", func(t *testing.T) {
		clauseText := "Xodimga topshirilayotgan vazifalarni tekshirish maqsadida 6 oy sinov muddati belgilanadi."
		findings := engine.AnalyzeClause("2.1", clauseText, clauseText)
		if len(findings) == 0 {
			t.Fatalf("LABOR_PROBATION_EXCESSIVE aniqlanmadi")
		}
		if findings[0].Severity != rules.SeverityRed {
			t.Errorf("6 oylik sinov RED bo'lishi kerak")
		}
		if findings[0].RiskCategory != rules.CategoryLabor {
			t.Errorf("Kategoriya LABOR bo'lishi kerak, lekin: %s", findings[0].RiskCategory)
		}
	})

	// 7. Test LABOR_NO_COMPETE_ILLEGAL
	t.Run("LABOR_NO_COMPETE_ILLEGAL", func(t *testing.T) {
		clauseText := "Xodim ishdan bo'shagandan so'ng 2 yil davomida raqobatchi kompaniyaga ishga kirmaslik majburiyatini oladi."
		findings := engine.AnalyzeClause("8.4", clauseText, clauseText)
		if len(findings) == 0 {
			t.Fatalf("LABOR_NO_COMPETE_ILLEGAL aniqlanmadi")
		}
		if findings[0].Severity != rules.SeverityRed {
			t.Errorf("No-compete RED bo'lishi kerak")
		}
	})

	// 8. Test LABOR_WORKING_HOURS_EXCESSIVE
	t.Run("LABOR_WORKING_HOURS_EXCESSIVE", func(t *testing.T) {
		clauseText := "Ish rejimi haftasiga 50 soat davom etadi va dam olish kunlarisiz belgilanadi."
		findings := engine.AnalyzeClause("4.1", clauseText, clauseText)
		if len(findings) == 0 {
			t.Fatalf("LABOR_WORKING_HOURS_EXCESSIVE aniqlanmadi")
		}
		if findings[0].Severity != rules.SeverityRed {
			t.Errorf("Ortiqcha ish vaqti RED bo'lishi kerak")
		}
	})

	// 9. Test DATA_LOCALIZATION_BREACH
	t.Run("DATA_LOCALIZATION_BREACH", func(t *testing.T) {
		clauseText := "Barcha mijozlar shaxsiy ma'lumotlari faqat chet eldagi serverlarda saqlanadi."
		findings := engine.AnalyzeClause("9.2", clauseText, clauseText)
		if len(findings) == 0 {
			t.Fatalf("DATA_LOCALIZATION_BREACH aniqlanmadi")
		}
		if findings[0].LegalSource.Article != "27-1-modda" {
			t.Errorf("Kutilgan: 27-1-modda, topildi: %s", findings[0].LegalSource.Article)
		}
	})

	// 10. Test Document Level Missing Clauses (Acceptance Act, Force Majeure, Privacy Consent, AI Oversight)
	t.Run("MissingClauses", func(t *testing.T) {
		minimalDoc := `
			1. Shartnoma predmeti: Sun'iy intellekt va neyrotarmoqlar asosida avtomatlashtirilgan xulosa berish.
			2. Narxi: 10,000,000 so'm. Mijoz pasport ma'lumotlari: AA1234567, JSHSHIR: 12345678901234.
			3. Taraflar imzolari.
		`
		clauses := map[string]string{
			"1": "1. Shartnoma predmeti: Sun'iy intellekt va neyrotarmoqlar asosida avtomatlashtirilgan xulosa berish.",
			"2": "2. Narxi: 10,000,000 so'm. Mijoz pasport ma'lumotlari: AA1234567, JSHSHIR: 12345678901234.",
			"3": "3. Taraflar imzolari.",
		}

		allFindings := engine.AnalyzeDocument(clauses, minimalDoc)
		foundAkt := false
		foundForsMajor := false
		foundPrivacyConsent := false
		foundAIOversight := false

		for _, f := range allFindings {
			switch f.RuleCode {
			case "SVC_NO_ACCEPTANCE_ACT":
				foundAkt = true
			case "SVC_FORCE_MAJEURE_MISSING":
				foundForsMajor = true
			case "PRIVACY_CONSENT_MISSING":
				foundPrivacyConsent = true
			case "AI_HUMAN_OVERSIGHT_MISSING":
				foundAIOversight = true
			}
		}

		if !foundAkt {
			t.Errorf("Dalolatnoma yo'qligi aniqlanmadi (SVC_NO_ACCEPTANCE_ACT)")
		}
		if !foundForsMajor {
			t.Errorf("Fors-major yo'qligi aniqlanmadi (SVC_FORCE_MAJEURE_MISSING)")
		}
		if !foundPrivacyConsent {
			t.Errorf("Shaxsiy ma'lumotlar roziligi yo'qligi aniqlanmadi (PRIVACY_CONSENT_MISSING)")
		}
		if !foundAIOversight {
			t.Errorf("AI inson nazorati yo'qligi aniqlanmadi (AI_HUMAN_OVERSIGHT_MISSING)")
		}
	})
}
