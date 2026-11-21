package analysis

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
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
	TotalClauses   int      `json:"total_clauses"`
	RedLegal       int      `json:"red_legal"`
	YellowComm     int      `json:"yellow_commercial"`
	GreenOK        int      `json:"green_ok"`
	ReviewRequired int      `json:"review_required"`
	PIIMasked      int      `json:"pii_masked"`
	RedCount       int      `json:"red_count"`
	YellowCount    int      `json:"yellow_count"`
	GreenCount     int      `json:"green_count"`
	GrayCount      int      `json:"gray_count"`
	BalanceLabel   string   `json:"balance_label"`
	TopRisks       []string `json:"top_risks"`
}

type CostMetrics struct {
	TokensUsed int `json:"tokens_used"`
	DurationMS int `json:"duration_ms"`
}

type DocumentBrief struct {
	ID           string `json:"id"`
	Filename     string `json:"filename"`
	SHA256       string `json:"sha256"`
	ContractDate string `json:"contract_date"`
	DocumentType string `json:"document_type"`
}

type FlaggedClause struct {
	ClauseNumber       string               `json:"clause_number"`
	ClauseText         string               `json:"clause_text"`
	OriginalQuote      string               `json:"original_quote"`      // Asl matn (Qizil)
	ProblematicQuote   string               `json:"problematic_quote"`   // Asl xavfli matn (Qizil)
	RiskLevel          string               `json:"risk_level"`          // RED, YELLOW, GREEN
	LawReference       *FlaggedLawReference `json:"law_reference,omitempty"`
	SuggestedRevision  string               `json:"suggested_revision"`  // Tavsiya matn (Yashil)
	SuggestedRedline   string               `json:"suggested_redline"`   // Tavsiya matn (Yashil)
	SuggestedAmendment string               `json:"suggested_amendment"` // Tavsiya matn (Yashil)
}

type FlaggedLawReference struct {
	LawTitle    string `json:"law_title"`
	Article     string `json:"article"`
	LexUzURL    string `json:"lex_uz_url"`
	Explanation string `json:"explanation"`
}

type AnalysisDetail struct {
	ID               string                         `json:"id"`
	ContractID       string                         `json:"contract_id"` // alias for frontend / CONTRACTS.md
	Document         DocumentBrief                  `json:"document"`    // CONTRACTS.md nested object
	Filename         string                         `json:"filename"`
	SHA256           string                         `json:"sha256"`
	Status           string                         `json:"status"`
	ExecutionMode    string                         `json:"execution_mode"`
	DocType          string                         `json:"doc_type"`
	ContractDate     string                         `json:"contract_date"`
	Disclaimer       string                         `json:"disclaimer"`
	OverallRiskScore int                            `json:"overall_risk_score"`
	RiskLevel        string                         `json:"risk_level"`
	TotalClauses     int                            `json:"total_clauses"`
	FlaggedClauses   []FlaggedClause                `json:"flagged_clauses"`
	Summary          AnalysisSummary                `json:"summary"`
	CostMetrics      CostMetrics                    `json:"cost_metrics"`
	Findings         []verification.VerifiedFinding `json:"findings"`
	CreatedAt        time.Time                      `json:"created_at"`
	CompletedAt      *time.Time                     `json:"completed_at,omitempty"`
}

// ---------------- D-10 DIRECTIVE MODELS (AI Live Voice & 3D Glanceable) ----------------

type VoiceRiskItem struct {
	ClauseNumber string `json:"clause_number"`
	Title        string `json:"title"`
	Severity     string `json:"severity"`
	LawReference string `json:"law_reference"`
	OfficialURL  string `json:"official_url"`
	RedlineFix   string `json:"redline_fix"`
}

type VoiceDebriefResponse struct {
	AnalysisID       string          `json:"analysis_id"`
	Language         string          `json:"language"`
	Tone             string          `json:"tone"`
	DurationSec      int             `json:"duration_sec"`
	AudioText        string          `json:"audio_text"`
	SSML             string          `json:"ssml"`
	TopCriticalRisks []VoiceRiskItem `json:"top_critical_risks"`
	ActionableAdvice []string        `json:"actionable_advice"`
	LegalConfidence  float64         `json:"legal_confidence"`
	GeneratedAt      time.Time       `json:"generated_at"`
}

type GlanceableSphere struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	RiskCount   int     `json:"risk_count"`
	DominantHex string  `json:"dominant_hex"`
	Radius      float64 `json:"radius"`
}

