# BySamio Keycloak

Security-hardened Keycloak Docker images for Kubernetes environments with runtime provider support.

## Image Variants

| Variant | Tag | Base | Use Case |
|---------|-----|------|----------|
| **Default** | `26.5.2`, `latest` | Alpine | Runtime provider/SPI loading, init containers |
| **Optimized** | `26.5.2-optimized`, `optimized` | Distroless | Maximum security, near-zero CVEs, fast startup |
| **Debug** | `26.5.2-debug`, `debug` | Distroless-debug | Troubleshooting with shell |

### Variant Comparison

| Feature | Default (Alpine) | Optimized (Distroless) |
|---------|------------------|------------------------|
| CVEs | 15-30 | 0-10 |
| Shell | Yes (bash) | No |
| Size | ~250MB | ~200MB |
| Startup | Auto-builds if needed | Fast (~5s, pre-built) |
| Runtime providers | Yes | No (build-time only) |
| Init containers | Full support | Themes only |
| Read-only FS | Partial | Yes |
| UID | 1001 | 65532 |

## Features

### Default Variant
- **Runtime provider loading**: Add SPIs via volume mounts or init containers
- **Auto-build**: Detects provider changes and rebuilds automatically
- **Init container support**: Download providers dynamically at startup
- **Full kc.sh access**: All Keycloak CLI commands available

### Optimized Variant
- **Near-zero CVEs**: Built on Google's distroless Java base image
- **No shell**: Maximum security - no shell to exploit
- **Read-only filesystem**: Full `readOnlyRootFilesystem: true` support
- **Fast startup**: Pre-built Quarkus for optimized startup (~5s)

### Both Variants
- **Non-root execution**: Default (1001), Optimized (65532)
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

## Available Tags

| Tag | Variant | Description |
|-----|---------|-------------|
| `26.5.2` | Default | Runtime provider support, auto-build (Alpine) |
| `latest` | Default | Latest stable version with provider support |
| `26.5.2-optimized` | Optimized | Pre-built, config locked, near-zero CVEs (Distroless) |
| `optimized` | Optimized | Latest optimized version |
| `26.5.2-debug` | Debug | Debug variant with busybox shell |
| `debug` | Debug | Latest debug variant |

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

### Understanding the Options

| Provider Type | Default Variant (runtime providers) | Optimized Variant (distroless) |
|---------------|-------------------------------------|--------------------------------|
| **Themes** (login, email) | Volume mount or init container | Volume mount (read-only) |
| **Custom SPIs** (Authenticators, User Storage, etc.) | Runtime via init container (auto-build) | Build-time only (bake into image) |

**Why the difference?** The optimized variant uses `--optimized` mode which compiles providers at build time for fast startup and a locked-down filesystem. The default variant can auto-build at startup when providers change.

### Supported Custom Providers (SPIs)

The default variant supports runtime loading of:
- **Authenticator SPI** - SMS OTP, custom MFA, CAPTCHA
- **User Storage SPI** - Legacy database integration
- **Password Policy SPI** - Breached password checks
- **Protocol Mapper SPI** - Custom token claims
- **Event Listener SPI** - Kafka/webhook integration
- **Theme SPI** - Branded login pages
- **Vault SPI** - External secrets manager

---

### Method 1: Default Variant with Init Container (Recommended for Dynamic Providers)

Use the **default variant** with init containers to dynamically load providers:

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      initContainers:
        # Download custom providers
        - name: provider-loader
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              echo "Downloading custom providers..."
              wget -O /providers/sms-authenticator.jar https://example.com/sms-authenticator.jar
              wget -O /providers/breached-password.jar https://example.com/breached-password.jar
              wget -O /providers/kafka-events.jar https://example.com/kafka-events.jar
              echo "Providers downloaded:"
              ls -la /providers/
          volumeMounts:
            - name: providers
              mountPath: /providers

      containers:
        - name: keycloak
          image: ghcr.io/bysamio/keycloak:26.5.2
          env:
            - name: KC_DB
              value: postgres
            - name: KC_FEATURES
              value: token-exchange,admin-fine-grained-authz
          volumeMounts:
            - name: providers
              mountPath: /opt/keycloak/providers
            - name: themes
              mountPath: /opt/keycloak/themes/my-theme
          securityContext:
            runAsUser: 1001
            runAsGroup: 1001
            runAsNonRoot: true

      volumes:
        - name: providers
          emptyDir: {}
        - name: themes
          configMap:
            name: my-keycloak-theme
```

Docker Compose example:

```yaml
services:
  keycloak:
    image: ghcr.io/bysamio/keycloak:26.5.2
    environment:
      KC_BOOTSTRAP_ADMIN_USERNAME: admin
      KC_BOOTSTRAP_ADMIN_PASSWORD: admin
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/keycloak
      KC_AUTO_BUILD: "true"
    volumes:
      - ./providers:/opt/keycloak/providers:ro
      - ./themes/my-theme:/opt/keycloak/themes/my-theme:ro
    user: "1001:1001"
```

### Method 2: Volume Mounts (Themes Only - Works with Both Variants)

For themes, simple volume mounts work with both variants:

```yaml
# Kubernetes
volumeMounts:
  - name: custom-theme
    mountPath: /opt/keycloak/themes/my-theme
    readOnly: true

volumes:
  - name: custom-theme
    configMap:
      name: my-keycloak-theme
