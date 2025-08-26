// Package usecase implements the TLA+ actions as use cases
package usecase

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"time"
	
	"github.com/bhatti/sample-task-management/internal/domain"
	"github.com/bhatti/sample-task-management/internal/repository"
)

// TaskUseCase implements task-related TLA+ actions
type TaskUseCase struct {
	uow              repository.UnitOfWork
	invariantChecker InvariantChecker
}

// InvariantChecker interface for runtime invariant validation
type InvariantChecker interface {
	CheckAllInvariants(state *domain.SystemState) error
	CheckTaskInvariants(task *domain.Task, state *domain.SystemState) error
	CheckTransitionInvariant(from, to domain.TaskStatus) error
}

// NewTaskUseCase creates a new task use case
func NewTaskUseCase(uow repository.UnitOfWork, checker InvariantChecker) *TaskUseCase {
	return &TaskUseCase{
		uow:              uow,
		invariantChecker: checker,
	}
}

// Authenticate implements TLA+ Authenticate action
func (uc *TaskUseCase) Authenticate(userID domain.UserID) (*domain.Session, error) {
	// Preconditions from TLA+:
	// - user \in Users
	// - ~sessions[user]
	
	user, err := uc.uow.Users().GetUser(userID)
	if err != nil {
		return nil, fmt.Errorf("user not found: %w", err)
	}
	
	// Check if user already has an active session
	existingSession, _ := uc.uow.Sessions().GetSessionByUser(userID)
	if existingSession != nil && existingSession.IsValid() {
		return nil, fmt.Errorf("user %s already has an active session", userID)
	}
	
	// Create new session
	token := generateToken()
	session := &domain.Session{
		UserID:    user.ID,
		Token:     token,
		Active:    true,
		CreatedAt: time.Now(),
		ExpiresAt: time.Now().Add(24 * time.Hour),
	}
	
	// Update state
	if err := uc.uow.Sessions().CreateSession(session); err != nil {
		return nil, fmt.Errorf("failed to create session: %w", err)
	}
	
	if err := uc.uow.SystemState().SetCurrentUser(&userID); err != nil {
		return nil, fmt.Errorf("failed to set current user: %w", err)
	}
	
	// Check invariants
	state, _ := uc.uow.SystemState().GetSystemState()
	if err := uc.invariantChecker.CheckAllInvariants(state); err != nil {
		uc.uow.Rollback()
		return nil, fmt.Errorf("invariant violation: %w", err)
	}
	
	return session, nil
}

// Logout implements TLA+ Logout action
func (uc *TaskUseCase) Logout(userID domain.UserID) error {
	// Preconditions from TLA+:
	// - currentUser # NULL
	// - currentUser \in Users
	
	currentUser, err := uc.uow.SystemState().GetCurrentUser()
	if err != nil || currentUser == nil {
		return fmt.Errorf("no user currently authenticated")
	}
	
	if *currentUser != userID {
		return fmt.Errorf("user %s is not the current user", userID)
	}
	
	// Deactivate session
	session, err := uc.uow.Sessions().GetSessionByUser(userID)
	if err == nil && session != nil {
		session.Active = false
		uc.uow.Sessions().UpdateSession(session)
	}
	
	// Clear current user
	if err := uc.uow.SystemState().SetCurrentUser(nil); err != nil {
		return fmt.Errorf("failed to clear current user: %w", err)
	}
	
	return nil
}

