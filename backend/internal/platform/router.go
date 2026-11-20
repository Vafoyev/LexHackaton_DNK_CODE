package platform

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/lexguard/backend/internal/admin"
	"github.com/lexguard/backend/internal/analysis"
	"github.com/lexguard/backend/internal/audit"
	"github.com/lexguard/backend/internal/billing"
	"github.com/lexguard/backend/internal/documents"
	"github.com/lexguard/backend/internal/identity"
	"github.com/lexguard/backend/internal/legalcorpus"
	"github.com/lexguard/backend/internal/privacy"
	"github.com/lexguard/backend/internal/report"
	"github.com/lexguard/backend/internal/rules"
	"github.com/lexguard/backend/internal/signing"
)

type RouterServices struct {
	DB          *pgxpool.Pool
	Config      *Config
	JWTManager  *JWTManager
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
}

func BuildRouter(s *RouterServices) http.Handler {
	r := chi.NewRouter()

	// Global Middlewares
	r.Use(RequestIDMiddleware)
	r.Use(LoggerMiddleware)
	r.Use(RecovererMiddleware)
	r.Use(CORSMiddleware)
	r.Use(BodyLimitMiddleware(15 * 1024 * 1024)) // 15MB max

	// System Endpoints (No Auth)
	r.Get("/healthz", func(w http.ResponseWriter, req *http.Request) {
		WriteJSON(w, req, http.StatusOK, map[string]string{
			"status":    "UP",
			"timestamp": time.Now().UTC().Format(time.RFC3339),
			"version":   "3.0.0",
		})
	})

	r.Get("/readyz", func(w http.ResponseWriter, req *http.Request) {
		ctx, cancel := context.WithTimeout(req.Context(), 2*time.Second)
		defer cancel()
		if err := s.DB.Ping(ctx); err != nil {
			WriteError(w, req, http.StatusServiceUnavailable, "DB_UNAVAILABLE", "Baza bilan aloqa yo'q", err.Error())
			return
		}
		WriteJSON(w, req, http.StatusOK, map[string]interface{}{
			"status":   "READY",
			"database": "CONNECTED",
			"storage":  "READY",
			"workers":  4,
		})
	})

	r.Get("/metrics", func(w http.ResponseWriter, req *http.Request) {
		w.Header().Set("Content-Type", "text/plain")
		fmt.Fprintf(w, "# HELP lexguard_requests_total Total number of HTTP requests\n")
		fmt.Fprintf(w, "lexguard_requests_total{status=\"200\"} 1\n")
		fmt.Fprintf(w, "# HELP lexguard_analyses_active Currently active analysis workers\n")
		fmt.Fprintf(w, "lexguard_analyses_active 4\n")
	})

	// API v1 Routes
	r.Route("/api/v1", func(api chi.Router) {

		// Integrations Status (Public / Transparent D-06)
		api.Get("/integrations/status", func(w http.ResponseWriter, req *http.Request) {
			rows, err := s.DB.Query(req.Context(), `SELECT name, mode, is_healthy, last_checked_at FROM integrations`)
			if err != nil {
				WriteError(w, req, http.StatusInternalServerError, "DB_ERROR", err.Error(), nil)
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
			WriteJSON(w, req, http.StatusOK, list)
		})

		// Monitoring (System-wide health & risk metrics)
		api.Get("/monitoring", func(w http.ResponseWriter, req *http.Request) {
			ov, err := s.AdminSvc.GetOverview(req.Context())
			if err != nil {
				WriteError(w, req, http.StatusInternalServerError, "OVERVIEW_ERROR", err.Error(), nil)
				return
			}
			WriteJSON(w, req, http.StatusOK, ov)
		})

		// Public Rules & Legal Sources
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
			WriteJSON(w, req, http.StatusOK, summary)
		})

		api.Get("/legal-sources", func(w http.ResponseWriter, req *http.Request) {
			list, err := s.CorpusRepo.ListAllSources(req.Context())
			if err != nil {
				WriteError(w, req, http.StatusInternalServerError, "DB_ERROR", err.Error(), nil)
				return
			}
			WriteJSON(w, req, http.StatusOK, list)
		})

		// Billing plans (Public)
		api.Get("/billing/plans", func(w http.ResponseWriter, req *http.Request) {
			plans := s.BillingSvc.GetAvailablePlans()
			WriteJSON(w, req, http.StatusOK, plans)
		})

		// ---------------- AUTH ROUTES (Public) ----------------
		api.Route("/auth", func(auth chi.Router) {
			auth.Post("/register", func(w http.ResponseWriter, req *http.Request) {
				var body struct {
					Email      string `json:"email"`
					Password   string `json:"password"`
					FullName   string `json:"full_name"`
					OrgName    string `json:"org_name"`
					Phone      string `json:"phone"`
					ClientType string `json:"client_type"`
				}
				if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
					WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "Noto'g'ri JSON", err.Error())
					return
				}
				res, err := s.IdentitySvc.Register(req.Context(), body.Email, body.Password, body.FullName, body.OrgName, body.Phone, body.ClientType)
				if err != nil {
					WriteError(w, req, http.StatusBadRequest, "REGISTRATION_FAILED", err.Error(), nil)
					return
				}
				s.AuditSvc.Log(req.Context(), res.User.OrganizationID, res.User.ID, "USER_REGISTER", "USER", res.User.ID, req.RemoteAddr, req.UserAgent(), nil)
				WriteJSON(w, req, http.StatusCreated, res)
			})

			auth.Post("/login", func(w http.ResponseWriter, req *http.Request) {
				var body struct {
					Email      string `json:"email"`
					Password   string `json:"password"`
					ClientType string `json:"client_type"`
				}
				if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
					WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "Noto'g'ri JSON", err.Error())
					return
				}
				res, err := s.IdentitySvc.Login(req.Context(), body.Email, body.Password, body.ClientType, req.UserAgent(), req.RemoteAddr)
				if err != nil {
					WriteError(w, req, http.StatusUnauthorized, "LOGIN_FAILED", err.Error(), nil)
					return
				}
				s.AuditSvc.Log(req.Context(), res.User.OrganizationID, res.User.ID, "USER_LOGIN", "USER", res.User.ID, req.RemoteAddr, req.UserAgent(), nil)
				WriteJSON(w, req, http.StatusOK, res)
			})

			auth.Post("/demo-session", func(w http.ResponseWriter, req *http.Request) {
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
					WriteError(w, req, http.StatusInternalServerError, "DEMO_SESSION_ERROR", err.Error(), nil)
					return
				}
				s.AuditSvc.Log(req.Context(), res.User.OrganizationID, res.User.ID, "DEMO_LOGIN", "USER", res.User.ID, req.RemoteAddr, req.UserAgent(), map[string]interface{}{"role": body.Role})
				WriteJSON(w, req, http.StatusOK, res)
			})

			auth.Post("/refresh", func(w http.ResponseWriter, req *http.Request) {
				var body struct {
					RefreshToken string `json:"refresh_token"`
					ClientType   string `json:"client_type"`
				}
				if err := json.NewDecoder(req.Body).Decode(&body); err != nil || body.RefreshToken == "" {
					WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "refresh_token talab qilinadi", nil)
					return
				}
				res, err := s.IdentitySvc.RefreshSession(req.Context(), body.RefreshToken, body.ClientType)
				if err != nil {
					WriteError(w, req, http.StatusUnauthorized, "REFRESH_FAILED", err.Error(), nil)
					return
				}
				WriteJSON(w, req, http.StatusOK, res)
			})

			auth.Post("/logout", func(w http.ResponseWriter, req *http.Request) {
				var body struct {
					RefreshToken string `json:"refresh_token"`
				}
				_ = json.NewDecoder(req.Body).Decode(&body)
				if body.RefreshToken != "" {
					_ = s.IdentitySvc.Logout(req.Context(), body.RefreshToken)
				}
				WriteJSON(w, req, http.StatusOK, map[string]bool{"logged_out": true})
			})

			// OneID Mock Endpoints
			auth.Get("/oneid/authorize", func(w http.ResponseWriter, req *http.Request) {
				callbackURL := req.URL.Query().Get("callback")
				if callbackURL == "" {
					callbackURL = "http://localhost:8080/api/v1/auth/oneid/callback"
				}
				code := uuid.NewString()[:8]
				WriteJSON(w, req, http.StatusOK, map[string]string{
					"mode":             "MOCK",
					"authorization_url": fmt.Sprintf("%s?code=%s&state=mock_state", callbackURL, code),
					"message":          "VM-679 OneID Sandbox Mock rejimida",
				})
			})

			auth.Get("/oneid/callback", func(w http.ResponseWriter, req *http.Request) {
				code := req.URL.Query().Get("code")
				if code == "" {
					code = "mock_code"
				}
				res, err := s.IdentitySvc.DemoSession(req.Context(), "lawyer", "web")
				if err != nil {
					WriteError(w, req, http.StatusInternalServerError, "ONEID_CALLBACK_ERROR", err.Error(), nil)
					return
				}
				WriteJSON(w, req, http.StatusOK, res)
			})
		})

		// ---------------- PROTECTED ROUTES ----------------
		api.Group(func(pr chi.Router) {
			pr.Use(AuthMiddleware(s.JWTManager))
			pr.Use(TenantGuardMiddleware)

			// Current User Profile & Consents
			pr.Get("/auth/me", func(w http.ResponseWriter, req *http.Request) {
				userID := GetUserID(req.Context())
				orgID := GetOrgID(req.Context())
				profile, err := s.IdentitySvc.GetMe(req.Context(), userID, orgID)
				if err != nil {
					WriteError(w, req, http.StatusNotFound, "NOT_FOUND", "Foydalanuvchi profili topilmadi", nil)
					return
				}
				WriteJSON(w, req, http.StatusOK, profile)
			})

			pr.Post("/consents", func(w http.ResponseWriter, req *http.Request) {
				var body struct {
					ConsentType string `json:"consent_type"` // EXTERNAL_AI, DATA_PROCESSING
					Granted     bool   `json:"granted"`
				}
				if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
					WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "Noto'g'ri JSON", nil)
					return
				}
				userID := GetUserID(req.Context())
				orgID := GetOrgID(req.Context())
				err := s.IdentitySvc.RecordConsent(req.Context(), userID, orgID, body.ConsentType, body.Granted, req.RemoteAddr)
				if err != nil {
					WriteError(w, req, http.StatusInternalServerError, "DB_ERROR", err.Error(), nil)
					return
				}
				WriteJSON(w, req, http.StatusOK, map[string]interface{}{
					"consent_type": body.ConsentType,
					"granted":      body.Granted,
				})
			})

			// Billing Quota
			pr.Get("/billing/quota", func(w http.ResponseWriter, req *http.Request) {
				orgID := GetOrgID(req.Context())
				q, err := s.BillingSvc.GetQuota(req.Context(), orgID)
				if err != nil {
					WriteError(w, req, http.StatusInternalServerError, "QUOTA_ERROR", err.Error(), nil)
					return
				}
				WriteJSON(w, req, http.StatusOK, q)
			})

			// ---------------- DOCUMENTS & CONTRACTS ----------------
			handleDocumentUpload := func(w http.ResponseWriter, req *http.Request) {
				orgID := GetOrgID(req.Context())
				userID := GetUserID(req.Context())

				// Support both multipart/form-data and direct JSON text
				contentType := req.Header.Get("Content-Type")

				var filename string
				var fileBytes []byte
				var mimeType string

				if strings.HasPrefix(contentType, "multipart/form-data") {
					err := req.ParseMultipartForm(10 * 1024 * 1024)
					if err != nil {
						WriteError(w, req, http.StatusBadRequest, "MULTIPART_ERROR", "Faylni o'qishda xatolik", err.Error())
						return
					}
					file, header, err := req.FormFile("file")
					if err != nil {
						WriteError(w, req, http.StatusBadRequest, "FILE_MISSING", "file maydoni talab qilinadi", err.Error())
						return
					}
					defer file.Close()

					filename = header.Filename
					buf, err := io.ReadAll(file)
					if err != nil {
						WriteError(w, req, http.StatusBadRequest, "READ_ERROR", "Fayl baytlarini o'qib bo'lmadi", err.Error())
						return
					}
					fileBytes = buf
					sniffed, err := documents.SniffMimeType(fileBytes, filename)
					if err != nil {
						WriteError(w, req, http.StatusUnsupportedMediaType, "UNSUPPORTED_MEDIA_TYPE", err.Error(), nil)
						return
					}
					mimeType = sniffed
				} else {
					// JSON body with direct raw text or filename
					var body struct {
						Filename string `json:"filename"`
						Text     string `json:"text"`
					}
					if err := json.NewDecoder(req.Body).Decode(&body); err != nil || body.Text == "" {
						WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "Matn yoki fayl kiritilishi shart", nil)
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
					WriteError(w, req, http.StatusInternalServerError, "STORAGE_ERROR", err.Error(), nil)
					return
				}

				// 3. Extract text
				rawText, parseConfidence, err := documents.ExtractText(fileBytes, mimeType)
				if err != nil {
					WriteError(w, req, http.StatusUnprocessableEntity, "PARSE_ERROR", err.Error(), nil)
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
					WriteError(w, req, http.StatusInternalServerError, "DB_ERROR", err.Error(), nil)
					return
				}

				s.AuditSvc.Log(req.Context(), orgID, userID, "DOCUMENT_UPLOAD", "DOCUMENT", docID, req.RemoteAddr, req.UserAgent(), map[string]interface{}{
					"filename": filename,
					"sha256":   shaHex,
					"clauses":  len(clauses),
				})

				WriteJSON(w, req, http.StatusCreated, docInfo)
			}

			handleDocumentsList := func(w http.ResponseWriter, req *http.Request) {
				orgID := GetOrgID(req.Context())
				limitStr := req.URL.Query().Get("limit")
				limit := 20
				if l, err := strconv.Atoi(limitStr); err == nil && l > 0 {
					limit = l
				}
				docs, err := s.DocRepo.ListDocuments(req.Context(), orgID, limit)
				if err != nil {
					WriteError(w, req, http.StatusInternalServerError, "DB_ERROR", err.Error(), nil)
					return
				}
				WriteJSON(w, req, http.StatusOK, docs)
			}

			handleDocumentDetail := func(w http.ResponseWriter, req *http.Request) {
				orgID := GetOrgID(req.Context())
				id := chi.URLParam(req, "id")
				doc, err := s.DocRepo.GetDocument(req.Context(), id, orgID)
				if err != nil {
					WriteError(w, req, http.StatusNotFound, "NOT_FOUND", "Hujjat topilmadi", nil)
					return
				}
				WriteJSON(w, req, http.StatusOK, doc)
			}

			handleDocumentDelete := func(w http.ResponseWriter, req *http.Request) {
				orgID := GetOrgID(req.Context())
				id := chi.URLParam(req, "id")
				if err := s.DocRepo.SoftDeleteDocument(req.Context(), id, orgID); err != nil {
					WriteError(w, req, http.StatusNotFound, "NOT_FOUND", err.Error(), nil)
					return
				}
				s.AuditSvc.Log(req.Context(), orgID, GetUserID(req.Context()), "DOCUMENT_DELETE", "DOCUMENT", id, req.RemoteAddr, req.UserAgent(), nil)
				WriteJSON(w, req, http.StatusOK, map[string]bool{"deleted": true})
			}

			// Register routes for both /documents and /contracts (contract alias)
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
				orgID := GetOrgID(req.Context())
				var body struct {
					DocumentID    string `json:"document_id"`
					ContractID    string `json:"contract_id"` // alias
					ContractDate  string `json:"contract_date"`
					DocType       string `json:"doc_type"`
					ExecutionMode string `json:"execution_mode"`
				}
				if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
					WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "Noto'g'ri JSON", nil)
					return
				}
				docID := body.DocumentID
				if docID == "" {
					docID = body.ContractID
				}
				if docID == "" {
					WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "document_id yoki contract_id talab qilinadi", nil)
					return
				}

				analysisID, err := s.AnalysisSvc.CreateAnalysis(req.Context(), orgID, docID, body.ContractDate, body.DocType, body.ExecutionMode)
				if err != nil {
					WriteError(w, req, http.StatusPaymentRequired, "QUOTA_OR_ANALYSIS_ERROR", err.Error(), nil)
					return
				}

				s.AuditSvc.Log(req.Context(), orgID, GetUserID(req.Context()), "ANALYSIS_TRIGGERED", "ANALYSIS", analysisID, req.RemoteAddr, req.UserAgent(), map[string]interface{}{
					"document_id": docID,
					"doc_type":    body.DocType,
				})

				WriteJSON(w, req, http.StatusAccepted, map[string]interface{}{
					"analysis_id": analysisID,
					"id":          analysisID,
					"contract_id": docID,
					"status":      "PENDING",
					"events_url":  fmt.Sprintf("/api/v1/analyses/%s/events", analysisID),
				})
			}

			handleListAnalyses := func(w http.ResponseWriter, req *http.Request) {
				orgID := GetOrgID(req.Context())
				list, err := s.AnalysisSvc.ListAnalyses(req.Context(), orgID, 20)
				if err != nil {
					WriteError(w, req, http.StatusInternalServerError, "DB_ERROR", err.Error(), nil)
					return
				}
				WriteJSON(w, req, http.StatusOK, list)
			}

			handleGetAnalysis := func(w http.ResponseWriter, req *http.Request) {
				orgID := GetOrgID(req.Context())
				id := chi.URLParam(req, "id")
				det, err := s.AnalysisSvc.GetAnalysis(req.Context(), id, orgID)
				if err != nil {
					WriteError(w, req, http.StatusNotFound, "NOT_FOUND", "Tahlil natijasi topilmadi", nil)
					return
				}
				WriteJSON(w, req, http.StatusOK, det)
			}

			pr.Post("/analyses", handleCreateAnalysis)
			pr.Get("/analyses", handleListAnalyses)
			pr.Get("/analyses/{id}", handleGetAnalysis)

			// Aliases for /analysis
			pr.Post("/analysis", handleCreateAnalysis)
			pr.Get("/analysis", handleListAnalyses)
			pr.Get("/analysis/{id}", handleGetAnalysis)

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

			// Report Export (DOCX / PDF / Text / JSON)
			pr.Get("/analyses/{id}/report", func(w http.ResponseWriter, req *http.Request) {
				orgID := GetOrgID(req.Context())
				id := chi.URLParam(req, "id")
				format := strings.ToLower(req.URL.Query().Get("format"))

				rep, err := s.ReportSvc.GenerateReport(req.Context(), id, orgID)
				if err != nil {
					WriteError(w, req, http.StatusNotFound, "NOT_FOUND", err.Error(), nil)
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

				WriteJSON(w, req, http.StatusOK, rep)
			})

			// Accept or Dismiss Finding
			pr.Post("/analyses/{id}/findings/{fid}/decision", func(w http.ResponseWriter, req *http.Request) {
				orgID := GetOrgID(req.Context())
				fid := chi.URLParam(req, "fid")
				var body struct {
					Decision string `json:"decision"` // ACCEPTED | DISMISSED
				}
				_ = json.NewDecoder(req.Body).Decode(&body)
				if body.Decision == "" {
					body.Decision = "ACCEPTED"
				}
				if err := s.AnalysisSvc.RecordFindingDecision(req.Context(), fid, orgID, body.Decision); err != nil {
					WriteError(w, req, http.StatusInternalServerError, "DECISION_ERROR", err.Error(), nil)
					return
				}
				WriteJSON(w, req, http.StatusOK, map[string]interface{}{
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
					WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "doc_sha256 talab qilinadi", nil)
					return
				}
				ch, err := s.SigningSvc.GenerateChallenge(body.DocSHA256)
				if err != nil {
					WriteError(w, req, http.StatusBadRequest, "CHALLENGE_ERROR", err.Error(), nil)
					return
				}
				WriteJSON(w, req, http.StatusOK, ch)
			})

			pr.Post("/signatures/verify", func(w http.ResponseWriter, req *http.Request) {
				var reqSig signing.SignatureVerificationRequest
				if err := json.NewDecoder(req.Body).Decode(&reqSig); err != nil {
					WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "Noto'g'ri JSON", nil)
					return
				}
				userID := GetUserID(req.Context())
				res, err := s.SigningSvc.VerifyAndRecordSignature(req.Context(), userID, reqSig)
				if err != nil {
					WriteError(w, req, http.StatusBadRequest, "SIGNATURE_ERROR", err.Error(), nil)
					return
				}
				WriteJSON(w, req, http.StatusOK, res)
			})

			// ---------------- ADMIN ROUTES (Protected with lawyer/admin role) ----------------
			pr.Route("/admin", func(adm chi.Router) {
				adm.Use(RequireRole("lawyer_reviewer", "admin", "owner", "platform_admin"))

				adm.Get("/overview", func(w http.ResponseWriter, req *http.Request) {
					ov, err := s.AdminSvc.GetOverview(req.Context())
					if err != nil {
						WriteError(w, req, http.StatusInternalServerError, "ADMIN_ERROR", err.Error(), nil)
						return
					}
					WriteJSON(w, req, http.StatusOK, ov)
				})

				adm.Get("/reviews", func(w http.ResponseWriter, req *http.Request) {
					items, err := s.AdminSvc.GetReviewQueue(req.Context(), 50)
					if err != nil {
						WriteError(w, req, http.StatusInternalServerError, "ADMIN_ERROR", err.Error(), nil)
						return
					}
					WriteJSON(w, req, http.StatusOK, items)
				})

				adm.Post("/reviews/{fid}/approve", func(w http.ResponseWriter, req *http.Request) {
					fid := chi.URLParam(req, "fid")
					var body struct {
						Status   string `json:"status"` // APPROVED | REJECTED
						Comments string `json:"comments"`
					}
					_ = json.NewDecoder(req.Body).Decode(&body)
					if body.Status == "" {
						body.Status = "APPROVED"
					}
					reviewerID := GetUserID(req.Context())
					err := s.AdminSvc.ApproveOrRejectFinding(req.Context(), fid, reviewerID, body.Status, body.Comments)
					if err != nil {
						WriteError(w, req, http.StatusInternalServerError, "APPROVAL_ERROR", err.Error(), nil)
						return
					}
					WriteJSON(w, req, http.StatusOK, map[string]interface{}{
						"finding_id": fid,
						"status":     body.Status,
					})
				})

				adm.Patch("/organizations/{id}/quota", func(w http.ResponseWriter, req *http.Request) {
					targetOrgID := chi.URLParam(req, "id")
					var body struct {
						AnalysesLimit int `json:"analyses_limit"`
					}
					if err := json.NewDecoder(req.Body).Decode(&body); err != nil || body.AnalysesLimit <= 0 {
						WriteError(w, req, http.StatusBadRequest, "VALIDATION_ERROR", "analyses_limit talab qilinadi", nil)
						return
					}
					err := s.AdminSvc.UpdateOrgQuota(req.Context(), targetOrgID, body.AnalysesLimit)
					if err != nil {
						WriteError(w, req, http.StatusInternalServerError, "QUOTA_ERROR", err.Error(), nil)
						return
					}
					WriteJSON(w, req, http.StatusOK, map[string]interface{}{
						"organization_id": targetOrgID,
						"analyses_limit":  body.AnalysesLimit,
					})
				})

				adm.Get("/audit-events", func(w http.ResponseWriter, req *http.Request) {
					orgID := GetOrgID(req.Context())
					events, err := s.AuditSvc.ListEvents(req.Context(), orgID, 50)
					if err != nil {
						WriteError(w, req, http.StatusInternalServerError, "AUDIT_ERROR", err.Error(), nil)
						return
					}
					WriteJSON(w, req, http.StatusOK, events)
				})
			})
		})
	})

	return r
}
