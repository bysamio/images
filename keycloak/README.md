# BySamio Keycloak

A security-hardened Keycloak Docker image with near-zero vulnerabilities, built on a distroless base for maximum security in Kubernetes environments.

## Features

- **Near-zero CVEs**: Built on Google's distroless Java base image
- **Non-root execution**: Runs as UID 65532 (distroless nonroot user)
- **Read-only filesystem**: Supports `readOnlyRootFilesystem: true`
- **No shell**: Distroless has no shell to exploit (debug variant available)
- **Minimal capabilities**: Works with `capabilities.drop: ["ALL"]`
- **Kubernetes PSS compliant**: Compatible with restricted Pod Security Standards
- **Multi-architecture**: Supports linux/amd64 and linux/arm64

## Quick Start

### Docker Run

```bash
# Run with in-memory dev database
docker run -d \
  -p 8080:8080 \
  -p 9000:9000 \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin \
  -e KC_DB=dev-mem \
  ghcr.io/bysamio/keycloak:26.5.2

# Access admin console at http://localhost:8080/admin
```

### Docker Compose

```bash
# Run with PostgreSQL
docker compose up
```

### Kubernetes / Helm

See the [Helm Values](#helm-deployment) section below.

## Image Variants

| Tag | Description |
|-----|-------------|
| `26.5.2` | Production image (distroless, no shell) |
| `latest` | Latest stable version |
| `26.5.2-debug` | Debug variant with busybox shell |
| `debug` | Latest debug variant |

## Environment Variables

The image uses official Keycloak environment variables (`KC_*` prefix):

### Essential Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `KC_BOOTSTRAP_ADMIN_USERNAME` | Initial admin username | - |
| `KC_BOOTSTRAP_ADMIN_PASSWORD` | Initial admin password | - |
| `KC_DB` | Database vendor (postgres, mysql, mariadb, dev-mem) | postgres |
| `KC_DB_URL` | JDBC connection URL | - |
| `KC_DB_USERNAME` | Database username | - |
| `KC_DB_PASSWORD` | Database password | - |

### HTTP/Proxy Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `KC_HTTP_ENABLED` | Enable HTTP listener | true |
| `KC_HTTP_PORT` | HTTP port | 8080 |
| `KC_HTTPS_PORT` | HTTPS port | 8443 |
| `KC_HOSTNAME` | Public hostname | - |
| `KC_HOSTNAME_STRICT` | Disable dynamic hostname | false |
| `KC_PROXY_HEADERS` | Proxy header mode (xforwarded, forwarded) | xforwarded |

### Health & Metrics

| Variable | Description | Default |
|----------|-------------|---------|
| `KC_HEALTH_ENABLED` | Enable health endpoints | true |
| `KC_METRICS_ENABLED` | Enable Prometheus metrics | true |
| `KC_HTTP_MANAGEMENT_PORT` | Management port | 9000 |

### Logging

| Variable | Description | Default |
|----------|-------------|---------|
| `KC_LOG_LEVEL` | Log level (INFO, DEBUG, etc.) | INFO |
| `KC_LOG` | Log output format (console, json) | console |

For complete configuration options, see the [Keycloak Server Configuration](https://www.keycloak.org/server/all-config).

## Ports

| Port | Description |
|------|-------------|
| 8080 | HTTP |
| 8443 | HTTPS |
| 9000 | Management (health/metrics) |

## Health Endpoints

The image exposes health endpoints on port 9000:

```bash
# Readiness probe
curl http://localhost:9000/health/ready

# Liveness probe
curl http://localhost:9000/health/live

# Full health status
curl http://localhost:9000/health

# Prometheus metrics
curl http://localhost:9000/metrics
```

## Custom Themes and Providers

### Method 1: Volume Mounts (Recommended for Kubernetes)

Mount your themes/providers as volumes:

```yaml
# Kubernetes example
volumes:
  - name: custom-theme
    configMap:
      name: my-keycloak-theme

volumeMounts:
  - name: custom-theme
    mountPath: /opt/keycloak/themes/my-theme
    readOnly: true
```

Docker example:

```bash
docker run -d \
  -v ./my-theme:/opt/keycloak/themes/my-theme:ro \
  -v ./my-provider.jar:/opt/keycloak/providers/my-provider.jar:ro \
  ghcr.io/bysamio/keycloak:26.5.2
```

### Method 2: Init Container (For Dynamic Loading)

Use an init container to download themes at startup:

```yaml
initContainers:
  - name: theme-loader
    image: busybox:1.36
    command:
      - sh
      - -c
      - |
        wget -O /themes/my-theme.jar https://example.com/theme.jar
    volumeMounts:
      - name: themes
        mountPath: /themes

containers:
  - name: keycloak
    volumeMounts:
      - name: themes
        mountPath: /opt/keycloak/providers
```

### Method 3: Build Custom Image

For stable themes, extend the BySamio image:

```dockerfile
FROM ghcr.io/bysamio/keycloak:26.5.2

# Copy themes
COPY --chown=65532:65532 my-theme/ /opt/keycloak/themes/my-theme/

# Copy providers
COPY --chown=65532:65532 my-provider.jar /opt/keycloak/providers/
```

### Setting Default Theme

```bash
# Via environment variable
docker run -e KC_SPI_THEME_DEFAULT=my-theme ghcr.io/bysamio/keycloak:26.5.2
```

## Helm Deployment

The included `values.yaml` is designed for the BySamio Keycloak image:

```bash
# Using with a Keycloak Helm chart
helm install keycloak oci://ghcr.io/bysamio/charts/keycloak \
  -f values.yaml \
  --set image.registry=ghcr.io \
  --set image.repository=bysamio/keycloak \
  --set image.tag=26.5.2
```

### Key Helm Values

```yaml
image:
  registry: ghcr.io
  repository: bysamio/keycloak
  tag: "26.5.2"

# Security context (matches distroless nonroot user)
containerSecurityContext:
  enabled: true
  runAsUser: 65532
  runAsGroup: 65532
  runAsNonRoot: true
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL

# Custom themes
themes:
  enabled: true
  existingConfigMap: my-theme-configmap
  default: my-theme
```

## Security Context

The image is designed for Kubernetes restricted Pod Security Standards:

```yaml
securityContext:
  runAsUser: 65532
  runAsGroup: 65532
  runAsNonRoot: true
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  seccompProfile:
    type: RuntimeDefault
  capabilities:
    drop:
      - ALL
```

## Debug Variant

For troubleshooting, use the debug variant which includes a busybox shell:

```bash
# Run debug variant
docker run -it ghcr.io/bysamio/keycloak:26.5.2-debug

# Exec into running container
docker exec -it <container> /busybox/sh
```

## Building Locally

```bash
# Build production image
make build-local

# Build debug variant
make build-debug

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

Expected CVE count: **0-10** (distroless base with only JRE)

## Comparison with Other Images

| Image | Base | CVEs (typical) | Shell | Size |
|-------|------|----------------|-------|------|
| **BySamio** | Distroless | 0-10 | No | ~200MB |
| Official Keycloak | UBI | 50-200 | Yes | ~450MB |
| Bitnami Keycloak | Debian | 30-100 | Yes | ~400MB |

## License

This image is provided under the Apache 2.0 License, consistent with Keycloak's licensing.

## Links

- [BySamio Images Repository](https://github.com/bysamio/images)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Keycloak Server Configuration](https://www.keycloak.org/server/all-config)
- [Google Distroless](https://github.com/GoogleContainerTools/distroless)
