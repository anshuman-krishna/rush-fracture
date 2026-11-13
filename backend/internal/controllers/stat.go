package controllers

import (
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
	stat, err := c.service.GetByUserID(r.PathValue("userId"))
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, stat)
}
