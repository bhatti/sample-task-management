---------------------------- MODULE TaskManagement ----------------------------
EXTENDS Integers, Sequences, FiniteSets, TLC

CONSTANTS Users, MaxTasks

VARIABLES 
    tasks,          \* Function from task ID to task record
    userTasks,      \* Function from user ID to set of task IDs  
    nextTaskId,     \* Counter for generating unique task IDs
    currentUser     \* Currently authenticated user

\* Define NULL as a model value
NULL == CHOOSE x : x \notin Users

\* Task states enumeration
TaskStates == {"pending", "in_progress", "completed", "cancelled"}

\* Priority levels
Priorities == {"low", "medium", "high"}

\* Type invariants
TypeInvariant == 
    /\ tasks \in [1..MaxTasks -> [
           id: 1..MaxTasks,
           title: STRING,
           description: STRING,
           status: TaskStates,
           priority: Priorities,
           assignee: Users,
           createdAt: Nat,
           dueDate: Nat \cup {NULL}
       ]]
    /\ userTasks \in [Users -> SUBSET (1..MaxTasks)]
    /\ nextTaskId \in 1..(MaxTasks + 1)
    /\ currentUser \in Users \cup {NULL}
    /\ DOMAIN tasks \subseteq 1..MaxTasks

\* System initialization
Init == 
    /\ tasks = << >>
    /\ userTasks = [u \in Users |-> {}]
    /\ nextTaskId = 1
    /\ currentUser = NULL

\* User authentication
Authenticate(user) ==
    /\ user \in Users
    /\ currentUser' = user
    /\ UNCHANGED <<tasks, userTasks, nextTaskId>>

\* Logout action
Logout ==
    /\ currentUser # NULL
    /\ currentUser' = NULL
    /\ UNCHANGED <<tasks, userTasks, nextTaskId>>

\* Create a new task
CreateTask ==
    /\ currentUser # NULL
    /\ nextTaskId <= MaxTasks
    /\ \E title \in STRING, description \in STRING, 
         priority \in Priorities, dueDate \in Nat \cup {NULL} :
       LET newTask == [
           id |-> nextTaskId,
           title |-> title,
           description |-> description,
           status |-> "pending",
           priority |-> priority,
           assignee |-> currentUser,
           createdAt |-> nextTaskId, \* Simplified timestamp
           dueDate |-> dueDate
       ] IN
       /\ tasks' = tasks @@ (nextTaskId :> newTask)
       /\ userTasks' = [userTasks EXCEPT ![currentUser] = @ \cup {nextTaskId}]
       /\ nextTaskId' = nextTaskId + 1
       /\ UNCHANGED currentUser

\* Update task status
UpdateTaskStatus ==
    /\ currentUser # NULL
    /\ \E taskId \in DOMAIN tasks, newStatus \in TaskStates :
       /\ taskId \in userTasks[currentUser]  \* User owns the task
       /\ \/ newStatus = "in_progress" /\ tasks[taskId].status = "pending"
          \/ newStatus = "completed" /\ tasks[taskId].status = "in_progress"
          \/ newStatus = "cancelled" /\ tasks[taskId].status \in {"pending", "in_progress"}
       /\ tasks' = [tasks EXCEPT ![taskId].status = newStatus]
       /\ UNCHANGED <<userTasks, nextTaskId, currentUser>>

\* Delete a task
DeleteTask ==
    /\ currentUser # NULL
    /\ \E taskId \in DOMAIN tasks :
       /\ taskId \in userTasks[currentUser]
       /\ tasks[taskId].status \in {"completed", "cancelled"}  \* Can only delete finished tasks
       /\ LET remainingTasks == [id \in (DOMAIN tasks \ {taskId}) |-> tasks[id]]
          IN tasks' = remainingTasks
       /\ userTasks' = [userTasks EXCEPT ![currentUser] = @ \ {taskId}]
       /\ UNCHANGED <<nextTaskId, currentUser>>

\* Safety properties
NoOrphanTasks ==
    \A taskId \in DOMAIN tasks :
        \E user \in Users : taskId \in userTasks[user]

TaskOwnership ==
    \A taskId \in DOMAIN tasks :
        \A user \in Users :
            taskId \in userTasks[user] => tasks[taskId].assignee = user

ValidTaskIds ==
    \A taskId \in DOMAIN tasks : taskId < nextTaskId

SafetyInvariant ==
    /\ NoOrphanTasks
    /\ TaskOwnership  
    /\ ValidTaskIds

\* Liveness properties
EventualCompletion ==
    \A taskId \in DOMAIN tasks :
        (tasks[taskId].status = "pending") ~> 
        (tasks[taskId].status \in {"completed", "cancelled"})

FairProgress ==
    \A taskId \in DOMAIN tasks :
        (tasks[taskId].status = "in_progress") ~> 
        (tasks[taskId].status = "completed")

\* Next state relation
Next == 
    \/ \E user \in Users : Authenticate(user)
    \/ Logout
    \/ CreateTask
    \/ UpdateTaskStatus
    \/ DeleteTask

\* Complete specification
Spec == 
    /\ Init 
    /\ [][Next]_<<tasks, userTasks, nextTaskId, currentUser>>
    /\ WF_<<tasks, userTasks, nextTaskId, currentUser>>(Next)

\* Properties to check
THEOREM TypeCorrectness == Spec => []TypeInvariant
THEOREM SafetyHolds == Spec => []SafetyInvariant
THEOREM LivenessHolds == Spec => EventualCompletion
================================================================================
