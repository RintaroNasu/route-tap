package handler_test

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
	"github.com/RintaroNasu/routetap/api/internal/service"
	"github.com/RintaroNasu/routetap/api/route"
	"github.com/labstack/echo/v4"
	"github.com/stretchr/testify/require"
)

type fakeSavedRouteService struct {
	create func(context.Context, uint, service.CreateSavedRouteInput) (*service.SavedRouteResponse, error)
	list   func(context.Context, uint) ([]service.SavedRouteResponse, error)
}

func (f *fakeSavedRouteService) Create(ctx context.Context, userID uint, input service.CreateSavedRouteInput) (*service.SavedRouteResponse, error) {
	return f.create(ctx, userID, input)
}

func (f *fakeSavedRouteService) List(ctx context.Context, userID uint) ([]service.SavedRouteResponse, error) {
	return f.list(ctx, userID)
}

func savedRouteServer(svc service.SavedRouteService) (*echo.Echo, *auth.JWTManager) {
	e := echo.New()
	e.HTTPErrorHandler = httpx.HTTPErrorHandler(slog.New(slog.NewTextHandler(io.Discard, nil)))
	jwtManager := auth.NewJWTManager("test-secret-at-least-32-characters", time.Hour)
	route.Register(e, handler.NewAuthHandler(nil), handler.NewSavedRouteHandler(svc), auth.Middleware(jwtManager))
	return e, jwtManager
}

func routeRequest(t *testing.T, e *echo.Echo, manager *auth.JWTManager, method, path, body string) *httptest.ResponseRecorder {
	t.Helper()
	token, err := manager.GenerateToken(7)
	require.NoError(t, err)
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
	req.Header.Set(echo.HeaderAuthorization, "Bearer "+token)
	rec := httptest.NewRecorder()
	e.ServeHTTP(rec, req)
	return rec
}

func TestSavedRouteHandler_Create(t *testing.T) {
	t.Run("【正常系】POSTで201を返しbodyの他人のユーザーIDは無視する", func(t *testing.T) {
		svc := &fakeSavedRouteService{create: func(_ context.Context, userID uint, input service.CreateSavedRouteInput) (*service.SavedRouteResponse, error) {
			require.Equal(t, uint(7), userID)
			require.Equal(t, service.CreateSavedRouteInput{Name: "通勤", Origin: "大井町駅", Destination: "浜松町駅"}, input)
			return &service.SavedRouteResponse{ID: 12, Name: input.Name, Origin: input.Origin, Destination: input.Destination,
				CreatedAt: "2026-11-03T18:03:00+09:00", UpdatedAt: "2026-11-03T18:03:00+09:00"}, nil
		}}
		e, manager := savedRouteServer(svc)
		rec := routeRequest(t, e, manager, http.MethodPost, "/routes", `{"name":"通勤","origin":"大井町駅","destination":"浜松町駅","user_id":999}`)
		require.Equal(t, http.StatusCreated, rec.Code)
		require.JSONEq(t, `{"id":12,"name":"通勤","origin":"大井町駅","destination":"浜松町駅","created_at":"2026-11-03T18:03:00+09:00","updated_at":"2026-11-03T18:03:00+09:00"}`, rec.Body.String())
	})
	t.Run("【異常系】JSON不正はサービスを呼ばず400にする", func(t *testing.T) {
		e, manager := savedRouteServer(&fakeSavedRouteService{})
		rec := routeRequest(t, e, manager, http.MethodPost, "/routes", `{"name":`)
		require.Equal(t, http.StatusBadRequest, rec.Code)
		require.Contains(t, rec.Body.String(), "INVALID_REQUEST")
	})
	tests := []struct {
		name    string
		err     error
		status  int
		code    string
		message string
	}{
		{"表示名必須", service.ErrRouteNameRequired, 400, "INVALID_REQUEST", "name is required"},
		{"出発地必須", service.ErrOriginRequired, 400, "INVALID_REQUEST", "origin is required"},
		{"目的地必須", service.ErrDestinationRequired, 400, "INVALID_REQUEST", "destination is required"},
		{"表示名の上限", service.ErrRouteNameTooLong, 400, "INVALID_REQUEST", "name must be 100 characters or fewer"},
		{"出発地の上限", service.ErrOriginTooLong, 400, "INVALID_REQUEST", "origin must be 500 characters or fewer"},
		{"目的地の上限", service.ErrDestinationTooLong, 400, "INVALID_REQUEST", "destination must be 500 characters or fewer"},
		{"認証ユーザーなし", service.ErrRouteUserRequired, 401, "UNAUTHORIZED", "authenticated user is required"},
		{"内部エラー", errors.New("private database details"), 500, "INTERNAL_ERROR", "internal server error"},
	}
	for _, tt := range tests {
		t.Run("【異常系】"+tt.name, func(t *testing.T) {
			svc := &fakeSavedRouteService{create: func(context.Context, uint, service.CreateSavedRouteInput) (*service.SavedRouteResponse, error) {
				return nil, tt.err
			}}
			e, manager := savedRouteServer(svc)
			rec := routeRequest(t, e, manager, http.MethodPost, "/routes", `{"name":"通勤","origin":"大井町駅","destination":"浜松町駅"}`)
			require.Equal(t, tt.status, rec.Code)
			require.JSONEq(t, `{"error":{"code":"`+tt.code+`","message":"`+tt.message+`"}}`, rec.Body.String())
		})
	}
}

