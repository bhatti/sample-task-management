---------------------------- MODULE TestScenarios ----------------------------
\* Test scenarios for TaskManagementImproved module
\* These scenarios test various aspects of the task management system

EXTENDS TaskManagementImproved, TLC

\* ============================================================================
\* Test Scenario 1: Basic Task Lifecycle
\* ============================================================================
TestBasicLifecycle ==
    /\ currentUser = "NULL"
    /\ Authenticate(alice)
    /\ CreateTask(task1, desc1, "medium", alice, 10, {}, {})
    /\ \E taskId \in DOMAIN tasks :
       /\ UpdateTaskStatus(taskId, "in_progress")
       /\ UpdateTaskStatus(taskId, "completed")

\* ============================================================================
\* Test Scenario 2: Multi-User Collaboration
\* ============================================================================
TestMultiUserCollaboration ==
    LET
        \* Alice creates and assigns task to Bob
        AliceCreatesTask == 
            /\ Authenticate(alice)
            /\ CreateTask(task1, desc1, "high", bob, 15, {"feature"}, {})
            /\ Logout
        
        \* Bob updates the task
        BobUpdatesTask ==
            /\ Authenticate(bob)
            /\ \E taskId \in GetUserTasks(bob) :
                UpdateTaskStatus(taskId, "in_progress")
            /\ Logout
        
        \* Charlie cannot access Bob's task
        CharlieCannotAccess ==
            /\ Authenticate(charlie)
            /\ \A taskId \in DOMAIN tasks :
                taskId \notin GetUserTasks(charlie)
    IN
    /\ AliceCreatesTask
    /\ BobUpdatesTask
    /\ CharlieCannotAccess

\* ============================================================================
\* Test Scenario 3: Task Dependencies
\* ============================================================================
TestTaskDependencies ==
    LET
        \* Create parent task
        CreateParentTask ==
            /\ Authenticate(alice)
            /\ CreateTask(task1, desc1, "high", alice, 20, {"feature"}, {})
        
        \* Create dependent task (should be blocked)
        CreateDependentTask ==
            /\ \E parentId \in DOMAIN tasks :
                CreateTask(task2, desc2, "medium", alice, 25, {"enhancement"}, {parentId})
        
        \* Verify dependent task is blocked
        VerifyBlocked ==
            \E taskId \in DOMAIN tasks :
                /\ tasks[taskId].dependencies # {}
                /\ tasks[taskId].status = "blocked"
        
        \* Complete parent task
        CompleteParent ==
            /\ \E parentId \in DOMAIN tasks :
                /\ tasks[parentId].dependencies = {}
                /\ UpdateTaskStatus(parentId, "in_progress")
                /\ UpdateTaskStatus(parentId, "completed")
        
        \* Check dependent task unblocked
        CheckUnblocked ==
            /\ CheckDependencies
            /\ \E taskId \in DOMAIN tasks :
                /\ tasks[taskId].dependencies # {}
                /\ tasks[taskId].status = "pending"
    IN
    /\ CreateParentTask
    /\ CreateDependentTask
    /\ VerifyBlocked
    /\ CompleteParent
    /\ CheckUnblocked

\* ============================================================================
\* Test Scenario 4: Priority Escalation
\* ============================================================================
TestPriorityEscalation ==
    /\ Authenticate(alice)
    /\ CreateTask(task1, desc1, "low", alice, 30, {"bug"}, {})
    /\ \E taskId \in DOMAIN tasks :
       /\ tasks[taskId].priority = "low"
       /\ UpdateTaskPriority(taskId, "medium")
       /\ UpdateTaskPriority(taskId, "high")
       /\ UpdateTaskPriority(taskId, "critical")
       /\ tasks'[taskId].priority = "critical"

\* ============================================================================
\* Test Scenario 5: Task Reassignment
\* ============================================================================
TestTaskReassignment ==
    LET
        \* Alice creates task assigned to herself
        AliceCreatesOwnTask ==
            /\ Authenticate(alice)
            /\ CreateTask(task1, desc1, "medium", alice, 15, {}, {})
        
        \* Alice reassigns to Bob
        ReassignToBob ==
            /\ \E taskId \in GetUserTasks(alice) :
                ReassignTask(taskId, bob)
        
        \* Verify Bob now owns the task
        VerifyBobOwns ==
            /\ \E taskId \in GetUserTasks(bob) :
                tasks[taskId].assignee = bob
            /\ \A taskId \in DOMAIN tasks :
                taskId \notin GetUserTasks(alice)
    IN
    /\ AliceCreatesOwnTask
    /\ ReassignToBob
    /\ VerifyBobOwns

