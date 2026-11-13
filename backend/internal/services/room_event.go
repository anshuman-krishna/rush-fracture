package services

import (
	"database/sql"
	"errors"
	"time"

	"rush-fracture/backend/internal/models"
	"rush-fracture/backend/internal/repositories"
)

// the most events one run may record. a real run produces a few dozen; the
// cap only exists so one run id cannot be used to fill the disk.
const MaxEventsPerRun = 2000

type RoomEventService struct {
	repo    *repositories.RoomEventRepository
	runRepo *repositories.RunRepository
}

func NewRoomEventService(repo *repositories.RoomEventRepository, runRepo *repositories.RunRepository) *RoomEventService {
	return &RoomEventService{repo: repo, runRepo: runRepo}
}

func (s *RoomEventService) RecordRoomEntered(runID string, roomIndex int, roomType string, elapsedTime int) (*models.RoomEvent, error) {
	return s.record(&models.RoomEvent{
		RunID:       runID,
		EventType:   models.RoomEventEntered,
		RoomIndex:   roomIndex,
		RoomType:    roomType,
		ElapsedTime: elapsedTime,
	})
}

func (s *RoomEventService) RecordRoomCleared(runID string, roomIndex int, roomType string, enemiesKilled, elapsedTime int) (*models.RoomEvent, error) {
	return s.record(&models.RoomEvent{
		RunID:         runID,
		EventType:     models.RoomEventCleared,
		RoomIndex:     roomIndex,
		RoomType:      roomType,
		EnemiesKilled: enemiesKilled,
		ElapsedTime:   elapsedTime,
	})
}

func (s *RoomEventService) RecordUpgrade(runID string, roomIndex int, upgradeID string, elapsedTime int) (*models.RoomEvent, error) {
	return s.record(&models.RoomEvent{
		RunID:       runID,
		EventType:   models.RoomEventUpgrade,
		RoomIndex:   roomIndex,
		UpgradeID:   upgradeID,
		ElapsedTime: elapsedTime,
	})
}

func (s *RoomEventService) GetByRunID(runID string) ([]*models.RoomEvent, error) {
	if _, err := s.runRepo.GetByID(runID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return s.repo.GetByRunID(runID)
}

func (s *RoomEventService) record(event *models.RoomEvent) (*models.RoomEvent, error) {
	run, err := s.runRepo.GetByID(event.RunID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if run.Status != models.RunStatusActive {
		return nil, ErrRunNotActive
	}
	count, err := s.repo.CountByRunID(event.RunID)
	if err != nil {
		return nil, err
	}
	if count >= MaxEventsPerRun {
		return nil, ErrTooManyEvents
	}

	event.ID = generateID()
	event.CreatedAt = time.Now().UTC()
	if err := s.repo.Create(event); err != nil {
		return nil, err
	}
	return event, nil
}
