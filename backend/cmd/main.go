package main

import (
	"log"
	"net/http"

	"rush-fracture/backend/internal/config"
	"rush-fracture/backend/internal/controllers"
	"rush-fracture/backend/internal/middleware"
	"rush-fracture/backend/internal/repositories"
	"rush-fracture/backend/internal/services"
	"rush-fracture/backend/internal/websocket"
)

func main() {
	cfg := config.Load()

	db, err := repositories.OpenDatabase(cfg.DatabasePath)
	if err != nil {
		log.Fatalf("failed to open database: %v", err)
	}
	defer db.Close()

	if err := repositories.Migrate(db); err != nil {
		log.Fatalf("failed to run migrations: %v", err)
	}

	userRepo := repositories.NewUserRepository(db)
	runRepo := repositories.NewRunRepository(db)
	statRepo := repositories.NewStatRepository(db)
	roomEventRepo := repositories.NewRoomEventRepository(db)

	userService := services.NewUserService(userRepo)
	runService := services.NewRunService(runRepo)
	statService := services.NewStatService(statRepo)
	roomEventService := services.NewRoomEventService(roomEventRepo, runRepo)

	healthController := controllers.NewHealthController()
	userController := controllers.NewUserController(userService)
	runController := controllers.NewRunController(runService)
	statController := controllers.NewStatController(statService)
	roomEventController := controllers.NewRoomEventController(roomEventService)

	wsHub := websocket.NewHub()
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

	handler := middleware.Chain(mux,
		middleware.Logger,
		middleware.Recovery,
		middleware.CORS,
	)

	log.Printf("server starting on %s", cfg.Address)
	if err := http.ListenAndServe(cfg.Address, handler); err != nil {
		log.Fatalf("server failed: %v", err)
	}
}
