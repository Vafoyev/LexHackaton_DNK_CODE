package platform

import (
	"log/slog"
	"os"
	"strings"
)

// InitLogger configures and sets the global structured slog logger.
// In development, it uses human-friendly text format with debug level.
// In production/staging, it uses high-performance JSON format with info level.
func InitLogger(appEnv string) *slog.Logger {
	var handler slog.Handler

	env := strings.ToLower(strings.TrimSpace(appEnv))
	if env == "development" || env == "dev" || env == "local" {
		handler = slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
			Level:     slog.LevelDebug,
			AddSource: true,
		})
	} else {
		handler = slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
			Level:     slog.LevelInfo,
			AddSource: false,
		})
	}

	logger := slog.New(handler)
	slog.SetDefault(logger)
	return logger
}
