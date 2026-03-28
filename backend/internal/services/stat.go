package services

import (
	"rush-fracture/backend/internal/models"
	"rush-fracture/backend/internal/repositories"
)

type StatService struct {
	repo *repositories.StatRepository
}

func NewStatService(repo *repositories.StatRepository) *StatService {
	return &StatService{repo: repo}
}

func (s *StatService) GetByUserID(userID string) (*models.Stat, error) {
	return s.repo.GetByUserID(userID)
}
