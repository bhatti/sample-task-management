// Package memory provides an in-memory implementation of the repository interfaces
package memory

import (
	"fmt"
	"sync"
	"time"
	
	"github.com/bhatti/sample-task-management/internal/domain"
	"github.com/bhatti/sample-task-management/internal/repository"
)

// MemoryRepository is an in-memory implementation with thread-safety
type MemoryRepository struct {
	mu          sync.RWMutex
	tasks       map[domain.TaskID]*domain.Task
	users       map[domain.UserID]*domain.User
	sessions    map[string]*domain.Session
	userTasks   map[domain.UserID]map[domain.TaskID]bool
	nextTaskID  domain.TaskID
	currentUser *domain.UserID
	clock       time.Time
}

// NewMemoryRepository creates a new in-memory repository
func NewMemoryRepository() *MemoryRepository {
	return &MemoryRepository{
		tasks:      make(map[domain.TaskID]*domain.Task),
		users:      make(map[domain.UserID]*domain.User),
		sessions:   make(map[string]*domain.Session),
		userTasks:  make(map[domain.UserID]map[domain.TaskID]bool),
		nextTaskID: 1,
		clock:      time.Now(),
	}
}

// Task Repository Implementation

func (r *MemoryRepository) CreateTask(task *domain.Task) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	if task.ID == 0 {
		task.ID = r.nextTaskID
		r.nextTaskID++
	}
	
	if _, exists := r.tasks[task.ID]; exists {
		return fmt.Errorf("task with ID %d already exists", task.ID)
	}
	
	r.tasks[task.ID] = task
	
	// Update user tasks mapping
	if r.userTasks[task.Assignee] == nil {
		r.userTasks[task.Assignee] = make(map[domain.TaskID]bool)
	}
	r.userTasks[task.Assignee][task.ID] = true
	
	return nil
}

func (r *MemoryRepository) GetTask(id domain.TaskID) (*domain.Task, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	
	task, exists := r.tasks[id]
	if !exists {
		return nil, fmt.Errorf("task with ID %d not found", id)
	}
	
	// Return a copy to prevent external modifications
	taskCopy := *task
	return &taskCopy, nil
}

func (r *MemoryRepository) UpdateTask(task *domain.Task) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	existing, exists := r.tasks[task.ID]
	if !exists {
		return fmt.Errorf("task with ID %d not found", task.ID)
	}
	
	// Handle assignee change
	if existing.Assignee != task.Assignee {
		// Remove from old assignee
		if r.userTasks[existing.Assignee] != nil {
			delete(r.userTasks[existing.Assignee], task.ID)
		}
		
		// Add to new assignee
		if r.userTasks[task.Assignee] == nil {
			r.userTasks[task.Assignee] = make(map[domain.TaskID]bool)
		}
		r.userTasks[task.Assignee][task.ID] = true
	}
	
	r.tasks[task.ID] = task
	return nil
}

func (r *MemoryRepository) DeleteTask(id domain.TaskID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	task, exists := r.tasks[id]
	if !exists {
		return fmt.Errorf("task with ID %d not found", id)
	}
	
	// Remove from user tasks
	if r.userTasks[task.Assignee] != nil {
		delete(r.userTasks[task.Assignee], id)
	}
	
	delete(r.tasks, id)
	return nil
}

func (r *MemoryRepository) GetAllTasks() (map[domain.TaskID]*domain.Task, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	
	// Return a copy of the map
	tasksCopy := make(map[domain.TaskID]*domain.Task)
	for id, task := range r.tasks {
		taskCopy := *task
		tasksCopy[id] = &taskCopy
	}
	
	return tasksCopy, nil
}

func (r *MemoryRepository) GetTasksByUser(userID domain.UserID) ([]*domain.Task, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	
	var userTaskList []*domain.Task
	
	if taskIDs, exists := r.userTasks[userID]; exists {
		for taskID := range taskIDs {
			if task, taskExists := r.tasks[taskID]; taskExists {
				taskCopy := *task
				userTaskList = append(userTaskList, &taskCopy)
			}
		}
	}
	
	return userTaskList, nil
}

