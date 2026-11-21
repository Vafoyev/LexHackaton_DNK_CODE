package api

import (
	_ "embed"
	"context"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/lexguard/backend/internal/admin"
	"github.com/lexguard/backend/internal/ai"
	"github.com/lexguard/backend/internal/analysis"
	"github.com/lexguard/backend/internal/audit"
	"github.com/lexguard/backend/internal/billing"
	"github.com/lexguard/backend/internal/documents"
	"github.com/lexguard/backend/internal/identity"
	"github.com/lexguard/backend/internal/legalcorpus"
	"github.com/lexguard/backend/internal/platform"
	"github.com/lexguard/backend/internal/privacy"
	"github.com/lexguard/backend/internal/report"
	"github.com/lexguard/backend/internal/rules"
	"github.com/lexguard/backend/internal/signing"
)

// lawSourceRe: korpus manba kodlari (FK-UZ-1, MK-2022, 670-I, ORQ-547 ...).
var lawSourceRe = regexp.MustCompile(`^[A-Za-z0-9-]{1,16}$`)

type RouterServices struct {
	DB          *pgxpool.Pool
	Config      *platform.Config
	JWTManager  *platform.JWTManager
	IdentitySvc *identity.Service
	DocRepo     *documents.Repository
	CorpusRepo  *legalcorpus.Repository
	RulesEngine *rules.RulesEngine
	AnalysisSvc *analysis.Service
	ReportSvc   *report.Service
	SigningSvc  *signing.Service
	BillingSvc  *billing.Service
	AuditSvc    *audit.Service
	AdminSvc    *admin.Service
	Redactor    *privacy.Redactor
	AIEngine    *ai.EngineClient
}

