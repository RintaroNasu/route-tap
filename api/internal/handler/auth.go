package handler

import (
	"errors"
	"net/http"

	"github.com/RintaroNasu/routetap/api/internal/auth"
	"github.com/RintaroNasu/routetap/api/internal/httpx"
	"github.com/RintaroNasu/routetap/api/internal/service"
	"github.com/labstack/echo/v4"
)

type AuthHandler interface {
	Signup(c echo.Context) error
	Login(c echo.Context) error
	Me(c echo.Context) error
	DeleteAccount(c echo.Context) error
}

type authHandler struct {
	authService service.AuthService
}

type signupRequest struct {
	Name     string `json:"name"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func NewAuthHandler(authService service.AuthService) AuthHandler {
	return &authHandler{authService: authService}
}

func (h *authHandler) Signup(c echo.Context) error {
	var req signupRequest
	if err := c.Bind(&req); err != nil {
		return httpx.InvalidRequest("invalid request body", err)
	}

	result, err := h.authService.Signup(c.Request().Context(), service.SignupInput{
		Name:     req.Name,
		Email:    req.Email,
		Password: req.Password,
	})
	if err != nil {
		return respondAuthError(err)
	}

	return c.JSON(201, result)
}

func (h *authHandler) Login(c echo.Context) error {
	var req loginRequest
	if err := c.Bind(&req); err != nil {
		return httpx.InvalidRequest("invalid request body", err)
	}

	result, err := h.authService.Login(c.Request().Context(), service.LoginInput{
		Email:    req.Email,
		Password: req.Password,
	})
	if err != nil {
		return respondAuthError(err)
	}

	return c.JSON(200, result)
}

func (h *authHandler) Me(c echo.Context) error {
	userID, ok := auth.UserIDFromContext(c)
	if !ok || userID == 0 {
		return httpx.Unauthorized("authenticated user is required", errors.New("authenticated user is missing from context"))
	}

	result, err := h.authService.Me(c.Request().Context(), userID)
	if err != nil {
		return respondAuthError(err)
	}

	return c.JSON(200, result)
}

func (h *authHandler) DeleteAccount(c echo.Context) error {
	userID, ok := auth.UserIDFromContext(c)
	if !ok || userID == 0 {
		return httpx.Unauthorized("authenticated user is required", errors.New("authenticated user is missing from context"))
	}
	if err := h.authService.DeleteAccount(c.Request().Context(), userID); err != nil {
		return respondAuthError(err)
	}
	return c.NoContent(http.StatusNoContent)
}

func respondAuthError(err error) error {
	switch {
	case errors.Is(err, service.ErrEmailRequired):
		return httpx.InvalidRequest("email is required", err)
	case errors.Is(err, service.ErrPasswordRequired):
		return httpx.InvalidRequest("password is required", err)
	case errors.Is(err, service.ErrInvalidEmailFormat):
		return httpx.InvalidRequest("email format is invalid", err)
	case errors.Is(err, service.ErrEmailAlreadyExists):
		return httpx.Conflict("email already exists", err)
	case errors.Is(err, service.ErrInvalidCredentials):
		return httpx.Unauthorized("email or password is incorrect", err)
	case errors.Is(err, service.ErrUserNotFound):
		return httpx.Unauthorized("authenticated user no longer exists", err)
	default:
		return httpx.Internal("internal server error", err)
	}
}
