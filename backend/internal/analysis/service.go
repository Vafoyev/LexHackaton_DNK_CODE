package analysis

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/lexguard/backend/internal/ai"
	"github.com/lexguard/backend/internal/billing"
	"github.com/lexguard/backend/internal/documents"
	"github.com/lexguard/backend/internal/legalcorpus"
	"github.com/lexguard/backend/internal/privacy"
	"github.com/lexguard/backend/internal/rules"
	"github.com/lexguard/backend/internal/verification"
)

type AnalysisSummary struct {
	RedLegal       int `json:"red_legal"`
	YellowComm     int `json:"yellow_commercial"`
	GreenOK        int `json:"green_ok"`
	ReviewRequired int `json:"review_required"`
	PIIMasked      int `json:"pii_masked"`
}

type CostMetrics struct {
	TokensUsed int `json:"tokens_used"`
	DurationMS int `json:"duration_ms"`
}

type FlaggedClause struct {
	ClauseNumber       string                 `json:"clause_number"`
	ClauseText         string                 `json:"clause_text"`
	RiskLevel          string                 `json:"risk_level"` // RED, YELLOW, GREEN
	LawReference       *FlaggedLawReference   `json:"law_reference,omitempty"`
	SuggestedAmendment string                 `json:"suggested_amendment"`
}

type FlaggedLawReference struct {
	LawTitle    string `json:"law_title"`
	Article     string `json:"article"`
	LexUzURL    string `json:"lex_uz_url"`
	Explanation string `json:"explanation"`
}

type AnalysisDetail struct {
	ID               string                 `json:"id"`
	ContractID       string                 `json:"contract_id"` // alias for frontend / CONTRACTS.md
	Filename         string                 `json:"filename"`
	SHA256           string                 `json:"sha256"`
	Status           string                 `json:"status"`
	ExecutionMode    string                 `json:"execution_mode"`
	DocType          string                 `json:"doc_type"`
	ContractDate     string                 `json:"contract_date"`
	Disclaimer       string                 `json:"disclaimer"`
	OverallRiskScore int                    `json:"overall_risk_score"`
	RiskLevel        string                 `json:"risk_level"`
	TotalClauses     int                    `json:"total_clauses"`
	FlaggedClauses   []FlaggedClause        `json:"flagged_clauses"`
	Summary          AnalysisSummary        `json:"summary"`
	CostMetrics      CostMetrics            `json:"cost_metrics"`
	Findings         []verification.VerifiedFinding `json:"findings"`
	CreatedAt        time.Time              `json:"created_at"`
	CompletedAt      *time.Time             `json:"completed_at,omitempty"`
}

type SSEBroadcaster struct {
	subscribers map[string][]chan string
	mu          sync.RWMutex
}

func NewSSEBroadcaster() *SSEBroadcaster {
	return &SSEBroadcaster{
		subscribers: make(map[string][]chan string),
	}
}

func (b *SSEBroadcaster) Subscribe(analysisID string) chan string {
	b.mu.Lock()
	defer b.mu.Unlock()
	ch := make(chan string, 20)
	b.subscribers[analysisID] = append(b.subscribers[analysisID], ch)
	return ch
}

func (b *SSEBroadcaster) Unsubscribe(analysisID string, ch chan string) {
	b.mu.Lock()
	defer b.mu.Unlock()
	channels := b.subscribers[analysisID]
	for i, c := range channels {
		if c == ch {
			b.subscribers[analysisID] = append(channels[:i], channels[i+1:]...)
			close(ch)
			break
		}
	}
}

func (b *SSEBroadcaster) Broadcast(analysisID, eventType string, data interface{}) {
	b.mu.RLock()
	defer b.mu.RUnlock()
	channels, ok := b.subscribers[analysisID]
	if !ok || len(channels) == 0 {
		return
	}

	payload, _ := json.Marshal(data)
	msg := fmt.Sprintf("event: %s\ndata: %s\n\n", eventType, string(payload))

	for _, ch := range channels {
		select {
		case ch <- msg:
		default:
		}
	}
}

type Service struct {
	db          *pgxpool.Pool
	docRepo     *documents.Repository
	corpusRepo  *legalcorpus.Repository
	billingSvc  *billing.Service
	rulesEngine *rules.RulesEngine
	aiProvider  ai.Provider
	arbiter     *verification.Arbiter
	llmGate     *privacy.ExternalLLMGate
	broadcaster *SSEBroadcaster
}

