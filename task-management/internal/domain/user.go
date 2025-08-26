package domain

import (
	"fmt"
	"time"
)

// User represents a system user (maps to TLA+ Users)
type User struct {
	ID       UserID    `json:"id"`
	Name     string    `json:"name"`
	Email    string    `json:"email"`
	JoinedAt time.Time `json:"joined_at"`
}

// Session represents an active user session (maps to TLA+ sessions)
type Session struct {
	UserID    UserID    `json:"user_id"`
	Token     string    `json:"token"`
	Active    bool      `json:"active"`
	CreatedAt time.Time `json:"created_at"`
	ExpiresAt time.Time `json:"expires_at"`
}

// IsExpired checks if the session has expired
func (s *Session) IsExpired() bool {
	return time.Now().After(s.ExpiresAt)
}

// IsValid checks if the session is valid
func (s *Session) IsValid() bool {
	return s.Active && !s.IsExpired()
}

// Validate performs domain validation on the user
func (u *User) Validate() error {
	if u.ID == "" {
		return fmt.Errorf("user ID cannot be empty")
	}
	if u.Name == "" {
		return fmt.Errorf("user name cannot be empty")
	}
	if u.Email == "" {
		return fmt.Errorf("user email cannot be empty")
	}
	return nil
}