// Package domain contains the core business entities matching the TLA+ specification
package domain

import (
	"fmt"
	"time"
)

// TaskID represents a unique task identifier (maps to TLA+ task ID)
type TaskID int

// UserID represents a user identifier (maps to TLA+ Users set)
type UserID string

// TaskStatus represents the state of a task (maps to TLA+ TaskStates)
type TaskStatus string

const (
	StatusPending    TaskStatus = "pending"
	StatusInProgress TaskStatus = "in_progress"
	StatusCompleted  TaskStatus = "completed"
	StatusCancelled  TaskStatus = "cancelled"
	StatusBlocked    TaskStatus = "blocked"
)

// Priority represents task priority levels (maps to TLA+ Priorities)
type Priority string

const (
	PriorityLow      Priority = "low"
	PriorityMedium   Priority = "medium"
	PriorityHigh     Priority = "high"
	PriorityCritical Priority = "critical"
)

// Tag represents task categories (maps to TLA+ tags subset)
type Tag string

const (
	TagBug           Tag = "bug"
	TagFeature       Tag = "feature"
	TagEnhancement   Tag = "enhancement"
	TagDocumentation Tag = "documentation"
)

// Task represents a task entity (maps to TLA+ task record)
type Task struct {
	ID           TaskID            `json:"id"`
	Title        string            `json:"title"`
	Description  string            `json:"description"`
	Status       TaskStatus        `json:"status"`
	Priority     Priority          `json:"priority"`
	Assignee     UserID            `json:"assignee"`
	CreatedBy    UserID            `json:"created_by"`
	CreatedAt    time.Time         `json:"created_at"`
	UpdatedAt    time.Time         `json:"updated_at"`
	DueDate      *time.Time        `json:"due_date,omitempty"`
	Tags         []Tag             `json:"tags"`
	Dependencies map[TaskID]bool   `json:"dependencies"`
}

// ValidTransition represents a valid state transition (maps to TLA+ ValidTransitions)
type ValidTransition struct {
	From TaskStatus
	To   TaskStatus
}

// ValidTransitions defines all allowed state transitions
var ValidTransitions = map[ValidTransition]bool{
	{StatusPending, StatusInProgress}:    true,
	{StatusPending, StatusCancelled}:     true,
	{StatusPending, StatusBlocked}:       true,
	{StatusInProgress, StatusCompleted}:  true,
	{StatusInProgress, StatusCancelled}:  true,
	{StatusInProgress, StatusBlocked}:    true,
	{StatusInProgress, StatusPending}:    true, // Allow reverting
	{StatusBlocked, StatusPending}:       true,
	{StatusBlocked, StatusInProgress}:    true,
	{StatusBlocked, StatusCancelled}:     true,
}

// IsValidTransition checks if a state transition is valid (maps to TLA+ IsValidTransition)
func IsValidTransition(from, to TaskStatus) bool {
	return ValidTransitions[ValidTransition{From: from, To: to}]
}

// CanDelete checks if a task can be deleted (only completed or cancelled)
func (t *Task) CanDelete() bool {
	return t.Status == StatusCompleted || t.Status == StatusCancelled
}

// IsBlocked checks if task should be blocked based on dependencies
func (t *Task) IsBlocked(allTasks map[TaskID]*Task) bool {
	if len(t.Dependencies) == 0 {
		return false
	}
	
	for depID := range t.Dependencies {
		if dep, exists := allTasks[depID]; exists {
			if dep.Status != StatusCompleted {
				return true
			}
		}
	}
	return false
}

// ShouldUnblock checks if a blocked task can be unblocked
func (t *Task) ShouldUnblock(allTasks map[TaskID]*Task) bool {
	if t.Status != StatusBlocked {
		return false
	}
	
	for depID := range t.Dependencies {
		if dep, exists := allTasks[depID]; exists {
			if dep.Status != StatusCompleted {
				return false
			}
		}
	}
	return true
}

// Validate performs domain validation on the task
func (t *Task) Validate() error {
	if t.Title == "" {
		return fmt.Errorf("task title cannot be empty")
	}
	if t.Description == "" {
		return fmt.Errorf("task description cannot be empty")
	}
	if !isValidStatus(t.Status) {
		return fmt.Errorf("invalid task status: %s", t.Status)
	}
	if !isValidPriority(t.Priority) {
		return fmt.Errorf("invalid task priority: %s", t.Priority)
	}
	if t.Assignee == "" {
		return fmt.Errorf("task must have an assignee")
	}
	if t.CreatedBy == "" {
		return fmt.Errorf("task must have a creator")
	}
	if t.CreatedAt.After(t.UpdatedAt) {
		return fmt.Errorf("created time cannot be after updated time")
	}
	for _, tag := range t.Tags {
		if !isValidTag(tag) {
			return fmt.Errorf("invalid tag: %s", tag)
		}
	}
	return nil
}

func isValidStatus(status TaskStatus) bool {
	switch status {
	case StatusPending, StatusInProgress, StatusCompleted, StatusCancelled, StatusBlocked:
		return true
	default:
		return false
	}
}

func isValidPriority(priority Priority) bool {
	switch priority {
	case PriorityLow, PriorityMedium, PriorityHigh, PriorityCritical:
		return true
	default:
		return false
	}
}

func isValidTag(tag Tag) bool {
	switch tag {
	case TagBug, TagFeature, TagEnhancement, TagDocumentation:
		return true
	default:
		return false
	}
}