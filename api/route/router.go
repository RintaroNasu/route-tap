package route

import (
	"github.com/RintaroNasu/routetap/api/internal/handler"
	"github.com/labstack/echo/v4"
)

func Register(e *echo.Echo, healthHandler *handler.HealthHandler) {
	e.GET("/health", healthHandler.Health)
	e.GET("/ready", healthHandler.Ready)
}
