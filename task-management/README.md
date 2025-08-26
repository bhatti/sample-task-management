# Task Management System - TLA+ Specification Implementation

A Go implementation that faithfully realizes a TLA+ specification for a task management system, with runtime invariant checking and formal correctness guarantees.

## Overview

This implementation directly maps TLA+ formal specification actions to Go code, ensuring behavioral correctness through:
- Runtime invariant checking after every operation
- Property-based testing against TLA+ properties
- State machine tests following TLA+ traces
- Concurrent access testing with invariant preservation

## Architecture

```
task-management/
├── cmd/server/          # Main application entry point
├── internal/
│   ├── domain/          # Core entities (maps to TLA+ types)
│   ├── usecase/         # Business logic (maps to TLA+ actions)
│   ├── repository/      # Data access interfaces
│   ├── infrastructure/  # In-memory storage implementation
│   └── api/http/        # REST API handlers
├── pkg/invariants/      # TLA+ invariant checkers
└── test/
    ├── property/        # Property-based tests
    ├── statemachine/    # State machine tests
    └── concurrent/      # Concurrency tests
```

## TLA+ to Go Mapping

### Domain Types
- `TaskID` → `domain.TaskID`
- `UserID` → `domain.UserID`
- `TaskStates` → `domain.TaskStatus`
- `Priorities` → `domain.Priority`
- `Task record` → `domain.Task` struct

### TLA+ Actions to Use Cases
- `Authenticate(user)` → `usecase.Authenticate()`
- `Logout` → `usecase.Logout()`
- `CreateTask(...)` → `usecase.CreateTask()`
- `UpdateTaskStatus(taskId, newStatus)` → `usecase.UpdateTaskStatus()`
- `UpdateTaskPriority(taskId, newPriority)` → `usecase.UpdateTaskPriority()`
- `ReassignTask(taskId, newAssignee)` → `usecase.ReassignTask()`
- `DeleteTask(taskId)` → `usecase.DeleteTask()`
- `CheckDependencies` → `usecase.CheckDependencies()`
- `BulkUpdateStatus(taskIds, newStatus)` → `usecase.BulkUpdateStatus()`

### Invariants (Runtime Checked)
- `NoOrphanTasks` - Every task has an owner
- `TaskOwnership` - Tasks are in assignee's list
- `ValidTaskIds` - IDs are sequential and valid
- `NoDuplicateTaskIds` - All IDs are unique
- `ValidStateTransitions` - Only legal state changes
- `ConsistentTimestamps` - Time ordering preserved
- `NoCyclicDependencies` - No dependency cycles
- `AuthenticationRequired` - All operations authenticated

## Installation & Running

```bash
# Install dependencies
go mod download

# Run tests
go test ./...

# Run property-based tests
go test ./test/property -v

# Start server
go run cmd/server/main.go
```

## API Endpoints

### Authentication
- `POST /auth/login` - Authenticate user (TLA+ Authenticate)
- `POST /auth/logout` - Logout user (TLA+ Logout)

### Task Operations
- `POST /tasks` - Create task (TLA+ CreateTask)
- `PUT /tasks/{id}/status` - Update status (TLA+ UpdateTaskStatus)
- `PUT /tasks/{id}/priority` - Update priority (TLA+ UpdateTaskPriority)
- `PUT /tasks/{id}/reassign` - Reassign task (TLA+ ReassignTask)
- `PUT /tasks/{id}/details` - Update details (TLA+ UpdateTaskDetails)
- `DELETE /tasks/{id}` - Delete task (TLA+ DeleteTask)
- `POST /tasks/bulk-update` - Bulk update (TLA+ BulkUpdateStatus)
- `POST /tasks/check-dependencies` - Check deps (TLA+ CheckDependencies)

## Example Usage

```bash
# Login
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"user_id": "alice"}'

# Create task
curl -X POST http://localhost:8080/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Implement feature",
    "description": "Add new functionality",
    "priority": "high",
    "assignee": "alice",
    "tags": ["feature"],
    "dependencies": []
  }'

# Update task status
curl -X PUT http://localhost:8080/tasks/1/status \
  -H "Content-Type: application/json" \
  -d '{"status": "in_progress"}'
```

## Correctness Guarantees

1. **Precondition Checking**: Every operation validates TLA+ preconditions
2. **Invariant Preservation**: All invariants checked after each operation
3. **Atomic Operations**: Repository operations maintain consistency
4. **Transition Validation**: Only valid state transitions allowed
5. **Dependency Management**: Cyclic dependencies prevented
6. **Concurrent Safety**: Thread-safe operations with mutex protection

## Testing Strategy

### Property-Based Tests
- Verify invariants hold after all operations
- Test state transition validity
- Check ownership preservation
- Validate concurrent operation safety

### State Machine Tests
- Follow TLA+ execution traces
- Verify action sequences
- Test complex workflows
- Validate liveness properties

### Concurrent Access Tests
- Multiple users operating simultaneously
- Race condition detection
- Invariant preservation under load
- Deadlock prevention

## Monitoring

The server includes runtime monitoring for:
- Invariant violations (logged as errors)
- Liveness property warnings (e.g., stuck tasks)
- Performance metrics
- State consistency checks

## Development Notes

- Every use case function maps directly to a TLA+ action
- Invariants are checked both at compile-time (type system) and runtime
- The implementation prioritizes correctness over performance
- All state modifications go through validated transitions
- The system maintains a complete audit trail

## License

MIT