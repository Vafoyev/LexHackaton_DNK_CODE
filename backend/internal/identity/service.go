package identity

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/lexguard/backend/internal/platform"
	"golang.org/x/crypto/bcrypt"
)

type UserProfile struct {
	ID             string   `json:"id"`
	Email          string   `json:"email"`
	FullName       string   `json:"full_name"`
	Phone          string   `json:"phone"`
	JSHSHIR        string   `json:"jshshir"`
	OrganizationID string   `json:"organization_id"`
	OrgName        string   `json:"org_name"`
	Role           string   `json:"role"`
	Consents       []string `json:"consents"`
}

type AuthResult struct {
	User   UserProfile         `json:"user"`
	Tokens *platform.TokenPair `json:"tokens"`
}

type Service struct {
	db         *pgxpool.Pool
	jwtManager *platform.JWTManager
}

func NewService(db *pgxpool.Pool, jwtManager *platform.JWTManager) *Service {
	return &Service{db: db, jwtManager: jwtManager}
}

func (s *Service) Register(ctx context.Context, email, password, fullName, orgName, phone, clientType string) (*AuthResult, error) {
	if email == "" || password == "" || fullName == "" {
		return nil, errors.New("email, parol va to'liq ism kiritilishi shart")
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	if orgName == "" {
		orgName = fullName + " Korxonasi"
	}
	slug := fmt.Sprintf("org-%d", time.Now().UnixNano()%1000000)

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	// 1. Create org
	var orgID string
	err = tx.QueryRow(ctx, `
		INSERT INTO organizations (name, inn, slug)
		VALUES ($1, '300000000', $2)
		RETURNING id
	`, orgName, slug).Scan(&orgID)
	if err != nil {
		return nil, fmt.Errorf("tashkilot yaratishda xatolik: %w", err)
	}

	// 2. Create user
	var userID string
	err = tx.QueryRow(ctx, `
		INSERT INTO users (email, password_hash, full_name, phone)
		VALUES ($1, $2, $3, $4)
		RETURNING id
	`, email, string(hash), fullName, phone).Scan(&userID)
	if err != nil {
		return nil, fmt.Errorf("foydalanuvchi yaratishda xatolik (balki ushbu email allaqachon mavjud): %w", err)
	}

	// 3. Create membership
	_, err = tx.Exec(ctx, `
		INSERT INTO memberships (organization_id, user_id, role, authority_verified)
		VALUES ($1, $2, 'owner', TRUE)
	`, orgID, userID)
	if err != nil {
		return nil, err
	}

	// 4. Create initial quota
	_, err = tx.Exec(ctx, `
		INSERT INTO quotas (organization_id, plan_name, analyses_limit, analyses_used, tokens_limit, tokens_used)
		VALUES ($1, 'STARTER', 50, 0, 500000, 0)
	`, orgID)
	if err != nil {
		return nil, err
	}

	// 5. Default consent
	_, err = tx.Exec(ctx, `
		INSERT INTO consents (user_id, organization_id, consent_type, version, granted)
		VALUES ($1, $2, 'DATA_PROCESSING', '1.0', TRUE),
		       ($1, $2, 'EXTERNAL_AI', '1.0', TRUE)
	`, userID, orgID)
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}

	return s.createSessionAndTokens(ctx, userID, orgID, orgName, email, fullName, phone, "", "owner", clientType, "")
}

func (s *Service) Login(ctx context.Context, email, password, clientType, userAgent, ip string) (*AuthResult, error) {
	sql := `
		SELECT u.id, u.email, u.password_hash, u.full_name, COALESCE(u.phone, ''), COALESCE(u.jshshir, ''),
		       m.organization_id, m.role, o.name
		FROM users u
		JOIN memberships m ON u.id = m.user_id
		JOIN organizations o ON m.organization_id = o.id
		WHERE u.email = $1 AND u.is_active = TRUE
		LIMIT 1
	`
	var u UserProfile
	var pwdHash string
	err := s.db.QueryRow(ctx, sql, email).Scan(
		&u.ID, &u.Email, &pwdHash, &u.FullName, &u.Phone, &u.JSHSHIR,
		&u.OrganizationID, &u.Role, &u.OrgName,
	)
	if err != nil {
		return nil, errors.New("email yoki parol noto'g'ri")
	}

	// Compare bcrypt password
	if err := bcrypt.CompareHashAndPassword([]byte(pwdHash), []byte(password)); err != nil {
		// Also allow hackathon demo bypass with Password123!
		if password != "Password123!" {
			return nil, errors.New("email yoki parol noto'g'ri")
		}
	}

	return s.createSessionAndTokens(ctx, u.ID, u.OrganizationID, u.OrgName, u.Email, u.FullName, u.Phone, u.JSHSHIR, u.Role, clientType, userAgent)
}

func (s *Service) DemoSession(ctx context.Context, asRole, clientType string) (*AuthResult, error) {
	email := "lawyer@lexguard.uz"
	if asRole == "client" {
		email = "client@lexguard.uz"
	}

	sql := `
		SELECT u.id, u.email, u.full_name, COALESCE(u.phone, ''), COALESCE(u.jshshir, ''),
		       m.organization_id, m.role, o.name
		FROM users u
		JOIN memberships m ON u.id = m.user_id
		JOIN organizations o ON m.organization_id = o.id
		WHERE u.email = $1
		LIMIT 1
	`
	var u UserProfile
	err := s.db.QueryRow(ctx, sql, email).Scan(
		&u.ID, &u.Email, &u.FullName, &u.Phone, &u.JSHSHIR,
		&u.OrganizationID, &u.Role, &u.OrgName,
	)
	if err != nil {
		return nil, fmt.Errorf("demo profilingiz topilmadi, iltimos bazani qayta yuklang: %w", err)
	}

	return s.createSessionAndTokens(ctx, u.ID, u.OrganizationID, u.OrgName, u.Email, u.FullName, u.Phone, u.JSHSHIR, u.Role, clientType, "demo-agent")
}

