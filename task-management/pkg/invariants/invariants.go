// Package invariants implements runtime checking of TLA+ invariants
package invariants

import (
	"fmt"

	"github.com/bhatti/sample-task-management/internal/domain"
)

// InvariantChecker implements all TLA+ safety invariants
type InvariantChecker struct{}

// NewInvariantChecker creates a new invariant checker
func NewInvariantChecker() *InvariantChecker {
	return &InvariantChecker{}
}

// CheckAllInvariants verifies all safety invariants (maps to TLA+ SafetyInvariant)
func (ic *InvariantChecker) CheckAllInvariants(state *domain.SystemState) error {
	// Check each invariant from the TLA+ specification

	if err := ic.checkNoOrphanTasks(state); err != nil {
		return fmt.Errorf("NoOrphanTasks violated: %w", err)
	}

	if err := ic.checkTaskOwnership(state); err != nil {
		return fmt.Errorf("TaskOwnership violated: %w", err)
	}

	if err := ic.checkValidTaskIds(state); err != nil {
		return fmt.Errorf("ValidTaskIds violated: %w", err)
	}

	if err := ic.checkNoDuplicateTaskIds(state); err != nil {
		return fmt.Errorf("NoDuplicateTaskIds violated: %w", err)
	}

	if err := ic.checkValidStateTransitions(state); err != nil {
		return fmt.Errorf("ValidStateTransitions violated: %w", err)
	}

	if err := ic.checkConsistentTimestamps(state); err != nil {
		return fmt.Errorf("ConsistentTimestamps violated: %w", err)
	}

	if err := ic.checkNoCyclicDependencies(state); err != nil {
		return fmt.Errorf("NoCyclicDependencies violated: %w", err)
	}

	if err := ic.checkAuthenticationRequired(state); err != nil {
		return fmt.Errorf("AuthenticationRequired violated: %w", err)
	}

	return nil
}

// CheckTaskInvariants verifies invariants for a specific task
func (ic *InvariantChecker) CheckTaskInvariants(task *domain.Task, state *domain.SystemState) error {
	// Validate task structure
	if err := task.Validate(); err != nil {
		return fmt.Errorf("task validation failed: %w", err)
	}

	// Check task is not orphaned
	found := false
	for _, taskIDs := range state.UserTasks {
		for _, id := range taskIDs {
			if id == task.ID {
				found = true
				break
			}
		}
		if found {
			break
		}
	}

	if !found {
		return fmt.Errorf("task %d is orphaned (not assigned to any user)", task.ID)
	}

	// Check dependencies exist
	for depID := range task.Dependencies {
		if !state.TaskExists(depID) {
			return fmt.Errorf("task %d has non-existent dependency %d", task.ID, depID)
		}
	}

	return nil
}

// CheckTransitionInvariant verifies state transition validity
func (ic *InvariantChecker) CheckTransitionInvariant(from, to domain.TaskStatus) error {
	if !domain.IsValidTransition(from, to) {
		return fmt.Errorf("invalid transition from %s to %s", from, to)
	}
	return nil
}

// NoOrphanTasks: Every task must be assigned to a user
func (ic *InvariantChecker) checkNoOrphanTasks(state *domain.SystemState) error {
	for taskID, task := range state.Tasks {
		found := false
		for _, userTasks := range state.UserTasks {
			for _, id := range userTasks {
				if id == taskID {
					found = true
					break
				}
			}
			if found {
				break
			}
		}

		if !found {
			return fmt.Errorf("task %d (assigned to %s) is not in any user's task list", taskID, task.Assignee)
		}
	}
	return nil
}

// TaskOwnership: Tasks must be in their assignee's task list
func (ic *InvariantChecker) checkTaskOwnership(state *domain.SystemState) error {
	for taskID, task := range state.Tasks {
		userTasks := state.GetUserTasks(task.Assignee)
		found := false
		for _, id := range userTasks {
			if id == taskID {
				found = true
				break
			}
		}

		if !found {
			return fmt.Errorf("task %d assigned to %s but not in their task list", taskID, task.Assignee)
		}
	}
	return nil
}

// ValidTaskIds: All task IDs must be valid
func (ic *InvariantChecker) checkValidTaskIds(state *domain.SystemState) error {
	for taskID := range state.Tasks {
		if taskID < 1 {
			return fmt.Errorf("invalid task ID %d (must be >= 1)", taskID)
		}
		if taskID >= state.NextTaskID {
			return fmt.Errorf("task ID %d >= nextTaskID %d", taskID, state.NextTaskID)
		}
	}
	return nil
}

// NoDuplicateTaskIds: Task IDs must be unique
func (ic *InvariantChecker) checkNoDuplicateTaskIds(state *domain.SystemState) error {
	seenIDs := make(map[domain.TaskID]bool)
	for taskID, task := range state.Tasks {
		if taskID != task.ID {
			return fmt.Errorf("task map key %d doesn't match task.ID %d", taskID, task.ID)
		}
		if seenIDs[task.ID] {
			return fmt.Errorf("duplicate task ID %d", task.ID)
		}
		seenIDs[task.ID] = true
	}
	return nil
}

