CONTAINER_ENGINE ?= docker
IMAGE ?= paperless:local
BUILD_FORMAT = $(if $(filter podman,$(notdir $(CONTAINER_ENGINE))),--format docker,)
TRIVY ?= trivy

.PHONY: build-local test test-nonroot test-security test-health test-ai scan scan-report

build-local:
	$(CONTAINER_ENGINE) build $(BUILD_FORMAT) --target runtime -t $(IMAGE) .

# Test the already-built image: CI must publish exactly this artifact.
test: test-nonroot test-security test-ai test-health

test-nonroot:
	@test "$$($(CONTAINER_ENGINE) run --rm --network none --entrypoint id $(IMAGE) -u)" = 1000

test-security:
	$(CONTAINER_ENGINE) run --rm --network none --cap-drop ALL --security-opt no-new-privileges:true \
		--entrypoint python3 $(IMAGE) -c 'from pathlib import Path; s=dict(line.split(":",1) for line in Path("/proc/self/status").read_text().splitlines() if ":" in line); assert int(s["CapEff"].strip(),16)==0; assert s["NoNewPrivs"].strip()=="1"'

test-health:
	CONTAINER_ENGINE=$(CONTAINER_ENGINE) IMAGE=$(IMAGE) bash test/run.sh

# Match the collection's existing fixable HIGH/CRITICAL publication gate.
# Findings without a vendor fix remain in the full report; this is not a
# zero-vulnerability claim or acceptance for processing personal documents.
scan:
	$(TRIVY) image --scanners vuln --ignorefile security/no-ignores.txt --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 $(IMAGE)

scan-report:
	$(TRIVY) image --scanners vuln --ignorefile security/no-ignores.txt --format json --output trivy-report.json $(IMAGE)

# Actual retrieval/filtering/synthesis on synthetic RAM data; no model calls.
test-ai:
	$(CONTAINER_ENGINE) run --rm -i --network none --read-only --cap-drop ALL \
		--security-opt no-new-privileges:true --tmpfs /tmp:rw,nosuid,nodev,size=256m,mode=1777 \
		--entrypoint python3 $(IMAGE) -I -B - < test/ai_chat.py
	$(CONTAINER_ENGINE) run --rm -i --network none --read-only --cap-drop ALL \
		--security-opt no-new-privileges:true --tmpfs /tmp:rw,nosuid,nodev,size=256m,mode=1777 \
		--entrypoint python3 $(IMAGE) -I -B - < test/ai_classifier.py

	$(CONTAINER_ENGINE) run --rm -i --network none --read-only --cap-drop ALL \
		--security-opt no-new-privileges:true --tmpfs /tmp:rw,nosuid,nodev,size=256m,mode=1777 \
		--entrypoint python3 $(IMAGE) -I -B - < test/ai_permissions.py
