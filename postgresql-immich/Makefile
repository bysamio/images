CONTAINER_ENGINE ?= docker
IMAGE ?= postgresql-immich:local
.PHONY: build-local test test-nonroot test-root-disabled test-security test-health scan
build-local:
	$(CONTAINER_ENGINE) build --pull --target runtime -t $(IMAGE) .
test:
	CONTAINER_ENGINE=$(CONTAINER_ENGINE) IMAGE=$(IMAGE) sh test/runtime.sh
test-nonroot:
	test "$$($(CONTAINER_ENGINE) run --rm --entrypoint id $(IMAGE) -u)" = 1001
test-root-disabled:
	! $(CONTAINER_ENGINE) run --rm --user 0:0 $(IMAGE) postgres --version
test-security:
	$(CONTAINER_ENGINE) run --rm --cap-drop ALL --security-opt no-new-privileges --entrypoint postgres $(IMAGE) --version
test-health: test
scan:
	trivy image --scanners vuln --ignorefile security/no-ignores.txt --ignore-unfixed --severity HIGH,CRITICAL --exit-code 1 $(IMAGE)
