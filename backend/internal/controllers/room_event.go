package controllers

import (
	"encoding/json"
	"net/http"

	"rush-fracture/backend/internal/services"
)

type RoomEventController struct {
	service *services.RoomEventService
}

func NewRoomEventController(service *services.RoomEventService) *RoomEventController {
	return &RoomEventController{service: service}
}

func (c *RoomEventController) RoomEntered(w http.ResponseWriter, r *http.Request) {
	runID := r.PathValue("id")

	var req struct {
		RoomIndex   int    `json:"room_index"`
		RoomType    string `json:"room_type"`
		ElapsedTime int    `json:"elapsed_time"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.RoomType == "" {
		http.Error(w, "room_type is required", http.StatusBadRequest)
		return
	}

	event, err := c.service.RecordRoomEntered(runID, req.RoomIndex, req.RoomType, req.ElapsedTime)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(event)
}

func (c *RoomEventController) RoomCleared(w http.ResponseWriter, r *http.Request) {
	runID := r.PathValue("id")

	var req struct {
		RoomIndex     int    `json:"room_index"`
		RoomType      string `json:"room_type"`
		EnemiesKilled int    `json:"enemies_killed"`
		ElapsedTime   int    `json:"elapsed_time"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.RoomType == "" {
		http.Error(w, "room_type is required", http.StatusBadRequest)
		return
	}

	event, err := c.service.RecordRoomCleared(runID, req.RoomIndex, req.RoomType, req.EnemiesKilled, req.ElapsedTime)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(event)
}

func (c *RoomEventController) UpgradeChosen(w http.ResponseWriter, r *http.Request) {
	runID := r.PathValue("id")

	var req struct {
		RoomIndex   int    `json:"room_index"`
		UpgradeID   string `json:"upgrade_id"`
		ElapsedTime int    `json:"elapsed_time"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.UpgradeID == "" {
		http.Error(w, "upgrade_id is required", http.StatusBadRequest)
		return
	}

	event, err := c.service.RecordUpgrade(runID, req.RoomIndex, req.UpgradeID, req.ElapsedTime)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(event)
}

func (c *RoomEventController) GetByRun(w http.ResponseWriter, r *http.Request) {
	runID := r.PathValue("id")

	events, err := c.service.GetByRunID(runID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(events)
}