```

```bash
# Docker
docker run -d \
  -v ./my-theme:/opt/keycloak/themes/my-theme:ro \
  ghcr.io/bysamio/keycloak:26.5.2
```

### Method 3: Build Custom Image (For Stable Providers)

If your providers rarely change, build them into the image:

```dockerfile
# For optimized (distroless, build-time providers)
FROM ghcr.io/bysamio/keycloak:26.5.2-optimized AS builder
# ... add providers to builder stage, then rebuild (providers are baked in)

# For default variant (runtime auto-build)
FROM ghcr.io/bysamio/keycloak:26.5.2

# Copy providers - will auto-build on first start (default variant only)
COPY --chown=1001:1001 my-provider.jar /opt/keycloak/providers/

# Copy themes
COPY --chown=1001:1001 my-theme/ /opt/keycloak/themes/my-theme/
```

### Default Variant Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `KC_AUTO_BUILD` | Auto-rebuild when providers change | `true` |
| `KC_CACHE_PROVIDERS` | Cache build state to avoid rebuilds | `true` |
| `KC_FEATURES` | Features to enable at build time | - |
| `KC_FEATURES_DISABLED` | Features to disable | - |

### Setting Default Theme

```bash
# Via environment variable (both variants)
docker run -e KC_SPI_THEME_DEFAULT=my-theme ghcr.io/bysamio/keycloak:26.5.2
```

## Helm Deployment

### Default Variant (Runtime Provider Support)

```bash
helm install keycloak oci://ghcr.io/bysamio/charts/keycloak \
  --set image.registry=ghcr.io \
  --set image.repository=bysamio/keycloak \
  --set image.tag=26.5.2
```

```yaml
image:
  registry: ghcr.io
  repository: bysamio/keycloak
  tag: "26.5.2"

# Security context for default variant (UID 1001)
containerSecurityContext:
  enabled: true
  runAsUser: 1001
  runAsGroup: 1001
  runAsNonRoot: true
  readOnlyRootFilesystem: false  # Needs to write for auto-build
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL

# Enable init container for custom providers
initContainers:
  - name: provider-loader
    image: busybox:1.36
    command: ["sh", "-c", "wget -O /providers/my-spi.jar https://..."]
    volumeMounts:
      - name: providers
        mountPath: /providers

extraVolumeMounts:
  - name: providers
    mountPath: /opt/keycloak/providers

extraVolumes:
  - name: providers
    emptyDir: {}
```

### Optimized Variant (Maximum Security)

```bash
helm install keycloak oci://ghcr.io/bysamio/charts/keycloak \
  --set image.registry=ghcr.io \
  --set image.repository=bysamio/keycloak \
  --set image.tag=26.5.2-optimized \
  --set containerSecurityContext.runAsUser=65532
```

```yaml
image:
  registry: ghcr.io
  repository: bysamio/keycloak
  tag: "26.5.2-optimized"

# Security context for optimized/distroless (UID 65532)
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
```

## Security Context

### Default Variant (Alpine)

```yaml
securityContext:
  runAsUser: 1001
  runAsGroup: 1001
  runAsNonRoot: true
  readOnlyRootFilesystem: false  # Required for auto-build
  allowPrivilegeEscalation: false
  seccompProfile:
    type: RuntimeDefault
  capabilities:
    drop:
      - ALL
```

**Note**: The default variant needs write access to `/opt/keycloak/data` for caching build state. Use `emptyDir` or persistent volume for this path in production.

### Optimized Variant (Distroless)

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
# Build default (Alpine) variant
make build-local

# Build optimized (Distroless) variant
make build-optimized

# Build debug variant
make build-debug

# Build all variants
make build-all

# Run tests
make test

# Run vulnerability scan
make scan
```

### Docker Build Targets

```bash
# Default variant (runtime provider support)
docker build --target default -t keycloak:latest .

# Optimized variant (distroless, pre-built)
docker build --target optimized -t keycloak:optimized .

# Debug variant
docker build --target debug -t keycloak:debug .
```

## Vulnerability Scanning

The image is automatically scanned for vulnerabilities in CI/CD:

- **Build time**: Trivy scans for CRITICAL and HIGH CVEs
- **Results**: Uploaded to GitHub Security tab
- **SBOM**: Software Bill of Materials generated with each release

Expected CVE count: **0-10** (distroless base with only JRE)

## Comparison with Other Images

| Image | Base | CVEs | Shell | Runtime Providers | Size |
|-------|------|------|-------|-------------------|------|
| **BySamio Default** | Alpine | 15-30 | Yes | Yes | ~250MB |
| **BySamio Optimized** | Distroless | 0-10 | No | No | ~200MB |
| Official Keycloak | UBI | 50-200 | Yes | Yes | ~450MB |
| Bitnami Keycloak | Debian | 30-100 | Yes | Yes | ~400MB |

### When to Use Each Variant

| Scenario | Recommended Variant |
|----------|---------------------|
| Custom SPIs (authenticators, user storage, etc.) | Default |
| Dynamic provider loading via init containers | Default |
| Most production deployments | Default |
| Maximum security, no custom SPIs | Optimized |
| Custom themes only (no SPI JARs) | Optimized |
| Debugging production issues | Debug |

## License

This image is provided under the Apache 2.0 License, consistent with Keycloak's licensing.

## Links

- [BySamio Images Repository](https://github.com/bysamio/images)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Keycloak Server Configuration](https://www.keycloak.org/server/all-config)
- [Google Distroless](https://github.com/GoogleContainerTools/distroless)
