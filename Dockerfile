# Multi-stage Dockerfile for Task Management System
# Stage 1: TLA+ verification
# Stage 2: Go build
# Stage 3: Runtime

# ==============================================================================
# Stage 1: TLA+ Verification
# ==============================================================================
FROM openjdk:11-slim AS tla-verify

# Install TLA+ tools
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Download TLA+ tools
RUN mkdir -p /opt/tla && \
    curl -L https://github.com/tlaplus/tlaplus/releases/latest/download/tla2tools.jar \
    -o /opt/tla/tla2tools.jar

# Copy TLA+ specifications
WORKDIR /tla
COPY *.tla *.cfg ./

# Verify TLA+ specifications
RUN java -cp /opt/tla/tla2tools.jar tlc2.TLC \
    -workers 4 \
    -config TaskManagementImproved.cfg \
    -deadlock \
    TaskManagementImproved.tla || \
    (echo "TLA+ verification failed" && exit 1)

# ==============================================================================
# Stage 2: Go Builder
# ==============================================================================
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    gcc \
    musl-dev \
    make \
    ca-certificates \
    tzdata

# Create non-root user for runtime
RUN adduser -D -g '' appuser

# Set working directory
WORKDIR /build

# Copy go mod files first for better caching
COPY task-management/go.mod task-management/go.sum ./task-management/
WORKDIR /build/task-management
RUN go mod download
RUN go mod verify

# Copy source code
COPY task-management/ ./

# Build arguments for version info
ARG VERSION=dev
ARG BUILD_TIME
ARG GIT_COMMIT

# Build the application
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s \
    -X main.Version=${VERSION} \
    -X main.BuildTime=${BUILD_TIME} \
    -X main.GitCommit=${GIT_COMMIT}" \
    -a -installsuffix cgo \
    -o task-server \
    ./cmd/server

# Run tests
RUN go test -v -race -timeout 30s ./...

# Run security scan
RUN go install github.com/securego/gosec/v2/cmd/gosec@latest && \
    gosec -fmt json -out security-report.json ./... || true

# ==============================================================================
# Stage 3: Runtime Image
# ==============================================================================
FROM scratch AS runtime

# Copy necessary files from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/passwd /etc/passwd

# Copy TLA+ verification result as proof
COPY --from=tla-verify /tla/*.tla /tla/*.cfg /opt/tla-specs/

# Copy the binary
COPY --from=builder /build/task-management/task-server /app/task-server

# Copy security report for audit
COPY --from=builder /build/task-management/security-report.json /app/security-report.json

# Use non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/app/task-server", "--health-check"]

# Labels for metadata
LABEL maintainer="Task Management Team" \
      version="${VERSION}" \
      description="TLA+ verified task management system" \
      tla.verified="true" \
      security.scanned="true"

# Runtime configuration
ENV LOG_LEVEL=info \
    SERVER_PORT=8080 \
    MAX_TASKS=1000 \
    SESSION_TIMEOUT=3600 \
    INVARIANT_CHECKING=true \
    TZ=UTC

# Run the application
ENTRYPOINT ["/app/task-server"]
CMD ["--config", "/app/config.yaml"]

# ==============================================================================
# Alternative: Debug Image (with shell for debugging)
# ==============================================================================
FROM alpine:3.19 AS debug

# Install debugging tools
RUN apk add --no-cache \
    bash \
    curl \
    htop \
    strace \
    tcpdump \
    vim \
    jq

# Copy from builder
COPY --from=builder /build/task-management/task-server /app/task-server
COPY --from=tla-verify /tla/*.tla /tla/*.cfg /opt/tla-specs/

# Create non-root user
RUN adduser -D -g '' appuser
USER appuser

WORKDIR /app

EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Environment variables
ENV LOG_LEVEL=debug \
    SERVER_PORT=8080 \
    DEBUG_MODE=true

ENTRYPOINT ["/app/task-server"]

# ==============================================================================
# Alternative: Development Image (with hot reload)
# ==============================================================================
FROM golang:1.21-alpine AS development

# Install development tools
RUN apk add --no-cache \
    git \
    make \
    bash \
    curl

# Install air for hot reload
RUN go install github.com/cosmtrek/air@latest

# Install development tools
RUN go install github.com/go-delve/delve/cmd/dlv@latest && \
    go install golang.org/x/tools/gopls@latest && \
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

WORKDIR /app

# Copy go mod files
COPY task-management/go.mod task-management/go.sum ./
RUN go mod download

# Copy source code
COPY task-management/ ./

# Copy TLA+ specs for reference
COPY *.tla *.cfg /opt/tla-specs/

# Expose ports
EXPOSE 8080 2345

# Volume for live code reload
VOLUME ["/app"]

# Air configuration
RUN echo 'root = "." \n\
tmp_dir = "tmp" \n\
[build] \n\
cmd = "go build -o ./tmp/server ./cmd/server" \n\
bin = "tmp/server" \n\
full_bin = "dlv exec --listen=:2345 --headless=true --api-version=2 --accept-multiclient ./tmp/server" \n\
include_ext = ["go", "tpl", "tmpl", "html"] \n\
exclude_dir = ["tmp", "vendor", "node_modules"] \n\
delay = 1000 \n\
[log] \n\
time = true' > .air.toml

# Environment variables for development
ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64 \
    LOG_LEVEL=debug \
    DEBUG_MODE=true

# Run with hot reload
CMD ["air", "-c", ".air.toml"]