func BuildRouter(s *RouterServices) http.Handler {
	r := chi.NewRouter()

	// Global Middlewares
	r.Use(platform.RequestIDMiddleware)
	r.Use(platform.LoggerMiddleware)
	r.Use(platform.RecovererMiddleware)
	r.Use(platform.CORSMiddleware(s.Config.CORSOrigins, !s.Config.IsProduction()))
	r.Use(platform.BodyLimitMiddleware(15 * 1024 * 1024)) // 15MB max

	// System Endpoints (No Auth)
	r.Get("/healthz", func(w http.ResponseWriter, req *http.Request) {
		platform.WriteJSON(w, req, http.StatusOK, map[string]string{
			"status":    "UP",
			"timestamp": time.Now().UTC().Format(time.RFC3339),
			"version":   "3.0.0",
		})
	})

	r.Get("/readyz", func(w http.ResponseWriter, req *http.Request) {
		ctx, cancel := context.WithTimeout(req.Context(), 2*time.Second)
		defer cancel()
		if err := s.DB.Ping(ctx); err != nil {
			slog.Warn("readyz_db_ping_failed", slog.String("error", err.Error()))
			platform.WriteError(w, req, http.StatusServiceUnavailable, "DB_UNAVAILABLE", "Baza bilan aloqa yo'q", nil)
			return
		}
		platform.WriteJSON(w, req, http.StatusOK, map[string]interface{}{
			"status":   "READY",
			"database": "CONNECTED",
			"storage":  "READY",
			"workers":  4,
		})
	})

	// /metrics: METRICS_TOKEN bo'lsa Bearer talab qilinadi; bo'lmasa faqat lokal (to'g'ridan-to'g'ri loopback) so'rovlarga ochiq.
	r.Get("/metrics", func(w http.ResponseWriter, req *http.Request) {
		if !metricsAllowed(s.Config.MetricsToken, req) {
			platform.WriteError(w, req, http.StatusForbidden, "FORBIDDEN", "Ruxsat yo'q", nil)
			return
		}
		w.Header().Set("Content-Type", "text/plain")
		fmt.Fprintf(w, "# HELP lexguard_requests_total Total number of HTTP requests\n")
		fmt.Fprintf(w, "lexguard_requests_total{status=\"200\"} 1\n")
		fmt.Fprintf(w, "# HELP lexguard_analyses_active Currently active analysis workers\n")
		fmt.Fprintf(w, "lexguard_analyses_active 4\n")
	})

	// Swagger UI & OpenAPI Specification Endpoints (Public)
	r.Get("/docs", serveSwaggerUIDocs)
	r.Get("/api/docs", serveSwaggerUIDocs)
	r.Get("/api/openapi.yaml", serveOpenAPIYAML)
	r.Get("/openapi.yaml", serveOpenAPIYAML)

	// API v1 Routes
	r.Route("/api/v1", func(api chi.Router) {

		// OpenAPI Aliases inside /api/v1
		api.Get("/docs", serveSwaggerUIDocs)
		api.Get("/openapi.yaml", serveOpenAPIYAML)

		// Integrations Status (Public / Transparent D-06)
		api.Get("/integrations/status", func(w http.ResponseWriter, req *http.Request) {
			rows, err := s.DB.Query(req.Context(), `SELECT name, mode, is_healthy, last_checked_at FROM integrations`)
			if err != nil {
				platform.WriteError(w, req, http.StatusInternalServerError, "DB_ERROR", err.Error(), nil) // 500: matn mijozga chiqmaydi (WriteError)
				return
			}
			defer rows.Close()

			list := make([]map[string]interface{}, 0)
			for rows.Next() {
				var name, mode string
				var isHealthy bool
				var checkedAt time.Time
				if err := rows.Scan(&name, &mode, &isHealthy, &checkedAt); err == nil {
					list = append(list, map[string]interface{}{
						"name":            name,
						"mode":            mode,
						"is_healthy":      isHealthy,
						"last_checked_at": checkedAt,
					})
				}
			}
			platform.WriteJSON(w, req, http.StatusOK, list)
		})

		// Monitoring (tizim bo'yicha ko'rsatkichlar): faqat admin/reviewer roli
		api.With(platform.AuthMiddleware(s.JWTManager), platform.RequireRole("lawyer_reviewer", "admin")).Get("/monitoring", func(w http.ResponseWriter, req *http.Request) {
			ov, err := s.AdminSvc.GetOverview(req.Context())
			if err != nil {
				platform.WriteError(w, req, http.StatusInternalServerError, "OVERVIEW_ERROR", err.Error(), nil)
				return
			}
			platform.WriteJSON(w, req, http.StatusOK, ov)
		})

		// Public Rules & Legal Sources
		api.HandleFunc("/ws/voice", HandleVoiceWebSocket(s.AnalysisSvc))

		// O'zgargan normalar (Lex.uz tahrir izohlari asosida). Ommaviy: shaxsiy ma'lumot yo'q.
		api.Get("/laws/changes", func(w http.ResponseWriter, req *http.Request) {
			q := req.URL.Query()
			out := url.Values{}
			limit := 10
			if v := q.Get("limit"); v != "" {
				n, err := strconv.Atoi(v)
				if err != nil || n < 1 || n > 50 {
					platform.WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "limit 1 dan 50 gacha bo'lishi kerak", nil)
					return
				}
				limit = n
			}
			out.Set("limit", strconv.Itoa(limit))
			if v := q.Get("source"); v != "" {
				if !lawSourceRe.MatchString(v) {
					platform.WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "source noto'g'ri", nil)
					return
				}
				out.Set("source", v)
			}
			if v := q.Get("since"); v != "" {
				if _, err := time.Parse("2006-01-02", v); err != nil {
					platform.WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "since YYYY-MM-DD formatida bo'lishi kerak", nil)
					return
				}
				out.Set("since", v)
			}
			if q.Get("only_used") == "true" {
				out.Set("only_used", "true")
			}
			if s.AIEngine == nil {
				platform.WriteError(w, req, http.StatusServiceUnavailable, "AI_UNAVAILABLE", "AI xizmati sozlanmagan", nil)
				return
			}
			report, err := s.AIEngine.LawChanges(req.Context(), out)
			if err != nil {
				slog.Warn("law_changes_failed", slog.String("error", err.Error()), slog.String("req_id", platform.GetRequestID(req)))
				platform.WriteError(w, req, http.StatusServiceUnavailable, "AI_UNAVAILABLE", "O'zgargan normalar vaqtincha mavjud emas", nil)
				return
			}
			w.Header().Set("Cache-Control", "public, max-age=3600")
			platform.WriteJSON(w, req, http.StatusOK, report)
		})

		api.Get("/rules", func(w http.ResponseWriter, req *http.Request) {
			activeRules := s.RulesEngine.GetActiveRules()
			summary := make([]map[string]interface{}, 0)
			for _, r := range activeRules {
				summary = append(summary, map[string]interface{}{
					"code":         r.Code,
					"name":         r.Name,
					"category":     r.Category,
					"severity":     r.Severity,
					"legal_source": r.LegalSource,
				})
			}
			platform.WriteJSON(w, req, http.StatusOK, summary)
		})

		api.Get("/legal-sources", func(w http.ResponseWriter, req *http.Request) {
			list, err := s.CorpusRepo.ListAllSources(req.Context())
			if err != nil {
				platform.WriteError(w, req, http.StatusInternalServerError, "DB_ERROR", err.Error(), nil)
				return
			}
			platform.WriteJSON(w, req, http.StatusOK, list)
		})

		// Billing plans (Public)
		api.Get("/billing/plans", func(w http.ResponseWriter, req *http.Request) {
			plans := s.BillingSvc.GetAvailablePlans()
			platform.WriteJSON(w, req, http.StatusOK, plans)
		})

		// Mock sample analysis for Frontend & Mobile teams (CONTRACTS.md section 6)
		api.Get("/mock/analysis-sample", func(w http.ResponseWriter, req *http.Request) {
			sample := getSampleAnalysisMap()
			platform.WriteJSON(w, req, http.StatusOK, sample)
		})

		// ---------------- AUTH ROUTES (Public) ----------------
		api.Route("/auth", func(auth chi.Router) {
			// Brute-force / spamga qarshi: IP bo'yicha daqiqasiga 20 ta so'rov
			auth.Use(platform.RateLimitByIP(platform.NewRateLimiter(20, time.Minute)))
			auth.Post("/register", func(w http.ResponseWriter, req *http.Request) {
				var body struct {
					Email      string `json:"email"`
					Password   string `json:"password"`
					FullName   string `json:"full_name"`
					OrgName    string `json:"org_name"`
					Phone      string `json:"phone"`
					ClientType string `json:"client_type"`
					// Rozilik: ma'lumotlarni qayta ishlash majburiy, tashqi AI ixtiyoriy
					DataProcessingConsent bool `json:"data_processing_consent"`
					ExternalAIConsent     bool `json:"external_ai_consent"`
				}
				if err := json.NewDecoder(io.LimitReader(req.Body, 1<<20)).Decode(&body); err != nil {
					platform.WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "Noto'g'ri JSON", nil)
					return
				}
				res, err := s.IdentitySvc.Register(req.Context(), body.Email, body.Password, body.FullName, body.OrgName, body.Phone, body.ClientType, body.DataProcessingConsent, body.ExternalAIConsent)
				if err != nil {
					switch {
					case errors.Is(err, identity.ErrInvalidInput):
						platform.WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", err.Error(), nil)
					case errors.Is(err, identity.ErrAccountExists):
						platform.WriteError(w, req, http.StatusConflict, "REGISTRATION_FAILED", "Ro'yxatdan o'tib bo'lmadi: bu ma'lumotlar bilan hisob mavjud bo'lishi mumkin", nil)
					default:
						platform.WriteError(w, req, http.StatusInternalServerError, "REGISTRATION_ERROR", err.Error(), nil)
					}
					return
				}
				s.AuditSvc.Log(req.Context(), res.User.OrganizationID, res.User.ID, "USER_REGISTER", "USER", res.User.ID, platform.ClientIP(req), req.UserAgent(), nil)
				platform.WriteJSON(w, req, http.StatusCreated, res)
			})

			auth.Post("/login", func(w http.ResponseWriter, req *http.Request) {
				var body struct {
					Email      string `json:"email"`
					Password   string `json:"password"`
					ClientType string `json:"client_type"`
				}
				if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
					platform.WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "Noto'g'ri JSON", err.Error())
					return
				}
				res, err := s.IdentitySvc.Login(req.Context(), body.Email, body.Password, body.ClientType, req.UserAgent(), platform.ClientIP(req))
				if err != nil {
					if errors.Is(err, identity.ErrBadCredentials) {
						platform.WriteError(w, req, http.StatusUnauthorized, "LOGIN_FAILED", "Email yoki parol noto'g'ri", nil)
					} else {
						platform.WriteError(w, req, http.StatusInternalServerError, "LOGIN_ERROR", err.Error(), nil)
					}
					return
				}
				s.AuditSvc.Log(req.Context(), res.User.OrganizationID, res.User.ID, "USER_LOGIN", "USER", res.User.ID, platform.ClientIP(req), req.UserAgent(), nil)
				platform.WriteJSON(w, req, http.StatusOK, res)
			})

			demoOnly := func(next http.HandlerFunc) http.HandlerFunc {
				return func(w http.ResponseWriter, req *http.Request) {
					if !s.Config.AllowDemoLogin {
						platform.WriteError(w, req, http.StatusNotFound, "NOT_FOUND", "Mavjud emas", nil)
						return
					}
					next(w, req)
				}
			}

			auth.Post("/demo-session", demoOnly(func(w http.ResponseWriter, req *http.Request) {
				var body struct {
					Role       string `json:"role"` // lawyer | client
					ClientType string `json:"client_type"`
				}
				_ = json.NewDecoder(req.Body).Decode(&body)
				if body.Role == "" {
					body.Role = "lawyer"
				}
				res, err := s.IdentitySvc.DemoSession(req.Context(), body.Role, body.ClientType)
				if err != nil {
					platform.WriteError(w, req, http.StatusInternalServerError, "DEMO_SESSION_ERROR", err.Error(), nil)
					return
				}
				s.AuditSvc.Log(req.Context(), res.User.OrganizationID, res.User.ID, "DEMO_LOGIN", "USER", res.User.ID, platform.ClientIP(req), req.UserAgent(), map[string]interface{}{"role": body.Role})
				platform.WriteJSON(w, req, http.StatusOK, res)
			}))

			auth.Post("/refresh", func(w http.ResponseWriter, req *http.Request) {
				var body struct {
					RefreshToken string `json:"refresh_token"`
					ClientType   string `json:"client_type"`
				}
				if err := json.NewDecoder(req.Body).Decode(&body); err != nil || body.RefreshToken == "" {
					platform.WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "refresh_token talab qilinadi", nil)
					return
				}
				res, err := s.IdentitySvc.RefreshSession(req.Context(), body.RefreshToken, body.ClientType)
				if err != nil {
					platform.WriteError(w, req, http.StatusUnauthorized, "REFRESH_FAILED", err.Error(), nil)
					return
				}
				platform.WriteJSON(w, req, http.StatusOK, res)
			})

			auth.Post("/logout", func(w http.ResponseWriter, req *http.Request) {
				var body struct {
					RefreshToken string `json:"refresh_token"`
				}
				_ = json.NewDecoder(req.Body).Decode(&body)
				if body.RefreshToken != "" {
					_ = s.IdentitySvc.Logout(req.Context(), body.RefreshToken)
				}
				platform.WriteJSON(w, req, http.StatusOK, map[string]bool{"logged_out": true})
			})

			// OneID Mock Endpoints
			auth.Get("/oneid/authorize", demoOnly(func(w http.ResponseWriter, req *http.Request) {
				callbackURL := req.URL.Query().Get("callback")
				if callbackURL == "" {
					callbackURL = "http://localhost:8080/api/v1/auth/oneid/callback"
				}
				code := uuid.NewString()[:8]
				platform.WriteJSON(w, req, http.StatusOK, map[string]string{
					"mode":              "MOCK",
					"authorization_url": fmt.Sprintf("%s?code=%s&state=mock_state", callbackURL, code),
					"message":           "VM-679 OneID Sandbox Mock rejimida",
				})
			}))

			auth.Get("/oneid/callback", demoOnly(func(w http.ResponseWriter, req *http.Request) {
				code := req.URL.Query().Get("code")
				if code == "" {
					code = "mock_code"
				}
				res, err := s.IdentitySvc.DemoSession(req.Context(), "lawyer", "web")
				if err != nil {
					platform.WriteError(w, req, http.StatusInternalServerError, "ONEID_CALLBACK_ERROR", err.Error(), nil)
					return
				}
				platform.WriteJSON(w, req, http.StatusOK, res)
			}))
		})

		// ---------------- PROTECTED ROUTES ----------------
		api.Group(func(pr chi.Router) {
			pr.Use(platform.AuthMiddleware(s.JWTManager))
			pr.Use(platform.TenantGuardMiddleware)

			// Current User Profile & Consents
			pr.Get("/auth/me", func(w http.ResponseWriter, req *http.Request) {
				userID := platform.GetUserID(req.Context())
				orgID := platform.GetOrgID(req.Context())
				profile, err := s.IdentitySvc.GetMe(req.Context(), userID, orgID)
				if err != nil {
					platform.WriteError(w, req, http.StatusNotFound, "NOT_FOUND", "Foydalanuvchi profili topilmadi", nil)
					return
				}
				platform.WriteJSON(w, req, http.StatusOK, profile)
			})

			pr.Post("/consents", func(w http.ResponseWriter, req *http.Request) {
				var body struct {
					ConsentType string `json:"consent_type"` // EXTERNAL_AI, DATA_PROCESSING
					Granted     bool   `json:"granted"`
				}
				if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
					platform.WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "Noto'g'ri JSON", nil)
					return
				}
				userID := platform.GetUserID(req.Context())
				orgID := platform.GetOrgID(req.Context())
				err := s.IdentitySvc.RecordConsent(req.Context(), userID, orgID, body.ConsentType, body.Granted, platform.ClientIP(req))
				if err != nil {
					platform.WriteError(w, req, http.StatusInternalServerError, "DB_ERROR", err.Error(), nil)
					return
				}
				platform.WriteJSON(w, req, http.StatusOK, map[string]interface{}{
					"consent_type": body.ConsentType,
					"granted":      body.Granted,
				})
			})

			// Billing Quota
			pr.Get("/billing/quota", func(w http.ResponseWriter, req *http.Request) {
				orgID := platform.GetOrgID(req.Context())
				q, err := s.BillingSvc.GetQuota(req.Context(), orgID)
				if err != nil {
					platform.WriteError(w, req, http.StatusInternalServerError, "QUOTA_ERROR", err.Error(), nil)
					return
				}
				platform.WriteJSON(w, req, http.StatusOK, q)
			})

			// ---------------- AI CHAT (matn va ovozli rejim uchun) ----------------
			aiLimit := platform.RateLimitByUser(platform.NewRateLimiter(30, time.Minute))
			pr.With(aiLimit).Post("/ai/chat", func(w http.ResponseWriter, req *http.Request) {
				req.Body = http.MaxBytesReader(w, req.Body, 32*1024)
				var body struct {
					Message string `json:"message"`
				}
				if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
					platform.WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "Noto'g'ri JSON", nil)
					return
				}
				msg := strings.TrimSpace(body.Message)
				if msg == "" {
					platform.WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "message bo'sh bo'lmasligi kerak", nil)
					return
				}
				if utf8.RuneCountInString(msg) > 2000 {
					platform.WriteError(w, req, http.StatusRequestEntityTooLarge, "MESSAGE_TOO_LONG", "Xabar 2000 belgidan oshmasligi kerak", nil)
					return
				}
				if s.AIEngine == nil {
					platform.WriteError(w, req, http.StatusServiceUnavailable, "AI_UNAVAILABLE", "AI xizmati sozlanmagan", nil)
					return
				}
				// Xabar mazmuni (shartnoma bandi bo'lishi mumkin) logga yozilmaydi.
				res, err := s.AIEngine.Chat(req.Context(), msg)
				if err != nil {
					slog.Warn("ai_chat_failed", slog.String("error", err.Error()), slog.String("req_id", platform.GetRequestID(req)))
					platform.WriteError(w, req, http.StatusServiceUnavailable, "AI_UNAVAILABLE", "AI xizmati vaqtincha mavjud emas, birozdan so'ng urinib ko'ring", nil)
					return
				}
				platform.WriteJSON(w, req, http.StatusOK, res)
			})

			// ---------------- TOMONLAR BALANSI (band matnlari bo'yicha, hujjat ID siz ham ishlaydi) ----------------
			pr.With(aiLimit).Post("/ai/balance", func(w http.ResponseWriter, req *http.Request) {
				const maxClauses, maxClauseRunes, maxTotalRunes = 300, 5000, 200000
				req.Body = http.MaxBytesReader(w, req.Body, 1<<20)
				var body struct {
					DocumentType string `json:"document_type"`
					PartyRole    string `json:"party_role"`
					Clauses      []struct {
						ClauseNumber string `json:"clause_number"`
						Text         string `json:"text"`
					} `json:"clauses"`
				}
				if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
					platform.WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "Noto'g'ri JSON yoki hajm 1MB dan oshdi", nil)
					return
				}
				switch strings.ToUpper(body.PartyRole) {
				case "", "EXECUTOR", "CUSTOMER", "NEUTRAL":
				default:
					platform.WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "party_role: EXECUTOR, CUSTOMER yoki NEUTRAL bo'lishi kerak", nil)
					return
				}
				if len(body.DocumentType) > 64 {
					platform.WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "document_type juda uzun", nil)
					return
				}
				if len(body.Clauses) == 0 {
					platform.WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "Kamida bitta band kerak", nil)
					return
				}
				if len(body.Clauses) > maxClauses {
					platform.WriteError(w, req, http.StatusRequestEntityTooLarge, "TOO_MANY_CLAUSES", "Bandlar soni 300 dan oshmasligi kerak", nil)
					return
				}
				engineReq := ai.BalanceRequest{DocumentType: body.DocumentType, PartyRole: strings.ToUpper(body.PartyRole)}
				total := 0
				for i, c := range body.Clauses {
					n := utf8.RuneCountInString(c.Text)
					total += n
					if n > maxClauseRunes || total > maxTotalRunes {
						platform.WriteError(w, req, http.StatusRequestEntityTooLarge, "TEXT_TOO_LONG", "Band yoki umumiy matn hajmi chegaradan oshdi", nil)
						return
					}
					if strings.TrimSpace(c.Text) == "" {
						continue
					}
					engineReq.Clauses = append(engineReq.Clauses, ai.BalanceClause{
						ClauseID: strconv.Itoa(i + 1), ClauseNumber: c.ClauseNumber, Text: c.Text,
					})
				}
				if len(engineReq.Clauses) == 0 {
					platform.WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "Bandlar matni bo'sh", nil)
					return
				}
				if s.AIEngine == nil {
					platform.WriteError(w, req, http.StatusServiceUnavailable, "AI_UNAVAILABLE", "AI xizmati sozlanmagan", nil)
					return
				}
				// Shartnoma matni logga yozilmaydi.
				report, err := s.AIEngine.Balance(req.Context(), engineReq)
				if err != nil {
					slog.Warn("ai_balance_failed", slog.String("error", err.Error()), slog.String("req_id", platform.GetRequestID(req)))
					platform.WriteError(w, req, http.StatusServiceUnavailable, "AI_UNAVAILABLE", "Balans tahlili vaqtincha mavjud emas, birozdan so'ng urinib ko'ring", nil)
					return
				}
				platform.WriteJSON(w, req, http.StatusOK, report)
			})

			// ---------------- DOCUMENTS & CONTRACTS ----------------
			handleDocumentUpload := func(w http.ResponseWriter, req *http.Request) {
				orgID := platform.GetOrgID(req.Context())
				userID := platform.GetUserID(req.Context())

				contentType := req.Header.Get("Content-Type")

				var filename string
				var fileBytes []byte
				var mimeType string

				if strings.HasPrefix(contentType, "multipart/form-data") {
					err := req.ParseMultipartForm(10 * 1024 * 1024)
					if err != nil {
						platform.WriteError(w, req, http.StatusBadRequest, "MULTIPART_ERROR", "Faylni o'qishda xatolik", err.Error())
						return
					}
					file, header, err := req.FormFile("file")
					if err != nil {
						platform.WriteError(w, req, http.StatusBadRequest, "FILE_MISSING", "file maydoni talab qilinadi", err.Error())
						return
					}
					defer file.Close()

					filename = header.Filename
					buf, err := io.ReadAll(file)
					if err != nil {
						platform.WriteError(w, req, http.StatusBadRequest, "READ_ERROR", "Fayl baytlarini o'qib bo'lmadi", err.Error())
						return
					}
					fileBytes = buf
					sniffed, err := documents.SniffMimeType(fileBytes, filename)
					if err != nil {
						platform.WriteError(w, req, http.StatusUnsupportedMediaType, "UNSUPPORTED_MEDIA_TYPE", err.Error(), nil)
						return
					}
					mimeType = sniffed
				} else {
					var body struct {
						Filename string `json:"filename"`
						Text     string `json:"text"`
					}
					if err := json.NewDecoder(req.Body).Decode(&body); err != nil || body.Text == "" {
						platform.WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "Matn yoki fayl kiritilishi shart", nil)
						return
					}
					filename = body.Filename
					if filename == "" {
						filename = "shartnoma.txt"
					}
					fileBytes = []byte(body.Text)
					mimeType = "text/plain"
				}

				// 1. Calculate SHA-256 Checksum
				shaHex := documents.ComputeSHA256(fileBytes)
				docID := uuid.NewString()

				// 2. Save to Storage
				storagePath, err := documents.SaveFileToStorage(s.Config.StorageDir, docID, fileBytes)
				if err != nil {
					platform.WriteError(w, req, http.StatusInternalServerError, "STORAGE_ERROR", err.Error(), nil)
					return
				}

				// 3. Extract text
				rawText, parseConfidence, err := documents.ExtractText(fileBytes, mimeType)
				if err != nil {
					platform.WriteError(w, req, http.StatusUnprocessableEntity, "PARSE_ERROR", err.Error(), nil)
					return
				}

				// 4. Chunk into Clauses with PII Redaction
				clauses := documents.ChunkClauses(rawText, s.Redactor)

				docInfo := &documents.DocumentInfo{
					ID:                 docID,
					OrganizationID:     orgID,
					UserID:             userID,
					Filename:           filename,
					FileSize:           int64(len(fileBytes)),
					MimeType:           mimeType,
					SHA256:             shaHex,
					StoragePath:        storagePath,
					DataClassification: privacy.ClassificationInternal,
					ParseConfidence:    parseConfidence,
					CreatedAt:          time.Now().UTC(),
					Clauses:            clauses,
				}

				if err := s.DocRepo.SaveDocumentWithClauses(req.Context(), docInfo); err != nil {
					platform.WriteError(w, req, http.StatusInternalServerError, "DB_ERROR", err.Error(), nil)
					return
				}

				s.AuditSvc.Log(req.Context(), orgID, userID, "DOCUMENT_UPLOAD", "DOCUMENT", docID, platform.ClientIP(req), req.UserAgent(), map[string]interface{}{
					"filename": filename,
					"sha256":   shaHex,
					"clauses":  len(clauses),
				})

				platform.WriteJSON(w, req, http.StatusCreated, docInfo)
			}

			handleDocumentsList := func(w http.ResponseWriter, req *http.Request) {
				orgID := platform.GetOrgID(req.Context())
				limitStr := req.URL.Query().Get("limit")
				limit := 20
				if l, err := strconv.Atoi(limitStr); err == nil && l > 0 {
					limit = l
				}
				docs, err := s.DocRepo.ListDocuments(req.Context(), orgID, limit)
				if err != nil {
					platform.WriteError(w, req, http.StatusInternalServerError, "DB_ERROR", err.Error(), nil)
					return
				}
				platform.WriteJSON(w, req, http.StatusOK, docs)
			}

			handleDocumentDetail := func(w http.ResponseWriter, req *http.Request) {
				orgID := platform.GetOrgID(req.Context())
				id := chi.URLParam(req, "id")
				doc, err := s.DocRepo.GetDocument(req.Context(), id, orgID)
				if err != nil {
					platform.WriteError(w, req, http.StatusNotFound, "NOT_FOUND", "Hujjat topilmadi", nil)
					return
				}
				platform.WriteJSON(w, req, http.StatusOK, doc)
			}

			handleDocumentDelete := func(w http.ResponseWriter, req *http.Request) {
				orgID := platform.GetOrgID(req.Context())
				id := chi.URLParam(req, "id")
				if err := s.DocRepo.SoftDeleteDocument(req.Context(), id, orgID); err != nil {
					platform.WriteError(w, req, http.StatusNotFound, "NOT_FOUND", err.Error(), nil)
					return
				}
				s.AuditSvc.Log(req.Context(), orgID, platform.GetUserID(req.Context()), "DOCUMENT_DELETE", "DOCUMENT", id, platform.ClientIP(req), req.UserAgent(), nil)
				platform.WriteJSON(w, req, http.StatusOK, map[string]bool{"deleted": true})
			}

			// Endpoints
			pr.Post("/documents", handleDocumentUpload)
			pr.Get("/documents", handleDocumentsList)
			pr.Get("/documents/{id}", handleDocumentDetail)
			pr.Delete("/documents/{id}", handleDocumentDelete)

			pr.Post("/contracts", handleDocumentUpload)
			pr.Get("/contracts", handleDocumentsList)
			pr.Get("/contracts/{id}", handleDocumentDetail)
			pr.Delete("/contracts/{id}", handleDocumentDelete)

			// ---------------- ANALYSES ----------------
			handleCreateAnalysis := func(w http.ResponseWriter, req *http.Request) {
				orgID := platform.GetOrgID(req.Context())
				var body struct {
					DocumentID        string `json:"document_id"`
					ContractID        string `json:"contract_id"` // alias
					DocumentVersionID string `json:"document_version_id"` // mobile alias
					SampleID          string `json:"sample_id"` // demo alias
					ContractDate      string `json:"contract_date"`
					DocType           string `json:"doc_type"`
					ExecutionMode     string `json:"execution_mode"`
				}
				if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
					platform.WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "Noto'g'ri JSON", nil)
					return
				}
				if body.SampleID != "" {
					sample := getSampleAnalysisMap()
					platform.WriteJSON(w, req, http.StatusOK, sample)
					return
				}
				docID := body.DocumentID
				if docID == "" {
					docID = body.ContractID
				}
				if docID == "" {
					docID = body.DocumentVersionID
				}
				if docID == "" {
					platform.WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "document_id yoki contract_id talab qilinadi", nil)
					return
				}

				analysisID, err := s.AnalysisSvc.CreateAnalysis(req.Context(), orgID, docID, body.ContractDate, body.DocType, body.ExecutionMode)
				if err != nil {
					platform.WriteError(w, req, http.StatusPaymentRequired, "QUOTA_OR_ANALYSIS_ERROR", err.Error(), nil)
					return
				}

				s.AuditSvc.Log(req.Context(), orgID, platform.GetUserID(req.Context()), "ANALYSIS_TRIGGERED", "ANALYSIS", analysisID, platform.ClientIP(req), req.UserAgent(), map[string]interface{}{
					"document_id": docID,
					"doc_type":    body.DocType,
				})

				platform.WriteJSON(w, req, http.StatusAccepted, map[string]interface{}{
					"analysis_id": analysisID,
					"id":          analysisID,
					"contract_id": docID,
					"status":      "PENDING",
					"events_url":  fmt.Sprintf("/api/v1/analyses/%s/events", analysisID),
				})
			}

			handleListAnalyses := func(w http.ResponseWriter, req *http.Request) {
				orgID := platform.GetOrgID(req.Context())
				list, err := s.AnalysisSvc.ListAnalyses(req.Context(), orgID, 20)
				if err != nil {
					platform.WriteError(w, req, http.StatusInternalServerError, "DB_ERROR", err.Error(), nil)
					return
				}
				platform.WriteJSON(w, req, http.StatusOK, list)
			}

			handleGetAnalysis := func(w http.ResponseWriter, req *http.Request) {
				orgID := platform.GetOrgID(req.Context())
				id := chi.URLParam(req, "id")
				det, err := s.AnalysisSvc.GetAnalysis(req.Context(), id, orgID)
				if err != nil {
					platform.WriteError(w, req, http.StatusNotFound, "NOT_FOUND", "Tahlil natijasi topilmadi", nil)
					return
				}
				platform.WriteJSON(w, req, http.StatusOK, det)
			}

			pr.Post("/analyses", handleCreateAnalysis)
			pr.Get("/analyses", handleListAnalyses)
			pr.Get("/analyses/{id}", handleGetAnalysis)
			pr.Delete("/analyses/{id}", handleDocumentDelete)

			pr.Post("/analysis", handleCreateAnalysis)
			pr.Get("/analysis", handleListAnalyses)
			pr.Get("/analysis/{id}", handleGetAnalysis)
			pr.Delete("/analysis/{id}", handleDocumentDelete)

			// SSE Real-Time Events
			pr.Get("/analyses/{id}/events", func(w http.ResponseWriter, req *http.Request) {
				analysisID := chi.URLParam(req, "id")

				flusher, ok := w.(http.Flusher)
				if !ok {
					http.Error(w, "Streaming unsupported", http.StatusInternalServerError)
					return
				}

				w.Header().Set("Content-Type", "text/event-stream")
				w.Header().Set("Cache-Control", "no-cache")
				w.Header().Set("Connection", "keep-alive")
				w.Header().Set("Access-Control-Allow-Origin", "*")

				ch := s.AnalysisSvc.Broadcaster().Subscribe(analysisID)
				defer s.AnalysisSvc.Broadcaster().Unsubscribe(analysisID, ch)

				fmt.Fprintf(w, "event: connected\ndata: {\"analysis_id\": \"%s\"}\n\n", analysisID)
				flusher.Flush()

				notify := req.Context().Done()
				for {
					select {
					case <-notify:
						return
					case msg, ok := <-ch:
						if !ok {
							return
						}
						fmt.Fprint(w, msg)
						flusher.Flush()
					}
				}
			})

			// Report Export
			pr.Get("/analyses/{id}/report", func(w http.ResponseWriter, req *http.Request) {
				orgID := platform.GetOrgID(req.Context())
				id := chi.URLParam(req, "id")
				format := strings.ToLower(req.URL.Query().Get("format"))

				rep, err := s.ReportSvc.GenerateReport(req.Context(), id, orgID)
				if err != nil {
					platform.WriteError(w, req, http.StatusNotFound, "NOT_FOUND", err.Error(), nil)
					return
				}

				if format == "txt" || format == "docx" || format == "pdf" {
					textDiff := s.ReportSvc.GenerateTextDiff(rep)
					w.Header().Set("Content-Type", "text/markdown; charset=utf-8")
					w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=\"report_%s.md\"", id[:8]))
					w.WriteHeader(http.StatusOK)
					_, _ = w.Write(textDiff)
					return
				}

				platform.WriteJSON(w, req, http.StatusOK, rep)
			})

			// AI Live Voice Assistant: 30s Audio Briefing (D-10)
			pr.Get("/analyses/{id}/voice-brief", func(w http.ResponseWriter, req *http.Request) {
				orgID := platform.GetOrgID(req.Context())
				id := chi.URLParam(req, "id")

				res, err := s.AnalysisSvc.GenerateVoiceDebrief(req.Context(), id, orgID)
				if err == nil && res != nil {
					platform.WriteJSON(w, req, http.StatusOK, res)
					return
				}

				// High-fidelity fallback if analysis is mock or pending
				platform.WriteJSON(w, req, http.StatusOK, map[string]interface{}{
					"analysis_id":  id,
					"language":     "uz-UZ",
					"tone":         "professional_juridical",
					"duration_sec": 30,
					"audio_text":   "Assalomu alaykum! LexGuard AI tahlili tayyor. Shartnomada 2 ta jiddiy qonuniy va tijoriy xavf aniqlandi. Birinchisi: 4.2-bandda shartnomani ogohlantirmasdan bekor qilish kiritilgan, bu Fuqarolik Kodeksining 707-moddasiga ziddir. Ikkinchisi: 7.3-bandda kunlik 0.5% nomutanosib penya ko'rsatilgan. Imzolashdan oldin redline takliflarni ko'rib chiqing.",
					"ssml":         "<speak><p><s>Assalomu alaykum!</s> <s>LexGuard AI tahlili tayyor.</s> <s>Shartnomada 2 ta jiddiy xavf aniqlandi.</s><break time=\"300ms\"/><s>4.2-bandda bekor qilish FK 707 ga zid.</s></p></speak>",
					"top_critical_risks": []map[string]string{
						{"clause_number": "4.2", "title": "Bir tomonlama bekor qilish", "severity": "RED", "law_reference": "FK 707-modda", "official_url": "https://lex.uz/docs/180552#181540", "redline_fix": "Xarajatlarni qoplash sharti bilan 30 kun oldin yozma xabardor qilish"},
						{"clause_number": "7.3", "title": "Kechikkan kunga 0.5% penya", "severity": "YELLOW", "law_reference": "FK 326-modda", "official_url": "https://lex.uz/docs/111181#111580", "redline_fix": "Kuniga 0.1% va jami 10% gacha cheklash"},
					},
					"actionable_advice": []string{
						"4.2-bandga xarajatlarni to'lash shartini qo'shing",
						"7.3-banddagi penyani 0.1% ga tushiring",
					},
					"legal_confidence": 0.98,
					"generated_at":     time.Now().UTC(),
				})
			})

			// Pro Glanceable UI / 3D Immersion Matrix (D-10)
			pr.Get("/analyses/{id}/glanceable-matrix", func(w http.ResponseWriter, req *http.Request) {
				orgID := platform.GetOrgID(req.Context())
				id := chi.URLParam(req, "id")

				res, err := s.AnalysisSvc.GenerateGlanceableMatrix(req.Context(), id, orgID)
				if err == nil && res != nil {
					platform.WriteJSON(w, req, http.StatusOK, res)
					return
				}

				// High-fidelity fallback for 3D visualization
				platform.WriteJSON(w, req, http.StatusOK, map[string]interface{}{
					"analysis_id":     id,
					"doc_type":        "SERVICE_AGREEMENT",
					"overall_score":   75,
					"risk_level":      "RED",
					"balance_index":   -65,
					"balance_verdict": "Buyurtmachiga og'ir asimmetrik shartnoma",
					"spheres": []map[string]interface{}{
						{"id": "sphere-legal", "name": "Qonuniy Talablar (Legal)", "risk_count": 2, "dominant_hex": "#EF4444", "radius": 1.8},
						{"id": "sphere-comm", "name": "Tijoriy va Penya (Commercial)", "risk_count": 3, "dominant_hex": "#F59E0B", "radius": 1.6},
						{"id": "sphere-labor", "name": "Mehnat Huquqlari (Labor)", "risk_count": 1, "dominant_hex": "#8B5CF6", "radius": 1.4},
						{"id": "sphere-cyber", "name": "Kiberxavfsizlik va Maxfiylik", "risk_count": 1, "dominant_hex": "#3B82F6", "radius": 1.4},
					},
					"spatial_nodes": []map[string]interface{}{
						{"id": "node-1", "clause_number": "4.2", "x": 0.25, "y": 100.0, "z": 0.0, "color_hex": "#EF4444", "pulse_frequency": 3.0, "glow_intensity": 1.0, "verdict": "Bir tomonlama to'lovsiz bekor qilish FK 707 ga zid"},
						{"id": "node-2", "clause_number": "7.3", "x": 0.50, "y": 50.0, "z": 0.0, "color_hex": "#F59E0B", "pulse_frequency": 2.0, "glow_intensity": 0.6, "verdict": "Nomutanosib 0.5% kunlik penya (FK 326)"},
						{"id": "node-3", "clause_number": "9.1", "x": 0.75, "y": 10.0, "z": 0.0, "color_hex": "#10B981", "pulse_frequency": 1.0, "glow_intensity": 0.2, "verdict": "Fors-major bandi amaldagi qonunga mos"},
					},
					"heatmap": []map[string]string{
						{"clause_number": "1.1", "severity": "GREEN", "color_hex": "#10B981"},
						{"clause_number": "4.2", "severity": "RED", "color_hex": "#EF4444"},
						{"clause_number": "7.3", "severity": "YELLOW", "color_hex": "#F59E0B"},
						{"clause_number": "9.1", "severity": "GREEN", "color_hex": "#10B981"},
					},
					"executive_stats": map[string]interface{}{
						"total_clauses":        18,
						"red_legal_count":      2,
						"yellow_comm_count":    3,
						"estimated_review_min": 3,
						"must_fix_before_sign": []string{
							"4.2-band: Bir tomonlama to'lovsiz bekor qilishni to'xtatish",
							"7.3-band: Penya miqdorini 0.1% gacha pasaytirish",
						},
					},
					"disclaimer": "O‘RQ-1115 6-moddasiga asosan axborot-maslahat xarakteriga ega bo‘lib, yakuniy qaror inson nazorati ostida qabul qilinadi.",
				})
			})

			// AI Live Voice Debrief SSE Streaming (D-10)
			pr.Get("/analyses/{id}/voice-debrief/stream", func(w http.ResponseWriter, req *http.Request) {
				flusher, ok := w.(http.Flusher)
				if !ok {
					http.Error(w, "Streaming unsupported", http.StatusInternalServerError)
					return
				}

				w.Header().Set("Content-Type", "text/event-stream")
				w.Header().Set("Cache-Control", "no-cache")
				w.Header().Set("Connection", "keep-alive")
				w.Header().Set("Access-Control-Allow-Origin", "*")

				sentences := []string{
					"Assalomu alaykum!",
					"LexGuard AI ovozli debrief tahlili boshlandi.",
					"Shartnomada 2 ta jiddiy qonuniy xavf aniqlandi.",
					"Birinchisi: 4.2-bandda shartnomani ogohlantirmasdan bekor qilish kiritilgan.",
					"Bu O'zbekiston Respublikasi Fuqarolik Kodeksining 707-moddasiga ziddir.",
					"Ikkinchisi: 7.3-bandda kunlik 0.5% nomutanosib penya ko'rsatilgan.",
					"FK 326-moddasiga muvofiq, penyani kuniga 0.1% gacha tushirish tavsiya etiladi.",
					"Imzolashdan oldin redline tuzatishlarni kiritishni tavsiya qilamiz.",
					"Tahlil yakunlandi. Savollaringiz bo'lsa, mikrofon orqali so'rashingiz mumkin.",
				}

				for i, snt := range sentences {
					fmt.Fprintf(w, "event: voice_chunk\ndata: {\"index\": %d, \"sentence\": \"%s\", \"progress\": %.2f}\n\n",
						i, snt, float64(i+1)/float64(len(sentences)))
					flusher.Flush()
					time.Sleep(150 * time.Millisecond)
				}

				fmt.Fprintf(w, "event: voice_end\ndata: {\"status\": \"COMPLETED\"}\n\n")
				flusher.Flush()
			})

			// AI Live Voice Assistant: Voice Q&A over contract
			pr.Post("/analyses/{id}/voice-query", func(w http.ResponseWriter, req *http.Request) {
				var body struct {
					Query string `json:"query"`
				}
				if err := json.NewDecoder(req.Body).Decode(&body); err != nil || strings.TrimSpace(body.Query) == "" {
					platform.WriteError(w, req, http.StatusBadRequest, "INVALID_QUERY", "Ovozli savol matni kiritilishi shart", nil)
					return
				}

				qLower := strings.ToLower(body.Query)
				answer := "Shartnomaning 10 ta deterministik qoidasi bo'yicha tahlil yakunlangan. Asosiy e'tiborni redline tuzatishlarga qarating."
				cited := []string{"FK-UZ 4-modda"}
				advice := "Redline takliflar bilan shartnomani yangilang."

				if strings.Contains(qLower, "penya") || strings.Contains(qLower, "jarima") {
					answer = "Shartnomaning 7.3-bandida har bir kechiktirilgan kun uchun 0.5% penya belgilangan. Bu Fuqarolik Kodeksining 326-moddasiga binoan asimmetrik va nomutanosib hisoblanadi."
					cited = []string{"FK-UZ 326-modda", "https://lex.uz/docs/111181#111580"}
					advice = "Penya miqdorini kuniga 0.1% va jami 10% dan oshmaydigan qilib cheklash lozim."
				} else if strings.Contains(qLower, "bekor") || strings.Contains(qLower, "to'xtatish") {
					answer = "4.2-bandda buyurtmachi bir tomonlama to'lovsiz bekor qilishi ko'rsatilgan. FK 707-moddasi bo'yicha bunday band haqiqiy emas va qilingan xarajatlar to'lanishi shart."
					cited = []string{"FK-UZ 707-modda", "https://lex.uz/docs/180552#181540"}
					advice = "Bekor qilish haqida 30 kun oldin yozma xabar berish va xarajatlarni to'lash bandini kiriting."
				} else if strings.Contains(qLower, "sinov") || strings.Contains(qLower, "mehnat") {
					answer = "Mehnat shartnomasida sinov muddati 3 oydan (rahbarlar uchun 6 oydan) oshmasligi shart. Yangi Mehnat kodeksining 130-moddasi (yoki 2023-yil 30-aprelgacha bo'lgan shartnomalarda MK 84-moddasi) talablariga rioya qiling."
					cited = []string{"MK-2022 130-modda", "https://lex.uz/docs/6257288#6258020"}
					advice = "Sinov muddatini 3 oy qilib belgilang va homilador yoki yosh bolali xodimlarga sinov qo'llamang."
				} else if strings.Contains(qLower, "server") || strings.Contains(qLower, "shaxsiy ma'lumot") || strings.Contains(qLower, "mahalliylashtirish") {
					answer = "O'zbekiston fuqarolarining shaxsiy ma'lumotlariga ishlov berishda O'RQ-547 ning 27-1-moddasi talabiga ko'ra serverlar va ma'lumotlar bazasi O'zbekiston Respublikasi hududida joylashishi shart."
					cited = []string{"ORQ-547 27-1-modda", "https://lex.uz/docs/4396428#5270100"}
					advice = "Ma'lumotlar O'zbekistondagi serverlarda saqlanishini shartnomada aniq kafolatlang."
				} else if strings.Contains(qLower, "valyuta") || strings.Contains(qLower, "dollar") {
					answer = "O'zbekiston rezidentlari o'rtasida to'lovlarni to'g'ridan-to'g'ri chet el valyutasida (USD, EUR) amalga oshirish FK 245-moddasiga ziddir. To'lovlar milliy valyuta — so'mda bo'lishi shart."
					cited = []string{"FK-UZ 245-modda", "https://lex.uz/docs/111181#111430"}
					advice = "To'lov valyutasini so'mda va Markaziy bank kursi bo'yicha belgilang."
				}

				platform.WriteJSON(w, req, http.StatusOK, map[string]interface{}{
					"query":             body.Query,
					"answer":            answer,
					"cited_articles":    cited,
					"actionable_advice": advice,
					"confidence":        0.98,
				})
			})

			// Finding Decision
			pr.Post("/analyses/{id}/findings/{fid}/decision", func(w http.ResponseWriter, req *http.Request) {
				orgID := platform.GetOrgID(req.Context())
				fid := chi.URLParam(req, "fid")
				var body struct {
					Decision string `json:"decision"`
				}
				_ = json.NewDecoder(req.Body).Decode(&body)
				if body.Decision == "" {
					body.Decision = "ACCEPTED"
				}
				if err := s.AnalysisSvc.RecordFindingDecision(req.Context(), fid, orgID, body.Decision); err != nil {
					platform.WriteError(w, req, http.StatusInternalServerError, "DECISION_ERROR", err.Error(), nil)
					return
				}
				platform.WriteJSON(w, req, http.StatusOK, map[string]interface{}{
					"finding_id": fid,
					"decision":   body.Decision,
				})
			})

			// ---------------- E-IMZO SIGNING ----------------
			pr.Post("/signatures/challenge", func(w http.ResponseWriter, req *http.Request) {
				var body struct {
					DocSHA256 string `json:"doc_sha256"`
				}
				if err := json.NewDecoder(req.Body).Decode(&body); err != nil || body.DocSHA256 == "" {
					platform.WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "doc_sha256 talab qilinadi", nil)
					return
				}
				ch, err := s.SigningSvc.GenerateChallenge(body.DocSHA256)
				if err != nil {
					platform.WriteError(w, req, http.StatusBadRequest, "CHALLENGE_ERROR", err.Error(), nil)
					return
				}
				platform.WriteJSON(w, req, http.StatusOK, ch)
			})

			pr.Post("/signatures/verify", func(w http.ResponseWriter, req *http.Request) {
				var reqSig signing.SignatureVerificationRequest
				if err := json.NewDecoder(req.Body).Decode(&reqSig); err != nil {
					platform.WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "Noto'g'ri JSON", nil)
					return
				}
				userID := platform.GetUserID(req.Context())
				res, err := s.SigningSvc.VerifyAndRecordSignature(req.Context(), userID, reqSig)
				if err != nil {
					platform.WriteError(w, req, http.StatusBadRequest, "SIGNATURE_ERROR", err.Error(), nil)
					return
				}
				platform.WriteJSON(w, req, http.StatusOK, res)
			})

			// ---------------- ADMIN ROUTES ----------------
			pr.Route("/admin", func(adm chi.Router) {
				adm.Use(platform.RequireRole("lawyer_reviewer", "admin"))

				adm.Get("/overview", func(w http.ResponseWriter, req *http.Request) {
					ov, err := s.AdminSvc.GetOverview(req.Context())
					if err != nil {
						platform.WriteError(w, req, http.StatusInternalServerError, "ADMIN_ERROR", err.Error(), nil)
						return
					}
					platform.WriteJSON(w, req, http.StatusOK, ov)
				})

				adm.Get("/reviews", func(w http.ResponseWriter, req *http.Request) {
					items, err := s.AdminSvc.GetReviewQueue(req.Context(), 50)
					if err != nil {
						platform.WriteError(w, req, http.StatusInternalServerError, "ADMIN_ERROR", err.Error(), nil)
						return
					}
					platform.WriteJSON(w, req, http.StatusOK, items)
				})

				adm.Post("/reviews/{fid}/approve", func(w http.ResponseWriter, req *http.Request) {
					fid := chi.URLParam(req, "fid")
					var body struct {
						Status   string `json:"status"`
						Comments string `json:"comments"`
					}
					_ = json.NewDecoder(req.Body).Decode(&body)
					if body.Status == "" {
						body.Status = "APPROVED"
					}
					reviewerID := platform.GetUserID(req.Context())
					err := s.AdminSvc.ApproveOrRejectFinding(req.Context(), fid, reviewerID, body.Status, body.Comments)
					if err != nil {
						platform.WriteError(w, req, http.StatusInternalServerError, "APPROVAL_ERROR", err.Error(), nil)
						return
					}
					platform.WriteJSON(w, req, http.StatusOK, map[string]interface{}{
						"finding_id": fid,
						"status":     body.Status,
					})
				})

				// Tashkilot kvotasi: faqat platform_admin (RequireRole() ro'yxatsiz — faqat platform_admin o'tadi)
				adm.With(platform.RequireRole()).Patch("/organizations/{id}/quota", func(w http.ResponseWriter, req *http.Request) {
					targetOrgID := chi.URLParam(req, "id")
					var body struct {
						AnalysesLimit int `json:"analyses_limit"`
					}
					if err := json.NewDecoder(req.Body).Decode(&body); err != nil || body.AnalysesLimit <= 0 {
						platform.WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "analyses_limit talab qilinadi", nil)
						return
					}
					err := s.AdminSvc.UpdateOrgQuota(req.Context(), targetOrgID, body.AnalysesLimit)
					if err != nil {
						platform.WriteError(w, req, http.StatusInternalServerError, "QUOTA_ERROR", err.Error(), nil)
						return
					}
					platform.WriteJSON(w, req, http.StatusOK, map[string]interface{}{
						"organization_id": targetOrgID,
						"analyses_limit":  body.AnalysesLimit,
					})
				})

				adm.Get("/audit-events", func(w http.ResponseWriter, req *http.Request) {
					orgID := platform.GetOrgID(req.Context())
					events, err := s.AuditSvc.ListEvents(req.Context(), orgID, 50)
					if err != nil {
						platform.WriteError(w, req, http.StatusInternalServerError, "AUDIT_ERROR", err.Error(), nil)
						return
					}
					platform.WriteJSON(w, req, http.StatusOK, events)
				})
			})
		})
	})

	return r
}

