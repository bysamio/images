# BySam.io Paperless-ngx

A small derivative of Paperless-ngx 3.3.0 for the PostgreSQL-based home-server
archive. This image preserves upstream application code and fixes selected
dependencies. It is a release candidate with remaining unfixed vulnerabilities;
publication does not clear it for processing personal documents.

## Contract

- Preserve Paperless 3.3.0 application code, `/init`, health check and volume paths.
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
  The build context allowlist includes only the Dockerfile and patch requirements.
- Test real OCR, dependency checks and startup in disposable synthetic storage.
  Capture full image vulnerability evidence and gate publication before pushing.
- Publish reviewed versions to `ghcr.io/bysamio/paperless-ngx`. Version `3.3.0-r1`
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
