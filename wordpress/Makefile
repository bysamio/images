# BySamio WordPress - Build and Test Commands
# Usage: make <target>

REGISTRY := ghcr.io
IMAGE_NAME := bysamio/wordpress
WORDPRESS_VERSION := 6.9.0
TAG := $(WORDPRESS_VERSION)

.PHONY: help build build-local push test test-nonroot test-port test-security clean

help: ## Show this help message
	@echo "BySamio WordPress - Build Commands"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

build: ## Build the Docker image for multiple platforms
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg WORDPRESS_VERSION=$(WORDPRESS_VERSION) \
		-t $(REGISTRY)/$(IMAGE_NAME):$(TAG) \
		-t $(REGISTRY)/$(IMAGE_NAME):latest \
		.

build-local: ## Build the Docker image for local testing (current platform only)
	docker build \
		--build-arg WORDPRESS_VERSION=$(WORDPRESS_VERSION) \
		-t $(REGISTRY)/$(IMAGE_NAME):$(TAG) \
		-t $(REGISTRY)/$(IMAGE_NAME):latest \
		-t wordpress:local \
		.

push: build ## Build and push the Docker image to registry
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg WORDPRESS_VERSION=$(WORDPRESS_VERSION) \
		-t $(REGISTRY)/$(IMAGE_NAME):$(TAG) \
		-t $(REGISTRY)/$(IMAGE_NAME):latest \
		--push \
		.

test: build-local test-nonroot test-port test-security ## Run all tests
	@echo "All tests passed!"

test-nonroot: ## Test that container runs as non-root
	@echo "Testing non-root execution..."
	@USER_ID=$$(docker run --rm wordpress:local id -u); \
	if [ "$$USER_ID" != "1001" ]; then \
		echo "FAIL: Container running as UID $$USER_ID, expected 1001"; \
		exit 1; \
	fi
	@echo "PASS: Container runs as UID 1001"

test-port: ## Test that WordPress responds on port 8080
	@echo "Testing port 8080..."
	@docker run -d --name wp-test-port -p 18080:8080 wordpress:local
	@sleep 15
	@HTTP_CODE=$$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18080 || echo "000"); \
	docker stop wp-test-port > /dev/null 2>&1; \
	docker rm wp-test-port > /dev/null 2>&1; \
	if [ "$$HTTP_CODE" = "302" ] || [ "$$HTTP_CODE" = "200" ]; then \
		echo "PASS: WordPress responds on port 8080 (HTTP $$HTTP_CODE)"; \
	else \
		echo "FAIL: WordPress not responding (HTTP $$HTTP_CODE)"; \
		exit 1; \
	fi

test-security: ## Test that image works with restricted security context
	@echo "Testing restricted security context..."
	@docker run --rm \
		--user 1001:1001 \
		--cap-drop ALL \
		--security-opt no-new-privileges:true \
		wordpress:local \
		apache2 -v > /dev/null 2>&1
	@echo "PASS: Image works with restricted security context"

run: build-local ## Run the container locally for testing
	@echo "Starting WordPress on http://localhost:8080"
	@echo "Press Ctrl+C to stop"
	docker run --rm -it \
		-p 8080:8080 \
		-e WORDPRESS_DB_HOST=host.docker.internal \
		-e WORDPRESS_DB_USER=wordpress \
		-e WORDPRESS_DB_PASSWORD=wordpress \
		-e WORDPRESS_DB_NAME=wordpress \
		wordpress:local

run-with-db: build-local ## Run WordPress with MariaDB using docker-compose
	docker compose up

clean: ## Clean up test containers and images
	-docker stop wp-test-port 2>/dev/null
	-docker rm wp-test-port 2>/dev/null
	-docker rmi wordpress:local 2>/dev/null
	-docker rmi $(REGISTRY)/$(IMAGE_NAME):$(TAG) 2>/dev/null
	-docker rmi $(REGISTRY)/$(IMAGE_NAME):latest 2>/dev/null
