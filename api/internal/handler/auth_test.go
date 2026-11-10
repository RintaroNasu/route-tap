package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/RintaroNasu/routetap/api/internal/httpx"
	"github.com/RintaroNasu/routetap/api/internal/service"
	"github.com/labstack/echo/v4"
	"github.com/stretchr/testify/require"
)

const authUserIDContextKey = "auth_user_id"

type fakeAuthService struct {
	signupFunc        func(ctx context.Context, input service.SignupInput) (*service.AuthResponse, error)
	loginFunc         func(ctx context.Context, input service.LoginInput) (*service.AuthResponse, error)
	meFunc            func(ctx context.Context, userID uint) (*service.MeResponse, error)
	deleteAccountFunc func(context.Context, uint) error
}

func (f *fakeAuthService) Signup(ctx context.Context, input service.SignupInput) (*service.AuthResponse, error) {
	if f.signupFunc == nil {
		return nil, nil
	}
	return f.signupFunc(ctx, input)
}

func (f *fakeAuthService) Login(ctx context.Context, input service.LoginInput) (*service.AuthResponse, error) {
	if f.loginFunc == nil {
		return nil, nil
	}
	return f.loginFunc(ctx, input)
}

func (f *fakeAuthService) Me(ctx context.Context, userID uint) (*service.MeResponse, error) {
	if f.meFunc == nil {
		return nil, nil
	}
	return f.meFunc(ctx, userID)
}

func (f *fakeAuthService) DeleteAccount(ctx context.Context, userID uint) error {
	return f.deleteAccountFunc(ctx, userID)
}

func TestAuthHandler_Signup(t *testing.T) {
	type input struct {
		body string
	}

	tests := []struct {
		name         string
		in           input
		service      fakeAuthService
		wantStatus   int
		wantResponse *service.AuthResponse
		wantAppError *httpx.AppError
	}{
		{
			name: "【正常系】signup成功時は201でtokenを返すこと",
			in: input{
				body: `{"name":"taro","email":"taro@example.com","password":"pass1234"}`,
			},
			service: fakeAuthService{
				signupFunc: func(ctx context.Context, input service.SignupInput) (*service.AuthResponse, error) {
					require.Equal(t, "taro", input.Name)
					require.Equal(t, "taro@example.com", input.Email)
					require.Equal(t, "pass1234", input.Password)
					return &service.AuthResponse{Token: "signup-token"}, nil
				},
			},
			wantStatus:   http.StatusCreated,
			wantResponse: &service.AuthResponse{Token: "signup-token"},
		},
		{
			name: "【異常系】bind失敗時はINVALID_REQUESTを返すこと",
			in: input{
				body: `{"name":"taro",`,
			},
			wantAppError: httpx.InvalidRequest("invalid request body", errors.New("bind failed")),
		},
		{
			name: "【異常系】ErrEmailRequired時は400を返すこと",
			in: input{
				body: `{"name":"taro","email":"","password":"pass1234"}`,
			},
			service: fakeAuthService{
				signupFunc: func(ctx context.Context, input service.SignupInput) (*service.AuthResponse, error) {
					return nil, service.ErrEmailRequired
				},
			},
			wantAppError: httpx.InvalidRequest("email is required", service.ErrEmailRequired),
		},
		{
			name: "【異常系】ErrPasswordRequired時は400を返すこと",
			in: input{
				body: `{"name":"taro","email":"taro@example.com","password":""}`,
			},
			service: fakeAuthService{
				signupFunc: func(ctx context.Context, input service.SignupInput) (*service.AuthResponse, error) {
					return nil, service.ErrPasswordRequired
				},
			},
			wantAppError: httpx.InvalidRequest("password is required", service.ErrPasswordRequired),
		},
		{
			name: "【異常系】ErrInvalidEmailFormat時は400を返すこと",
			in: input{
				body: `{"name":"taro","email":"invalid-email","password":"pass1234"}`,
			},
			service: fakeAuthService{
				signupFunc: func(ctx context.Context, input service.SignupInput) (*service.AuthResponse, error) {
					return nil, service.ErrInvalidEmailFormat
				},
			},
			wantAppError: httpx.InvalidRequest("email format is invalid", service.ErrInvalidEmailFormat),
		},
		{
			name: "【異常系】ErrEmailAlreadyExists時は409を返すこと",
			in: input{
				body: `{"name":"taro","email":"taro@example.com","password":"pass1234"}`,
			},
			service: fakeAuthService{
				signupFunc: func(ctx context.Context, input service.SignupInput) (*service.AuthResponse, error) {
					return nil, service.ErrEmailAlreadyExists
				},
			},
			wantAppError: httpx.Conflict("email already exists", service.ErrEmailAlreadyExists),
		},
		{
			name: "【異常系】想定外エラー時は500を返すこと",
			in: input{
				body: `{"name":"taro","email":"taro@example.com","password":"pass1234"}`,
			},
			service: fakeAuthService{
				signupFunc: func(ctx context.Context, input service.SignupInput) (*service.AuthResponse, error) {
					return nil, errors.New("unexpected error")
				},
			},
			wantAppError: httpx.Internal("internal server error", errors.New("unexpected error")),
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			e := echo.New()
			req := httptest.NewRequest(http.MethodPost, "/signup", strings.NewReader(tt.in.body))
			req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
			rec := httptest.NewRecorder()
			c := e.NewContext(req, rec)

			h := NewAuthHandler(&tt.service)
			err := h.Signup(c)

			if tt.wantAppError != nil {
				require.Error(t, err)
				appErr, ok := err.(*httpx.AppError)
				require.True(t, ok)
				require.Equal(t, tt.wantAppError.Status, appErr.Status)
				require.Equal(t, tt.wantAppError.Code, appErr.Code)
				require.Equal(t, tt.wantAppError.Message, appErr.Message)
				return
			}

			require.NoError(t, err)
			require.Equal(t, tt.wantStatus, rec.Code)

			var got service.AuthResponse
			require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
			require.Equal(t, tt.wantResponse, &got)
		})
	}
}

