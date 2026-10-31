# PostgreSQL for Immich

Dedicated PostgreSQL **17.11 / VectorChord 1.1.1 / pgvector 0.8.7** image for
the private home-server photo pilot. This does not replace `bysamio/postgresql`
or change Paperless. PostgreSQL 17 has support through 2029; the pilot has no
existing database to migrate from PostgreSQL 14.

The official 17.11 Alpine base is pinned by digest. Both extensions are compiled
from SHA256-verified upstream archives against that base's `/usr/local/bin/pg_config`.
No glibc extension binaries are copied into musl. Cargo fetch uses the upstream
lockfile and compilation runs offline. Rebuilds apply Alpine security updates.

## Runtime contract

- UID/GID **1001:1001**, root startup rejected, all capabilities can be dropped.
- Mount data at **`/var/lib/postgresql/pgdata`**, not the inherited `/data` volume.
  Provision host directories as 1001:1001 before startup. Never chown an existing
  PostgreSQL 14 cluster and attempt to start PostgreSQL 17 on it.
- Default command preloads `vchord.so`; overriding the command must preserve this.
- Set `POSTGRES_PASSWORD` privately and `POSTGRES_DB=immich`. Initialization uses
  SCRAM for local and TCP authentication. No published database port is needed.
- The image supplies `vector`, `vchord`, `cube` and `earthdistance`. Immich creates
  the extensions in its dedicated database during migration. It is the only DB
  consumer; PostgreSQL superuser access supports Immich's built-in `pg_dumpall`.
- Persist data, keep backups outside that data directory, and keep `/tmp` and
  `/var/run/postgresql` writable. These paths can be tmpfs with UID/GID 1001.

## Verification and publication

```sh
make build-local
make test
make scan
# Or: make CONTAINER_ENGINE=podman build-local test
```

Tests initialize a disposable volume under restricted privileges, load all
extensions, build/query a VectorChord index, restart with persistent data and
restore a logical dump into a fresh database. No production credentials/data are
used. Native linux/amd64 CI tests and scans the exact image before publication.
Full findings and CycloneDX SBOM are retained; fixable HIGH/CRITICAL findings
block publishing, with no added ignores. A unique run/attempt tag is published;
consumers must pin its registry digest. Weekly verification does not publish.

For a fresh failed pilot stop the application and retain its volume and logs.
After accepting photo uploads, rollback must restore a matched database and
media backup; a PostgreSQL major-version downgrade is not a volume rollback.

Sources: [Immich database requirements](https://docs.immich.app/administration/postgres-standalone/),
[VectorChord installation](https://docs.vectorchord.ai/vectorchord/getting-started/installation.html),
[pgvector build instructions](https://github.com/pgvector/pgvector),
[PostgreSQL version policy](https://www.postgresql.org/support/versioning/).
