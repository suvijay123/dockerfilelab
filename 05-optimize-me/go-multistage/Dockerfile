# ─────────────────────────────────────────────
# LEVEL 3 · INTERMEDIATE
# Multi-stage build for a Go web API
# Concepts: multi-stage builds, ARG, non-root USER,
#           HEALTHCHECK, LABEL, .dockerignore
#
# Result: the golang build image is ~300 MB, the final image is ~15 MB.
# ─────────────────────────────────────────────

# Build-time variable: change with --build-arg GO_VERSION=1.22
ARG GO_VERSION=1.23

# ===== STAGE 1: "builder" — has the full Go toolchain =====
FROM golang:${GO_VERSION}-alpine AS builder

WORKDIR /src

# Download dependencies first (cached unless go.mod changes)
COPY go.mod ./
RUN go mod download

# Copy source and compile a single static binary
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /out/server .

# ===== STAGE 2: "runtime" — tiny image with ONLY the binary =====
FROM alpine:3.20

# Metadata about the image (shows up in `docker inspect`)
LABEL org.opencontainers.image.title="go-api" \
      org.opencontainers.image.description="Docker workshop multi-stage demo"

# Security: create and switch to a non-root user
RUN addgroup -S app && adduser -S app -G app
USER app

WORKDIR /app

# Copy ONLY the compiled binary from the builder stage.
# The Go compiler, source code and caches are all left behind.
COPY --from=builder --chown=app:app /out/server .

# Runtime configuration (can be overridden with `docker run -e PORT=9090`)
ENV PORT=8080
EXPOSE 8080

# Docker checks this every 30s and marks the container healthy/unhealthy
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost:${PORT}/health || exit 1

ENTRYPOINT ["./server"]

# Build:   docker build -t go-api .
# Run:     docker run -d -p 8080:8080 --name api go-api
# Test:    curl http://localhost:8080
# Health:  docker ps          (look for "healthy" in STATUS)
# Size:    docker images go-api   (compare with golang:1.23-alpine)
