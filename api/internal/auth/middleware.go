package auth

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/RintaroNasu/routetap/api/internal/httpx"
	"github.com/RintaroNasu/routetap/api/internal/models"
	"github.com/golang-jwt/jwt/v5"
	"github.com/labstack/echo/v4"
	"gorm.io/gorm"
)

const userIDContextKey = "auth_user_id"

type userFinder interface {
	FindUserByID(ctx context.Context, userID uint) (*models.User, error)
}

func Middleware(jwtManager *JWTManager, users userFinder) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			authHeader := c.Request().Header.Get("Authorization")
			if authHeader == "" {
				return httpx.Unauthorized("authorization header is required", errors.New("authorization header is missing"))
			}

			token := strings.TrimSpace(strings.TrimPrefix(authHeader, "Bearer "))
			if token == "" || token == authHeader {
				return httpx.Unauthorized("bearer token is required", errors.New("bearer token is missing"))
			}

			userID, err := jwtManager.ParseToken(token)
			if err != nil {
				switch {
				case errors.Is(err, jwt.ErrTokenExpired):
					return httpx.Unauthorized("token has expired", err)
				default:
					return httpx.Unauthorized("invalid token", err)
				}
			}

			user, err := users.FindUserByID(c.Request().Context(), userID)
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return httpx.Unauthorized("authenticated user no longer exists", err)
			}
			if err != nil {
				return httpx.Internal("internal server error", fmt.Errorf("find authenticated user: %w", err))
			}
			if user == nil || user.ID != userID {
				return httpx.Unauthorized("authenticated user no longer exists", errors.New("authenticated user was not found"))
			}

			c.Set(userIDContextKey, userID)
			return next(c)
		}
	}
}

func UserIDFromContext(c echo.Context) (uint, bool) {
	userID, ok := c.Get(userIDContextKey).(uint)
	return userID, ok
}
