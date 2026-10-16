# BySam.io Paperless-ngx

A small derivative of Paperless-ngx 3.3.2 for the PostgreSQL-based home-server
archive. This image fixes selected dependencies and applies narrow, source-verified
chat retrieval and classification-budget corrections. It is a release candidate with remaining unfixed vulnerabilities;
publication does not clear it for processing personal documents.

## Contract

- Preserve Paperless 3.3.2 behavior except the reviewed AI corrections below;
  retain `/init`, health check and volume paths.
- Pin the official multi-platform base digest and the Ghostscript Trixie security
  package version; verify all four Ghostscript packages are at least
  `10.05.1~dfsg-1+deb13u3`.
- Patch fsspec with a hashed binary wheel. Check the complete installed Python
  environment for dependency conflicts. Preserve already-fixed dependencies.
- Remove unused pip and its ensurepip bootstrap wheel, including vulnerable
  vendored msgpack, setuptools and urllib3. Upstream `uv` remains available.
  `pip` and `python -m ensurepip` are intentionally unsupported in this image.
- Default to UID/GID `1000:1000`; support the upstream rootless configuration
  with explicit consumer `user: UID:GID`, pre-owned persistent directories and
  bundled German/English OCR. Do not pass upstream root-startup `USERMAP_*`
  variables into a rootless container.
- Use no credentials, `.env`, family documents or host configuration in the build.
  The build context allowlist includes only the Dockerfile, hashed requirements
  and reviewed build-time AI patches/token-budget helper.
- Test real OCR, dependency checks and startup in disposable synthetic storage.
  Capture full image vulnerability evidence and gate publication before pushing.
- Publish reviewed versions to `ghcr.io/bysamio/paperless-ngx`. Version `3.3.2-r1`
  receives a unique `<version>-<run-id>-<attempt>` tag; no tag is reused and no
  `latest` alias is published. Consumers pin the recorded registry digest.

## Build and verify

```bash
make build-local
make test
make scan-report
make scan
# On a Mac with Podman, prefix these commands with CONTAINER_ENGINE=podman.
```

`make test` verifies an existing `paperless:local` image; run the build first.
Podman builds use Docker format to retain the inherited health check.
Tests use only generated German/English pixels, disposable SQLite state and a
digest-pinned Valkey broker on an internal network. They exercise real upstream
OCR and searchable PDF/A-2b, `/init`, all supervised services, Celery ping,
migrations and the scheduled image health check. No host ports, host mounts or
family documents are used; only generated resources are removed.

The release workflow initially publishes **linux/amd64**, the home-server
platform. Native ARM64 tests are useful development evidence, but do not imply
an ARM64 registry release. CI tests and scans the AMD64 image before transferring
that exact artifact to a separate publication job. Pull requests have no registry
write token. Weekly runs test and scan without publishing; manual publication
requires `main` and an explicit `push_image` selection.

## Security status and maintenance

The collection's existing publication gate blocks fixable HIGH/CRITICAL findings.
It does **not** establish zero vulnerabilities: full reports and CycloneDX SBOMs
retain unfixed findings in workflow artifacts. No CVE ignore entries or analysis
exclusions are introduced for this image. [Security notes](security/README.md)
record the patch, scan evidence and remaining deployment gates.

Ghostscript remains Debian Trixie's security-backported 10.05.1 package. OCRmyPDF
warns that complex-script ligatures can lose ToUnicode mappings in PDF/A; the
German/English fixture passes, but other scripts need separate validation. Do not
mix Debian distributions to silence a version warning.

Review vendor fixes weekly, update this Dockerfile and hashed requirements in
source, rerun all tests and scans, and publish a new revision. Never patch a
running container. Retain the previous digest and application backup for rollback;
database migrations require a restore plan rather than assuming image downgrade
is safe.

## Consumer configuration

Use the registry digest from the successful workflow, a pre-owned writable data
directory and the upstream rootless mode:

