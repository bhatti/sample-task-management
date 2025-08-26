---------------------------- MODULE PropertyCounterexamples ----------------------------
\* Counterexamples and test scenarios for discovered properties
\* These demonstrate how properties can fail and how to fix violations

EXTENDS TaskManagementImproved, DiscoveredProperties, Integers, FiniteSets, TLC

\* ============================================================================
\* COUNTEREXAMPLE SCENARIOS
\* Each shows how a property can be violated
\* ============================================================================

\* ----------------------------------------------------------------------------
\* Scenario 1: Dependency Temporal Consistency Violation
\* ----------------------------------------------------------------------------
ViolateDependencyTemporal ==
    /\ Init
    /\ Authenticate("alice")
    /\ CreateTask("Task1", "Desc1", "low", "alice", "NULL", {}, {})  \* ID: 1
    /\ CreateTask("Task2", "Desc2", "low", "alice", "NULL", {}, {})  \* ID: 2
    /\ \* Hypothetically, if we could modify dependencies after creation:
       \* tasks' = [tasks EXCEPT ![1].dependencies = {2}]
       \* This would violate DependencyTemporalConsistency
       FALSE  \* Can't actually do this in current spec

\* Fix: Dependencies can only be set at creation time to earlier tasks

\* ----------------------------------------------------------------------------
\* Scenario 2: Priority Inheritance Violation  
\* ----------------------------------------------------------------------------
ViolatePriorityInheritance ==
    /\ Init
    /\ Authenticate("alice")
    /\ CreateTask("LowPriorityTask", "Desc", "low", "alice", "NULL", {}, {})  \* ID: 1
    /\ CreateTask("CriticalTask", "Desc", "critical", "alice", "NULL", {}, {1})  \* ID: 2
    /\ \* Now we have critical task depending on low priority task
       \* This violates PriorityInheritance
       ~PriorityInheritance

\* Fix: Automatically escalate dependency priority or prevent such creation

\* ----------------------------------------------------------------------------
\* Scenario 3: Workload Balance Violation
\* ----------------------------------------------------------------------------
ViolateWorkloadBalance ==
    /\ Init
    /\ Authenticate("alice")
    /\ \* Create 11 tasks all assigned to alice
       \E i \in 1..11 :
           CreateTask("Task", "Desc", "medium", "alice", "NULL", {}, {})
    /\ \* Check violation (assuming MaxTasksPerUser = 10)
       ~WorkloadBalance

\* Fix: Implement task limit checking in CreateTask action

\* ----------------------------------------------------------------------------
\* Scenario 4: Deadline Consistency Violation
\* ----------------------------------------------------------------------------
ViolateDeadlineConsistency ==
    /\ Init
    /\ Authenticate("alice")
    /\ CreateTask("Dependency", "Desc", "high", "alice", 100, {}, {})  \* Due: 100
    /\ CreateTask("Dependent", "Desc", "high", "alice", 50, {}, {1})    \* Due: 50
    /\ \* Task 2 due before its dependency - violates DeadlineConsistency
       ~DeadlineConsistency

\* Fix: Validate deadlines when creating tasks with dependencies

\* ----------------------------------------------------------------------------
\* Scenario 5: Completion Without Dependencies Complete
\* ----------------------------------------------------------------------------
ViolateCompletionDependencyCheck ==
    /\ Init
    /\ Authenticate("alice")
    /\ CreateTask("Dep", "Desc", "high", "alice", "NULL", {}, {})      \* ID: 1
    /\ CreateTask("Task", "Desc", "high", "alice", "NULL", {}, {1})    \* ID: 2
    /\ UpdateTaskStatus(2, "in_progress")  \* Would fail - blocked
    /\ \* If we could force complete without checking:
       \* tasks' = [tasks EXCEPT ![2].status = "completed"]
       \* This would violate CompletionDependencyCheck
       FALSE

\* Fix: Current spec already prevents this with transition validation

\* ----------------------------------------------------------------------------
\* Scenario 6: Deadlock Creation
\* ----------------------------------------------------------------------------
CreateDeadlock ==
    /\ Init
    /\ Authenticate("alice")
    /\ CreateTask("A", "Desc", "high", "alice", "NULL", {}, {})     \* ID: 1
    /\ CreateTask("B", "Desc", "high", "alice", "NULL", {}, {1})    \* ID: 2
    /\ CreateTask("C", "Desc", "high", "alice", "NULL", {}, {2})    \* ID: 3
    /\ \* If we could create circular dependency:
       \* CreateTask("D", "Desc", "high", "alice", "NULL", {}, {3, 1})
       \* This would create A→B→C→D→A cycle
       FALSE  \* NoCyclicDependencies prevents this

\* Fix: Cycle detection in CreateTask prevents this

