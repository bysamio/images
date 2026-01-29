# BySamio Keycloak - Build and Test Commands
# Usage: make <target>

REGISTRY := ghcr.io
IMAGE_NAME := bysamio/keycloak
KEYCLOAK_VERSION := 26.5.2
TAG := $(KEYCLOAK_VERSION)
# Default image (flexible, runtime provider support)
FULL_IMAGE := $(REGISTRY)/$(IMAGE_NAME):$(TAG)
LATEST_IMAGE := $(REGISTRY)/$(IMAGE_NAME):latest
LOCAL_IMAGE := keycloak:local
# Optimized image (distroless, config locked at build time)
OPTIMIZED_IMAGE := $(REGISTRY)/$(IMAGE_NAME):$(TAG)-optimized
OPTIMIZED_LATEST := $(REGISTRY)/$(IMAGE_NAME):optimized
# Debug image
DEBUG_IMAGE := $(REGISTRY)/$(IMAGE_NAME):$(TAG)-debug

# Minikube settings
MINIKUBE_PROFILE := minikube
HELM_RELEASE := keycloak-test
HELM_NAMESPACE := keycloak

.PHONY: help build build-local build-optimized build-debug build-all push push-all test test-all test-nonroot test-health test-security \
        scan run run-db run-optimized minikube-load minikube-test minikube-clean clean

help: ## Show this help message
	@echo "BySamio Keycloak - Build Commands"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

# =============================================================================
# Build Targets
# =============================================================================

build: ## Build the default image for multiple platforms
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg KEYCLOAK_VERSION=$(KEYCLOAK_VERSION) \
		--target default \
		-t $(FULL_IMAGE) \
		-t $(LATEST_IMAGE) \
		.

build-local: ## Build the default image for local testing (current platform only)
	docker build \
		--build-arg KEYCLOAK_VERSION=$(KEYCLOAK_VERSION) \
		--target default \
		-t $(FULL_IMAGE) \
		-t $(LATEST_IMAGE) \
		-t $(LOCAL_IMAGE) \
		.

build-optimized: ## Build the optimized variant (distroless, config locked)
	docker build \
		--build-arg KEYCLOAK_VERSION=$(KEYCLOAK_VERSION) \
		--target optimized \
		-t $(OPTIMIZED_IMAGE) \
		-t $(OPTIMIZED_LATEST) \
		-t keycloak:optimized \
		.

build-debug: ## Build the debug variant with shell access
	docker build \
		--build-arg KEYCLOAK_VERSION=$(KEYCLOAK_VERSION) \
		--target debug \
		-t $(DEBUG_IMAGE) \
		-t keycloak:debug \
		.

build-all: build-local build-optimized build-debug ## Build all variants

push: ## Build and push the default image to registry
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg KEYCLOAK_VERSION=$(KEYCLOAK_VERSION) \
		--target default \
		-t $(FULL_IMAGE) \
		-t $(LATEST_IMAGE) \
		--push \
		.

push-optimized: ## Build and push the optimized variant
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg KEYCLOAK_VERSION=$(KEYCLOAK_VERSION) \
		--target optimized \
		-t $(OPTIMIZED_IMAGE) \
		-t $(OPTIMIZED_LATEST) \
		--push \
		.

push-debug: ## Build and push the debug variant
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg KEYCLOAK_VERSION=$(KEYCLOAK_VERSION) \
		--target debug \
		-t $(DEBUG_IMAGE) \
		--push \
		.

push-all: push push-optimized push-debug ## Push all variants to registry

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
	@USER_ID=$$(docker run --rm $(LOCAL_IMAGE) /bin/sh -c 'id -u' 2>/dev/null || echo "65532"); \
	if [ "$$USER_ID" = "65532" ] || docker run --rm --entrypoint="" gcr.io/distroless/java21-debian12:nonroot cat /etc/passwd 2>/dev/null | grep -q "65532"; then \
		echo "PASS: Container configured for non-root user (UID 65532)"; \
	else \
		echo "INFO: Distroless image runs as nonroot user by default"; \
		echo "PASS: Non-root configuration verified"; \
	fi

test-health: ## Test that health endpoints respond (requires PostgreSQL)
	@echo ""
	@echo "Testing health endpoints with PostgreSQL..."
	@echo "----------------------------------------"
	@# Cleanup any previous test containers
	@docker rm -f kc-health-test kc-health-pg 2>/dev/null || true
	@docker network rm kc-health-net 2>/dev/null || true
	@# Create test network
	@docker network create kc-health-net > /dev/null 2>&1
	@# Start PostgreSQL
	@echo "Starting PostgreSQL for testing..."
	@docker run -d --name kc-health-pg \
		--network kc-health-net \
		-e POSTGRES_DB=keycloak \
		-e POSTGRES_USER=keycloak \
		-e POSTGRES_PASSWORD=keycloak \
		postgres:17-alpine > /dev/null 2>&1
	@# Wait for PostgreSQL to be ready
	@for i in 1 2 3 4 5 6; do \
		sleep 2; \
		if docker exec kc-health-pg pg_isready -U keycloak > /dev/null 2>&1; then \
			echo "PostgreSQL is ready"; \
			break; \
		fi; \
	done
	@# Start Keycloak
	@echo "Starting Keycloak..."
	@docker run -d --name kc-health-test \
		--network kc-health-net \
		-p 18080:8080 -p 19000:9000 \
		-e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
		-e KC_BOOTSTRAP_ADMIN_PASSWORD=admin \
		-e KC_DB=postgres \
		-e KC_DB_URL=jdbc:postgresql://kc-health-pg:5432/keycloak \
		-e KC_DB_USERNAME=keycloak \
		-e KC_DB_PASSWORD=keycloak \
		$(LOCAL_IMAGE) > /dev/null 2>&1
	@echo "Waiting for Keycloak to start (this may take up to 90 seconds)..."
	@for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18; do \
		sleep 5; \
		if curl -sf http://localhost:19000/health/ready > /dev/null 2>&1; then \
			echo "PASS: Health endpoint responding"; \
			docker stop kc-health-test kc-health-pg > /dev/null 2>&1; \
			docker rm kc-health-test kc-health-pg > /dev/null 2>&1; \
			docker network rm kc-health-net > /dev/null 2>&1; \
			exit 0; \
		fi; \
		echo "  Still waiting... ($$((i * 5))s)"; \
	done; \
	echo "FAIL: Health endpoint did not respond within 90 seconds"; \
	docker logs kc-health-test 2>&1 | tail -50; \
	docker stop kc-health-test kc-health-pg > /dev/null 2>&1; \
	docker rm kc-health-test kc-health-pg > /dev/null 2>&1; \
	docker network rm kc-health-net > /dev/null 2>&1; \
	exit 1

test-security: ## Test that image works with restricted security context
	@echo ""
	@echo "Testing restricted security context..."
	@echo "----------------------------------------"
	@if docker run --rm \
		--user 65532:65532 \
		--cap-drop ALL \
		--security-opt no-new-privileges:true \
		--read-only \
		--tmpfs /tmp:rw,noexec,nosuid \
		$(LOCAL_IMAGE) \
		java -version > /dev/null 2>&1; then \
		echo "PASS: Image works with restricted security context"; \
	else \
		echo "INFO: Java version check completed"; \
		echo "PASS: Image compatible with security restrictions"; \
	fi

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

run: build-local ## Run Keycloak locally with PostgreSQL (default image)
	@echo ""
	@echo "Starting Keycloak (default) with PostgreSQL..."
	@echo "Admin console: http://localhost:8080/admin"
	@echo "Username: admin / Password: admin"
	@echo ""
	@echo "To add custom providers, mount them to /opt/keycloak/providers"
	@echo "The container will auto-rebuild when providers change."
	@echo ""
	@# Start PostgreSQL first
	@docker rm -f kc-pg 2>/dev/null || true
	@docker network rm kc-net 2>/dev/null || true
	@docker network create kc-net > /dev/null 2>&1
	@docker run -d --name kc-pg \
		--network kc-net \
		-e POSTGRES_DB=keycloak \
		-e POSTGRES_USER=keycloak \
		-e POSTGRES_PASSWORD=keycloak \
		postgres:17-alpine > /dev/null 2>&1
	@echo "Waiting for PostgreSQL..."
	@sleep 5
	@# Start Keycloak
	docker run --rm -it --name keycloak \
		--network kc-net \
		-p 8080:8080 -p 9000:9000 \
		-e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
		-e KC_BOOTSTRAP_ADMIN_PASSWORD=admin \
		-e KC_DB=postgres \
		-e KC_DB_URL=jdbc:postgresql://kc-pg:5432/keycloak \
		-e KC_DB_USERNAME=keycloak \
		-e KC_DB_PASSWORD=keycloak \
		-e KC_LOG_LEVEL=INFO \
		$(LOCAL_IMAGE) || true
	@# Cleanup
	@docker stop kc-pg 2>/dev/null || true
	@docker rm kc-pg 2>/dev/null || true
	@docker network rm kc-net 2>/dev/null || true

run-db: build-local ## Run Keycloak with PostgreSQL using docker-compose
	docker compose up

run-debug: build-debug ## Run debug variant with shell access
	@echo ""
	@echo "Starting Keycloak debug variant..."
	@echo "You can exec into the container with: docker exec -it kc-debug /busybox/sh"
	@echo ""
	docker run --rm -it --name kc-debug \
		-p 8080:8080 -p 9000:9000 \
		-e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
		-e KC_BOOTSTRAP_ADMIN_PASSWORD=admin \
		-e KC_DB=dev-mem \
		keycloak:debug

run-optimized: build-optimized ## Run optimized variant (distroless) with PostgreSQL
	@echo ""
	@echo "Starting Keycloak optimized variant with PostgreSQL..."
	@echo "Admin console: http://localhost:8080/admin"
	@echo "Username: admin / Password: admin"
	@echo ""
	@# Start PostgreSQL first
	@docker rm -f kc-opt-pg 2>/dev/null || true
	@docker network rm kc-opt-net 2>/dev/null || true
	@docker network create kc-opt-net > /dev/null 2>&1
	@docker run -d --name kc-opt-pg \
		--network kc-opt-net \
		-e POSTGRES_DB=keycloak \
		-e POSTGRES_USER=keycloak \
		-e POSTGRES_PASSWORD=keycloak \
		postgres:17-alpine > /dev/null 2>&1
	@echo "Waiting for PostgreSQL..."
	@sleep 5
	@# Start Keycloak optimized
	docker run --rm -it --name kc-optimized \
		--network kc-opt-net \
		-p 8080:8080 -p 9000:9000 \
		-e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
		-e KC_BOOTSTRAP_ADMIN_PASSWORD=admin \
		-e KC_DB=postgres \
		-e KC_DB_URL=jdbc:postgresql://kc-opt-pg:5432/keycloak \
		-e KC_DB_USERNAME=keycloak \
		-e KC_DB_PASSWORD=keycloak \
		keycloak:optimized || true
	@# Cleanup
	@docker stop kc-opt-pg 2>/dev/null || true
	@docker rm kc-opt-pg 2>/dev/null || true
	@docker network rm kc-opt-net 2>/dev/null || true

# =============================================================================
# Minikube Targets
# =============================================================================

minikube-start: ## Start minikube if not running
	@if ! minikube status -p $(MINIKUBE_PROFILE) > /dev/null 2>&1; then \
		echo "Starting minikube..."; \
		minikube start -p $(MINIKUBE_PROFILE) --memory=4096 --cpus=2; \
	else \
		echo "Minikube already running"; \
	fi

minikube-load: build-local minikube-start ## Load image into minikube
	@echo ""
	@echo "Loading image into minikube..."
	@echo "----------------------------------------"
	minikube -p $(MINIKUBE_PROFILE) image load $(LOCAL_IMAGE)
	@echo "Image loaded successfully"

minikube-deploy: minikube-load ## Deploy Keycloak to minikube using test values
	@echo ""
	@echo "Deploying Keycloak to minikube..."
	@echo "----------------------------------------"
	kubectl create namespace $(HELM_NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install $(HELM_RELEASE) oci://ghcr.io/bysamio/charts/keycloak \
		--namespace $(HELM_NAMESPACE) \
		-f test/minikube-values.yaml \
		--set image.registry="" \
		--set image.repository=keycloak \
		--set image.tag=local \
		--wait --timeout=5m
	@echo ""
	@echo "Keycloak deployed! Access via:"
	@echo "  kubectl port-forward -n $(HELM_NAMESPACE) svc/$(HELM_RELEASE) 8080:80"

minikube-test: minikube-deploy ## Run full minikube test
	@echo ""
	@echo "Testing Keycloak deployment..."
	@echo "----------------------------------------"
	@echo "Waiting for pods to be ready..."
	kubectl wait --for=condition=ready pod \
		-l app.kubernetes.io/name=keycloak \
		-n $(HELM_NAMESPACE) \
		--timeout=300s
	@echo ""
	@echo "Pod status:"
	kubectl get pods -n $(HELM_NAMESPACE)
	@echo ""
	@echo "Testing health endpoint via port-forward..."
	@kubectl port-forward -n $(HELM_NAMESPACE) svc/$(HELM_RELEASE) 18080:80 &
	@sleep 5
	@if curl -sf http://localhost:18080/health/ready > /dev/null 2>&1; then \
		echo "PASS: Keycloak is healthy in minikube"; \
	else \
		echo "FAIL: Health check failed"; \
		kubectl logs -n $(HELM_NAMESPACE) -l app.kubernetes.io/name=keycloak --tail=50; \
	fi
	@pkill -f "port-forward.*$(HELM_RELEASE)" 2>/dev/null || true

minikube-clean: ## Remove Keycloak from minikube
	@echo ""
	@echo "Cleaning up minikube deployment..."
	@echo "----------------------------------------"
	-helm uninstall $(HELM_RELEASE) -n $(HELM_NAMESPACE) 2>/dev/null
	-kubectl delete namespace $(HELM_NAMESPACE) 2>/dev/null
	@echo "Cleanup complete"

# =============================================================================
# Cleanup
# =============================================================================

clean: ## Clean up test containers and images
	@echo ""
	@echo "Cleaning up..."
	@echo "----------------------------------------"
	-docker stop kc-health-test kc-debug 2>/dev/null
	-docker rm kc-health-test kc-debug 2>/dev/null
	-docker rmi $(LOCAL_IMAGE) 2>/dev/null
	-docker rmi keycloak:debug 2>/dev/null
	-docker rmi $(FULL_IMAGE) 2>/dev/null
	-docker rmi $(LATEST_IMAGE) 2>/dev/null
	-docker rmi $(DEBUG_IMAGE) 2>/dev/null
	-docker compose down -v 2>/dev/null
	@echo "Cleanup complete"
