package report

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/xml"
	"fmt"
	"strings"
	"time"

	"github.com/lexguard/backend/internal/analysis"
)

type ReportData struct {
	AnalysisID       string                   `json:"analysis_id"`
	ContractFilename string                   `json:"contract_filename"`
	ContractSHA256   string                   `json:"contract_sha256"`
	OverallRiskScore int                      `json:"overall_risk_score"`
	RiskLevel        string                   `json:"risk_level"`
	GeneratedAt      time.Time                `json:"generated_at"`
	Disclaimer       string                   `json:"disclaimer"`
	Summary          analysis.AnalysisSummary `json:"summary"`
	Findings         []FindingReportItem      `json:"findings"`
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

// GenerateTextDiff generates a Markdown audit report (3-color + neutral balance, no percentage risk index per DOCX §4).
func (s *Service) GenerateTextDiff(rep *ReportData) []byte {
	var sb strings.Builder
	sb.WriteString("# LEXGUARD AI — SHARTNOMA TAHLIL HISOBOTI\n\n")
	sb.WriteString(fmt.Sprintf("**Hujjat nomi**: %s\n", rep.ContractFilename))
	sb.WriteString(fmt.Sprintf("**SHA256**: `%s`\n", rep.ContractSHA256))
	if rep.Summary.BalanceLabel != "" {
		sb.WriteString(fmt.Sprintf("**Taraf balansi (neytral)**: %s\n", rep.Summary.BalanceLabel))
	}
	sb.WriteString(fmt.Sprintf("**Sana**: %s\n", rep.GeneratedAt.Format("2006-01-02 15:04:05 UTC")))
	sb.WriteString(fmt.Sprintf("\n> %s\n\n", rep.Disclaimer))

	sb.WriteString("## Natija (3 rang):\n")
	sb.WriteString(fmt.Sprintf("- Qizil (Qonunga zid): %d\n", rep.Summary.RedLegal))
	sb.WriteString(fmt.Sprintf("- Sariq (Qonunga mos, lekin e'tibor kerak): %d\n", rep.Summary.YellowComm))
	sb.WriteString(fmt.Sprintf("- Yashil (Muammo topilmadi): %d\n", rep.Summary.GreenOK))
	if rep.Summary.ReviewRequired > 0 {
		sb.WriteString(fmt.Sprintf("- Rangsiz (Tekshirilmadi -> hamkor advokatga): %d\n", rep.Summary.ReviewRequired))
	}
	sb.WriteString(fmt.Sprintf("- Lokal maskalangan PII: %d\n\n", rep.Summary.PIIMasked))

	sb.WriteString("## Bandlar bo'yicha topilmalar va tavsiyalar:\n\n")
	for i, f := range rep.Findings {
		sb.WriteString(fmt.Sprintf("### %d. Band %s — [%s] %s\n", i+1, f.ClauseNumber, f.Severity, f.RiskCategory))
		sb.WriteString(fmt.Sprintf("- **Verifikatsiya**: %s\n", f.VerificationStatus))
		sb.WriteString(fmt.Sprintf("- **Oldin (Asl matn)**: _\"%s\"_\n", f.OriginalText))
		sb.WriteString(fmt.Sprintf("- **Keyin (Tavsiya tahrir)**: **\"%s\"**\n", f.SuggestedRevision))
		if f.LegalBasis != "" {
			sb.WriteString(fmt.Sprintf("- **Rasmiy norma**: %s (%s)\n", f.LegalBasis, f.OfficialURL))
		}
		sb.WriteString(fmt.Sprintf("- **Izoh**: %s\n\n", f.Explanation))
	}

	return []byte(sb.String())
}

// GenerateAnnotatedDocx creates official Output #1 (DOCX §9):
// Izohli takliflar .docx + Kelishmovchiliklar bayonnomasi.
func (s *Service) GenerateAnnotatedDocx(rep *ReportData) ([]byte, error) {
	lines := []string{
		"LEXGUARD AI — IZOHLI TAKLIFLAR VA KELISHMOVCHILIKLAR BAYONNOMASI",
		fmt.Sprintf("Hujjat: %s | Sana: %s", rep.ContractFilename, rep.GeneratedAt.Format("2006-01-02")),
		fmt.Sprintf("Natija (3 rang): Qizil=%d | Sariq=%d | Yashil=%d | Balans: %s",
			rep.Summary.RedLegal, rep.Summary.YellowComm, rep.Summary.GreenOK, rep.Summary.BalanceLabel),
		"Eslatma (O'RQ-1115): Axborot-tahliliy hisobot; yakuniy yuridik qarorni taraflar yoki advokat tasdiqlaydi.",
		"",
	}
	for i, f := range rep.Findings {
		lines = append(lines,
			fmt.Sprintf("%d. Band %s [%s]", i+1, f.ClauseNumber, f.Severity),
			fmt.Sprintf("   Oldin: %s", f.OriginalText),
			fmt.Sprintf("   Tavsiya (Keyin): %s", f.SuggestedRevision),
			fmt.Sprintf("   Norma: %s (%s)", f.LegalBasis, f.OfficialURL),
			fmt.Sprintf("   Izoh: %s", f.Explanation),
			"",
		)
	}
	return buildMinimalDocx(lines)
}

// GenerateCleanDraftDocx creates official Output #2 (DOCX §9):
// To'liq tahrir .docx starting with "LOYIHA — taraflar kelishmaguncha imzolanmaydi".
func (s *Service) GenerateCleanDraftDocx(rep *ReportData) ([]byte, error) {
	lines := []string{
		"LOYIHA — TARAFLAR KELISHMAGUNCHA IMZOLANMAYDI",
		fmt.Sprintf("Asos hujjat: %s | Tahrir sanasi: %s", rep.ContractFilename, rep.GeneratedAt.Format("2006-01-02")),
		"Ushbu loyihaga faqat tasdiqlangan tavsiya tahrirlar kiritilgan. «Tekshirilmadi» bandlari izoh sifatida qoldiriladi.",
		"",
	}
	for _, f := range rep.Findings {
		if f.VerificationStatus == "UNKNOWN" || f.VerificationStatus == "REVIEW_REQUIRED" {
			lines = append(lines,
				fmt.Sprintf("Band %s [TEKSHIRILMADI — HAMKOR ADVOKAT KO'RIGI ZARUR]:", f.ClauseNumber),
				f.OriginalText,
				"",
			)
		} else {
			lines = append(lines,
				fmt.Sprintf("Band %s (Tahrirlangan):", f.ClauseNumber),
				f.SuggestedRevision,
				"",
			)
		}
	}
	return buildMinimalDocx(lines)
}

// GeneratePartnerLetter creates official Output #3 (DOCX §6 & §9):
// Hamkorga kelishmovchiliklar xati / pretenziya loyihasi.
func (s *Service) GeneratePartnerLetter(rep *ReportData) []byte {
	var sb strings.Builder
	sb.WriteString("HAMKORGA KELISHMOVCHILIKLAR XATI (LOYIHA)\n")
	sb.WriteString(fmt.Sprintf("Shartnoma: %s\n", rep.ContractFilename))
	sb.WriteString(fmt.Sprintf("Sana: %s\n\n", rep.GeneratedAt.Format("2006-01-02")))
	sb.WriteString("Hurmatli hamkor,\n\n")
	sb.WriteString("Shartnoma loyihasini ko'rib chiqib, quyidagi bandlarni O'zbekiston Respublikasi qonunchiligi va o'zaro muvozanat asosida qayta tahrirlashni taklif etamiz:\n\n")
	idx := 1
	for _, f := range rep.Findings {
		if f.Severity == "RED" || f.Severity == "YELLOW" {
			sb.WriteString(fmt.Sprintf("%d. Band %s (%s):\n", idx, f.ClauseNumber, f.LegalBasis))
			sb.WriteString(fmt.Sprintf("   - Hozirgi matn: %s\n", f.OriginalText))
			sb.WriteString(fmt.Sprintf("   - Taklif etilayotgan tahrir: %s\n\n", f.SuggestedRevision))
			idx++
		}
	}
	sb.WriteString("Takliflarimiz bo'yicha 10 kalendar kun ichida yozma javob berishingizni so'raymiz.\n")
	return []byte(sb.String())
}

// buildMinimalDocx generates a standards-compliant OOXML .docx archive in pure Go.
func buildMinimalDocx(paragraphs []string) ([]byte, error) {
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)

	const contentTypesXML = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>`

	const relsXML = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>`

	var docBody strings.Builder
	docBody.WriteString(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?>`)
	docBody.WriteString(`<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>`)
	for _, p := range paragraphs {
		var escaped bytes.Buffer
		_ = xml.EscapeText(&escaped, []byte(p))
		docBody.WriteString("<w:p><w:r><w:t xml:space=\"preserve\">")
		docBody.WriteString(escaped.String())
		docBody.WriteString("</w:t></w:r></w:p>")
	}
	docBody.WriteString(`</w:body></w:document>`)

	files := map[string]string{
		"[Content_Types].xml": contentTypesXML,
		"_rels/.rels":         relsXML,
		"word/document.xml":   docBody.String(),
	}
	for name, content := range files {
		w, err := zw.Create(name)
		if err != nil {
			return nil, err
		}
		if _, err := w.Write([]byte(content)); err != nil {
			return nil, err
		}
	}
	if err := zw.Close(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}
