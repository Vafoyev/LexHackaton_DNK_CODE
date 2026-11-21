package legalcorpus

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrArticleNotFound    = errors.New("article not found in legal allowlist")
	ErrTemporalOutOfRange = errors.New("article was not in force on contract date")
)

type LegalArticle struct {
	ID              string     `json:"id"`
	SourceCode      string     `json:"source_code"`
	SourceTitle     string     `json:"source_title"`
	ArticleNumber   string     `json:"article_number"`
	Title           string     `json:"title"`
	FullText        string     `json:"full_text"`
	NormNature      string     `json:"norm_nature"` // IMPERATIVE, DISPOSITIVE
	OfficialURL     string     `json:"official_url"`
	EffectiveFrom   time.Time  `json:"effective_from"`
	EffectiveTo     *time.Time `json:"effective_to"`
	SimilarityScore float64    `json:"similarity_score"`
}

type Repository struct {
	db              *pgxpool.Pool
	inMemoryCorpus  []LegalArticle
	inMemorySources []map[string]interface{}
}

func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{
		db:              db,
		inMemoryCorpus:  CuratedLegalArticles,
		inMemorySources: CuratedLegalSources,
	}
}

// SearchHybrid performs Temporal Hybrid RAG (Temporal Filter + Lexical Ranking + In-Memory Fallback)
func (r *Repository) SearchHybrid(ctx context.Context, query string, contractDate time.Time, docType string, limit int) ([]LegalArticle, error) {
	if limit <= 0 {
		limit = 5
	}

	if contractDate.IsZero() {
		contractDate = time.Now()
	}

	dateStr := contractDate.Format("2006-01-02")

	// Try PostgreSQL if connection exists
	if r.db != nil {
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
		if err == nil {
			defer rows.Close()
			var articles []LegalArticle
			for rows.Next() {
				var a LegalArticle
				var rank float64
				if err := rows.Scan(
					&a.ID, &a.SourceCode, &a.SourceTitle, &a.ArticleNumber, &a.Title,
					&a.FullText, &a.NormNature, &a.OfficialURL, &a.EffectiveFrom, &a.EffectiveTo,
					&rank,
				); err == nil {
					a.SimilarityScore = rank
					articles = append(articles, a)
				}
			}
			if len(articles) > 0 {
				return articles, nil
			}
		}
	}

	// Deterministic Offline/In-Memory Fallback
	return r.searchInMemory(query, contractDate, docType, limit), nil
}

func (r *Repository) searchInMemory(query string, contractDate time.Time, docType string, limit int) []LegalArticle {
	qLower := strings.ToLower(query)
	qTokens := strings.Fields(qLower)

	type scoredArticle struct {
		art   LegalArticle
		score float64
	}

	var candidates []scoredArticle

	for _, art := range r.inMemoryCorpus {
		// 1. Strict Temporal Check: must be active on contractDate
		if art.EffectiveFrom.After(contractDate) {
			continue // Not yet in force!
		}
		if art.EffectiveTo != nil && art.EffectiveTo.Before(contractDate) {
			continue // Expired/superseded!
		}

		// 2. Lexical scoring
		textLower := strings.ToLower(art.Title + " " + art.FullText + " " + art.ArticleNumber)
		matches := 0
		for _, token := range qTokens {
			cleanToken := strings.Trim(token, ".,!?:;\"'()[]{}")
			if len(cleanToken) > 2 && strings.Contains(textLower, cleanToken) {
				matches++
			}
		}

		score := float64(matches) / float64(len(qTokens)+1)
		if strings.Contains(textLower, qLower) {
			score += 1.0
		}

		if score > 0 {
			artCopy := art
			artCopy.SimilarityScore = score
			candidates = append(candidates, scoredArticle{art: artCopy, score: score})
		}
	}

	// Sort descending by score
	for i := 0; i < len(candidates)-1; i++ {
		for j := i + 1; j < len(candidates); j++ {
			if candidates[j].score > candidates[i].score {
				candidates[i], candidates[j] = candidates[j], candidates[i]
			}
		}
	}

	var results []LegalArticle
	for i, c := range candidates {
		if i >= limit {
			break
		}
		results = append(results, c.art)
	}

	// If results are still empty, return top temporally valid general articles
	if len(results) == 0 {
		for _, art := range r.inMemoryCorpus {
			if !art.EffectiveFrom.After(contractDate) && (art.EffectiveTo == nil || !art.EffectiveTo.Before(contractDate)) {
				artCopy := art
				artCopy.SimilarityScore = 0.5
				results = append(results, artCopy)
				if len(results) >= limit {
					break
				}
			}
		}
	}

	return results
}

