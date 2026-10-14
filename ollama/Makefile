CONTAINER_ENGINE ?= docker
IMAGE ?= ollama-cpu:local
TRIVY ?= trivy
BUILD_FORMAT = $(if $(filter podman,$(notdir $(CONTAINER_ENGINE))),--format docker,)

.PHONY: build-local test test-nonroot test-security test-health scan scan-report
build-local:
	$(CONTAINER_ENGINE) build $(BUILD_FORMAT) --platform linux/amd64 --target runtime -t $(IMAGE) .
test: test-nonroot test-security test-health
test-nonroot:
	@test "$$($(CONTAINER_ENGINE) run --rm --network none --entrypoint id $(IMAGE) -u)" = 1000
test-security:
	$(CONTAINER_ENGINE) run --rm --network none --cap-drop ALL --security-opt no-new-privileges:true --read-only \
		--entrypoint sh $(IMAGE) -ec 'test "$$OLLAMA_NO_CLOUD" = 1; grep -Eq "^CapEff:[[:space:]]+0+$$" /proc/1/status; grep -Eq "^NoNewPrivs:[[:space:]]+1$$" /proc/1/status'
test-health:
	CONTAINER_ENGINE=$(CONTAINER_ENGINE) IMAGE=$(IMAGE) bash test/run.sh
scan:
	$(TRIVY) image --scanners vuln --ignorefile security/no-ignores.txt --severity HIGH,CRITICAL --exit-code 1 $(IMAGE)
scan-report:
	$(TRIVY) image --scanners vuln --ignorefile security/no-ignores.txt --format json --output trivy-report.json $(IMAGE)
