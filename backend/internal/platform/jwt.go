package platform

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type JWTClaims struct {
	UserID         string `json:"sub"`
	OrganizationID string `json:"org_id"`
	Role           string `json:"role"`
	ClientType     string `json:"client_type"`
	jwt.RegisteredClaims
}

type TokenPair struct {
	AccessToken  string    `json:"access_token"`
	RefreshToken string    `json:"refresh_token"`
	ExpiresAt    time.Time `json:"expires_at"`
	TokenType    string    `json:"token_type"`
}

type JWTManager struct {
	secretKey     []byte
	accessExpiry  time.Duration
	refreshExpiry time.Duration
}

func NewJWTManager(secret string) *JWTManager {
	return &JWTManager{
		secretKey:     []byte(secret),
		accessExpiry:  15 * time.Minute,
		refreshExpiry: 30 * 24 * time.Hour,
	}
}

func (m *JWTManager) GenerateTokenPair(userID, orgID, role, clientType string) (*TokenPair, string, error) {
	now := time.Now().UTC()
	accessExpiry := now.Add(m.accessExpiry)

	claims := JWTClaims{
		UserID:         userID,
		OrganizationID: orgID,
		Role:           role,
		ClientType:     clientType,
		RegisteredClaims: jwt.RegisteredClaims{
			ID:        uuid.NewString(),
			Subject:   userID,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(accessExpiry),
			Issuer:    "lexguard-api",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signedAccess, err := token.SignedString(m.secretKey)
	if err != nil {
		return nil, "", err
	}

	// Generate 32 bytes cryptographic random refresh token
	rawRefreshBytes := make([]byte, 32)
	if _, err := rand.Read(rawRefreshBytes); err != nil {
		return nil, "", err
	}
	rawRefreshToken := hex.EncodeToString(rawRefreshBytes)
	refreshHash := HashRefreshToken(rawRefreshToken)

	pair := &TokenPair{
		AccessToken:  signedAccess,
		RefreshToken: rawRefreshToken,
		ExpiresAt:    accessExpiry,
		TokenType:    "Bearer",
	}

	return pair, refreshHash, nil
}

func (m *JWTManager) ValidateToken(tokenString string) (*JWTClaims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &JWTClaims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return m.secretKey, nil
	},
		jwt.WithValidMethods([]string{"HS256"}),
		jwt.WithIssuer("lexguard-api"),
		jwt.WithExpirationRequired(),
	)
	if err != nil {
		return nil, err
	}

	claims, ok := token.Claims.(*JWTClaims)
	if !ok || !token.Valid {
		return nil, errors.New("invalid token claims")
	}

	return claims, nil
}

func HashRefreshToken(token string) string {
	h := sha256.Sum256([]byte(token))
	return hex.EncodeToString(h[:])
}
