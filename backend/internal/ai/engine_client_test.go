package ai

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestEngineClient_AnalyzeClauses_And_SelfCorrect(t *testing.T) {
	// Mock Python AI Engine Server
	mockServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")

		switch r.URL.Path {
		case "/health":
			w.WriteHeader(http.StatusOK)
			_ = json.NewEncoder(w).Encode(map[string]interface{}{
				"status":  "UP",
				"service": "lexguard-ai-engine",
				"version": "4.2.0",
			})

		case "/api/v1/analyze-clauses":
			var req AnalysisEngineRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			resp := AnalysisEngineResponse{
				AnalysisID:    req.AnalysisID,
				TotalClauses:  len(req.Clauses),
				FindingsCount: 1,
				Findings: []FindingOutput{
					{
						ClauseID:         "c-1",
						ClauseNumber:     "4.2",
						RiskLevel:        "RED",
						Category:         "LEGAL",
						IssueTitle:       "Asossiz bir tomonlama bekor qilish huquqi",
						ProblematicQuote: "Buyurtmachi istalgan vaqtda shartnomani bekor qilishi mumkin.",
						IssueExplanation: "FK 707-moddasiga zid.",
						CitedArticle:     "FK-UZ 707-modda",
						SuggestedRedline: "Buyurtmachi amalda qilingan xarajatlarni qoplagan holda 15 kun oldin xabardor qiladi.",
						BalanceLabel:     "Buyurtmachiga og'ir",
						LexUzURL:         "https://lex.uz/docs/180552#181540",
					},
				},
			}
			w.WriteHeader(http.StatusOK)
			_ = json.NewEncoder(w).Encode(resp)

		case "/api/v1/self-correct":
			var req SelfCorrectionRequest
			_ = json.NewDecoder(r.Body).Decode(&req)

			resp := SelfCorrectionResponse{
				Resolved:         true,
				CorrectedArticle: "FK-UZ 707-modda",
				Explanation:      "To'g'rilangan norma: FK 707-modda bir tomonlama bekor qilishni tartibga soladi.",
				SuggestedRedline: "Amaldagi xarajatlar qoplanishi shart.",
			}
			w.WriteHeader(http.StatusOK)
			_ = json.NewEncoder(w).Encode(resp)

		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer mockServer.Close()

	client := NewEngineClient(mockServer.URL)

	// 1. Test HealthCheck
	ok, err := client.HealthCheck(context.Background())
	if err != nil || !ok {
		t.Fatalf("HealthCheck failed: ok=%v, err=%v", ok, err)
	}

	// 2. Test AnalyzeClauses
	req := AnalysisEngineRequest{
		AnalysisID:   "test-001",
		DocumentType: "B2B_SERVICE",
		ContractDate: "2026-11-21",
		Clauses: []ClauseInput{
			{
				ClauseID:     "c-1",
				ClauseNumber: "4.2",
				Text:         "Buyurtmachi istalgan vaqtda shartnomani bekor qilishi mumkin.",
			},
		},
	}
	resp, err := client.AnalyzeClauses(context.Background(), req)
	if err != nil {
		t.Fatalf("AnalyzeClauses failed: %v", err)
	}
	if resp.FindingsCount != 1 || resp.Findings[0].RiskLevel != "RED" {
		t.Errorf("Unexpected findings: %+v", resp)
	}
	if resp.Findings[0].ProblematicQuote == "" || resp.Findings[0].SuggestedRedline == "" {
		t.Errorf("Red/Green fields must not be empty: %+v", resp.Findings[0])
	}

	// 3. Test SelfCorrect
	scReq := SelfCorrectionRequest{
		ClauseText:           "Shartnomani to'lovsiz bekor qilish.",
		PreviousCitedArticle: "Noma'lum 999-modda",
		VerificationError:    "Article not found in legal allowlist",
	}
	scResp, err := client.SelfCorrect(context.Background(), scReq)
	if err != nil {
		t.Fatalf("SelfCorrect failed: %v", err)
	}
	if !scResp.Resolved || scResp.CorrectedArticle != "FK-UZ 707-modda" {
		t.Errorf("Unexpected self-correction result: %+v", scResp)
	}
}
