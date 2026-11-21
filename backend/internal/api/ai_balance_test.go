package api_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/lexguard/backend/internal/ai"
	"github.com/lexguard/backend/internal/platform"
)

func balanceEngine(t *testing.T, received *ai.BalanceRequest) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/balance" || r.Method != http.MethodPost {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		if received != nil {
			_ = json.NewDecoder(r.Body).Decode(received)
		}
		_, _ = w.Write([]byte(`{"verdict":"ONE_SIDED_PROVIDER","verdict_label":"Ijrochi tomoniga og'ir","score":20,"topics":[]}`))
	}))
}

func postBalance(router http.Handler, token, body string) *httptest.ResponseRecorder {
	req, _ := http.NewRequest("POST", "/api/v1/ai/balance", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rr := httptest.NewRecorder()
	router.ServeHTTP(rr, req)
	return rr
}

func TestAIBalance_RequiresAuth(t *testing.T) {
	router, _ := chatRouter(nil)
	if rr := postBalance(router, "", `{"clauses":[{"text":"x"}]}`); rr.Code != http.StatusUnauthorized {
		t.Fatalf("401 kutilgan, %d", rr.Code)
	}
}

func TestAIBalance_ProxiesReportAndMapsClauses(t *testing.T) {
	var got ai.BalanceRequest
	srv := balanceEngine(t, &got)
	defer srv.Close()
	router, token := chatRouter(ai.NewEngineClient(srv.URL))

	body := `{"document_type":"SERVICE_AGREEMENT","party_role":"executor","clauses":[` +
		`{"clause_number":"1.1","text":"Birinchi band"},{"clause_number":"1.2","text":"   "},{"clause_number":"1.3","text":"Uchinchi band"}]}`
	rr := postBalance(router, token, body)
	if rr.Code != http.StatusOK {
		t.Fatalf("200 kutilgan, %d: %s", rr.Code, rr.Body.String())
	}
	var resp platform.APIResponse
	_ = json.Unmarshal(rr.Body.Bytes(), &resp)
	data, _ := resp.Data.(map[string]interface{})
	if data["verdict"] != "ONE_SIDED_PROVIDER" || data["score"] == nil {
		t.Errorf("engine hisoboti o'zgarmasdan o'tishi kerak: %v", resp.Data)
	}
	if got.DocumentType != "SERVICE_AGREEMENT" || got.PartyRole != "EXECUTOR" {
		t.Errorf("parametrlar noto'g'ri uzatildi: %+v", got)
	}
	if len(got.Clauses) != 2 || got.Clauses[0].ClauseNumber != "1.1" || got.Clauses[1].ClauseNumber != "1.3" {
		t.Errorf("bo'sh band tashlanib, qolganlari uzatilishi kerak: %+v", got.Clauses)
	}
	if got.Clauses[1].ClauseID != "3" {
		t.Errorf("clause_id asl tartib raqami bo'lishi kerak: %q", got.Clauses[1].ClauseID)
	}
}

func TestAIBalance_Validation(t *testing.T) {
	srv := balanceEngine(t, nil)
	defer srv.Close()
	router, token := chatRouter(ai.NewEngineClient(srv.URL))

	many := `{"clauses":[` + strings.TrimSuffix(strings.Repeat(`{"text":"x"},`, 301), ",") + `]}`
	long := `{"clauses":[{"text":"` + strings.Repeat("a", 5001) + `"}]}`
	cases := []struct {
		name, body string
		want       int
	}{
		{"bandlar yo'q", `{"clauses":[]}`, http.StatusBadRequest},
		{"noto'g'ri json", `nope`, http.StatusBadRequest},
		{"hammasi bo'sh matn", `{"clauses":[{"text":" "},{"text":""}]}`, http.StatusBadRequest},
		{"noto'g'ri party_role", `{"party_role":"HACKER","clauses":[{"text":"x"}]}`, http.StatusBadRequest},
		{"juda uzun document_type", `{"document_type":"` + strings.Repeat("A", 65) + `","clauses":[{"text":"x"}]}`, http.StatusBadRequest},
		{"301 ta band", many, http.StatusRequestEntityTooLarge},
		{"5001 belgili band", long, http.StatusRequestEntityTooLarge},
		{"chegara: 300 ta band", `{"clauses":[` + strings.TrimSuffix(strings.Repeat(`{"text":"x"},`, 300), ",") + `]}`, http.StatusOK},
		{"party_role bo'sh", `{"clauses":[{"text":"x"}]}`, http.StatusOK},
	}
	for _, c := range cases {
		if rr := postBalance(router, token, c.body); rr.Code != c.want {
			t.Errorf("%s: %d kutilgan, %d (%s)", c.name, c.want, rr.Code, rr.Body.String())
		}
	}
}

func TestAIBalance_TotalSizeLimit(t *testing.T) {
	srv := balanceEngine(t, nil)
	defer srv.Close()
	router, token := chatRouter(ai.NewEngineClient(srv.URL))
	// 41 ta band x 5000 belgi = 205000 > 200000
	body := `{"clauses":[` + strings.TrimSuffix(strings.Repeat(`{"text":"`+strings.Repeat("a", 5000)+`"},`, 41), ",") + `]}`
	if rr := postBalance(router, token, body); rr.Code != http.StatusRequestEntityTooLarge {
		t.Fatalf("413 kutilgan, %d", rr.Code)
	}
}

func TestAIBalance_EngineFailuresReturn503(t *testing.T) {
	// engine yo'q
	router, token := chatRouter(nil)
	if rr := postBalance(router, token, `{"clauses":[{"text":"x"}]}`); rr.Code != http.StatusServiceUnavailable {
		t.Errorf("sozlanmagan engine: 503 kutilgan, %d", rr.Code)
	}
	// engine o'chiq
	srv := balanceEngine(t, nil)
	url := srv.URL
	srv.Close()
	router, token = chatRouter(ai.NewEngineClient(url))
	rr := postBalance(router, token, `{"clauses":[{"text":"x"}]}`)
	if rr.Code != http.StatusServiceUnavailable || strings.Contains(rr.Body.String(), "127.0.0.1") {
		t.Errorf("o'chiq engine: 503 va ichki manzilsiz javob kutilgan: %d %s", rr.Code, rr.Body.String())
	}
	// engine 500 / yaroqsiz JSON
	bad := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { _, _ = w.Write([]byte("not json")) }))
	defer bad.Close()
	router, token = chatRouter(ai.NewEngineClient(bad.URL))
	if rr := postBalance(router, token, `{"clauses":[{"text":"x"}]}`); rr.Code != http.StatusServiceUnavailable {
		t.Errorf("yaroqsiz JSON: 503 kutilgan, %d", rr.Code)
	}
}
