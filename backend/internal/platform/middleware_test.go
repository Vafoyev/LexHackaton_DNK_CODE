package platform

import (
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

// LoggerMiddleware ResponseWriter ni o'rab oladi; SSE (Flusher) va WebSocket (Hijacker) ishlashi uchun
// o'ram bu interfeyslarni yo'qotmasligi shart.
func TestLoggerMiddlewarePreservesFlusherAndHijacker(t *testing.T) {
	srv := httptest.NewServer(LoggerMiddleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, isFlusher := w.(http.Flusher)
		_, isHijacker := w.(http.Hijacker)
		fmt.Fprintf(w, "flusher=%v hijacker=%v", isFlusher, isHijacker)
	})))
	defer srv.Close()

	resp, err := http.Get(srv.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if string(body) != "flusher=true hijacker=true" {
		t.Fatalf("o'ram interfeyslarni yo'qotdi: %s", body)
	}
}

func TestLoggerMiddlewareFlushWritesThroughAndKeepsStatus(t *testing.T) {
	srv := httptest.NewServer(LoggerMiddleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusTeapot)
		w.Write([]byte("a"))
		w.(http.Flusher).Flush()
	})))
	defer srv.Close()

	resp, err := http.Get(srv.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusTeapot {
		t.Fatalf("status yo'qoldi: %d", resp.StatusCode)
	}
}