// CreateTask implements TLA+ CreateTask action
func (uc *TaskUseCase) CreateTask(
	title, description string,
	priority domain.Priority,
	assignee domain.UserID,
	dueDate *time.Time,
	tags []domain.Tag,
	dependencies []domain.TaskID,
) (*domain.Task, error) {
	// Preconditions from TLA+:
	// - currentUser # NULL
	// - currentUser \in Users
	// - nextTaskId <= MaxTasks
	// - deps \subseteq DOMAIN tasks
	// - \A dep \in deps : tasks[dep].status # "cancelled"
	
	currentUser, err := uc.uow.SystemState().GetCurrentUser()
	if err != nil || currentUser == nil {
		return nil, fmt.Errorf("authentication required")
	}
	
	// Check max tasks limit
	nextID, err := uc.uow.SystemState().GetNextTaskID()
	if err != nil {
		return nil, fmt.Errorf("failed to get next task ID: %w", err)
	}
	
	if nextID > domain.MaxTasks {
		return nil, fmt.Errorf("maximum number of tasks (%d) reached", domain.MaxTasks)
	}
	
	// Validate dependencies
	allTasks, err := uc.uow.Tasks().GetAllTasks()
	if err != nil {
		return nil, fmt.Errorf("failed to get tasks: %w", err)
	}
	
	depMap := make(map[domain.TaskID]bool)
	for _, depID := range dependencies {
		depTask, exists := allTasks[depID]
		if !exists {
			return nil, fmt.Errorf("dependency task %d does not exist", depID)
		}
		if depTask.Status == domain.StatusCancelled {
			return nil, fmt.Errorf("cannot depend on cancelled task %d", depID)
		}
		depMap[depID] = true
	}
	
	// Check for cyclic dependencies
	if err := uc.checkCyclicDependencies(nextID, depMap, allTasks); err != nil {
		return nil, err
	}
	
	// Determine initial status based on dependencies
	status := domain.StatusPending
	if len(dependencies) > 0 {
		// Check if all dependencies are completed
		allCompleted := true
		for depID := range depMap {
			if allTasks[depID].Status != domain.StatusCompleted {
				allCompleted = false
				break
			}
		}
		if !allCompleted {
			status = domain.StatusBlocked
		}
	}
	
	// Create task
	task := &domain.Task{
		ID:           nextID,
		Title:        title,
		Description:  description,
		Status:       status,
		Priority:     priority,
		Assignee:     assignee,
		CreatedBy:    *currentUser,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
		DueDate:      dueDate,
		Tags:         tags,
		Dependencies: depMap,
	}
	
	// Validate task
	if err := task.Validate(); err != nil {
		return nil, fmt.Errorf("task validation failed: %w", err)
	}
	
	// Save task
	if err := uc.uow.Tasks().CreateTask(task); err != nil {
		return nil, fmt.Errorf("failed to create task: %w", err)
	}
	
	// Increment next task ID
	if _, err := uc.uow.SystemState().IncrementNextTaskID(); err != nil {
		return nil, fmt.Errorf("failed to increment task ID: %w", err)
	}
	
	// Check invariants
	state, _ := uc.uow.SystemState().GetSystemState()
	if err := uc.invariantChecker.CheckAllInvariants(state); err != nil {
		uc.uow.Rollback()
		return nil, fmt.Errorf("invariant violation after task creation: %w", err)
	}
	
	return task, nil
}

// UpdateTaskStatus implements TLA+ UpdateTaskStatus action
func (uc *TaskUseCase) UpdateTaskStatus(taskID domain.TaskID, newStatus domain.TaskStatus) error {
	// Preconditions from TLA+:
	// - currentUser # NULL
	// - TaskExists(taskId)
	// - taskId \in GetUserTasks(currentUser)
	// - IsValidTransition(tasks[taskId].status, newStatus)
	// - newStatus = "in_progress" => all dependencies completed
	
	currentUser, err := uc.uow.SystemState().GetCurrentUser()
	if err != nil || currentUser == nil {
		return fmt.Errorf("authentication required")
	}
	
	task, err := uc.uow.Tasks().GetTask(taskID)
	if err != nil {
		return fmt.Errorf("task not found: %w", err)
	}
	
	// Check user owns the task
	userTasks, err := uc.uow.SystemState().GetUserTasks(*currentUser)
	if err != nil {
		return fmt.Errorf("failed to get user tasks: %w", err)
	}
	
	hasTask := false
	for _, id := range userTasks {
		if id == taskID {
			hasTask = true
			break
		}
	}
	
	if !hasTask {
		return fmt.Errorf("user does not have access to task %d", taskID)
	}
	
	// Check valid transition
	if !domain.IsValidTransition(task.Status, newStatus) {
		return fmt.Errorf("invalid transition from %s to %s", task.Status, newStatus)
	}
	
	// Check dependencies if moving to in_progress
	if newStatus == domain.StatusInProgress {
		allTasks, _ := uc.uow.Tasks().GetAllTasks()
		for depID := range task.Dependencies {
			if depTask, exists := allTasks[depID]; exists {
				if depTask.Status != domain.StatusCompleted {
					return fmt.Errorf("cannot start task: dependency %d is not completed", depID)
				}
			}
		}
	}
	
	// Update status
	task.Status = newStatus
	task.UpdatedAt = time.Now()
	
	if err := uc.uow.Tasks().UpdateTask(task); err != nil {
		return fmt.Errorf("failed to update task: %w", err)
	}
	
	// Check invariants
	state, _ := uc.uow.SystemState().GetSystemState()
	if err := uc.invariantChecker.CheckAllInvariants(state); err != nil {
		uc.uow.Rollback()
		return fmt.Errorf("invariant violation: %w", err)
	}
	
	return nil
}

