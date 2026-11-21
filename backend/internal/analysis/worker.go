package analysis

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/lexguard/backend/internal/ai"
	"github.com/lexguard/backend/internal/rules"
	"github.com/lexguard/backend/internal/verification"
)

type WorkerPool struct {
	svc     *Service
	workers int
	stopCh  chan struct{}
}

func NewWorkerPool(svc *Service, workers int) *WorkerPool {
	if workers <= 0 {
		workers = 4
	}
	return &WorkerPool{
		svc:     svc,
		workers: workers,
		stopCh:  make(chan struct{}),
	}
}

func (wp *WorkerPool) Start(ctx context.Context) {
	log.Printf("[INFO] Analysis Worker Pool started with %d workers (PG FOR UPDATE SKIP LOCKED)\n", wp.workers)
	for i := 0; i < wp.workers; i++ {
		workerID := fmt.Sprintf("worker-%d", i+1)
		go wp.runWorker(ctx, workerID)
	}
}

func (wp *WorkerPool) Stop() {
	close(wp.stopCh)
}

func (wp *WorkerPool) runWorker(ctx context.Context, workerID string) {
	ticker := time.NewTicker(500 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-wp.stopCh:
			return
		case <-ticker.C:
			wp.processNextJob(ctx, workerID)
		}
	}
}

func (wp *WorkerPool) processNextJob(ctx context.Context, workerID string) {
	tx, err := wp.svc.db.Begin(ctx)
	if err != nil {
		return
	}
	defer tx.Rollback(ctx)

	// FOR UPDATE SKIP LOCKED - safe concurrency across all worker instances!
	sqlJob := `
		SELECT id, analysis_id, attempts
		FROM analysis_jobs
		WHERE status IN ('PENDING', 'RETRY')
		  AND (lease_until IS NULL OR lease_until < NOW())
		ORDER BY created_at ASC
		LIMIT 1
		FOR UPDATE SKIP LOCKED
	`
	var jobID, analysisID string
	var attempts int
	err = tx.QueryRow(ctx, sqlJob).Scan(&jobID, &analysisID, &attempts)
	if err != nil {
		return // no job in queue
	}

	// Claim lease
	_, err = tx.Exec(ctx, `
		UPDATE analysis_jobs
		SET status = 'IN_PROGRESS', worker_id = $1, lease_until = NOW() + INTERVAL '45 seconds', attempts = attempts + 1, updated_at = NOW()
		WHERE id = $2
	`, workerID, jobID)
	if err != nil {
		return
	}

	// Update analysis status
	_, _ = tx.Exec(ctx, `UPDATE analyses SET status = 'IN_PROGRESS', updated_at = NOW() WHERE id = $1`, analysisID)

	if err := tx.Commit(ctx); err != nil {
		return
	}

	// Notify SSE
	wp.svc.broadcaster.Broadcast(analysisID, "stage_changed", map[string]string{
		"stage":   "PROCESSING",
		"message": "Shartnoma bandlari tahlil qilinmoqda...",
	})

	// Execute Pipeline
	err = wp.executePipeline(ctx, analysisID)
	if err != nil {
		log.Printf("[ERR] Analysis job %s failed: %v\n", jobID, err)
		_, _ = wp.svc.db.Exec(ctx, `
			UPDATE analysis_jobs SET status = 'FAILED', error_message = $1, updated_at = NOW() WHERE id = $2
		`, err.Error(), jobID)
		_, _ = wp.svc.db.Exec(ctx, `UPDATE analyses SET status = 'FAILED', updated_at = NOW() WHERE id = $1`, analysisID)
		wp.svc.broadcaster.Broadcast(analysisID, "error", map[string]string{"error": err.Error()})
		return
	}

	// Mark Job as Completed
	_, _ = wp.svc.db.Exec(ctx, `UPDATE analysis_jobs SET status = 'COMPLETED', updated_at = NOW() WHERE id = $1`, jobID)
}