\* ============================================================================
\* Test Scenario 6: Bulk Operations
\* ============================================================================
TestBulkOperations ==
    LET
        \* Create multiple tasks
        CreateMultipleTasks ==
            /\ Authenticate(alice)
            /\ CreateTask(task1, desc1, "low", alice, 10, {"bug"}, {})
            /\ CreateTask(task2, desc2, "medium", alice, 15, {"feature"}, {})
            /\ CreateTask(task3, desc3, "high", alice, 20, {"enhancement"}, {})
        
        \* Bulk update to in_progress
        BulkStart ==
            /\ LET taskIds == GetUserTasks(alice) IN
                BulkUpdateStatus(taskIds, "in_progress")
        
        \* Verify all updated
        VerifyAllInProgress ==
            \A taskId \in GetUserTasks(alice) :
                tasks[taskId].status = "in_progress"
    IN
    /\ CreateMultipleTasks
    /\ BulkStart
    /\ VerifyAllInProgress

\* ============================================================================
\* Test Scenario 7: Invalid Operations (Should Fail)
\* ============================================================================
TestInvalidOperations ==
    LET
        \* Try to create task without authentication
        CreateWithoutAuth ==
            /\ currentUser = "NULL"
            /\ ~CreateTask(task1, desc1, "medium", alice, 10, {}, {})
        
        \* Try invalid state transition
        InvalidTransition ==
            /\ Authenticate(alice)
            /\ CreateTask(task1, desc1, "medium", alice, 10, {}, {})
            /\ \E taskId \in DOMAIN tasks :
                /\ tasks[taskId].status = "pending"
                /\ ~UpdateTaskStatus(taskId, "completed")  \* Should fail
        
        \* Try to delete non-completed task
        DeleteIncomplete ==
            /\ \E taskId \in DOMAIN tasks :
                /\ tasks[taskId].status = "pending"
                /\ ~DeleteTask(taskId)  \* Should fail
    IN
    /\ CreateWithoutAuth
    /\ InvalidTransition
    /\ DeleteIncomplete

\* ============================================================================
\* Test Scenario 8: Concurrent Sessions
\* ============================================================================
TestConcurrentSessions ==
    LET
        \* Multiple users authenticate simultaneously
        MultiAuth ==
            /\ Authenticate(alice)
            /\ sessions[alice] = TRUE
            /\ currentUser' = bob  \* Switch context
            /\ Authenticate(bob)
            /\ sessions[bob] = TRUE
        
        \* Both create tasks
        BothCreateTasks ==
            /\ currentUser = alice
            /\ CreateTask(task1, desc1, "high", alice, 10, {}, {})
            /\ currentUser' = bob
            /\ CreateTask(task2, desc2, "low", bob, 15, {}, {})
        
        \* Verify isolation
        VerifyIsolation ==
            /\ Cardinality(GetUserTasks(alice)) = 1
            /\ Cardinality(GetUserTasks(bob)) = 1
            /\ GetUserTasks(alice) \cap GetUserTasks(bob) = {}
    IN
    /\ MultiAuth
    /\ BothCreateTasks
    /\ VerifyIsolation

\* ============================================================================
\* Test Scenario 9: Time-based Operations
\* ============================================================================
TestTimeBasedOperations ==
    LET
        \* Create task with due date
        CreateTimedTask ==
            /\ Authenticate(alice)
            /\ clock = 0
            /\ CreateTask(task1, desc1, "high", alice, 5, {"urgent"}, {})
        
        \* Advance time
        TimeProgresses ==
            /\ AdvanceTime
            /\ AdvanceTime
            /\ AdvanceTime
            /\ clock = 3
        
        \* Update task (should have updated timestamp)
        UpdateWithTime ==
            /\ \E taskId \in DOMAIN tasks :
                /\ UpdateTaskStatus(taskId, "in_progress")
                /\ tasks'[taskId].updatedAt = 3
                /\ tasks'[taskId].createdAt = 0
    IN
    /\ CreateTimedTask
    /\ TimeProgresses
    /\ UpdateWithTime

