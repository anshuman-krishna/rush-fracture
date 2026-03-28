package repositories

import (
	"database/sql"

	_ "github.com/mattn/go-sqlite3"
)

func OpenDatabase(path string) (*sql.DB, error) {
	db, err := sql.Open("sqlite3", path)
	if err != nil {
		return nil, err
	}

	db.SetMaxOpenConns(1)

	if err := db.Ping(); err != nil {
		return nil, err
	}

	return db, nil
}

func Migrate(db *sql.DB) error {
	_, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS users (
			id TEXT PRIMARY KEY,
			username TEXT NOT NULL UNIQUE,
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
		);

		CREATE TABLE IF NOT EXISTS runs (
			id TEXT PRIMARY KEY,
			user_id TEXT NOT NULL,
			status TEXT NOT NULL DEFAULT 'active',
			score INTEGER NOT NULL DEFAULT 0,
			level INTEGER NOT NULL DEFAULT 0,
			enemies_killed INTEGER NOT NULL DEFAULT 0,
			duration INTEGER NOT NULL DEFAULT 0,
			best_combo INTEGER NOT NULL DEFAULT 0,
			weapon_used TEXT NOT NULL DEFAULT '',
			mutations TEXT NOT NULL DEFAULT '',
			run_tags TEXT NOT NULL DEFAULT '',
			boss_encountered INTEGER NOT NULL DEFAULT 0,
			boss_defeated INTEGER NOT NULL DEFAULT 0,
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (user_id) REFERENCES users(id)
		);

		CREATE TABLE IF NOT EXISTS stats (
			user_id TEXT PRIMARY KEY,
			total_runs INTEGER NOT NULL DEFAULT 0,
			best_score INTEGER NOT NULL DEFAULT 0,
			best_level INTEGER NOT NULL DEFAULT 0,
			total_time INTEGER NOT NULL DEFAULT 0,
			total_kills INTEGER NOT NULL DEFAULT 0,
			FOREIGN KEY (user_id) REFERENCES users(id)
		);

		CREATE TABLE IF NOT EXISTS room_events (
			id TEXT PRIMARY KEY,
			run_id TEXT NOT NULL,
			event_type TEXT NOT NULL,
			room_index INTEGER NOT NULL DEFAULT 0,
			room_type TEXT NOT NULL DEFAULT '',
			enemies_killed INTEGER NOT NULL DEFAULT 0,
			elapsed_time INTEGER NOT NULL DEFAULT 0,
			upgrade_id TEXT NOT NULL DEFAULT '',
			fracture_type TEXT NOT NULL DEFAULT '',
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (run_id) REFERENCES runs(id)
		);
	`)
	return err
}