```yaml
webserver:
  image: ghcr.io/bysamio/paperless-ngx@sha256:<verified-published-digest>
  user: "1000:1000" # substitute the owner of your application bind mounts
  cap_drop: [ALL]
  security_opt: ["no-new-privileges:true"]
```

This fragment is not a complete deployment. Use the reviewed home-server Compose
stack for PostgreSQL, Valkey, encrypted persistent mounts, loopback-only access,
resource limits, secrets and backups. Configure bundled `deu+eng`; installing extra
languages at startup needs root and is incompatible with this rootless contract.
Leave `USERMAP_UID`/`USERMAP_GID` out of the **container environment**; Compose may
use those names locally to substitute its `user` field. The application port and
volume paths remain upstream defaults.

## Chat retrieval correction in 3.3.2-r1

The upstream chat path retrieved permission-filtered nodes for citations, then
retrieved/embedded the same query again through `RetrieverQueryEngine.query`.
The derivative passes the first nodes directly to the installed response
synthesizer. Citations and generation now use the same nodes. Permission filters,
trash exclusion, templates, shared-lock lifetime and streaming remain intact.

The build refuses unknown upstream `chat.py` bytes and records original/patched
SHA256 values in `/usr/share/bysamio/ai-chat-fix.json`. The synthetic `make test-ai`
regression uses the real SQLite vector store, retriever and streaming synthesizer
with mock embeddings/generation in RAM. It checks ordinary visibility and
unrestricted trash exclusion, citation scope, streamed content and exactly one
query embedding. A larger synthetic context also checks that fitting evidence
needs one generation call, preserves both source facts and retains citations. It failed on the published r1 image with two embeddings and
passes on the local candidate with one. No family documents or model calls are
used. This local regression does not establish production UI latency or fix the
production classification context handling; native provider and UI validation
remain deployment gates.

## Complete prompt budgeting in 3.3.2-r1

The upstream classifier independently truncated document content and related
context before joining them, allowing the final request to exceed its context.
The derivative budgets the full rendered prompt, system text and JSON schema,
with 512 output tokens and 256 framing tokens reserved. It keeps taxonomy text
intact, prefers the primary document and trims related context first. Inputs
that cannot fit the fixed instructions fail before a provider request, without
private text in the error. Candidate ID validation and user permissions remain
upstream behavior. This budget is not an increase in the configured context.

For the existing local `qwen3:4b-instruct-2507-q4_K_M` model, classification and
chat synthesis use Qwen's matching public tokenizer instead of the library's
generic tokenizer. Other configured models keep the library tokenizer. The
[artifact record](security/qwen-tokenizer.json) pins the upstream revision,
SHA256, size and Apache-2.0 license. The build verifies both downloads; runtime
uses the bundled, root-owned data with the existing `tokenizers` package, no
network calls, weights or remote code. Build receipts for the classifier, chat
and prompt helper are at `/usr/share/bysamio/ai-context-fix.json`.

Synthetic classification regressions use the real templates/schema and token
counts at 4,096/8,192 tokens with long English, German and Chinese input. They
verify that the complete budget fits, primary evidence and taxonomy survive,
Unicode remains valid and impossible fixed overhead fails privately. The old
classifier fails these cases. Inverting the new budget condition and restoring
chat's duplicate retrieval both cause regression failures. These offline checks
do not establish the actual provider's token framing, answer quality or UI
latency; native validation remains necessary before deployment acceptance.

Chat generation now packs retrieved evidence against the available answer
context, with a 256-token framing reserve, rather than imposing the embedding
chunk size on each answer batch. The installed prompt helper still reserves
512 output tokens and counts the system/template text. Embedding chunks,
retrieval depth and the persistent index are unchanged. A real retrieval and
synthesis regression reproduced two sequential generation calls for evidence
that fits one prompt; the corrected candidate makes one call.

The candidate now uses official stable 3.3.2, including its document-version and
ownerless-classification permission fixes. Classification uses effective content
from the current document version. A disposable ORM regression checks ownerless
vector and full-text classification against private documents/taxonomy, including
stale retrieval results. The local patches do not alter these permission paths.
