package platform

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"log/slog"
	"net"
	"net/http"
	"net/netip"
	"runtime/debug"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
)

type contextKey string

const (
	RequestIDKey      contextKey = "request_id"
	UserIDKey         contextKey = "user_id"
	OrganizationIDKey contextKey = "org_id"
	UserRoleKey       contextKey = "user_role"
	ClientTypeKey     contextKey = "client_type"
)

func RequestIDMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		reqID := r.Header.Get("X-Request-Id")
		if reqID == "" {
			reqID = uuid.NewString()
		}
		w.Header().Set("X-Request-Id", reqID)
		ctx := context.WithValue(r.Context(), RequestIDKey, reqID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func GetRequestID(r *http.Request) string {
	if val := r.Context().Value(RequestIDKey); val != nil {
		if s, ok := val.(string); ok {
			return s
		}
	}
	return ""
}

func LoggerMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rw := &statusResponseWriter{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rw, r)
		duration := time.Since(start)

		reqID := GetRequestID(r)
		slog.Info("http_request",
			slog.String("method", r.Method),
			slog.String("path", r.URL.Path),
			slog.Int("status", rw.status),
			slog.Duration("duration", duration),
			slog.Float64("duration_ms", float64(duration.Microseconds())/1000.0),
			slog.String("ip", ClientIP(r)),
			slog.String("req_id", reqID),
			slog.String("user_agent", r.UserAgent()),
		)
	})
}

type statusResponseWriter struct {
	http.ResponseWriter
	status int
}

func (rw *statusResponseWriter) WriteHeader(status int) {
	rw.status = status
	rw.ResponseWriter.WriteHeader(status)
}

// Flush SSE (text/event-stream) uchun: o'ram http.Flusher ni yo'qotmasligi kerak.
func (rw *statusResponseWriter) Flush() {
	if f, ok := rw.ResponseWriter.(http.Flusher); ok {
		f.Flush()
	}
}

// Hijack WebSocket (/ws/voice) uchun: o'ram http.Hijacker ni yo'qotmasligi kerak.
func (rw *statusResponseWriter) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	h, ok := rw.ResponseWriter.(http.Hijacker)
	if !ok {
		return nil, nil, http.ErrNotSupported
	}
	return h.Hijack()
}

// Unwrap http.ResponseController uchun.
func (rw *statusResponseWriter) Unwrap() http.ResponseWriter {
	return rw.ResponseWriter
}

func RecovererMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				reqID := GetRequestID(r)
				stack := string(debug.Stack())
				slog.Error("panic_recovered",
					slog.Any("error", rec),
					slog.String("stack", stack),
					slog.String("path", r.URL.Path),
					slog.String("req_id", reqID),
				)
				log.Printf("[PANIC RECOVER] %v\nStack: %s", rec, stack)
				// Panic matni (ichki tafsilot) faqat logga yoziladi, mijozga yuborilmaydi.
				WriteError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "Kutilmagan server xatoligi yuz berdi", nil)
			}
		}()
		next.ServeHTTP(w, r)
	})
}

// CORSMiddleware faqat ruxsat etilgan origin'larga CORS sarlavhalarini beradi.
//   - Origin sarlavhasi bo'lmasa (same-origin, mobil, server-server) — CORS sarlavhalari qo'shilmaydi.
//   - allowed ro'yxatidagi origin aks ettiriladi va cookie/credentials ruxsat etiladi.
//   - Ro'yxat bo'sh va devAnyOrigin=true (faqat rivojlantirish): istalgan origin, LEKIN credentials'siz.
func CORSMiddleware(allowed []string, devAnyOrigin bool) func(http.Handler) http.Handler {
	allow := make(map[string]struct{}, len(allowed))
	for _, o := range allowed {
		allow[strings.TrimRight(o, "/")] = struct{}{}
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			origin := r.Header.Get("Origin")
			if origin != "" {
				w.Header().Add("Vary", "Origin")
				_, listed := allow[strings.TrimRight(origin, "/")]
				switch {
				case listed:
					w.Header().Set("Access-Control-Allow-Origin", origin)
					w.Header().Set("Access-Control-Allow-Credentials", "true")
				case devAnyOrigin && len(allow) == 0:
					w.Header().Set("Access-Control-Allow-Origin", "*")
				}
				if w.Header().Get("Access-Control-Allow-Origin") != "" {
					w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
					w.Header().Set("Access-Control-Allow-Headers", "Accept, Authorization, Content-Type, X-Request-Id, X-Tenant-Id, X-Client-Type, Idempotency-Key")
					w.Header().Set("Access-Control-Max-Age", "86400")
				}
			}

			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusNoContent)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

func BodyLimitMiddleware(maxBytes int64) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			r.Body = http.MaxBytesReader(w, r.Body, maxBytes)
			next.ServeHTTP(w, r)
		})
	}
}