type GlanceableNode struct {
	ID             string  `json:"id"`
	ClauseNumber   string  `json:"clause_number"`
	X              float64 `json:"x"` // 0.0 to 1.0 along document length
	Y              float64 `json:"y"` // severity weight: 10 (Green), 50 (Yellow), 100 (Red)
	Z              float64 `json:"z"` // temporal impact (-1.0 to 1.0)
	ColorHex       string  `json:"color_hex"`
	PulseFrequency float64 `json:"pulse_frequency"`
	GlowIntensity  float64 `json:"glow_intensity"`
	Verdict        string  `json:"verdict"`
	ShortQuote     string  `json:"short_quote"`
}

type GlanceableHeatmap struct {
	ClauseNumber string `json:"clause_number"`
	Severity     string `json:"severity"`
	ColorHex     string `json:"color_hex"`
}

type ExecutiveStats struct {
	TotalClauses       int      `json:"total_clauses"`
	RedLegalCount      int      `json:"red_legal_count"`
	YellowCommCount    int      `json:"yellow_comm_count"`
	EstimatedReviewMin int      `json:"estimated_review_min"`
	MustFixBeforeSign  []string `json:"must_fix_before_sign"`
}

type GlanceableMatrixResponse struct {
	AnalysisID     string              `json:"analysis_id"`
	DocType        string              `json:"doc_type"`
	OverallScore   int                 `json:"overall_score"`
	RiskLevel      string              `json:"risk_level"`
	BalanceIndex   int                 `json:"balance_index"` // -100 (heavily biased) to +100
	BalanceVerdict string              `json:"balance_verdict"`
	Spheres        []GlanceableSphere  `json:"spheres"`
	SpatialNodes   []GlanceableNode    `json:"spatial_nodes"`
	Heatmap        []GlanceableHeatmap `json:"heatmap"`
	ExecutiveStats ExecutiveStats      `json:"executive_stats"`
	Disclaimer     string              `json:"disclaimer"`
}

// ---------------- SSE BROADCASTER ----------------

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

// ---------------- SERVICE ----------------

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
	if s.db == nil {
		return nil, fmt.Errorf("baza ulanmagan (offline mode)")
	}
	sql := `
		SELECT a.id, a.document_id, d.filename, d.sha256, a.status, a.execution_mode,
		       a.doc_type, a.contract_date::text, a.disclaimer, a.overall_risk_score,
		       a.risk_level, a.summary_json, a.cost_metrics_json, a.created_at, a.completed_at
		FROM analyses a
		JOIN documents d ON a.document_id = d.id
		WHERE a.id = $1 AND a.organization_id = $2
	`
	det := AnalysisDetail{
		FlaggedClauses: make([]FlaggedClause, 0),
		Findings:       make([]verification.VerifiedFinding, 0),
	}
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

	det.Document = DocumentBrief{
		ID:           det.ContractID,
		Filename:     det.Filename,
		SHA256:       det.SHA256,
		ContractDate: det.ContractDate,
		DocumentType: det.DocType,
	}

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
					vf.LegalBasis = vf.LegalSource
				}
				vf.RuleID = vf.RuleCode
				vf.Category = vf.RiskCategory
				vf.RiskLevel = vf.Severity
				vf.SuggestedRedline = vf.SuggestedRevision
				vf.ProblematicQuote = vf.OriginalQuote
				vf.SuggestedRedline = vf.SuggestedRevision
				vf.IssueTitle = vf.Explanation
				vf.IssueExplanation = vf.Explanation
				det.Findings = append(det.Findings, vf)

				// Fill CONTRACTS.md flagged_clauses schema with full Red (Original) and Green (Suggested) fields
				if vf.Severity == "RED" || vf.Severity == "YELLOW" {
					det.FlaggedClauses = append(det.FlaggedClauses, FlaggedClause{
						ClauseNumber:       vf.ClauseNumber,
						ClauseText:         vf.OriginalQuote,
						OriginalQuote:      vf.OriginalQuote,
						ProblematicQuote:   vf.OriginalQuote,
						RiskLevel:          vf.Severity,
						LawReference: &FlaggedLawReference{
							LawTitle:    lawCode,
							Article:     lawArt,
							LexUzURL:    officialURL,
							Explanation: vf.Explanation,
						},
						SuggestedRevision:  vf.SuggestedRevision,
						SuggestedRedline:   vf.SuggestedRevision,
						SuggestedAmendment: vf.SuggestedRevision,
					})
				}
			}
		}
	}

	return &det, nil
}

