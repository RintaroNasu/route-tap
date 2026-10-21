package migrate

import (
	"context"
	"time"

	"github.com/RintaroNasu/routetap/api/internal/models"
	"gorm.io/gorm"
)

func Migrate(conn *gorm.DB) error {
	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	defer cancel()
	return conn.WithContext(ctx).AutoMigrate(&models.User{})
}
