package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/RintaroNasu/routetap/api/cmd/migrate"
	"github.com/RintaroNasu/routetap/api/internal/db"
	"github.com/RintaroNasu/routetap/api/internal/handler"
	"github.com/RintaroNasu/routetap/api/route"

	"github.com/labstack/echo/v4"
)

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}

func run() error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	conn, err := db.New()
	if err != nil {
		return err
	}
	defer db.CloseDB(conn)
	if err := migrate.Migrate(conn); err != nil {
		return fmt.Errorf("database migration failed: %w", err)
	}

	e := echo.New()
	route.Register(e, handler.NewHealthHandler(conn))

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	go func() {
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := e.Shutdown(shutdownCtx); err != nil {
			e.Logger.Error(err)
		}
	}()
	if err := e.Start(":" + port); err != nil && !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	return nil
}
