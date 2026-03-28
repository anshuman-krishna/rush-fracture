package services

import (
	"fmt"
	"time"

	"rush-fracture/backend/internal/models"
	"rush-fracture/backend/internal/repositories"
)

type RoomEventService struct {
	repo    *repositories.RoomEventRepository
	runRepo *repositories.RunRepository
}

func NewRoomEventService(repo *repositories.RoomEventRepository, runRepo *repositories.RunRepository) *RoomEventService {
	return &RoomEventService{repo: repo, runRepo: runRepo}
}

func (s *RoomEventService) RecordRoomEntered(runID string, roomIndex int, roomType string, elapsedTime int) (*models.RoomEvent, error) {
	if err := s.validateActiveRun(runID); err != nil {
		return nil, err
	}

	event := &models.RoomEvent{
		ID:          generateID(),
		RunID:       runID,
		EventType:   models.RoomEventEntered,
		RoomIndex:   roomIndex,
		RoomType:    roomType,
		ElapsedTime: elapsedTime,
		CreatedAt:   time.Now().UTC(),
	}
	if err := s.repo.Create(event); err != nil {
		return nil, err
	}
	return event, nil
}

func (s *RoomEventService) RecordRoomCleared(runID string, roomIndex int, roomType string, enemiesKilled, elapsedTime int) (*models.RoomEvent, error) {
	if err := s.validateActiveRun(runID); err != nil {
		return nil, err
	}

	event := &models.RoomEvent{
		ID:            generateID(),
		RunID:         runID,
		EventType:     models.RoomEventCleared,
		RoomIndex:     roomIndex,
		RoomType:      roomType,
		EnemiesKilled: enemiesKilled,
		ElapsedTime:   elapsedTime,
		CreatedAt:     time.Now().UTC(),
	}
	if err := s.repo.Create(event); err != nil {
		return nil, err
	}
	return event, nil
}

func (s *RoomEventService) RecordUpgrade(runID string, roomIndex int, upgradeID string, elapsedTime int) (*models.RoomEvent, error) {
	if err := s.validateActiveRun(runID); err != nil {
		return nil, err
	}

	event := &models.RoomEvent{
		ID:          generateID(),
		RunID:       runID,
		EventType:   models.RoomEventUpgrade,
		RoomIndex:   roomIndex,
		UpgradeID:   upgradeID,
		ElapsedTime: elapsedTime,
		CreatedAt:   time.Now().UTC(),
	}
	if err := s.repo.Create(event); err != nil {
		return nil, err
	}
	return event, nil
}

func (s *RoomEventService) GetByRunID(runID string) ([]*models.RoomEvent, error) {
	return s.repo.GetByRunID(runID)
}

func (s *RoomEventService) validateActiveRun(runID string) error {
	run, err := s.runRepo.GetByID(runID)
	if err != nil {
		return fmt.Errorf("run not found")
	}
	if run.Status != models.RunStatusActive {
		return fmt.Errorf("run is not active")
	}
	return nil
}
