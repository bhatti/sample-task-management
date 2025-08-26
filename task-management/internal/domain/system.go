package domain

import "time"

// SystemState represents the global system state (maps to TLA+ VARIABLES)
type SystemState struct {
	Tasks       map[TaskID]*Task      `json:"tasks"`        // Maps to TLA+ tasks
	UserTasks   map[UserID][]TaskID   `json:"user_tasks"`   // Maps to TLA+ userTasks
	NextTaskID  TaskID                `json:"next_task_id"` // Maps to TLA+ nextTaskId
	CurrentUser *UserID               `json:"current_user"` // Maps to TLA+ currentUser
	Clock       time.Time             `json:"clock"`        // Maps to TLA+ clock
	Sessions    map[UserID]*Session   `json:"sessions"`     // Maps to TLA+ sessions
}

// NewSystemState creates a new initial system state (maps to TLA+ Init)
func NewSystemState() *SystemState {
	return &SystemState{
		Tasks:       make(map[TaskID]*Task),
		UserTasks:   make(map[UserID][]TaskID),
		NextTaskID:  1,
		CurrentUser: nil,
		Clock:       time.Now(),
		Sessions:    make(map[UserID]*Session),
	}
}

// GetUserTasks returns tasks assigned to a user (maps to TLA+ GetUserTasks)
func (s *SystemState) GetUserTasks(userID UserID) []TaskID {
	if tasks, exists := s.UserTasks[userID]; exists {
		return tasks
	}
	return []TaskID{}
}

// TaskExists checks if a task exists (maps to TLA+ TaskExists)
func (s *SystemState) TaskExists(taskID TaskID) bool {
	_, exists := s.Tasks[taskID]
	return exists
}

// IsAuthenticated checks if there's a current authenticated user
func (s *SystemState) IsAuthenticated() bool {
	return s.CurrentUser != nil
}

// GetCurrentUser returns the current authenticated user
func (s *SystemState) GetCurrentUser() UserID {
	if s.CurrentUser == nil {
		return ""
	}
	return *s.CurrentUser
}

// AdvanceClock advances the system clock (maps to TLA+ AdvanceTime)
func (s *SystemState) AdvanceClock() {
	s.Clock = time.Now()
}

// Constants matching TLA+ CONSTANTS
const (
	MaxTasks = 1000 // Maximum number of tasks in the system
	MaxTime  = 365  // Maximum time in days for simulation
)