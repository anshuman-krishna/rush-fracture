package repositories

import (
	"database/sql"

	"rush-fracture/backend/internal/models"
)

// the most events one request for a run's log will return.
const MaxEventsReturned = 1000

type RoomEventRepository struct {
	db *sql.DB
}

func NewRoomEventRepository(db *sql.DB) *RoomEventRepository {
	return &RoomEventRepository{db: db}
}

func (r *RoomEventRepository) Create(event *models.RoomEvent) error {
	_, err := r.db.Exec(
		`INSERT INTO room_events (id, run_id, player_id, event_type, room_index, room_type, enemies_killed, elapsed_time, upgrade_id, fracture_type, created_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		event.ID, event.RunID, event.PlayerID, event.EventType, event.RoomIndex, event.RoomType,
		event.EnemiesKilled, event.ElapsedTime, event.UpgradeID, event.FractureType, event.CreatedAt,
	)
	return translate(err)
}

func (r *RoomEventRepository) CountByRunID(runID string) (int, error) {
	var n int
	err := r.db.QueryRow("SELECT COUNT(*) FROM room_events WHERE run_id = ?", runID).Scan(&n)
	return n, err
}

func (r *RoomEventRepository) GetByRunID(runID string) ([]*models.RoomEvent, error) {
	rows, err := r.db.Query(
		"SELECT id, run_id, player_id, event_type, room_index, room_type, enemies_killed, elapsed_time, upgrade_id, fracture_type, created_at FROM room_events WHERE run_id = ? ORDER BY created_at, rowid LIMIT ?",
		runID, MaxEventsReturned,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	// an empty log is an empty list, not null, once it is json
	events := []*models.RoomEvent{}
	for rows.Next() {
		e := &models.RoomEvent{}
		if err := rows.Scan(&e.ID, &e.RunID, &e.PlayerID, &e.EventType, &e.RoomIndex, &e.RoomType, &e.EnemiesKilled, &e.ElapsedTime, &e.UpgradeID, &e.FractureType, &e.CreatedAt); err != nil {
			return nil, err
		}
		events = append(events, e)
	}
	return events, rows.Err()
}