func (s *Service) ListAnalyses(ctx context.Context, orgID string, limit int) ([]AnalysisDetail, error) {
	if s.db == nil {
		return []AnalysisDetail{}, nil
	}
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

// ---------------- D-10 DIRECTIVE IMPLEMENTATION ----------------

// GenerateVoiceDebrief creates a professional 30-second legal voice brief with SSML and top risks
func (s *Service) GenerateVoiceDebrief(ctx context.Context, analysisID, orgID string) (*VoiceDebriefResponse, error) {
	det, err := s.GetAnalysis(ctx, analysisID, orgID)
	if err != nil {
		return nil, err
	}

	var redCount, yellowCount int
	var topRisks []VoiceRiskItem
	var actionableAdvice []string

	for _, f := range det.Findings {
		if f.Severity == "RED" {
			redCount++
		} else if f.Severity == "YELLOW" {
			yellowCount++
		}

		if (f.Severity == "RED" || f.Severity == "YELLOW") && len(topRisks) < 3 {
			lawRef := "Fuqarolik Kodeksi"
			offURL := "https://lex.uz"
			if f.LegalSource != nil {
				lawRef = fmt.Sprintf("%s %s", f.LegalSource.Code, f.LegalSource.Article)
				offURL = f.LegalSource.OfficialURL
			}
			topRisks = append(topRisks, VoiceRiskItem{
				ClauseNumber: f.ClauseNumber,
				Title:        f.IssueTitle,
				Severity:     f.Severity,
				LawReference: lawRef,
				OfficialURL:  offURL,
				RedlineFix:   f.SuggestedRevision,
			})
			actionableAdvice = append(actionableAdvice, fmt.Sprintf("%s-bandni tavsiya etilgan redline bo‘yicha o‘zgartiring", f.ClauseNumber))
		}
	}

	if len(actionableAdvice) == 0 {
		actionableAdvice = append(actionableAdvice, "Shartnoma qonunchilikka to‘liq mos keladi, imzolash mumkin.")
	}

	// Uzbek natural audio brief script
	var sb strings.Builder
	var ssml strings.Builder

	sb.WriteString("Assalomu alaykum! LexGuard AI tahlili yakunlandi. ")
	ssml.WriteString("<speak><p><s>Assalomu alaykum!</s> <s>LexGuard AI tahlili yakunlandi.</s> ")

	if redCount > 0 {
		msg := fmt.Sprintf("Hujjatda %d ta qizil qonuniy xavf va %d ta tijoriy xavf aniqlandi. ", redCount, yellowCount)
		sb.WriteString(msg)
		ssml.WriteString(fmt.Sprintf("<s>Hujjatda <emphasis level=\"strong\">%d ta qizil qonuniy xavf</emphasis> aniqlandi.</s> ", redCount))
	} else if yellowCount > 0 {
		msg := fmt.Sprintf("Shartnomada %d ta tijoriy xavf mavjud. ", yellowCount)
		sb.WriteString(msg)
		ssml.WriteString(fmt.Sprintf("<s>Shartnomada %d ta tijoriy xavf mavjud.</s> ", yellowCount))
	} else {
		sb.WriteString("Shartnomada jiddiy huquqiy xavflar aniqlanmadi. ")
		ssml.WriteString("<s>Shartnomada jiddiy huquqiy xavflar aniqlanmadi.</s> ")
	}

	for i, r := range topRisks {
		desc := fmt.Sprintf("%d-asosiy xavf: %s-bandda, %s talabiga asosan. ", i+1, r.ClauseNumber, r.LawReference)
		sb.WriteString(desc)
		ssml.WriteString(fmt.Sprintf("<break time=\"200ms\"/><s>%s</s> ", desc))
	}

	sb.WriteString("Imzolashdan oldin tavsiya etilgan redline tahrirlarini kiritishni maslahat beramiz.")
	ssml.WriteString("<s>Imzolashdan oldin tavsiya etilgan redline tahrirlarini kiritishni maslahat beramiz.</s></p></speak>")

	return &VoiceDebriefResponse{
		AnalysisID:       analysisID,
		Language:         "uz-UZ",
		Tone:             "professional_juridical",
		DurationSec:      30,
		AudioText:        sb.String(),
		SSML:             ssml.String(),
		TopCriticalRisks: topRisks,
		ActionableAdvice: actionableAdvice,
		LegalConfidence:  0.98,
		GeneratedAt:      time.Now().UTC(),
	}, nil
}

// GenerateGlanceableMatrix produces 3D Immersion & Pro Glanceable UI visual metadata
func (s *Service) GenerateGlanceableMatrix(ctx context.Context, analysisID, orgID string) (*GlanceableMatrixResponse, error) {
	det, err := s.GetAnalysis(ctx, analysisID, orgID)
	if err != nil {
		return nil, err
	}

	// 1. Group into 4 3D Spheres
	sphereLegal := GlanceableSphere{ID: "sphere-legal", Name: "Qonuniy Talablar (Legal)", DominantHex: "#EF4444", Radius: 1.0}
	sphereComm := GlanceableSphere{ID: "sphere-comm", Name: "Tijoriy va Penya (Commercial)", DominantHex: "#F59E0B", Radius: 1.0}
	sphereLabor := GlanceableSphere{ID: "sphere-labor", Name: "Mehnat Huquqlari (Labor)", DominantHex: "#8B5CF6", Radius: 1.0}
	sphereCyber := GlanceableSphere{ID: "sphere-cyber", Name: "Kiberxavfsizlik va Maxfiylik", DominantHex: "#3B82F6", Radius: 1.0}

	spatialNodes := make([]GlanceableNode, 0)
	heatmap := make([]GlanceableHeatmap, 0)

	total := len(det.Findings)
	if total == 0 {
		total = 1
	}

	balanceBias := 0

	for i, f := range det.Findings {
		xPos := float64(i+1) / float64(total)
		yWeight := 10.0
		colorHex := "#10B981"
		pulseFreq := 1.0
		glowInt := 0.2

		switch f.Severity {
		case "RED":
			yWeight = 100.0
			colorHex = "#EF4444"
			pulseFreq = 3.0
			glowInt = 1.0
			balanceBias -= 30
		case "YELLOW":
			yWeight = 50.0
			colorHex = "#F59E0B"
			pulseFreq = 2.0
			glowInt = 0.6
			balanceBias -= 15
		default:
			balanceBias += 5
		}

		// Sphere categorization
		switch f.RiskCategory {
		case "LABOR":
			sphereLabor.RiskCount++
		case "PRIVACY", "AI":
			sphereCyber.RiskCount++
		case "COMMERCIAL":
			sphereComm.RiskCount++
		default:
			sphereLegal.RiskCount++
		}

		quoteShort := f.OriginalQuote
		if len(quoteShort) > 60 {
			quoteShort = quoteShort[:60] + "..."
		}

		spatialNodes = append(spatialNodes, GlanceableNode{
			ID:             f.ID,
			ClauseNumber:   f.ClauseNumber,
			X:              xPos,
			Y:              yWeight,
			Z:              0.0,
			ColorHex:       colorHex,
			PulseFrequency: pulseFreq,
			GlowIntensity:  glowInt,
			Verdict:        f.Explanation,
			ShortQuote:     quoteShort,
		})

		heatmap = append(heatmap, GlanceableHeatmap{
			ClauseNumber: f.ClauseNumber,
			Severity:     f.Severity,
			ColorHex:     colorHex,
		})
	}

	// Adjust sphere radii proportionally
	sphereLegal.Radius = 1.0 + float64(sphereLegal.RiskCount)*0.4
	sphereComm.Radius = 1.0 + float64(sphereComm.RiskCount)*0.3
	sphereLabor.Radius = 1.0 + float64(sphereLabor.RiskCount)*0.4
	sphereCyber.Radius = 1.0 + float64(sphereCyber.RiskCount)*0.4

	balanceVerdict := "Muvozanatli shartnoma"
	if balanceBias < -40 {
		balanceVerdict = "Buyurtmachiga o‘ta og‘ir asimmetrik shartnoma"
	} else if balanceBias < 0 {
		balanceVerdict = "Ijrochi manfaatlariga nomutanosiblik mavjud"
	}

	mustFix := make([]string, 0)
	for _, f := range det.Findings {
		if f.Severity == "RED" && len(mustFix) < 3 {
			mustFix = append(mustFix, fmt.Sprintf("%s-band: %s", f.ClauseNumber, f.Explanation))
		}
	}

	return &GlanceableMatrixResponse{
		AnalysisID:     analysisID,
		DocType:        det.DocType,
		OverallScore:   det.OverallRiskScore,
		RiskLevel:      det.RiskLevel,
		BalanceIndex:   balanceBias,
		BalanceVerdict: balanceVerdict,
		Spheres:        []GlanceableSphere{sphereLegal, sphereComm, sphereLabor, sphereCyber},
		SpatialNodes:   spatialNodes,
		Heatmap:        heatmap,
		ExecutiveStats: ExecutiveStats{
			TotalClauses:       det.TotalClauses,
			RedLegalCount:      det.Summary.RedLegal,
			YellowCommCount:    det.Summary.YellowComm,
			EstimatedReviewMin: 3,
			MustFixBeforeSign:  mustFix,
		},
		Disclaimer: "O‘RQ-1115 6-moddasiga asosan axborot-maslahat xarakteriga ega bo‘lib, yakuniy qaror inson nazorati ostida qabul qilinadi.",
	}, nil
}
