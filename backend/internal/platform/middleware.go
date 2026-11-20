package platform

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"runtime/debug"
	"strings"
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

		log.Printf("[HTTP] %s %s | status: %d | duration: %v | ip: %s | req_id: %s",
			r.Method, r.URL.Path, rw.status, duration, r.RemoteAddr, GetRequestID(r))
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

func RecovererMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				log.Printf("[PANIC RECOVER] %v\nStack: %s", rec, string(debug.Stack()))
				WriteError(w, r, http.StatusInternalServerError, "INTERNAL_ERROR", "Kutilmagan server xatoligi yuz berdi", fmt.Sprintf("%v", rec))
			}
		}()
		next.ServeHTTP(w, r)
	})
}

func CORSMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin == "" {
			origin = "*"
		}
		w.Header().Set("Access-Control-Allow-Origin", origin)
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Accept, Authorization, Content-Type, X-Request-Id, X-Tenant-Id, X-Client-Type, Idempotency-Key")
		w.Header().Set("Access-Control-Allow-Credentials", "true")
		w.Header().Set("Access-Control-Max-Age", "86400")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
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
				WriteError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "Yaroqsiz yoki muddati o'tgan JWT token", err.Error())
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
				if userRole == role || userRole == "platform_admin" || userRole == "owner" {
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
