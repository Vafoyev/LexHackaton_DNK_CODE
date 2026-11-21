package api_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/lexguard/backend/internal/ai"
	"github.com/lexguard/backend/internal/analysis"
	"github.com/lexguard/backend/internal/api"
	"github.com/lexguard/backend/internal/billing"
	"github.com/lexguard/backend/internal/documents"
	"github.com/lexguard/backend/internal/legalcorpus"
	"github.com/lexguard/backend/internal/platform"
	"github.com/lexguard/backend/internal/privacy"
	"github.com/lexguard/backend/internal/report"
	"github.com/lexguard/backend/internal/rules"
	"github.com/lexguard/backend/internal/verification"
)

// chatRouter AI engine ni (mock yoki yo'q) bilan router quradi.
func chatRouter(engine *ai.EngineClient) (http.Handler, string) {
	cfg := &platform.Config{JWTSecret: "test_secret_32_bytes_super_secure!", StorageDir: "/tmp/storage_test"}
	jwtMgr := platform.NewJWTManager(cfg.JWTSecret)
	corpusRepo := legalcorpus.NewRepository(nil)
	rulesEngine := rules.NewRulesEngine()
	billingSvc := billing.NewService(nil)
	docRepo := documents.NewRepository(nil)
	analysisSvc := analysis.NewService(nil, docRepo, corpusRepo, billingSvc, rulesEngine, ai.NewTemporalLegalAIProvider(),
		verification.NewArbiter(corpusRepo), privacy.NewExternalLLMGate(), analysis.NewSSEBroadcaster())

	router := api.BuildRouter(&api.RouterServices{
		Config: cfg, JWTManager: jwtMgr, DocRepo: docRepo, CorpusRepo: corpusRepo, RulesEngine: rulesEngine,
		AnalysisSvc: analysisSvc, ReportSvc: report.NewService(analysisSvc), BillingSvc: billingSvc,
		Redactor: privacy.NewRedactor(), AIEngine: engine,
	})
	pair, _, _ := jwtMgr.GenerateTokenPair("55555555-0000-0000-0000-000000000002", "44444444-0000-0000-0000-000000000001", "owner", "web")
	return router, pair.AccessToken
}

func postChat(router http.Handler, token, body string) *httptest.ResponseRecorder {
	req, _ := http.NewRequest("POST", "/api/v1/ai/chat", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rr := httptest.NewRecorder()
	router.ServeHTTP(rr, req)
	return rr
}

func mockEngine(t *testing.T, received *string) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/chat" || r.Method != http.MethodPost {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		var in struct {
			Message string `json:"message"`
		}
		_ = json.NewDecoder(r.Body).Decode(&in)
		if received != nil {
			*received = in.Message
		}
		_ = json.NewEncoder(w).Encode(ai.ChatResponse{
			Intent: "article", Answer: "FK 707 — javob", Speech: "FK 707 javob",
			Sources:  []ai.ChatSource{{ID: "FK-UZ-2_707", Code: "FK-UZ-2 707-modda", Title: "t", URL: "https://lex.uz/x"}},
			Findings: []ai.ChatFinding{}, Suggestions: []string{"a"}, Disclaimer: "d",
		})
	}))
}

func TestAIChat_RequiresAuth(t *testing.T) {
	router, _ := chatRouter(nil)
	if rr := postChat(router, "", `{"message":"salom"}`); rr.Code != http.StatusUnauthorized {
		t.Fatalf("token yo'q: 401 kutilgan, %d", rr.Code)
	}
}

func TestAIChat_ProxiesToEngine(t *testing.T) {
	var got string
	srv := mockEngine(t, &got)
	defer srv.Close()
	router, token := chatRouter(ai.NewEngineClient(srv.URL))

	rr := postChat(router, token, `{"message":"  707-modda nima deydi?  "}`)
	if rr.Code != http.StatusOK {
		t.Fatalf("200 kutilgan, %d: %s", rr.Code, rr.Body.String())
	}
	if got != "707-modda nima deydi?" {
		t.Errorf("engine ga bo'shliqsiz xabar yetishi kerak, olindi %q", got)
	}
	var resp platform.APIResponse
	_ = json.Unmarshal(rr.Body.Bytes(), &resp)
	data, _ := resp.Data.(map[string]interface{})
	if data["answer"] != "FK 707 — javob" || data["speech"] == nil || data["sources"] == nil {
		t.Errorf("javob shakli noto'g'ri: %v", resp.Data)
	}
}

func TestAIChat_Validation(t *testing.T) {
	srv := mockEngine(t, nil)
	defer srv.Close()
	router, token := chatRouter(ai.NewEngineClient(srv.URL))

	cases := []struct {
		name, body string
		want       int
	}{
		{"bo'sh xabar", `{"message":"   "}`, http.StatusBadRequest},
		{"message yo'q", `{}`, http.StatusBadRequest},
		{"noto'g'ri json", `not json`, http.StatusBadRequest},
		{"juda uzun", `{"message":"` + strings.Repeat("a", 2001) + `"}`, http.StatusRequestEntityTooLarge},
		{"2000 belgi (chegarada)", `{"message":"` + strings.Repeat("a", 2000) + `"}`, http.StatusOK},
		{"2000 ta ko'p baytli belgi", `{"message":"` + strings.Repeat("ʻ", 2000) + `"}`, http.StatusOK},
	}
	for _, c := range cases {
		if rr := postChat(router, token, c.body); rr.Code != c.want {
			t.Errorf("%s: %d kutilgan, %d (%s)", c.name, c.want, rr.Code, rr.Body.String())
		}
	}
}

func TestAIChat_EngineDownReturns503WithoutLeakingDetails(t *testing.T) {
	srv := mockEngine(t, nil)
	url := srv.URL
	srv.Close() // engine o'chiq
	router, token := chatRouter(ai.NewEngineClient(url))

	rr := postChat(router, token, `{"message":"salom"}`)
	if rr.Code != http.StatusServiceUnavailable {
		t.Fatalf("503 kutilgan, %d", rr.Code)
	}
	if strings.Contains(rr.Body.String(), "127.0.0.1") || strings.Contains(rr.Body.String(), "dial") {
		t.Errorf("ichki manzil/xato tafsiloti mijozga chiqmasligi kerak: %s", rr.Body.String())
	}
}

func TestAIChat_EngineNotConfiguredReturns503(t *testing.T) {
	router, token := chatRouter(nil)
	if rr := postChat(router, token, `{"message":"salom"}`); rr.Code != http.StatusServiceUnavailable {
		t.Fatalf("503 kutilgan, %d", rr.Code)
	}
}

func TestAIChat_EngineErrorStatusReturns503(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusInternalServerError) }))
	defer srv.Close()
	router, token := chatRouter(ai.NewEngineClient(srv.URL))
	if rr := postChat(router, token, `{"message":"salom"}`); rr.Code != http.StatusServiceUnavailable {
		t.Fatalf("503 kutilgan, %d", rr.Code)
	}
}
