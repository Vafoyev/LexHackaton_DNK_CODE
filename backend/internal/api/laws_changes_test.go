package api_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"github.com/lexguard/backend/internal/ai"
	"github.com/lexguard/backend/internal/platform"
)

func lawChangesEngine(t *testing.T, got *url.Values) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/law-changes" || r.Method != http.MethodGet {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		if got != nil {
			*got = r.URL.Query()
		}
		_, _ = w.Write([]byte(`{"snapshot_latest":"2026-11-13","total_changed_articles":1,"items":[{"code":"MK-2022 4-modda"}],"laws":[]}`))
	}))
}

func getLawChanges(router http.Handler, query string) *httptest.ResponseRecorder {
	req, _ := http.NewRequest("GET", "/api/v1/laws/changes"+query, nil)
	rr := httptest.NewRecorder()
	router.ServeHTTP(rr, req)
	return rr
}

func TestLawChanges_PublicAndProxiesWithCacheHeader(t *testing.T) {
	var got url.Values
	srv := lawChangesEngine(t, &got)
	defer srv.Close()
	router, _ := chatRouter(ai.NewEngineClient(srv.URL))

	rr := getLawChanges(router, "?limit=5&source=MK-2022&since=2026-01-01&only_used=true")
	if rr.Code != http.StatusOK {
		t.Fatalf("200 kutilgan (token talab qilinmaydi), %d: %s", rr.Code, rr.Body.String())
	}
	if cc := rr.Header().Get("Cache-Control"); !strings.Contains(cc, "max-age=3600") {
		t.Errorf("Cache-Control kutilgan: %q", cc)
	}
	if got.Get("limit") != "5" || got.Get("source") != "MK-2022" || got.Get("since") != "2026-01-01" || got.Get("only_used") != "true" {
		t.Errorf("parametrlar noto'g'ri uzatildi: %v", got)
	}
	var resp platform.APIResponse
	_ = json.Unmarshal(rr.Body.Bytes(), &resp)
	data, _ := resp.Data.(map[string]interface{})
	if data["snapshot_latest"] != "2026-11-13" {
		t.Errorf("engine hisoboti o'zgarmasdan o'tishi kerak: %v", resp.Data)
	}
}

func TestLawChanges_DefaultsAndUnknownParamsAreNotForwarded(t *testing.T) {
	var got url.Values
	srv := lawChangesEngine(t, &got)
	defer srv.Close()
	router, _ := chatRouter(ai.NewEngineClient(srv.URL))

	if rr := getLawChanges(router, "?evil=1&limit=3"); rr.Code != http.StatusOK {
		t.Fatalf("200 kutilgan, %d", rr.Code)
	}
	if got.Get("evil") != "" || got.Get("limit") != "3" {
		t.Errorf("faqat ruxsat etilgan parametrlar uzatilishi kerak: %v", got)
	}
	if rr := getLawChanges(router, ""); rr.Code != http.StatusOK || got.Get("limit") != "10" {
		t.Errorf("default limit=10 bo'lishi kerak: %d %v", rr.Code, got)
	}
}

func TestLawChanges_Validation(t *testing.T) {
	srv := lawChangesEngine(t, nil)
	defer srv.Close()
	router, _ := chatRouter(ai.NewEngineClient(srv.URL))

	for _, q := range []string{"?limit=0", "?limit=51", "?limit=abc", "?source=x%3Bdrop", "?source=" + strings.Repeat("A", 17), "?since=kecha", "?since=2026-13-40"} {
		if rr := getLawChanges(router, q); rr.Code != http.StatusBadRequest {
			t.Errorf("%s: 400 kutilgan, %d", q, rr.Code)
		}
	}
}

func TestLawChanges_EngineFailures(t *testing.T) {
	router, _ := chatRouter(nil)
	if rr := getLawChanges(router, ""); rr.Code != http.StatusServiceUnavailable {
		t.Errorf("sozlanmagan engine: 503 kutilgan, %d", rr.Code)
	}
	srv := lawChangesEngine(t, nil)
	url := srv.URL
	srv.Close()
	router, _ = chatRouter(ai.NewEngineClient(url))
	rr := getLawChanges(router, "")
	if rr.Code != http.StatusServiceUnavailable || strings.Contains(rr.Body.String(), "127.0.0.1") {
		t.Errorf("o'chiq engine: 503 va ichki manzilsiz javob kutilgan: %d %s", rr.Code, rr.Body.String())
	}
}
