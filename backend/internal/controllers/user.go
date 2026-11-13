package controllers

import (
	"net/http"

	"rush-fracture/backend/internal/services"
	"rush-fracture/backend/internal/validate"
)

type UserController struct {
	service *services.UserService
}

func NewUserController(service *services.UserService) *UserController {
	return &UserController{service: service}
}

func (c *UserController) Create(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Username string `json:"username"`
	}
	if !readJSON(w, r, &req) {
		return
	}

	if err := validate.NonEmpty("username", req.Username, validate.MaxUsernameLen); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	user, err := c.service.Create(req.Username)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, user)
}

func (c *UserController) Get(w http.ResponseWriter, r *http.Request) {
	user, err := c.service.GetByID(r.PathValue("id"))
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, user)
}
