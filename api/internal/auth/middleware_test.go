package auth

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/RintaroNasu/routetap/api/internal/httpx"
	"github.com/RintaroNasu/routetap/api/internal/models"
	"github.com/labstack/echo/v4"
	"github.com/stretchr/testify/require"
	"gorm.io/gorm"
)

type fakeUserFinder struct {
	find  func(context.Context, uint) (*models.User, error)
	calls int
}

func (f *fakeUserFinder) FindUserByID(ctx context.Context, userID uint) (*models.User, error) {
	f.calls++
	if f.find != nil {
		return f.find(ctx, userID)
	}
	return &models.User{ID: userID}, nil
}

func TestMiddleware(t *testing.T) {
	secret := "test-secret"
	validManager := NewJWTManager(secret, time.Hour)
	validToken, err := validManager.GenerateToken(1)
	require.NoError(t, err)

	expiredManager := NewJWTManager(secret, -time.Minute)
	expiredToken, err := expiredManager.GenerateToken(1)
	require.NoError(t, err)

	tests := []struct {
		name             string
		authHeader       string
		wantAppError     *httpx.AppError
		wantNextCalled   bool
		wantUserID       uint
		wantUserIDExists bool
	}{
		{
			name:         "【異常系】Authorizationヘッダーがない場合は401を返すこと",
			wantAppError: httpx.Unauthorized("authorization header is required", errors.New("authorization header is missing")),
		},
		{
			name:         "【異常系】Bearer形式不正の場合は401を返すこと",
			authHeader:   "invalid-token",
			wantAppError: httpx.Unauthorized("bearer token is required", errors.New("bearer token is missing")),
		},
		{
			name:         "【異常系】不正tokenの場合は401を返すこと",
			authHeader:   "Bearer invalid-token",
			wantAppError: httpx.Unauthorized("invalid token", errors.New("invalid token")),
		},
		{
			name:         "【異常系】期限切れtokenの場合は401を返すこと",
			authHeader:   "Bearer " + expiredToken,
			wantAppError: httpx.Unauthorized("token has expired", errors.New("token expired")),
		},
		{
			name:             "【正常系】正常tokenの場合はnextが呼ばれuserIDをcontextから取得できること",
			authHeader:       "Bearer " + validToken,
			wantNextCalled:   true,
			wantUserID:       1,
			wantUserIDExists: true,
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			e := echo.New()
			req := httptest.NewRequest(http.MethodGet, "/me", nil)
			if tt.authHeader != "" {
				req.Header.Set("Authorization", tt.authHeader)
			}
			rec := httptest.NewRecorder()
			c := e.NewContext(req, rec)

			nextCalled := false
			var gotUserID uint
			var gotUserIDExists bool

			users := &fakeUserFinder{}
			h := Middleware(validManager, users)(func(c echo.Context) error {
				nextCalled = true
				gotUserID, gotUserIDExists = UserIDFromContext(c)
				return c.NoContent(http.StatusNoContent)
			})

			err := h(c)

			if tt.wantAppError != nil {
				require.Error(t, err)
				appErr, ok := err.(*httpx.AppError)
				require.True(t, ok)
				require.Equal(t, tt.wantAppError.Status, appErr.Status)
				require.Equal(t, tt.wantAppError.Code, appErr.Code)
				require.Equal(t, tt.wantAppError.Message, appErr.Message)
				require.False(t, nextCalled)
				require.Zero(t, users.calls)
				return
			}

			require.NoError(t, err)
			require.True(t, nextCalled)
			require.Equal(t, 1, users.calls)
			require.Equal(t, http.StatusNoContent, rec.Code)
			require.Equal(t, tt.wantUserIDExists, gotUserIDExists)
			require.Equal(t, tt.wantUserID, gotUserID)
		})
	}
}

func TestUserIDFromContext(t *testing.T) {
	tests := []struct {
		name       string
		setUserID  bool
		userID     uint
		wantUserID uint
		wantOK     bool
	}{
		{
			name:       "【正常系】userIDが格納されている場合は取得できること",
			setUserID:  true,
			userID:     10,
			wantUserID: 10,
			wantOK:     true,
		},
		{
			name:   "【異常系】userIDが格納されていない場合はfalseを返すこと",
			wantOK: false,
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			e := echo.New()
			req := httptest.NewRequest(http.MethodGet, "/me", nil)
			rec := httptest.NewRecorder()
			c := e.NewContext(req, rec)

			if tt.setUserID {
				c.Set(userIDContextKey, tt.userID)
			}

			got, ok := UserIDFromContext(c)

			require.Equal(t, tt.wantOK, ok)
			require.Equal(t, tt.wantUserID, got)
		})
	}
}

func TestMiddleware_UserLookup(t *testing.T) {
	manager := NewJWTManager("test-secret", time.Hour)
	token, err := manager.GenerateToken(7)
	require.NoError(t, err)
	dbErr := errors.New("database unavailable")
	for _, tt := range []struct {
		name      string
		user      *models.User
		lookupErr error
		status    int
	}{
		{"削除済みユーザー", nil, gorm.ErrRecordNotFound, 401},
		{"DB接続エラー", nil, dbErr, 500},
		{"ユーザーが返らない", nil, nil, 401},
		{"別のユーザーが返る", &models.User{ID: 8}, nil, 401},
	} {
		t.Run("【異常系】"+tt.name+"では後続を実行しない", func(t *testing.T) {
			users := &fakeUserFinder{find: func(ctx context.Context, id uint) (*models.User, error) {
				require.Equal(t, uint(7), id)
				return tt.user, tt.lookupErr
			}}
			e := echo.New()
			req := httptest.NewRequest(http.MethodGet, "/routes", nil)
			req.Header.Set(echo.HeaderAuthorization, "Bearer "+token)
			c := e.NewContext(req, httptest.NewRecorder())
			nextCalled := false
			err := Middleware(manager, users)(func(echo.Context) error { nextCalled = true; return nil })(c)
			var appErr *httpx.AppError
			require.ErrorAs(t, err, &appErr)
			require.Equal(t, tt.status, appErr.Status)
			require.False(t, nextCalled)
			_, ok := UserIDFromContext(c)
			require.False(t, ok)
			require.Equal(t, 1, users.calls)
			if tt.lookupErr == dbErr {
				require.ErrorIs(t, appErr, dbErr)
			}
		})
	}
}
