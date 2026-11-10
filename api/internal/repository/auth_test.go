package repository

import (
	"context"
	"errors"
	"regexp"
	"sync"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/RintaroNasu/routetap/api/internal/models"
	"github.com/stretchr/testify/require"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
	"gorm.io/gorm/schema"
)

func authTestRepository(t *testing.T) (AuthRepository, sqlmock.Sqlmock) {
	t.Helper()
	conn, mock, err := sqlmock.New()
	require.NoError(t, err)
	db, err := gorm.Open(postgres.New(postgres.Config{Conn: conn}), &gorm.Config{
		DisableAutomaticPing: true,
		Logger:               logger.Default.LogMode(logger.Silent),
	})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, mock.ExpectationsWereMet()); _ = conn.Close() })
	return NewAuthRepository(db), mock
}

func TestAuthRepository_DeleteUser(t *testing.T) {
	query := regexp.QuoteMeta(`DELETE FROM "users" WHERE id = $1`)
	for _, tt := range []struct {
		name     string
		affected int64
		wantErr  error
	}{
		{"指定ユーザーを削除", 1, nil},
		{"削除対象なし", 0, gorm.ErrRecordNotFound},
	} {
		t.Run(tt.name, func(t *testing.T) {
			repo, mock := authTestRepository(t)
			mock.ExpectBegin()
			mock.ExpectExec(query).WithArgs(uint(7)).WillReturnResult(sqlmock.NewResult(0, tt.affected))
			mock.ExpectCommit()
			err := repo.DeleteUser(context.Background(), 7)
			if tt.wantErr != nil {
				require.ErrorIs(t, err, tt.wantErr)
			} else {
				require.NoError(t, err)
			}
		})
	}
	t.Run("DBエラーはrollbackして返す", func(t *testing.T) {
		repo, mock := authTestRepository(t)
		dbErr := errors.New("database unavailable")
		mock.ExpectBegin()
		mock.ExpectExec(query).WithArgs(uint(7)).WillReturnError(dbErr)
		mock.ExpectRollback()
		require.ErrorIs(t, repo.DeleteUser(context.Background(), 7), dbErr)
	})
	t.Run("commitエラーを成功扱いしない", func(t *testing.T) {
		repo, mock := authTestRepository(t)
		commitErr := errors.New("commit failed")
		mock.ExpectBegin()
		mock.ExpectExec(query).WithArgs(uint(7)).WillReturnResult(sqlmock.NewResult(0, 1))
		mock.ExpectCommit().WillReturnError(commitErr)
		require.ErrorIs(t, repo.DeleteUser(context.Background(), 7), commitErr)
	})
}

func TestUserSavedRoutesCascadeConstraint(t *testing.T) {
	userSchema, err := schema.Parse(&models.User{}, &sync.Map{}, schema.NamingStrategy{})
	require.NoError(t, err)
	relationship := userSchema.Relationships.Relations["SavedRoutes"]
	require.NotNil(t, relationship)
	constraint := relationship.ParseConstraint()
	require.NotNil(t, constraint)
	require.Equal(t, "CASCADE", constraint.OnDelete)
	require.Equal(t, "users", constraint.ReferenceSchema.Table)
	require.Equal(t, "saved_routes", constraint.Schema.Table)
	require.Len(t, constraint.ForeignKeys, 1)
	require.Equal(t, "user_id", constraint.ForeignKeys[0].DBName)
	require.Len(t, constraint.References, 1)
	require.Equal(t, "id", constraint.References[0].DBName)
}
