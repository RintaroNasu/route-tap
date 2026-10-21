package models

import "time"

type User struct {
	ID           uint   `gorm:"primaryKey"`
	Email        string `gorm:"not null;uniqueIndex;check:email_normalized,email = lower(btrim(email)) AND email <> ''"`
	PasswordHash string `gorm:"not null;check:password_hash_not_empty,password_hash <> ''" json:"-"`
	CreatedAt    time.Time
	UpdatedAt    time.Time
}
