package platform

import (
	"errors"
	"log/slog"
	"os"
	"strconv"
	"strings"
)

// DefaultInsecureJWTSecret faqat lokal rivojlantirish uchun. Production'da ishlatilsa server ishga tushmaydi.
const DefaultInsecureJWTSecret = "super-secret-lexguard-jwt-key-2026-minimum-32-chars!"

type Config struct {
	AppEnv            string
	HTTPAddr          string
	DatabaseURL       string
	JWTSecret         string
	AIProvider        string
	ExternalAIEnabled bool
	StorageDir        string
	// CORSOrigins: ruxsat etilgan brauzer origin'lari (vergul bilan). Bo'sh bo'lsa production'da CORS yopiq.
	CORSOrigins []string
	// AllowDemoLogin: /auth/demo-session va OneID mock endpointlari. Default: production'dan boshqa muhitda yoqilgan.
	AllowDemoLogin bool
	// MetricsToken: /metrics uchun Bearer token. Bo'sh bo'lsa /metrics faqat lokal (loopback) so'rovlarga ochiq.
	MetricsToken string
}

func LoadConfig() *Config {
	env := getEnv("APP_ENV", "development")
	cfg := &Config{
		AppEnv:            env,
		HTTPAddr:          getEnv("HTTP_ADDR", ":8080"),
		DatabaseURL:       getEnv("DATABASE_URL", "postgres://lexguard:lexguard@127.0.0.1:5432/lexguard?sslmode=disable"),
		JWTSecret:         getEnv("JWT_SECRET", DefaultInsecureJWTSecret),
		AIProvider:        getEnv("AI_PROVIDER", "noop"),
		ExternalAIEnabled: getEnvBool("EXTERNAL_AI_ENABLED", false),
		StorageDir:        getEnv("STORAGE_DIR", "./var/uploads"),
		CORSOrigins:       splitList(os.Getenv("CORS_ORIGINS")),
		AllowDemoLogin:    getEnvBool("ALLOW_DEMO_LOGIN", env != "production"),
		MetricsToken:      os.Getenv("METRICS_TOKEN"),
	}
	return cfg
}

func (c *Config) IsProduction() bool { return c.AppEnv == "production" }

// Validate production'da xavfli sozlamalarni rad etadi (default/qisqa JWT kaliti) va dev'da ogohlantiradi.
func (c *Config) Validate() error {
	weak := c.JWTSecret == DefaultInsecureJWTSecret || len(c.JWTSecret) < 32
	if weak && c.IsProduction() {
		return errors.New("JWT_SECRET production'da kamida 32 belgi bo'lishi va standart qiymat bo'lmasligi shart (openssl rand -hex 32)")
	}
	if weak {
		slog.Warn("jwt_secret_insecure_dev_default", slog.String("hint", "faqat rivojlantirish uchun; production'da JWT_SECRET o'rnating"))
	}
	if c.IsProduction() && c.AllowDemoLogin {
		slog.Warn("demo_login_enabled_in_production", slog.String("hint", "ALLOW_DEMO_LOGIN=true: demo-session hamma uchun ochiq"))
	}
	return nil
}

// RedactedDatabaseURL loglar uchun: parol maskalangan.
func (c *Config) RedactedDatabaseURL() string {
	return RedactURL(c.DatabaseURL)
}

func RedactURL(raw string) string {
	// postgres://user:pass@host/db -> postgres://user:***@host/db
	at := strings.LastIndex(raw, "@")
	scheme := strings.Index(raw, "://")
	if at < 0 || scheme < 0 || at < scheme {
		return raw
	}
	creds := raw[scheme+3 : at]
	if colon := strings.Index(creds, ":"); colon >= 0 {
		creds = creds[:colon] + ":***"
	}
	return raw[:scheme+3] + creds + raw[at:]
}

func splitList(v string) []string {
	var out []string
	for _, p := range strings.Split(v, ",") {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}

func getEnv(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}

func getEnvBool(key string, defaultVal bool) bool {
	if val := os.Getenv(key); val != "" {
		b, err := strconv.ParseBool(val)
		if err == nil {
			return b
		}
	}
	return defaultVal
}
