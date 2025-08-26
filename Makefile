# Task Management System - Makefile
# Comprehensive build, test, and verification targets

# Variables
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

# Project paths
PROJECT_ROOT := $(shell pwd)
GO_MODULE := github.com/task-management
GO_SRC := task-management
TLA_SPECS := $(wildcard *.tla)
TLA_CONFIGS := $(wildcard *.cfg)

# Go variables
GO := go
GOFLAGS := -v
GOBUILD := $(GO) build $(GOFLAGS)
GOTEST := $(GO) test $(GOFLAGS)
GOVET := $(GO) vet
GOFMT := gofmt
GOLINT := golangci-lint
GOMOD := $(GO) mod
GOCOV := $(GO) tool cover

# TLA+ variables
TLC := java -cp /usr/local/lib/tla2tools.jar tlc2.TLC
TLAPM := tlapm
SANY := java -cp /usr/local/lib/tla2tools.jar tla2sany.SANY
TLA_WORKERS := 4
TLA_MEMORY := 4G

# Docker variables
DOCKER := docker
DOCKER_IMAGE := task-management
DOCKER_TAG := latest
DOCKER_REGISTRY := localhost:5000

# Build variables
BUILD_DIR := build
BIN_DIR := $(BUILD_DIR)/bin
COV_DIR := $(BUILD_DIR)/coverage
TLA_OUT_DIR := $(BUILD_DIR)/tla

# Version and build info
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_TIME := $(shell date -u '+%Y-%m-%d_%H:%M:%S')
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
LDFLAGS := -ldflags "-X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME) -X main.GitCommit=$(GIT_COMMIT)"

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

# ==============================================================================
# Help Target
# ==============================================================================

.PHONY: help
help: ## Show this help message
	@echo -e "$(BLUE)Task Management System - Build Targets$(NC)"
	@echo -e "$(BLUE)=======================================$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo -e "$(YELLOW)Examples:$(NC)"
	@echo "  make build          # Build the Go application"
	@echo "  make test           # Run all tests"
	@echo "  make tla-verify     # Verify TLA+ specifications"
	@echo "  make docker-build   # Build Docker image"
	@echo "  make all            # Run everything"

# ==============================================================================
# Development Setup
# ==============================================================================

.PHONY: setup
setup: ## Install development dependencies
	@echo -e "$(BLUE)Setting up development environment...$(NC)"
	@which go > /dev/null || (echo "Please install Go" && exit 1)
	@which java > /dev/null || (echo "Please install Java for TLA+" && exit 1)
	@which docker > /dev/null || (echo "Please install Docker" && exit 1)
	@echo "Installing Go tools..."
	@go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@go install golang.org/x/tools/cmd/goimports@latest
	@go install github.com/securego/gosec/v2/cmd/gosec@latest
	@echo "Downloading TLA+ tools..."
	@mkdir -p /usr/local/lib
	@[ -f /usr/local/lib/tla2tools.jar ] || \
		curl -L https://github.com/tlaplus/tlaplus/releases/latest/download/tla2tools.jar \
		-o /usr/local/lib/tla2tools.jar
	@echo -e "$(GREEN)Setup complete!$(NC)"

.PHONY: deps
deps: ## Download and verify Go dependencies
	@echo -e "$(BLUE)Downloading Go dependencies...$(NC)"
	@cd $(GO_SRC) && $(GOMOD) download
	@cd $(GO_SRC) && $(GOMOD) verify
	@echo -e "$(GREEN)Dependencies ready!$(NC)"

# ==============================================================================
# Go Build Targets
# ==============================================================================

.PHONY: build
build: deps ## Build the Go application
	@echo -e "$(BLUE)Building application...$(NC)"
	@mkdir -p $(BIN_DIR)
	@cd $(GO_SRC) && $(GOBUILD) $(LDFLAGS) -o ../$(BIN_DIR)/task-server ./cmd/server
	@echo -e "$(GREEN)Build complete: $(BIN_DIR)/task-server$(NC)"

.PHONY: build-all
build-all: build ## Build for multiple platforms
	@echo -e "$(BLUE)Building for multiple platforms...$(NC)"
	@cd $(GO_SRC) && GOOS=linux GOARCH=amd64 $(GOBUILD) $(LDFLAGS) \
		-o ../$(BIN_DIR)/task-server-linux-amd64 ./cmd/server
	@cd $(GO_SRC) && GOOS=darwin GOARCH=amd64 $(GOBUILD) $(LDFLAGS) \
		-o ../$(BIN_DIR)/task-server-darwin-amd64 ./cmd/server
	@cd $(GO_SRC) && GOOS=windows GOARCH=amd64 $(GOBUILD) $(LDFLAGS) \
		-o ../$(BIN_DIR)/task-server-windows-amd64.exe ./cmd/server
	@echo -e "$(GREEN)Multi-platform build complete!$(NC)"

