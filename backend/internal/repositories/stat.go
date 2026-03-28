package repositories

import (
	"database/sql"

	"rush-fracture/backend/internal/models"
)

type StatRepository struct {
	db *sql.DB
}

func NewStatRepository(db *sql.DB) *StatRepository {
	return &StatRepository{db: db}
}

func (r *StatRepository) GetByUserID(userID string) (*models.Stat, error) {
	stat := &models.Stat{}
	err := r.db.QueryRow(
		"SELECT user_id, total_runs, best_score, best_level, total_time, total_kills FROM stats WHERE user_id = ?",
		userID,
	).Scan(&stat.UserID, &stat.TotalRuns, &stat.BestScore, &stat.BestLevel, &stat.TotalTime, &stat.TotalKills)
	if err != nil {
		return nil, err
	}
	return stat, nil
}