// UpdateTaskPriority implements TLA+ UpdateTaskPriority action
func (uc *TaskUseCase) UpdateTaskPriority(taskID domain.TaskID, newPriority domain.Priority) error {
	currentUser, err := uc.uow.SystemState().GetCurrentUser()
	if err != nil || currentUser == nil {
		return fmt.Errorf("authentication required")
	}
	
	task, err := uc.uow.Tasks().GetTask(taskID)
	if err != nil {
		return fmt.Errorf("task not found: %w", err)
	}
	
	// Check user owns the task
	if task.Assignee != *currentUser {
		return fmt.Errorf("user does not have access to task %d", taskID)
	}
	
	task.Priority = newPriority
	task.UpdatedAt = time.Now()
	
	if err := uc.uow.Tasks().UpdateTask(task); err != nil {
		return fmt.Errorf("failed to update task priority: %w", err)
	}
	
	return nil
}

// ReassignTask implements TLA+ ReassignTask action
func (uc *TaskUseCase) ReassignTask(taskID domain.TaskID, newAssignee domain.UserID) error {
	currentUser, err := uc.uow.SystemState().GetCurrentUser()
	if err != nil || currentUser == nil {
		return fmt.Errorf("authentication required")
	}
	
	task, err := uc.uow.Tasks().GetTask(taskID)
	if err != nil {
		return fmt.Errorf("task not found: %w", err)
	}
	
	// Check user owns the task
	if task.Assignee != *currentUser && task.CreatedBy != *currentUser {
		return fmt.Errorf("user does not have permission to reassign task %d", taskID)
	}
	
	// Verify new assignee exists
	if _, err := uc.uow.Users().GetUser(newAssignee); err != nil {
		return fmt.Errorf("new assignee not found: %w", err)
	}
	
	oldAssignee := task.Assignee
	task.Assignee = newAssignee
	task.UpdatedAt = time.Now()
	
	// Update task
	if err := uc.uow.Tasks().UpdateTask(task); err != nil {
		return fmt.Errorf("failed to reassign task: %w", err)
	}
	
	// Update user task mappings
	uc.uow.SystemState().RemoveUserTask(oldAssignee, taskID)
	uc.uow.SystemState().AddUserTask(newAssignee, taskID)
	
	return nil
}

// UpdateTaskDetails implements TLA+ UpdateTaskDetails action
func (uc *TaskUseCase) UpdateTaskDetails(
	taskID domain.TaskID,
	title, description string,
	dueDate *time.Time,
) error {
	currentUser, err := uc.uow.SystemState().GetCurrentUser()
	if err != nil || currentUser == nil {
		return fmt.Errorf("authentication required")
	}
	
	task, err := uc.uow.Tasks().GetTask(taskID)
	if err != nil {
		return fmt.Errorf("task not found: %w", err)
	}
	
	// Check user owns the task
	if task.Assignee != *currentUser {
		return fmt.Errorf("user does not have access to task %d", taskID)
	}
	
	task.Title = title
	task.Description = description
	task.DueDate = dueDate
	task.UpdatedAt = time.Now()
	
	// Validate updated task
	if err := task.Validate(); err != nil {
		return fmt.Errorf("task validation failed: %w", err)
	}
	
	if err := uc.uow.Tasks().UpdateTask(task); err != nil {
		return fmt.Errorf("failed to update task details: %w", err)
	}
	
	return nil
}

// DeleteTask implements TLA+ DeleteTask action
func (uc *TaskUseCase) DeleteTask(taskID domain.TaskID) error {
	// Preconditions from TLA+:
	// - currentUser # NULL
	// - TaskExists(taskId)
	// - taskId \in GetUserTasks(currentUser)
	// - tasks[taskId].status \in {"completed", "cancelled"}
	// - No other tasks depend on this one
	
	currentUser, err := uc.uow.SystemState().GetCurrentUser()
	if err != nil || currentUser == nil {
		return fmt.Errorf("authentication required")
	}
	
	task, err := uc.uow.Tasks().GetTask(taskID)
	if err != nil {
		return fmt.Errorf("task not found: %w", err)
	}
	
	// Check user owns the task
	if task.Assignee != *currentUser {
		return fmt.Errorf("user does not have permission to delete task %d", taskID)
	}
	
	// Check task is completed or cancelled
	if !task.CanDelete() {
		return fmt.Errorf("can only delete completed or cancelled tasks")
	}
	
	// Check no other tasks depend on this one
	dependentTasks, err := uc.uow.Tasks().GetTasksByDependency(taskID)
	if err != nil {
		return fmt.Errorf("failed to check dependencies: %w", err)
	}
	
	if len(dependentTasks) > 0 {
		return fmt.Errorf("cannot delete task %d: %d tasks depend on it", taskID, len(dependentTasks))
	}
	
	// Delete task
	if err := uc.uow.Tasks().DeleteTask(taskID); err != nil {
		return fmt.Errorf("failed to delete task: %w", err)
	}
	
	return nil
}

