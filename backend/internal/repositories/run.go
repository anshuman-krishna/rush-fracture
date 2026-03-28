package repositories

import (
	"database/sql"

	"rush-fracture/backend/internal/models"
)

type RunRepository struct {
	db *sql.DB
}

func NewRunRepository(db *sql.DB) *RunRepository {
	return &RunRepository{db: db}
}

func (r *RunRepository) Create(run *models.Run) error {
	_, err := r.db.Exec(
		"INSERT INTO runs (id, user_id, status, score, level, enemies_killed, duration, best_combo, weapon_used, mutations, run_tags, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
		run.ID, run.UserID, run.Status, run.Score, run.Level, run.EnemiesKilled, run.Duration, run.BestCombo, run.WeaponUsed, run.Mutations, run.RunTags, run.CreatedAt,
	)
	return err
}

func (r *RunRepository) GetByID(id string) (*models.Run, error) {
	run := &models.Run{}
	err := r.db.QueryRow(
		"SELECT id, user_id, status, score, level, enemies_killed, duration, best_combo, weapon_used, mutations, run_tags, created_at FROM runs WHERE id = ?", id,
	).Scan(&run.ID, &run.UserID, &run.Status, &run.Score, &run.Level, &run.EnemiesKilled, &run.Duration, &run.BestCombo, &run.WeaponUsed, &run.Mutations, &run.RunTags, &run.CreatedAt)
	if err != nil {
		return nil, err
	}
	return run, nil
}

func (r *RunRepository) Update(run *models.Run) error {
	_, err := r.db.Exec(
		"UPDATE runs SET status = ?, score = ?, level = ?, enemies_killed = ?, duration = ?, best_combo = ?, weapon_used = ?, mutations = ?, run_tags = ? WHERE id = ?",
		run.Status, run.Score, run.Level, run.EnemiesKilled, run.Duration, run.BestCombo, run.WeaponUsed, run.Mutations, run.RunTags, run.ID,
	)
	return err
}
