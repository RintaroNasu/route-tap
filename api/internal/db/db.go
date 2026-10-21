package db

import (
	"context"
	"errors"
	"net"
	"net/url"
	"os"
	"time"

	"github.com/joho/godotenv"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func New() (*gorm.DB, error) {
	_ = godotenv.Load()
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		for _, key := range []string{"POSTGRES_USER", "POSTGRES_PASSWORD", "POSTGRES_HOST", "POSTGRES_PORT", "POSTGRES_DB"} {
			if os.Getenv(key) == "" {
				return nil, errors.New("set DATABASE_URL or all POSTGRES_* connection variables")
			}
		}
		connectionURL := url.URL{
			Scheme: "postgres",
			User:   url.UserPassword(os.Getenv("POSTGRES_USER"), os.Getenv("POSTGRES_PASSWORD")),
			Host:   net.JoinHostPort(os.Getenv("POSTGRES_HOST"), os.Getenv("POSTGRES_PORT")),
			Path:   "/" + os.Getenv("POSTGRES_DB"),
		}
		query := connectionURL.Query()
		if mode := os.Getenv("POSTGRES_SSLMODE"); mode != "" {
			query.Set("sslmode", mode)
		}
		connectionURL.RawQuery = query.Encode()
		dsn = connectionURL.String()
	}

	conn, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		TranslateError:       true,
		DisableAutomaticPing: true,
		// SQL logs can expose email addresses and password hashes.
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		return nil, errors.New("invalid database connection configuration")
	}
	sqlDB, err := conn.DB()
	if err != nil {
		return nil, errors.New("failed to initialize database connection pool")
	}
	sqlDB.SetMaxOpenConns(5)
	sqlDB.SetMaxIdleConns(2)
	sqlDB.SetConnMaxIdleTime(time.Minute)
	sqlDB.SetConnMaxLifetime(30 * time.Minute)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := sqlDB.PingContext(ctx); err != nil {
		sqlDB.Close()
		return nil, errors.New("database connection failed; check connection settings and database availability")
	}
	return conn, nil
}

func CloseDB(conn *gorm.DB) error {
	sqlDB, err := conn.DB()
	if err != nil {
		return err
	}
	return sqlDB.Close()
}
