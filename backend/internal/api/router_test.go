package api_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
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

func setupTestRouter() (http.Handler, *platform.JWTManager) {
	cfg := &platform.Config{
		JWTSecret:  "test_secret_32_bytes_super_secure!",
		StorageDir: "/tmp/storage_test",
	}
	jwtMgr := platform.NewJWTManager(cfg.JWTSecret)
	corpusRepo := legalcorpus.NewRepository(nil)
	rulesEngine := rules.NewRulesEngine()
	aiProvider := ai.NewTemporalLegalAIProvider()
	arbiter := verification.NewArbiter(corpusRepo)
	broadcaster := analysis.NewSSEBroadcaster()
	redactor := privacy.NewRedactor()
	llmGate := privacy.NewExternalLLMGate()

	billingSvc := billing.NewService(nil)
	docRepo := documents.NewRepository(nil)
	analysisSvc := analysis.NewService(nil, docRepo, corpusRepo, billingSvc, rulesEngine, aiProvider, arbiter, llmGate, broadcaster)
	reportSvc := report.NewService(analysisSvc)

	services := &api.RouterServices{
		DB:          nil,
		Config:      cfg,
		JWTManager:  jwtMgr,
		IdentitySvc: nil,
		DocRepo:     docRepo,
		CorpusRepo:  corpusRepo,
		RulesEngine: rulesEngine,
		AnalysisSvc: analysisSvc,
		ReportSvc:   reportSvc,
		SigningSvc:  nil,
		BillingSvc:  billingSvc,
		AuditSvc:    nil,
		AdminSvc:    nil,
		Redactor:    redactor,
	}

	return api.BuildRouter(services), jwtMgr
}

func TestAPI_PublicEndpoints(t *testing.T) {
	router, _ := setupTestRouter()

	// 1. Healthz
	req, _ := http.NewRequest("GET", "/healthz", nil)
	rr := httptest.NewRecorder()
	router.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Errorf("Expected 200 for /healthz, got %d", rr.Code)
	}

	// 2. Rules
	req, _ = http.NewRequest("GET", "/api/v1/rules", nil)
	rr = httptest.NewRecorder()
	router.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Errorf("Expected 200 for /api/v1/rules, got %d", rr.Code)
	}
	var resp platform.APIResponse
	_ = json.Unmarshal(rr.Body.Bytes(), &resp)
	rulesList, ok := resp.Data.([]interface{})
	if !ok || len(rulesList) < 10 {
		t.Errorf("Kutilgan kamida 10 ta qoida, olindi: %v", resp.Data)
	}

	// 3. Legal Sources
	req, _ = http.NewRequest("GET", "/api/v1/legal-sources", nil)
	rr = httptest.NewRecorder()
	router.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Errorf("Expected 200 for /api/v1/legal-sources, got %d", rr.Code)
	}
	var respSources platform.APIResponse
	_ = json.Unmarshal(rr.Body.Bytes(), &respSources)
	sources, ok := respSources.Data.([]interface{})
	if !ok || len(sources) < 5 {
		t.Errorf("Kutilgan kamida 5 ta qonun manbasi, olindi: %v", respSources.Data)
	}

	// 4. Mock Sample
	req, _ = http.NewRequest("GET", "/api/v1/mock/analysis-sample", nil)
	rr = httptest.NewRecorder()
	router.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Errorf("Expected 200 for /api/v1/mock/analysis-sample, got %d", rr.Code)
	}
}

