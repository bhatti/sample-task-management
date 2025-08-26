# Property Discovery Guide for Task Management System

## Overview
This guide explains discovered properties that strengthen your TLA+ specification, organized by category with practical examples and counterexamples.

## 1. Additional Safety Invariants

### 1.1 Dependency Temporal Consistency
```tla
DependencyTemporalConsistency ==
    ∀ taskId ∈ DOMAIN tasks :
        ∀ depId ∈ tasks[taskId].dependencies :
            depId < taskId
```

**What it guarantees:** Tasks can only depend on previously created tasks

**Why it matters:** Prevents temporal paradoxes and ensures causality

**Counterexample scenario:**
```
Task 5 created at time T1
Task 7 created at time T2 (T2 > T1)  
Task 5 modified to depend on Task 7 ← VIOLATION
```

**How to verify:**
```bash
# Add to your .cfg file
INVARIANT DependencyTemporalConsistency
```

### 1.2 Priority Inheritance
```tla
PriorityInheritance ==
    ∀ critical task with dependencies:
        All dependencies have priority ≥ high
```

**What it guarantees:** Critical tasks aren't blocked by low-priority work

**Why it matters:** Prevents priority inversion deadlocks

**Counterexample scenario:**
```
Critical fix (Task A) depends on:
  → Low priority refactoring (Task B) ← VIOLATION
  
Result: Critical fix delayed by non-urgent work
```

### 1.3 Workload Balance
```tla
WorkloadBalance ==
    ∀ user : ActiveTaskCount(user) ≤ MaxTasksPerUser
```

**What it guarantees:** No user becomes a bottleneck

**Why it matters:** Ensures system scalability and fairness

**Counterexample scenario:**
```
Alice: 50 active tasks (overloaded)
Bob: 0 active tasks (idle)
Charlie: 1 active task
← System throughput limited by Alice
```

### 1.4 Deadline Consistency
```tla
DeadlineConsistency ==
    ∀ task with dependencies:
        dependency.dueDate ≤ task.dueDate
```

**What it guarantees:** Dependencies complete before dependent tasks are due

**Why it matters:** Prevents impossible scheduling constraints

**Counterexample scenario:**
```
Deploy Feature (due: Jan 1)
  depends on → Code Review (due: Jan 15)
← Impossible to meet deadline
```

## 2. Liveness Properties for Progress Guarantees

### 2.1 Bounded Task Completion
```tla
BoundedCompletion ==
    ◇□(in_progress task → ◇≤MaxTime (completed ∨ cancelled))
```

**What it guarantees:** Tasks don't remain in progress forever

**Why it matters:** Ensures system makes progress

**Failure scenario:**
```
Task enters "in_progress" at T0
Still "in_progress" at T0 + MaxTime
← Indicates stuck task or abandoned work
```

### 2.2 Priority-Based Progress
```tla
PriorityProgress ==
    critical_pending ∧ low_pending ~> 
        (critical_in_progress ∨ ¬low_in_progress)
```

**What it guarantees:** Higher priority tasks progress first

**Why it matters:** Ensures important work isn't delayed

**Failure scenario:**
```
State 1: Critical bug (pending), Feature request (pending)
State 2: Critical bug (pending), Feature request (in_progress)
← Priority inversion
```

### 2.3 Dependency Resolution Progress
```tla
DependencyResolution ==
    blocked ∧ all_deps_complete ~> unblocked
```

**What it guarantees:** Tasks unblock when dependencies complete

**Why it matters:** Prevents permanent blocking

**Failure scenario:**
```
Task A blocked on Task B
Task B completes
Task A remains blocked indefinitely
← CheckDependencies not running
```

## 3. Fairness Conditions to Prevent Starvation

### 3.1 Strong Fairness for Critical Tasks
```tla
SF_tasks(critical_pending → critical_in_progress)
```

**What it guarantees:** Critical tasks eventually get resources

**Why it matters:** Prevents critical work starvation

**Starvation scenario without fairness:**
```
Infinite stream of medium-priority tasks
Critical task waits forever
← Without SF, valid but undesirable
```

### 3.2 Weak Fairness for User Sessions
```tla
WF_sessions(user_waiting → user_authenticated)
```

**What it guarantees:** Every user gets a turn to work

**Why it matters:** Prevents user lockout

**Starvation scenario without fairness:**
```
Alice continuously authenticates/works/logs out
Bob never gets authenticated
← Without WF, Bob could starve
```

### 3.3 Fair Task Distribution
```tla
WF(underloaded_user → receives_task)
```

**What it guarantees:** Work distributed evenly

**Why it matters:** Maximizes throughput

**Imbalance scenario without fairness:**
```
All new tasks → Alice (even when overloaded)
Bob remains idle
← Suboptimal resource utilization
```

## 4. Temporal Properties for Sequencing Constraints

### 4.1 Authentication Precedence
```tla
□(task_exists → ◇authenticated_creator)
```

**What it guarantees:** Every task has authenticated creator

**Why it matters:** Security and audit trail

**Violation scenario:**
```
Task appears in system
No authentication event for creator
← Indicates security breach
```

### 4.2 Dependency Order Preservation
```tla
□(dependent_completed → dependency_completed)
```

**What it guarantees:** Correct execution order

**Why it matters:** Maintains logical consistency

**Violation scenario:**
```
"Deploy" marked complete
"Run Tests" (dependency) still in progress
← Invalid state
```

