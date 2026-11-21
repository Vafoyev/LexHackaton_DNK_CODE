package admin

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type SystemOverview struct {
	TotalAnalyses      int                      `json:"total_analyses"`
	TotalDocuments     int                      `json:"total_documents"`
	TotalOrganizations int                      `json:"total_organizations"`
	TotalFindings      int                      `json:"total_findings"`
	PendingReviews     int                      `json:"pending_reviews"`
	RedRisksCount      int                      `json:"red_risks_count"`
	YellowRisksCount   int                      `json:"yellow_risks_count"`
	TotalPIIMasked     int                      `json:"total_pii_masked"`
	ActiveWorkers      int                      `json:"active_workers"`
	Integrations       []map[string]interface{} `json:"integrations"`
}

type ReviewItem struct {
	ApprovalID   string    `json:"approval_id"`
	AnalysisID   string    `json:"analysis_id"`
	FindingID    string    `json:"finding_id"`
	Filename     string    `json:"filename"`
	ClauseNumber string    `json:"clause_number"`
	RuleCode     string    `json:"rule_code"`
	Severity     string    `json:"severity"`
	OriginalQuote string   `json:"original_quote"`
	SuggestedRevision string `json:"suggested_revision"`
	Explanation  string    `json:"explanation"`
	CreatedAt    time.Time `json:"created_at"`
}

type Service struct {
	db *pgxpool.Pool
}

func NewService(db *pgxpool.Pool) *Service {
	return &Service{db: db}
}

func (s *Service) GetOverview(ctx context.Context) (*SystemOverview, error) {
	ov := &SystemOverview{
		ActiveWorkers: 4,
	}

	_ = s.db.QueryRow(ctx, `SELECT count(*) FROM analyses`).Scan(&ov.TotalAnalyses)
	_ = s.db.QueryRow(ctx, `SELECT count(*) FROM documents WHERE deleted_at IS NULL`).Scan(&ov.TotalDocuments)
	_ = s.db.QueryRow(ctx, `SELECT count(*) FROM organizations`).Scan(&ov.TotalOrganizations)
	_ = s.db.QueryRow(ctx, `SELECT count(*) FROM findings`).Scan(&ov.TotalFindings)
	_ = s.db.QueryRow(ctx, `SELECT count(*) FROM approvals WHERE status = 'PENDING'`).Scan(&ov.PendingReviews)
	_ = s.db.QueryRow(ctx, `SELECT count(*) FROM findings WHERE severity = 'RED'`).Scan(&ov.RedRisksCount)
	_ = s.db.QueryRow(ctx, `SELECT count(*) FROM findings WHERE severity = 'YELLOW'`).Scan(&ov.YellowRisksCount)

	// Fetch integrations
	rows, err := s.db.Query(ctx, `SELECT name, mode, is_healthy, last_checked_at FROM integrations`)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var name, mode string
			var isHealthy bool
			var lastChecked time.Time
			if err := rows.Scan(&name, &mode, &isHealthy, &lastChecked); err == nil {
				ov.Integrations = append(ov.Integrations, map[string]interface{}{
					"name":            name,
					"mode":            mode,
					"is_healthy":      isHealthy,
					"last_checked_at": lastChecked,
				})
			}
		}
	}

	return ov, nil
}

func (s *Service) GetReviewQueue(ctx context.Context, limit int) ([]ReviewItem, error) {
	if limit <= 0 {
		limit = 50
	}
	sql := `
		SELECT ap.id, ap.analysis_id, ap.finding_id, d.filename, f.clause_number,
		       f.rule_code, f.severity, f.original_quote, f.suggested_revision,
		       f.explanation, ap.created_at
		FROM approvals ap
		JOIN findings f ON ap.finding_id = f.id
		JOIN analyses a ON ap.analysis_id = a.id
		JOIN documents d ON a.document_id = d.id
		WHERE ap.status = 'PENDING'
		ORDER BY ap.created_at ASC
		LIMIT $1
	`
	rows, err := s.db.Query(ctx, sql, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]ReviewItem, 0)
	for rows.Next() {
		var it ReviewItem
		err := rows.Scan(
			&it.ApprovalID, &it.AnalysisID, &it.FindingID, &it.Filename,
			&it.ClauseNumber, &it.RuleCode, &it.Severity, &it.OriginalQuote,
			&it.SuggestedRevision, &it.Explanation, &it.CreatedAt,
		)
		if err == nil {
			items = append(items, it)
		}
	}
	return items, nil
}

func (s *Service) ApproveOrRejectFinding(ctx context.Context, findingID, reviewerID, status, comments string) error {
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	// Update approval record
	_, err = tx.Exec(ctx, `
		UPDATE approvals
		SET status = $1, reviewer_id = NULLIF($2, '')::uuid, comments = $3, reviewed_at = NOW()
		WHERE finding_id = $4
	`, status, reviewerID, comments, findingID)
	if err != nil {
		return err
	}

	// If approved, update finding verification status
	if status == "APPROVED" {
		_, _ = tx.Exec(ctx, `UPDATE findings SET verification_status = 'VERIFIED' WHERE id = $1`, findingID)
	}

	return tx.Commit(ctx)
}

func (s *Service) UpdateOrgQuota(ctx context.Context, orgID string, newLimit int) error {
	sql := `UPDATE quotas SET analyses_limit = $1, updated_at = NOW() WHERE organization_id = $2`
	_, err := s.db.Exec(ctx, sql, newLimit, orgID)
	return err
}
