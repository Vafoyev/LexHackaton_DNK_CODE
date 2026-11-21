package platform

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestRateLimiterWindow(t *testing.T) {
	l := NewRateLimiter(2, time.Minute)
	now := time.Now()
	l.now = func() time.Time { return now }
	for i := 0; i < 2; i++ {
		if ok, _ := l.Allow("a"); !ok {
			t.Fatalf("so'rov %d ruxsat etilishi kerak edi", i)
		}
	}
	if ok, wait := l.Allow("a"); ok || wait <= 0 {
		t.Fatal("3-so'rov rad etilishi va kutish vaqti qaytishi kerak")
	}
	if ok, _ := l.Allow("b"); !ok {
		t.Fatal("boshqa kalit mustaqil bo'lishi kerak")
	}
	now = now.Add(2 * time.Minute)
	if ok, _ := l.Allow("a"); !ok {
		t.Fatal("oyna tugagach ruxsat qaytishi kerak")
	}
}

func TestClientIPTrustsHeadersOnlyFromPrivatePeer(t *testing.T) {
	r := httptest.NewRequest("GET", "/", nil)
	r.RemoteAddr = "8.8.8.8:1234"
	r.Header.Set("X-Forwarded-For", "1.2.3.4")
	if got := ClientIP(r); got != "8.8.8.8" {
		t.Fatalf("ommaviy peer sarlavhasi e'tiborga olinmasligi kerak, got %s", got)
	}
	r.RemoteAddr = "172.18.0.2:5555"
	if got := ClientIP(r); got != "1.2.3.4" {
		t.Fatalf("ichki proksi sarlavhasi ishonchli, got %s", got)
	}
}

func TestCORSAllowlist(t *testing.T) {
	h := CORSMiddleware([]string{"https://lexguardai.uz"}, false)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(200)
	}))
	do := func(origin, method string) *httptest.ResponseRecorder {
		req := httptest.NewRequest(method, "/", nil)
		if origin != "" {
			req.Header.Set("Origin", origin)
		}
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, req)
		return rec
	}
	if got := do("https://lexguardai.uz", "GET").Header().Get("Access-Control-Allow-Origin"); got != "https://lexguardai.uz" {
		t.Fatalf("ruxsat etilgan origin aks etishi kerak, got %q", got)
	}
	if got := do("https://evil.example", "GET").Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Fatalf("begona origin ruxsat etilmasligi kerak, got %q", got)
	}
	if rec := do("https://lexguardai.uz", "OPTIONS"); rec.Code != http.StatusNoContent {
		t.Fatalf("preflight 204 bo'lishi kerak, got %d", rec.Code)
	}
}

func TestConfigValidate(t *testing.T) {
	c := &Config{AppEnv: "production", JWTSecret: DefaultInsecureJWTSecret}
	if err := c.Validate(); err == nil {
		t.Fatal("production'da default JWT rad etilishi kerak")
	}
	c.JWTSecret = "short"
	if err := c.Validate(); err == nil {
		t.Fatal("production'da qisqa JWT rad etilishi kerak")
	}
	c.JWTSecret = strings.Repeat("k", 40)
	if err := c.Validate(); err != nil {
		t.Fatalf("kuchli kalit qabul qilinishi kerak: %v", err)
	}
	if err := (&Config{AppEnv: "development", JWTSecret: DefaultInsecureJWTSecret}).Validate(); err != nil {
		t.Fatalf("dev'da default faqat ogohlantiradi: %v", err)
	}
}

func TestRedactURL(t *testing.T) {
	got := RedactURL("postgres://lexguard:s3cret@db:5432/lexguard?sslmode=disable")
	if strings.Contains(got, "s3cret") || !strings.Contains(got, "lexguard:***@db") {
		t.Fatalf("parol maskalanmadi: %s", got)
	}
}

func TestWriteErrorMasks500(t *testing.T) {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/", nil)
	WriteError(rec, req, http.StatusInternalServerError, "DB_ERROR", "pq: relation \"secret_table\" does not exist", "trace")
	if strings.Contains(rec.Body.String(), "secret_table") || strings.Contains(rec.Body.String(), "trace") {
		t.Fatalf("500 javobida ichki tafsilot chiqdi: %s", rec.Body.String())
	}
}

func TestRequireRoleNoOwnerBypass(t *testing.T) {
	h := RequireRole("admin")(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(200) }))
	for role, want := range map[string]int{"owner": 403, "admin": 200, "platform_admin": 200, "client": 403} {
		req := httptest.NewRequest("GET", "/", nil)
		req = req.WithContext(context.WithValue(req.Context(), UserRoleKey, role))
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, req)
		if rec.Code != want {
			t.Errorf("rol %s: kutilgan %d, olingan %d", role, want, rec.Code)
		}
	}
}
