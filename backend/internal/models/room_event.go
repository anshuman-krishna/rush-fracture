package models

import "time"

type RoomEventType string

const (
	RoomEventEntered  RoomEventType = "entered"
	RoomEventCleared  RoomEventType = "cleared"
	RoomEventUpgrade  RoomEventType = "upgrade"
	RoomEventFracture RoomEventType = "fracture"
)

type RoomEvent struct {
	ID            string        `json:"id"`
	RunID         string        `json:"run_id"`
	EventType     RoomEventType `json:"event_type"`
	RoomIndex     int           `json:"room_index"`
	RoomType      string        `json:"room_type"`
	EnemiesKilled int           `json:"enemies_killed"`
	ElapsedTime   int           `json:"elapsed_time"`
	UpgradeID     string        `json:"upgrade_id,omitempty"`
	FractureType  string        `json:"fracture_type,omitempty"`
	CreatedAt     time.Time     `json:"created_at"`
}
