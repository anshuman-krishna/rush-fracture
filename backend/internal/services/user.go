package services

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"errors"
	"strings"
	"time"
	"unicode"

	"rush-fracture/backend/internal/models"
	"rush-fracture/backend/internal/repositories"
)

type UserService struct {
	repo *repositories.UserRepository
}

func NewUserService(repo *repositories.UserRepository) *UserService {
	return &UserService{repo: repo}
}

func (s *UserService) Create(username string) (*models.User, error) {
	username = strings.TrimSpace(username)
	if username == "" {
		return nil, ErrBadUsername
	}
	for _, r := range username {
		if unicode.IsControl(r) {
			return nil, ErrBadUsername
		}
	}

	user := &models.User{
		ID:        generateID(),
		Username:  username,
		CreatedAt: time.Now().UTC(),
	}
	if err := s.repo.Create(user); err != nil {
		if errors.Is(err, repositories.ErrDuplicate) {
			return nil, ErrUsernameTaken
		}
		return nil, err
	}
	return user, nil
}

func (s *UserService) GetByID(id string) (*models.User, error) {
	user, err := s.repo.GetByID(id)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return user, err
}

func generateID() string {
	b := make([]byte, 16)
	rand.Read(b)
	return hex.EncodeToString(b)
}
