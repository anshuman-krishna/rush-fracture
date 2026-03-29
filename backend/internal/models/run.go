package models

import "time"

type RunStatus string

const (
	RunStatusActive   RunStatus = "active"
	RunStatusComplete RunStatus = "complete"
)

type Run struct {
	ID              string    `json:"id"`
	UserID          string    `json:"user_id"`
	PlayerID        string    `json:"player_id,omitempty"`
	Status          RunStatus `json:"status"`
	Score           int       `json:"score"`
	Level           int       `json:"level"`
	EnemiesKilled   int       `json:"enemies_killed"`
	Duration        int       `json:"duration"`
	BestCombo       int       `json:"best_combo"`
	WeaponUsed      string    `json:"weapon_used"`
	Mutations       string    `json:"mutations"`
	RunTags         string    `json:"run_tags"`
	BossEncountered bool      `json:"boss_encountered"`
	BossDefeated    bool      `json:"boss_defeated"`
	CreatedAt       time.Time `json:"created_at"`
}
