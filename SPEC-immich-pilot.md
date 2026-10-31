# Immich pilot images

Approved scope: the home-server operator authorized the recommended image,
verification, publication and staged deployment sequence on 2026-10-31.

| Module | Contract | Depends on |
|---|---|---|
| postgresql-immich | Dedicated PostgreSQL 17.11, pgvector 0.8.7, VectorChord 1.1.1, cube and earthdistance; UID/GID 1001; PGDATA /var/lib/postgresql/pgdata | official PostgreSQL |
| immich | Preserve upstream 3.3.5 application/mobile protocol, assets and media tooling; rebuild Node server/CLI with reviewed security dependency pins; update native Brotli | upstream Immich |
| publication | Native amd64 runtime tests and full findings/SBOM before registry login; publish the same tested artifact under a unique tag | both images |

Build order: PostgreSQL extension proof, patched Immich, combined empty-data
integration, review, publication, home-server digest pins and deployment.

## Commands and layout

Each image lives in its own directory with Dockerfile, Makefile, README and test/.
Run `make -C postgresql-immich build-local test scan` and
`make -C immich build-local test scan`; use `CONTAINER_ENGINE=podman` locally.
Tests use disposable containers, networks and volumes, never production data.
Shell uses `set -eu`, quoted arguments and cleanup traps; Python uses the standard
library. Upstream archives and base images are pinned by SHA256.

## Acceptance and boundaries

- PostgreSQL initializes as 1001 with all capabilities dropped, rejects root,
  creates the required extensions, builds/queries a vector index, persists across
  restart, and restores a logical backup into a fresh database.
- Immich starts and migrates against the new database, serves the versioned API,
  accepts a sample photo, retains its checksum and produces a thumbnail. Its
  patched body parser, WebSocket parser and mailer are exercised in runtime tests.
- Preserve the authoritative pnpm version and frozen lock; disable install
  scripts first and permit only reviewed native build scripts. Record the native
  audit and full scan. Fixable HIGH/CRITICAL findings block publication, matching
  the existing Paperless workflow; no new blanket ignores.
- No production secrets in source or CI. No change to generic PostgreSQL or
  Paperless consumers. No server activation before exact artifact verification.
- Initial deployment uses the existing 16 GB server, bounded concurrency and no
  ML service. Preserve original photos and the installed secret. Deployment needs
  a rollback checkpoint and a small pilot before bulk import.

If Alpine cannot build/load both extensions reliably against its exact server,
use a separately documented Debian variant. Do not copy glibc binaries into musl.
Remove security overlays when a tested upstream release includes the fixes.