func (r *MemoryRepository) GetTasksByStatus(status domain.TaskStatus) ([]*domain.Task, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	
	var statusTasks []*domain.Task
	for _, task := range r.tasks {
		if task.Status == status {
			taskCopy := *task
			statusTasks = append(statusTasks, &taskCopy)
		}
	}
	
	return statusTasks, nil
}

func (r *MemoryRepository) GetTasksByDependency(taskID domain.TaskID) ([]*domain.Task, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	
	var dependentTasks []*domain.Task
	for _, task := range r.tasks {
		if _, hasDep := task.Dependencies[taskID]; hasDep {
			taskCopy := *task
			dependentTasks = append(dependentTasks, &taskCopy)
		}
	}
	
	return dependentTasks, nil
}

func (r *MemoryRepository) BulkUpdateStatus(taskIDs []domain.TaskID, status domain.TaskStatus) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	for _, id := range taskIDs {
		if task, exists := r.tasks[id]; exists {
			task.Status = status
			task.UpdatedAt = time.Now()
		}
	}
	
	return nil
}

// User Repository Implementation

func (r *MemoryRepository) CreateUser(user *domain.User) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	if _, exists := r.users[user.ID]; exists {
		return fmt.Errorf("user with ID %s already exists", user.ID)
	}
	
	r.users[user.ID] = user
	return nil
}

func (r *MemoryRepository) GetUser(id domain.UserID) (*domain.User, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	
	user, exists := r.users[id]
	if !exists {
		return nil, fmt.Errorf("user with ID %s not found", id)
	}
	
	userCopy := *user
	return &userCopy, nil
}

func (r *MemoryRepository) GetAllUsers() ([]*domain.User, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	
	var userList []*domain.User
	for _, user := range r.users {
		userCopy := *user
		userList = append(userList, &userCopy)
	}
	
	return userList, nil
}

func (r *MemoryRepository) UpdateUser(user *domain.User) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	if _, exists := r.users[user.ID]; !exists {
		return fmt.Errorf("user with ID %s not found", user.ID)
	}
	
	r.users[user.ID] = user
	return nil
}

func (r *MemoryRepository) DeleteUser(id domain.UserID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	if _, exists := r.users[id]; !exists {
		return fmt.Errorf("user with ID %s not found", id)
	}
	
	delete(r.users, id)
	return nil
}

// Session Repository Implementation

func (r *MemoryRepository) CreateSession(session *domain.Session) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	if _, exists := r.sessions[session.Token]; exists {
		return fmt.Errorf("session with token already exists")
	}
	
	r.sessions[session.Token] = session
	return nil
}

func (r *MemoryRepository) GetSession(token string) (*domain.Session, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	
	session, exists := r.sessions[token]
	if !exists {
		return nil, fmt.Errorf("session not found")
	}
	
	sessionCopy := *session
	return &sessionCopy, nil
}

func (r *MemoryRepository) GetSessionByUser(userID domain.UserID) (*domain.Session, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	
	for _, session := range r.sessions {
		if session.UserID == userID && session.IsValid() {
			sessionCopy := *session
			return &sessionCopy, nil
		}
	}
	
	return nil, fmt.Errorf("no active session for user %s", userID)
}

func (r *MemoryRepository) UpdateSession(session *domain.Session) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	if _, exists := r.sessions[session.Token]; !exists {
		return fmt.Errorf("session not found")
	}
	
	r.sessions[session.Token] = session
	return nil
}

func (r *MemoryRepository) DeleteSession(token string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	if _, exists := r.sessions[token]; !exists {
		return fmt.Errorf("session not found")
	}
	
	delete(r.sessions, token)
	return nil
}

func (r *MemoryRepository) DeleteUserSessions(userID domain.UserID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	for token, session := range r.sessions {
		if session.UserID == userID {
			delete(r.sessions, token)
		}
	}
	
	return nil
}

func (r *MemoryRepository) GetActiveSessions() ([]*domain.Session, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	
	var activeSessions []*domain.Session
	for _, session := range r.sessions {
		if session.IsValid() {
			sessionCopy := *session
			activeSessions = append(activeSessions, &sessionCopy)
		}
	}
	
	return activeSessions, nil
}

// System State Repository Implementation