.PHONY: run
run: build ## Run the application locally
	@echo -e "$(BLUE)Starting task management server...$(NC)"
	@$(BIN_DIR)/task-server

# ==============================================================================
# Go Testing Targets
# ==============================================================================

.PHONY: test
test: ## Run all Go tests
	@echo -e "$(BLUE)Running tests...$(NC)"
	@cd $(GO_SRC) && $(GOTEST) -race -timeout 30s ./...
	@echo -e "$(GREEN)All tests passed!$(NC)"

.PHONY: test-verbose
test-verbose: ## Run tests with verbose output
	@cd $(GO_SRC) && $(GOTEST) -race -v -timeout 30s ./...

.PHONY: test-short
test-short: ## Run only short tests
	@cd $(GO_SRC) && $(GOTEST) -short -timeout 10s ./...

.PHONY: test-coverage
test-coverage: ## Run tests with coverage report
	@echo -e "$(BLUE)Running tests with coverage...$(NC)"
	@mkdir -p $(COV_DIR)
	@cd $(GO_SRC) && $(GOTEST) -race -coverprofile=../$(COV_DIR)/coverage.out \
		-covermode=atomic ./...
	@cd $(GO_SRC) && $(GOCOV) -html=../$(COV_DIR)/coverage.out \
		-o ../$(COV_DIR)/coverage.html
	@echo -e "$(GREEN)Coverage report: $(COV_DIR)/coverage.html$(NC)"
	@cd $(GO_SRC) && $(GOCOV) -func=../$(COV_DIR)/coverage.out

.PHONY: test-integration
test-integration: ## Run integration tests
	@echo -e "$(BLUE)Running integration tests...$(NC)"
	@cd $(GO_SRC) && $(GOTEST) -tags=integration -timeout 60s ./test/integration/...

.PHONY: test-property
test-property: ## Run property-based tests
	@echo -e "$(BLUE)Running property-based tests...$(NC)"
	@cd $(GO_SRC) && $(GOTEST) -timeout 120s ./test/property/...

.PHONY: test-refinement
test-refinement: ## Run refinement tests
	@echo -e "$(BLUE)Running refinement tests...$(NC)"
	@cd $(GO_SRC) && $(GOTEST) -timeout 60s ./test/refinement/...

.PHONY: test-concurrent
test-concurrent: ## Run concurrent access tests
	@echo -e "$(BLUE)Running concurrent access tests...$(NC)"
	@cd $(GO_SRC) && $(GOTEST) -race -timeout 60s ./test/concurrent/...

.PHONY: test-benchmark
test-benchmark: ## Run benchmark tests
	@echo -e "$(BLUE)Running benchmarks...$(NC)"
	@cd $(GO_SRC) && $(GOTEST) -bench=. -benchmem -timeout 300s ./...

.PHONY: test-all
test-all: test test-property test-refinement test-concurrent ## Run all test suites

# ==============================================================================
# Go Code Quality Targets
# ==============================================================================

.PHONY: fmt
fmt: ## Format Go code
	@echo -e "$(BLUE)Formatting code...$(NC)"
	@cd $(GO_SRC) && $(GOFMT) -w -s .
	@cd $(GO_SRC) && goimports -w .
	@echo -e "$(GREEN)Code formatted!$(NC)"

.PHONY: lint
lint: ## Run Go linters
	@echo -e "$(BLUE)Running linters...$(NC)"
	@cd $(GO_SRC) && $(GOLINT) run --timeout 5m ./...
	@echo -e "$(GREEN)Linting passed!$(NC)"

.PHONY: vet
vet: ## Run Go vet
	@echo -e "$(BLUE)Running go vet...$(NC)"
	@cd $(GO_SRC) && $(GOVET) ./...
	@echo -e "$(GREEN)Vet passed!$(NC)"

.PHONY: security
security: ## Run security checks
	@echo -e "$(BLUE)Running security scan...$(NC)"
	@cd $(GO_SRC) && gosec -fmt json -out ../$(BUILD_DIR)/security.json ./...
	@cd $(GO_SRC) && gosec ./...
	@echo -e "$(GREEN)Security scan complete!$(NC)"

.PHONY: check
check: fmt lint vet security ## Run all code quality checks

# ==============================================================================
# TLA+ Verification Targets
# ==============================================================================

