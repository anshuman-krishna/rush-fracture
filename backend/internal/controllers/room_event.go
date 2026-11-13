package controllers

import (
	"net/http"

	"rush-fracture/backend/internal/services"
	"rush-fracture/backend/internal/validate"
)

type RoomEventController struct {
	service *services.RoomEventService
}

func NewRoomEventController(service *services.RoomEventService) *RoomEventController {
	return &RoomEventController{service: service}
}

func (c *RoomEventController) RoomEntered(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RoomIndex   int    `json:"room_index"`
		RoomType    string `json:"room_type"`
		ElapsedTime int    `json:"elapsed_time"`
	}
	if !readJSON(w, r, &req) {
		return
	}

	if err := validateRoomFields(req.RoomIndex, req.RoomType, req.ElapsedTime); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	event, err := c.service.RecordRoomEntered(r.PathValue("id"), req.RoomIndex, req.RoomType, req.ElapsedTime)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, event)
}

func (c *RoomEventController) RoomCleared(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RoomIndex     int    `json:"room_index"`
		RoomType      string `json:"room_type"`
		EnemiesKilled int    `json:"enemies_killed"`
		ElapsedTime   int    `json:"elapsed_time"`
	}
	if !readJSON(w, r, &req) {
		return
	}

	if err := validateRoomFields(req.RoomIndex, req.RoomType, req.ElapsedTime); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	if err := validate.Range("enemies_killed", req.EnemiesKilled, 0, validate.MaxKills); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	event, err := c.service.RecordRoomCleared(r.PathValue("id"), req.RoomIndex, req.RoomType, req.EnemiesKilled, req.ElapsedTime)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, event)
}

func (c *RoomEventController) UpgradeChosen(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RoomIndex   int    `json:"room_index"`
		UpgradeID   string `json:"upgrade_id"`
		ElapsedTime int    `json:"elapsed_time"`
	}
	if !readJSON(w, r, &req) {
		return
	}

	if err := validate.NonEmpty("upgrade_id", req.UpgradeID, validate.MaxShortStrLen); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	if err := validate.Range("room_index", req.RoomIndex, 0, validate.MaxRoomIndex); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	if err := validate.Range("elapsed_time", req.ElapsedTime, 0, validate.MaxDuration); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	event, err := c.service.RecordUpgrade(r.PathValue("id"), req.RoomIndex, req.UpgradeID, req.ElapsedTime)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, event)
}

func (c *RoomEventController) GetByRun(w http.ResponseWriter, r *http.Request) {
	events, err := c.service.GetByRunID(r.PathValue("id"))
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, events)
}

func validateRoomFields(roomIndex int, roomType string, elapsedTime int) error {
	if err := validate.NonEmpty("room_type", roomType, validate.MaxShortStrLen); err != nil {
		return err
	}
	if err := validate.Range("room_index", roomIndex, 0, validate.MaxRoomIndex); err != nil {
		return err
	}
	if err := validate.Range("elapsed_time", elapsedTime, 0, validate.MaxDuration); err != nil {
		return err
	}
	return nil
}
