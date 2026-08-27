package config

import (
	"os"
	"strconv"
	"strings"
)

type Config struct {
	Address         string
	DatabasePath    string
	APIKey          string
	AllowedOrigins  []string
	RateLimitPerMin int
}

func Load() Config {
	return Config{
		Address:         envOr("SERVER_ADDRESS", ":8080"),
		DatabasePath:    envOr("DATABASE_PATH", "rush-fracture.db"),
		APIKey:          envOr("API_KEY", ""),
		AllowedOrigins:  splitCSV(envOr("ALLOWED_ORIGINS", "")),
		RateLimitPerMin: envOrInt("RATE_LIMIT_PER_MIN", 120),
	}
}

func envOr(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}

func envOrInt(key string, fallback int) int {
	val := os.Getenv(key)
	if val == "" {
		return fallback
	}
	n, err := strconv.Atoi(val)
	if err != nil {
		return fallback
	}
	return n
}

func splitCSV(val string) []string {
	if val == "" {
		return nil
	}
	parts := strings.Split(val, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}