.PHONY: tla-check
tla-check: ## Check TLA+ syntax
	@echo -e "$(BLUE)Checking TLA+ syntax...$(NC)"
	@for spec in $(TLA_SPECS); do \
		echo "Checking $$spec..."; \
		$(SANY) $$spec || exit 1; \
	done
	@echo -e "$(GREEN)TLA+ syntax check passed!$(NC)"

.PHONY: tla-verify
tla-verify: ## Verify core TLA+ properties (fast)
	@echo -e "$(BLUE)Verifying TLA+ specifications...$(NC)"
	@mkdir -p $(TLA_OUT_DIR)
	@$(TLC) -workers $(TLA_WORKERS) -gzip \
		-config TaskManagementImproved.cfg \
		-metadir $(TLA_OUT_DIR) \
		TaskManagementImproved.tla | tee $(TLA_OUT_DIR)/verification.log
	@echo -e "$(GREEN)TLA+ verification complete!$(NC)"

.PHONY: tla-verify-safety
tla-verify-safety: ## Verify safety properties only
	@echo -e "$(BLUE)Verifying safety properties...$(NC)"
	@$(TLC) -workers $(TLA_WORKERS) -gzip \
		-config PropertyVerification.cfg \
		-deadlock \
		TaskManagementImproved.tla

.PHONY: tla-verify-liveness
tla-verify-liveness: ## Verify liveness properties
	@echo -e "$(BLUE)Verifying liveness properties...$(NC)"
	@$(TLC) -workers $(TLA_WORKERS) -gzip \
		-config PropertyVerification.cfg \
		-lncheck final \
		TaskManagementImproved.tla

.PHONY: tla-verify-all
tla-verify-all: tla-check tla-verify tla-verify-safety ## Run all TLA+ verifications

.PHONY: tla-simulate
tla-simulate: ## Run TLA+ simulation mode
	@echo -e "$(BLUE)Running TLA+ simulation...$(NC)"
	@$(TLC) -workers $(TLA_WORKERS) -simulate \
		-depth 100 -seed 42 \
		-config TaskManagementImproved.cfg \
		TaskManagementImproved.tla

.PHONY: tla-coverage
tla-coverage: ## Generate TLA+ coverage report
	@echo -e "$(BLUE)Generating TLA+ coverage...$(NC)"
	@$(TLC) -workers $(TLA_WORKERS) -coverage 1 \
		-config TaskManagementImproved.cfg \
		TaskManagementImproved.tla

# ==============================================================================
# Docker Targets
# ==============================================================================

.PHONY: docker-build
docker-build: ## Build Docker image
	@echo -e "$(BLUE)Building Docker image...$(NC)"
	@$(DOCKER) build -t $(DOCKER_IMAGE):$(DOCKER_TAG) \
		--build-arg VERSION=$(VERSION) \
		--build-arg BUILD_TIME=$(BUILD_TIME) \
		--build-arg GIT_COMMIT=$(GIT_COMMIT) \
		-f Dockerfile .
	@echo -e "$(GREEN)Docker image built: $(DOCKER_IMAGE):$(DOCKER_TAG)$(NC)"

.PHONY: docker-push
docker-push: docker-build ## Push Docker image to registry
	@echo -e "$(BLUE)Pushing Docker image...$(NC)"
	@$(DOCKER) tag $(DOCKER_IMAGE):$(DOCKER_TAG) \
		$(DOCKER_REGISTRY)/$(DOCKER_IMAGE):$(DOCKER_TAG)
	@$(DOCKER) push $(DOCKER_REGISTRY)/$(DOCKER_IMAGE):$(DOCKER_TAG)
	@echo -e "$(GREEN)Image pushed to registry!$(NC)"

.PHONY: docker-run
docker-run: docker-build ## Run Docker container locally
	@echo -e "$(BLUE)Running Docker container...$(NC)"
	@$(DOCKER) run -d --name task-management \
		-p 8080:8080 \
		-e LOG_LEVEL=info \
		$(DOCKER_IMAGE):$(DOCKER_TAG)

.PHONY: docker-stop
docker-stop: ## Stop and remove Docker container
	@$(DOCKER) stop task-management || true
	@$(DOCKER) rm task-management || true

.PHONY: docker-logs
docker-logs: ## Show Docker container logs
	@$(DOCKER) logs -f task-management

.PHONY: docker-compose-up
docker-compose-up: ## Start services with docker-compose
	@echo -e "$(BLUE)Starting services with docker-compose...$(NC)"
	@docker-compose up -d
	@echo -e "$(GREEN)Services started!$(NC)"

.PHONY: docker-compose-down
docker-compose-down: ## Stop services with docker-compose
	@docker-compose down

# ==============================================================================
# CI/CD Targets
# ==============================================================================

