package route_test

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/RintaroNasu/routetap/api/internal/auth"
	"github.com/RintaroNasu/routetap/api/internal/handler"
	"github.com/RintaroNasu/routetap/api/internal/httpx"
	"github.com/RintaroNasu/routetap/api/internal/models"
	"github.com/RintaroNasu/routetap/api/internal/service"
	"github.com/RintaroNasu/routetap/api/route"
	"github.com/labstack/echo/v4"
	"github.com/stretchr/testify/require"
	"gorm.io/gorm"
)

type accountRepository struct {
	users     map[uint]models.User
	lookupErr error
}

func (r *accountRepository) CreateUser(context.Context, *models.User) error {
	return errors.New("not used")
}
func (r *accountRepository) FindUserByEmail(context.Context, string) (*models.User, error) {
	return nil, errors.New("not used")
}
func (r *accountRepository) FindUserByID(_ context.Context, id uint) (*models.User, error) {
	if r.lookupErr != nil {
		return nil, r.lookupErr
	}
	user, ok := r.users[id]
	if !ok {
		return nil, gorm.ErrRecordNotFound
	}
	return &user, nil
}
func (r *accountRepository) DeleteUser(_ context.Context, id uint) error {
	if _, ok := r.users[id]; !ok {
		return gorm.ErrRecordNotFound
	}
	delete(r.users, id)
	return nil
}

type savedRouteHandler struct{ calls int }

func (h *savedRouteHandler) handle(c echo.Context) error {
	h.calls++
	return c.NoContent(http.StatusOK)
}
func (h *savedRouteHandler) Create(c echo.Context) error { return h.handle(c) }
func (h *savedRouteHandler) List(c echo.Context) error   { return h.handle(c) }
func (h *savedRouteHandler) Update(c echo.Context) error { return h.handle(c) }
func (h *savedRouteHandler) Delete(c echo.Context) error { return h.handle(c) }

func accountServer(repo *accountRepository) (*echo.Echo, *auth.JWTManager, *savedRouteHandler) {
	e := echo.New()
	e.HTTPErrorHandler = httpx.HTTPErrorHandler(slog.New(slog.NewTextHandler(io.Discard, nil)))
	manager := auth.NewJWTManager("account-deletion-test-secret-only", time.Hour)
	routes := &savedRouteHandler{}
	route.Register(e, handler.NewAuthHandler(service.NewAuthService(repo, manager)), routes, auth.Middleware(manager, repo))
	return e, manager, routes
}

func accountRequest(e *echo.Echo, method, path, token, body string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
	if token != "" {
		req.Header.Set(echo.HeaderAuthorization, "Bearer "+token)
	}
	rec := httptest.NewRecorder()
	e.ServeHTTP(rec, req)
	return rec
}

func TestAccountDeletionBlocksOldTokenOnEveryProtectedRoute(t *testing.T) {
	repo := &accountRepository{users: map[uint]models.User{1: {ID: 1, Email: "a@example.com"}, 2: {ID: 2, Email: "b@example.com"}}}
	e, manager, routes := accountServer(repo)
	tokenA, err := manager.GenerateToken(1)
	require.NoError(t, err)
	tokenB, err := manager.GenerateToken(2)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, accountRequest(e, http.MethodGet, "/routes", tokenA, "").Code)
	rec := accountRequest(e, http.MethodDelete, "/me?user_id=2", tokenA, `{"user_id":2,"id":2}`)
	require.Equal(t, http.StatusNoContent, rec.Code)
	require.Empty(t, rec.Body.String())
	require.NotContains(t, repo.users, uint(1))
	require.Contains(t, repo.users, uint(2))
	for _, endpoint := range []struct{ method, path string }{
		{http.MethodGet, "/me"}, {http.MethodDelete, "/me"},
		{http.MethodPost, "/routes"}, {http.MethodGet, "/routes"},
		{http.MethodPut, "/routes/1"}, {http.MethodDelete, "/routes/1"},
	} {
		t.Run(endpoint.method+" "+endpoint.path, func(t *testing.T) {
			result := accountRequest(e, endpoint.method, endpoint.path, tokenA, "")
			require.Equal(t, http.StatusUnauthorized, result.Code)
			require.JSONEq(t, `{"error":{"code":"UNAUTHORIZED","message":"authenticated user no longer exists"}}`, result.Body.String())
		})
	}
	require.Equal(t, 1, routes.calls)
	require.Equal(t, http.StatusOK, accountRequest(e, http.MethodGet, "/me", tokenB, "").Code)
	require.Equal(t, http.StatusOK, accountRequest(e, http.MethodGet, "/routes", tokenB, "").Code)
}

func TestDeleteAccountAuthenticationFailures(t *testing.T) {
	for _, kind := range []string{"未認証", "不正JWT", "期限切れJWT", "DB接続エラー"} {
		t.Run(kind, func(t *testing.T) {
			repo := &accountRepository{users: map[uint]models.User{1: {ID: 1}}}
			e, manager, _ := accountServer(repo)
			token := ""
			switch kind {
			case "不正JWT":
				token = "invalid-token"
			case "期限切れJWT":
				expired := auth.NewJWTManager("account-deletion-test-secret-only", -time.Hour)
				var err error
				token, err = expired.GenerateToken(1)
				require.NoError(t, err)
			case "DB接続エラー":
				var err error
				token, err = manager.GenerateToken(1)
				require.NoError(t, err)
				repo.lookupErr = errors.New("private database details")
			}
			rec := accountRequest(e, http.MethodDelete, "/me", token, "")
			if kind == "DB接続エラー" {
				require.Equal(t, http.StatusInternalServerError, rec.Code)
				require.JSONEq(t, `{"error":{"code":"INTERNAL_ERROR","message":"internal server error"}}`, rec.Body.String())
			} else {
				require.Equal(t, http.StatusUnauthorized, rec.Code)
			}
			require.Contains(t, repo.users, uint(1))
		})
	}
}
