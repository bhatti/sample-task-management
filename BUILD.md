# Build and Deployment Guide

## 📋 Table of Contents
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Development Setup](#development-setup)
- [Building](#building)
- [Testing](#testing)
- [TLA+ Verification](#tla-verification)
- [Docker Deployment](#docker-deployment)
- [CI/CD Pipeline](#cicd-pipeline)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools
- **Go** 1.21+ ([Download](https://go.dev/dl/))
- **Java** 11+ (for TLA+ verification)
- **Docker** 20.10+ ([Download](https://docs.docker.com/get-docker/))
- **Make** (usually pre-installed on Unix systems)

### Optional Tools
- **Docker Compose** 2.0+ (for orchestration)
- **kubectl** (for Kubernetes deployment)
- **TLA+ Toolbox** (for GUI-based TLA+ work)

### Install Dependencies
```bash
# Install all development dependencies
make setup

# Or manually install specific tools
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
curl -L https://github.com/tlaplus/tlaplus/releases/latest/download/tla2tools.jar \
  -o /usr/local/lib/tla2tools.jar
```

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/bhatti/sample-task-management.git
cd task-management

# 2. Run everything (verify, test, build, deploy)
make all

# 3. Start the application
make run

# Or use Docker
docker-compose up
```

## Development Setup

### Local Development
```bash
# Install Go dependencies
make deps

# Run with hot reload (requires Air)
make serve

# Or run directly
cd task-management && go run cmd/server/main.go
```

### Development with Docker
```bash
# Start development environment with hot reload
docker-compose --profile development up

# Access the application
curl http://localhost:8080/health

# Access debugger
# Connect your IDE to localhost:2345
```

## Building

### Build for Current Platform
```bash
# Simple build
make build

# Output: build/bin/task-server
```

### Cross-Platform Build
```bash
# Build for all platforms
make build-all

# Outputs:
# build/bin/task-server-linux-amd64
# build/bin/task-server-darwin-amd64
# build/bin/task-server-windows-amd64.exe
```

### Build with Version Info
```bash
# Build with version information
VERSION=v1.2.3 make build

# Or use git tags
git tag v1.2.3
make build
```

## Testing

### Run All Tests
```bash
# Run complete test suite
make test-all
```

### Specific Test Types
```bash
# Unit tests only
make test

# Property-based tests (TLA+ refinement)
make test-property

# Refinement tests
make test-refinement

# Concurrent access tests
make test-concurrent

# Integration tests
make test-integration

# Benchmarks
make test-benchmark
```

### Test Coverage
```bash
# Generate coverage report
make test-coverage

# View report in browser
open build/coverage/coverage.html
```

### Code Quality Checks
```bash
# Format code
make fmt

# Run linters
make lint

# Security scan
make security

# Run all checks
make check
```

## TLA+ Verification

### Verify Specifications
```bash
# Quick verification (core properties)
make tla-verify

# Check syntax only
make tla-check

# Verify safety properties
make tla-verify-safety

# Verify liveness properties
make tla-verify-liveness

# Run simulation
make tla-simulate

# Generate coverage
make tla-coverage
```

### Custom TLA+ Verification
```bash
# Run with custom configuration
java -cp /usr/local/lib/tla2tools.jar tlc2.TLC \
  -workers 8 \
  -config PropertyVerification.cfg \
  TaskManagementImproved.tla
```

## Docker Deployment

### Build Docker Image
```bash
# Build image
make docker-build

# Build with custom tag
DOCKER_TAG=v1.2.3 make docker-build

# Build debug image
docker build --target debug -t task-management:debug .

# Build development image
docker build --target development -t task-management:dev .
```

### Run with Docker Compose

#### Mode
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f task-api

# Stop services
docker-compose down
```

#### Development Mode
```bash
# Start with development profile
docker-compose --profile development up

# With monitoring
docker-compose --profile monitoring up

# With TLA+ verification
docker-compose --profile verification up
```

#### Full Stack with All Services
```bash
# Start everything
docker-compose \
  --profile development \
  --profile monitoring \
  --profile verification \
  --profile backup \
  up
```

### Docker Registry Operations
```bash
# Push to registry
make docker-push

# Custom registry
DOCKER_REGISTRY=myregistry.com make docker-push
```

## CI/CD Pipeline

### GitHub Actions Workflow

The CI/CD pipeline automatically runs on:
- Push to `main` or `develop` branches
- Pull requests to `main`
- Tag pushes (v*)
- Weekly scheduled verification

### Pipeline Stages

1. **TLA+ Verification** - Verifies formal specifications
2. **Go Testing** - Runs all test suites
3. **Code Quality** - Linting, formatting, security
4. **Build** - Multi-platform binary compilation
5. **Docker Build** - Container image creation
6. **Integration Tests** - Full system tests
7. **Release** - GitHub release creation
8. **Deploy** - deployment

### Manual Trigger
```bash
# Trigger workflow manually
gh workflow run ci-cd.yml

# With specific branch
gh workflow run ci-cd.yml --ref develop
```

## Deployment

### Kubernetes Deployment
```bash
# Create namespace
kubectl create namespace task-management

# Apply configurations
kubectl apply -f k8s/

# Verify deployment
kubectl get pods -n task-management

# Check service
kubectl get svc -n task-management
```

### Docker Swarm Deployment
```bash
# Initialize swarm
docker swarm init

# Deploy stack
docker stack deploy -c docker-compose.yml task-stack

# Check services
docker service ls

# Scale service
docker service scale task-stack_task-api=3
```

### Environment Variables

```bash
# Required
export DB_USER=taskuser
export DB_PASSWORD=secure_password
export GRAFANA_PASSWORD=admin_password

# Optional
export LOG_LEVEL=info
export MAX_TASKS=1000
export SESSION_TIMEOUT=3600
export TLA_WORKERS=8
export TLA_MEMORY=8G
```

### Health Checks
```bash
# Check application health
curl http://localhost:8080/health

# Check metrics
curl http://localhost:8080/metrics

# Check readiness
curl http://localhost:8080/ready
```

## Monitoring

### Prometheus Metrics
```bash
# Start monitoring stack
docker-compose --profile monitoring up

# Access Prometheus
open http://localhost:9090

# Access Grafana
open http://localhost:3000
# Default login: admin/admin
```

### Jaeger Tracing
```bash
# Start tracing
docker-compose --profile tracing up

# Access Jaeger UI
open http://localhost:16686
```

## Backup and Recovery

### Backup
```bash
# Start backup service
docker-compose --profile backup up

# Manual backup
make backup

# Backup to S3
aws s3 cp backups/ s3://my-bucket/backups/ --recursive
```

### Recovery
```bash
# Restore from backup
docker exec -i task-postgres psql -U taskuser taskmanagement < backup.sql

# Restore Redis
docker exec -i task-redis redis-cli --rdb /data/dump.rdb
```

## Troubleshooting

### Common Issues

#### Port Already in Use
```bash
# Find process using port
lsof -i :8080

# Kill process
kill -9 <PID>

# Or use different port
SERVER_PORT=8081 make run
```

#### TLA+ Out of Memory
```bash
# Increase memory
java -Xmx8G -cp /usr/local/lib/tla2tools.jar tlc2.TLC ...

# Or in Makefile
TLA_MEMORY=8G make tla-verify
```

#### Docker Build Fails
```bash
# Clean Docker cache
docker system prune -a

# Rebuild without cache
docker build --no-cache -t task-management .
```

#### Tests Failing
```bash
# Run tests verbosely
make test-verbose

# Run specific test
cd task-management
go test -v -run TestSpecificFunction ./...
```

### Debug Mode
```bash
# Run with debug logging
LOG_LEVEL=debug make run

# Enable Go race detector
go run -race cmd/server/main.go

# Enable CPU profiling
make profile
go tool pprof build/profile/cpu.prof
```

### Logs and Diagnostics
```bash
# View Docker logs
docker-compose logs -f --tail=100 task-api

# View container details
docker inspect task-api

# Execute commands in container
docker exec -it task-api sh

# Check resource usage
docker stats task-api
```

## Performance Tuning

### Go Application
```bash
# Run benchmarks
make test-benchmark

# Generate profiles
make profile

# Analyze profiles
go tool pprof -http=:8081 build/profile/cpu.prof
```

### TLA+ Verification
```bash
# Optimize worker count
TLA_WORKERS=$(nproc) make tla-verify

# Use simulation for large models
make tla-simulate

# Reduce state space
# Edit .cfg file to add constraints
```

### Docker Optimization
```bash
# Multi-stage build (already implemented)
# Use alpine images (already implemented)
# Enable BuildKit
export DOCKER_BUILDKIT=1
docker build .
```

## Security

### Security Scanning
```bash
# Run security checks
make security

# Scan Docker image
docker scan task-management:latest

# Check for vulnerabilities
cd task-management && govulncheck ./...
```

### Secret Management
```bash
# Never commit secrets
# Use environment variables
export DB_PASSWORD=$(vault read -field=password secret/db)

# Or use secrets management
docker secret create db_password password.txt
```

## Release Process

### Creating a Release
```bash
# 1. Update version
echo "v1.2.3" > VERSION

# 2. Run tests
make test-all

# 3. Verify TLA+ specs
make tla-verify-all

# 4. Create tag
git tag -a v1.2.3 -m "Release v1.2.3"

# 5. Push tag (triggers CI/CD)
git push origin v1.2.3

# 6. Build release artifacts
make release
```

### Release Artifacts
```
build/release/
├── task-management-v1.2.3-linux-amd64.tar.gz
├── task-management-v1.2.3-darwin-amd64.tar.gz
└── task-management-v1.2.3-windows-amd64.zip
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## Support

- GitHub Issues: [Report bugs](https://github.com/your-org/task-management/issues)
- Documentation: [Wiki](https://github.com/your-org/task-management/wiki)
- Slack: [#task-management](https://your-org.slack.com/channels/task-management)
