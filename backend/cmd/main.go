package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"rush-fracture/backend/internal/config"
	"rush-fracture/backend/internal/repositories"
	"rush-fracture/backend/internal/server"
)

const shutdownTimeout = 10 * time.Second

func main() {
	cfg := config.Load()

	db, err := repositories.OpenDatabase(cfg.DatabasePath)
	if err != nil {
		slog.Error("failed to open database", "error", err)
		os.Exit(1)
	}
	defer db.Close()

	if err := repositories.Migrate(db); err != nil {
		slog.Error("failed to run migrations", "error", err)
		os.Exit(1)
	}

	if cfg.APIKey == "" {
		slog.Warn("API_KEY not set, api is open with no auth")
	}
	if len(cfg.AllowedOrigins) == 0 {
		slog.Warn("ALLOWED_ORIGINS not set, no browser origin can call this api")
	}

	// the timeouts stop a client that opens a connection and then sends
	// nothing (or reads nothing) from holding it forever. websocket
	// connections manage their own deadlines once they are upgraded.
	srv := &http.Server{
		Addr:              cfg.Address,
		Handler:           server.New(cfg, db),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
		MaxHeaderBytes:    1 << 16,
	}

	serverErr := make(chan error, 1)
	go func() {
		slog.Info("server starting", "address", cfg.Address)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serverErr <- err
		}
		close(serverErr)
	}()

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	select {
	case err := <-serverErr:
		slog.Error("server failed", "error", err)
		os.Exit(1)
	case <-ctx.Done():
		stop()
		slog.Info("shutdown signal received, draining connections")

		shutdownCtx, cancel := context.WithTimeout(context.Background(), shutdownTimeout)
		defer cancel()
		if err := srv.Shutdown(shutdownCtx); err != nil {
			slog.Error("graceful shutdown failed", "error", err)
			os.Exit(1)
		}
		slog.Info("server stopped cleanly")
	}
}
