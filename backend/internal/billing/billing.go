package billing

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type QuotaInfo struct {
	OrganizationID string    `json:"organization_id"`
	PlanName       string    `json:"plan_name"`
	AnalysesLimit  int       `json:"analyses_limit"`
	AnalysesUsed   int       `json:"analyses_used"`
	AnalysesLeft   int       `json:"analyses_left"`
	TokensLimit    int       `json:"tokens_limit"`
	TokensUsed     int       `json:"tokens_used"`
	PeriodStart    time.Time `json:"period_start"`
	PeriodEnd      time.Time `json:"period_end"`
}

type PlanInfo struct {
	Name             string   `json:"name"`
	PriceUZS         int64    `json:"price_uzs"`
	AnalysesLimit    int      `json:"analyses_limit"`
	TokensLimit      int      `json:"tokens_limit"`
	Features         []string `json:"features"`
}

type Service struct {
	db *pgxpool.Pool
}

func NewService(db *pgxpool.Pool) *Service {
	return &Service{db: db}
}

func (s *Service) ReserveAnalysisQuota(ctx context.Context, orgID string) error {
	sql := `
		UPDATE quotas
		SET analyses_used = analyses_used + 1, updated_at = NOW()
		WHERE organization_id = $1 AND analyses_used < analyses_limit
		RETURNING analyses_limit, analyses_used
	`
	var limit, used int
	err := s.db.QueryRow(ctx, sql, orgID).Scan(&limit, &used)
	if err != nil {
		return errors.New("oylik tahlil kvotasi tugagan yoki mavjud emas (QUOTA_EXCEEDED)")
	}
	return nil
}

func (s *Service) GetQuota(ctx context.Context, orgID string) (*QuotaInfo, error) {
	sql := `
		SELECT organization_id, plan_name, analyses_limit, analyses_used,
		       tokens_limit, tokens_used, period_start, period_end
		FROM quotas
		WHERE organization_id = $1
	`
	var q QuotaInfo
	err := s.db.QueryRow(ctx, sql, orgID).Scan(
		&q.OrganizationID, &q.PlanName, &q.AnalysesLimit, &q.AnalysesUsed,
		&q.TokensLimit, &q.TokensUsed, &q.PeriodStart, &q.PeriodEnd,
	)
	if err != nil {
		// If org has no quota row yet, auto-provision STARTER trial
		insertSQL := `
			INSERT INTO quotas (organization_id, plan_name, analyses_limit, analyses_used, tokens_limit, tokens_used)
			VALUES ($1, 'STARTER', 50, 0, 500000, 0)
			ON CONFLICT (organization_id) DO NOTHING
			RETURNING organization_id, plan_name, analyses_limit, analyses_used, tokens_limit, tokens_used, period_start, period_end
		`
		err = s.db.QueryRow(ctx, insertSQL, orgID).Scan(
			&q.OrganizationID, &q.PlanName, &q.AnalysesLimit, &q.AnalysesUsed,
			&q.TokensLimit, &q.TokensUsed, &q.PeriodStart, &q.PeriodEnd,
		)
		if err != nil {
			return nil, fmt.Errorf("kvota ma'lumotlarini yuklab bo'lmadi: %w", err)
		}
	}
	q.AnalysesLeft = q.AnalysesLimit - q.AnalysesUsed
	if q.AnalysesLeft < 0 {
		q.AnalysesLeft = 0
	}
	return &q, nil
}

func (s *Service) GetAvailablePlans() []PlanInfo {
	return []PlanInfo{
		{
			Name:          "FREE",
			PriceUZS:      0,
			AnalysesLimit: 5,
			TokensLimit:   50000,
			Features:      []string{"10 ta deterministik qoida", "Oddiy tahlil hisoboti"},
		},
		{
			Name:          "STARTER",
			PriceUZS:      199000,
			AnalysesLimit: 50,
			TokensLimit:   500000,
			Features:      []string{"B2B Xizmat shartnomasi qoidalari", "Temporal RAG (FK, O'RQ-547, 1115)", "DOCX/PDF eksport", "SSE Real-time progress"},
		},
		{
			Name:          "PRO",
			PriceUZS:      399000,
			AnalysesLimit: 200,
			TokensLimit:   2000000,
			Features:      []string{"Barcha turdagi shartnomalar", "10-vektorli anti-gallyutsinatsiya filtri", "Yurist Review navbati", "E-IMZO tekshiruvi"},
		},
	}
}
