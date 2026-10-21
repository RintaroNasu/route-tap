package handler

import (
	"context"
	"net/http"
	"time"

	"github.com/labstack/echo/v4"
	"gorm.io/gorm"
)

type HealthHandler struct {
	db *gorm.DB
}

func NewHealthHandler(db *gorm.DB) *HealthHandler {
	return &HealthHandler{db: db}
}

func (h *HealthHandler) Health(c echo.Context) error {
	return c.JSON(http.StatusOK, map[string]string{"status": "ok"})
}

func (h *HealthHandler) Ready(c echo.Context) error {
	ctx, cancel := context.WithTimeout(c.Request().Context(), 3*time.Second)
	defer cancel()
	sqlDB, err := h.db.DB()
	if err != nil || sqlDB.PingContext(ctx) != nil {
		return c.JSON(http.StatusServiceUnavailable, map[string]string{"status": "unavailable"})
	}
	return c.JSON(http.StatusOK, map[string]string{"status": "ok"})
}
