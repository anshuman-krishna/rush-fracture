package controllers

import (
	"encoding/json"
	"net/http"

	"rush-fracture/backend/internal/services"
	"rush-fracture/backend/internal/validate"
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

	if err := validate.NonEmpty("user_id", req.UserID, validate.MaxIDLen); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
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
		Score         int    `json:"score"`
		Level         int    `json:"level"`
		EnemiesKilled int    `json:"enemies_killed"`
		Duration      int    `json:"duration"`
		BestCombo     int    `json:"best_combo"`
		WeaponUsed    string `json:"weapon_used"`
		Mutations       string `json:"mutations"`
		RunTags         string `json:"run_tags"`
		BossEncountered bool   `json:"boss_encountered"`
		BossDefeated    bool   `json:"boss_defeated"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if err := validateRunEnd(req.Score, req.Level, req.EnemiesKilled, req.Duration, req.BestCombo, req.WeaponUsed, req.Mutations, req.RunTags); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	run, err := c.service.End(id, req.Score, req.Level, req.EnemiesKilled, req.Duration, req.BestCombo, req.WeaponUsed, req.Mutations, req.RunTags, req.BossEncountered, req.BossDefeated)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(run)
}

func validateRunEnd(score, level, enemiesKilled, duration, bestCombo int, weaponUsed, mutations, runTags string) error {
	if err := validate.Range("score", score, 0, validate.MaxScore); err != nil {
		return err
	}
	if err := validate.Range("level", level, 0, validate.MaxLevel); err != nil {
		return err
	}
	if err := validate.Range("enemies_killed", enemiesKilled, 0, validate.MaxKills); err != nil {
		return err
	}
	if err := validate.Range("duration", duration, 0, validate.MaxDuration); err != nil {
		return err
	}
	if err := validate.Range("best_combo", bestCombo, 0, validate.MaxCombo); err != nil {
		return err
	}
	if err := validate.MaxLen("weapon_used", weaponUsed, validate.MaxShortStrLen); err != nil {
		return err
	}
	if err := validate.MaxLen("mutations", mutations, validate.MaxTagsLen); err != nil {
		return err
	}
	if err := validate.MaxLen("run_tags", runTags, validate.MaxTagsLen); err != nil {
		return err
	}
	return nil
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
