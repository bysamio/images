# Ollama CPU image

Prepare `ghcr.io/bysamio/ollama:0.40.3-cpu-r1-<run>-<attempt>` for the home-server's
local generation and embeddings. The image is not published or approved yet.

The reviewed contract is Linux/amd64 CPU inference, Ollama's existing API,
upstream stable source and native CPU payload provenance, Go dependency
remediation without suppressions, non-root UID/GID 1000, and startup under a
read-only root with a writable private `.ollama` directory. Cloud functions are
disabled. The consumer must provide encrypted state and restrict networking.

The executable is rebuilt from Ollama v0.40.3, commit
`eab97e9f92b9a25c2d52d2cc6c1b1c99bd9fae21`, with Go 1.27.2 and the generated
`go.mod`/`go.sum`. Minimum patched versions: jsonparser 1.1.2, klauspost/compress 1.18.7, x/crypto 0.57.0,
x/image 0.45.0, x/mod 0.41.0, x/net 0.60.0 and x/text 0.42.0. Go's minimum-version
selection can raise additional modules; inspect the committed resolved graph.
Explicit release version/mode linker flags preserve model-version checks.

The complete flat native CPU executable/library payload and native license files are retained from the
exact official AMD64 manifest. GPU/MLX subdirectories and their unused dangling header-directory link are excluded. Native parsing
coverage is limited: a clean OS/Go scan does not prove every C/C++ component safe.
Use only deliberately selected trusted model artifacts and verify their digests.

Acceptance requires focused upstream tests, actual CPU generation and embeddings,
correct `/api/version`, fresh state creation under runtime restrictions, invalid
API input rejection, complete image/SBOM scans and the collection's HIGH/CRITICAL
gate. CI must publish the exact tested artifact under a unique tag, then consumers
pin its immutable digest. No floating/latest tag or vulnerability ignore applies.

Sources:
- [Official Dockerfile](https://github.com/ollama/ollama/blob/eab97e9f92b9a25c2d52d2cc6c1b1c99bd9fae21/Dockerfile)
- [Official release build flags](https://github.com/ollama/ollama/blob/eab97e9f92b9a25c2d52d2cc6c1b1c99bd9fae21/.github/workflows/release.yaml)
- [Startup keypair](https://github.com/ollama/ollama/blob/eab97e9f92b9a25c2d52d2cc6c1b1c99bd9fae21/cmd/cmd.go)

Build: `make build-local`; tests: `make test`; full scan: `make scan-report`;
publication gate: `make scan`. The builder uses its native platform and cross-compiles when necessary; the
runtime target remains Linux/amd64.

## Security evidence and updates

[Local candidate review](security/review.json) records the exact binary, complete
scan counts and report hashes. Trivy 0.71.1 reports **0 HIGH, 0 CRITICAL**, with
nine MEDIUM OS occurrences currently lacking fixes. Govulncheck v1.9.0 identified
an additional compressor fix, applied at 1.18.7. Its remaining deprecated OpenPGP
module finding is absent from both the application's compile dependencies and
the actual 24,671-function ELF table. Nothing is added to an ignore file.
`test/audit/check.py` verifies that proof against the tested runtime binary and
blocks every other Go advisory, even one not yet assigned a Trivy severity.

The native AMD64 workflow repeats restricted real inference, records a full scan,
SBOM and Go audit, and blocks all HIGH/CRITICAL findings including those without
fixes before publication. A separate permission-limited job loads and publishes
the exact tested image. Weekly Monday checks rebuild and scan but never publish.
Review failures promptly; recheck the current residual findings by **18 October
2026**. Rebuild when fixed packages become available, rerun the same gates, merge
an image PR, and update consumers only to the resulting verified registry digest.

Native CPU libraries remain the pinned upstream payload (`llama.cpp b11351`).
The OS/Go scans do not cover all native parser behavior. Use trusted, deliberately
selected model artifacts, record their immutable manifests, and isolate inference
from document/database credentials and outbound access. Local results used AMD64
emulation on a Mac; CI must pass on a native AMD64 runner before release.