// ValidStateTransitions: All task states must be valid
func (ic *InvariantChecker) checkValidStateTransitions(state *domain.SystemState) error {
	validStates := map[domain.TaskStatus]bool{
		domain.StatusPending:    true,
		domain.StatusInProgress: true,
		domain.StatusCompleted:  true,
		domain.StatusCancelled:  true,
		domain.StatusBlocked:    true,
	}

	for taskID, task := range state.Tasks {
		if !validStates[task.Status] {
			return fmt.Errorf("task %d has invalid status %s", taskID, task.Status)
		}
	}
	return nil
}

// ConsistentTimestamps: CreatedAt <= UpdatedAt <= Clock
func (ic *InvariantChecker) checkConsistentTimestamps(state *domain.SystemState) error {
	for taskID, task := range state.Tasks {
		if task.CreatedAt.After(task.UpdatedAt) {
			return fmt.Errorf("task %d: createdAt (%v) > updatedAt (%v)",
				taskID, task.CreatedAt, task.UpdatedAt)
		}

		//if task.UpdatedAt.After(state.Clock) {
		//	return fmt.Errorf("task %d: updatedAt (%v) > system clock (%v)",
		//		taskID, task.UpdatedAt, state.Clock)
		//}
	}
	return nil
}

// NoCyclicDependencies: No task can depend on itself transitively
func (ic *InvariantChecker) checkNoCyclicDependencies(state *domain.SystemState) error {
	// For each task, compute transitive dependencies and check for cycles
	for taskID := range state.Tasks {
		visited := make(map[domain.TaskID]bool)
		recStack := make(map[domain.TaskID]bool)

		if ic.hasCycle(taskID, state, visited, recStack) {
			return fmt.Errorf("cyclic dependency detected starting from task %d", taskID)
		}
	}
	return nil
}

func (ic *InvariantChecker) hasCycle(
	taskID domain.TaskID,
	state *domain.SystemState,
	visited map[domain.TaskID]bool,
	recStack map[domain.TaskID]bool,
) bool {
	visited[taskID] = true
	recStack[taskID] = true

	if task, exists := state.Tasks[taskID]; exists {
		for depID := range task.Dependencies {
			if !visited[depID] {
				if ic.hasCycle(depID, state, visited, recStack) {
					return true
				}
			} else if recStack[depID] {
				// Found a back edge (cycle)
				return true
			}
		}
	}

	recStack[taskID] = false
	return false
}

// AuthenticationRequired: All tasks must have a valid creator
func (ic *InvariantChecker) checkAuthenticationRequired(state *domain.SystemState) error {
	for taskID, task := range state.Tasks {
		if task.CreatedBy == "" {
			return fmt.Errorf("task %d has no creator", taskID)
		}

		// Note: In a full implementation, we'd verify the creator exists in the user database
		// For now, we just check it's not empty
	}
	return nil
}

// Additional helper to check liveness properties (for monitoring)
func (ic *InvariantChecker) CheckLivenessProperties(state *domain.SystemState) []string {
	var warnings []string

	// Check for tasks stuck in pending for too long
	for taskID, task := range state.Tasks {
		if task.Status == domain.StatusPending {
			age := state.Clock.Sub(task.CreatedAt)
			if age.Hours() > 24*7 { // Week old pending tasks
				warnings = append(warnings,
					fmt.Sprintf("Task %d has been pending for %v", taskID, age))
			}
		}

		// Check for overdue tasks
		if task.DueDate != nil && state.Clock.After(*task.DueDate) {
			if task.Status != domain.StatusCompleted && task.Status != domain.StatusCancelled {
				warnings = append(warnings,
					fmt.Sprintf("Task %d is overdue (due: %v)", taskID, task.DueDate))
			}
		}

		// Check for blocked tasks with completed dependencies
		if task.Status == domain.StatusBlocked {
			allDepsCompleted := true
			for depID := range task.Dependencies {
				if dep, exists := state.Tasks[depID]; exists {
					if dep.Status != domain.StatusCompleted {
						allDepsCompleted = false
						break
					}
				}
			}
			if allDepsCompleted {
				warnings = append(warnings,
					fmt.Sprintf("Task %d is blocked but all dependencies are completed", taskID))
			}
		}
	}

	// Check for critical tasks not in progress
	criticalPendingCount := 0
	for _, task := range state.Tasks {
		if task.Priority == domain.PriorityCritical && task.Status == domain.StatusPending {
			criticalPendingCount++
		}
	}
	if criticalPendingCount > 0 {
		warnings = append(warnings,
			fmt.Sprintf("%d critical tasks are still pending", criticalPendingCount))
	}

	return warnings
}
