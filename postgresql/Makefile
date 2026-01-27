# BySamio PostgreSQL - Build and Test Commands
# Usage: make <target>

REGISTRY := ghcr.io
IMAGE_NAME := bysamio/postgresql
POSTGRESQL_VERSION := 17.7
TAG := $(POSTGRESQL_VERSION)
ALPINE_TAG := $(POSTGRESQL_VERSION)-alpine
FULL_IMAGE := $(REGISTRY)/$(IMAGE_NAME):$(TAG)
ALPINE_IMAGE := $(REGISTRY)/$(IMAGE_NAME):$(ALPINE_TAG)
LATEST_IMAGE := $(REGISTRY)/$(IMAGE_NAME):latest
LOCAL_IMAGE := postgresql:local

.PHONY: help build build-local push test test-all test-nonroot test-health test-security \
        scan run clean

help: ## Show this help message
	@echo "BySamio PostgreSQL - Build Commands"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

# =============================================================================
# Build Targets
# =============================================================================

build: ## Build the Docker image for multiple platforms
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg POSTGRESQL_VERSION=$(POSTGRESQL_VERSION) \
		--target runtime \
		-t $(FULL_IMAGE) \
		-t $(ALPINE_IMAGE) \
		-t $(LATEST_IMAGE) \
		.

build-local: ## Build the Docker image for local testing (current platform only)
	docker build \
		--build-arg POSTGRESQL_VERSION=$(POSTGRESQL_VERSION) \
		--target runtime \
		-t $(FULL_IMAGE) \
		-t $(ALPINE_IMAGE) \
		-t $(LATEST_IMAGE) \
		-t $(LOCAL_IMAGE) \
		.

push: ## Build and push the Docker image to registry
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg POSTGRESQL_VERSION=$(POSTGRESQL_VERSION) \
		--target runtime \
		-t $(FULL_IMAGE) \
		-t $(ALPINE_IMAGE) \
		-t $(LATEST_IMAGE) \
		--push \
		.

# =============================================================================
# Test Targets
# =============================================================================

test: build-local test-nonroot test-health test-security ## Run all tests
	@echo ""
	@echo "========================================"
	@echo "All tests passed!"
	@echo "========================================"

test-all: test scan ## Run all tests including vulnerability scan

test-nonroot: ## Test that container runs as non-root
	@echo ""
	@echo "Testing non-root execution..."
	@echo "----------------------------------------"
	@USER_ID=$$(docker run --rm --entrypoint id $(LOCAL_IMAGE) -u); \
	if [ "$$USER_ID" = "1001" ]; then \
		echo "PASS: Container runs as UID 1001"; \
	else \
		echo "FAIL: Container running as UID $$USER_ID, expected 1001"; \
		exit 1; \
	fi

test-health: ## Test that PostgreSQL starts and accepts connections
	@echo ""
	@echo "Testing PostgreSQL health..."
	@echo "----------------------------------------"
	@docker rm -f pg-health-test 2>/dev/null || true
	@docker run -d --name pg-health-test \
		-e POSTGRES_PASSWORD=testpassword \
		-e POSTGRES_USER=testuser \
		-e POSTGRES_DB=testdb \
		-p 15432:5432 \
		$(LOCAL_IMAGE)
	@echo "Waiting for PostgreSQL to start..."
	@for i in 1 2 3 4 5 6 7 8 9 10; do \
		sleep 3; \
		if docker exec pg-health-test pg_isready -U testuser -d testdb > /dev/null 2>&1; then \
			echo "PASS: PostgreSQL is ready"; \
			docker stop pg-health-test > /dev/null 2>&1; \
			docker rm pg-health-test > /dev/null 2>&1; \
			exit 0; \
		fi; \
		echo "  Still waiting... ($$((i * 3))s)"; \
	done; \
	echo "FAIL: PostgreSQL did not start within 30 seconds"; \
	docker logs pg-health-test 2>&1 | tail -20; \
	docker stop pg-health-test > /dev/null 2>&1; \
	docker rm pg-health-test > /dev/null 2>&1; \
	exit 1

test-security: ## Test that image works with restricted security context
	@echo ""
	@echo "Testing restricted security context..."
	@echo "----------------------------------------"
	@docker run --rm \
		--user 1001:1001 \
		--cap-drop ALL \
		--security-opt no-new-privileges:true \
		--entrypoint postgres \
		$(LOCAL_IMAGE) \
		--version > /dev/null 2>&1
	@echo "PASS: Image works with restricted security context"

# =============================================================================
# Security Scanning
# =============================================================================

scan: build-local ## Run Trivy vulnerability scan
	@echo ""
	@echo "Running vulnerability scan..."
	@echo "----------------------------------------"
	@if command -v trivy > /dev/null 2>&1; then \
		trivy image --severity CRITICAL,HIGH $(LOCAL_IMAGE); \
	else \
		echo "Trivy not installed. Running via Docker..."; \
		docker run --rm \
			-v /var/run/docker.sock:/var/run/docker.sock \
			aquasec/trivy:latest image \
			--severity CRITICAL,HIGH $(LOCAL_IMAGE); \
	fi

scan-full: build-local ## Run full Trivy vulnerability scan (all severities)
	@echo ""
	@echo "Running full vulnerability scan..."
	@echo "----------------------------------------"
	@if command -v trivy > /dev/null 2>&1; then \
		trivy image $(LOCAL_IMAGE); \
	else \
		docker run --rm \
			-v /var/run/docker.sock:/var/run/docker.sock \
			aquasec/trivy:latest image $(LOCAL_IMAGE); \
	fi

# =============================================================================
# Local Run Targets
# =============================================================================

run: build-local ## Run PostgreSQL locally
	@echo ""
	@echo "Starting PostgreSQL on localhost:5432"
	@echo "Connection: psql -h localhost -U postgres -d postgres"
	@echo "Password: postgres"
	@echo "Press Ctrl+C to stop"
	@echo ""
	docker run --rm -it \
		-p 5432:5432 \
		-e POSTGRES_PASSWORD=postgres \
		-e POSTGRES_USER=postgres \
		-e POSTGRES_DB=postgres \
		$(LOCAL_IMAGE)

run-persistent: build-local ## Run PostgreSQL with persistent data
	@echo ""
	@echo "Starting PostgreSQL with persistent volume..."
	docker run --rm -it \
		-p 5432:5432 \
		-e POSTGRES_PASSWORD=postgres \
		-e POSTGRES_USER=postgres \
		-e POSTGRES_DB=postgres \
		-v pgdata:/var/lib/postgresql/data \
		$(LOCAL_IMAGE)

run-db: build-local ## Run PostgreSQL using docker-compose
	docker-compose up

# =============================================================================
# Cleanup
# =============================================================================

clean: ## Clean up test containers and images
	@echo ""
	@echo "Cleaning up..."
	@echo "----------------------------------------"
	-docker stop pg-health-test 2>/dev/null
	-docker rm pg-health-test 2>/dev/null
	-docker rmi $(LOCAL_IMAGE) 2>/dev/null
	-docker rmi $(FULL_IMAGE) 2>/dev/null
	-docker rmi $(LATEST_IMAGE) 2>/dev/null
	-docker-compose down -v 2>/dev/null
	@echo "Cleanup complete"
