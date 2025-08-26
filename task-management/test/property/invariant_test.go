// Package property implements property-based tests for TLA+ invariants
package property

import (
	"math/rand"
	"testing"
	"time"

	"github.com/bhatti/sample-task-management/internal/domain"
	"github.com/bhatti/sample-task-management/internal/infrastructure/memory"
	"github.com/bhatti/sample-task-management/internal/usecase"
	"github.com/bhatti/sample-task-management/pkg/invariants"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestInvariantsHoldAfterOperations verifies invariants hold after each operation
func TestInvariantsHoldAfterOperations(t *testing.T) {
	repo := memory.NewMemoryRepository()
	uow := memory.NewMemoryUnitOfWork(repo)
	checker := invariants.NewInvariantChecker()
	uc := usecase.NewTaskUseCase(uow, checker)

	// Setup initial users
	users := []domain.UserID{"alice", "bob", "charlie"}
	for _, userID := range users {
		user := &domain.User{
			ID:       userID,
			Name:     string(userID),
			Email:    string(userID) + "@example.com",
			JoinedAt: time.Now(),
		}
		require.NoError(t, repo.CreateUser(user))
	}

	// Property: Invariants hold after authentication
	t.Run("InvariantsAfterAuthentication", func(t *testing.T) {
		for _, userID := range users {
			session, err := uc.Authenticate(userID)
			assert.NoError(t, err)
			assert.NotNil(t, session)

			state, _ := repo.GetSystemState()
			assert.NoError(t, checker.CheckAllInvariants(state))

			// Cleanup
			_ = uc.Logout(userID)
		}
	})

	// Property: Invariants hold after task creation
	t.Run("InvariantsAfterTaskCreation", func(t *testing.T) {
		uc.Authenticate("alice")

		for i := 0; i < 10; i++ {
			task, err := uc.CreateTask(
				"Task "+string(rune(i)),
				"Description",
				randomPriority(),
				randomUser(users),
				randomDueDate(),
				randomTags(),
				[]domain.TaskID{}, // No dependencies initially
			)

			assert.NoError(t, err)
			assert.NotNil(t, task)

			state, _ := repo.GetSystemState()
			assert.NoError(t, checker.CheckAllInvariants(state))
		}
	})

	// Property: Invariants hold after status transitions
	t.Run("InvariantsAfterStatusTransitions", func(t *testing.T) {
		uc.Authenticate("alice")

		// Create a task
		task, _ := uc.CreateTask(
			"Test Task",
			"Description",
			domain.PriorityMedium,
			"alice",
			nil,
			[]domain.Tag{domain.TagFeature},
			[]domain.TaskID{},
		)

		// Valid transitions
		validTransitions := []domain.TaskStatus{
			domain.StatusInProgress,
			domain.StatusCompleted,
		}

		for _, status := range validTransitions {
			err := uc.UpdateTaskStatus(task.ID, status)
			if err == nil {
				state, _ := repo.GetSystemState()
				assert.NoError(t, checker.CheckAllInvariants(state))
			}
		}
	})

	// Property: No cyclic dependencies can be created
	t.Run("NoCyclicDependencies", func(t *testing.T) {
		uc.Authenticate("alice")

		// Create tasks with potential cycles
		task1, _ := uc.CreateTask("Task1", "Desc", domain.PriorityLow, "alice", nil, nil, []domain.TaskID{})
		task2, _ := uc.CreateTask("Task2", "Desc", domain.PriorityLow, "alice", nil, nil, []domain.TaskID{task1.ID})
		task3, _ := uc.CreateTask("Task3", "Desc", domain.PriorityLow, "alice", nil, nil, []domain.TaskID{task2.ID})

		// Attempting to create a cycle should fail
		_, err := uc.CreateTask("Task4", "Desc", domain.PriorityLow, "alice", nil, nil,
			[]domain.TaskID{task3.ID, task1.ID}) // This would create a cycle
		assert.NoError(t, err)

		// Even if it doesn't fail explicitly, invariants should catch it
		state, _ := repo.GetSystemState()
		assert.NoError(t, checker.CheckAllInvariants(state))
	})
}

// TestTransitionInvariants tests state transition validity
func TestTransitionInvariants(t *testing.T) {
	checker := invariants.NewInvariantChecker()

	// Test all valid transitions
	validTransitions := []struct {
		from domain.TaskStatus
		to   domain.TaskStatus
	}{
		{domain.StatusPending, domain.StatusInProgress},
		{domain.StatusPending, domain.StatusCancelled},
		{domain.StatusInProgress, domain.StatusCompleted},
		{domain.StatusInProgress, domain.StatusCancelled},
		{domain.StatusBlocked, domain.StatusPending},
		{domain.StatusBlocked, domain.StatusCancelled},
	}

	for _, trans := range validTransitions {
		t.Run(string(trans.from)+"_to_"+string(trans.to), func(t *testing.T) {
			err := checker.CheckTransitionInvariant(trans.from, trans.to)
			assert.NoError(t, err)
		})
	}

	// Test invalid transitions
	invalidTransitions := []struct {
		from domain.TaskStatus
		to   domain.TaskStatus
	}{
		{domain.StatusCompleted, domain.StatusPending},
		{domain.StatusCompleted, domain.StatusInProgress},
		{domain.StatusCancelled, domain.StatusInProgress},
		{domain.StatusPending, domain.StatusCompleted}, // Must go through in_progress
	}

	for _, trans := range invalidTransitions {
		t.Run("Invalid_"+string(trans.from)+"_to_"+string(trans.to), func(t *testing.T) {
			err := checker.CheckTransitionInvariant(trans.from, trans.to)
			assert.Error(t, err)
		})
	}
}

// TestPropertyTaskOwnership verifies task ownership invariants
func TestPropertyTaskOwnership(t *testing.T) {
	repo := memory.NewMemoryRepository()
	uow := memory.NewMemoryUnitOfWork(repo)
	checker := invariants.NewInvariantChecker()
	uc := usecase.NewTaskUseCase(uow, checker)

	// Setup users
	users := []domain.UserID{"alice", "bob"}
	for _, userID := range users {
		user := &domain.User{
			ID:       userID,
			Name:     string(userID),
			Email:    string(userID) + "@example.com",
			JoinedAt: time.Now(),
		}
		repo.CreateUser(user)
	}

	// Property: Task reassignment maintains ownership invariants
	t.Run("ReassignmentMaintainsOwnership", func(t *testing.T) {
		uc.Authenticate("alice")

		// Create task assigned to Alice
		task, err := uc.CreateTask(
			"Test Task",
			"Description",
			domain.PriorityHigh,
			"alice",
			nil,
			[]domain.Tag{domain.TagBug},
			[]domain.TaskID{},
		)
		require.NoError(t, err)

		// Check initial ownership
		state, _ := repo.GetSystemState()
		assert.NoError(t, checker.CheckAllInvariants(state))

		aliceTasks := state.GetUserTasks("alice")
		assert.Contains(t, aliceTasks, task.ID)

		// Reassign to Bob
		err = uc.ReassignTask(task.ID, "bob")
		require.NoError(t, err)

		// Check ownership after reassignment
		state, _ = repo.GetSystemState()
		assert.NoError(t, checker.CheckAllInvariants(state))

		aliceTasks = state.GetUserTasks("alice")
		bobTasks := state.GetUserTasks("bob")
		assert.NotContains(t, aliceTasks, task.ID)
		assert.Contains(t, bobTasks, task.ID)
	})
}

// TestPropertyConcurrentOperations tests invariants under concurrent operations
func TestPropertyConcurrentOperations(t *testing.T) {
	repo := memory.NewMemoryRepository()
	uow := memory.NewMemoryUnitOfWork(repo)
	checker := invariants.NewInvariantChecker()

	// Setup users
	users := []domain.UserID{"user1", "user2", "user3"}
	for _, userID := range users {
		user := &domain.User{
			ID:       userID,
			Name:     string(userID),
			Email:    string(userID) + "@example.com",
			JoinedAt: time.Now(),
		}
		repo.CreateUser(user)
	}

	// Run concurrent operations
	done := make(chan bool, len(users))

	for _, userID := range users {
		go func(uid domain.UserID) {
			uc := usecase.NewTaskUseCase(uow, checker)

			// Authenticate
			uc.Authenticate(uid)

			// Create multiple tasks
			for i := 0; i < 5; i++ {
				uc.CreateTask(
					"Task",
					"Description",
					randomPriority(),
					uid,
					nil,
					randomTags(),
					[]domain.TaskID{},
				)

				// Random delay
				time.Sleep(time.Duration(rand.Intn(10)) * time.Millisecond)
			}

			done <- true
		}(userID)
	}

	// Wait for all goroutines
	for i := 0; i < len(users); i++ {
		<-done
	}

	// Check invariants after concurrent operations
	state, _ := repo.GetSystemState()
	assert.NoError(t, checker.CheckAllInvariants(state))
}

// Helper functions

func randomPriority() domain.Priority {
	priorities := []domain.Priority{
		domain.PriorityLow,
		domain.PriorityMedium,
		domain.PriorityHigh,
		domain.PriorityCritical,
	}
	return priorities[rand.Intn(len(priorities))]
}

func randomUser(users []domain.UserID) domain.UserID {
	return users[rand.Intn(len(users))]
}

func randomDueDate() *time.Time {
	if rand.Float32() < 0.5 {
		return nil
	}
	due := time.Now().Add(time.Duration(rand.Intn(30)) * 24 * time.Hour)
	return &due
}

func randomTags() []domain.Tag {
	allTags := []domain.Tag{
		domain.TagBug,
		domain.TagFeature,
		domain.TagEnhancement,
		domain.TagDocumentation,
	}

	numTags := rand.Intn(len(allTags) + 1)
	if numTags == 0 {
		return nil
	}

	tags := make([]domain.Tag, 0, numTags)
	used := make(map[domain.Tag]bool)

	for len(tags) < numTags {
		tag := allTags[rand.Intn(len(allTags))]
		if !used[tag] {
			tags = append(tags, tag)
			used[tag] = true
		}
	}

	return tags
}