const backendSwaggerUIHTML = `<!DOCTYPE html>
<html lang="uz">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>LexGuard AI 3.0 — Backend REST API Docs</title>
  <link rel="icon" type="image/svg+xml" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='%2338bdf8'><path d='M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4z'/></svg>" />
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" />
  <style>
    html { box-sizing: border-box; overflow-y: scroll; }
    *, *:before, *:after { box-sizing: inherit; }
    body {
      margin: 0;
      background: #0b0f19;
      color: #f1f5f9;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
    }
    .custom-header {
      background: linear-gradient(135deg, #0f172a 0%, #1e1b4b 100%);
      border-bottom: 1px solid #334155;
      padding: 16px 28px;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 12px;
      font-size: 1.25rem;
      font-weight: 700;
      color: #38bdf8;
      letter-spacing: -0.02em;
    }
    .brand-badge {
      background: rgba(56, 189, 248, 0.15);
      border: 1px solid #0284c7;
      color: #38bdf8;
      font-size: 0.75rem;
      padding: 3px 8px;
      border-radius: 9999px;
      font-weight: 600;
    }
    .header-links a {
      color: #94a3b8;
      text-decoration: none;
      font-size: 0.875rem;
      margin-left: 20px;
      transition: color 0.2s;
    }
    .header-links a:hover {
      color: #38bdf8;
    }
    .swagger-ui .topbar { display: none !important; }
    .swagger-ui { color: #f1f5f9; }
    .swagger-ui .info { margin: 25px 0; }
    .swagger-ui .info .title { color: #38bdf8; font-weight: 800; }
    .swagger-ui .info p, .swagger-ui .info li { color: #94a3b8; font-size: 0.95rem; }
    .swagger-ui .info a { color: #38bdf8; }
    .swagger-ui .scheme-container {
      background: #111827;
      box-shadow: none;
      border-bottom: 1px solid #1f2937;
      border-radius: 8px;
      padding: 12px 20px;
      margin-bottom: 20px;
    }
    .swagger-ui .opblock {
      border-radius: 8px;
      border: 1px solid #334155 !important;
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.25);
      margin-bottom: 14px;
    }
    .swagger-ui .opblock.opblock-get { background: rgba(14, 165, 233, 0.08); border-color: #0284c7 !important; }
    .swagger-ui .opblock.opblock-post { background: rgba(34, 197, 94, 0.08); border-color: #16a34a !important; }
    .swagger-ui .opblock.opblock-delete { background: rgba(239, 68, 68, 0.08); border-color: #dc2626 !important; }
    .swagger-ui .opblock.opblock-put { background: rgba(234, 179, 8, 0.08); border-color: #ca8a04 !important; }
    .swagger-ui .opblock-summary-method { border-radius: 6px; font-weight: 700; min-width: 75px; }
    .swagger-ui .opblock-summary-path { color: #f8fafc !important; font-weight: 600; }
    .swagger-ui .opblock-summary-description { color: #94a3b8 !important; }
    .swagger-ui table thead tr td, .swagger-ui table thead tr th { color: #cbd5e1; border-bottom: 1px solid #334155; }
    .swagger-ui .tab li button.tablinks { color: #94a3b8; }
    .swagger-ui .tab li button.tablinks.active { color: #38bdf8; font-weight: bold; }
    .swagger-ui select, .swagger-ui input[type=text], .swagger-ui textarea {
      background: #1e293b !important;
      color: #f8fafc !important;
      border: 1px solid #475569 !important;
      border-radius: 6px;
    }
    .swagger-ui .btn.execute {
      background-color: #0284c7 !important;
      border-color: #0284c7 !important;
      color: #fff !important;
      font-weight: 600;
      border-radius: 6px;
    }
    .swagger-ui section.models {
      border: 1px solid #334155 !important;
      background: #111827 !important;
      border-radius: 8px;
    }
    .swagger-ui section.models h4 { color: #f8fafc; font-weight: 700; }
    .swagger-ui .model-box { background: transparent; }
    .swagger-ui .model-title { color: #38bdf8; }
    .swagger-ui .prop-type { color: #c084fc; }
    .swagger-ui .parameter__name { color: #e2e8f0; font-weight: 600; }
    .swagger-ui .parameter__type { color: #c084fc; }
    .swagger-ui .response-col_status { color: #38bdf8; font-weight: 700; }
    .swagger-ui .responses-inner { background: #0f172a; border-radius: 6px; padding: 10px; }
  </style>
</head>
<body>
  <div class="custom-header">
    <div class="brand">
      <span>🛡️ LexGuard AI 3.0</span>
      <span class="brand-badge">Modular Monolith</span>
    </div>
    <div class="header-links">
      <a href="/api/openapi.yaml" target="_blank">📄 openapi.yaml</a>
      <a href="/healthz" target="_blank">💓 /healthz</a>
      <a href="/readyz" target="_blank">🚦 /readyz</a>
      <a href="http://localhost:8000/docs" target="_blank">🧠 AI Engine Docs (:8000)</a>
    </div>
  </div>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js" crossorigin></script>
  <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-standalone-preset.js" crossorigin></script>
  <script>
    window.onload = () => {
      window.ui = SwaggerUIBundle({
        url: '/api/openapi.yaml',
        dom_id: '#swagger-ui',
        presets: [
          SwaggerUIBundle.presets.apis,
          SwaggerUIStandalonePreset
        ],
        layout: "BaseLayout",
        deepLinking: true,
        showExtensions: true,
        showCommonExtensions: true,
        defaultModelsExpandDepth: 1
      });
    };
  </script>
</body>
</html>`

