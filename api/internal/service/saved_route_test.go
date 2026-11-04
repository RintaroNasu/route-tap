package service

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/RintaroNasu/routetap/api/internal/models"
	"github.com/stretchr/testify/require"
)

type fakeSavedRouteRepo struct {
	create func(context.Context, *models.SavedRoute) error
	find   func(context.Context, uint) ([]models.SavedRoute, error)
}

func (f *fakeSavedRouteRepo) CreateRoute(ctx context.Context, route *models.SavedRoute) error {
	return f.create(ctx, route)
}

func (f *fakeSavedRouteRepo) FindRoutesByUserID(ctx context.Context, userID uint) ([]models.SavedRoute, error) {
	return f.find(ctx, userID)
}

func TestSavedRouteService_Create(t *testing.T) {
	t.Run("【正常系】前後の空白を除きログインユーザーのルートを保存する", func(t *testing.T) {
		now := time.Date(2026, 11, 3, 18, 3, 0, 0, time.FixedZone("JST", 9*60*60))
		repo := &fakeSavedRouteRepo{create: func(ctx context.Context, route *models.SavedRoute) error {
			require.Equal(t, uint(7), route.UserID)
			require.Equal(t, "通勤", route.Name)
			require.Equal(t, "大井町駅、東京都品川区", route.Origin)
			require.Equal(t, "浜松町駅、東京都港区", route.Destination)
			route.ID = 12
			route.CreatedAt = now
			route.UpdatedAt = now
			return nil
		}}
		result, err := NewSavedRouteService(repo).Create(context.Background(), 7, CreateSavedRouteInput{
			Name: "  通勤  ", Origin: "大井町駅、東京都品川区", Destination: " 浜松町駅、東京都港区 ",
		})
		require.NoError(t, err)
		require.Equal(t, &SavedRouteResponse{
			ID: 12, Name: "通勤", Origin: "大井町駅、東京都品川区", Destination: "浜松町駅、東京都港区",
			CreatedAt: "2026-11-03T18:03:00+09:00", UpdatedAt: "2026-11-03T18:03:00+09:00",
		}, result)
	})

	tests := []struct {
		name    string
		userID  uint
		input   CreateSavedRouteInput
		wantErr error
	}{
		{"ユーザーIDが0", 0, CreateSavedRouteInput{"通勤", "大井町駅", "浜松町駅"}, ErrRouteUserRequired},
		{"表示名が空白", 7, CreateSavedRouteInput{"  ", "大井町駅", "浜松町駅"}, ErrRouteNameRequired},
		{"出発地が空白", 7, CreateSavedRouteInput{"通勤", " ", "浜松町駅"}, ErrOriginRequired},
		{"目的地が空白", 7, CreateSavedRouteInput{"通勤", "大井町駅", " "}, ErrDestinationRequired},
		{"表示名が101文字", 7, CreateSavedRouteInput{strings.Repeat("名", 101), "大井町駅", "浜松町駅"}, ErrRouteNameTooLong},
		{"出発地が501文字", 7, CreateSavedRouteInput{"通勤", strings.Repeat("駅", 501), "浜松町駅"}, ErrOriginTooLong},
		{"目的地が501文字", 7, CreateSavedRouteInput{"通勤", "大井町駅", strings.Repeat("駅", 501)}, ErrDestinationTooLong},
	}
	for _, tt := range tests {
		t.Run("【異常系】"+tt.name+"の場合は保存しない", func(t *testing.T) {
			repo := &fakeSavedRouteRepo{create: func(context.Context, *models.SavedRoute) error {
				t.Fatal("入力エラー時にDBを呼んではいけない")
				return nil
			}}
			result, err := NewSavedRouteService(repo).Create(context.Background(), tt.userID, tt.input)
			require.ErrorIs(t, err, tt.wantErr)
			require.Nil(t, result)
		})
	}
	t.Run("【正常系】日本語でも文字数上限ちょうどなら保存できる", func(t *testing.T) {
		input := CreateSavedRouteInput{strings.Repeat("名", 100), strings.Repeat("駅", 500), strings.Repeat("先", 500)}
		repo := &fakeSavedRouteRepo{create: func(_ context.Context, route *models.SavedRoute) error {
			require.Equal(t, input.Name, route.Name)
			require.Equal(t, input.Origin, route.Origin)
			require.Equal(t, input.Destination, route.Destination)
			return nil
		}}
		_, err := NewSavedRouteService(repo).Create(context.Background(), 7, input)
		require.NoError(t, err)
	})
	t.Run("【異常系】DBの保存エラーを返す", func(t *testing.T) {
		dbErr := errors.New("database unavailable")
		repo := &fakeSavedRouteRepo{create: func(context.Context, *models.SavedRoute) error { return dbErr }}
		result, err := NewSavedRouteService(repo).Create(context.Background(), 7, CreateSavedRouteInput{"通勤", "大井町駅", "浜松町駅"})
		require.ErrorIs(t, err, dbErr)
		require.Nil(t, result)
	})
}

