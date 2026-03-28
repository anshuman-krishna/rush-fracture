package models

import "time"

type RunStatus string

const (
	RunStatusActive   RunStatus = "active"
	RunStatusComplete RunStatus = "complete"
)

type Run struct {
	ID            string    `json:"id"`
	UserID        string    `json:"user_id"`
	Status        RunStatus `json:"status"`
	Score         int       `json:"score"`
	Level         int       `json:"level"`
	EnemiesKilled int       `json:"enemies_killed"`
	Duration      int       `json:"duration"`
	CreatedAt     time.Time `json:"created_at"`
}
