package handler

import (
	"errors"
	"net/http"

	"github.com/RintaroNasu/routetap/api/internal/auth"
	"github.com/RintaroNasu/routetap/api/internal/httpx"
	"github.com/RintaroNasu/routetap/api/internal/service"
	"github.com/labstack/echo/v4"
)

type SavedRouteHandler interface {
	Create(c echo.Context) error
	List(c echo.Context) error
}

type savedRouteHandler struct {
	routeService service.SavedRouteService
}

type createSavedRouteRequest struct {
	Name        string `json:"name"`
	Origin      string `json:"origin"`
	Destination string `json:"destination"`
}

func NewSavedRouteHandler(routeService service.SavedRouteService) SavedRouteHandler {
	return &savedRouteHandler{routeService: routeService}
}

func (h *savedRouteHandler) Create(c echo.Context) error {
	userID, ok := auth.UserIDFromContext(c)
	if !ok || userID == 0 {
		return respondSavedRouteError(service.ErrRouteUserRequired)
	}
	var req createSavedRouteRequest
	if err := c.Bind(&req); err != nil {
		return httpx.InvalidRequest("invalid request body", err)
	}
	result, err := h.routeService.Create(c.Request().Context(), userID, service.CreateSavedRouteInput{
		Name:        req.Name,
		Origin:      req.Origin,
		Destination: req.Destination,
	})
	if err != nil {
		return respondSavedRouteError(err)
	}
	return c.JSON(http.StatusCreated, result)
}

func (h *savedRouteHandler) List(c echo.Context) error {
	userID, ok := auth.UserIDFromContext(c)
	if !ok || userID == 0 {
		return respondSavedRouteError(service.ErrRouteUserRequired)
	}
	result, err := h.routeService.List(c.Request().Context(), userID)
	if err != nil {
		return respondSavedRouteError(err)
	}
	return c.JSON(http.StatusOK, result)
}

func respondSavedRouteError(err error) error {
	switch {
	case errors.Is(err, service.ErrRouteUserRequired):
		return httpx.Unauthorized("authenticated user is required", err)
	case errors.Is(err, service.ErrRouteNameRequired),
		errors.Is(err, service.ErrOriginRequired),
		errors.Is(err, service.ErrDestinationRequired),
		errors.Is(err, service.ErrRouteNameTooLong),
		errors.Is(err, service.ErrOriginTooLong),
		errors.Is(err, service.ErrDestinationTooLong):
		return httpx.InvalidRequest(err.Error(), err)
	default:
		return httpx.Internal("internal server error", err)
	}
}
