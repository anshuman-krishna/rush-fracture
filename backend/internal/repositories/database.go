package repositories

import (
	"database/sql"
	"errors"
	"strings"

	_ "github.com/mattn/go-sqlite3"
)

// ErrDuplicate is returned when an insert breaks a unique constraint.
var ErrDuplicate = errors.New("duplicate value")

// ErrMissingReference is returned when a row points at a parent that does
// not exist (a run for an unknown user, an event for an unknown run).
var ErrMissingReference = errors.New("referenced row does not exist")

func OpenDatabase(path string) (*sql.DB, error) {
	// sqlite leaves foreign keys off unless asked, and without a busy
	// timeout a second writer fails at once instead of waiting its turn.
	sep := "?"
	if strings.Contains(path, "?") {
		sep = "&"
	}
	db, err := sql.Open("sqlite3", path+sep+"_foreign_keys=on&_busy_timeout=5000")
	if err != nil {
		return nil, err
	}

	db.SetMaxOpenConns(1)

	if err := db.Ping(); err != nil {
		db.Close()
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
			player_id TEXT NOT NULL DEFAULT '',
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

		CREATE TABLE IF NOT EXISTS room_events (
			id TEXT PRIMARY KEY,
			run_id TEXT NOT NULL,
			player_id TEXT NOT NULL DEFAULT '',
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

		CREATE INDEX IF NOT EXISTS idx_runs_user ON runs(user_id);
		CREATE INDEX IF NOT EXISTS idx_room_events_run ON room_events(run_id, created_at);
	`)
	return err
}

// translates the driver's constraint errors into ones the services can test
// for. the driver's own error type only exists in cgo builds, so this goes
// by the message, which sqlite keeps stable.
func translate(err error) error {
	if err == nil {
		return nil
	}
	msg := err.Error()
	switch {
	case strings.Contains(msg, "UNIQUE constraint failed"):
		return ErrDuplicate
	case strings.Contains(msg, "FOREIGN KEY constraint failed"):
		return ErrMissingReference
	}
	return err
}
