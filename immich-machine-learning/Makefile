CONTAINER_ENGINE ?= docker
IMAGE ?= immich-machine-learning:local
BUILD_ARGS ?=
.PHONY: build-local test test-nonroot test-security test-health scan
build-local:
	$(CONTAINER_ENGINE) build --pull --target runtime $(BUILD_ARGS) -t $(IMAGE) .
test:
	CONTAINER_ENGINE=$(CONTAINER_ENGINE) IMAGE=$(IMAGE) sh test/runtime.sh
test-nonroot:
	test "$$($(CONTAINER_ENGINE) run --rm --network none --entrypoint id $(IMAGE) -u)" = 1000
test-security:
	$(CONTAINER_ENGINE) run --rm --network none --read-only --cap-drop ALL --security-opt no-new-privileges --entrypoint python $(IMAGE) -c 'import os,pathlib; assert os.getuid()==1000; assert "CapBnd:\t0000000000000000" in pathlib.Path("/proc/self/status").read_text()'
test-health: test
scan:
	trivy image --scanners vuln --ignorefile security/no-ignores.txt --ignore-unfixed --severity HIGH,CRITICAL --exit-code 1 $(IMAGE)
