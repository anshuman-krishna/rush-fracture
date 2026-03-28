package services

import (
	"fmt"
	"time"

	"rush-fracture/backend/internal/models"
	"rush-fracture/backend/internal/repositories"
)

type RunService struct {
	repo *repositories.RunRepository
}

func NewRunService(repo *repositories.RunRepository) *RunService {
	return &RunService{repo: repo}
}

func (s *RunService) Start(userID string) (*models.Run, error) {
	run := &models.Run{
		ID:        generateID(),
		UserID:    userID,
		Status:    models.RunStatusActive,
		CreatedAt: time.Now().UTC(),
	}
	if err := s.repo.Create(run); err != nil {
		return nil, err
	}
	return run, nil
}

func (s *RunService) End(id string, score, level, enemiesKilled, duration int) (*models.Run, error) {
	run, err := s.repo.GetByID(id)
	if err != nil {
		return nil, err
	}

	if run.Status != models.RunStatusActive {
		return nil, fmt.Errorf("run is not active")
	}

	run.Status = models.RunStatusComplete
	run.Score = score
	run.Level = level
	run.EnemiesKilled = enemiesKilled
	run.Duration = duration

	if err := s.repo.Update(run); err != nil {
		return nil, err
	}
	return run, nil
}

func (s *RunService) GetByID(id string) (*models.Run, error) {
	return s.repo.GetByID(id)
}
