package service

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/RintaroNasu/routetap/api/internal/models"
	"github.com/RintaroNasu/routetap/api/internal/repository"
	"gorm.io/gorm"
)

var (
	ErrRouteNameRequired   = errors.New("name is required")
	ErrOriginRequired      = errors.New("origin is required")
	ErrDestinationRequired = errors.New("destination is required")
	ErrRouteNameTooLong    = errors.New("name must be 100 characters or fewer")
	ErrOriginTooLong       = errors.New("origin must be 500 characters or fewer")
	ErrDestinationTooLong  = errors.New("destination must be 500 characters or fewer")
	ErrRouteUserRequired   = errors.New("authenticated user is required")
	ErrInvalidRouteID      = errors.New("route id must be a positive integer")
	ErrRouteNotFound       = errors.New("route not found")
)

type SavedRouteService interface {
	Create(ctx context.Context, userID uint, input SavedRouteInput) (*SavedRouteResponse, error)
	List(ctx context.Context, userID uint) ([]SavedRouteResponse, error)
	Update(ctx context.Context, userID, routeID uint, input SavedRouteInput) (*SavedRouteResponse, error)
	Delete(ctx context.Context, userID, routeID uint) error
}

type SavedRouteInput struct {
	Name        string
	Origin      string
	Destination string
}

type SavedRouteResponse struct {
	ID          uint   `json:"id"`
	Name        string `json:"name"`
	Origin      string `json:"origin"`
	Destination string `json:"destination"`
	CreatedAt   string `json:"created_at"`
	UpdatedAt   string `json:"updated_at"`
}

type savedRouteService struct {
	repo repository.SavedRouteRepository
}

func NewSavedRouteService(repo repository.SavedRouteRepository) SavedRouteService {
	return &savedRouteService{repo: repo}
}

func (s *savedRouteService) Create(ctx context.Context, userID uint, input SavedRouteInput) (*SavedRouteResponse, error) {
	if userID == 0 {
		return nil, ErrRouteUserRequired
	}
	input, err := normalizeAndValidateSavedRouteInput(input)
	if err != nil {
		return nil, err
	}

	route := &models.SavedRoute{
		UserID:      userID,
		Name:        input.Name,
		Origin:      input.Origin,
		Destination: input.Destination,
	}
	if err := s.repo.CreateRoute(ctx, route); err != nil {
		return nil, fmt.Errorf("create saved route: %w", err)
	}
	result := savedRouteResponse(*route)
	return &result, nil
}

func (s *savedRouteService) List(ctx context.Context, userID uint) ([]SavedRouteResponse, error) {
	if userID == 0 {
		return nil, ErrRouteUserRequired
	}
	routes, err := s.repo.FindRoutesByUserID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("find saved routes: %w", err)
	}
	result := make([]SavedRouteResponse, 0, len(routes))
	for _, route := range routes {
		result = append(result, savedRouteResponse(route))
	}
	return result, nil
}

func (s *savedRouteService) Update(ctx context.Context, userID, routeID uint, input SavedRouteInput) (*SavedRouteResponse, error) {
	if userID == 0 {
		return nil, ErrRouteUserRequired
	}
	if routeID == 0 {
		return nil, ErrInvalidRouteID
	}
	input, err := normalizeAndValidateSavedRouteInput(input)
	if err != nil {
		return nil, err
	}
	route := &models.SavedRoute{Name: input.Name, Origin: input.Origin, Destination: input.Destination}
	if err := s.repo.UpdateRoute(ctx, userID, routeID, route); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrRouteNotFound
		}
		return nil, fmt.Errorf("update saved route: %w", err)
	}
	result := savedRouteResponse(*route)
	return &result, nil
}

func (s *savedRouteService) Delete(ctx context.Context, userID, routeID uint) error {
	if userID == 0 {
		return ErrRouteUserRequired
	}
	if routeID == 0 {
		return ErrInvalidRouteID
	}
	if err := s.repo.DeleteRoute(ctx, userID, routeID); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrRouteNotFound
		}
		return fmt.Errorf("delete saved route: %w", err)
	}
	return nil
}

func normalizeAndValidateSavedRouteInput(input SavedRouteInput) (SavedRouteInput, error) {
	input.Name = strings.TrimSpace(input.Name)
	input.Origin = strings.TrimSpace(input.Origin)
	input.Destination = strings.TrimSpace(input.Destination)
	switch {
	case input.Name == "":
		return input, ErrRouteNameRequired
	case input.Origin == "":
		return input, ErrOriginRequired
	case input.Destination == "":
		return input, ErrDestinationRequired
	case utf8.RuneCountInString(input.Name) > 100:
		return input, ErrRouteNameTooLong
	case utf8.RuneCountInString(input.Origin) > 500:
		return input, ErrOriginTooLong
	case utf8.RuneCountInString(input.Destination) > 500:
		return input, ErrDestinationTooLong
	}
	return input, nil
}

func savedRouteResponse(route models.SavedRoute) SavedRouteResponse {
	return SavedRouteResponse{
		ID:          route.ID,
		Name:        route.Name,
		Origin:      route.Origin,
		Destination: route.Destination,
		CreatedAt:   route.CreatedAt.Format(time.RFC3339),
		UpdatedAt:   route.UpdatedAt.Format(time.RFC3339),
	}
}
