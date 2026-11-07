package repository

import (
	"context"
	"errors"
	"regexp"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/RintaroNasu/routetap/api/internal/models"
	"github.com/stretchr/testify/require"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func savedRouteTestRepository(t *testing.T) (SavedRouteRepository, sqlmock.Sqlmock) {
	t.Helper()
	conn, mock, err := sqlmock.New()
	require.NoError(t, err)
	db, err := gorm.Open(postgres.New(postgres.Config{Conn: conn}), &gorm.Config{
		DisableAutomaticPing: true,
		Logger:               logger.Default.LogMode(logger.Silent),
	})
	require.NoError(t, err)
	t.Cleanup(func() {
		require.NoError(t, mock.ExpectationsWereMet())
		_ = conn.Close()
	})
	return NewSavedRouteRepository(db), mock
}

func TestSavedRouteRepository_UpdateRoute(t *testing.T) {
	query := regexp.QuoteMeta(`UPDATE "saved_routes" SET "destination"=$1,"name"=$2,"origin"=$3,"updated_at"=$4 WHERE id = $5 AND user_id = $6 RETURNING *`)
	columns := []string{"id", "user_id", "name", "origin", "destination", "created_at", "updated_at"}
	t.Run("【正常系】IDと所有者で絞り込み編集可能な列のみ更新する", func(t *testing.T) {
		repo, mock := savedRouteTestRepository(t)
		created := time.Date(2026, 11, 1, 9, 0, 0, 0, time.UTC)
		updated := created.Add(time.Hour)
		mock.ExpectBegin()
		mock.ExpectQuery(query).WithArgs("大井町駅", "帰宅", "浜松町駅", sqlmock.AnyArg(), uint(12), uint(7)).
			WillReturnRows(sqlmock.NewRows(columns).AddRow(12, 7, "帰宅", "浜松町駅", "大井町駅", created, updated))
		mock.ExpectCommit()
		route := &models.SavedRoute{Name: "帰宅", Origin: "浜松町駅", Destination: "大井町駅"}
		require.NoError(t, repo.UpdateRoute(context.Background(), 7, 12, route))
		require.Equal(t, &models.SavedRoute{ID: 12, UserID: 7, Name: "帰宅", Origin: "浜松町駅", Destination: "大井町駅", CreatedAt: created, UpdatedAt: updated}, route)
	})
	for _, userID := range []uint{7, 999} {
		t.Run("【異常系】該当する所有者の行がなければnot found", func(t *testing.T) {
			repo, mock := savedRouteTestRepository(t)
			mock.ExpectBegin()
			mock.ExpectQuery(query).WithArgs("大井町駅", "帰宅", "浜松町駅", sqlmock.AnyArg(), uint(12), userID).
				WillReturnRows(sqlmock.NewRows(columns))
			mock.ExpectCommit()
			err := repo.UpdateRoute(context.Background(), userID, 12, &models.SavedRoute{Name: "帰宅", Origin: "浜松町駅", Destination: "大井町駅"})
			require.ErrorIs(t, err, gorm.ErrRecordNotFound)
		})
	}
	t.Run("【異常系】DBエラー時はrollbackして返す", func(t *testing.T) {
		repo, mock := savedRouteTestRepository(t)
		dbErr := errors.New("database unavailable")
		mock.ExpectBegin()
		mock.ExpectQuery(query).WithArgs("大井町駅", "帰宅", "浜松町駅", sqlmock.AnyArg(), uint(12), uint(7)).WillReturnError(dbErr)
		mock.ExpectRollback()
		err := repo.UpdateRoute(context.Background(), 7, 12, &models.SavedRoute{Name: "帰宅", Origin: "浜松町駅", Destination: "大井町駅"})
		require.ErrorIs(t, err, dbErr)
	})
}

func TestSavedRouteRepository_DeleteRoute(t *testing.T) {
	query := regexp.QuoteMeta(`DELETE FROM "saved_routes" WHERE id = $1 AND user_id = $2`)
	t.Run("【正常系】IDと所有者の両方で絞り込んで削除する", func(t *testing.T) {
		repo, mock := savedRouteTestRepository(t)
		mock.ExpectBegin()
		mock.ExpectExec(query).WithArgs(uint(12), uint(7)).WillReturnResult(sqlmock.NewResult(0, 1))
		mock.ExpectCommit()
		require.NoError(t, repo.DeleteRoute(context.Background(), 7, 12))
	})
	for _, userID := range []uint{7, 999} {
		t.Run("【異常系】対象なし・所有者不一致はnot found", func(t *testing.T) {
			repo, mock := savedRouteTestRepository(t)
			mock.ExpectBegin()
			mock.ExpectExec(query).WithArgs(uint(12), userID).WillReturnResult(sqlmock.NewResult(0, 0))
			mock.ExpectCommit()
			require.ErrorIs(t, repo.DeleteRoute(context.Background(), userID, 12), gorm.ErrRecordNotFound)
		})
	}
	t.Run("【異常系】DBエラー時はrollbackして返す", func(t *testing.T) {
		repo, mock := savedRouteTestRepository(t)
		dbErr := errors.New("database unavailable")
		mock.ExpectBegin()
		mock.ExpectExec(query).WithArgs(uint(12), uint(7)).WillReturnError(dbErr)
		mock.ExpectRollback()
		require.ErrorIs(t, repo.DeleteRoute(context.Background(), 7, 12), dbErr)
	})
}
