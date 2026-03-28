package controllers

import (
	"encoding/json"
	"net/http"

	"rush-fracture/backend/internal/services"
)

type RunController struct {
	service *services.RunService
}

func NewRunController(service *services.RunService) *RunController {
	return &RunController{service: service}
}

func (c *RunController) Start(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID string `json:"user_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.UserID == "" {
		http.Error(w, "user_id is required", http.StatusBadRequest)
		return
	}

	run, err := c.service.Start(req.UserID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(run)
}

func (c *RunController) End(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")

	var req struct {
		Score         int `json:"score"`
		Level         int `json:"level"`
		EnemiesKilled int `json:"enemies_killed"`
		Duration      int `json:"duration"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	run, err := c.service.End(id, req.Score, req.Level, req.EnemiesKilled, req.Duration)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(run)
}

func (c *RunController) Get(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")

	run, err := c.service.GetByID(id)
	if err != nil {
		http.Error(w, "run not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(run)
}
