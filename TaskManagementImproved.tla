---------------------------- MODULE TaskManagementImproved ----------------------------
EXTENDS Integers, Sequences, FiniteSets, TLC

CONSTANTS 
    Users,          \* Set of users
    MaxTasks,       \* Maximum number of tasks
    MaxTime,        \* Maximum time value for simulation
    Titles,         \* Set of possible task titles
    Descriptions    \* Set of possible task descriptions

VARIABLES
    tasks,          \* Function from task ID to task record
    userTasks,      \* Function from user ID to set of task IDs
    nextTaskId,     \* Counter for generating unique task IDs
    currentUser,    \* Currently authenticated user
    clock,          \* Global clock for timestamps
    sessions        \* Active user sessions

\* Model values
ModelValues == {
    "NULL",
    "EMPTY_STRING"
}

\* Task states enumeration with valid transitions
TaskStates == {"pending", "in_progress", "completed", "cancelled", "blocked"}

\* Priority levels
Priorities == {"low", "medium", "high", "critical"}

\* Valid state transitions
ValidTransitions == {
    <<"pending", "in_progress">>,
    <<"pending", "cancelled">>,
    <<"pending", "blocked">>,
    <<"in_progress", "completed">>,
    <<"in_progress", "cancelled">>,
    <<"in_progress", "blocked">>,
    <<"in_progress", "pending">>,      \* Allow reverting to pending
    <<"blocked", "pending">>,
    <<"blocked", "in_progress">>,
    <<"blocked", "cancelled">>
}

\* Helper functions
IsValidTransition(fromState, toState) ==
    <<fromState, toState>> \in ValidTransitions

GetUserTasks(user) ==
    IF user \in DOMAIN userTasks THEN userTasks[user] ELSE {}

TaskExists(taskId) ==
    taskId \in DOMAIN tasks

\* Type invariants
TypeInvariant ==
    /\ tasks \in [1..MaxTasks -> [
           id: 1..MaxTasks,
           title: Titles,
           description: Descriptions,
           status: TaskStates,
           priority: Priorities,
           assignee: Users,
           createdBy: Users,
           createdAt: 0..MaxTime,
           updatedAt: 0..MaxTime,
           dueDate: 0..MaxTime \cup {"NULL"},
           tags: SUBSET {"bug", "feature", "enhancement", "documentation"},
           dependencies: SUBSET (1..MaxTasks)
       ]]
    /\ userTasks \in [Users -> SUBSET (1..MaxTasks)]
    /\ nextTaskId \in 1..(MaxTasks + 1)
    /\ currentUser \in Users \cup {"NULL"}
    /\ clock \in 0..MaxTime
    /\ sessions \in [Users -> BOOLEAN]
    /\ DOMAIN tasks \subseteq 1..MaxTasks

\* System initialization
Init ==
    /\ tasks = [i \in {} |-> CHOOSE x : FALSE]  \* Empty function
    /\ userTasks = [u \in Users |-> {}]
    /\ nextTaskId = 1
    /\ currentUser = "NULL"
    /\ clock = 0
    /\ sessions = [u \in Users |-> FALSE]

\* Time advancement
AdvanceTime ==
    /\ clock < MaxTime
    /\ clock' = clock + 1
    /\ UNCHANGED <<tasks, userTasks, nextTaskId, currentUser, sessions>>

\* User authentication
Authenticate(user) ==
    /\ user \in Users
    /\ ~sessions[user]  \* User not already logged in
    /\ currentUser' = user
    /\ sessions' = [sessions EXCEPT ![user] = TRUE]
    /\ UNCHANGED <<tasks, userTasks, nextTaskId, clock>>

\* Logout action
Logout ==
    /\ currentUser # "NULL"
    /\ currentUser \in Users
    /\ sessions' = [sessions EXCEPT ![currentUser] = FALSE]
    /\ currentUser' = "NULL"
    /\ UNCHANGED <<tasks, userTasks, nextTaskId, clock>>

