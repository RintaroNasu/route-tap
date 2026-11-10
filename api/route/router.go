package route

import (
	"github.com/RintaroNasu/routetap/api/internal/handler"
	"github.com/labstack/echo/v4"
)

func Register(e *echo.Echo, authHandler handler.AuthHandler, savedRouteHandler handler.SavedRouteHandler, authMiddleware echo.MiddlewareFunc) {
	e.POST("/signup", authHandler.Signup)
	e.POST("/login", authHandler.Login)
	e.GET("/me", authHandler.Me, authMiddleware)
	e.DELETE("/me", authHandler.DeleteAccount, authMiddleware)
	e.POST("/routes", savedRouteHandler.Create, authMiddleware)
	e.GET("/routes", savedRouteHandler.List, authMiddleware)
	e.PUT("/routes/:id", savedRouteHandler.Update, authMiddleware)
	e.DELETE("/routes/:id", savedRouteHandler.Delete, authMiddleware)
}
