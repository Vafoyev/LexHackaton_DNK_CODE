package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
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
	ClauseID          string                   `json:"clause_id"`
	ClauseNumber      string                   `json:"clause_number"`
	RiskLevel         string                   `json:"risk_level"`
	Category          string                   `json:"category"`
	IssueTitle        string                   `json:"issue_title"`
	ProblematicQuote  string                   `json:"problematic_quote"` // Asl matn (Qizil)
	IssueExplanation  string                   `json:"issue_explanation"`
	CitedArticle      string                   `json:"cited_article"`
	SuggestedRedline  string                   `json:"suggested_redline"` // Tavsiya matn (Yashil)
	BalanceLabel      string                   `json:"balance_label"`
	LexUzURL          string                   `json:"lex_uz_url"`
	MultiHopChain     []map[string]interface{} `json:"multi_hop_chain,omitempty"`
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
	ClauseText            string   `json:"clause_text"`
	PreviousCitedArticle  string   `json:"previous_cited_article"`
	VerificationError     string   `json:"verification_error"`
	CandidateArticles     []string `json:"candidate_articles,omitempty"`
}

// SelfCorrectionResponse is returned by /api/v1/self-correct
type SelfCorrectionResponse struct {
	Resolved         bool   `json:"resolved"`
	CorrectedArticle string `json:"corrected_article,omitempty"`
	Explanation      string `json:"explanation,omitempty"`
	SuggestedRedline string `json:"suggested_redline,omitempty"`
	Message          string `json:"message,omitempty"`
}

// ChatSource is a law article the chat answer is grounded in.
type ChatSource struct {
	ID    string `json:"id"`
	Code  string `json:"code"`
	Title string `json:"title"`
	URL   string `json:"url"`
}

// ChatFinding is a clause-level risk returned when the user pastes a contract clause into the chat.
type ChatFinding struct {
	RiskLevel        string `json:"risk_level"`
	IssueTitle       string `json:"issue_title"`
	ProblematicQuote string `json:"problematic_quote"`
	SuggestedRedline string `json:"suggested_redline"`
	CitedArticle     string `json:"cited_article"`
	LexUzURL         string `json:"lex_uz_url"`
	BalanceLabel     string `json:"balance_label"`
}

// ChatResponse is the AI Engine answer for /api/v1/chat. Speech is a short, TTS-friendly version of Answer.
type ChatResponse struct {
	Intent      string        `json:"intent"`
	Answer      string        `json:"answer"`
	Speech      string        `json:"speech"`
	Sources     []ChatSource  `json:"sources"`
	Findings    []ChatFinding `json:"findings"`
	Suggestions []string      `json:"suggestions"`
	Disclaimer  string        `json:"disclaimer"`
}

// BalanceClause is a single clause sent for contract-level party-balance analysis.
type BalanceClause struct {
	ClauseID     string `json:"clause_id"`
	ClauseNumber string `json:"clause_number"`
	Text         string `json:"text"`
}

// BalanceRequest is the payload for /api/v1/balance.
type BalanceRequest struct {
	DocumentType string          `json:"document_type"`
	PartyRole    string          `json:"party_role"`
	Clauses      []BalanceClause `json:"clauses"`
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

// Chat calls /api/v1/chat on the AI Engine (law Q&A, article lookup, clause analysis).
func (c *EngineClient) Chat(ctx context.Context, message string) (*ChatResponse, error) {
	bodyBytes, err := json.Marshal(map[string]string{"message": message})
	if err != nil {
		return nil, fmt.Errorf("failed to marshal chat request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/api/v1/chat", bytes.NewReader(bodyBytes))
	if err != nil {
		return nil, fmt.Errorf("failed to create http request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("ai engine chat unreachable: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
		return nil, fmt.Errorf("ai engine chat returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var res ChatResponse
	if err := json.NewDecoder(resp.Body).Decode(&res); err != nil {
		return nil, fmt.Errorf("failed to decode chat response: %w", err)
	}
	return &res, nil
}

// Balance calls /api/v1/balance. The report shape is owned by the AI Engine, so it is passed through as raw JSON.
func (c *EngineClient) Balance(ctx context.Context, req BalanceRequest) (json.RawMessage, error) {
	bodyBytes, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal balance request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/api/v1/balance", bytes.NewReader(bodyBytes))
	if err != nil {
		return nil, fmt.Errorf("failed to create http request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("ai engine balance unreachable: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
		return nil, fmt.Errorf("ai engine balance returned status %d: %s", resp.StatusCode, string(respBody))
	}

	raw, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if err != nil {
		return nil, fmt.Errorf("failed to read balance response: %w", err)
	}
	if !json.Valid(raw) {
		return nil, fmt.Errorf("ai engine balance returned invalid json")
	}
	return json.RawMessage(raw), nil
}

// LawChanges calls GET /api/v1/law-changes (recently amended articles, derived from Lex.uz amendment notes in the corpus).
// Only the explicitly built query is sent; the report is passed through as raw JSON.
func (c *EngineClient) LawChanges(ctx context.Context, query url.Values) (json.RawMessage, error) {
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/api/v1/law-changes?"+query.Encode(), nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create http request: %w", err)
	}

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("ai engine law-changes unreachable: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
		return nil, fmt.Errorf("ai engine law-changes returned status %d: %s", resp.StatusCode, string(respBody))
	}

	raw, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		return nil, fmt.Errorf("failed to read law-changes response: %w", err)
	}
	if !json.Valid(raw) {
		return nil, fmt.Errorf("ai engine law-changes returned invalid json")
	}
	return json.RawMessage(raw), nil
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

		parts := strings.SplitN(f.CitedArticle, " ", 2)
		lawCode := "FK-UZ"
		article := f.CitedArticle
		if len(parts) == 2 {
			lawCode = parts[0]
			article = parts[1]
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