func TestSavedRouteHandler_List(t *testing.T) {
	t.Run("【正常系】GETで200と一覧を返しqueryの他人のユーザーIDは無視する", func(t *testing.T) {
		svc := &fakeSavedRouteService{list: func(_ context.Context, userID uint) ([]service.SavedRouteResponse, error) {
			require.Equal(t, uint(7), userID)
			return []service.SavedRouteResponse{{ID: 12, Name: "通勤", Origin: "大井町駅", Destination: "浜松町駅",
				CreatedAt: "2026-11-03T18:03:00+09:00", UpdatedAt: "2026-11-03T18:03:00+09:00"}}, nil
		}}
		e, manager := savedRouteServer(svc)
		rec := routeRequest(t, e, manager, http.MethodGet, "/routes?user_id=999", "")
		require.Equal(t, http.StatusOK, rec.Code)
		require.JSONEq(t, `[{"id":12,"name":"通勤","origin":"大井町駅","destination":"浜松町駅","created_at":"2026-11-03T18:03:00+09:00","updated_at":"2026-11-03T18:03:00+09:00"}]`, rec.Body.String())
	})
	t.Run("【正常系】未登録なら空配列を返す", func(t *testing.T) {
		svc := &fakeSavedRouteService{list: func(context.Context, uint) ([]service.SavedRouteResponse, error) {
			return []service.SavedRouteResponse{}, nil
		}}
		e, manager := savedRouteServer(svc)
		rec := routeRequest(t, e, manager, http.MethodGet, "/routes", "")
		require.Equal(t, http.StatusOK, rec.Code)
		require.JSONEq(t, "[]", rec.Body.String())
	})
	t.Run("【異常系】内部エラーの詳細を公開しない", func(t *testing.T) {
		svc := &fakeSavedRouteService{list: func(context.Context, uint) ([]service.SavedRouteResponse, error) {
			return nil, errors.New("private database details")
		}}
		e, manager := savedRouteServer(svc)
		rec := routeRequest(t, e, manager, http.MethodGet, "/routes", "")
		require.Equal(t, http.StatusInternalServerError, rec.Code)
		require.JSONEq(t, `{"error":{"code":"INTERNAL_ERROR","message":"internal server error"}}`, rec.Body.String())
	})
}

func TestSavedRouteHandler_Authentication(t *testing.T) {
	for _, method := range []string{http.MethodPost, http.MethodGet} {
		for _, kind := range []string{"未認証", "不正トークン", "期限切れ"} {
			t.Run("【異常系】"+method+"/"+kind+"は401を返す", func(t *testing.T) {
				e, _ := savedRouteServer(&fakeSavedRouteService{})
				req := httptest.NewRequest(method, "/routes", nil)
				switch kind {
				case "不正トークン":
					req.Header.Set(echo.HeaderAuthorization, "Bearer invalid-token")
				case "期限切れ":
					manager := auth.NewJWTManager("test-secret-at-least-32-characters", -time.Hour)
					token, err := manager.GenerateToken(7)
					require.NoError(t, err)
					req.Header.Set(echo.HeaderAuthorization, "Bearer "+token)
				}
				rec := httptest.NewRecorder()
				e.ServeHTTP(rec, req)
				require.Equal(t, http.StatusUnauthorized, rec.Code)
			})
		}
	}
	t.Run("【異常系】middlewareなしでハンドラーを呼んでも未認証なら拒否する", func(t *testing.T) {
		for _, method := range []string{http.MethodPost, http.MethodGet} {
			e := echo.New()
			e.HTTPErrorHandler = httpx.HTTPErrorHandler(slog.New(slog.NewTextHandler(io.Discard, nil)))
			h := handler.NewSavedRouteHandler(&fakeSavedRouteService{})
			e.POST("/routes", h.Create)
			e.GET("/routes", h.List)
			rec := httptest.NewRecorder()
			e.ServeHTTP(rec, httptest.NewRequest(method, "/routes", nil))
			require.Equal(t, http.StatusUnauthorized, rec.Code)
		}
	})
}
