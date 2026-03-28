package services

import (
	"crypto/rand"
	"encoding/hex"
	"time"

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
	user := &models.User{
		ID:        generateID(),
		Username:  username,
		CreatedAt: time.Now().UTC(),
	}
	if err := s.repo.Create(user); err != nil {
		return nil, err
	}
	return user, nil
}

func (s *UserService) GetByID(id string) (*models.User, error) {
	return s.repo.GetByID(id)
}

func generateID() string {
	b := make([]byte, 16)
	rand.Read(b)
	return hex.EncodeToString(b)
}
