// Package main is the entry point for the task management server
package main

import (
	"fmt"
	"log"
	"net/http"
	"time"
	
	"github.com/gorilla/mux"
	"github.com/bhatti/sample-task-management/internal/api/http/handlers"
	"github.com/bhatti/sample-task-management/internal/domain"
	"github.com/bhatti/sample-task-management/internal/infrastructure/memory"
	"github.com/bhatti/sample-task-management/internal/usecase"
	"github.com/bhatti/sample-task-management/pkg/invariants"
)

func main() {
	// Initialize repository and dependencies
	repo := memory.NewMemoryRepository()
	uow := memory.NewMemoryUnitOfWork(repo)
	checker := invariants.NewInvariantChecker()
	taskUseCase := usecase.NewTaskUseCase(uow, checker)
	
	// Initialize default users (for testing)
	initializeDefaultUsers(repo)
	
	// Create HTTP handlers
	taskHandler := handlers.NewTaskHandler(taskUseCase)
	
	// Setup routes
	router := setupRoutes(taskHandler)
	
	// Add middleware
	router.Use(loggingMiddleware)
	router.Use(invariantCheckMiddleware(repo, checker))
	
	// Start server
	port := ":8080"
	log.Printf("Task Management Server starting on port %s", port)
	log.Printf("TLA+ specification-compliant implementation")
	log.Printf("All invariants will be checked at runtime")
	
	if err := http.ListenAndServe(port, router); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}

func setupRoutes(taskHandler *handlers.TaskHandler) *mux.Router {
	router := mux.NewRouter()
	
	// Authentication endpoints
	router.HandleFunc("/auth/login", taskHandler.Login).Methods("POST")
	router.HandleFunc("/auth/logout", taskHandler.Logout).Methods("POST")
	
	// Task endpoints (maps to TLA+ actions)
	router.HandleFunc("/tasks", taskHandler.CreateTask).Methods("POST")
	router.HandleFunc("/tasks/{id}/status", taskHandler.UpdateTaskStatus).Methods("PUT")
	router.HandleFunc("/tasks/{id}/priority", taskHandler.UpdateTaskPriority).Methods("PUT")
	router.HandleFunc("/tasks/{id}/reassign", taskHandler.ReassignTask).Methods("PUT")
	router.HandleFunc("/tasks/{id}/details", taskHandler.UpdateTaskDetails).Methods("PUT")
	router.HandleFunc("/tasks/{id}", taskHandler.DeleteTask).Methods("DELETE")
	
	// Bulk operations
	router.HandleFunc("/tasks/bulk-update", taskHandler.BulkUpdateStatus).Methods("POST")
	router.HandleFunc("/tasks/check-dependencies", taskHandler.CheckDependencies).Methods("POST")
	
	// Health check
	router.HandleFunc("/health", healthCheck).Methods("GET")
	
	return router
}

func initializeDefaultUsers(repo *memory.MemoryRepository) {
	users := []domain.User{
		{
			ID:       "alice",
			Name:     "Alice",
			Email:    "alice@example.com",
			JoinedAt: time.Now(),
		},
		{
			ID:       "bob",
			Name:     "Bob",
			Email:    "bob@example.com",
			JoinedAt: time.Now(),
		},
		{
			ID:       "charlie",
			Name:     "Charlie",
			Email:    "charlie@example.com",
			JoinedAt: time.Now(),
		},
	}
	
	for _, user := range users {
		if err := repo.CreateUser(&user); err != nil {
			log.Printf("Failed to create user %s: %v", user.ID, err)
		} else {
			log.Printf("Created default user: %s", user.ID)
		}
	}
}

func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, `{"status":"healthy","message":"TLA+ compliant task management system"}`)
}

func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		
		// Log request
		log.Printf("[%s] %s %s", r.Method, r.RequestURI, r.RemoteAddr)
		
		// Call next handler
		next.ServeHTTP(w, r)
		
		// Log response time
		log.Printf("Request completed in %v", time.Since(start))
	})
}

func invariantCheckMiddleware(repo *memory.MemoryRepository, checker *invariants.InvariantChecker) mux.MiddlewareFunc {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Call next handler
			next.ServeHTTP(w, r)
			
			// Check invariants after each request
			state, err := repo.GetSystemState()
			if err != nil {
				log.Printf("Failed to get system state: %v", err)
				return
			}
			
			if err := checker.CheckAllInvariants(state); err != nil {
				log.Printf("INVARIANT VIOLATION DETECTED: %v", err)
				// In production, you might want to trigger alerts here
			}
			
			// Check liveness properties for monitoring
			warnings := checker.CheckLivenessProperties(state)
			for _, warning := range warnings {
				log.Printf("LIVENESS WARNING: %s", warning)
			}
		})
	}
}