func NewService(
	db *pgxpool.Pool,
	docRepo *documents.Repository,
	corpusRepo *legalcorpus.Repository,
	billingSvc *billing.Service,
	rulesEngine *rules.RulesEngine,
	aiProvider ai.Provider,
	arbiter *verification.Arbiter,
	llmGate *privacy.ExternalLLMGate,
	broadcaster *SSEBroadcaster,
) *Service {
	return &Service{
		db:          db,
		docRepo:     docRepo,
		corpusRepo:  corpusRepo,
		billingSvc:  billingSvc,
		rulesEngine: rulesEngine,
		aiProvider:  aiProvider,
		arbiter:     arbiter,
		llmGate:     llmGate,
		broadcaster: broadcaster,
	}
}

func (s *Service) Broadcaster() *SSEBroadcaster {
	return s.broadcaster
}

func (s *Service) CreateAnalysis(
	ctx context.Context,
	orgID, docID, contractDate, docType, execMode string,
) (string, error) {
	// 1. Check & Reserve Quota
	if err := s.billingSvc.ReserveAnalysisQuota(ctx, orgID); err != nil {
		return "", err
	}

	if contractDate == "" {
		contractDate = time.Now().Format("2006-01-02")
	}
	if docType == "" {
		docType = "SERVICE_AGREEMENT"
	}
	if execMode == "" {
		execMode = "HYBRID_AI"
	}

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(ctx)

	// 2. Insert into analyses
	sqlAnalysis := `
		INSERT INTO analyses (
			id, organization_id, document_id, status, execution_mode,
			doc_type, contract_date, created_at, updated_at
		) VALUES (
			gen_random_uuid(), $1, $2, 'PENDING', $3,
			$4, $5::date, NOW(), NOW()
		) RETURNING id
	`
	var analysisID string
	err = tx.QueryRow(ctx, sqlAnalysis, orgID, docID, execMode, docType, contractDate).Scan(&analysisID)
	if err != nil {
		return "", fmt.Errorf("tahlil yozuvini yaratishda xatolik: %w", err)
	}

	// 3. Insert into analysis_jobs (Worker queue)
	sqlJob := `
		INSERT INTO analysis_jobs (
			id, analysis_id, status, attempts, max_attempts, created_at, updated_at
		) VALUES (
			gen_random_uuid(), $1, 'PENDING', 0, 3, NOW(), NOW()
		)
	`
	if _, err := tx.Exec(ctx, sqlJob, analysisID); err != nil {
		return "", fmt.Errorf("tahlil navbatiga qo'shishda xatolik: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return "", err
	}

	return analysisID, nil
}

func (s *Service) GetAnalysis(ctx context.Context, analysisID, orgID string) (*AnalysisDetail, error) {
	sql := `
		SELECT a.id, a.document_id, d.filename, d.sha256, a.status, a.execution_mode,
		       a.doc_type, a.contract_date::text, a.disclaimer, a.overall_risk_score,
		       a.risk_level, a.summary_json, a.cost_metrics_json, a.created_at, a.completed_at
		FROM analyses a
		JOIN documents d ON a.document_id = d.id
		WHERE a.id = $1 AND a.organization_id = $2
	`
	var det AnalysisDetail
	var summaryBytes, metricsBytes []byte
	err := s.db.QueryRow(ctx, sql, analysisID, orgID).Scan(
		&det.ID, &det.ContractID, &det.Filename, &det.SHA256, &det.Status, &det.ExecutionMode,
		&det.DocType, &det.ContractDate, &det.Disclaimer, &det.OverallRiskScore,
		&det.RiskLevel, &summaryBytes, &metricsBytes, &det.CreatedAt, &det.CompletedAt,
	)
	if err != nil {
		return nil, err
	}
	_ = json.Unmarshal(summaryBytes, &det.Summary)
	_ = json.Unmarshal(metricsBytes, &det.CostMetrics)

	// Fetch clauses count
	var totalClauses int
	_ = s.db.QueryRow(ctx, `SELECT count(*) FROM clauses WHERE document_id = $1`, det.ContractID).Scan(&totalClauses)
	det.TotalClauses = totalClauses

	// Fetch verified findings
	sqlFindings := `
		SELECT f.id, f.clause_number, f.rule_code, f.risk_category, f.severity,
		       f.verification_status, f.original_quote, f.suggested_revision,
		       f.legal_source_version_id::text, f.score, f.explanation,
		       COALESCE(ls.code, ''), COALESCE(lsv.article_number, ''),
		       COALESCE(lsv.norm_nature, ''), COALESCE(lsv.official_url, '')
		FROM findings f
		LEFT JOIN legal_source_versions lsv ON f.legal_source_version_id = lsv.id
		LEFT JOIN legal_sources ls ON lsv.source_id = ls.id
		WHERE f.analysis_id = $1
		ORDER BY f.created_at ASC
	`
	rows, err := s.db.Query(ctx, sqlFindings, analysisID)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var vf verification.VerifiedFinding
			var lsvIDStr string
			var lawCode, lawArt, normNature, officialURL string
			err := rows.Scan(
				&vf.ID, &vf.ClauseNumber, &vf.RuleCode, &vf.RiskCategory, &vf.Severity,
				&vf.VerificationStatus, &vf.OriginalQuote, &vf.SuggestedRevision,
				&lsvIDStr, &vf.Score, &vf.Explanation,
				&lawCode, &lawArt, &normNature, &officialURL,
			)
			if err == nil {
				if lsvIDStr != "" {
					vf.LegalSourceVersionID = &lsvIDStr
				}
				if lawArt != "" {
					vf.LegalSource = &rules.LegalReference{
						Code:        lawCode,
						Article:     lawArt,
						NormNature:  normNature,
						OfficialURL: officialURL,
						Explanation: vf.Explanation,
					}
				}
				det.Findings = append(det.Findings, vf)

				// Fill CONTRACTS.md flagged_clauses schema
				if vf.Severity == "RED" || vf.Severity == "YELLOW" {
					det.FlaggedClauses = append(det.FlaggedClauses, FlaggedClause{
						ClauseNumber: vf.ClauseNumber,
						ClauseText:   vf.OriginalQuote,
						RiskLevel:    vf.Severity,
						LawReference: &FlaggedLawReference{
							LawTitle:    lawCode,
							Article:     lawArt,
							LexUzURL:    officialURL,
							Explanation: vf.Explanation,
						},
						SuggestedAmendment: vf.SuggestedRevision,
					})
				}
			}
		}
	}

	return &det, nil
}