\* Create a new task with validation
CreateTask(title, description, priority, assignee, dueDate, tags, deps) ==
    /\ currentUser # "NULL"
    /\ currentUser \in Users
    /\ nextTaskId <= MaxTasks
    /\ title \in Titles
    /\ description \in Descriptions
    /\ priority \in Priorities
    /\ assignee \in Users
    /\ dueDate \in 0..MaxTime \cup {"NULL"}
    /\ tags \subseteq {"bug", "feature", "enhancement", "documentation"}
    /\ deps \subseteq DOMAIN tasks  \* Dependencies must exist
    /\ \A dep \in deps : tasks[dep].status # "cancelled"  \* Can't depend on cancelled tasks
    /\ LET newTask == [
           id |-> nextTaskId,
           title |-> title,
           description |-> description,
           status |-> IF deps = {} THEN "pending" ELSE "blocked",
           priority |-> priority,
           assignee |-> assignee,
           createdBy |-> currentUser,
           createdAt |-> clock,
           updatedAt |-> clock,
           dueDate |-> dueDate,
           tags |-> tags,
           dependencies |-> deps
       ] IN
       /\ tasks' = [i \in DOMAIN tasks \cup {nextTaskId} |-> 
                     IF i = nextTaskId THEN newTask ELSE tasks[i]]
       /\ userTasks' = [u \in Users |->
                         IF u = assignee 
                         THEN GetUserTasks(u) \cup {nextTaskId}
                         ELSE GetUserTasks(u)]
       /\ nextTaskId' = nextTaskId + 1
       /\ UNCHANGED <<currentUser, clock, sessions>>

\* Update task status with validation
UpdateTaskStatus(taskId, newStatus) ==
    /\ currentUser # "NULL"
    /\ currentUser \in Users
    /\ TaskExists(taskId)
    /\ taskId \in GetUserTasks(currentUser)  \* User owns or is assigned the task
    /\ newStatus \in TaskStates
    /\ IsValidTransition(tasks[taskId].status, newStatus)
    /\ \* Check dependencies for unblocking
       (newStatus = "in_progress" => 
         \A dep \in tasks[taskId].dependencies : 
           tasks[dep].status = "completed")
    /\ tasks' = [tasks EXCEPT 
                  ![taskId].status = newStatus,
                  ![taskId].updatedAt = clock]
    /\ UNCHANGED <<userTasks, nextTaskId, currentUser, clock, sessions>>

\* Update task priority
UpdateTaskPriority(taskId, newPriority) ==
    /\ currentUser # "NULL"
    /\ currentUser \in Users
    /\ TaskExists(taskId)
    /\ taskId \in GetUserTasks(currentUser)
    /\ newPriority \in Priorities
    /\ tasks' = [tasks EXCEPT 
                  ![taskId].priority = newPriority,
                  ![taskId].updatedAt = clock]
    /\ UNCHANGED <<userTasks, nextTaskId, currentUser, clock, sessions>>

\* Reassign task to another user
ReassignTask(taskId, newAssignee) ==
    /\ currentUser # "NULL"
    /\ currentUser \in Users
    /\ TaskExists(taskId)
    /\ taskId \in GetUserTasks(currentUser)
    /\ newAssignee \in Users
    /\ newAssignee # tasks[taskId].assignee
    /\ LET oldAssignee == tasks[taskId].assignee IN
       /\ tasks' = [tasks EXCEPT 
                     ![taskId].assignee = newAssignee,
                     ![taskId].updatedAt = clock]
       /\ userTasks' = [u \in Users |->
                         IF u = oldAssignee THEN GetUserTasks(u) \ {taskId}
                         ELSE IF u = newAssignee THEN GetUserTasks(u) \cup {taskId}
                         ELSE GetUserTasks(u)]
    /\ UNCHANGED <<nextTaskId, currentUser, clock, sessions>>

