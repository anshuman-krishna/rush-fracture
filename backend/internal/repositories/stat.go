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

// computed live from runs — no separate stats table to keep in sync.
// always returns a row (zeroed if the user has no runs yet).
func (r *StatRepository) GetByUserID(userID string) (*models.Stat, error) {
	stat := &models.Stat{UserID: userID}
	err := r.db.QueryRow(
		`SELECT COUNT(*), COALESCE(MAX(score), 0), COALESCE(MAX(level), 0),
			COALESCE(SUM(duration), 0), COALESCE(SUM(enemies_killed), 0)
		FROM runs WHERE user_id = ?`,
		userID,
	).Scan(&stat.TotalRuns, &stat.BestScore, &stat.BestLevel, &stat.TotalTime, &stat.TotalKills)
	if err != nil {
		return nil, err
	}
	return stat, nil
}
