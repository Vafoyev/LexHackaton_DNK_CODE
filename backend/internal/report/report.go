package report

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/lexguard/backend/internal/analysis"
)

type ReportData struct {
	AnalysisID       string                  `json:"analysis_id"`
	ContractFilename string                  `json:"contract_filename"`
	ContractSHA256   string                  `json:"contract_sha256"`
	OverallRiskScore int                     `json:"overall_risk_score"`
	RiskLevel        string                  `json:"risk_level"`
	GeneratedAt      time.Time               `json:"generated_at"`
	Disclaimer       string                  `json:"disclaimer"`
	Summary          analysis.AnalysisSummary `json:"summary"`
	Findings         []FindingReportItem     `json:"findings"`
}

type FindingReportItem struct {
	ClauseNumber       string `json:"clause_number"`
	RiskCategory       string `json:"risk_category"`
	Severity           string `json:"severity"`
	VerificationStatus string `json:"verification_status"`
	OriginalText       string `json:"original_text"`
	SuggestedRevision  string `json:"suggested_revision"`
	LegalBasis         string `json:"legal_basis"`
	OfficialURL        string `json:"official_url"`
	Explanation        string `json:"explanation"`
}

type Service struct {
	analysisSvc *analysis.Service
}

func NewService(analysisSvc *analysis.Service) *Service {
	return &Service{analysisSvc: analysisSvc}
}

func (s *Service) GenerateReport(ctx context.Context, analysisID, orgID string) (*ReportData, error) {
	det, err := s.analysisSvc.GetAnalysis(ctx, analysisID, orgID)
	if err != nil {
		return nil, err
	}

	rep := &ReportData{
		AnalysisID:       det.ID,
		ContractFilename: det.Filename,
		ContractSHA256:   det.SHA256,
		OverallRiskScore: det.OverallRiskScore,
		RiskLevel:        det.RiskLevel,
		GeneratedAt:      time.Now().UTC(),
		Disclaimer:       det.Disclaimer,
		Summary:          det.Summary,
	}

	for _, f := range det.Findings {
		legalBasis := ""
		officialURL := ""
		if f.LegalSource != nil {
			legalBasis = fmt.Sprintf("%s, %s", f.LegalSource.Code, f.LegalSource.Article)
			officialURL = f.LegalSource.OfficialURL
		}

		rep.Findings = append(rep.Findings, FindingReportItem{
			ClauseNumber:       f.ClauseNumber,
			RiskCategory:       f.RiskCategory,
			Severity:           f.Severity,
			VerificationStatus: string(f.VerificationStatus),
			OriginalText:       f.OriginalQuote,
			SuggestedRevision:  f.SuggestedRevision,
			LegalBasis:         legalBasis,
			OfficialURL:        officialURL,
			Explanation:        f.Explanation,
		})
	}

	return rep, nil
}

// GenerateTextDiff generates markdown text report for download
func (s *Service) GenerateTextDiff(rep *ReportData) []byte {
	var sb strings.Builder
	sb.WriteString("# LEXGUARD AI 3.0 — SHARTNOMA XAVFSIZLIGI AUDIT HISOBOTI\n\n")
	sb.WriteString(fmt.Sprintf("**Hujjat nomi**: %s\n", rep.ContractFilename))
	sb.WriteString(fmt.Sprintf("**SHA256 Xesh**: `%s`\n", rep.ContractSHA256))
	sb.WriteString(fmt.Sprintf("**Umumiy Xavf Bali**: %d / 100 (%s)\n", rep.OverallRiskScore, rep.RiskLevel))
	sb.WriteString(fmt.Sprintf("**Sana**: %s\n", rep.GeneratedAt.Format("2006-01-02 15:04:05 UTC")))
	sb.WriteString(fmt.Sprintf("\n> %s\n\n", rep.Disclaimer))

	sb.WriteString("## Xulosa Ko'rsatkichlari:\n")
	sb.WriteString(fmt.Sprintf("- 🔴 Qonuniy qizil xavflar (LEGAL / RED): %d\n", rep.Summary.RedLegal))
	sb.WriteString(fmt.Sprintf("- 🟡 Tijoriy xavflar (COMMERCIAL / YELLOW): %d\n", rep.Summary.YellowComm))
	sb.WriteString(fmt.Sprintf("- ⚖️ Yurist ekspert ko'rigi talab etiladi: %d\n", rep.Summary.ReviewRequired))
	sb.WriteString(fmt.Sprintf("- 🛡️ Maskalangan shaxsiy ma'lumotlar (PII): %d\n\n", rep.Summary.PIIMasked))

	sb.WriteString("## Aniqlangan Xavflar va Taklif Etilgan Tahrirlar:\n\n")
	for i, f := range rep.Findings {
		sb.WriteString(fmt.Sprintf("### %d. Band %s — [%s] %s\n", i+1, f.ClauseNumber, f.Severity, f.RiskCategory))
		sb.WriteString(fmt.Sprintf("- **Verifikatsiya holati**: %s (10-vektorli tekshiruvdan o'tgan)\n", f.VerificationStatus))
		sb.WriteString(fmt.Sprintf("- **Asl matn**: _\"%s\"_\n", f.OriginalText))
		sb.WriteString(fmt.Sprintf("- **Tavsiya etilgan tahrir**: **\"%s\"**\n", f.SuggestedRevision))
		if f.LegalBasis != "" {
			sb.WriteString(fmt.Sprintf("- **Huquqiy asos**: %s ([Lex.uz havolasi](%s))\n", f.LegalBasis, f.OfficialURL))
		}
		sb.WriteString(fmt.Sprintf("- **Izoh**: %s\n\n", f.Explanation))
	}

	return []byte(sb.String())
}
