package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/lexguard/backend/internal/admin"
	"github.com/lexguard/backend/internal/ai"
	"github.com/lexguard/backend/internal/analysis"
	"github.com/lexguard/backend/internal/api"
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
	"github.com/lexguard/backend/internal/verification"
)

func main() {
	// 0. Distroless-friendly built-in container healthcheck probe
	if len(os.Args) > 1 && (os.Args[1] == "healthcheck" || os.Args[1] == "-healthcheck" || os.Args[1] == "--healthcheck") {
		client := &http.Client{Timeout: 3 * time.Second}
		resp, err := client.Get("http://127.0.0.1:8080/healthz")
		if err != nil || resp.StatusCode != http.StatusOK {
			fmt.Fprintf(os.Stderr, "healthcheck failed: err=%v, code=%v\n", err, resp)
			os.Exit(1)
		}
		os.Exit(0)
	}

	log.Println("=================================================================")
	log.Println("  🛡️  LEXGUARD AI 3.0 — GO MODULAR MONOLITH BACKEND SERVER")
	log.Println("  Chuqur Xavfsizlik (O'RQ-547/1115/1125) & Temporal RAG Engine")
	log.Println("=================================================================")

	// 1. Load Config & Initialize Structured Logger (slog)
	cfg := platform.LoadConfig()
	logger := platform.InitLogger(cfg.AppEnv)
	slog.Info("lexguard_startup",
		slog.String("version", "3.0.0"),
		slog.String("env", cfg.AppEnv),
		slog.String("http_addr", cfg.HTTPAddr),
		slog.String("ai_provider", cfg.AIProvider),
		slog.Bool("external_ai_enabled", cfg.ExternalAIEnabled),
	)

	// 2. Initialize Database Pool
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	dbPool, err := platform.NewDBPool(ctx, cfg.DatabaseURL)
	if err != nil {
		slog.Error("postgres_connection_failed", slog.Any("error", err))
		log.Fatalf("[FATAL] PostgreSQL ulanishida xatolik: %v", err)
	}
	defer dbPool.Close()
	slog.Info("postgres_connected", slog.String("db_url", cfg.DatabaseURL))

	// 3. Instantiate Domain Kernels
	jwtManager := platform.NewJWTManager(cfg.JWTSecret)
	redactor := privacy.NewRedactor()
	llmGate := privacy.NewExternalLLMGate()
	rulesEngine := rules.NewRulesEngine()

	// Repositories & Adapters
	docRepo := documents.NewRepository(dbPool)
	corpusRepo := legalcorpus.NewRepository(dbPool)
	aiEngineClient := ai.NewEngineClient()
	aiProvider := ai.NewProvider(cfg.AIProvider)
	arbiter := verification.NewArbiter(corpusRepo, aiEngineClient)
	broadcaster := analysis.NewSSEBroadcaster()

	// Services
	identitySvc := identity.NewService(dbPool, jwtManager)
	billingSvc := billing.NewService(dbPool)
	auditSvc := audit.NewService(dbPool)
	analysisSvc := analysis.NewService(
		dbPool, docRepo, corpusRepo, billingSvc,
		rulesEngine, aiProvider, arbiter, llmGate, broadcaster,
	)
	analysisSvc.SetExternalAIEnabled(cfg.ExternalAIEnabled)
	reportSvc := report.NewService(analysisSvc)
	signingSvc := signing.NewService(dbPool)
	adminSvc := admin.NewService(dbPool)

	// 4. Start Background Worker Pool (FOR UPDATE SKIP LOCKED)
	workerPool := analysis.NewWorkerPool(analysisSvc, 4)
	workerPool.Start(ctx)
	defer workerPool.Stop()

	// 5. Build HTTP Router
	routerServices := &api.RouterServices{
		DB:          dbPool,
		Config:      cfg,
		JWTManager:  jwtManager,
		IdentitySvc: identitySvc,
		DocRepo:     docRepo,
		CorpusRepo:  corpusRepo,
		RulesEngine: rulesEngine,
		AnalysisSvc: analysisSvc,
		ReportSvc:   reportSvc,
		SigningSvc:  signingSvc,
		BillingSvc:  billingSvc,
		AuditSvc:    auditSvc,
		AdminSvc:    adminSvc,
		Redactor:    redactor,
		AIEngine:    aiEngineClient,
	}
	handler := api.BuildRouter(routerServices)

	// 6. Start HTTP Server
	server := &http.Server{
		Addr:         cfg.HTTPAddr,
		Handler:      handler,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 60 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	go func() {
		slog.Info("server_listening",
			slog.String("addr", cfg.HTTPAddr),
			slog.String("healthz", fmt.Sprintf("http://127.0.0.1%s/healthz", cfg.HTTPAddr)),
			slog.String("readyz", fmt.Sprintf("http://127.0.0.1%s/readyz", cfg.HTTPAddr)),
		)
		log.Printf("[INFO] Server tinglamoqda -> http://127.0.0.1%s\n", cfg.HTTPAddr)
		log.Printf("[INFO] API Docs / Readyz: http://127.0.0.1%s/readyz\n", cfg.HTTPAddr)
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			slog.Error("server_fatal_error", slog.Any("error", err))
			log.Fatalf("[FATAL] HTTP server xatosi: %v", err)
		}
	}()

	// 7. Graceful Shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	sig := <-quit
	slog.Info("shutdown_signal_received", slog.String("signal", sig.String()))
	log.Printf("[INFO] Signal qabul qilindi (%s). Server to'xtatilmoqda...\n", sig)

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer shutdownCancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		slog.Error("forced_shutdown", slog.Any("error", err))
		log.Printf("[ERR] Server majburiy to'xtatildi: %v", err)
	}

	_ = logger
	slog.Info("server_stopped_gracefully")
	log.Println("[INFO] LexGuard AI serveri muvaffaqiyatli to'xtatildi.")
}
