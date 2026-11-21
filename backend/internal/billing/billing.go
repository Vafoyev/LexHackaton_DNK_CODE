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
	Code          string   `json:"code"`
	Name          string   `json:"name"`
	Segment       string   `json:"segment"` // "individual" | "business"
	PriceUZS      int64    `json:"price_uzs"`
	BillingUnit   string   `json:"billing_unit"` // "oy" | "hujjat" | "14 kun"
	AnalysesLimit int      `json:"analyses_limit"`
	DailyLimit    int      `json:"daily_limit,omitempty"`
	RetentionDays int      `json:"retention_days"`
	TokensLimit   int      `json:"tokens_limit"`
	Features      []string `json:"features"`
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
		// Auto-provision official 14-day Business Trial (10 analyses, 3/day) per Loyiha DOCX §7.1
		insertSQL := `
			INSERT INTO quotas (organization_id, plan_name, analyses_limit, analyses_used, tokens_limit, tokens_used)
			VALUES ($1, 'B2B_TRIAL', 10, 0, 200000, 0)
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

// GetAvailablePlans returns official tariffs aligned 1-to-1 with LexGuard-AI-Loyiha.docx (§7, §12).
// Pass optional segment ("individual" or "business") to filter strictly by account type.
func (s *Service) GetAvailablePlans(segment ...string) []PlanInfo {
	all := []PlanInfo{
		{
			Code:          "CITIZEN_FREE",
			Name:          "Fuqaro · Bepul",
			Segment:       "individual",
			PriceUZS:      0,
			BillingUnit:   "oy",
			AnalysesLimit: 3,
			DailyLimit:    3,
			RetentionDays: 30,
			TokensLimit:   100000,
			Features: []string{
				"Oyiga 3 ta hujjat bepul (20 bet / 10 MB gacha)",
				"Bandma-band tahlil + R6 notarial qoida",
				"2 ta tayyor .docx + hamkorga xat loyihasi",
				"30 kun saqlash · istalgan payt o'chirish",
			},
		},
		{
			Code:          "CITIZEN_SINGLE",
			Name:          "Fuqaro · Bir martalik",
			Segment:       "individual",
			PriceUZS:      19900,
			BillingUnit:   "hujjat",
			AnalysesLimit: 1,
			RetentionDays: 30,
			TokensLimit:   50000,
			Features: []string{
				"Oylik 3 ta bepul limitdan keyin (obunasiz)",
				"Payme / Click orqali tezkor to'lov",
				"2 ta .docx + xat loyihasi + 7 kun bepul qayta tekshiruv",
			},
		},
		{
			Code:          "B2B_TRIAL",
			Name:          "Biznes sinov",
			Segment:       "business",
			PriceUZS:      0,
			BillingUnit:   "14 kun",
			AnalysesLimit: 10,
			DailyLimit:    3,
			RetentionDays: 7,
			TokensLimit:   200000,
			Features: []string{
				"14 kun sinov · kuniga 3 ta, jami 10 ta hujjat",
				"Hujjatlar 7 kun saqlanadi · eksport doim ochiq",
			},
		},
		{
			Code:          "BUSINESS",
			Name:          "Business",
			Segment:       "business",
			PriceUZS:      199000,
			BillingUnit:   "oy",
			AnalysesLimit: 30,
			RetentionDays: 30,
			TokensLimit:   1000000,
			Features: []string{
				"Oyiga 30 ta tahlil · 30 kun saqlash",
				"2 ta .docx eksport · Shartnomalarim va Firma hujjatlari tarixi",
				"MChJ bank o'tkazmasi, e-faktura, Payme / Click",
			},
		},
		{
			Code:          "PRO",
			Name:          "Pro",
			Segment:       "business",
			PriceUZS:      399000,
			BillingUnit:   "oy",
			AnalysesLimit: 80,
			RetentionDays: 30,
			TokensLimit:   3000000,
			Features: []string{
				"Oyiga 80 ta tahlil · barcha Business imkoniyatlari",
				"Bir nechta foydalanuvchi, rollar va audit jurnali",
				"Qonun o'zgarishi monitoringi (P2)",
			},
		},
		{
			Code:          "B2B_EXTRA",
			Name:          "Qo'shimcha tahlil",
			Segment:       "business",
			PriceUZS:      9900,
			BillingUnit:   "hujjat",
			AnalysesLimit: 1,
			RetentionDays: 30,
			TokensLimit:   50000,
			Features: []string{
				"Oylik limitdan ortiq har bir hujjat uchun",
				"Obunani o'zgartirmasdan alohida to'lov",
			},
		},
	}

	if len(segment) == 0 || segment[0] == "" {
		return all
	}
	target := segment[0]
	filtered := make([]PlanInfo, 0, len(all))
	for _, p := range all {
		if p.Segment == target {
			filtered = append(filtered, p)
		}
	}
	return filtered
}