func AuthMiddleware(jwtManager *JWTManager) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			authHeader := r.Header.Get("Authorization")
			if authHeader == "" {
				WriteError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "Avtorizatsiya sarlavhasi talab qilinadi", nil)
				return
			}

			parts := strings.Split(authHeader, " ")
			if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
				WriteError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "Noto'g'ri Authorization formati. 'Bearer <token>' kutiladi", nil)
				return
			}

			claims, err := jwtManager.ValidateToken(parts[1])
			if err != nil {
				slog.Debug("jwt_rejected", slog.String("error", err.Error()), slog.String("req_id", GetRequestID(r)))
				WriteError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "Yaroqsiz yoki muddati o'tgan JWT token", nil)
				return
			}

			ctx := context.WithValue(r.Context(), UserIDKey, claims.UserID)
			ctx = context.WithValue(ctx, OrganizationIDKey, claims.OrganizationID)
			ctx = context.WithValue(ctx, UserRoleKey, claims.Role)
			ctx = context.WithValue(ctx, ClientTypeKey, claims.ClientType)

			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func TenantGuardMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		tokenOrgID, _ := r.Context().Value(OrganizationIDKey).(string)
		headerOrgID := r.Header.Get("X-Tenant-Id")

		if headerOrgID != "" && tokenOrgID != "" && headerOrgID != tokenOrgID {
			WriteError(w, r, http.StatusForbidden, "FORBIDDEN_TENANT", "Tashkilot konteksti mos kelmadi (IDOR himoyasi)", nil)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func RequireRole(allowedRoles ...string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			userRole, _ := r.Context().Value(UserRoleKey).(string)
			for _, role := range allowedRoles {
				if userRole == role || userRole == "platform_admin" {
					next.ServeHTTP(w, r)
					return
				}
			}
			WriteError(w, r, http.StatusForbidden, "FORBIDDEN_ROLE", "Ushbu amalni bajarish uchun ruxsat yetarli emas", nil)
		})
	}
}

func GetUserID(ctx context.Context) string {
	if val := ctx.Value(UserIDKey); val != nil {
		if s, ok := val.(string); ok {
			return s
		}
	}
	return ""
}

func GetOrgID(ctx context.Context) string {
	if val := ctx.Value(OrganizationIDKey); val != nil {
		if s, ok := val.(string); ok {
			return s
		}
	}
	return ""
}

// ClientIP haqiqiy mijoz manzilini qaytaradi. X-Real-IP / X-Forwarded-For ga FAQAT so'rov ishonchli proksidan
// (loopback yoki xususiy tarmoq: nginx, docker) kelganda ishoniladi; aks holda soxtalashtirish mumkin bo'lardi.
func ClientIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	peer, perr := netip.ParseAddr(host)
	if perr == nil && (peer.IsLoopback() || peer.IsPrivate()) {
		if v := strings.TrimSpace(r.Header.Get("X-Real-IP")); v != "" {
			if _, e := netip.ParseAddr(v); e == nil {
				return v
			}
		}
		if v := r.Header.Get("X-Forwarded-For"); v != "" {
			first := strings.TrimSpace(strings.Split(v, ",")[0])
			if _, e := netip.ParseAddr(first); e == nil {
				return first
			}
		}
	}
	return host
}

type rateBucket struct {
	count   int
	resetAt time.Time
}

// RateLimiter oddiy sobit-oynali (fixed window) tezlik chegarasi; kalit bo'yicha (IP yoki foydalanuvchi).
type RateLimiter struct {
	mu      sync.Mutex
	limit   int
	window  time.Duration
	buckets map[string]*rateBucket
	now     func() time.Time
}

func NewRateLimiter(limit int, window time.Duration) *RateLimiter {
	return &RateLimiter{limit: limit, window: window, buckets: make(map[string]*rateBucket), now: time.Now}
}

// Allow kalit uchun so'rovga ruxsat beradi. Ruxsat bo'lmasa qolgan kutish vaqtini qaytaradi.
func (l *RateLimiter) Allow(key string) (bool, time.Duration) {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	if len(l.buckets) > 10000 { // xotira o'sishining oldini olish
		for k, b := range l.buckets {
			if now.After(b.resetAt) {
				delete(l.buckets, k)
			}
		}
	}
	b, ok := l.buckets[key]
	if !ok || now.After(b.resetAt) {
		l.buckets[key] = &rateBucket{count: 1, resetAt: now.Add(l.window)}
		return true, 0
	}
	if b.count >= l.limit {
		return false, b.resetAt.Sub(now)
	}
	b.count++
	return true, 0
}

// RateLimitByIP middleware: mijoz IP si bo'yicha.
func RateLimitByIP(l *RateLimiter) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if ok, wait := l.Allow(ClientIP(r)); !ok {
				w.Header().Set("Retry-After", fmt.Sprintf("%d", int(wait.Seconds())+1))
				WriteError(w, r, http.StatusTooManyRequests, "RATE_LIMITED", "So'rovlar juda ko'p. Birozdan so'ng urinib ko'ring", nil)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// RateLimitByUser middleware: autentifikatsiyadan o'tgan foydalanuvchi bo'yicha (AuthMiddleware'dan keyin).
func RateLimitByUser(l *RateLimiter) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			key := GetUserID(r.Context())
			if key == "" {
				key = ClientIP(r)
			}
			if ok, wait := l.Allow(key); !ok {
				w.Header().Set("Retry-After", fmt.Sprintf("%d", int(wait.Seconds())+1))
				WriteError(w, r, http.StatusTooManyRequests, "RATE_LIMITED", "So'rovlar juda ko'p. Birozdan so'ng urinib ko'ring", nil)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
