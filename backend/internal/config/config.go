package config

import "os"

type Config struct {
	Address      string
	DatabasePath string
}

func Load() Config {
	return Config{
		Address:      envOr("SERVER_ADDRESS", ":8080"),
		DatabasePath: envOr("DATABASE_PATH", "rush-fracture.db"),
	}
}

func envOr(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}