func (wp *WorkerPool) executePipeline(ctx context.Context, analysisID string) error {
	start := time.Now()

	// 1. Load Analysis and Document
	sql := `
		SELECT a.organization_id, a.document_id, a.contract_date, a.doc_type, a.execution_mode,
		       d.data_classification, d.parse_confidence
		FROM analyses a
		JOIN documents d ON a.document_id = d.id
		WHERE a.id = $1
	`
	var orgID, docID, docType, execMode, classStr string
	var contractDate time.Time
	var parseConfidence float64
	err := wp.svc.db.QueryRow(ctx, sql, analysisID).Scan(
		&orgID, &docID, &contractDate, &docType, &execMode,
		&classStr, &parseConfidence,
	)
	if err != nil {
		return fmt.Errorf("tahlil ma'lumotlari topilmadi: %w", err)
	}

	doc, err := wp.svc.docRepo.GetDocument(ctx, docID, orgID)
	if err != nil {
		return fmt.Errorf("hujjat bandlari yuklanmadi: %w", err)
	}

	// Build full document text and clauses map
	clausesMap := make(map[string]string)
	var fullDocBuilder strings.Builder
	totalPIIMasked := 0
	for _, c := range doc.Clauses {
		clausesMap[c.ClauseNumber] = c.RawText
		fullDocBuilder.WriteString(c.RawText)
		fullDocBuilder.WriteString("\n")
		totalPIIMasked += len(c.PIIEntities)
	}
	fullDocText := fullDocBuilder.String()

	// 2. Run Deterministic Go Rules Engine
	ruleFindings := wp.svc.rulesEngine.AnalyzeDocument(clausesMap, fullDocText)

	// Broadcast early rule findings via SSE!
	for _, rf := range ruleFindings {
		wp.svc.broadcaster.Broadcast(analysisID, "partial_rule_finding", rf)
	}

	// 3. Process each clause with RAG + Arbiter
	verifiedFindings := make([]verification.VerifiedFinding, 0)
	var totalTokens int

	for _, c := range doc.Clauses {
		clauseRFs := wp.svc.rulesEngine.AnalyzeClause(c.ClauseNumber, c.RawText, fullDocText)

		// Temporal Hybrid RAG
		articles, _ := wp.svc.corpusRepo.SearchHybrid(ctx, c.RedactedText, contractDate, docType, 3)
		candidateNames := make([]string, 0)
		for _, art := range articles {
			candidateNames = append(candidateNames, fmt.Sprintf("%s %s: %s", art.SourceCode, art.ArticleNumber, art.Title))
		}

		// AI Provider draft
		var llmDraft *ai.DraftSuggestion
		if execMode == "HYBRID_AI" {
			draft, metrics, err := wp.svc.aiProvider.AnalyzeClause(ctx, ai.RedactedClauseRequest{
				ClauseNumber:      c.ClauseNumber,
				RedactedText:      c.RedactedText,
				ContractDate:      contractDate.Format("2006-01-02"),
				DocType:           docType,
				CandidateArticles: candidateNames,
			})
			if err == nil && draft != nil {
				llmDraft = draft
				if metrics != nil {
					totalTokens += metrics.TotalTokens
				}
			}
		}

		// 10-Vector Anti-Hallucination Arbiter Gate
		vfs := wp.svc.arbiter.Arbitrate(ctx, c.ClauseNumber, c.RawText, contractDate, parseConfidence, clauseRFs, llmDraft)
		for i := range vfs {
			vfs[i].ID = uuid.NewString()
			verifiedFindings = append(verifiedFindings, vfs[i])
		}
	}

	// Also add document-level findings (missing clauses)
	for _, rf := range ruleFindings {
		if rf.ClauseNumber == "UMUMIY" {
			vfs := wp.svc.arbiter.Arbitrate(ctx, "UMUMIY", rf.OriginalQuote, contractDate, parseConfidence, []rules.RuleFinding{rf}, nil)
			for i := range vfs {
				vfs[i].ID = uuid.NewString()
				verifiedFindings = append(verifiedFindings, vfs[i])
			}
		}
	}

	// 4. Persist findings to database
	tx, err := wp.svc.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	sqlInsertFinding := `
		INSERT INTO findings (
			id, analysis_id, clause_number, rule_code, risk_category,
			severity, verification_status, original_quote, suggested_revision,
			legal_source_version_id, score, explanation, created_at
		) VALUES (
			$1, $2, $3, $4, $5,
			$6, $7, $8, $9,
			NULLIF($10, '')::uuid, $11, $12, NOW()
		)
	`
	summary := AnalysisSummary{
		PIIMasked: totalPIIMasked,
	}

	overallScore := 0
	for _, vf := range verifiedFindings {
		lsvID := ""
		if vf.LegalSourceVersionID != nil {
			lsvID = *vf.LegalSourceVersionID
		}

		_, err := tx.Exec(ctx, sqlInsertFinding,
			vf.ID, analysisID, vf.ClauseNumber, vf.RuleCode, vf.RiskCategory,
			vf.Severity, string(vf.VerificationStatus), vf.OriginalQuote, vf.SuggestedRevision,
			lsvID, vf.Score, vf.Explanation,
		)
		if err != nil {
			return fmt.Errorf("finding insert xatolik: %w", err)
		}

		switch vf.Severity {
		case "RED":
			summary.RedLegal++
			overallScore += 30
		case "YELLOW":
			summary.YellowComm++
			overallScore += 15
		default:
			summary.GreenOK++
		}

		if vf.VerificationStatus == verification.StatusReviewRequired {
			summary.ReviewRequired++
			// Auto create approval queue item for human lawyer!
			_, _ = tx.Exec(ctx, `
				INSERT INTO approvals (id, analysis_id, finding_id, status, created_at)
				VALUES (gen_random_uuid(), $1, $2, 'PENDING', NOW())
			`, analysisID, vf.ID)
		}
	}

	if overallScore > 100 {
		overallScore = 100
	}
	riskLevel := "GREEN"
	if overallScore >= 60 || summary.RedLegal > 0 {
		riskLevel = "RED"
	} else if overallScore >= 20 || summary.YellowComm > 0 {
		riskLevel = "YELLOW"
	}

	durationMS := int(time.Since(start).Milliseconds())
	costMetrics := CostMetrics{
		TokensUsed: totalTokens,
		DurationMS: durationMS,
	}

	summaryBytes, _ := json.Marshal(summary)
	costBytes, _ := json.Marshal(costMetrics)

	// 5. Update Analysis as COMPLETED
	sqlUpdateAnalysis := `
		UPDATE analyses
		SET status = 'COMPLETED', overall_risk_score = $1, risk_level = $2,
		    summary_json = $3, cost_metrics_json = $4, completed_at = NOW(), updated_at = NOW()
		WHERE id = $5
	`
	_, err = tx.Exec(ctx, sqlUpdateAnalysis, overallScore, riskLevel, summaryBytes, costBytes, analysisID)
	if err != nil {
		return fmt.Errorf("analysis update xatolik: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return err
	}

	// 6. Broadcast SSE Completed
	wp.svc.broadcaster.Broadcast(analysisID, "completed", map[string]interface{}{
		"analysis_id":        analysisID,
		"overall_risk_score": overallScore,
		"risk_level":         riskLevel,
		"summary":            summary,
		"duration_ms":        durationMS,
	})

	log.Printf("[INFO] Analysis %s COMPLETED in %dms | Score: %d (%s) | Red: %d, Yellow: %d\n",
		analysisID, durationMS, overallScore, riskLevel, summary.RedLegal, summary.YellowComm)

	return nil
}