func (r *MemoryRepository) GetSystemState() (*domain.SystemState, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	
	state := &domain.SystemState{
		Tasks:       make(map[domain.TaskID]*domain.Task),
		UserTasks:   make(map[domain.UserID][]domain.TaskID),
		NextTaskID:  r.nextTaskID,
		CurrentUser: r.currentUser,
		Clock:       r.clock,
		Sessions:    make(map[domain.UserID]*domain.Session),
	}
	
	// Copy tasks
	for id, task := range r.tasks {
		taskCopy := *task
		state.Tasks[id] = &taskCopy
	}
	
	// Copy user tasks
	for userID, taskIDs := range r.userTasks {
		for taskID := range taskIDs {
			state.UserTasks[userID] = append(state.UserTasks[userID], taskID)
		}
	}
	
	// Copy sessions
	for _, session := range r.sessions {
		if session.IsValid() {
			sessionCopy := *session
			state.Sessions[session.UserID] = &sessionCopy
		}
	}
	
	return state, nil
}

func (r *MemoryRepository) SaveSystemState(state *domain.SystemState) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	// Clear and rebuild state
	r.tasks = make(map[domain.TaskID]*domain.Task)
	r.userTasks = make(map[domain.UserID]map[domain.TaskID]bool)
	r.sessions = make(map[string]*domain.Session)
	
	// Copy tasks
	for id, task := range state.Tasks {
		taskCopy := *task
		r.tasks[id] = &taskCopy
	}
	
	// Rebuild user tasks
	for userID, taskIDs := range state.UserTasks {
		r.userTasks[userID] = make(map[domain.TaskID]bool)
		for _, taskID := range taskIDs {
			r.userTasks[userID][taskID] = true
		}
	}
	
	// Copy sessions
	for _, session := range state.Sessions {
		sessionCopy := *session
		r.sessions[session.Token] = &sessionCopy
	}
	
	r.nextTaskID = state.NextTaskID
	r.currentUser = state.CurrentUser
	r.clock = state.Clock
	
	return nil
}

func (r *MemoryRepository) GetNextTaskID() (domain.TaskID, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	
	return r.nextTaskID, nil
}

func (r *MemoryRepository) IncrementNextTaskID() (domain.TaskID, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	currentID := r.nextTaskID
	r.nextTaskID++
	return currentID, nil
}

func (r *MemoryRepository) GetCurrentUser() (*domain.UserID, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	
	return r.currentUser, nil
}

func (r *MemoryRepository) SetCurrentUser(userID *domain.UserID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	r.currentUser = userID
	return nil
}

func (r *MemoryRepository) GetUserTasks(userID domain.UserID) ([]domain.TaskID, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	
	var taskList []domain.TaskID
	if taskIDs, exists := r.userTasks[userID]; exists {
		for taskID := range taskIDs {
			taskList = append(taskList, taskID)
		}
	}
	
	return taskList, nil
}

func (r *MemoryRepository) AddUserTask(userID domain.UserID, taskID domain.TaskID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	if r.userTasks[userID] == nil {
		r.userTasks[userID] = make(map[domain.TaskID]bool)
	}
	r.userTasks[userID][taskID] = true
	
	return nil
}

func (r *MemoryRepository) RemoveUserTask(userID domain.UserID, taskID domain.TaskID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	if r.userTasks[userID] != nil {
		delete(r.userTasks[userID], taskID)
	}
	
	return nil
}

// UnitOfWork implementation
type MemoryUnitOfWork struct {
	repo *MemoryRepository
}

func NewMemoryUnitOfWork(repo *MemoryRepository) repository.UnitOfWork {
	return &MemoryUnitOfWork{repo: repo}
}

func (u *MemoryUnitOfWork) Begin() error {
	// No-op for in-memory implementation
	return nil
}

func (u *MemoryUnitOfWork) Commit() error {
	// No-op for in-memory implementation
	return nil
}

func (u *MemoryUnitOfWork) Rollback() error {
	// No-op for in-memory implementation
	return nil
}

func (u *MemoryUnitOfWork) Tasks() repository.TaskRepository {
	return u.repo
}

func (u *MemoryUnitOfWork) Users() repository.UserRepository {
	return u.repo
}

func (u *MemoryUnitOfWork) Sessions() repository.SessionRepository {
	return u.repo
}

func (u *MemoryUnitOfWork) SystemState() repository.SystemStateRepository {
	return u.repo
}
