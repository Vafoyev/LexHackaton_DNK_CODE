package audit

import (
	"context"
	"encoding/json"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type AuditEvent struct {
	ID             string                 `json:"id"`
	OrganizationID string                 `json:"organization_id"`
	UserID         string                 `json:"user_id"`
	EventType      string                 `json:"event_type"`
	ResourceType   string                 `json:"resource_type"`
	ResourceID     string                 `json:"resource_id"`
	IPAddress      string                 `json:"ip_address"`
	UserAgent      string                 `json:"user_agent"`
	Metadata       map[string]interface{} `json:"metadata"`
	CreatedAt      time.Time              `json:"created_at"`
}

type Service struct {
	db *pgxpool.Pool
}

func NewService(db *pgxpool.Pool) *Service {
	return &Service{db: db}
}

func (s *Service) Log(
	ctx context.Context,
	orgID, userID, eventType, resType, resID, ip, userAgent string,
	meta map[string]interface{},
) {
	if meta == nil {
		meta = make(map[string]interface{})
	}
	metaBytes, _ := json.Marshal(meta)

	sql := `
		INSERT INTO audit_events (
			id, organization_id, user_id, event_type, resource_type,
			resource_id, ip_address, user_agent, metadata_json, created_at
		) VALUES (
			gen_random_uuid(),
			NULLIF($1, '')::uuid,
			NULLIF($2, '')::uuid,
			$3, $4,
			NULLIF($5, '')::uuid,
			$6, $7, $8, NOW()
		)
	`
	// Run fire-and-forget or background logging to not slow down primary transaction
	go func() {
		bgCtx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		_, _ = s.db.Exec(bgCtx, sql, orgID, userID, eventType, resType, resID, ip, userAgent, metaBytes)
	}()
}

func (s *Service) ListEvents(ctx context.Context, orgID string, limit int) ([]AuditEvent, error) {
	if limit <= 0 {
		limit = 50
	}
	sql := `
		SELECT id, COALESCE(organization_id::text, ''), COALESCE(user_id::text, ''),
		       event_type, resource_type, COALESCE(resource_id::text, ''),
		       COALESCE(ip_address, ''), COALESCE(user_agent, ''), metadata_json, created_at
		FROM audit_events
		WHERE ($1 = '' OR organization_id = NULLIF($1, '')::uuid)
		ORDER BY created_at DESC
		LIMIT $2
	`
	rows, err := s.db.Query(ctx, sql, orgID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var events []AuditEvent
	for rows.Next() {
		var e AuditEvent
		var metaBytes []byte
		err := rows.Scan(
			&e.ID, &e.OrganizationID, &e.UserID, &e.EventType, &e.ResourceType,
			&e.ResourceID, &e.IPAddress, &e.UserAgent, &metaBytes, &e.CreatedAt,
		)
		if err == nil {
			_ = json.Unmarshal(metaBytes, &e.Metadata)
			events = append(events, e)
		}
	}
	return events, nil
}
