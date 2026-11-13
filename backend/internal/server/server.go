// package server wires the repositories, services, controllers and
// middleware into one http handler, so the binary and the tests build the
// api the same way.
package server

import (
	"database/sql"
	"net/http"
	"time"

	"rush-fracture/backend/internal/config"
	"rush-fracture/backend/internal/controllers"
	"rush-fracture/backend/internal/middleware"
	"rush-fracture/backend/internal/repositories"
	"rush-fracture/backend/internal/services"
	"rush-fracture/backend/internal/websocket"
)

func New(cfg config.Config, db *sql.DB) http.Handler {
	userRepo := repositories.NewUserRepository(db)
	runRepo := repositories.NewRunRepository(db)
	statRepo := repositories.NewStatRepository(db)
	roomEventRepo := repositories.NewRoomEventRepository(db)

	userService := services.NewUserService(userRepo)
	runService := services.NewRunService(runRepo, userRepo)
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

	// the rate limiter sits in front of the key check on purpose: wrong
	// guesses at the key count against the limit like anything else.
	return middleware.Chain(mux,
		middleware.Logger,
		middleware.Recovery,
		middleware.CORS(cfg.AllowedOrigins),
		rateLimiter.Middleware,
		middleware.APIKeyAuth(cfg.APIKey),
		middleware.MaxBody(cfg.MaxBodyBytes),
	)
}
