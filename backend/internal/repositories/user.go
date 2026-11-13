package repositories

import (
	"database/sql"

	"rush-fracture/backend/internal/models"
)

type UserRepository struct {
	db *sql.DB
}

func NewUserRepository(db *sql.DB) *UserRepository {
	return &UserRepository{db: db}
}

func (r *UserRepository) Create(user *models.User) error {
	_, err := r.db.Exec(
		"INSERT INTO users (id, username, created_at) VALUES (?, ?, ?)",
		user.ID, user.Username, user.CreatedAt,
	)
	return translate(err)
}

func (r *UserRepository) GetByID(id string) (*models.User, error) {
	user := &models.User{}
	err := r.db.QueryRow(
		"SELECT id, username, created_at FROM users WHERE id = ?", id,
	).Scan(&user.ID, &user.Username, &user.CreatedAt)
	if err != nil {
		return nil, err
	}
	return user, nil
}

func (r *UserRepository) Exists(id string) (bool, error) {
	var one int
	err := r.db.QueryRow("SELECT 1 FROM users WHERE id = ?", id).Scan(&one)
	if err == sql.ErrNoRows {
		return false, nil
	}
	return err == nil, err
}
