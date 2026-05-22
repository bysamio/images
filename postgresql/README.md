# BySamio PostgreSQL

A security-hardened PostgreSQL Docker image based on the official PostgreSQL Alpine image, optimized for Kubernetes environments with enhanced security features.

## Features

- **Minimal CVEs**: Based on Alpine Linux with security updates applied
- **Non-root execution**: Runs as UID 1001 (compatible with Kubernetes PSS)
- **No privilege drop helper**: The inherited `gosu` binary is removed; root startup is intentionally unsupported
- **Kubernetes ready**: Compatible with restricted Pod Security Standards
- **SCRAM-SHA-256**: Modern password authentication by default
- **Health checks**: Built-in health check support
- **Multi-architecture**: Supports linux/amd64 and linux/arm64

## Quick Start

### Docker Run

```bash
# Run with default settings
docker run -d \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=secretpassword \
  ghcr.io/bysamio/postgresql:17.10

# Connect with psql
psql -h localhost -U postgres -d postgres
```

### Docker Compose

```bash
# Run with docker-compose
docker-compose up -d
```

### Kubernetes / Helm

See the [Helm Values](#helm-deployment) section below.

## Image Variants

| Tag | Description |
|-----|-------------|
| `17.10` | PostgreSQL 17.10 on Alpine |
| `17.10-alpine` | PostgreSQL 17.10 on Alpine (explicit Alpine tag) |
| `latest` | Latest stable version (currently 17.10-alpine) |

All tags are based on Alpine Linux for minimal size and reduced attack surface.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `POSTGRES_PASSWORD` | Password for the postgres superuser | (required) |
| `POSTGRES_USER` | Username for the superuser | `postgres` |
| `POSTGRES_DB` | Default database name | `postgres` |
| `POSTGRES_INITDB_ARGS` | Arguments for initdb | `--auth-host=scram-sha-256` |
| `PGDATA` | Data directory location | `/var/lib/postgresql/pgdata` |

## Ports

| Port | Description |
|------|-------------|
| 5432 | PostgreSQL |

## Health Check

The image includes a built-in health check:

```bash
# Check if PostgreSQL is ready
pg_isready -U postgres -d postgres
```

## Custom Initialization

Mount SQL or shell scripts to `/docker-entrypoint-initdb.d/`:

```bash
docker run -d \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=secret \
  -v ./init-scripts:/docker-entrypoint-initdb.d:ro \
  ghcr.io/bysamio/postgresql:17.10
```

Scripts are executed in alphabetical order during first startup.

## Helm Deployment

```bash
# Using with a PostgreSQL Helm chart
helm install postgresql oci://ghcr.io/bysamio/charts/postgresql \
  -f values.yaml \
  --set image.registry=ghcr.io \
  --set image.repository=bysamio/postgresql \
  --set image.tag=17.10
```

### Key Helm Values

```yaml
image:
  registry: ghcr.io
  repository: bysamio/postgresql
  tag: "17.10"

# Security context (matches image UID/GID)
primary:
  containerSecurityContext:
    enabled: true
    runAsUser: 1001
    runAsGroup: 1001
    runAsNonRoot: true
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL

auth:
  postgresPassword: "your-secure-password"
  database: "myapp"
  username: "myuser"
  password: "user-password"
```

## Security Context

The image is designed for Kubernetes restricted Pod Security Standards:

```yaml
securityContext:
  runAsUser: 1001
  runAsGroup: 1001
  runAsNonRoot: true
  allowPrivilegeEscalation: false
  seccompProfile:
    type: RuntimeDefault
  capabilities:
    drop:
      - ALL
```

**Note**: PostgreSQL requires writable data, runtime socket, and temporary directories. The Helm chart mounts those paths separately, so `readOnlyRootFilesystem: true` is supported there; direct Docker runs need equivalent writable mounts when using `--read-only`.

### Rootless Runtime Contract

This image is designed to start directly as UID `1001`. It intentionally removes the upstream image's inherited `gosu` binary because the root-to-postgres privilege-drop path is not used by the Docker Compose or Helm chart configurations.

Running the container as root is unsupported and exits with an error. For Kubernetes volumes that need ownership repair, enable the Helm chart's `volumePermissions.enabled` init container or pre-provision the PVC with UID/GID `1001`.

## Building Locally

Make targets use Docker by default. To use Podman, prefix the target with `CONTAINER_ENGINE=podman`.

```bash
# Build production image
make build-local

# Run tests
make test

# Run vulnerability scan
make scan
```

## Vulnerability Scanning

The image is automatically scanned for vulnerabilities in CI/CD:

- **Build time**: Trivy scans for CRITICAL and HIGH CVEs
- **Results**: Uploaded to GitHub Security tab
- **SBOM**: Software Bill of Materials generated with each release

Expected CVE count: **5-15** (Alpine base with PostgreSQL)

## Comparison with Other Images

| Image | Base | CVEs (typical) | Size |
|-------|------|----------------|------|
| **BySamio** | Alpine | 5-15 | ~85MB |
| Official PostgreSQL | Debian | 50-150 | ~425MB |
| Bitnami PostgreSQL | Debian | 30-80 | ~350MB |

## Persistence

For production, always use persistent volumes:

```yaml
volumes:
  - name: postgres-data
    persistentVolumeClaim:
      claimName: postgres-pvc
```

## Replication

For replication setups, configure the standby server:

```bash
# Primary
docker run -d \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_REPLICATION_USER=repl_user \
  -e POSTGRES_REPLICATION_PASSWORD=repl_secret \
  ghcr.io/bysamio/postgresql:17.10

# Replica (using streaming replication)
# Configure via pg_basebackup and recovery.conf
```

## License

This image is provided under the PostgreSQL License, consistent with PostgreSQL's licensing.

## Links

- [BySamio Images Repository](https://github.com/bysamio/images)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Official PostgreSQL Docker Image](https://hub.docker.com/_/postgres)