### 4.3 Monotonic Task IDs
```tla
□(nextTaskId' ≥ nextTaskId)
```

**What it guarantees:** IDs never decrease or repeat

**Why it matters:** Unique identification

**Violation scenario:**
```
nextTaskId = 10
Create task (ID: 10)
nextTaskId = 10 (doesn't increment)
Create another task (ID: 10)
← Duplicate IDs
```

## 5. State Predicates for Debugging

### 5.1 Deadlock Detection
```tla
DeadlockExists ==
    ∃ circular dependency chain where all tasks blocked
```

**Purpose:** Find circular dependency deadlocks

**How to use:**
```tla
\* In debugging mode
ASSUME ~DeadlockExists
```

**Example deadlock:**
```
Task A depends on Task B
Task B depends on Task C  
Task C depends on Task A
All blocked → Deadlock detected
```

### 5.2 Abandoned Tasks
```tla
AbandonedTasks ==
    {tasks not updated for > 30 time units}
```

**Purpose:** Find stale work items

**How to use:**
```tla
\* Alert when abandoned tasks exist
Alert == Cardinality(AbandonedTasks) > 0
```

### 5.3 Priority Inversion Detection
```tla
PriorityInversionExists ==
    ∃ low_priority task blocking critical task
```

**Purpose:** Find scheduling problems

**Example:**
```
Critical Security Fix blocked by:
  → Low Priority Refactoring (in progress)
← Priority inversion detected
```

## 6. Verification Strategies

### 6.1 Model Checking Configuration
```cfg
\* Essential invariants to always check
INVARIANT TypeInvariant
INVARIANT SafetyInvariant
INVARIANT DependencyTemporalConsistency
INVARIANT DeadlineConsistency

\* Liveness properties (requires fairness)
PROPERTY EventualCompletion
PROPERTY DependencyResolution

\* Debugging predicates (check periodically)
CONSTRAINT ~DeadlockExists
CONSTRAINT OverdueTasksCount < 10
```

### 6.2 Bounded Model Checking
```cfg
\* For initial verification
CONSTANTS
    Users = {alice, bob, charlie}
    MaxTasks = 10
    MaxTime = 50
    
\* State space constraints
CONSTRAINT Cardinality(DOMAIN tasks) <= 5
CONSTRAINT clock <= 20
```

### 6.3 Simulation Mode Testing
```tla
\* Test specific scenarios
TestCriticalPath ==
    /\ Init
    /\ CreateTask("A", ..., {})        \* No dependencies
    /\ CreateTask("B", ..., {1})       \* Depends on A
    /\ CreateTask("C", ..., {2})       \* Depends on B
    /\ UNCHANGED CriticalPathLength = 3
```

## 7. Property Categories Summary

| Category | Purpose | Verification Type | Performance Impact |
|----------|---------|------------------|-------------------|
| **Safety Invariants** | Prevent bad states | Every state | Low (state check) |
| **Liveness Properties** | Ensure progress | Execution paths | High (temporal) |
| **Fairness Conditions** | Prevent starvation | Scheduling | Medium |
| **Temporal Properties** | Sequence constraints | Traces | High |
| **State Predicates** | Debugging/monitoring | On-demand | Variable |

## 8. Common Property Patterns

### 8.1 Eventually Always Pattern
```tla
◇□(good_condition)
"Eventually reaches and maintains good state"
```

### 8.2 Always Eventually Pattern  
```tla
□◇(progress_condition)
"Repeatedly makes progress"
```

### 8.3 Leads-To Pattern
```tla
condition1 ~> condition2
"condition1 eventually leads to condition2"
```

### 8.4 Until Pattern
```tla
condition1 U condition2
"condition1 holds until condition2"
```

## 9. Property Testing Strategy

### Phase 1: Core Safety
1. TypeInvariant
2. SafetyInvariant
3. DependencyTemporalConsistency

### Phase 2: Progress
1. EventualCompletion
2. DependencyResolution
3. BoundedCompletion

### Phase 3: Fairness
1. CriticalTaskFairness
2. UserSessionFairness
3. FairTaskAssignment

### Phase 4: Advanced
1. DeadlockExists (should be false)
2. WorkloadImbalanced (monitor)
3. SystemHealthy (composite)

## 10. Troubleshooting Failed Properties

### When Invariant Fails
1. Check error trace in TLC
2. Identify violating state
3. Trace back to action that caused violation
4. Add precondition or strengthen postcondition

### When Liveness Fails
1. Check for missing fairness conditions
2. Look for infinite loops without progress
3. Verify eventual conditions are reachable
4. Add progress actions if needed

### When Fairness Fails
1. Identify starving component
2. Add appropriate WF or SF condition
3. Verify fairness doesn't conflict with invariants
4. Test with different scheduling

## Best Practices

1. **Start Simple:** Begin with type safety, add properties incrementally
2. **Use Predicates:** Create reusable state predicates for complex conditions
3. **Document Failures:** Keep counterexamples as regression tests
4. **Monitor Performance:** Complex properties increase verification time
5. **Layer Properties:** Build complex properties from simple ones
6. **Test Boundaries:** Focus on edge cases and limits
7. **Version Properties:** Track which properties apply to which spec version

This comprehensive property set ensures your task management system is:
- **Safe:** No bad states reachable
- **Live:** Always makes progress  
- **Fair:** No starvation
- **Correct:** Follows intended behavior
- **Debuggable:** Easy to diagnose issues
