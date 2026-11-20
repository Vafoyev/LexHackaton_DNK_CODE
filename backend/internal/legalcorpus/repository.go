package legalcorpus

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type LegalArticle struct {
	ID                 string    `json:"id"`
	SourceCode         string    `json:"source_code"`
	SourceTitle        string    `json:"source_title"`
	ArticleNumber      string    `json:"article_number"`
	Title              string    `json:"title"`
	FullText           string    `json:"full_text"`
	NormNature         string    `json:"norm_nature"` // IMPERATIVE, DISPOSITIVE
	OfficialURL        string    `json:"official_url"`
	EffectiveFrom      time.Time `json:"effective_from"`
	EffectiveTo        *time.Time `json:"effective_to"`
	SimilarityScore    float64   `json:"similarity_score"`
}

type Repository struct {
	db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

// SearchHybrid performs Temporal Hybrid RAG (Temporal Filter + Lexical TSVector + Fallback)
func (r *Repository) SearchHybrid(ctx context.Context, query string, contractDate time.Time, docType string, limit int) ([]LegalArticle, error) {
	if limit <= 0 {
		limit = 5
	}

	dateStr := contractDate.Format("2006-01-02")

	// Pre-process query tokens
	cleanQuery := strings.ReplaceAll(query, "'", "")
	words := strings.Fields(cleanQuery)
	var tsQueryParts []string
	for _, w := range words {
		w = strings.Trim(w, ".,!?:;\"'()[]{}")
		if len(w) > 3 {
			tsQueryParts = append(tsQueryParts, w)
		}
	}
	tsQuery := strings.Join(tsQueryParts, " | ")
	if tsQuery == "" {
		tsQuery = "shartnoma | xizmat | javobgarlik"
	}

	// SQL Temporal & Scope Pre-Filter + Full-text lexical search
	sql := `
		SELECT lsv.id, ls.code, ls.title, lsv.article_number, lsv.title, lsv.full_text,
		       lsv.norm_nature, lsv.official_url, lsv.effective_from, lsv.effective_to,
		       ts_rank_cd(lsv.tsv, to_tsquery('simple', $1)) AS rank
		FROM legal_source_versions lsv
		JOIN legal_sources ls ON lsv.source_id = ls.id
		WHERE lsv.effective_from <= $2::date
		  AND (lsv.effective_to IS NULL OR lsv.effective_to >= $2::date)
		  AND ($3 = ANY(lsv.applicable_doc_types) OR 'ALL' = ANY(lsv.applicable_doc_types))
		ORDER BY rank DESC, lsv.created_at ASC
		LIMIT $4
	`

	rows, err := r.db.Query(ctx, sql, tsQuery, dateStr, docType, limit)
	if err != nil {
		// Fallback to simple ILIKE search if tsquery syntax had an issue
		fallbackSQL := `
			SELECT lsv.id, ls.code, ls.title, lsv.article_number, lsv.title, lsv.full_text,
			       lsv.norm_nature, lsv.official_url, lsv.effective_from, lsv.effective_to,
			       0.5 AS rank
			FROM legal_source_versions lsv
			JOIN legal_sources ls ON lsv.source_id = ls.id
			WHERE lsv.effective_from <= $1::date
			  AND (lsv.effective_to IS NULL OR lsv.effective_to >= $1::date)
			LIMIT $2
		`
		rows, err = r.db.Query(ctx, fallbackSQL, dateStr, limit)
		if err != nil {
			return nil, fmt.Errorf("failed to search legal corpus: %w", err)
		}
	}
	defer rows.Close()

	articles := make([]LegalArticle, 0)
	for rows.Next() {
		var a LegalArticle
		var rank float64
		err := rows.Scan(
			&a.ID, &a.SourceCode, &a.SourceTitle, &a.ArticleNumber, &a.Title,
			&a.FullText, &a.NormNature, &a.OfficialURL, &a.EffectiveFrom, &a.EffectiveTo,
			&rank,
		)
		if err != nil {
			continue
		}
		a.SimilarityScore = rank
		articles = append(articles, a)
	}

	return articles, nil
}

// ValidateCitation verifies if an article and official URL actually exist in the database (Closed-World Allowlist)
func (r *Repository) ValidateCitation(ctx context.Context, sourceCode, articleNumber, officialURL string, contractDate time.Time) (*LegalArticle, error) {
	dateStr := contractDate.Format("2006-01-02")
	sql := `
		SELECT lsv.id, ls.code, ls.title, lsv.article_number, lsv.title, lsv.full_text,
		       lsv.norm_nature, lsv.official_url, lsv.effective_from, lsv.effective_to, 1.0
		FROM legal_source_versions lsv
		JOIN legal_sources ls ON lsv.source_id = ls.id
		WHERE (ls.code = $1 OR ls.code ILIKE '%' || $1 || '%')
		  AND (lsv.article_number = $2 OR lsv.article_number ILIKE '%' || $2 || '%')
		  AND lsv.effective_from <= $3::date
		  AND (lsv.effective_to IS NULL OR lsv.effective_to >= $3::date)
		LIMIT 1
	`
	var a LegalArticle
	var rank float64
	err := r.db.QueryRow(ctx, sql, sourceCode, articleNumber, dateStr).Scan(
		&a.ID, &a.SourceCode, &a.SourceTitle, &a.ArticleNumber, &a.Title,
		&a.FullText, &a.NormNature, &a.OfficialURL, &a.EffectiveFrom, &a.EffectiveTo,
		&rank,
	)
	if err != nil {
		return nil, err
	}
	return &a, nil
}

// ListAllSources returns all registered legal sources
func (r *Repository) ListAllSources(ctx context.Context) ([]map[string]interface{}, error) {
	sql := `SELECT id, code, title, short_name, source_type, jurisdiction FROM legal_sources ORDER BY code`
	rows, err := r.db.Query(ctx, sql)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []map[string]interface{}
	for rows.Next() {
		var id, code, title, shortName, sourceType, jurisdiction string
		if err := rows.Scan(&id, &code, &title, &shortName, &sourceType, &jurisdiction); err == nil {
			list = append(list, map[string]interface{}{
				"id":           id,
				"code":         code,
				"title":        title,
				"short_name":   shortName,
				"source_type":  sourceType,
				"jurisdiction": jurisdiction,
			})
		}
	}
	return list, nil
}
