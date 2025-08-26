---------------------------- MODULE DiscoveredProperties ----------------------------
\* Additional properties discovered for the TaskManagementImproved specification
\* These properties ensure system correctness, fairness, and progress guarantees

EXTENDS TaskManagementImproved, Integers, Sequences, FiniteSets, TLC

\* ============================================================================
\* ADDITIONAL SAFETY INVARIANTS
\* ============================================================================

\* ----------------------------------------------------------------------------
\* 1. Dependency Consistency Invariant
\* Guarantees: A task cannot depend on tasks created after it
\* Prevents: Future dependency paradoxes
\* ----------------------------------------------------------------------------
DependencyTemporalConsistency ==
    \A taskId \in DOMAIN tasks :
        \A depId \in tasks[taskId].dependencies :
            depId < taskId

\* Counterexample scenario: Task 5 depends on Task 7 (created later)
\* This could happen if we allow editing dependencies after creation

\* ----------------------------------------------------------------------------
\* 2. Priority Escalation Invariant  
\* Guarantees: Critical tasks with dependencies inherit urgency
\* Prevents: Critical tasks being blocked by low-priority dependencies
\* ----------------------------------------------------------------------------
PriorityInheritance ==
    \A taskId \in DOMAIN tasks :
        (tasks[taskId].priority = "critical" /\ tasks[taskId].dependencies # {}) =>
            \A depId \in tasks[taskId].dependencies :
                tasks[depId].priority \in {"high", "critical"}

\* Counterexample: Critical deployment task depends on low-priority documentation

\* ----------------------------------------------------------------------------
\* 3. Workload Balance Invariant
\* Guarantees: No user is overloaded beyond a threshold
\* Prevents: Task assignment bottlenecks
\* ----------------------------------------------------------------------------
WorkloadBalance ==
    LET MaxTasksPerUser == 10  \* Configurable threshold
    IN \A user \in Users :
        Cardinality({t \in DOMAIN tasks : 
            tasks[t].assignee = user /\ 
            tasks[t].status \in {"pending", "in_progress"}}) <= MaxTasksPerUser

\* Counterexample: One user assigned 50 active tasks while others have none

\* ----------------------------------------------------------------------------
\* 4. Deadline Consistency Invariant
\* Guarantees: Dependent tasks have compatible deadlines
\* Prevents: Impossible scheduling constraints
\* ----------------------------------------------------------------------------
DeadlineConsistency ==
    \A taskId \in DOMAIN tasks :
        \A depId \in tasks[taskId].dependencies :
            (tasks[taskId].dueDate # "NULL" /\ tasks[depId].dueDate # "NULL") =>
                tasks[depId].dueDate <= tasks[taskId].dueDate

\* Counterexample: Task due tomorrow depends on task due next week

\* ----------------------------------------------------------------------------
\* 5. Session Uniqueness Invariant
\* Guarantees: At most one active session per user
\* Prevents: Concurrent session conflicts
\* ----------------------------------------------------------------------------
UniqueActiveSession ==
    \A user \in Users :
        sessions[user] => (currentUser = user \/ currentUser = "NULL")

\* Counterexample: User has session but another user is currentUser

\* ----------------------------------------------------------------------------
\* 6. Task Progress Monotonicity
\* Guarantees: Tasks don't regress to earlier lifecycle stages (except planned revert)
\* Prevents: Unexpected state regressions
\* ----------------------------------------------------------------------------
ProgressMonotonicity ==
    LET StateOrder == [
        "pending" |-> 1,
        "in_progress" |-> 2,
        "completed" |-> 3,
        "cancelled" |-> 3,
        "blocked" |-> 0  \* Can transition to any state
    ]
    IN \A taskId \in DOMAIN tasks :
        tasks[taskId].status = "completed" => 
            tasks[taskId].updatedAt >= tasks[taskId].createdAt

\* This is a weaker version - the full version would track state history

\* ----------------------------------------------------------------------------
\* 7. Dependency Completion Invariant
\* Guarantees: Completed tasks had all dependencies completed
\* Prevents: Premature task completion
\* ----------------------------------------------------------------------------
CompletionDependencyCheck ==
    \A taskId \in DOMAIN tasks :
        tasks[taskId].status = "completed" =>
            \A depId \in tasks[taskId].dependencies :
                tasks[depId].status = "completed"

\* Counterexample: Task marked complete while dependency still in progress

\* ----------------------------------------------------------------------------
\* 8. Tag Consistency Invariant
\* Guarantees: Bug-tagged tasks get appropriate priority
\* Prevents: Critical bugs with low priority
\* ----------------------------------------------------------------------------
BugPriorityConsistency ==
    \A taskId \in DOMAIN tasks :
        ("bug" \in tasks[taskId].tags) =>
            tasks[taskId].priority \in {"medium", "high", "critical"}

\* Counterexample: bug with low priority

\* ============================================================================
\* LIVENESS PROPERTIES FOR PROGRESS GUARANTEES
\* ============================================================================

\* ----------------------------------------------------------------------------
\* 1. Bounded Task Completion
\* Guarantees: All tasks eventually complete within bounded time
\* Prevents: Tasks stuck indefinitely
\* ----------------------------------------------------------------------------
BoundedCompletion ==
    \A taskId \in DOMAIN tasks :
        (tasks[taskId].status = "in_progress") ~>
            \E t \in 1..MaxTime :
                (clock = tasks[taskId].createdAt + t) =>
                    tasks[taskId].status \in {"completed", "cancelled"}

\* ----------------------------------------------------------------------------
\* 2. Priority-Based Progress
\* Guarantees: Higher priority tasks progress before lower priority ones
\* Prevents: Priority inversion
\* ----------------------------------------------------------------------------
PriorityProgress ==
    \A t1, t2 \in DOMAIN tasks :
        LET p1 == CASE tasks[t1].priority = "critical" -> 4
                    [] tasks[t1].priority = "high" -> 3
                    [] tasks[t1].priority = "medium" -> 2
                    [] tasks[t1].priority = "low" -> 1
            p2 == CASE tasks[t2].priority = "critical" -> 4
                    [] tasks[t2].priority = "high" -> 3
                    [] tasks[t2].priority = "medium" -> 2
                    [] tasks[t2].priority = "low" -> 1
        IN (tasks[t1].status = "pending" /\ 
            tasks[t2].status = "pending" /\ 
            p1 > p2) ~>
                (tasks[t1].status = "in_progress" \/ 
                 tasks[t2].status # "in_progress")

\* ----------------------------------------------------------------------------
\* 3. Dependency Resolution Progress
\* Guarantees: Blocked tasks become unblocked when dependencies complete
\* Prevents: Permanent blocking
\* ----------------------------------------------------------------------------
DependencyResolution ==
    \A taskId \in DOMAIN tasks :
        (tasks[taskId].status = "blocked" /\
         \A dep \in tasks[taskId].dependencies : 
            tasks[dep].status = "completed") ~>
                (tasks[taskId].status # "blocked")

\* ----------------------------------------------------------------------------
\* 4. Session Termination
\* Guarantees: All sessions eventually terminate
\* Prevents: Resource leaks from abandoned sessions
\* ----------------------------------------------------------------------------
SessionTermination ==
    \A user \in Users :
        sessions[user] ~> ~sessions[user]

\* ----------------------------------------------------------------------------
\* 5. Work Distribution
\* Guarantees: Available tasks get assigned to available users
\* Prevents: Work stagnation
\* ----------------------------------------------------------------------------
WorkDistribution ==
    (\E taskId \in DOMAIN tasks : 
        tasks[taskId].status = "pending" /\
        tasks[taskId].dependencies = {}) ~>
            (\E taskId \in DOMAIN tasks :
                tasks[taskId].status = "in_progress")

\* ----------------------------------------------------------------------------
\* 6. Overdue Task Escalation
\* Guarantees: Overdue tasks get priority escalation
\* Prevents: Missed deadlines for important work
\* ----------------------------------------------------------------------------
OverdueEscalation ==
    \A taskId \in DOMAIN tasks :
        (tasks[taskId].dueDate # "NULL" /\
         clock > tasks[taskId].dueDate /\
         tasks[taskId].status \in {"pending", "in_progress"}) ~>
            (tasks[taskId].priority \in {"high", "critical"} \/
             tasks[taskId].status \in {"completed", "cancelled"})

\* ============================================================================
\* FAIRNESS CONDITIONS TO PREVENT STARVATION
\* ============================================================================

\* ----------------------------------------------------------------------------
\* 1. Strong Fairness for Critical Tasks
\* Guarantees: Critical tasks get CPU time
\* Prevents: Critical task starvation
\* ----------------------------------------------------------------------------
CriticalTaskFairness ==
    \A taskId \in DOMAIN tasks :
        SF_<<tasks>>((tasks[taskId].priority = "critical" /\ 
                      tasks[taskId].status = "pending") =>
                     UpdateTaskStatus(taskId, "in_progress"))

\* ----------------------------------------------------------------------------
\* 2. Weak Fairness for User Sessions
\* Guarantees: Every user gets a chance to work
\* Prevents: User lockout
\* ----------------------------------------------------------------------------
UserSessionFairness ==
    \A user \in Users :
        WF_<<sessions, currentUser>>(
            (~sessions[user] /\ currentUser = "NULL") => 
            Authenticate(user))

\* ----------------------------------------------------------------------------
\* 3. Fair Task Assignment
\* Guarantees: Tasks are distributed fairly among users
\* Prevents: Single user monopoly
\* ----------------------------------------------------------------------------
FairTaskAssignment ==
    \A user \in Users :
        WF_<<userTasks>>(
            LET userLoad == Cardinality(GetUserTasks(user))
                avgLoad == Cardinality(DOMAIN tasks) \div Cardinality(Users)
            IN userLoad < avgLoad)

\* ----------------------------------------------------------------------------
\* 4. Dependency Check Fairness
\* Guarantees: Dependency checks happen regularly
\* Prevents: Indefinite blocking
\* ----------------------------------------------------------------------------
DependencyCheckFairness ==
    SF_<<tasks>>(CheckDependencies)

\* ----------------------------------------------------------------------------
\* 5. Bulk Operation Fairness
\* Guarantees: Bulk operations don't starve individual operations
\* Prevents: Bulk operation monopoly
\* ----------------------------------------------------------------------------
BulkOperationFairness ==
    WF_<<tasks>>(\E taskId \in DOMAIN tasks, newStatus \in TaskStates :
                    UpdateTaskStatus(taskId, newStatus))

\* ============================================================================
\* TEMPORAL PROPERTIES FOR SEQUENCING CONSTRAINTS
\* ============================================================================

\* ----------------------------------------------------------------------------
\* 1. Authentication Before Action
\* Guarantees: All task operations are preceded by authentication
\* Prevents: Unauthorized actions
\* ----------------------------------------------------------------------------
AuthenticationPrecedence ==
    \A taskId \in DOMAIN tasks :
        [](TaskExists(taskId) => 
            <>(currentUser # "NULL" /\ currentUser = tasks[taskId].createdBy))

\* ----------------------------------------------------------------------------
\* 2. Creation Before Modification
\* Guarantees: Tasks must exist before being modified
\* Prevents: Operations on non-existent tasks
\* ----------------------------------------------------------------------------
CreationBeforeModification ==
    \A taskId \in 1..MaxTasks :
        []((taskId \in DOMAIN tasks)' => 
            (taskId \in DOMAIN tasks \/ taskId = nextTaskId))

\* ----------------------------------------------------------------------------
\* 3. Dependency Order Preservation
\* Guarantees: Dependencies complete before dependent tasks
\* Prevents: Out-of-order execution
\* ----------------------------------------------------------------------------
DependencyOrdering ==
    \A t1, t2 \in DOMAIN tasks :
        (t2 \in tasks[t1].dependencies) =>
            [](tasks[t1].status = "completed" => 
                tasks[t2].status = "completed")

\* ----------------------------------------------------------------------------
\* 4. Status Transition Ordering
\* Guarantees: Tasks follow proper lifecycle
\* Prevents: Lifecycle violations
\* ----------------------------------------------------------------------------
StatusTransitionOrdering ==
    \A taskId \in DOMAIN tasks :
        [](tasks[taskId].status = "completed" =>
            <>(tasks[taskId].status = "in_progress"))

\* ----------------------------------------------------------------------------
\* 5. Session Lifecycle
\* Guarantees: Login before operations, logout after
\* Prevents: Session leaks
\* ----------------------------------------------------------------------------
SessionLifecycle ==
    \A user \in Users :
        [](sessions[user] => 
            (<>~sessions[user] /\ 
             [](~sessions[user] => currentUser # user)))

\* ----------------------------------------------------------------------------
\* 6. Monotonic Task IDs
\* Guarantees: Task IDs always increase
\* Prevents: ID reuse or confusion
\* ----------------------------------------------------------------------------
MonotonicTaskIds ==
    [](nextTaskId' >= nextTaskId)

\* ----------------------------------------------------------------------------
\* 7. Timestamp Progression
\* Guarantees: Time moves forward, updates are newer
\* Prevents: Time travel bugs
\* ----------------------------------------------------------------------------
TimestampProgression ==
    \A taskId \in DOMAIN tasks :
        [](tasks[taskId].updatedAt' >= tasks[taskId].updatedAt)

\* ============================================================================
\* STATE PREDICATES FOR DEBUGGING
\* ============================================================================

\* ----------------------------------------------------------------------------
\* 1. System Load Predicate
\* Purpose: Check if system is under heavy load
\* Use: Performance monitoring and debugging
\* ----------------------------------------------------------------------------
SystemUnderLoad ==
    Cardinality({t \in DOMAIN tasks : 
        tasks[t].status = "in_progress"}) > Cardinality(Users)

\* ----------------------------------------------------------------------------
\* 2. Deadlock Detection Predicate
\* Purpose: Detect circular dependency deadlocks
\* Use: Debugging stuck tasks
\* ----------------------------------------------------------------------------
DeadlockExists ==
    \E taskSet \in SUBSET DOMAIN tasks :
        /\ Cardinality(taskSet) > 1
        /\ \A t1 \in taskSet : \E t2 \in taskSet :
            t2 \in tasks[t1].dependencies
        /\ \A t \in taskSet : tasks[t].status = "blocked"

\* ----------------------------------------------------------------------------
\* 3. Abandoned Task Predicate
\* Purpose: Find tasks with no recent activity
\* Use: Cleanup and maintenance
\* ----------------------------------------------------------------------------
AbandonedTasks ==
    {taskId \in DOMAIN tasks :
        /\ tasks[taskId].status \in {"pending", "in_progress"}
        /\ clock - tasks[taskId].updatedAt > 30}  \* 30 time units old

\* ----------------------------------------------------------------------------
\* 4. User Workload Imbalance
\* Purpose: Detect uneven work distribution
\* Use: Load balancing decisions
\* ----------------------------------------------------------------------------
WorkloadImbalanced ==
    LET loads == [u \in Users |-> 
                    Cardinality({t \in DOMAIN tasks : 
                        tasks[t].assignee = u /\ 
                        tasks[t].status \in {"pending", "in_progress"}})]
        maxLoad == CHOOSE u \in Users : 
                    \A v \in Users : loads[u] >= loads[v]
        minLoad == CHOOSE u \in Users : 
                    \A v \in Users : loads[u] <= loads[v]
    IN loads[maxLoad] > 2 * loads[minLoad] + 1

\* ----------------------------------------------------------------------------
\* 5. Critical Path Length
\* Purpose: Find longest dependency chain
\* Use: Schedule optimization
\* ----------------------------------------------------------------------------
CriticalPathLength ==
    LET RECURSIVE PathLength(_)
        PathLength(taskId) ==
            IF ~TaskExists(taskId) \/ tasks[taskId].dependencies = {}
            THEN 1
            ELSE 1 + CHOOSE maxLen \in Nat :
                maxLen = Max({PathLength(dep) : dep \in tasks[taskId].dependencies})
    IN CHOOSE maxPath \in Nat :
        maxPath = Max({PathLength(t) : t \in DOMAIN tasks})

\* ----------------------------------------------------------------------------
\* 6. Overdue Tasks Count
\* Purpose: Count tasks past their due date
\* Use: SLA monitoring
\* ----------------------------------------------------------------------------
OverdueTasksCount ==
    Cardinality({t \in DOMAIN tasks :
        /\ tasks[t].dueDate # "NULL"
        /\ clock > tasks[t].dueDate
        /\ tasks[t].status \notin {"completed", "cancelled"}})

\* ----------------------------------------------------------------------------
\* 7. Session Activity Predicate
\* Purpose: Check if any user is active
\* Use: System activity monitoring
\* ----------------------------------------------------------------------------
SystemActive ==
    \E user \in Users : sessions[user] = TRUE

\* ----------------------------------------------------------------------------
\* 8. Priority Inversion Detection
\* Purpose: Find low-priority tasks blocking high-priority ones
\* Use: Priority scheduling debugging
\* ----------------------------------------------------------------------------
PriorityInversionExists ==
    \E t1, t2 \in DOMAIN tasks :
        /\ t1 \in tasks[t2].dependencies
        /\ tasks[t2].priority = "critical"
        /\ tasks[t1].priority = "low"
        /\ tasks[t1].status # "completed"

\* ----------------------------------------------------------------------------
\* 9. Task Completion Rate
\* Purpose: Measure system throughput
\* Use: Performance metrics
\* ----------------------------------------------------------------------------
CompletionRate ==
    LET completed == Cardinality({t \in DOMAIN tasks : 
                        tasks[t].status = "completed"})
        total == Cardinality(DOMAIN tasks)
    IN IF total > 0 THEN (completed * 100) \div total ELSE 0

\* ----------------------------------------------------------------------------
\* 10. Blocked Task Ratio
\* Purpose: Measure dependency bottlenecks
\* Use: Dependency management optimization
\* ----------------------------------------------------------------------------
BlockedRatio ==
    LET blocked == Cardinality({t \in DOMAIN tasks : 
                      tasks[t].status = "blocked"})
        total == Cardinality(DOMAIN tasks)
    IN IF total > 0 THEN (blocked * 100) \div total ELSE 0

\* ============================================================================
\* COMPOSITE PROPERTIES
\* Combine multiple aspects for comprehensive guarantees
\* ============================================================================

\* Overall system health combining multiple properties
SystemHealthy ==
    /\ SafetyInvariant
    /\ ~DeadlockExists
    /\ ~WorkloadImbalanced
    /\ OverdueTasksCount < 5
    /\ BlockedRatio < 30

\* Progress guarantee combining fairness and liveness
ProgressGuarantee ==
    /\ EventualCompletion
    /\ FairProgress
    /\ DependencyResolution
    /\ PriorityProgress

\* Complete correctness specification
CompleteCorrectness ==
    /\ TypeInvariant
    /\ SafetyInvariant
    /\ DependencyTemporalConsistency
    /\ DeadlineConsistency
    /\ CompletionDependencyCheck

================================================================================