func TestAuthHandler_Login(t *testing.T) {
	type input struct {
		body string
	}

	tests := []struct {
		name         string
		in           input
		service      fakeAuthService
		wantStatus   int
		wantResponse *service.AuthResponse
		wantAppError *httpx.AppError
	}{
		{
			name: "【正常系】login成功時は200でtokenを返すこと",
			in: input{
				body: `{"email":"taro@example.com","password":"pass1234"}`,
			},
			service: fakeAuthService{
				loginFunc: func(ctx context.Context, input service.LoginInput) (*service.AuthResponse, error) {
					require.Equal(t, "taro@example.com", input.Email)
					require.Equal(t, "pass1234", input.Password)
					return &service.AuthResponse{Token: "login-token"}, nil
				},
			},
			wantStatus:   http.StatusOK,
			wantResponse: &service.AuthResponse{Token: "login-token"},
		},
		{
			name: "【異常系】bind失敗時はINVALID_REQUESTを返すこと",
			in: input{
				body: `{"email":"taro@example.com",`,
			},
			wantAppError: httpx.InvalidRequest("invalid request body", errors.New("bind failed")),
		},
		{
			name: "【異常系】ErrInvalidCredentials時は401を返すこと",
			in: input{
				body: `{"email":"taro@example.com","password":"wrongpass"}`,
			},
			service: fakeAuthService{
				loginFunc: func(ctx context.Context, input service.LoginInput) (*service.AuthResponse, error) {
					return nil, service.ErrInvalidCredentials
				},
			},
			wantAppError: httpx.Unauthorized("email or password is incorrect", service.ErrInvalidCredentials),
		},
		{
			name: "【異常系】想定外エラー時は500を返すこと",
			in: input{
				body: `{"email":"taro@example.com","password":"pass1234"}`,
			},
			service: fakeAuthService{
				loginFunc: func(ctx context.Context, input service.LoginInput) (*service.AuthResponse, error) {
					return nil, errors.New("unexpected error")
				},
			},
			wantAppError: httpx.Internal("internal server error", errors.New("unexpected error")),
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			e := echo.New()
			req := httptest.NewRequest(http.MethodPost, "/login", strings.NewReader(tt.in.body))
			req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
			rec := httptest.NewRecorder()
			c := e.NewContext(req, rec)

			h := NewAuthHandler(&tt.service)
			err := h.Login(c)

			if tt.wantAppError != nil {
				require.Error(t, err)
				appErr, ok := err.(*httpx.AppError)
				require.True(t, ok)
				require.Equal(t, tt.wantAppError.Status, appErr.Status)
				require.Equal(t, tt.wantAppError.Code, appErr.Code)
				require.Equal(t, tt.wantAppError.Message, appErr.Message)
				return
			}

			require.NoError(t, err)
			require.Equal(t, tt.wantStatus, rec.Code)

			var got service.AuthResponse
			require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
			require.Equal(t, tt.wantResponse, &got)
		})
	}
}

