package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/RintaroNasu/routetap/api/cmd/migrate"
	"github.com/RintaroNasu/routetap/api/internal/auth"
	"github.com/RintaroNasu/routetap/api/internal/db"
	"github.com/RintaroNasu/routetap/api/internal/handler"
	"github.com/RintaroNasu/routetap/api/internal/httpx"
	"github.com/RintaroNasu/routetap/api/internal/logging"
	"github.com/RintaroNasu/routetap/api/internal/repository"
	"github.com/RintaroNasu/routetap/api/internal/service"
	"github.com/RintaroNasu/routetap/api/route"

	"github.com/labstack/echo/v4"
	"gorm.io/gorm"
)

func main() {
	slog.SetDefault(logging.New())
	if err := run(); err != nil {
		slog.Error("server stopped", "error", err)
		os.Exit(1)
	}
}

func run() error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	conn, err := db.New()
	if err != nil {
		return fmt.Errorf("failed to connect to database: %w", err)
	}
	defer func() {
		if err := db.CloseDB(conn); err != nil {
			slog.Error("failed to close database", "error", err)
		}
	}()
	secret := strings.TrimSpace(os.Getenv("JWT_SECRET"))
	if len(secret) < 32 {
		return errors.New("JWT_SECRET must contain at least 32 bytes")
	}
	if err := migrate.Migrate(conn); err != nil {
		return fmt.Errorf("database migration failed: %w", err)
	}

	e := newServer(conn, secret)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	go func() {
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := e.Shutdown(shutdownCtx); err != nil {
			slog.Error("failed to shut down server", "error", err)
		}
	}()
	slog.Info("server starting", "addr", ":"+port)
	if err := e.Start(":" + port); err != nil && !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	slog.Info("server stopped")
	return nil
}

func newServer(conn *gorm.DB, secret string) *echo.Echo {
	e := echo.New()
	e.HideBanner = true
	e.HidePort = true
	e.HTTPErrorHandler = httpx.HTTPErrorHandler(slog.Default())
	e.Use(httpx.RecoverMiddleware())
	jwtManager := auth.NewJWTManager(secret, time.Hour)
	authRepository := repository.NewAuthRepository(conn)
	authService := service.NewAuthService(authRepository, jwtManager)
	savedRouteRepository := repository.NewSavedRouteRepository(conn)
	savedRouteService := service.NewSavedRouteService(savedRouteRepository)
	route.Register(e, handler.NewAuthHandler(authService), handler.NewSavedRouteHandler(savedRouteService), auth.Middleware(jwtManager))

	return e
}
