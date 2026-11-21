package ai_test

import (
	"context"
	"testing"

	"github.com/lexguard/backend/internal/ai"
)

func TestTemporalLegalAIProvider_ProbationRouting(t *testing.T) {
	provider := ai.NewTemporalLegalAIProvider()
	ctx := context.Background()

	// 1. Shartnoma 2022-yilda tuzilgan
	req2022 := ai.RedactedClauseRequest{
		ClauseNumber: "2.1",
		RedactedText: "Xodimga 4 oy sinov muddati belgilanadi.",
		ContractDate: "2022-05-15",
		DocType:      "LABOR_AGREEMENT",
	}

	res2022, _, err := provider.AnalyzeClause(ctx, req2022)
	if err != nil {
		t.Fatalf("AnalyzeClause xatosi: %v", err)
	}
	if res2022 == nil {
		t.Fatalf("Taklif bo'sh qaytdi")
	}
	if res2022.CitedLawCode != "MK-1995" {
		t.Errorf("2022-yil uchun MK-1995 kutilgan edi, lekin olindi: %s", res2022.CitedLawCode)
	}
	if res2022.CitedArticle != "84-modda" {
		t.Errorf("2022-yil uchun 84-modda kutilgan edi, lekin olindi: %s", res2022.CitedArticle)
	}

	// 2. Shartnoma 2024-yilda tuzilgan
	req2024 := ai.RedactedClauseRequest{
		ClauseNumber: "2.1",
		RedactedText: "Xodimga 4 oy sinov muddati belgilanadi.",
		ContractDate: "2024-05-15",
		DocType:      "LABOR_AGREEMENT",
	}

	res2024, _, err := provider.AnalyzeClause(ctx, req2024)
	if err != nil {
		t.Fatalf("AnalyzeClause xatosi: %v", err)
	}
	if res2024 == nil {
		t.Fatalf("Taklif bo'sh qaytdi")
	}
	if res2024.CitedLawCode != "MK-2022" {
		t.Errorf("2024-yil uchun MK-2022 kutilgan edi, lekin olindi: %s", res2024.CitedLawCode)
	}
	if res2024.CitedArticle != "130-modda" {
		t.Errorf("2024-yil uchun 130-modda kutilgan edi, lekin olindi: %s", res2024.CitedArticle)
	}
}

func TestTemporalLegalAIProvider_UnilateralAndPenalty(t *testing.T) {
	provider := ai.NewTemporalLegalAIProvider()
	ctx := context.Background()

	// Unilateral termination
	reqUnilateral := ai.RedactedClauseRequest{
		ClauseNumber: "4.2",
		RedactedText: "Buyurtmachi istalgan paytda to'lovsiz shartnomani bekor qilishi mumkin.",
		ContractDate: "2026-01-01",
		DocType:      "SERVICE_AGREEMENT",
	}
	resUni, _, err := provider.AnalyzeClause(ctx, reqUnilateral)
	if err != nil || resUni == nil {
		t.Fatalf("Unilateral xatosi: %v", err)
	}
	if resUni.Severity != "RED" || resUni.CitedArticle != "707-modda" {
		t.Errorf("Kutilgan RED va FK 707, olindi: %s %s", resUni.Severity, resUni.CitedArticle)
	}

	// Penalty check (dispositive -> YELLOW)
	reqPenalty := ai.RedactedClauseRequest{
		ClauseNumber: "7.3",
		RedactedText: "Kechiktirilgan kunga 1% penya to'lanadi.",
		ContractDate: "2026-01-01",
		DocType:      "SERVICE_AGREEMENT",
	}
	resPen, _, err := provider.AnalyzeClause(ctx, reqPenalty)
	if err != nil || resPen == nil {
		t.Fatalf("Penalty xatosi: %v", err)
	}
	if resPen.Severity != "YELLOW" || resPen.CitedArticle != "326-modda" {
		t.Errorf("Kutilgan YELLOW va FK 326, olindi: %s %s", resPen.Severity, resPen.CitedArticle)
	}
}