func TestSavedRouteService_List(t *testing.T) {
	t.Run("【正常系】ログインユーザーIDで一覧を取得し順序を維持する", func(t *testing.T) {
		now := time.Date(2026, 11, 3, 18, 3, 0, 0, time.UTC)
		repo := &fakeSavedRouteRepo{find: func(_ context.Context, userID uint) ([]models.SavedRoute, error) {
			require.Equal(t, uint(7), userID)
			return []models.SavedRoute{
				{ID: 12, UserID: 7, Name: "会社へ", Origin: "大井町駅", Destination: "浜松町駅", CreatedAt: now, UpdatedAt: now},
				{ID: 10, UserID: 7, Name: "家へ", Origin: "浜松町駅", Destination: "大井町駅", CreatedAt: now, UpdatedAt: now},
			}, nil
		}}
		result, err := NewSavedRouteService(repo).List(context.Background(), 7)
		require.NoError(t, err)
		require.Equal(t, []SavedRouteResponse{
			{ID: 12, Name: "会社へ", Origin: "大井町駅", Destination: "浜松町駅", CreatedAt: now.Format(time.RFC3339), UpdatedAt: now.Format(time.RFC3339)},
			{ID: 10, Name: "家へ", Origin: "浜松町駅", Destination: "大井町駅", CreatedAt: now.Format(time.RFC3339), UpdatedAt: now.Format(time.RFC3339)},
		}, result)
	})
	t.Run("【正常系】未登録ならnullではなく空配列を返す", func(t *testing.T) {
		repo := &fakeSavedRouteRepo{find: func(context.Context, uint) ([]models.SavedRoute, error) { return nil, nil }}
		result, err := NewSavedRouteService(repo).List(context.Background(), 7)
		require.NoError(t, err)
		body, err := json.Marshal(result)
		require.NoError(t, err)
		require.Equal(t, "[]", string(body))
	})
	t.Run("【異常系】ユーザーIDが0なら取得しない", func(t *testing.T) {
		repo := &fakeSavedRouteRepo{find: func(context.Context, uint) ([]models.SavedRoute, error) {
			t.Fatal("未認証時にDBを呼んではいけない")
			return nil, nil
		}}
		result, err := NewSavedRouteService(repo).List(context.Background(), 0)
		require.ErrorIs(t, err, ErrRouteUserRequired)
		require.Nil(t, result)
	})
	t.Run("【異常系】DBの取得エラーを返す", func(t *testing.T) {
		dbErr := errors.New("database unavailable")
		repo := &fakeSavedRouteRepo{find: func(context.Context, uint) ([]models.SavedRoute, error) { return nil, dbErr }}
		result, err := NewSavedRouteService(repo).List(context.Background(), 7)
		require.ErrorIs(t, err, dbErr)
		require.Nil(t, result)
	})
}