.PHONY: ci
ci: deps check test tla-verify build ## Run CI pipeline
	@echo -e "$(GREEN)CI pipeline complete!$(NC)"

.PHONY: cd
cd: ci docker-build docker-push ## Run CD pipeline
	@echo -e "$(GREEN)CD pipeline complete!$(NC)"

# ==============================================================================
# Cleanup Targets
# ==============================================================================

.PHONY: clean
clean: ## Clean build artifacts
	@echo -e "$(BLUE)Cleaning build artifacts...$(NC)"
	@rm -rf $(BUILD_DIR)
	@cd $(GO_SRC) && $(GO) clean -cache -testcache
	@echo -e "$(GREEN)Clean complete!$(NC)"

.PHONY: clean-docker
clean-docker: docker-stop ## Clean Docker images
	@echo -e "$(BLUE)Cleaning Docker images...$(NC)"
	@$(DOCKER) rmi $(DOCKER_IMAGE):$(DOCKER_TAG) || true
	@echo -e "$(GREEN)Docker cleanup complete!$(NC)"

.PHONY: clean-all
clean-all: clean clean-docker ## Clean everything
	@echo -e "$(GREEN)Full cleanup complete!$(NC)"

# ==============================================================================
# Utility Targets
# ==============================================================================

.PHONY: version
version: ## Show version information
	@echo "Version: $(VERSION)"
	@echo "Build Time: $(BUILD_TIME)"
	@echo "Git Commit: $(GIT_COMMIT)"

.PHONY: info
info: ## Show project information
	@echo -e "$(BLUE)Project Information$(NC)"
	@echo "==================="
	@echo "Module: $(GO_MODULE)"
	@echo "Version: $(VERSION)"
	@echo "Go Version: $(shell go version)"
	@echo "Docker Version: $(shell docker --version)"
	@echo "Java Version: $(shell java -version 2>&1 | head -n 1)"
	@echo "TLA+ Specs: $(TLA_SPECS)"

.PHONY: watch
watch: ## Watch for changes and rebuild
	@echo -e "$(BLUE)Watching for changes...$(NC)"
	@while true; do \
		$(MAKE) build; \
		inotifywait -qre close_write $(GO_SRC); \
	done

.PHONY: serve
serve: build ## Run with hot reload
	@echo -e "$(BLUE)Starting with hot reload...$(NC)"
	@air -c .air.toml

# ==============================================================================
# Advanced Targets
# ==============================================================================

.PHONY: profile
profile: ## Run CPU profiling
	@echo -e "$(BLUE)Running CPU profiling...$(NC)"
	@mkdir -p $(BUILD_DIR)/profile
	@cd $(GO_SRC) && $(GOTEST) -cpuprofile=../$(BUILD_DIR)/profile/cpu.prof \
		-memprofile=../$(BUILD_DIR)/profile/mem.prof \
		-bench=. ./...
	@echo -e "$(GREEN)Profiling complete: $(BUILD_DIR)/profile/$(NC)"

.PHONY: trace
trace: ## Generate execution trace
	@echo -e "$(BLUE)Generating execution trace...$(NC)"
	@cd $(GO_SRC) && $(GOTEST) -trace=../$(BUILD_DIR)/trace.out ./...
	@echo -e "$(GREEN)Trace generated: $(BUILD_DIR)/trace.out$(NC)"

.PHONY: release
release: clean test tla-verify build-all docker-build ## Create release artifacts
	@echo -e "$(BLUE)Creating release $(VERSION)...$(NC)"
	@mkdir -p $(BUILD_DIR)/release
	@tar -czf $(BUILD_DIR)/release/task-management-$(VERSION)-linux-amd64.tar.gz \
		-C $(BIN_DIR) task-server-linux-amd64
	@tar -czf $(BUILD_DIR)/release/task-management-$(VERSION)-darwin-amd64.tar.gz \
		-C $(BIN_DIR) task-server-darwin-amd64
	@zip -j $(BUILD_DIR)/release/task-management-$(VERSION)-windows-amd64.zip \
		$(BIN_DIR)/task-server-windows-amd64.exe
	@echo -e "$(GREEN)Release artifacts created in $(BUILD_DIR)/release/$(NC)"

# ==============================================================================
# Composite Targets
# ==============================================================================

.PHONY: all
all: clean deps check test tla-verify build docker-build ## Run everything

.PHONY: quick
quick: fmt build test ## Quick build and test

.PHONY: verify
verify: check test tla-verify ## Full verification

# Prevent make from trying to remake the Makefile
Makefile: ;

# Keep intermediate files
.SECONDARY:

# Special targets
.PHONY: FORCE
FORCE: