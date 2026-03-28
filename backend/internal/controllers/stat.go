package controllers

import (
	"encoding/json"
	"net/http"

	"rush-fracture/backend/internal/services"
)

type StatController struct {
	service *services.StatService
}

func NewStatController(service *services.StatService) *StatController {
	return &StatController{service: service}
}

func (c *StatController) GetByUser(w http.ResponseWriter, r *http.Request) {
	userID := r.PathValue("userId")

	stat, err := c.service.GetByUserID(userID)
	if err != nil {
		http.Error(w, "stats not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(stat)
}
