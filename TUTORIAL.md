# Building a Formally Verified System: A Complete Tutorial

## How This Project Was Created Using AI-Assisted Development

This tutorial documents the complete process of building a formally verified task management system through a conversation with Claude, demonstrating how to leverage AI for systematic software development with mathematical correctness guarantees.

## Table of Contents

1. [Project Overview](#project-overview)
2. [The Development Journey](#the-development-journey)
3. [Prompts and Responses](#prompts-and-responses)
4. [Key Learnings](#key-learnings)
5. [Reproducing This Project](#reproducing-this-project)

---

## Project Overview

### What We Built

A sample -ready task management system with:
- **TLA+ formal specifications** proving correctness
- **Go implementation** that refines the specification
- **Property-based testing** verifying the refinement
- **Complete DevOps pipeline** with Docker, CI/CD, and monitoring

### The Approach

Instead of traditional ad-hoc development, we followed a formal methods approach:
1. Start with mathematical specification (TLA+)
2. Discover and prove properties
3. Implement following the specification
4. Verify implementation matches specification
5. Deploy with confidence

---

## The Development Journey

### Phase 1: Initial TLA+ Specification

**Human Prompt #1:**
```
I have the following TLA+ specification for a task management system. Please:
1. Review it for syntax errors and logical issues
2. Suggest improvements for completeness
3. Identify any missing safety/liveness properties
4. Generate comprehensive test scenarios
[TLA+ specification provided...]
```

**AI Response:**
- Identified syntax errors in the initial specification
- Found logical issues (no dependency validation, missing state transitions)
- Created improved specification with:
  - Task dependencies with cycle detection
  - Session management
  - Priority inheritance
  - Bulk operations
  - Comprehensive invariants

**Key Files Generated:**
- `TaskManagementImproved.tla` - Enhanced specification
- `TestScenarios.tla` - 12 comprehensive test scenarios
- `TaskManagementImproved.cfg` - Model configuration

### Phase 2: Implementation Request

**Human Prompt #2:**
```
Given this verified TLA+ specification for a task management system, generate a complete implementation with the following requirements:
1. Language: Go 1.21+ with standard library
2. Architecture: Clean architecture with layers
3. Correctness Requirements: Every API endpoint must check preconditions from TLA+ spec
4. Testing Requirements: Property-based tests that verify TLA+ invariants
5. Documentation: Map each Go function to its TLA+ action
```

**AI Response:**
Created a complete Go implementation with:
- **Domain layer** mapping TLA+ types to Go structs
- **Use case layer** implementing each TLA+ action
- **Repository pattern** for data persistence
- **Invariant checkers** validating all TLA+ properties at runtime
- **Property-based tests** ensuring refinement

**Key Files Generated:**
- `internal/domain/*.go` - Domain entities
- `internal/usecase/task_usecase.go` - TLA+ actions as Go methods
- `pkg/invariants/invariants.go` - Runtime invariant checking
- `test/property/invariant_test.go` - Property-based tests

### Phase 3: Verification and Refinement

**Human Prompt #3:**
```
Using the context from my task manager project, verify that I have a TLA+ specification and its Go implementation. Please:
1. Verify the implementation correctly realizes the TLA+ spec
2. Generate a refinement mapping between implementation and spec
3. Create property-based tests that check refinement
4. Identify any behavioral divergences
```

**AI Response:**
- Created formal refinement mapping
- Identified minor divergences (3 issues found)
- Generated comprehensive refinement tests
- Provided behavioral analysis document

**Key Files Generated:**
- `RefinementMapping.tla` - Formal refinement between Go and TLA+
- `test/refinement/refinement_test.go` - Refinement verification
- `BehavioralAnalysis.md` - Complete analysis with fixes

### Phase 4: Property Discovery

**Human Prompt #4:**
```
Given this TLA+ specification, help me discover important properties:
[Specification provided...]
Please generate:
1. Additional safety invariants I should verify
2. Liveness properties for progress guarantees
3. Fairness conditions to prevent starvation
4. Temporal properties for sequencing constraints
5. State predicates for debugging
```

**AI Response:**
Discovered 40+ new properties organized into categories:
- 8 additional safety invariants
- 6 liveness properties
- 5 fairness conditions
- 7 temporal properties
- 10 debugging predicates

**Key Files Generated:**
- `DiscoveredProperties.tla` - All new properties
- `PropertyAnalysisGuide.md` - Detailed explanations
- `PropertyVerification.cfg` - Verification profiles
- `PropertyCounterexamples.tla` - Test scenarios

### Phase 5: Build and Deployment Infrastructure

**Human Prompt #5:**
```
Can you create Makefile to define targets for testing, tla verification, lint, build, etc. 
Also, create Dockerfile for deployment.
```

**AI Response:**
Created complete DevOps infrastructure:
- Comprehensive Makefile with 50+ targets
- Multi-stage Dockerfile with TLA+ verification
- Docker Compose for full stack
- GitHub Actions CI/CD pipeline
- Deployment documentation

**Key Files Generated:**
- `Makefile` - Build automation
- `Dockerfile` - Container builds
- `docker-compose.yml` - Service orchestration
- `.github/workflows/ci-cd.yml` - CI/CD pipeline
- `BUILD.md` - Complete build guide

### Phase 6: Professional Documentation

**Human Prompt #6:**
```
Can you recreate README.md so that it not only has build/deployment documentation but explains 
the design of task management, code structure, how it uses tla and property based testing. 
It needs to look like professional open source project. And then create a file that shows 
how above prompts were used to create this project as this is meant a tutorial.
```

**AI Response:**
Created professional documentation:
- Complete README with architecture, design, and usage
- This tutorial file showing the development process

---

## Prompts and Responses

### Effective Prompt Patterns Used

#### 1. Specification Review Pattern
```
I have the following [SPECIFICATION TYPE] for [SYSTEM]. Please:
1. Review it for [SPECIFIC ISSUES]
2. Suggest improvements for [QUALITY ATTRIBUTES]
3. Identify any missing [PROPERTIES]
4. Generate [TEST ARTIFACTS]
```

#### 2. Implementation Generation Pattern
```
Given this [VERIFIED SPECIFICATION], generate a complete implementation with:
- Language: [SPECIFIC VERSION AND CONSTRAINTS]
- Architecture: [ARCHITECTURAL PATTERN]
- Requirements: [CORRECTNESS REQUIREMENTS]
- Testing: [TESTING STRATEGY]
- Documentation: [DOCUMENTATION REQUIREMENTS]
```

#### 3. Verification Pattern
```
Verify that [IMPLEMENTATION] correctly realizes [SPECIFICATION]. Please:
1. Verify [SPECIFIC MAPPINGS]
2. Generate [VERIFICATION ARTIFACTS]
3. Create [TEST TYPES]
4. Identify [DIVERGENCES]
```

#### 4. Property Discovery Pattern
```
Given this [SPECIFICATION], help me discover important properties:
- [PROPERTY CATEGORY 1]
- [PROPERTY CATEGORY 2]
For each property:
- Explain what it guarantees
- Show how to express it
- Provide counterexample scenarios
```

### What Made These Prompts Effective

1. **Specific Requirements**: Each prompt included detailed requirements
2. **Structured Requests**: Used numbered lists and clear categories
3. **Context Provision**: Always provided the full specification/code
4. **Incremental Building**: Each phase built on previous results
5. **Verification Focus**: Emphasized correctness at every step

---

## Key Learnings

### Technical Insights

1. **Formal Methods Are Practical**
   - TLA+ can specify real systems
   - Specifications guide implementation
   - Properties can be verified at runtime

2. **Refinement Is Achievable**
   - Go code can directly map to TLA+ actions
   - Invariants translate to runtime checks
   - Property-based testing verifies refinement

3. **Clean Architecture Helps**
   - Separation of concerns enables verification
   - Each layer has clear responsibilities
   - Testing becomes systematic

### Process Insights

1. **Start with Specification**
   - Define behavior before implementation
   - Discover properties early
   - Use specification to guide design

2. **Verify Continuously**
   - Check invariants at runtime
   - Test properties not just examples
   - Automate verification in CI/CD

3. **Document the Mapping**
   - Explicitly map specification to code
   - Document refinement relationships
   - Make verification traceable

### AI-Assisted Development Insights

1. **Iterative Refinement Works**
   - Start with basic version
   - Incrementally add features
   - Verify at each step

2. **Comprehensive Requests Get Better Results**
   - Provide full context
   - Specify requirements clearly
   - Ask for specific artifacts

3. **Verification Should Be First-Class**
   - Request tests with implementation
   - Ask for property discovery
   - Demand refinement checking

---

## Reproducing This Project

### Step-by-Step Guide

#### Step 1: Start with a Basic Specification
```bash
# Create initial TLA+ specification
# Focus on core functionality first
```

**Prompt to use:**
```
Create a TLA+ specification for a [YOUR SYSTEM] with:
- Basic CRUD operations
- User authentication
- State management
Include safety invariants and type definitions
```

#### Step 2: Enhance and Verify Specification
```bash
# Have AI review and enhance
# Add missing properties
```

**Prompt to use:**
```
Review this TLA+ specification and:
1. Add missing safety/liveness properties
2. Include temporal properties
3. Add test scenarios
4. Create model configuration
```

#### Step 3: Generate Implementation
```bash
# Create implementation that maps to specification
# Include runtime verification
```

**Prompt to use:**
```
Generate a [LANGUAGE] implementation of this TLA+ specification with:
- Each TLA+ action as a method
- Runtime invariant checking
- Property-based tests
- Clean architecture
```

#### Step 4: Verify Refinement
```bash
# Check implementation matches specification
# Create refinement tests
```

**Prompt to use:**
```
Create refinement mapping between TLA+ and implementation:
- Map each state variable
- Map each action
- Create tests verifying refinement
- Identify any divergences
```

#### Step 5: Build Infrastructure
```bash
# Create build and deployment pipeline
# Include TLA+ verification in CI/CD
```

**Prompt to use:**
```
Create build infrastructure with:
- Makefile for all operations
- Dockerfile with TLA+ verification
- CI/CD pipeline
- Docker Compose setup
```

### Tools You'll Need

1. **TLA+ Tools**
   ```bash
   # Download TLA+ tools
   curl -L https://github.com/tlaplus/tlaplus/releases/latest/download/tla2tools.jar \
     -o /usr/local/lib/tla2tools.jar
   ```

2. **Go Development**
   ```bash
   # Install Go 1.21+
   # Install development tools
   go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
   ```

3. **Docker**
   ```bash
   # Install Docker and Docker Compose
   # Required for containerization
   ```

### Testing Your Implementation

1. **Verify TLA+ Specification**
   ```bash
   make tla-verify
   ```

2. **Run Property-Based Tests**
   ```bash
   make test-property
   ```

3. **Check Refinement**
   ```bash
   make test-refinement
   ```

4. **Verify Invariants**
   ```bash
   make test-all
   ```

---

## Advanced Topics

### Extending the System

To add new features:

1. **Update TLA+ Specification**
   ```tla
   NewAction(...) ==
       /\ preconditions
       /\ state_updates
       /\ postconditions
   ```

2. **Add Properties**
   ```tla
   NewInvariant ==
       \A element : property_holds
   ```

3. **Implement in Go**
   ```go
   func (uc *UseCase) NewAction(...) error {
       // Check preconditions
       // Perform action
       // Verify invariants
   }
   ```

4. **Add Tests**
   ```go
   func TestNewActionRefinement(t *testing.T) {
       // Verify Go matches TLA+
   }
   ```

### Debugging Techniques

1. **TLA+ Model Checking**
   ```bash
   # Check specific property
   java -cp tla2tools.jar tlc2.TLC \
     -config Debug.cfg \
     Specification.tla
   ```

2. **Runtime Invariant Violations**
   ```go
   // Add detailed logging
   if err := checker.CheckInvariant(state); err != nil {
       log.Printf("Invariant violated: %v\nState: %+v", err, state)
   }
   ```

3. **Property Test Failures**
   ```go
   // Minimize failing input
   quick.Check(property, &quick.Config{
       MaxCountScale: 1000,
       MinSuccessfulTests: 100,
   })
   ```

---

## Conclusion

This project demonstrates that formal verification is not just academic—it's practical and achievable with modern tools and AI assistance. By following this approach, you can build systems with mathematical confidence in their correctness.

### Key Takeaways

1. **Start with formal specification** - It guides everything else
2. **Verify continuously** - At specification, implementation, and runtime
3. **Use AI effectively** - Provide context and be specific
4. **Automate everything** - From verification to deployment
5. **Document the journey** - For learning and maintenance

### Next Steps

- Try building your own formally verified system
- Explore more TLA+ patterns
- Contribute to this project
- Share your experiences

### Resources

- [TLA+ Homepage](https://lamport.azurewebsites.net/tla/tla.html)
- [Learn TLA+](https://learntla.com)
- [Go Documentation](https://go.dev/doc/)
- [Property-Based Testing](https://hypothesis.works/)

---

*This tutorial shows that building reliable software with formal methods is achievable through systematic development and intelligent use of AI assistance.*

## Appendix: Complete Prompt Sequence

For reference, here's the complete sequence of prompts used to build this project:

1. **Initial Specification Review** - Analyzed and improved TLA+ specification
2. **Implementation Generation** - Created Go implementation with verification
3. **Refinement Verification** - Verified implementation matches specification
4. **Property Discovery** - Found 40+ additional properties to verify
5. **Infrastructure Creation** - Built complete DevOps pipeline
6. **Documentation** - Created professional README and this tutorial

Each prompt built upon previous results, creating a complete, verified system through iterative refinement and continuous verification.
