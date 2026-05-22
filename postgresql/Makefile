# BySamio PostgreSQL - Build and Test Commands
# Usage: make <target>

REGISTRY := ghcr.io
IMAGE_NAME := bysamio/postgresql
POSTGRESQL_VERSION := 17.10
TAG := $(POSTGRESQL_VERSION)
ALPINE_TAG := $(POSTGRESQL_VERSION)-alpine
FULL_IMAGE := $(REGISTRY)/$(IMAGE_NAME):$(TAG)
ALPINE_IMAGE := $(REGISTRY)/$(IMAGE_NAME):$(ALPINE_TAG)
LATEST_IMAGE := $(REGISTRY)/$(IMAGE_NAME):latest
LOCAL_IMAGE := postgresql:local
CONTAINER_ENGINE ?= docker
COMPOSE ?= $(CONTAINER_ENGINE) compose

.PHONY: help build build-local push test test-all test-nonroot test-root-disabled test-health test-security \
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
	$(CONTAINER_ENGINE) buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg POSTGRESQL_VERSION=$(POSTGRESQL_VERSION) \
		--target runtime \
		-t $(FULL_IMAGE) \
		-t $(ALPINE_IMAGE) \
		-t $(LATEST_IMAGE) \
		.

build-local: ## Build the Docker image for local testing (current platform only)
	$(CONTAINER_ENGINE) build \
		--build-arg POSTGRESQL_VERSION=$(POSTGRESQL_VERSION) \
		--target runtime \
		-t $(FULL_IMAGE) \
		-t $(ALPINE_IMAGE) \
		-t $(LATEST_IMAGE) \
		-t $(LOCAL_IMAGE) \
		.

push: ## Build and push the Docker image to registry
	$(CONTAINER_ENGINE) buildx build \
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

test: build-local test-nonroot test-root-disabled test-health test-security ## Run all tests
	@echo ""
	@echo "========================================"
	@echo "All tests passed!"
	@echo "========================================"

test-all: test scan ## Run all tests including vulnerability scan

test-nonroot: ## Test that container runs as non-root
	@echo ""
	@echo "Testing non-root execution..."
	@echo "----------------------------------------"
	@USER_ID=$$($(CONTAINER_ENGINE) run --rm --entrypoint id $(LOCAL_IMAGE) -u); \
	if [ "$$USER_ID" = "1001" ]; then \
		echo "PASS: Container runs as UID 1001"; \
	else \
		echo "FAIL: Container running as UID $$USER_ID, expected 1001"; \
		exit 1; \
	fi

test-root-disabled: ## Test that root startup is rejected and gosu is absent
	@echo ""
	@echo "Testing root startup is disabled..."
	@echo "----------------------------------------"
	@$(CONTAINER_ENGINE) run --rm --entrypoint /bin/sh $(LOCAL_IMAGE) -c 'test ! -e /usr/local/bin/gosu'
	@if $(CONTAINER_ENGINE) run --rm --user 0:0 $(LOCAL_IMAGE) >/tmp/postgresql-root-test.log 2>&1; then \
		echo "FAIL: Root startup succeeded unexpectedly"; \
		cat /tmp/postgresql-root-test.log; \
		exit 1; \
	else \
		echo "PASS: Root startup is rejected"; \
	fi

test-health: ## Test that PostgreSQL starts and accepts connections
	@echo ""
	@echo "Testing PostgreSQL health..."
	@echo "----------------------------------------"
	@$(CONTAINER_ENGINE) rm -f pg-health-test 2>/dev/null || true
	@$(CONTAINER_ENGINE) run -d --name pg-health-test \
		-e POSTGRES_PASSWORD=testpassword \
		-e POSTGRES_USER=testuser \
		-e POSTGRES_DB=testdb \
		-p 15432:5432 \
		$(LOCAL_IMAGE)
	@echo "Waiting for PostgreSQL to start..."
	@for i in 1 2 3 4 5 6 7 8 9 10; do \
		sleep 3; \
		if $(CONTAINER_ENGINE) exec pg-health-test pg_isready -U testuser -d testdb > /dev/null 2>&1; then \
			echo "PASS: PostgreSQL is ready"; \
			$(CONTAINER_ENGINE) stop pg-health-test > /dev/null 2>&1; \
			$(CONTAINER_ENGINE) rm pg-health-test > /dev/null 2>&1; \
			exit 0; \
		fi; \
		echo "  Still waiting... ($$((i * 3))s)"; \
	done; \
	echo "FAIL: PostgreSQL did not start within 30 seconds"; \
	$(CONTAINER_ENGINE) logs pg-health-test 2>&1 | tail -20; \
	$(CONTAINER_ENGINE) stop pg-health-test > /dev/null 2>&1; \
	$(CONTAINER_ENGINE) rm pg-health-test > /dev/null 2>&1; \
	exit 1

test-security: ## Test that image works with restricted security context
	@echo ""
	@echo "Testing restricted security context..."
	@echo "----------------------------------------"
	@$(CONTAINER_ENGINE) run --rm \
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
		$(CONTAINER_ENGINE) run --rm \
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
		$(CONTAINER_ENGINE) run --rm \
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
	$(CONTAINER_ENGINE) run --rm -it \
		-p 5432:5432 \
		-e POSTGRES_PASSWORD=postgres \
		-e POSTGRES_USER=postgres \
		-e POSTGRES_DB=postgres \
		$(LOCAL_IMAGE)

run-persistent: build-local ## Run PostgreSQL with persistent data
	@echo ""
	@echo "Starting PostgreSQL with persistent volume..."
	$(CONTAINER_ENGINE) run --rm -it \
		-p 5432:5432 \
		-e POSTGRES_PASSWORD=postgres \
		-e POSTGRES_USER=postgres \
		-e POSTGRES_DB=postgres \
		-v pgdata:/var/lib/postgresql/data \
		$(LOCAL_IMAGE)

run-db: build-local ## Run PostgreSQL using compose
	$(COMPOSE) up

# =============================================================================
# Cleanup
# =============================================================================

clean: ## Clean up test containers and images
	@echo ""
	@echo "Cleaning up..."
	@echo "----------------------------------------"
	-$(CONTAINER_ENGINE) stop pg-health-test 2>/dev/null
	-$(CONTAINER_ENGINE) rm pg-health-test 2>/dev/null
	-$(CONTAINER_ENGINE) rmi $(LOCAL_IMAGE) 2>/dev/null
	-$(CONTAINER_ENGINE) rmi $(FULL_IMAGE) 2>/dev/null
	-$(CONTAINER_ENGINE) rmi $(LATEST_IMAGE) 2>/dev/null
	-$(COMPOSE) down -v 2>/dev/null
	@echo "Cleanup complete"