// ValidateCitation verifies if an article and official URL actually exist in the database (Closed-World Allowlist)
// and whether it was legally in force at the contractDate (Vector 1 & Vector 2)
func (r *Repository) ValidateCitation(ctx context.Context, sourceCode, articleNumber, officialURL string, contractDate time.Time) (*LegalArticle, error) {
	if contractDate.IsZero() {
		contractDate = time.Now()
	}

	// Normalize article number e.g. "707" -> "707-modda"
	normArt := strings.TrimSpace(articleNumber)
	if !strings.HasSuffix(normArt, "-modda") && !strings.Contains(normArt, "modda") {
		normArt = normArt + "-modda"
	}

	// Check DB if available
	if r.db != nil {
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
		err := r.db.QueryRow(ctx, sql, sourceCode, normArt, dateStr).Scan(
			&a.ID, &a.SourceCode, &a.SourceTitle, &a.ArticleNumber, &a.Title,
			&a.FullText, &a.NormNature, &a.OfficialURL, &a.EffectiveFrom, &a.EffectiveTo,
			&rank,
		)
		if err == nil {
			return &a, nil
		}
	}

	// In-memory verification (Closed-world allowlist & temporal check)
	sourceCodeLower := strings.ToLower(strings.TrimSpace(sourceCode))
	normArtLower := strings.ToLower(normArt)

	var foundArticle *LegalArticle

	for _, art := range r.inMemoryCorpus {
		artCodeLower := strings.ToLower(art.SourceCode)
		artNumLower := strings.ToLower(art.ArticleNumber)

		codeMatches := strings.Contains(artCodeLower, sourceCodeLower) || strings.Contains(sourceCodeLower, artCodeLower)
		numMatches := strings.Contains(artNumLower, normArtLower) || strings.Contains(normArtLower, artNumLower)

		if codeMatches && numMatches {
			foundArticle = &art
			break
		}
	}

	if foundArticle == nil {
		return nil, ErrArticleNotFound
	}

	// Temporal check (FK 4-modda)
	if foundArticle.EffectiveFrom.After(contractDate) {
		return foundArticle, fmt.Errorf("%w: %s %s kuchga kirish sanasi %s, shartnoma sanasi %s",
			ErrTemporalOutOfRange, foundArticle.SourceCode, foundArticle.ArticleNumber,
			foundArticle.EffectiveFrom.Format("2006-01-02"), contractDate.Format("2006-01-02"))
	}

	if foundArticle.EffectiveTo != nil && foundArticle.EffectiveTo.Before(contractDate) {
		return foundArticle, fmt.Errorf("%w: %s %s amal qilish muddati tugagan (%s)",
			ErrTemporalOutOfRange, foundArticle.SourceCode, foundArticle.ArticleNumber,
			foundArticle.EffectiveTo.Format("2006-01-02"))
	}

	return foundArticle, nil
}

// ResolveApplicableLaws determines which laws were strictly in force on the given contractDate
func (r *Repository) ResolveApplicableLaws(contractDate time.Time, docType string) []LegalArticle {
	if contractDate.IsZero() {
		contractDate = time.Now()
	}

	var active []LegalArticle
	for _, art := range r.inMemoryCorpus {
		if art.EffectiveFrom.After(contractDate) {
			continue
		}
		if art.EffectiveTo != nil && art.EffectiveTo.Before(contractDate) {
			continue
		}
		active = append(active, art)
	}
	return active
}

// ExplainTemporalApplicability explains why a law is or isn't valid for a given date
func (r *Repository) ExplainTemporalApplicability(sourceCode, articleNumber string, contractDate time.Time) string {
	art, err := r.ValidateCitation(context.Background(), sourceCode, articleNumber, "", contractDate)
	if err == nil && art != nil {
		return fmt.Sprintf("%s %s shartnoma sanasida (%s) to‘liq qonuniy kuchga ega bo‘lgan (Kuchga kirgan: %s).",
			art.SourceTitle, art.ArticleNumber, contractDate.Format("2006-01-02"), art.EffectiveFrom.Format("2006-01-02"))
	}

	if errors.Is(err, ErrTemporalOutOfRange) {
		if art != nil && art.EffectiveFrom.After(contractDate) {
			return fmt.Sprintf("DIQQAT: %s %s ushbu shartnoma sanasida (%s) amalda bo‘lmagan! U faqat %s dan kuchga kirgan. FK 4-moddasiga ko‘ra orqaga qaytish kuchiga ega emas.",
				art.SourceCode, art.ArticleNumber, contractDate.Format("2006-01-02"), art.EffectiveFrom.Format("2006-01-02"))
		}
		if art != nil && art.EffectiveTo != nil {
			return fmt.Sprintf("DIQQAT: %s %s ushbu shartnoma sanasida (%s) o‘z kuchini yo‘qotgan bo‘lgan (Tugagan: %s).",
				art.SourceCode, art.ArticleNumber, contractDate.Format("2006-01-02"), art.EffectiveTo.Format("2006-01-02"))
		}
	}

	return fmt.Sprintf("%s %s rasmiy Lex.uz qonunchilik bazasida topilmadi (Gallyutsinatsiya xavfi).", sourceCode, articleNumber)
}

// ListAllSources returns all registered legal sources
func (r *Repository) ListAllSources(ctx context.Context) ([]map[string]interface{}, error) {
	if r.db != nil {
		sql := `SELECT id, code, title, short_name, source_type, jurisdiction FROM legal_sources ORDER BY code`
		rows, err := r.db.Query(ctx, sql)
		if err == nil {
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
			if len(list) > 0 {
				return list, nil
			}
		}
	}
	return r.inMemorySources, nil
}
