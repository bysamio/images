CONTAINER_ENGINE ?= docker
IMAGE ?= immich:local
DB_IMAGE ?= postgresql-immich:local
.PHONY: build-local test test-schema test-nonroot test-security test-health scan
build-local:
	$(CONTAINER_ENGINE) build --pull --target runtime -t $(IMAGE) .
test: test-schema
	CONTAINER_ENGINE=$(CONTAINER_ENGINE) IMAGE=$(IMAGE) DB_IMAGE=$(DB_IMAGE) sh test/runtime.sh
test-schema:
	$(CONTAINER_ENGINE) run --rm -i --network none --entrypoint node $(IMAGE) - < test/schema.cjs
test-nonroot:
	test "$$($(CONTAINER_ENGINE) run --rm --entrypoint id $(IMAGE) -u)" = 1000
test-security:
	$(CONTAINER_ENGINE) run --rm --cap-drop ALL --security-opt no-new-privileges --entrypoint node $(IMAGE) --version
test-health: test
scan:
	trivy image --scanners vuln --ignorefile security/no-ignores.txt --ignore-unfixed --severity HIGH,CRITICAL --exit-code 1 $(IMAGE)
