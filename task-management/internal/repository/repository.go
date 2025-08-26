// Package repository defines the data access interfaces
package repository

import (
	"github.com/bhatti/sample-task-management/internal/domain"
)

// TaskRepository defines the interface for task persistence
type TaskRepository interface {
	// Task operations
	CreateTask(task *domain.Task) error
	GetTask(id domain.TaskID) (*domain.Task, error)
	UpdateTask(task *domain.Task) error
	DeleteTask(id domain.TaskID) error
	GetAllTasks() (map[domain.TaskID]*domain.Task, error)
	GetTasksByUser(userID domain.UserID) ([]*domain.Task, error)
	GetTasksByStatus(status domain.TaskStatus) ([]*domain.Task, error)
	GetTasksByDependency(taskID domain.TaskID) ([]*domain.Task, error)
	
	// Bulk operations
	BulkUpdateStatus(taskIDs []domain.TaskID, status domain.TaskStatus) error
}

// UserRepository defines the interface for user persistence
type UserRepository interface {
	CreateUser(user *domain.User) error
	GetUser(id domain.UserID) (*domain.User, error)
	GetAllUsers() ([]*domain.User, error)
	UpdateUser(user *domain.User) error
	DeleteUser(id domain.UserID) error
}

// SessionRepository defines the interface for session management
type SessionRepository interface {
	CreateSession(session *domain.Session) error
	GetSession(token string) (*domain.Session, error)
	GetSessionByUser(userID domain.UserID) (*domain.Session, error)
	UpdateSession(session *domain.Session) error
	DeleteSession(token string) error
	DeleteUserSessions(userID domain.UserID) error
	GetActiveSessions() ([]*domain.Session, error)
}

// SystemStateRepository defines the interface for system state persistence
type SystemStateRepository interface {
	GetSystemState() (*domain.SystemState, error)
	SaveSystemState(state *domain.SystemState) error
	GetNextTaskID() (domain.TaskID, error)
	IncrementNextTaskID() (domain.TaskID, error)
	GetCurrentUser() (*domain.UserID, error)
	SetCurrentUser(userID *domain.UserID) error
	GetUserTasks(userID domain.UserID) ([]domain.TaskID, error)
	AddUserTask(userID domain.UserID, taskID domain.TaskID) error
	RemoveUserTask(userID domain.UserID, taskID domain.TaskID) error
}

// UnitOfWork defines a transaction boundary for operations
type UnitOfWork interface {
	Begin() error
	Commit() error
	Rollback() error
	Tasks() TaskRepository
	Users() UserRepository
	Sessions() SessionRepository
	SystemState() SystemStateRepository
}
