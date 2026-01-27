# BySamio PostgreSQL

A security-hardened PostgreSQL Docker image based on the official PostgreSQL Alpine image, optimized for Kubernetes environments with enhanced security features.

## Features

- **Minimal CVEs**: Based on Alpine Linux with security updates applied
- **Non-root execution**: Runs as UID 1001 (compatible with Kubernetes PSS)
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
  ghcr.io/bysamio/postgresql:17.7

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
| `17.7` | PostgreSQL 17.7 on Alpine (latest) |
| `latest` | Latest stable version |

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `POSTGRES_PASSWORD` | Password for the postgres superuser | (required) |
| `POSTGRES_USER` | Username for the superuser | `postgres` |
| `POSTGRES_DB` | Default database name | `postgres` |
| `POSTGRES_INITDB_ARGS` | Arguments for initdb | `--auth-host=scram-sha-256` |
| `PGDATA` | Data directory location | `/var/lib/postgresql/data` |

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
  ghcr.io/bysamio/postgresql:17.7
```

Scripts are executed in alphabetical order during first startup.

## Helm Deployment

```bash
# Using with a PostgreSQL Helm chart
helm install postgresql oci://ghcr.io/bysamio/charts/postgresql \
  -f values.yaml \
  --set image.registry=ghcr.io \
  --set image.repository=bysamio/postgresql \
  --set image.tag=17.7
```

### Key Helm Values

```yaml
image:
  registry: ghcr.io
  repository: bysamio/postgresql
  tag: "17.7"

# Security context (matches image UID/GID)
primary:
  containerSecurityContext:
    enabled: true
    runAsUser: 1001
    runAsGroup: 1001
    runAsNonRoot: true
    readOnlyRootFilesystem: false  # PostgreSQL needs to write
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

**Note**: PostgreSQL requires a writable data directory, so `readOnlyRootFilesystem` cannot be enabled without additional volume mounts.

## Building Locally

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
  ghcr.io/bysamio/postgresql:17.7

# Replica (using streaming replication)
# Configure via pg_basebackup and recovery.conf
```

## License

This image is provided under the PostgreSQL License, consistent with PostgreSQL's licensing.

## Links

- [BySamio Images Repository](https://github.com/bysamio/images)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Official PostgreSQL Docker Image](https://hub.docker.com/_/postgres)
