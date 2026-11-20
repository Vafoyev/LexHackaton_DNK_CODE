package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

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
	"github.com/lexguard/backend/internal/verification"
)

func main() {
	log.Println("=================================================================")
	log.Println("  🛡️  LEXGUARD AI 3.0 — GO MODULAR MONOLITH BACKEND SERVER")
	log.Println("  Chuqur Xavfsizlik (O'RQ-547/1115/1125) & Temporal RAG Engine")
	log.Println("=================================================================")

	// 1. Load Config
	cfg := platform.LoadConfig()

	// 2. Initialize Database Pool
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	dbPool, err := platform.NewDBPool(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("[FATAL] PostgreSQL ulanishida xatolik: %v", err)
	}
	defer dbPool.Close()

	// 3. Instantiate Domain Kernels
	jwtManager := platform.NewJWTManager(cfg.JWTSecret)
	redactor := privacy.NewRedactor()
	llmGate := privacy.NewExternalLLMGate()
	rulesEngine := rules.NewRulesEngine()

	// Repositories & Adapters
	docRepo := documents.NewRepository(dbPool)
	corpusRepo := legalcorpus.NewRepository(dbPool)
	aiProvider := ai.NewProvider(cfg.AIProvider)
	arbiter := verification.NewArbiter(corpusRepo)
	broadcaster := analysis.NewSSEBroadcaster()

	// Services
	identitySvc := identity.NewService(dbPool, jwtManager)
	billingSvc := billing.NewService(dbPool)
	auditSvc := audit.NewService(dbPool)
	analysisSvc := analysis.NewService(
		dbPool, docRepo, corpusRepo, billingSvc,
		rulesEngine, aiProvider, arbiter, llmGate, broadcaster,
	)
	reportSvc := report.NewService(analysisSvc)
	signingSvc := signing.NewService(dbPool)
	adminSvc := admin.NewService(dbPool)

	// 4. Start Background Worker Pool (FOR UPDATE SKIP LOCKED)
	workerPool := analysis.NewWorkerPool(analysisSvc, 4)
	workerPool.Start(ctx)
	defer workerPool.Stop()

	// 5. Build HTTP Router
	routerServices := &platform.RouterServices{
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
	}
	handler := platform.BuildRouter(routerServices)

	// 6. Start HTTP Server
	server := &http.Server{
		Addr:         cfg.HTTPAddr,
		Handler:      handler,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 60 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	go func() {
		log.Printf("[INFO] Server tinglamoqda -> http://127.0.0.1%s\n", cfg.HTTPAddr)
		log.Printf("[INFO] API Docs / Readiez: http://127.0.0.1%s/readyz\n", cfg.HTTPAddr)
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("[FATAL] HTTP server xatosi: %v", err)
		}
	}()

	// 7. Graceful Shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	sig := <-quit
	log.Printf("[INFO] Signal qabul qilindi (%s). Server to'xtatilmoqda...\n", sig)

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer shutdownCancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Printf("[ERR] Server majburiy to'xtatildi: %v", err)
	}

	log.Println("[INFO] LexGuard AI serveri muvaffaqiyatli to'xtatildi.")
}
