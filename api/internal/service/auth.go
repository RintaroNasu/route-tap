package service

import (
	"context"
	"errors"
	"fmt"
	"net/mail"
	"strings"
	"time"

	"github.com/RintaroNasu/routetap/api/internal/models"
	"github.com/RintaroNasu/routetap/api/internal/repository"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

var (
	ErrInvalidEmailFormat = errors.New("invalid email format")
	ErrEmailRequired      = errors.New("email is required")
	ErrPasswordRequired   = errors.New("password is required")
	ErrEmailAlreadyExists = errors.New("email already exists")
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrUserNotFound       = errors.New("user not found")
)

type AuthService interface {
	Signup(ctx context.Context, input SignupInput) (*AuthResponse, error)
	Login(ctx context.Context, input LoginInput) (*AuthResponse, error)
	Me(ctx context.Context, userID uint) (*MeResponse, error)
	DeleteAccount(ctx context.Context, userID uint) error
}

type SignupInput struct {
	Name     string
	Email    string
	Password string
}

type LoginInput struct {
	Email    string
	Password string
}

type AuthResponse struct {
	Token string `json:"token"`
}

type MeResponse struct {
	ID        uint   `json:"id"`
	Name      string `json:"name"`
	Email     string `json:"email"`
	CreatedAt string `json:"created_at"`
	UpdatedAt string `json:"updated_at"`
}

type tokenGenerator interface {
	GenerateToken(userID uint) (string, error)
}

type authService struct {
	repo       repository.AuthRepository
	jwtManager tokenGenerator
}

func NewAuthService(repo repository.AuthRepository, jwtManager tokenGenerator) AuthService {
	return &authService{
		repo:       repo,
		jwtManager: jwtManager,
	}
}

func (s *authService) Signup(ctx context.Context, input SignupInput) (*AuthResponse, error) {
	email, err := normalizeAndValidateCredentials(input.Email, input.Password)
	if err != nil {
		return nil, err
	}

	passwordHash, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, fmt.Errorf("generate password hash: %w", err)
	}

	user := &models.User{
		Name:         strings.TrimSpace(input.Name),
		Email:        email,
		PasswordHash: string(passwordHash),
	}

	if err := s.repo.CreateUser(ctx, user); err != nil {
		if errors.Is(err, gorm.ErrDuplicatedKey) {
			return nil, ErrEmailAlreadyExists
		}

		return nil, fmt.Errorf("create user: %w", err)
	}

	token, err := s.jwtManager.GenerateToken(user.ID)
	if err != nil {
		return nil, fmt.Errorf("generate token: %w", err)
	}

	return &AuthResponse{
		Token: token,
	}, nil
}

func (s *authService) Login(ctx context.Context, input LoginInput) (*AuthResponse, error) {
	email, err := normalizeAndValidateCredentials(input.Email, input.Password)
	if err != nil {
		return nil, err
	}

	user, err := s.repo.FindUserByEmail(ctx, email)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrInvalidCredentials
		}

		return nil, fmt.Errorf("find user by email: %w", err)
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(input.Password)); err != nil {
		if errors.Is(err, bcrypt.ErrMismatchedHashAndPassword) {
			return nil, ErrInvalidCredentials
		}

		return nil, fmt.Errorf("compare password hash: %w", err)
	}

	token, err := s.jwtManager.GenerateToken(user.ID)
	if err != nil {
		return nil, fmt.Errorf("generate token: %w", err)
	}

	return &AuthResponse{
		Token: token,
	}, nil
}

func (s *authService) Me(ctx context.Context, userID uint) (*MeResponse, error) {
	if userID == 0 {
		return nil, ErrUserNotFound
	}
	user, err := s.repo.FindUserByID(ctx, userID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}

		return nil, fmt.Errorf("find user by id: %w", err)
	}

	return &MeResponse{
		ID:        user.ID,
		Name:      user.Name,
		Email:     user.Email,
		CreatedAt: user.CreatedAt.Format(time.RFC3339),
		UpdatedAt: user.UpdatedAt.Format(time.RFC3339),
	}, nil
}

func (s *authService) DeleteAccount(ctx context.Context, userID uint) error {
	if userID == 0 {
		return ErrUserNotFound
	}
	if err := s.repo.DeleteUser(ctx, userID); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrUserNotFound
		}
		return fmt.Errorf("delete user: %w", err)
	}
	return nil
}

func normalizeAndValidateCredentials(email string, password string) (string, error) {
	normalizedEmail := strings.ToLower(strings.TrimSpace(email))
	if normalizedEmail == "" {
		return "", ErrEmailRequired
	}

	if password == "" {
		return "", ErrPasswordRequired
	}

	if _, err := mail.ParseAddress(normalizedEmail); err != nil {
		return "", ErrInvalidEmailFormat
	}

	return normalizedEmail, nil
}
