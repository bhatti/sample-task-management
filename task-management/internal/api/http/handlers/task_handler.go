// Package handlers implements HTTP handlers for the REST API
package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"
	
	"github.com/gorilla/mux"
	"github.com/bhatti/sample-task-management/internal/domain"
	"github.com/bhatti/sample-task-management/internal/usecase"
)

// TaskHandler handles HTTP requests for task operations
type TaskHandler struct {
	taskUseCase *usecase.TaskUseCase
}

// NewTaskHandler creates a new task handler
func NewTaskHandler(taskUseCase *usecase.TaskUseCase) *TaskHandler {
	return &TaskHandler{
		taskUseCase: taskUseCase,
	}
}

// CreateTaskRequest represents the request body for creating a task
type CreateTaskRequest struct {
	Title        string            `json:"title"`
	Description  string            `json:"description"`
	Priority     domain.Priority   `json:"priority"`
	Assignee     domain.UserID     `json:"assignee"`
	DueDate      *time.Time        `json:"due_date,omitempty"`
	Tags         []domain.Tag      `json:"tags"`
	Dependencies []domain.TaskID   `json:"dependencies"`
}

// UpdateStatusRequest represents the request body for updating task status
type UpdateStatusRequest struct {
	Status domain.TaskStatus `json:"status"`
}

// UpdatePriorityRequest represents the request body for updating task priority
type UpdatePriorityRequest struct {
	Priority domain.Priority `json:"priority"`
}

// ReassignTaskRequest represents the request body for reassigning a task
type ReassignTaskRequest struct {
	Assignee domain.UserID `json:"assignee"`
}

// UpdateDetailsRequest represents the request body for updating task details
type UpdateDetailsRequest struct {
	Title       string     `json:"title"`
	Description string     `json:"description"`
	DueDate     *time.Time `json:"due_date,omitempty"`
}

// BulkUpdateRequest represents the request body for bulk status updates
type BulkUpdateRequest struct {
	TaskIDs []domain.TaskID   `json:"task_ids"`
	Status  domain.TaskStatus `json:"status"`
}

// LoginRequest represents the request body for authentication
type LoginRequest struct {
	UserID domain.UserID `json:"user_id"`
}

// ErrorResponse represents an error response
type ErrorResponse struct {
	Error   string `json:"error"`
	Details string `json:"details,omitempty"`
}

// CreateTask handles POST /tasks
func (h *TaskHandler) CreateTask(w http.ResponseWriter, r *http.Request) {
	var req CreateTaskRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.sendError(w, http.StatusBadRequest, "Invalid request body", err.Error())
		return
	}
	
	task, err := h.taskUseCase.CreateTask(
		req.Title,
		req.Description,
		req.Priority,
		req.Assignee,
		req.DueDate,
		req.Tags,
		req.Dependencies,
	)
	
	if err != nil {
		h.sendError(w, http.StatusBadRequest, "Failed to create task", err.Error())
		return
	}
	
	h.sendJSON(w, http.StatusCreated, task)
}

// UpdateTaskStatus handles PUT /tasks/{id}/status
func (h *TaskHandler) UpdateTaskStatus(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	taskID, err := strconv.Atoi(vars["id"])
	if err != nil {
		h.sendError(w, http.StatusBadRequest, "Invalid task ID", err.Error())
		return
	}
	
	var req UpdateStatusRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.sendError(w, http.StatusBadRequest, "Invalid request body", err.Error())
		return
	}
	
	if err := h.taskUseCase.UpdateTaskStatus(domain.TaskID(taskID), req.Status); err != nil {
		h.sendError(w, http.StatusBadRequest, "Failed to update task status", err.Error())
		return
	}
	
	h.sendJSON(w, http.StatusOK, map[string]string{"message": "Task status updated successfully"})
}

// UpdateTaskPriority handles PUT /tasks/{id}/priority
func (h *TaskHandler) UpdateTaskPriority(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	taskID, err := strconv.Atoi(vars["id"])
	if err != nil {
		h.sendError(w, http.StatusBadRequest, "Invalid task ID", err.Error())
		return
	}
	
	var req UpdatePriorityRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.sendError(w, http.StatusBadRequest, "Invalid request body", err.Error())
		return
	}
	
	if err := h.taskUseCase.UpdateTaskPriority(domain.TaskID(taskID), req.Priority); err != nil {
		h.sendError(w, http.StatusBadRequest, "Failed to update task priority", err.Error())
		return
	}
	
	h.sendJSON(w, http.StatusOK, map[string]string{"message": "Task priority updated successfully"})
}