func (s *Service) RefreshSession(ctx context.Context, rawRefreshToken, clientType string) (*AuthResult, error) {
	refreshHash := platform.HashRefreshToken(rawRefreshToken)

	sql := `
		SELECT s.id, s.user_id, s.organization_id, u.email, u.full_name, COALESCE(u.phone, ''),
		       COALESCE(u.jshshir, ''), m.role, o.name, s.expires_at, s.revoked_at
		FROM sessions s
		JOIN users u ON s.user_id = u.id
		JOIN memberships m ON s.organization_id = m.organization_id AND s.user_id = m.user_id
		JOIN organizations o ON s.organization_id = o.id
		WHERE s.refresh_token_hash = $1
		LIMIT 1
	`
	var sessionID, userID, orgID, email, fullName, phone, jshshir, role, orgName string
	var expiresAt time.Time
	var revokedAt *time.Time

	err := s.db.QueryRow(ctx, sql, refreshHash).Scan(
		&sessionID, &userID, &orgID, &email, &fullName, &phone,
		&jshshir, &role, &orgName, &expiresAt, &revokedAt,
	)
	if err != nil {
		return nil, errors.New("yaroqsiz refresh token")
	}

	if revokedAt != nil || time.Now().After(expiresAt) {
		// Session rotation violation or expired
		_, _ = s.db.Exec(ctx, `UPDATE sessions SET revoked_at = NOW() WHERE user_id = $1`, userID)
		return nil, errors.New("sessiya muddati tugagan yoki xavfsizlik sababli bekor qilingan")
	}

	// Revoke old session immediately (Session Rotation)
	_, _ = s.db.Exec(ctx, `UPDATE sessions SET revoked_at = NOW() WHERE id = $1`, sessionID)

	// Issue new token pair and session
	return s.createSessionAndTokens(ctx, userID, orgID, orgName, email, fullName, phone, jshshir, role, clientType, "rotated")
}

func (s *Service) Logout(ctx context.Context, rawRefreshToken string) error {
	refreshHash := platform.HashRefreshToken(rawRefreshToken)
	_, err := s.db.Exec(ctx, `UPDATE sessions SET revoked_at = NOW() WHERE refresh_token_hash = $1`, refreshHash)
	return err
}

func (s *Service) GetMe(ctx context.Context, userID, orgID string) (*UserProfile, error) {
	sql := `
		SELECT u.id, u.email, u.full_name, COALESCE(u.phone, ''), COALESCE(u.jshshir, ''),
		       m.organization_id, m.role, o.name
		FROM users u
		JOIN memberships m ON u.id = m.user_id AND m.organization_id = $2
		JOIN organizations o ON m.organization_id = o.id
		WHERE u.id = $1
	`
	var u UserProfile
	err := s.db.QueryRow(ctx, sql, userID, orgID).Scan(
		&u.ID, &u.Email, &u.FullName, &u.Phone, &u.JSHSHIR,
		&u.OrganizationID, &u.Role, &u.OrgName,
	)
	if err != nil {
		return nil, err
	}

	// Load consents
	rows, err := s.db.Query(ctx, `SELECT consent_type FROM consents WHERE user_id = $1 AND granted = TRUE`, userID)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var ct string
			if err := rows.Scan(&ct); err == nil {
				u.Consents = append(u.Consents, ct)
			}
		}
	}

	return &u, nil
}

func (s *Service) RecordConsent(ctx context.Context, userID, orgID, consentType string, granted bool, ip string) error {
	sql := `
		INSERT INTO consents (id, user_id, organization_id, consent_type, version, granted, ip_address, granted_at)
		VALUES (gen_random_uuid(), $1, $2, $3, '1.0', $4, $5, NOW())
	`
	_, err := s.db.Exec(ctx, sql, userID, orgID, consentType, granted, ip)
	return err
}

func (s *Service) createSessionAndTokens(
	ctx context.Context,
	userID, orgID, orgName, email, fullName, phone, jshshir, role, clientType, userAgent string,
) (*AuthResult, error) {
	if clientType == "" {
		clientType = "web"
	}

	tokens, refreshHash, err := s.jwtManager.GenerateTokenPair(userID, orgID, role, clientType)
	if err != nil {
		return nil, fmt.Errorf("token yaratishda xatolik: %w", err)
	}

	// Insert session into DB
	sqlSession := `
		INSERT INTO sessions (
			id, user_id, organization_id, refresh_token_hash, client_type,
			user_agent, expires_at, created_at
		) VALUES (
			gen_random_uuid(), $1, $2, $3, $4,
			$5, NOW() + INTERVAL '30 days', NOW()
		)
	`
	_, err = s.db.Exec(ctx, sqlSession, userID, orgID, refreshHash, clientType, userAgent)
	if err != nil {
		return nil, fmt.Errorf("sessiyani bazaga yozishda xatolik: %w", err)
	}

	return &AuthResult{
		User: UserProfile{
			ID:             userID,
			Email:          email,
			FullName:       fullName,
			Phone:          phone,
			JSHSHIR:        jshshir,
			OrganizationID: orgID,
			OrgName:        orgName,
			Role:           role,
			Consents:       []string{"DATA_PROCESSING", "EXTERNAL_AI"},
		},
		Tokens: tokens,
	}, nil
}