\* ----------------------------------------------------------------------------
\* Scenario 7: Priority Inversion
\* ----------------------------------------------------------------------------
CreatePriorityInversion ==
    /\ Init
    /\ Authenticate("alice")
    /\ CreateTask("LowPriority", "Refactoring", "low", "alice", "NULL", {}, {})
    /\ UpdateTaskStatus(1, "in_progress")
    /\ Authenticate("bob")
    /\ CreateTask("CriticalBug", "SecurityFix", "critical", "bob", "NULL", {}, {1})
    /\ \* Critical task now blocked by low priority work
       PriorityInversionExists

\* Fix: Priority inheritance or preemption mechanism

\* ----------------------------------------------------------------------------
\* Scenario 8: Session Conflict
\* ----------------------------------------------------------------------------
CreateSessionConflict ==
    /\ Init
    /\ Authenticate("alice")
    /\ \* Try to authenticate alice again without logout
       ~Authenticate("alice")  \* Should fail
    /\ \* Or if multiple sessions were allowed:
       \* This would violate UniqueActiveSession
       TRUE

\* Fix: Current spec prevents double authentication

\* ----------------------------------------------------------------------------
\* Scenario 9: Abandoned Task
\* ----------------------------------------------------------------------------
CreateAbandonedTask ==
    /\ Init
    /\ Authenticate("alice")
    /\ CreateTask("Task", "Desc", "medium", "alice", "NULL", {}, {})
    /\ UpdateTaskStatus(1, "in_progress")
    /\ Logout
    /\ \* Advance time significantly
       \E i \in 1..40 : AdvanceTime
    /\ \* Task 1 is now abandoned (not updated for 40 time units)
       1 \in AbandonedTasks

\* Fix: Implement task timeout or automatic reassignment

\* ----------------------------------------------------------------------------
\* Scenario 10: Overdue Critical Task
\* ----------------------------------------------------------------------------
CreateOverdueCritical ==
    /\ Init
    /\ Authenticate("alice")
    /\ CreateTask("CriticalTask", "Urgent", "critical", "alice", 10, {}, {})
    /\ \* Advance time past due date
       \E i \in 1..15 : AdvanceTime
    /\ \* Task is overdue
       OverdueTasksCount > 0

\* Fix: Automatic escalation or alerting mechanism

\* ============================================================================
\* PROPERTY PRESERVATION PATTERNS
\* Show how to maintain properties during operations
\* ============================================================================

\* ----------------------------------------------------------------------------
\* Pattern 1: Safe Task Creation
\* ----------------------------------------------------------------------------
SafeCreateTask(title, desc, priority, assignee, dueDate, tags, deps) ==
    /\ CreateTask(title, desc, priority, assignee, dueDate, tags, deps)
    /\ \* Additional checks to preserve properties
       /\ WorkloadBalance'
       /\ DeadlineConsistency'
       /\ ~DeadlockExists'

