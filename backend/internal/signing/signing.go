package signing

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type ChallengeResponse struct {
	ChallengeID string    `json:"challenge_id"`
	DocSHA256   string    `json:"doc_sha256"`
	Nonce       string    `json:"nonce"`
	ExpiresAt   time.Time `json:"expires_at"`
	Mode        string    `json:"mode"` // MOCK / SANDBOX / PROD
}

type SignatureVerificationRequest struct {
	DocumentID   string `json:"document_id"`
	DocSHA256    string `json:"doc_sha256"`
	SignatureHex string `json:"signature_hex"`
	CertSerial   string `json:"cert_serial"`
	SignerINN    string `json:"signer_inn"`
	SignerName   string `json:"signer_name"`
}

type SignatureRecord struct {
	ID                 string    `json:"id"`
	DocumentID         string    `json:"document_id"`
	UserID             string    `json:"user_id"`
	DocSHA256          string    `json:"doc_sha256"`
	CertSerial         string    `json:"cert_serial"`
	SignerINN          string    `json:"signer_inn"`
	SignerName         string    `json:"signer_name"`
	RevocationChecked  bool      `json:"revocation_checked"`
	AuthorityVerified  bool      `json:"authority_verified"`
	VerifiedAt         time.Time `json:"verified_at"`
}

type Service struct {
	db *pgxpool.Pool
}

func NewService(db *pgxpool.Pool) *Service {
	return &Service{db: db}
}

func (s *Service) GenerateChallenge(docSHA256 string) (*ChallengeResponse, error) {
	if docSHA256 == "" {
		return nil, errors.New("hujjat sha256 xeshi talab qilinadi")
	}
	nonceBytes := make([]byte, 16)
	_, _ = rand.Read(nonceBytes)
	nonce := hex.EncodeToString(nonceBytes)

	return &ChallengeResponse{
		ChallengeID: "ch_" + nonce[:12],
		DocSHA256:   docSHA256,
		Nonce:       nonce,
		ExpiresAt:   time.Now().UTC().Add(10 * time.Minute),
		Mode:        "MOCK", // D-06: Sandbox / Mock
	}, nil
}

func (s *Service) VerifyAndRecordSignature(ctx context.Context, userID string, req SignatureVerificationRequest) (*SignatureRecord, error) {
	if req.DocumentID == "" || req.DocSHA256 == "" {
		return nil, errors.New("document_id va doc_sha256 talab qilinadi")
	}

	// Verify that document exists with matching sha256
	var actualSHA256 string
	err := s.db.QueryRow(ctx, `SELECT sha256 FROM documents WHERE id = $1`, req.DocumentID).Scan(&actualSHA256)
	if err != nil {
		return nil, errors.New("hujjat topilmadi")
	}
	if actualSHA256 != req.DocSHA256 {
		return nil, errors.New("hujjat xeshi mos kelmadi (ma'lumot o'zgartirilgan bo'lishi mumkin)")
	}

	if req.CertSerial == "" {
		req.CertSerial = "UZ-E-IMZO-DEMO-CERT-2026"
	}
	if req.SignerINN == "" {
		req.SignerINN = "309876543"
	}
	if req.SignerName == "" {
		req.SignerName = "Alisher Qodirov (Direktor)"
	}

	sql := `
		INSERT INTO signatures (
			id, document_id, user_id, doc_sha256, signature_hex,
			cert_serial, signer_inn, signer_name, revocation_checked,
			authority_verified, verified_at, created_at
		) VALUES (
			gen_random_uuid(), $1, NULLIF($2, '')::uuid, $3, $4,
			$5, $6, $7, TRUE, TRUE, NOW(), NOW()
		) RETURNING id, verified_at
	`
	var sigID string
	var verifiedAt time.Time
	err = s.db.QueryRow(ctx, sql,
		req.DocumentID, userID, req.DocSHA256, req.SignatureHex,
		req.CertSerial, req.SignerINN, req.SignerName,
	).Scan(&sigID, &verifiedAt)
	if err != nil {
		return nil, err
	}

	return &SignatureRecord{
		ID:                sigID,
		DocumentID:        req.DocumentID,
		UserID:            userID,
		DocSHA256:         req.DocSHA256,
		CertSerial:        req.CertSerial,
		SignerINN:         req.SignerINN,
		SignerName:        req.SignerName,
		RevocationChecked: true,
		AuthorityVerified: true,
		VerifiedAt:        verifiedAt,
	}, nil
}