\* ============================================================================
\* Test Scenario 10: Cyclic Dependency Prevention
\* ============================================================================
TestCyclicDependencyPrevention ==
    LET
        \* Create three tasks
        CreateThreeTasks ==
            /\ Authenticate(alice)
            /\ CreateTask(task1, desc1, "high", alice, 10, {}, {})
            /\ CreateTask(task2, desc2, "medium", alice, 15, {}, {1})
            /\ CreateTask(task3, desc3, "low", alice, 20, {}, {2})
        
        \* Try to create cycle (should fail)
        AttemptCycle ==
            /\ \E task1Id, task3Id \in DOMAIN tasks :
                /\ task1Id = 1
                /\ task3Id = 3
                /\ tasks[task1Id].dependencies = {}
                /\ task3Id \in tasks[task3Id].dependencies
                /\ ~(tasks' = [tasks EXCEPT ![task1Id].dependencies = {task3Id}])
    IN
    /\ CreateThreeTasks
    /\ AttemptCycle
    /\ NoCyclicDependencies  \* Should always hold

\* ============================================================================
\* Test Scenario 11: Edge Cases
\* ============================================================================
TestEdgeCases ==
    LET
        \* Max tasks creation
        CreateMaxTasks ==
            /\ Authenticate(alice)
            /\ \A i \in 1..MaxTasks :
                CreateTask(
                    CHOOSE t \in Titles : TRUE,
                    CHOOSE d \in Descriptions : TRUE,
                    "medium",
                    alice,
                    i * 5,
                    {},
                    {}
                )
            /\ nextTaskId = MaxTasks + 1
        
        \* Try to exceed max (should fail)
        ExceedMax ==
            /\ nextTaskId > MaxTasks
            /\ ~CreateTask(task1, desc1, "low", alice, 100, {}, {})
        
        \* Delete all tasks
        DeleteAll ==
            /\ \A taskId \in DOMAIN tasks :
                /\ UpdateTaskStatus(taskId, "in_progress")
                /\ UpdateTaskStatus(taskId, "completed")
                /\ DeleteTask(taskId)
            /\ DOMAIN tasks = {}
    IN
    /\ CreateMaxTasks
    /\ ExceedMax
    /\ DeleteAll

\* ============================================================================
\* Test Scenario 12: Complex Workflow
\* ============================================================================
TestComplexWorkflow ==
    LET
        \* Phase 1: Setup project structure
        SetupProject ==
            /\ Authenticate(alice)
            /\ CreateTask(task1, desc1, "critical", alice, 5, {"feature"}, {})  \* Main feature
            /\ CreateTask(task2, desc2, "high", bob, 10, {"bug"}, {})          \* Bug fix
            /\ CreateTask(task3, desc3, "medium", charlie, 15, {"enhancement"}, {1})  \* Depends on feature
            /\ CreateTask(task4, desc1, "low", alice, 20, {"documentation"}, {1, 3})  \* Depends on both
        
        \* Phase 2: Work progression
        WorkProgression ==
            /\ UpdateTaskStatus(2, "in_progress")  \* Start bug fix
            /\ UpdateTaskStatus(2, "completed")     \* Complete bug fix
            /\ UpdateTaskStatus(1, "in_progress")   \* Start main feature
            /\ UpdateTaskPriority(3, "high")        \* Escalate enhancement
            /\ UpdateTaskStatus(1, "completed")     \* Complete feature
            /\ CheckDependencies                    \* Unblock task 3
            /\ UpdateTaskStatus(3, "in_progress")   \* Start enhancement
        
        \* Phase 3: Reassignment and completion
        ReassignAndComplete ==
            /\ ReassignTask(3, alice)              \* Alice takes over enhancement
            /\ UpdateTaskStatus(3, "completed")     \* Complete enhancement
            /\ CheckDependencies                    \* Unblock documentation
            /\ UpdateTaskStatus(4, "in_progress")   \* Start documentation
            /\ UpdateTaskDetails(4, task4, desc3, 25)  \* Update doc details
            /\ UpdateTaskStatus(4, "completed")     \* Complete documentation
        
        \* Phase 4: Cleanup
        Cleanup ==
            /\ DeleteTask(2)  \* Delete completed bug
            /\ DeleteTask(1)  \* Delete completed feature
            /\ DeleteTask(3)  \* Delete completed enhancement
            /\ DeleteTask(4)  \* Delete completed documentation
    IN
    /\ SetupProject
    /\ WorkProgression
    /\ ReassignAndComplete
    /\ Cleanup

\* ============================================================================
\* Assertion Tests
\* ============================================================================

\* Test that authentication is required for all operations
AssertAuthenticationRequired ==
    /\ currentUser = "NULL"
    => /\ ~(\E t \in Titles, d \in Descriptions, p \in Priorities, 
             u \in Users, dd \in 0..MaxTime \cup {"NULL"}, 
             tags \in SUBSET {"bug", "feature", "enhancement", "documentation"},
             deps \in SUBSET DOMAIN tasks :
             CreateTask(t, d, p, u, dd, tags, deps))
       /\ ~(\E taskId \in DOMAIN tasks, newStatus \in TaskStates :
             UpdateTaskStatus(taskId, newStatus))
       /\ ~(\E taskId \in DOMAIN tasks : DeleteTask(taskId))

\* Test that task IDs are unique and sequential
AssertUniqueSequentialIds ==
    /\ \A t1, t2 \in DOMAIN tasks :
        t1 # t2 => tasks[t1].id # tasks[t2].id
    /\ \A taskId \in DOMAIN tasks :
        taskId = tasks[taskId].id

\* Test that dependencies are properly managed
AssertDependencyIntegrity ==
    /\ \A taskId \in DOMAIN tasks :
        \A dep \in tasks[taskId].dependencies :
            dep \in DOMAIN tasks  \* All dependencies exist
    /\ \A taskId \in DOMAIN tasks :
        tasks[taskId].status = "blocked" <=>
        (\E dep \in tasks[taskId].dependencies : 
         tasks[dep].status # "completed")

\* Test session management
AssertSessionManagement ==
    /\ currentUser # "NULL" => sessions[currentUser] = TRUE
    /\ \A u \in Users :
        sessions[u] = TRUE => 
        \E moment : currentUser = u  \* User was authenticated at some point

================================================================================