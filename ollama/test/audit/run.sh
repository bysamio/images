#!/usr/bin/env bash
# Run in the exact build stage; compare its binary hash with the tested runtime.
set -euo pipefail
export GOTOOLCHAIN=local
GOFLAGS='' go install golang.org/x/vuln/cmd/govulncheck@v1.9.0
/go/bin/govulncheck -mode=binary -json /out/ollama > /evidence/govulncheck.json
export CGO_ENABLED=1 GOOS=linux GOARCH=amd64
if [ "$(go env GOHOSTARCH)" != amd64 ]; then export CC=x86_64-linux-gnu-gcc CXX=x86_64-linux-gnu-g++; fi
go list -deps . > /evidence/compiled-packages.txt
# Inspect the runtime binary's actual Go function table, including stripped PIE.
GOFLAGS='' CGO_ENABLED=0 GOARCH="$(go env GOHOSTARCH)" go run /audit/compiled.go /out/ollama > /evidence/compiled-functions.json
