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
	"rush-fracture/backend/internal/controllers"
	"rush-fracture/backend/internal/middleware"
	"rush-fracture/backend/internal/repositories"
	"rush-fracture/backend/internal/services"
	"rush-fracture/backend/internal/websocket"
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

	userRepo := repositories.NewUserRepository(db)
	runRepo := repositories.NewRunRepository(db)
	statRepo := repositories.NewStatRepository(db)
	roomEventRepo := repositories.NewRoomEventRepository(db)

	userService := services.NewUserService(userRepo)
	runService := services.NewRunService(runRepo)
	statService := services.NewStatService(statRepo)
	roomEventService := services.NewRoomEventService(roomEventRepo, runRepo)

	healthController := controllers.NewHealthController(db)
	userController := controllers.NewUserController(userService)
	runController := controllers.NewRunController(runService)
	statController := controllers.NewStatController(statService)
	roomEventController := controllers.NewRoomEventController(roomEventService)

	wsHub := websocket.NewHub(cfg.AllowedOrigins)
	go wsHub.Run()

	mux := http.NewServeMux()

	mux.HandleFunc("GET /health", healthController.Health)
	mux.HandleFunc("POST /api/users", userController.Create)
	mux.HandleFunc("GET /api/users/{id}", userController.Get)
	mux.HandleFunc("POST /api/runs/start", runController.Start)
	mux.HandleFunc("POST /api/runs/{id}/end", runController.End)
	mux.HandleFunc("GET /api/runs/{id}", runController.Get)
	mux.HandleFunc("POST /api/runs/{id}/rooms/enter", roomEventController.RoomEntered)
	mux.HandleFunc("POST /api/runs/{id}/rooms/clear", roomEventController.RoomCleared)
	mux.HandleFunc("POST /api/runs/{id}/upgrade", roomEventController.UpgradeChosen)
	mux.HandleFunc("GET /api/runs/{id}/events", roomEventController.GetByRun)
	mux.HandleFunc("GET /api/stats/{userId}", statController.GetByUser)
	mux.HandleFunc("GET /ws", wsHub.HandleConnection)

	rateLimiter := middleware.NewRateLimiter(cfg.RateLimitPerMin, time.Minute)

	if cfg.APIKey == "" {
		slog.Warn("API_KEY not set, api is open with no auth")
	}
	if len(cfg.AllowedOrigins) == 0 {
		slog.Warn("ALLOWED_ORIGINS not set, no browser origin can call this api")
	}

	handler := middleware.Chain(mux,
		middleware.Logger,
		middleware.Recovery,
		middleware.CORS(cfg.AllowedOrigins),
		middleware.APIKeyAuth(cfg.APIKey),
		rateLimiter.Middleware,
		middleware.MaxBody(cfg.MaxBodyBytes),
	)

	srv := &http.Server{
		Addr:    cfg.Address,
		Handler: handler,
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
