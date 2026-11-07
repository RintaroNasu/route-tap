package handler

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/RintaroNasu/routetap/api/internal/auth"
	"github.com/RintaroNasu/routetap/api/internal/httpx"
	"github.com/RintaroNasu/routetap/api/internal/service"
	"github.com/labstack/echo/v4"
)

type SavedRouteHandler interface {
	Create(c echo.Context) error
	List(c echo.Context) error
	Update(c echo.Context) error
	Delete(c echo.Context) error
}

type savedRouteHandler struct {
	routeService service.SavedRouteService
}

type savedRouteRequest struct {
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
	var req savedRouteRequest
	if err := c.Bind(&req); err != nil {
		return httpx.InvalidRequest("invalid request body", err)
	}
	result, err := h.routeService.Create(c.Request().Context(), userID, service.SavedRouteInput{
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

func (h *savedRouteHandler) Update(c echo.Context) error {
	userID, ok := auth.UserIDFromContext(c)
	if !ok || userID == 0 {
		return respondSavedRouteError(service.ErrRouteUserRequired)
	}
	routeID, err := savedRouteID(c)
	if err != nil {
		return respondSavedRouteError(err)
	}
	var req savedRouteRequest
	if err := c.Bind(&req); err != nil {
		return httpx.InvalidRequest("invalid request body", err)
	}
	result, err := h.routeService.Update(c.Request().Context(), userID, routeID, service.SavedRouteInput{
		Name: req.Name, Origin: req.Origin, Destination: req.Destination,
	})
	if err != nil {
		return respondSavedRouteError(err)
	}
	return c.JSON(http.StatusOK, result)
}

func (h *savedRouteHandler) Delete(c echo.Context) error {
	userID, ok := auth.UserIDFromContext(c)
	if !ok || userID == 0 {
		return respondSavedRouteError(service.ErrRouteUserRequired)
	}
	routeID, err := savedRouteID(c)
	if err != nil {
		return respondSavedRouteError(err)
	}
	if err := h.routeService.Delete(c.Request().Context(), userID, routeID); err != nil {
		return respondSavedRouteError(err)
	}
	return c.NoContent(http.StatusNoContent)
}

func savedRouteID(c echo.Context) (uint, error) {
	// PostgreSQLのBIGINTに収まる正の整数のみ受け付ける。
	id, err := strconv.ParseUint(c.Param("id"), 10, 63)
	if err != nil || id == 0 {
		return 0, service.ErrInvalidRouteID
	}
	return uint(id), nil
}

func respondSavedRouteError(err error) error {
	switch {
	case errors.Is(err, service.ErrRouteNotFound):
		return httpx.NotFound("route not found", err)
	case errors.Is(err, service.ErrInvalidRouteID):
		return httpx.InvalidRequest("route id must be a positive integer", err)
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