func TestAPI_D10_VoiceAndGlanceableEndpoints(t *testing.T) {
	router, jwtMgr := setupTestRouter()

	// Generate authenticated token
	pair, _, err := jwtMgr.GenerateTokenPair("55555555-0000-0000-0000-000000000001", "44444444-0000-0000-0000-000000000001", "lawyer_reviewer", "web")
	if err != nil {
		t.Fatalf("Token yaratishda xatolik: %v", err)
	}
	token := pair.AccessToken

	// 1. Voice Brief (D-10)
	req, _ := http.NewRequest("GET", "/api/v1/analyses/mock-test-id/voice-brief", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rr := httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("Expected 200 for /voice-brief, got %d: %s", rr.Code, rr.Body.String())
	}
	var respVB platform.APIResponse
	_ = json.Unmarshal(rr.Body.Bytes(), &respVB)
	vbRes, ok := respVB.Data.(map[string]interface{})
	if !ok || vbRes["audio_text"] == nil || vbRes["ssml"] == nil {
		t.Errorf("audio_text yoki ssml bo'sh qaytdi: %v", respVB.Data)
	}

	// 2. Glanceable Matrix (D-10)
	req, _ = http.NewRequest("GET", "/api/v1/analyses/mock-test-id/glanceable-matrix", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rr = httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("Expected 200 for /glanceable-matrix, got %d: %s", rr.Code, rr.Body.String())
	}
	var respGM platform.APIResponse
	_ = json.Unmarshal(rr.Body.Bytes(), &respGM)
	gmRes, ok := respGM.Data.(map[string]interface{})
	if !ok || gmRes["spheres"] == nil || gmRes["spatial_nodes"] == nil {
		t.Errorf("spheres yoki spatial_nodes bo'sh qaytdi: %v", respGM.Data)
	}

	// 3. Voice Query Q&A (D-10)
	queryPayload := map[string]string{
		"query": "Shartnomada penya miqdori bo'yicha qanday cheklovlar bor?",
	}
	bodyBytes, _ := json.Marshal(queryPayload)
	req, _ = http.NewRequest("POST", "/api/v1/analyses/mock-test-id/voice-query", bytes.NewReader(bodyBytes))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	rr = httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("Expected 200 for /voice-query, got %d: %s", rr.Code, rr.Body.String())
	}
	var respVQ platform.APIResponse
	_ = json.Unmarshal(rr.Body.Bytes(), &respVQ)
	vqRes, ok := respVQ.Data.(map[string]interface{})
	if !ok || vqRes["answer"] == nil || vqRes["cited_articles"] == nil {
		t.Errorf("Ovozli savol javobi to'liq emas: %v", respVQ.Data)
	}

	// 4. WebSocket Voice Endpoint Check (/api/v1/ws/voice)
	reqWS, _ := http.NewRequest("GET", "/api/v1/ws/voice", nil)
	rrWS := httptest.NewRecorder()
	router.ServeHTTP(rrWS, reqWS)
	// Without websocket upgrade headers, it must return 400 Bad Request
	if rrWS.Code != http.StatusBadRequest {
		t.Errorf("Expected 400 Bad Request for non-upgrade websocket request, got %d", rrWS.Code)
	}
}

func TestAPI_SwaggerAndDocsEndpoints(t *testing.T) {
	router, _ := setupTestRouter()

	// 1. /docs Swagger UI
	req, _ := http.NewRequest("GET", "/docs", nil)
	rr := httptest.NewRecorder()
	router.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Errorf("Expected 200 for /docs, got %d", rr.Code)
	}
	if !bytes.Contains(rr.Body.Bytes(), []byte("swagger-ui")) {
		t.Errorf("Expected swagger-ui in /docs body")
	}

	// 2. /api/docs Swagger UI alias
	req, _ = http.NewRequest("GET", "/api/docs", nil)
	rr = httptest.NewRecorder()
	router.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Errorf("Expected 200 for /api/docs, got %d", rr.Code)
	}

	// 3. /api/openapi.yaml
	req, _ = http.NewRequest("GET", "/api/openapi.yaml", nil)
	rr = httptest.NewRecorder()
	router.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Errorf("Expected 200 for /api/openapi.yaml, got %d", rr.Code)
	}
	if !bytes.Contains(rr.Body.Bytes(), []byte("LexGuard AI")) {
		t.Errorf("Expected 'LexGuard AI' in /api/openapi.yaml")
	}

	// 4. /openapi.yaml alias
	req, _ = http.NewRequest("GET", "/openapi.yaml", nil)
	rr = httptest.NewRecorder()
	router.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Errorf("Expected 200 for /openapi.yaml, got %d", rr.Code)
	}
}
