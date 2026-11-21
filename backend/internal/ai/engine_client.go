package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"strings"
	"time"
)

// ClauseInput represents a single clause sent to AI Engine
type ClauseInput struct {
	ClauseID     string `json:"clause_id"`
	ClauseNumber string `json:"clause_number"`
	Text         string `json:"text"`
}

// AnalysisEngineRequest is the payload for /api/v1/analyze-clauses
type AnalysisEngineRequest struct {
	AnalysisID   string        `json:"analysis_id"`
	DocumentType string        `json:"document_type"`
	ContractDate string        `json:"contract_date"`
	Clauses      []ClauseInput `json:"clauses"`
}

// FindingOutput is the structured finding returned by AI Engine
type FindingOutput struct {
	ClauseID         string                   `json:"clause_id"`
	ClauseNumber     string                   `json:"clause_number"`
	RiskLevel        string                   `json:"risk_level"`
	Category         string                   `json:"category"`
	IssueTitle       string                   `json:"issue_title"`
	ProblematicQuote string                   `json:"problematic_quote"` // Asl matn (Qizil)
	IssueExplanation string                   `json:"issue_explanation"`
	CitedArticle     string                   `json:"cited_article"`
	SuggestedRedline string                   `json:"suggested_redline"` // Tavsiya matn (Yashil)
	BalanceLabel     string                   `json:"balance_label"`
	LexUzURL         string                   `json:"lex_uz_url"`
	MultiHopChain    []map[string]interface{} `json:"multi_hop_chain,omitempty"`
}

// AnalysisEngineResponse is the response from /api/v1/analyze-clauses
type AnalysisEngineResponse struct {
	AnalysisID    string          `json:"analysis_id"`
	TotalClauses  int             `json:"total_clauses"`
	FindingsCount int             `json:"findings_count"`
	Findings      []FindingOutput `json:"findings"`
}

// SelfCorrectionRequest is sent when verification detects invalid/hallucinated citation
type SelfCorrectionRequest struct {
	ClauseText           string   `json:"clause_text"`
	PreviousCitedArticle string   `json:"previous_cited_article"`
	VerificationError    string   `json:"verification_error"`
	CandidateArticles    []string `json:"candidate_articles,omitempty"`
}

// SelfCorrectionResponse is returned by /api/v1/self-correct
type SelfCorrectionResponse struct {
	Resolved         bool   `json:"resolved"`
	CorrectedArticle string `json:"corrected_article,omitempty"`
	Explanation      string `json:"explanation,omitempty"`
	SuggestedRedline string `json:"suggested_redline,omitempty"`
	Message          string `json:"message,omitempty"`
}

// EngineClient handles HTTP / gRPC communication with the Python AI Engine
type EngineClient struct {
	baseURL    string
	httpClient *http.Client
	fallback   Provider
}

// NewEngineClient instantiates a client for http://localhost:8000 AI Engine
func NewEngineClient(customURL ...string) *EngineClient {
	url := "http://localhost:8000"
	if len(customURL) > 0 && customURL[0] != "" {
		url = strings.TrimRight(customURL[0], "/")
	} else if env := os.Getenv("AI_ENGINE_URL"); env != "" {
		url = strings.TrimRight(env, "/")
	}

	return &EngineClient{
		baseURL: url,
		httpClient: &http.Client{
			Timeout: 15 * time.Second,
		},
		fallback: NewTemporalLegalAIProvider(),
	}
}

// BaseURL returns the configured endpoint URL
func (c *EngineClient) BaseURL() string {
	return c.baseURL
}