// CheckDependencies implements TLA+ CheckDependencies action
func (uc *TaskUseCase) CheckDependencies() (int, error) {
	// Find all blocked tasks and check if they can be unblocked
	blockedTasks, err := uc.uow.Tasks().GetTasksByStatus(domain.StatusBlocked)
	if err != nil {
		return 0, fmt.Errorf("failed to get blocked tasks: %w", err)
	}
	
	allTasks, err := uc.uow.Tasks().GetAllTasks()
	if err != nil {
		return 0, fmt.Errorf("failed to get all tasks: %w", err)
	}
	
	unblockedCount := 0
	for _, task := range blockedTasks {
		if task.ShouldUnblock(allTasks) {
			task.Status = domain.StatusPending
			task.UpdatedAt = time.Now()
			
			if err := uc.uow.Tasks().UpdateTask(task); err != nil {
				return unblockedCount, fmt.Errorf("failed to unblock task %d: %w", task.ID, err)
			}
			unblockedCount++
		}
	}
	
	return unblockedCount, nil
}

// BulkUpdateStatus implements TLA+ BulkUpdateStatus action
func (uc *TaskUseCase) BulkUpdateStatus(taskIDs []domain.TaskID, newStatus domain.TaskStatus) error {
	currentUser, err := uc.uow.SystemState().GetCurrentUser()
	if err != nil || currentUser == nil {
		return fmt.Errorf("authentication required")
	}
	
	// Check all tasks exist and user has access
	for _, taskID := range taskIDs {
		task, err := uc.uow.Tasks().GetTask(taskID)
		if err != nil {
			return fmt.Errorf("task %d not found: %w", taskID, err)
		}
		
		if task.Assignee != *currentUser {
			return fmt.Errorf("user does not have access to task %d", taskID)
		}
		
		// Check valid transition
		if !domain.IsValidTransition(task.Status, newStatus) {
			return fmt.Errorf("invalid transition for task %d from %s to %s", taskID, task.Status, newStatus)
		}
	}
	
	// Perform bulk update
	if err := uc.uow.Tasks().BulkUpdateStatus(taskIDs, newStatus); err != nil {
		return fmt.Errorf("bulk update failed: %w", err)
	}
	
	// Check invariants
	state, _ := uc.uow.SystemState().GetSystemState()
	if err := uc.invariantChecker.CheckAllInvariants(state); err != nil {
		uc.uow.Rollback()
		return fmt.Errorf("invariant violation after bulk update: %w", err)
	}
	
	return nil
}

// Helper functions

func generateToken() string {
	b := make([]byte, 32)
	rand.Read(b)
	return hex.EncodeToString(b)
}

func (uc *TaskUseCase) checkCyclicDependencies(
	newTaskID domain.TaskID,
	dependencies map[domain.TaskID]bool,
	allTasks map[domain.TaskID]*domain.Task,
) error {
	// Build dependency graph and check for cycles
	visited := make(map[domain.TaskID]bool)
	recStack := make(map[domain.TaskID]bool)
	
	var hasCycle func(taskID domain.TaskID) bool
	hasCycle = func(taskID domain.TaskID) bool {
		visited[taskID] = true
		recStack[taskID] = true
		
		task, exists := allTasks[taskID]
		if !exists {
			// For new task being created
			if taskID == newTaskID {
				for depID := range dependencies {
					if !visited[depID] {
						if hasCycle(depID) {
							return true
						}
					} else if recStack[depID] {
						return true
					}
				}
			}
		} else {
			for depID := range task.Dependencies {
				if !visited[depID] {
					if hasCycle(depID) {
						return true
					}
				} else if recStack[depID] {
					return true
				}
			}
		}
		
		recStack[taskID] = false
		return false
	}
	
	// Check from the new task
	if hasCycle(newTaskID) {
		return fmt.Errorf("cyclic dependency detected")
	}
	
	return nil
}
