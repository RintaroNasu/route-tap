package models

import "time"

type SavedRoute struct {
	ID          uint   `gorm:"primaryKey"`
	UserID      uint   `gorm:"not null;index"`
	Name        string `gorm:"type:varchar(100);not null"`
	Origin      string `gorm:"type:varchar(500);not null"`
	Destination string `gorm:"type:varchar(500);not null"`
	CreatedAt   time.Time
	UpdatedAt   time.Time
}