func TestAuthHandler_Me(t *testing.T) {
	now := time.Date(2026, 6, 7, 10, 0, 0, 0, time.UTC)

	tests := []struct {
		name         string
		setUserID    bool
		service      fakeAuthService
		wantStatus   int
		wantResponse *service.MeResponse
		wantAppError *httpx.AppError
	}{
		{
			name:      "【正常系】me成功時は200でuser情報を返すこと",
			setUserID: true,
			service: fakeAuthService{
				meFunc: func(ctx context.Context, userID uint) (*service.MeResponse, error) {
					require.Equal(t, uint(1), userID)
					return &service.MeResponse{
						ID:        1,
						Name:      "taro",
						Email:     "taro@example.com",
						CreatedAt: now.Format(time.RFC3339),
						UpdatedAt: now.Format(time.RFC3339),
					}, nil
				},
			},
			wantStatus: http.StatusOK,
			wantResponse: &service.MeResponse{
				ID:        1,
				Name:      "taro",
				Email:     "taro@example.com",
				CreatedAt: now.Format(time.RFC3339),
				UpdatedAt: now.Format(time.RFC3339),
			},
		},
		{
			name:      "【異常系】contextにuserIDがない場合は401を返すこと",
			setUserID: false,
			wantAppError: httpx.Unauthorized(
				"authenticated user is required",
				errors.New("authenticated user is missing from context"),
			),
		},
		{
			name:      "【異常系】ErrUserNotFound時は401を返すこと",
			setUserID: true,
			service: fakeAuthService{
				meFunc: func(ctx context.Context, userID uint) (*service.MeResponse, error) {
					return nil, service.ErrUserNotFound
				},
			},
			wantAppError: httpx.Unauthorized("authenticated user no longer exists", service.ErrUserNotFound),
		},
		{
			name:      "【異常系】想定外エラー時は500を返すこと",
			setUserID: true,
			service: fakeAuthService{
				meFunc: func(ctx context.Context, userID uint) (*service.MeResponse, error) {
					return nil, errors.New("unexpected error")
				},
			},
			wantAppError: httpx.Internal("internal server error", errors.New("unexpected error")),
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
				c.Set(authUserIDContextKey, uint(1))
			}

			h := NewAuthHandler(&tt.service)
			err := h.Me(c)

			if tt.wantAppError != nil {
				require.Error(t, err)
				appErr, ok := err.(*httpx.AppError)
				require.True(t, ok)
				require.Equal(t, tt.wantAppError.Status, appErr.Status)
				require.Equal(t, tt.wantAppError.Code, appErr.Code)
				require.Equal(t, tt.wantAppError.Message, appErr.Message)
				return
			}

			require.NoError(t, err)
			require.Equal(t, tt.wantStatus, rec.Code)

			var got service.MeResponse
			require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &got))
			require.Equal(t, tt.wantResponse, &got)
		})
	}
}

func TestAuthHandler_DeleteAccount(t *testing.T) {
	t.Run("【正常系】bodyやqueryの他人のIDを使わず204を返す", func(t *testing.T) {
		called := false
		svc := &fakeAuthService{deleteAccountFunc: func(_ context.Context, userID uint) error {
			called = true
			require.Equal(t, uint(7), userID)
			return nil
		}}
		e := echo.New()
		req := httptest.NewRequest(http.MethodDelete, "/me?user_id=999", strings.NewReader(`{"user_id":999,"id":999}`))
		req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
		rec := httptest.NewRecorder()
		c := e.NewContext(req, rec)
		c.Set(authUserIDContextKey, uint(7))
		require.NoError(t, NewAuthHandler(svc).DeleteAccount(c))
		require.True(t, called)
		require.Equal(t, http.StatusNoContent, rec.Code)
		require.Empty(t, rec.Body.String())
	})
	for _, tt := range []struct {
		name   string
		setID  bool
		userID uint
	}{
		{"認証情報なし", false, 0}, {"IDが0", true, 0},
	} {
		t.Run("【異常系】"+tt.name, func(t *testing.T) {
			e := echo.New()
			c := e.NewContext(httptest.NewRequest(http.MethodDelete, "/me", nil), httptest.NewRecorder())
			if tt.setID {
				c.Set(authUserIDContextKey, tt.userID)
			}
			err := NewAuthHandler(&fakeAuthService{}).DeleteAccount(c)
			var appErr *httpx.AppError
			require.ErrorAs(t, err, &appErr)
			require.Equal(t, http.StatusUnauthorized, appErr.Status)
		})
	}
	for _, tt := range []struct {
		name       string
		serviceErr error
		status     int
		message    string
	}{
		{"削除済み", service.ErrUserNotFound, 401, "authenticated user no longer exists"},
		{"DBエラー", errors.New("private database details"), 500, "internal server error"},
	} {
		t.Run("【異常系】"+tt.name, func(t *testing.T) {
			e := echo.New()
			c := e.NewContext(httptest.NewRequest(http.MethodDelete, "/me", nil), httptest.NewRecorder())
			c.Set(authUserIDContextKey, uint(7))
			svc := &fakeAuthService{deleteAccountFunc: func(context.Context, uint) error { return tt.serviceErr }}
			var appErr *httpx.AppError
			require.ErrorAs(t, NewAuthHandler(svc).DeleteAccount(c), &appErr)
			require.Equal(t, tt.status, appErr.Status)
			require.Equal(t, tt.message, appErr.Message)
		})
	}
}
