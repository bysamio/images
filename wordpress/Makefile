# BySamio WordPress - Build and Test Commands
# Usage: make <target>

REGISTRY := ghcr.io
IMAGE_NAME := bysamio/wordpress
WORDPRESS_VERSION := 7.1.3
TAG := $(WORDPRESS_VERSION)
CONTAINER_ENGINE ?= docker
IMAGE ?= wordpress:local
TRIVY ?= trivy

.PHONY: help build build-local push test test-nonroot test-security test-health test-php-release scan scan-report run run-with-db clean

help: ## Show this help message
	@echo "BySamio WordPress - Build Commands"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

build: ## Build the Docker image for multiple platforms
	$(CONTAINER_ENGINE) buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg WORDPRESS_VERSION=$(WORDPRESS_VERSION) \
		-t $(REGISTRY)/$(IMAGE_NAME):$(TAG) \
		-t $(REGISTRY)/$(IMAGE_NAME):latest \
		.

build-local: ## Build the Docker image for local testing (current platform only)
	$(CONTAINER_ENGINE) build --pull \
		--build-arg WORDPRESS_VERSION=$(WORDPRESS_VERSION) \
		-t $(REGISTRY)/$(IMAGE_NAME):$(TAG) \
		-t $(REGISTRY)/$(IMAGE_NAME):latest \
		-t $(IMAGE) \
		.

push: build ## Build and push the Docker image to registry
	$(CONTAINER_ENGINE) buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg WORDPRESS_VERSION=$(WORDPRESS_VERSION) \
		-t $(REGISTRY)/$(IMAGE_NAME):$(TAG) \
		-t $(REGISTRY)/$(IMAGE_NAME):latest \
		--push \
		.

test: build-local test-nonroot test-security test-health ## Build, then run all tests
	@echo "All tests passed!"

test-nonroot: ## Test that the image's default user is UID 1001
	@echo "Testing non-root execution..."
	@USER_ID=$$($(CONTAINER_ENGINE) run --rm --entrypoint id $(IMAGE) -u); \
	if [ "$$USER_ID" != "1001" ]; then \
		echo "FAIL: Container running as UID $$USER_ID, expected 1001"; \
		exit 1; \
	fi
	@echo "PASS: Container runs as UID 1001"

test-security: ## Test that image works with restricted security context
	@echo "Testing restricted security context..."
	@$(CONTAINER_ENGINE) run --rm \
		--user 1001:1001 \
		--cap-drop ALL \
		--security-opt no-new-privileges:true \
		$(IMAGE) \
		apache2 -v > /dev/null 2>&1
	@echo "PASS: Image works with restricted security context"

test-health: ## Install WordPress against MariaDB and serve it on port 8080 (restricted)
	@echo "Testing WordPress install and serving..."
	@CONTAINER_ENGINE=$(CONTAINER_ENGINE) IMAGE=$(IMAGE) bash test/run.sh

test-php-release: ## Fail if php.net has a newer release on the image's PHP branch
	@bash test/php-release.sh "$$($(CONTAINER_ENGINE) run --rm --network none --entrypoint php $(IMAGE) -r 'echo PHP_VERSION;')"

# Publication gate used by CI: fixable HIGH/CRITICAL findings block release.
scan: ## Trivy gate: fail on fixable HIGH/CRITICAL vulnerabilities
	$(TRIVY) image --scanners vuln --ignorefile security/no-ignores.txt --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 $(IMAGE)

scan-report: ## Full Trivy JSON report, including findings without a fix
	$(TRIVY) image --scanners vuln --ignorefile security/no-ignores.txt --format json --output trivy-report.json $(IMAGE)

run: build-local ## Run the container locally for testing
	@echo "Starting WordPress on http://localhost:8080"
	@echo "Press Ctrl+C to stop"
	$(CONTAINER_ENGINE) run --rm -it \
		-p 8080:8080 \
		-e WORDPRESS_DB_HOST=host.docker.internal \
		-e WORDPRESS_DB_USER=wordpress \
		-e WORDPRESS_DB_PASSWORD=wordpress \
		-e WORDPRESS_DB_NAME=wordpress \
		$(IMAGE)

run-with-db: build-local ## Run WordPress with MariaDB using docker-compose
	$(CONTAINER_ENGINE) compose up

clean: ## Clean up test images
	-$(CONTAINER_ENGINE) rmi $(IMAGE) 2>/dev/null
	-$(CONTAINER_ENGINE) rmi $(REGISTRY)/$(IMAGE_NAME):$(TAG) 2>/dev/null
	-$(CONTAINER_ENGINE) rmi $(REGISTRY)/$(IMAGE_NAME):latest 2>/dev/null
