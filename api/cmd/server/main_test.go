package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/golang-jwt/jwt/v5"
	"github.com/stretchr/testify/require"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func TestLoginIssuesTokenValidForThirtyDays(t *testing.T) {
	conn, mock, err := sqlmock.New()
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, mock.ExpectationsWereMet()); _ = conn.Close() })
	db, err := gorm.Open(postgres.New(postgres.Config{Conn: conn}), &gorm.Config{
		DisableAutomaticPing: true,
		Logger:               logger.Default.LogMode(logger.Silent),
	})
	require.NoError(t, err)
	passwordHash, err := bcrypt.GenerateFromPassword([]byte("password"), bcrypt.MinCost)
	require.NoError(t, err)
	mock.ExpectQuery(`SELECT .* FROM "users" WHERE email = .*`).
		WithArgs("test@example.com", 1).
		WillReturnRows(sqlmock.NewRows([]string{"id", "email", "password_hash"}).
			AddRow(7, "test@example.com", string(passwordHash)))
	secret := "test-secret-at-least-32-characters"
	server := newServer(db, secret)
	request := httptest.NewRequest(http.MethodPost, "/login", strings.NewReader(`{"email":"test@example.com","password":"password"}`))
	request.Header.Set("Content-Type", "application/json")
	response := httptest.NewRecorder()
	server.ServeHTTP(response, request)
	require.Equal(t, http.StatusOK, response.Code, response.Body.String())
	var body struct {
		Token string `json:"token"`
	}
	require.NoError(t, json.Unmarshal(response.Body.Bytes(), &body))
	claims := &jwt.RegisteredClaims{}
	key := func(*jwt.Token) (any, error) { return []byte(secret), nil }
	_, err = jwt.ParseWithClaims(body.Token, claims, key)
	require.NoError(t, err)
	require.Equal(t, "7", claims.Subject)
	require.NotNil(t, claims.IssuedAt)
	require.NotNil(t, claims.ExpiresAt)
	require.Equal(t, 30*24*time.Hour, claims.ExpiresAt.Sub(claims.IssuedAt.Time))
	_, err = jwt.Parse(body.Token, key, jwt.WithTimeFunc(func() time.Time {
		return claims.ExpiresAt.Add(-time.Second)
	}))
	require.NoError(t, err)
	_, err = jwt.Parse(body.Token, key, jwt.WithTimeFunc(func() time.Time {
		return claims.ExpiresAt.Time
	}))
	require.ErrorIs(t, err, jwt.ErrTokenExpired)
}