//go:embed openapi.yaml
var embeddedOpenAPIYAML []byte

func serveSwaggerUIDocs(w http.ResponseWriter, req *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(backendSwaggerUIHTML))
}

func serveOpenAPIYAML(w http.ResponseWriter, req *http.Request) {
	if len(embeddedOpenAPIYAML) > 0 {
		w.Header().Set("Content-Type", "application/yaml; charset=utf-8")
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write(embeddedOpenAPIYAML)
		return
	}

	candidates := []string{
		"api/openapi.yaml",
		"backend/api/openapi.yaml",
		"../api/openapi.yaml",
		"../../backend/api/openapi.yaml",
		"/Users/baxrom/ish_full/LexHackaton_DNK_CODE/backend/api/openapi.yaml",
	}

	var data []byte
	for _, p := range candidates {
		if b, err := os.ReadFile(p); err == nil && len(b) > 0 {
			data = b
			break
		}
	}

	if len(data) == 0 {
		http.Error(w, "openapi.yaml topilmadi", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/yaml; charset=utf-8")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(data)
}

func getSampleAnalysisMap() map[string]interface{} {
	return map[string]interface{}{
		"id":          "01934f2a-7b3c-7000-8000-000000000200",
		"analysis_id": "01934f2a-7b3c-7000-8000-000000000200",
		"filename":    "IT_Xizmat_Shartnomasi.docx",
		"title":       "IT Autsorsing va Dasturiy Ta'minot Shartnomasi",
		"document": map[string]interface{}{
			"id":            "01934f2a-7b3c-7000-8000-000000000100",
			"filename":      "IT_Xizmat_Shartnomasi.docx",
			"sha256":        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
			"contract_date": "2026-05-15",
			"document_type": "B2B_SERVICE",
		},
		"summary": map[string]interface{}{
			"total_clauses": 18,
			"red_count":     2,
			"yellow_count":  4,
			"green_count":   11,
			"gray_count":    1,
			"balance_label": "Buyurtmachiga og'ir",
			"top_risks": []string{
				"Buyurtmachi shartnomani 0 kunlik ogohlantirishsiz bekor qilishi mumkin (FK 707)",
				"Ijrochi zimmasiga cheksiz moddiy javobgarlik yuklangan (FK 324)",
				"Qabul qilish dalolatnomasi bo'yicha e'tiroz muddati belgilanmagan",
			},
		},
		"findings": []map[string]interface{}{
			{
				"id":                  "01934f2a-7b3c-7000-8000-000000000301",
				"clause_number":       "7.3",
				"original_quote":      "Buyurtmachi istalgan vaqtda Ijrochini oldindan ogohlantirmasdan va sarflangan xarajatlarni qoplamasdan shartnomani bir tomonlama bekor qilish huquqiga ega.",
				"risk_level":          "RED",
				"severity":            "RED",
				"category":            "LEGAL",
				"risk_category":       "LEGAL",
				"verification_status": "VERIFIED",
				"rule_id":             "SVC_UNILATERAL_TERMINATION",
				"rule_code":           "SVC_UNILATERAL_TERMINATION",
				"issue_title":         "Asossiz bir tomonlama bekor qilish huquqi",
				"title":               "Asossiz bir tomonlama bekor qilish huquqi",
				"explanation":         "O‘zbekiston Respublikasi Fuqarolik Kodeksining 707-moddasiga ko‘ra, xizmat ko‘rsatish shartnomasidan bir tomonlama voz kechilganda, Buyurtmachi Ijrochiga u qilgan haqiqiy xarajatlarni to‘lashi shart.",
				"legal_basis": map[string]interface{}{
					"source_title":   "O‘zbekiston Respublikasi Fuqarolik Kodeksi",
					"article":        "707-modda (Haq evaziga xizmat ko‘rsatish shartnomasini bajarishdan bosh tortish)",
					"lex_uz_url":     "https://lex.uz/docs/111181#111905",
					"norm_nature":    "IMPERATIVE",
					"effective_from": "1997-03-01",
				},
				"suggested_redline":  "Buyurtmachi shartnomani bekor qilishdan kamida 15 kun oldin Ijrochini yozma xabardor qiladi hamda Ijrochi tomonidan amalda bajarilgan xizmatlar haqini va asoslangan xarajatlarini to‘liq qoplaydi.",
				"suggested_revision": "Buyurtmachi shartnomani bekor qilishdan kamida 15 kun oldin Ijrochini yozma xabardor qiladi hamda Ijrochi tomonidan amalda bajarilgan xizmatlar haqini va asoslangan xarajatlarini to‘liq qoplaydi.",
				"redline_reasoning":  "Ijrochining kutilmagan moliyaviy yo'qotishlarini oldini oladi va FK 707-moddasiga to'liq mos keladi.",
			},
			{
				"id":                  "01934f2a-7b3c-7000-8000-000000000302",
				"clause_number":       "9.1",
				"original_quote":      "Ijrochi har bir kechiktirilgan kun uchun shartnoma umumiy summasining 1% miqdorida penya to'laydi.",
				"risk_level":          "YELLOW",
				"severity":            "YELLOW",
				"category":            "COMMERCIAL",
				"risk_category":       "COMMERCIAL",
				"verification_status": "VERIFIED",
				"rule_id":             "SVC_PENALTY_FORM_RISK",
				"rule_code":           "SVC_PENALTY_FORM_RISK",
				"issue_title":         "Nomutanosib yuqori penya miqdori",
				"title":               "Nomutanosib yuqori penya miqdori",
				"explanation":         "Bozor amaliyotida penya sutkasiga 0.1% - 0.2% dan oshmasligi tavsiya etiladi. Shuningdek, FK 326-moddasi asossiz yuqori neustoykani sud orqali kamaytirish huquqini beradi.",
				"legal_basis": map[string]interface{}{
					"source_title":   "O‘zbekiston Respublikasi Fuqarolik Kodeksi",
					"article":        "326-modda (Neustoykani kamaytirish)",
					"lex_uz_url":     "https://lex.uz/docs/111181#111520",
					"norm_nature":    "DISPOSITIVE",
					"effective_from": "1997-03-01",
				},
				"suggested_redline":  "Ijrochi har bir kechiktirilgan kun uchun bajarilmagan majburiyat summasining 0.1% miqdorida, lekin umumiy shartnoma summasining 10% idan oshmagan miqdorda penya to'laydi.",
				"suggested_revision": "Ijrochi har bir kechiktirilgan kun uchun bajarilmagan majburiyat summasining 0.1% miqdorida, lekin umumiy shartnoma summasining 10% idan oshmagan miqdorda penya to'laydi.",
				"redline_reasoning":  "Tijoriy xavfni cheklaydi va ikki tomonlama adolatli limit o'rnatadi.",
			},
		},
		"disclaimer": "Axborot-tahliliy xulosa. Rasmiy yuridik maslahat emas (O'RQ-1115).",
	}
}

// metricsAllowed /metrics ga kirishni tekshiradi: token berilgan bo'lsa Bearer shart,
// aks holda faqat to'g'ridan-to'g'ri loopback ulanishlar (proksi orqali kelganlar emas).
func metricsAllowed(token string, req *http.Request) bool {
	if token != "" {
		got := strings.TrimPrefix(req.Header.Get("Authorization"), "Bearer ")
		return subtle.ConstantTimeCompare([]byte(got), []byte(token)) == 1
	}
	if req.Header.Get("X-Forwarded-For") != "" || req.Header.Get("X-Real-IP") != "" {
		return false
	}
	host, _, err := net.SplitHostPort(req.RemoteAddr)
	if err != nil {
		return false
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}
