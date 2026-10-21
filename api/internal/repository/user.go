package repository

import (
	"context"
	"strings"

	"github.com/RintaroNasu/routetap/api/internal/models"
	"gorm.io/gorm"
)

type UserRepository interface {
	CreateUser(ctx context.Context, user *models.User) error
}

type userRepository struct {
	db *gorm.DB
}

func NewUserRepository(db *gorm.DB) UserRepository {
	return &userRepository{db: db}
}

// CreateUser expects an already hashed password. Registration validation and
// password hashing will be implemented in the service layer in the next step.
func (r *userRepository) CreateUser(ctx context.Context, user *models.User) error {
	user.Email = strings.ToLower(strings.TrimSpace(user.Email))
	return r.db.WithContext(ctx).Create(user).Error
}