// HealthCheck verifies if AI Engine is reachable
func (c *EngineClient) HealthCheck(ctx context.Context) (bool, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/health", nil)
	if err != nil {
		return false, err
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()

	return resp.StatusCode == http.StatusOK, nil
}

// AnalyzeClauses calls /api/v1/analyze-clauses on the AI Engine
func (c *EngineClient) AnalyzeClauses(ctx context.Context, req AnalysisEngineRequest) (*AnalysisEngineResponse, error) {
	bodyBytes, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal analyze request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/api/v1/analyze-clauses", bytes.NewReader(bodyBytes))
	if err != nil {
		return nil, fmt.Errorf("failed to create http request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("ai engine analyze-clauses unreachable: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("ai engine returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var res AnalysisEngineResponse
	if err := json.NewDecoder(resp.Body).Decode(&res); err != nil {
		return nil, fmt.Errorf("failed to decode ai engine response: %w", err)
	}

	return &res, nil
}

// SelfCorrect calls /api/v1/self-correct on the AI Engine
func (c *EngineClient) SelfCorrect(ctx context.Context, req SelfCorrectionRequest) (*SelfCorrectionResponse, error) {
	bodyBytes, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal self-correct request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/api/v1/self-correct", bytes.NewReader(bodyBytes))
	if err != nil {
		return nil, fmt.Errorf("failed to create http request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("ai engine self-correct unreachable: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("ai engine self-correct returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var res SelfCorrectionResponse
	if err := json.NewDecoder(resp.Body).Decode(&res); err != nil {
		return nil, fmt.Errorf("failed to decode self-correct response: %w", err)
	}

	return &res, nil
}

// Name implements ai.Provider interface
func (c *EngineClient) Name() string {
	return "LexGuard-AIEngine-HTTPClient (Python Knowledge Graph Engine)"
}

// AnalyzeClause satisfies ai.Provider and delegates to AI Engine with fallback
func (c *EngineClient) AnalyzeClause(ctx context.Context, req RedactedClauseRequest) (*DraftSuggestion, *UsageMetrics, error) {
	start := time.Now()

	// Try remote AI Engine first
	engineReq := AnalysisEngineRequest{
		AnalysisID:   "clause-eval",
		DocumentType: req.DocType,
		ContractDate: req.ContractDate,
		Clauses: []ClauseInput{
			{
				ClauseID:     "cl-1",
				ClauseNumber: req.ClauseNumber,
				Text:         req.RedactedText,
			},
		},
	}

	engineResp, err := c.AnalyzeClauses(ctx, engineReq)
	if err == nil && engineResp != nil && len(engineResp.Findings) > 0 {
		f := engineResp.Findings[0]

		lawCode := ""
		article := strings.TrimSpace(f.CitedArticle)
		if article != "" {
			parts := strings.SplitN(article, " ", 2)
			if len(parts) == 2 {
				lawCode = parts[0]
				article = parts[1]
			} else {
				lawCode = "FK-UZ"
			}
		}

		draft := &DraftSuggestion{
			RuleCode:          "ENGINE_" + strings.ToUpper(f.RiskLevel),
			RiskCategory:      f.Category,
			Severity:          f.RiskLevel,
			OriginalQuote:     f.ProblematicQuote,
			SuggestedRevision: f.SuggestedRedline,
			CitedLawCode:      lawCode,
			CitedArticle:      article,
			OfficialURL:       f.LexUzURL,
			Explanation:       f.IssueExplanation,
			ConfidenceScore:   0.96,
		}

		metrics := &UsageMetrics{
			PromptTokens:     len(req.RedactedText) / 4,
			CompletionTokens: len(f.SuggestedRedline) / 4,
			TotalTokens:      (len(req.RedactedText) + len(f.SuggestedRedline)) / 4,
			Duration:         time.Since(start),
			ProviderName:     c.Name(),
		}
		return draft, metrics, nil
	}

	// Resilient fallback to local deterministic provider
	if c.fallback != nil {
		return c.fallback.AnalyzeClause(ctx, req)
	}

	return nil, nil, errors.New("ai engine analysis failed and no fallback configured")
}

// OCRResponse is returned by ai-engine /api/v1/ocr
type OCRResponse struct {
	Filename        string  `json:"filename"`
	ConfidenceScore float64 `json:"confidence_score"`
	TotalClauses    int     `json:"total_clauses"`
	FullTextSample  string  `json:"full_text_sample"`
	Clauses         []struct {
		ClauseNumber string `json:"clause_number"`
		Text         string `json:"text"`
	} `json:"clauses"`
}

// OCRDocument forwards an image or scanned PDF to Python ai-engine /api/v1/ocr
func (c *EngineClient) OCRDocument(ctx context.Context, filename string, fileBytes []byte) (string, float64, error) {
	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	part, err := writer.CreateFormFile("file", filename)
	if err != nil {
		return "", 0, err
	}
	if _, err := part.Write(fileBytes); err != nil {
		return "", 0, err
	}
	if err := writer.Close(); err != nil {
		return "", 0, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/api/v1/ocr", &body)
	if err != nil {
		return "", 0, err
	}
	req.Header.Set("Content-Type", writer.FormDataContentType())

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", 0, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", 0, fmt.Errorf("ocr endpoint returned %d", resp.StatusCode)
	}

	var parsed OCRResponse
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return "", 0, err
	}
	var sb strings.Builder
	for _, cl := range parsed.Clauses {
		if strings.TrimSpace(cl.Text) != "" {
			sb.WriteString(cl.ClauseNumber)
			sb.WriteString(". ")
			sb.WriteString(strings.TrimSpace(cl.Text))
			sb.WriteString("\n")
		}
	}
	text := strings.TrimSpace(sb.String())
	if text == "" {
		text = strings.TrimSpace(parsed.FullTextSample)
	}
	return text, parsed.ConfidenceScore, nil
}
