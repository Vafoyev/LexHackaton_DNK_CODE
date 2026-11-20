package platform

import (
	"os"
	"strconv"
)

type Config struct {
	AppEnv            string
	HTTPAddr          string
	DatabaseURL       string
	JWTSecret         string
	AIProvider        string
	ExternalAIEnabled bool
	StorageDir        string
}

func LoadConfig() *Config {
	cfg := &Config{
		AppEnv:            getEnv("APP_ENV", "development"),
		HTTPAddr:          getEnv("HTTP_ADDR", ":8080"),
		DatabaseURL:       getEnv("DATABASE_URL", "postgres://lexguard:lexguard@127.0.0.1:5432/lexguard?sslmode=disable"),
		JWTSecret:         getEnv("JWT_SECRET", "super-secret-lexguard-jwt-key-2026-minimum-32-chars!"),
		AIProvider:        getEnv("AI_PROVIDER", "noop"),
		ExternalAIEnabled: getEnvBool("EXTERNAL_AI_ENABLED", false),
		StorageDir:        getEnv("STORAGE_DIR", "./var/uploads"),
	}
	return cfg
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