// ReassignTask handles PUT /tasks/{id}/reassign
func (h *TaskHandler) ReassignTask(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	taskID, err := strconv.Atoi(vars["id"])
	if err != nil {
		h.sendError(w, http.StatusBadRequest, "Invalid task ID", err.Error())
		return
	}
	
	var req ReassignTaskRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.sendError(w, http.StatusBadRequest, "Invalid request body", err.Error())
		return
	}
	
	if err := h.taskUseCase.ReassignTask(domain.TaskID(taskID), req.Assignee); err != nil {
		h.sendError(w, http.StatusBadRequest, "Failed to reassign task", err.Error())
		return
	}
	
	h.sendJSON(w, http.StatusOK, map[string]string{"message": "Task reassigned successfully"})
}

// UpdateTaskDetails handles PUT /tasks/{id}/details
func (h *TaskHandler) UpdateTaskDetails(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	taskID, err := strconv.Atoi(vars["id"])
	if err != nil {
		h.sendError(w, http.StatusBadRequest, "Invalid task ID", err.Error())
		return
	}
	
	var req UpdateDetailsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.sendError(w, http.StatusBadRequest, "Invalid request body", err.Error())
		return
	}
	
	if err := h.taskUseCase.UpdateTaskDetails(
		domain.TaskID(taskID),
		req.Title,
		req.Description,
		req.DueDate,
	); err != nil {
		h.sendError(w, http.StatusBadRequest, "Failed to update task details", err.Error())
		return
	}
	
	h.sendJSON(w, http.StatusOK, map[string]string{"message": "Task details updated successfully"})
}

// DeleteTask handles DELETE /tasks/{id}
func (h *TaskHandler) DeleteTask(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	taskID, err := strconv.Atoi(vars["id"])
	if err != nil {
		h.sendError(w, http.StatusBadRequest, "Invalid task ID", err.Error())
		return
	}
	
	if err := h.taskUseCase.DeleteTask(domain.TaskID(taskID)); err != nil {
		h.sendError(w, http.StatusBadRequest, "Failed to delete task", err.Error())
		return
	}
	
	h.sendJSON(w, http.StatusOK, map[string]string{"message": "Task deleted successfully"})
}

// BulkUpdateStatus handles POST /tasks/bulk-update
func (h *TaskHandler) BulkUpdateStatus(w http.ResponseWriter, r *http.Request) {
	var req BulkUpdateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.sendError(w, http.StatusBadRequest, "Invalid request body", err.Error())
		return
	}
	
	if err := h.taskUseCase.BulkUpdateStatus(req.TaskIDs, req.Status); err != nil {
		h.sendError(w, http.StatusBadRequest, "Failed to bulk update tasks", err.Error())
		return
	}
	
	h.sendJSON(w, http.StatusOK, map[string]string{
		"message": "Tasks updated successfully",
		"count":   strconv.Itoa(len(req.TaskIDs)),
	})
}

// CheckDependencies handles POST /tasks/check-dependencies
func (h *TaskHandler) CheckDependencies(w http.ResponseWriter, r *http.Request) {
	count, err := h.taskUseCase.CheckDependencies()
	if err != nil {
		h.sendError(w, http.StatusInternalServerError, "Failed to check dependencies", err.Error())
		return
	}
	
	h.sendJSON(w, http.StatusOK, map[string]interface{}{
		"message":         "Dependencies checked",
		"unblocked_count": count,
	})
}

// Login handles POST /auth/login
func (h *TaskHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.sendError(w, http.StatusBadRequest, "Invalid request body", err.Error())
		return
	}
	
	session, err := h.taskUseCase.Authenticate(req.UserID)
	if err != nil {
		h.sendError(w, http.StatusUnauthorized, "Authentication failed", err.Error())
		return
	}
	
	h.sendJSON(w, http.StatusOK, session)
}

// Logout handles POST /auth/logout
func (h *TaskHandler) Logout(w http.ResponseWriter, r *http.Request) {
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		h.sendError(w, http.StatusBadRequest, "User ID required", "")
		return
	}
	
	if err := h.taskUseCase.Logout(domain.UserID(userID)); err != nil {
		h.sendError(w, http.StatusBadRequest, "Logout failed", err.Error())
		return
	}
	
	h.sendJSON(w, http.StatusOK, map[string]string{"message": "Logged out successfully"})
}

// Helper methods

func (h *TaskHandler) sendJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func (h *TaskHandler) sendError(w http.ResponseWriter, status int, message, details string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(ErrorResponse{
		Error:   message,
		Details: details,
	})
}