func (s *Service) ListAnalyses(ctx context.Context, orgID string, limit int) ([]AnalysisDetail, error) {
	if limit <= 0 {
		limit = 20
	}
	sql := `
		SELECT a.id, a.document_id, d.filename, d.sha256, a.status, a.execution_mode,
		       a.doc_type, a.contract_date::text, a.disclaimer, a.overall_risk_score,
		       a.risk_level, a.summary_json, a.cost_metrics_json, a.created_at, a.completed_at
		FROM analyses a
		JOIN documents d ON a.document_id = d.id
		WHERE a.organization_id = $1
		ORDER BY a.created_at DESC
		LIMIT $2
	`
	rows, err := s.db.Query(ctx, sql, orgID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	list := make([]AnalysisDetail, 0)
	for rows.Next() {
		var det AnalysisDetail
		var summaryBytes, metricsBytes []byte
		err := rows.Scan(
			&det.ID, &det.ContractID, &det.Filename, &det.SHA256, &det.Status, &det.ExecutionMode,
			&det.DocType, &det.ContractDate, &det.Disclaimer, &det.OverallRiskScore,
			&det.RiskLevel, &summaryBytes, &metricsBytes, &det.CreatedAt, &det.CompletedAt,
		)
		if err == nil {
			_ = json.Unmarshal(summaryBytes, &det.Summary)
			_ = json.Unmarshal(metricsBytes, &det.CostMetrics)
			list = append(list, det)
		}
	}
	return list, nil
}

func (s *Service) RecordFindingDecision(ctx context.Context, findingID, orgID, decision string) error {
	sql := `
		UPDATE findings
		SET client_decision = $1
		WHERE id = $2 AND analysis_id IN (SELECT id FROM analyses WHERE organization_id = $3)
	`
	_, err := s.db.Exec(ctx, sql, decision, findingID, orgID)
	return err
}
