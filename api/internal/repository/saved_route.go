package repository

import (
	"context"

	"github.com/RintaroNasu/routetap/api/internal/models"
	"gorm.io/gorm"
)

type SavedRouteRepository interface {
	CreateRoute(ctx context.Context, route *models.SavedRoute) error
	FindRoutesByUserID(ctx context.Context, userID uint) ([]models.SavedRoute, error)
}

type savedRouteRepository struct {
	db *gorm.DB
}

func NewSavedRouteRepository(db *gorm.DB) SavedRouteRepository {
	return &savedRouteRepository{db: db}
}

func (r *savedRouteRepository) CreateRoute(ctx context.Context, route *models.SavedRoute) error {
	return r.db.WithContext(ctx).Create(route).Error
}

func (r *savedRouteRepository) FindRoutesByUserID(ctx context.Context, userID uint) ([]models.SavedRoute, error) {
	var routes []models.SavedRoute
	err := r.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("created_at DESC").Order("id DESC").
		Find(&routes).Error
	return routes, err
}
