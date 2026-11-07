package repository

import (
	"context"

	"github.com/RintaroNasu/routetap/api/internal/models"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type SavedRouteRepository interface {
	CreateRoute(ctx context.Context, route *models.SavedRoute) error
	FindRoutesByUserID(ctx context.Context, userID uint) ([]models.SavedRoute, error)
	UpdateRoute(ctx context.Context, userID, routeID uint, route *models.SavedRoute) error
	DeleteRoute(ctx context.Context, userID, routeID uint) error
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

func (r *savedRouteRepository) UpdateRoute(ctx context.Context, userID, routeID uint, route *models.SavedRoute) error {
	result := r.db.WithContext(ctx).Model(route).
		Clauses(clause.Returning{}).
		Where("id = ? AND user_id = ?", routeID, userID).
		Updates(map[string]any{
			"name":        route.Name,
			"origin":      route.Origin,
			"destination": route.Destination,
		})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

func (r *savedRouteRepository) DeleteRoute(ctx context.Context, userID, routeID uint) error {
	result := r.db.WithContext(ctx).
		Where("id = ? AND user_id = ?", routeID, userID).
		Delete(&models.SavedRoute{})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}