\* Update task details (title, description, due date)
UpdateTaskDetails(taskId, title, description, dueDate) ==
    /\ currentUser # "NULL"
    /\ currentUser \in Users
    /\ TaskExists(taskId)
    /\ taskId \in GetUserTasks(currentUser)
    /\ title \in Titles
    /\ description \in Descriptions
    /\ dueDate \in 0..MaxTime \cup {"NULL"}
    /\ tasks' = [tasks EXCEPT 
                  ![taskId].title = title,
                  ![taskId].description = description,
                  ![taskId].dueDate = dueDate,
                  ![taskId].updatedAt = clock]
    /\ UNCHANGED <<userTasks, nextTaskId, currentUser, clock, sessions>>

\* Delete a task (only completed or cancelled)
DeleteTask(taskId) ==
    /\ currentUser # "NULL"
    /\ currentUser \in Users
    /\ TaskExists(taskId)
    /\ taskId \in GetUserTasks(currentUser)
    /\ tasks[taskId].status \in {"completed", "cancelled"}
    /\ \* No other tasks depend on this one
       \A otherTaskId \in DOMAIN tasks \ {taskId} :
         taskId \notin tasks[otherTaskId].dependencies
    /\ LET remainingTasks == [id \in DOMAIN tasks \ {taskId} |-> tasks[id]]
       IN tasks' = remainingTasks
    /\ userTasks' = [u \in Users |-> GetUserTasks(u) \ {taskId}]
    /\ UNCHANGED <<nextTaskId, currentUser, clock, sessions>>

\* Check and unblock tasks when dependencies are completed
CheckDependencies ==
    /\ \E taskId \in DOMAIN tasks :
       /\ tasks[taskId].status = "blocked"
       /\ \A dep \in tasks[taskId].dependencies : 
           tasks[dep].status = "completed"
       /\ tasks' = [tasks EXCEPT 
                     ![taskId].status = "pending",
                     ![taskId].updatedAt = clock]
    /\ UNCHANGED <<userTasks, nextTaskId, currentUser, clock, sessions>>

\* Bulk update operation
BulkUpdateStatus(taskIds, newStatus) ==
    /\ currentUser # "NULL"
    /\ currentUser \in Users
    /\ taskIds \subseteq DOMAIN tasks
    /\ taskIds \subseteq GetUserTasks(currentUser)
    /\ newStatus \in TaskStates
    /\ \A taskId \in taskIds : 
         IsValidTransition(tasks[taskId].status, newStatus)
    /\ tasks' = [taskId \in DOMAIN tasks |->
                  IF taskId \in taskIds 
                  THEN [tasks[taskId] EXCEPT 
                        !.status = newStatus,
                        !.updatedAt = clock]
                  ELSE tasks[taskId]]
    /\ UNCHANGED <<userTasks, nextTaskId, currentUser, clock, sessions>>

\* Safety properties
NoOrphanTasks ==
    \A taskId \in DOMAIN tasks :
        \E user \in Users : taskId \in GetUserTasks(user)

TaskOwnership ==
    \A taskId \in DOMAIN tasks :
        tasks[taskId].assignee \in Users /\
        taskId \in GetUserTasks(tasks[taskId].assignee)

ValidTaskIds ==
    \A taskId \in DOMAIN tasks : 
        /\ taskId < nextTaskId
        /\ taskId >= 1

NoDuplicateTaskIds ==
    \A t1, t2 \in DOMAIN tasks :
        t1 = t2 \/ tasks[t1].id # tasks[t2].id

ValidStateTransitionsInvariant ==
    \A taskId \in DOMAIN tasks :
        tasks[taskId].status \in TaskStates

ConsistentTimestamps ==
    \A taskId \in DOMAIN tasks :
        /\ tasks[taskId].createdAt <= tasks[taskId].updatedAt
        /\ tasks[taskId].updatedAt <= clock

NoCyclicDependencies ==
    LET
        \* Transitive closure of dependencies
        RECURSIVE TransitiveDeps(_)
        TransitiveDeps(taskId) ==
            IF ~TaskExists(taskId) THEN {}
            ELSE LET directDeps == tasks[taskId].dependencies IN
                 directDeps \cup 
                 UNION {TransitiveDeps(dep) : dep \in directDeps}
    IN
    \A taskId \in DOMAIN tasks :
        taskId \notin TransitiveDeps(taskId)