\* ----------------------------------------------------------------------------
\* Pattern 2: Safe Status Update
\* ----------------------------------------------------------------------------
SafeUpdateStatus(taskId, newStatus) ==
    /\ UpdateTaskStatus(taskId, newStatus)
    /\ \* Ensure completion dependencies are met
       (newStatus = "completed" => CompletionDependencyCheck')

\* ----------------------------------------------------------------------------
\* Pattern 3: Safe Bulk Operation
\* ----------------------------------------------------------------------------
SafeBulkUpdate(taskIds, newStatus) ==
    /\ BulkUpdateStatus(taskIds, newStatus)
    /\ \* Preserve all tasks' dependency constraints
       /\ \A t \in taskIds : 
           (newStatus = "completed" => 
            \A dep \in tasks[t].dependencies : 
                tasks[dep].status = "completed")

\* ============================================================================
\* PROPERTY TESTING SEQUENCES
\* Specific sequences to test property preservation
\* ============================================================================

\* ----------------------------------------------------------------------------
\* Test 1: Dependency Chain Resolution
\* ----------------------------------------------------------------------------
TestDependencyChain ==
    /\ Init
    /\ Authenticate("alice")
    /\ CreateTask("A", "First", "high", "alice", "NULL", {}, {})
    /\ CreateTask("B", "Second", "high", "alice", "NULL", {}, {1})
    /\ CreateTask("C", "Third", "high", "alice", "NULL", {}, {2})
    /\ UpdateTaskStatus(1, "in_progress")
    /\ UpdateTaskStatus(1, "completed")
    /\ CheckDependencies  \* Should unblock B
    /\ UpdateTaskStatus(2, "in_progress")
    /\ UpdateTaskStatus(2, "completed")
    /\ CheckDependencies  \* Should unblock C
    /\ tasks[3].status = "pending"  \* C should be unblocked

\* ----------------------------------------------------------------------------
\* Test 2: Priority Escalation Chain
\* ----------------------------------------------------------------------------
TestPriorityEscalation ==
    /\ Init
    /\ Authenticate("alice")
    /\ CreateTask("Low", "Task", "low", "alice", "NULL", {}, {})
    /\ CreateTask("Critical", "Task", "critical", "alice", "NULL", {}, {1})
    /\ \* Should trigger priority escalation for task 1
       UpdateTaskPriority(1, "high")
    /\ tasks[1].priority \in {"high", "critical"}

\* ----------------------------------------------------------------------------
\* Test 3: Workload Rebalancing
\* ----------------------------------------------------------------------------
TestWorkloadRebalance ==
    /\ Init
    /\ Authenticate("alice")
    /\ \* Create several tasks for alice
       \E i \in 1..5 : 
           CreateTask("Task", "Desc", "medium", "alice", "NULL", {}, {})
    /\ \* Reassign some to bob
       ReassignTask(3, "bob")
    /\ ReassignTask(4, "bob")
    /\ \* Check balance improved
       WorkloadBalance'

\* ----------------------------------------------------------------------------
\* Test 4: Deadline Cascade
\* ----------------------------------------------------------------------------
TestDeadlineCascade ==
    /\ Init
    /\ Authenticate("alice")
    /\ CreateTask("Phase1", "Early", "high", "alice", 20, {}, {})
    /\ CreateTask("Phase2", "Middle", "high", "alice", 40, {}, {1})
    /\ CreateTask("Phase3", "Late", "high", "alice", 60, {}, {2})
    /\ \* All deadlines are consistent
       DeadlineConsistency

\* ============================================================================
\* PROPERTY VIOLATION DETECTORS
\* Predicates to detect when properties are about to be violated
\* ============================================================================

AboutToViolateWorkload(user) ==
    Cardinality({t \in DOMAIN tasks : 
        tasks[t].assignee = user /\ 
        tasks[t].status \in {"pending", "in_progress"}}) = 9
    \* One more task would violate WorkloadBalance (assuming max=10)

AboutToCreateDeadlock(newDeps) ==
    \E taskId \in newDeps :
        taskId \in TransitiveDeps(nextTaskId)
    \* Adding these dependencies would create a cycle

AboutToMissDeadline(taskId) ==
    /\ tasks[taskId].dueDate # "NULL"
    /\ clock >= tasks[taskId].dueDate - 5
    /\ tasks[taskId].status \in {"pending", "blocked"}
    \* Task likely to miss deadline soon

\* ============================================================================
\* PROPERTY FIX ACTIONS
\* Actions that restore violated properties
\* ============================================================================

FixPriorityInversion ==
    \E t1, t2 \in DOMAIN tasks :
        /\ t1 \in tasks[t2].dependencies
        /\ tasks[t2].priority = "critical"
        /\ tasks[t1].priority \in {"low", "medium"}
        /\ UpdateTaskPriority(t1, "high")

FixWorkloadImbalance ==
    \E overloaded, underloaded \in Users :
        LET overTasks == {t \in DOMAIN tasks : tasks[t].assignee = overloaded}
            underTasks == {t \in DOMAIN tasks : tasks[t].assignee = underloaded}
        IN
        /\ Cardinality(overTasks) > Cardinality(underTasks) + 2
        /\ \E taskId \in overTasks :
            ReassignTask(taskId, underloaded)

FixAbandonedTask ==
    \E taskId \in AbandonedTasks :
        \/ UpdateTaskStatus(taskId, "cancelled")
        \/ ReassignTask(taskId, CHOOSE u \in Users : 
            Cardinality(GetUserTasks(u)) < 5)

\* ============================================================================
\* COMPOSITE PROPERTY TESTS
\* Test multiple properties together
\* ============================================================================

TestAllSafetyProperties ==
    /\ Init
    /\ \* Perform various operations
       Authenticate("alice")
    /\ CreateTask("T1", "D1", "high", "alice", 50, {}, {})
    /\ CreateTask("T2", "D2", "critical", "bob", 30, {}, {1})
    /\ UpdateTaskStatus(1, "in_progress")
    /\ \* Check all safety properties hold
       /\ TypeInvariant
       /\ SafetyInvariant
       /\ DependencyTemporalConsistency
       /\ DeadlineConsistency
       /\ CompletionDependencyCheck
       /\ ~DeadlockExists

TestProgressUnderLoad ==
    /\ Init
    /\ \* Create high load scenario
       \A u \in Users : Authenticate(u)
    /\ \A i \in 1..9 : 
        CreateTask("Task", "Desc", "medium", 
                   CHOOSE u \in Users : TRUE, "NULL", {}, {})
    /\ \* Verify progress properties
       /\ EventualCompletion
       /\ WorkDistribution
       /\ ~WorkloadImbalanced

================================================================================