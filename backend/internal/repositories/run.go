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
		"INSERT INTO runs (id, user_id, player_id, status, score, level, enemies_killed, duration, best_combo, weapon_used, mutations, run_tags, boss_encountered, boss_defeated, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
		run.ID, run.UserID, run.PlayerID, run.Status, run.Score, run.Level, run.EnemiesKilled, run.Duration, run.BestCombo, run.WeaponUsed, run.Mutations, run.RunTags, run.BossEncountered, run.BossDefeated, run.CreatedAt,
	)
	return translate(err)
}

func (r *RunRepository) GetByID(id string) (*models.Run, error) {
	run := &models.Run{}
	err := r.db.QueryRow(
		"SELECT id, user_id, player_id, status, score, level, enemies_killed, duration, best_combo, weapon_used, mutations, run_tags, boss_encountered, boss_defeated, created_at FROM runs WHERE id = ?", id,
	).Scan(&run.ID, &run.UserID, &run.PlayerID, &run.Status, &run.Score, &run.Level, &run.EnemiesKilled, &run.Duration, &run.BestCombo, &run.WeaponUsed, &run.Mutations, &run.RunTags, &run.BossEncountered, &run.BossDefeated, &run.CreatedAt)
	if err != nil {
		return nil, err
	}
	return run, nil
}

// Finish writes a run's results and marks it complete, but only if it is
// still active. the check and the write are one statement, so two requests
// ending the same run cannot both succeed. reports whether it changed a row.
func (r *RunRepository) Finish(run *models.Run) (bool, error) {
	res, err := r.db.Exec(
		"UPDATE runs SET status = ?, score = ?, level = ?, enemies_killed = ?, duration = ?, best_combo = ?, weapon_used = ?, mutations = ?, run_tags = ?, boss_encountered = ?, boss_defeated = ? WHERE id = ? AND status = ?",
		models.RunStatusComplete, run.Score, run.Level, run.EnemiesKilled, run.Duration, run.BestCombo, run.WeaponUsed, run.Mutations, run.RunTags, run.BossEncountered, run.BossDefeated, run.ID, models.RunStatusActive,
	)
	if err != nil {
		return false, err
	}
	n, err := res.RowsAffected()
	return n > 0, err
}
