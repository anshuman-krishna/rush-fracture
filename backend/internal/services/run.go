package services

import (
	"database/sql"
	"errors"
	"time"

	"rush-fracture/backend/internal/models"
	"rush-fracture/backend/internal/repositories"
)

type RunService struct {
	repo     *repositories.RunRepository
	userRepo *repositories.UserRepository
}

func NewRunService(repo *repositories.RunRepository, userRepo *repositories.UserRepository) *RunService {
	return &RunService{repo: repo, userRepo: userRepo}
}

func (s *RunService) Start(userID string) (*models.Run, error) {
	exists, err := s.userRepo.Exists(userID)
	if err != nil {
		return nil, err
	}
	if !exists {
		return nil, ErrUnknownUser
	}

	run := &models.Run{
		ID:        generateID(),
		UserID:    userID,
		Status:    models.RunStatusActive,
		CreatedAt: time.Now().UTC(),
	}
	if err := s.repo.Create(run); err != nil {
		// the user was deleted between the check and the insert
		if errors.Is(err, repositories.ErrMissingReference) {
			return nil, ErrUnknownUser
		}
		return nil, err
	}
	return run, nil
}

func (s *RunService) End(id string, score, level, enemiesKilled, duration, bestCombo int, weaponUsed, mutations, runTags string, bossEncountered, bossDefeated bool) (*models.Run, error) {
	run, err := s.GetByID(id)
	if err != nil {
		return nil, err
	}

	run.Score = score
	run.Level = level
	run.EnemiesKilled = enemiesKilled
	run.Duration = duration
	run.BestCombo = bestCombo
	run.WeaponUsed = weaponUsed
	run.Mutations = mutations
	run.RunTags = runTags
	run.BossEncountered = bossEncountered
	run.BossDefeated = bossDefeated

	finished, err := s.repo.Finish(run)
	if err != nil {
		return nil, err
	}
	if !finished {
		return nil, ErrRunNotActive
	}
	run.Status = models.RunStatusComplete
	return run, nil
}

func (s *RunService) GetByID(id string) (*models.Run, error) {
	run, err := s.repo.GetByID(id)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return run, err
}
