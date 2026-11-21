package documents

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/lexguard/backend/internal/privacy"
)

type Repository struct {
	db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

func (r *Repository) SaveDocumentWithClauses(ctx context.Context, doc *DocumentInfo) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	// 1. Insert into documents
	sqlDoc := `
		INSERT INTO documents (
			id, organization_id, user_id, filename, file_size, mime_type, sha256,
			storage_path, data_classification, parse_confidence, created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $11)
	`
	now := time.Now().UTC()
	_, err = tx.Exec(ctx, sqlDoc,
		doc.ID, doc.OrganizationID, doc.UserID, doc.Filename, doc.FileSize,
		doc.MimeType, doc.SHA256, doc.StoragePath, string(doc.DataClassification),
		doc.ParseConfidence, now,
	)
	if err != nil {
		return fmt.Errorf("failed to insert document: %w", err)
	}

	// 2. Insert into document_versions
	sqlVer := `
		INSERT INTO document_versions (id, document_id, version_number, sha256, storage_path, created_at)
		VALUES (gen_random_uuid(), $1, 1, $2, $3, $4)
	`
	if _, err := tx.Exec(ctx, sqlVer, doc.ID, doc.SHA256, doc.StoragePath, now); err != nil {
		return fmt.Errorf("failed to insert document version: %w", err)
	}

	// 3. Insert clauses
	sqlClause := `
		INSERT INTO clauses (
			id, document_id, clause_number, title, raw_text, redacted_text,
			pii_entities_json, start_offset, end_offset, created_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`
	for _, c := range doc.Clauses {
		piiJSON, _ := json.Marshal(c.PIIEntities)
		_, err := tx.Exec(ctx, sqlClause,
			c.ID, doc.ID, c.ClauseNumber, c.Title, c.RawText, c.RedactedText,
			piiJSON, c.StartOffset, c.EndOffset, now,
		)
		if err != nil {
			return fmt.Errorf("failed to insert clause %s: %w", c.ClauseNumber, err)
		}
	}

	return tx.Commit(ctx)
}

func (r *Repository) GetDocument(ctx context.Context, docID, orgID string) (*DocumentInfo, error) {
	sqlDoc := `
		SELECT id, organization_id, COALESCE(user_id::text, ''), filename, file_size, mime_type,
		       sha256, storage_path, data_classification, parse_confidence, created_at
		FROM documents
		WHERE id = $1 AND organization_id = $2 AND deleted_at IS NULL
	`
	var doc DocumentInfo
	var classStr string
	err := r.db.QueryRow(ctx, sqlDoc, docID, orgID).Scan(
		&doc.ID, &doc.OrganizationID, &doc.UserID, &doc.Filename, &doc.FileSize,
		&doc.MimeType, &doc.SHA256, &doc.StoragePath, &classStr,
		&doc.ParseConfidence, &doc.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	doc.DataClassification = privacy.DataClassification(classStr)

	// Fetch clauses
	sqlClauses := `
		SELECT id, document_id, clause_number, COALESCE(title, ''), raw_text, redacted_text,
		       pii_entities_json, start_offset, end_offset
		FROM clauses
		WHERE document_id = $1
		ORDER BY start_offset ASC, clause_number ASC
	`
	rows, err := r.db.Query(ctx, sqlClauses, docID)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var c ClauseInfo
			var piiBytes []byte
			if err := rows.Scan(&c.ID, &c.DocumentID, &c.ClauseNumber, &c.Title, &c.RawText, &c.RedactedText, &piiBytes, &c.StartOffset, &c.EndOffset); err == nil {
				_ = json.Unmarshal(piiBytes, &c.PIIEntities)
				doc.Clauses = append(doc.Clauses, c)
			}
		}
	}

	return &doc, nil
}

func (r *Repository) ListDocuments(ctx context.Context, orgID string, limit int) ([]DocumentInfo, error) {
	if limit <= 0 {
		limit = 20
	}
	sqlDocs := `
		SELECT id, organization_id, COALESCE(user_id::text, ''), filename, file_size, mime_type,
		       sha256, storage_path, data_classification, parse_confidence, created_at
		FROM documents
		WHERE organization_id = $1 AND deleted_at IS NULL
		ORDER BY created_at DESC
		LIMIT $2
	`
	rows, err := r.db.Query(ctx, sqlDocs, orgID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	list := make([]DocumentInfo, 0)
	for rows.Next() {
		var doc DocumentInfo
		var classStr string
		err := rows.Scan(
			&doc.ID, &doc.OrganizationID, &doc.UserID, &doc.Filename, &doc.FileSize,
			&doc.MimeType, &doc.SHA256, &doc.StoragePath, &classStr,
			&doc.ParseConfidence, &doc.CreatedAt,
		)
		if err == nil {
			doc.DataClassification = privacy.DataClassification(classStr)
			list = append(list, doc)
		}
	}
	return list, nil
}

func (r *Repository) SoftDeleteDocument(ctx context.Context, docID, orgID string) error {
	sql := `UPDATE documents SET deleted_at = NOW(), updated_at = NOW() WHERE id = $1 AND organization_id = $2`
	tag, err := r.db.Exec(ctx, sql, docID, orgID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("hujjat topilmadi yoki o'chirishga ruxsat berilmadi")
	}
	return nil
}