AuthenticationRequired ==
    \* All task operations require authentication
    \A taskId \in DOMAIN tasks :
        tasks[taskId].createdBy \in Users

SafetyInvariant ==
    /\ NoOrphanTasks
    /\ TaskOwnership
    /\ ValidTaskIds
    /\ NoDuplicateTaskIds
    /\ ValidStateTransitionsInvariant
    /\ ConsistentTimestamps
    /\ NoCyclicDependencies
    /\ AuthenticationRequired

\* Liveness properties
EventualCompletion ==
    \A taskId \in DOMAIN tasks :
        (tasks[taskId].status = "pending") ~>
        (tasks[taskId].status \in {"completed", "cancelled"})

FairProgress ==
    \A taskId \in DOMAIN tasks :
        (tasks[taskId].status = "in_progress") ~>
        (tasks[taskId].status \in {"completed", "cancelled"})

EventualUnblocking ==
    \A taskId \in DOMAIN tasks :
        (tasks[taskId].status = "blocked") ~>
        (tasks[taskId].status # "blocked")

EventualAuthentication ==
    \A user \in Users :
        <>(sessions[user] = TRUE)

NoStarvation ==
    \A taskId \in DOMAIN tasks :
        (tasks[taskId].priority = "critical" /\ 
         tasks[taskId].status = "pending") ~>
        (tasks[taskId].status = "in_progress")

\* Next state relation
Next ==
    \/ AdvanceTime
    \/ \E user \in Users : Authenticate(user)
    \/ Logout
    \/ \E t \in Titles, d \in Descriptions, p \in Priorities, 
         u \in Users, dd \in 0..MaxTime \cup {"NULL"},
         tags \in SUBSET {"bug", "feature", "enhancement", "documentation"},
         deps \in SUBSET DOMAIN tasks :
       CreateTask(t, d, p, u, dd, tags, deps)
    \/ \E taskId \in DOMAIN tasks, newStatus \in TaskStates :
       UpdateTaskStatus(taskId, newStatus)
    \/ \E taskId \in DOMAIN tasks, newPriority \in Priorities :
       UpdateTaskPriority(taskId, newPriority)
    \/ \E taskId \in DOMAIN tasks, newAssignee \in Users :
       ReassignTask(taskId, newAssignee)
    \/ \E taskId \in DOMAIN tasks, t \in Titles, 
         d \in Descriptions, dd \in 0..MaxTime \cup {"NULL"} :
       UpdateTaskDetails(taskId, t, d, dd)
    \/ \E taskId \in DOMAIN tasks : DeleteTask(taskId)
    \/ CheckDependencies
    \/ \E taskIds \in SUBSET DOMAIN tasks, newStatus \in TaskStates :
       taskIds # {} /\ BulkUpdateStatus(taskIds, newStatus)

\* Fairness conditions
Fairness ==
    /\ WF_<<tasks, userTasks, nextTaskId, currentUser, clock, sessions>>(Next)
    /\ SF_<<tasks>>(CheckDependencies)
    /\ \A user \in Users : 
       SF_<<currentUser, sessions>>(Authenticate(user))

\* Complete specification
Spec ==
    /\ Init
    /\ [][Next]_<<tasks, userTasks, nextTaskId, currentUser, clock, sessions>>
    /\ Fairness

\* Properties to check
THEOREM TypeCorrectness == Spec => []TypeInvariant
THEOREM SafetyHolds == Spec => []SafetyInvariant
THEOREM LivenessHolds == Spec => (EventualCompletion /\ FairProgress)
THEOREM NoDeadlock == Spec => []<>Next
THEOREM Termination == Spec => <>(\A taskId \in DOMAIN tasks : 
                                    tasks[taskId].status \in {"completed", "cancelled"})

================================================================================