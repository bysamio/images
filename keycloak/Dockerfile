# BySamio Keycloak - Security-Hardened Images
# Provides multiple variants for different use cases:
#   - default (alpine): Runtime provider/SPI loading, init container support
#   - optimized (distroless): Maximum security, near-zero CVEs, fast startup
#   - debug (distroless-debug): Troubleshooting with shell access
#
# Build variants:
#   docker build --target default -t ghcr.io/bysamio/keycloak:26.7.3 .
#   docker build --target optimized -t ghcr.io/bysamio/keycloak:26.7.3-optimized .
#
# Run:
#   docker run -p 8080:8080 -e KC_BOOTSTRAP_ADMIN_USERNAME=admin -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin ghcr.io/bysamio/keycloak:latest

ARG KEYCLOAK_VERSION=26.7.3
ARG OTEL_PATCH_VERSION=1.62.0
ARG KEYCLOAK_OTEL_VERSION=1.57.0
ARG OTEL_INCUBATOR_PATCH_VERSION=1.62.0-alpha
ARG KEYCLOAK_OTEL_INCUBATOR_VERSION=1.57.0-alpha
ARG NETTY_PATCH_VERSION=4.1.138.Final
ARG KEYCLOAK_NETTY_VERSION=4.1.136.Final

# =============================================================================
# Stage 1: Dependency Patches - Backport fixed JARs until upstream catches up
# =============================================================================
FROM alpine:3.22 AS dependency-patches

ARG OTEL_PATCH_VERSION
ARG KEYCLOAK_OTEL_VERSION
ARG OTEL_INCUBATOR_PATCH_VERSION
ARG KEYCLOAK_OTEL_INCUBATOR_VERSION
ARG NETTY_PATCH_VERSION
ARG KEYCLOAK_NETTY_VERSION

RUN apk add --no-cache ca-certificates curl

WORKDIR /patches

# Keycloak 26.7.3 ships OpenTelemetry 1.57.0, which upstream has not yet
# advanced. Keep the original filenames to preserve Keycloak's generated
# classpath, while replacing contents with 1.62.0 to fix CVE-2026-45292
# (unbounded memory allocation in W3C Baggage Propagation).
RUN set -eux; \
    for artifact in \
        opentelemetry-api \
        opentelemetry-common \
        opentelemetry-context \
        opentelemetry-sdk \
        opentelemetry-sdk-common \
        opentelemetry-sdk-logs \
        opentelemetry-sdk-metrics \
        opentelemetry-sdk-trace \
        opentelemetry-exporter-common \
        opentelemetry-exporter-otlp \
        opentelemetry-exporter-otlp-common \
        opentelemetry-sdk-extension-autoconfigure \
        opentelemetry-sdk-extension-autoconfigure-spi; do \
        base_url="https://repo1.maven.org/maven2/io/opentelemetry/${artifact}/${OTEL_PATCH_VERSION}"; \
        patched_name="io.opentelemetry.${artifact}-${KEYCLOAK_OTEL_VERSION}.jar"; \
        curl -fsSLo "${patched_name}" "${base_url}/${artifact}-${OTEL_PATCH_VERSION}.jar"; \
        curl -fsSLo "${patched_name}.sha512" "${base_url}/${artifact}-${OTEL_PATCH_VERSION}.jar.sha512"; \
        echo "$(cat "${patched_name}.sha512")  ${patched_name}" | sha512sum -c -; \
        rm "${patched_name}.sha512"; \
    done

# Patch opentelemetry-api-incubator (alpha variant, separate Maven group path)
RUN set -eux; \
    base_url="https://repo1.maven.org/maven2/io/opentelemetry/opentelemetry-api-incubator/${OTEL_INCUBATOR_PATCH_VERSION}"; \
    patched_name="io.opentelemetry.opentelemetry-api-incubator-${KEYCLOAK_OTEL_INCUBATOR_VERSION}.jar"; \
    curl -fsSLo "${patched_name}" "${base_url}/opentelemetry-api-incubator-${OTEL_INCUBATOR_PATCH_VERSION}.jar"; \
    curl -fsSLo "${patched_name}.sha512" "${base_url}/opentelemetry-api-incubator-${OTEL_INCUBATOR_PATCH_VERSION}.jar.sha512"; \
    echo "$(cat "${patched_name}.sha512")  ${patched_name}" | sha512sum -c -; \
    rm "${patched_name}.sha512"

# Keycloak 26.7.3 ships Netty 4.1.136.Final, which carries CVE-2026-75595
# (CRITICAL) in netty-handler, along with CVE-2026-75596 and CVE-2026-49844 in
# the same module and CVE-2026-59903 (information disclosure via CORS Vary
# header overwrite) in netty-codec-http. Upstream fixes them in 4.1.137.Final;
# 26.7.3 is the newest Keycloak release, so there is no version to bump to.
#
# Every Netty module is replaced, not just netty-handler: they share internal
# APIs and are only supported in lockstep, so a mixed 4.1.136/4.1.138 classpath
# is not a configuration upstream tests. Filenames keep the 4.1.136.Final
# version so Keycloak's generated classpath still resolves.
#
# Revisit when a Keycloak release ships 4.1.137.Final or newer, at which point
# this whole block should be deleted rather than re-pinned — see the Jackson and
# pgJDBC overlays removed in the 26.7.3 bump for why a stale overlay is worse
# than none.
RUN set -eux; \
    for artifact in \
        netty-buffer \
        netty-codec \
        netty-codec-dns \
        netty-codec-haproxy \
        netty-codec-http \
        netty-codec-http2 \
        netty-codec-socks \
        netty-common \
        netty-handler \
        netty-handler-proxy \
        netty-resolver \
        netty-resolver-dns \
        netty-transport \
        netty-transport-classes-epoll \
        netty-transport-native-unix-common; do \
        base_url="https://repo1.maven.org/maven2/io/netty/${artifact}/${NETTY_PATCH_VERSION}"; \
        patched_name="io.netty.${artifact}-${KEYCLOAK_NETTY_VERSION}.jar"; \
        curl -fsSLo "${patched_name}" "${base_url}/${artifact}-${NETTY_PATCH_VERSION}.jar"; \
        curl -fsSLo "${patched_name}.sha512" "${base_url}/${artifact}-${NETTY_PATCH_VERSION}.jar.sha512"; \
        echo "$(cat "${patched_name}.sha512")  ${patched_name}" | sha512sum -c -; \
        rm "${patched_name}.sha512"; \
    done

# The native epoll transport ships one JAR per platform classifier, and Keycloak
# bundles both so a single image runs on amd64 and arm64.
RUN set -eux; \
    base_url="https://repo1.maven.org/maven2/io/netty/netty-transport-native-epoll/${NETTY_PATCH_VERSION}"; \
    for classifier in linux-aarch_64 linux-x86_64; do \
        upstream="netty-transport-native-epoll-${NETTY_PATCH_VERSION}-${classifier}.jar"; \
        patched_name="io.netty.netty-transport-native-epoll-${KEYCLOAK_NETTY_VERSION}-${classifier}.jar"; \
        curl -fsSLo "${patched_name}" "${base_url}/${upstream}"; \
        curl -fsSLo "${patched_name}.sha512" "${base_url}/${upstream}.sha512"; \
        echo "$(cat "${patched_name}.sha512")  ${patched_name}" | sha512sum -c -; \
        rm "${patched_name}.sha512"; \
    done

# =============================================================================
# Stage 2: Keycloak Patched Base - Official distribution with patched deps
# =============================================================================
FROM quay.io/keycloak/keycloak:${KEYCLOAK_VERSION} AS keycloak-patched

COPY --from=dependency-patches /patches/*.jar /opt/keycloak/lib/lib/main/

# =============================================================================
# Stage 3: Optimized Builder - Build optimized Keycloak (for distroless variant)
# =============================================================================
FROM keycloak-patched AS optimized-builder

# Set build-time configuration
ENV KC_HEALTH_ENABLED=true \
    KC_METRICS_ENABLED=true \
    KC_FEATURES=token-exchange,admin-fine-grained-authz \
    KC_DB=postgres

WORKDIR /opt/keycloak

# Build the optimized server
# This pre-compiles Quarkus for faster startup and includes only needed features
RUN /opt/keycloak/bin/kc.sh build \
    --health-enabled=true \
    --metrics-enabled=true \
    --features=token-exchange,admin-fine-grained-authz \
    --db=postgres

# =============================================================================
# Stage 4: Optimized - Distroless production image (use tag: 26.7.3-optimized)
# =============================================================================
FROM gcr.io/distroless/java21-debian13:nonroot AS optimized

LABEL org.opencontainers.image.title="BySamio Keycloak (Optimized)"
LABEL org.opencontainers.image.description="Optimized Keycloak with near-zero CVEs, config locked at build time"
LABEL org.opencontainers.image.vendor="BySam.io"
LABEL org.opencontainers.image.source="https://github.com/bysamio/images"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.base.name="gcr.io/distroless/java21-debian13:nonroot"

# Copy the built Keycloak server from optimized-builder stage
# Using --chown to set ownership to nonroot user (65532 in distroless)
COPY --from=optimized-builder --chown=65532:65532 /opt/keycloak /opt/keycloak

WORKDIR /opt/keycloak

# Environment variables for runtime configuration
# These can be overridden at runtime
ENV KC_HTTP_PORT=8080 \
    KC_HTTPS_PORT=8443 \
    KC_HTTP_MANAGEMENT_PORT=9000 \
    KC_HEALTH_ENABLED=true \
    KC_METRICS_ENABLED=true \
    KC_HTTP_ENABLED=true \
    KC_HOSTNAME_STRICT=false \
    KC_PROXY_HEADERS=xforwarded \
    JAVA_OPTS_APPEND="-Djava.awt.headless=true"

# Expose ports
# 8080 - HTTP
# 8443 - HTTPS
# 9000 - Management (health/metrics)
EXPOSE 8080 8443 9000

# Run as non-root user (65532 is the nonroot user in distroless)
USER 65532

# Entrypoint using Java directly (distroless has no shell)
# The optimized server uses the Quarkus runner with Keycloak's main class
ENTRYPOINT [ \
    "java", \
    "-Djava.util.logging.manager=org.jboss.logmanager.LogManager", \
    "-Dquarkus.http.host=0.0.0.0", \
    "-Djava.awt.headless=true", \
    "-Dkc.home.dir=/opt/keycloak", \
    "-Djboss.server.config.dir=/opt/keycloak/conf", \
    "-Dkeycloak.theme.dir=/opt/keycloak/themes", \
    "--add-opens=java.base/java.util=ALL-UNNAMED", \
    "--add-opens=java.base/java.util.concurrent=ALL-UNNAMED", \
    "--add-opens=java.base/java.security=ALL-UNNAMED", \
    "-jar", "/opt/keycloak/lib/quarkus-run.jar" \
]

# Default command: start in optimized mode
CMD ["start", "--optimized"]

# =============================================================================
# Stage 5: Debug variant - For troubleshooting (use tag: 26.7.3-debug)
# =============================================================================
FROM gcr.io/distroless/java21-debian13:debug-nonroot AS debug

LABEL org.opencontainers.image.title="BySamio Keycloak (Debug)"
LABEL org.opencontainers.image.description="Debug variant with shell access for troubleshooting"
LABEL org.opencontainers.image.vendor="BySam.io"

COPY --from=optimized-builder --chown=65532:65532 /opt/keycloak /opt/keycloak

WORKDIR /opt/keycloak

ENV KC_HTTP_PORT=8080 \
    KC_HTTPS_PORT=8443 \
    KC_HTTP_MANAGEMENT_PORT=9000 \
    KC_HEALTH_ENABLED=true \
    KC_METRICS_ENABLED=true \
    KC_HTTP_ENABLED=true \
    KC_HOSTNAME_STRICT=false \
    KC_PROXY_HEADERS=xforwarded \
    JAVA_OPTS_APPEND="-Djava.awt.headless=true"

EXPOSE 8080 8443 9000

USER 65532

ENTRYPOINT [ \
    "java", \
    "-Djava.util.logging.manager=org.jboss.logmanager.LogManager", \
    "-Dquarkus.http.host=0.0.0.0", \
    "-Djava.awt.headless=true", \
    "-Dkc.home.dir=/opt/keycloak", \
    "-Djboss.server.config.dir=/opt/keycloak/conf", \
    "-Dkeycloak.theme.dir=/opt/keycloak/themes", \
    "--add-opens=java.base/java.util=ALL-UNNAMED", \
    "--add-opens=java.base/java.util.concurrent=ALL-UNNAMED", \
    "--add-opens=java.base/java.security=ALL-UNNAMED", \
    "-jar", "/opt/keycloak/lib/quarkus-run.jar" \
]

CMD ["start", "--optimized"]

# =============================================================================
# Stage 6: Default - Runtime provider loading support (use tag: 26.7.3, latest)
# =============================================================================
# This is the DEFAULT variant - supports runtime customization:
# - Runtime provider/SPI loading via volume mounts
# - Init containers to dynamically add providers (SMS OTP, custom auth, etc.)
# - Auto-build on startup when providers are detected
# - Non-root execution (UID 1001)
#
# Trade-offs vs optimized variant:
# - Slightly larger image (~250MB vs ~200MB)
# - More CVEs (Alpine vs distroless, but still minimal)
# - Slower first startup (needs to build, then cached)
# - Has shell (required for kc.sh and auto-build)
# =============================================================================
FROM keycloak-patched AS builder

# Don't build yet - we want the full distribution for runtime flexibility
WORKDIR /opt/keycloak

# =============================================================================
FROM eclipse-temurin:21-jre-alpine AS default

LABEL org.opencontainers.image.title="BySamio Keycloak"
LABEL org.opencontainers.image.description="Keycloak with runtime provider support and auto-build"
LABEL org.opencontainers.image.vendor="BySam.io"
LABEL org.opencontainers.image.source="https://github.com/bysamio/images"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.base.name="eclipse-temurin:21-jre-alpine"

# Install minimal required packages and apply security updates
RUN apk update && \
    apk upgrade --no-cache && \
    apk add --no-cache bash tini && \
    rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# Create keycloak user with UID 1001 (matches Helm chart expectations)
RUN addgroup -g 1001 -S keycloak && \
    adduser -u 1001 -S -D -G keycloak -H -h /opt/keycloak -s /bin/bash keycloak

# Copy Keycloak distribution from official image
COPY --from=builder --chown=1001:1001 /opt/keycloak /opt/keycloak

# Copy custom entrypoint script
COPY --chmod=755 entrypoint-flexible.sh /opt/keycloak/bin/bysamio-entrypoint.sh

# Create directories for providers and themes (can be mounted as volumes)
RUN mkdir -p /opt/keycloak/providers \
             /opt/keycloak/themes \
             /opt/keycloak/data \
             /opt/keycloak/conf && \
    chown -R 1001:1001 /opt/keycloak

WORKDIR /opt/keycloak

# Environment variables
ENV KC_HOME=/opt/keycloak \
    KC_HTTP_PORT=8080 \
    KC_HTTPS_PORT=8443 \
    KC_HTTP_MANAGEMENT_PORT=9000 \
    KC_HEALTH_ENABLED=true \
    KC_METRICS_ENABLED=true \
    KC_HTTP_ENABLED=true \
    KC_HOSTNAME_STRICT=false \
    KC_PROXY_HEADERS=xforwarded \
    KC_DB=postgres \
    # Auto-build settings
    KC_AUTO_BUILD=true \
    KC_CACHE_PROVIDERS=true \
    JAVA_OPTS_APPEND="-Djava.awt.headless=true"

# Expose ports
EXPOSE 8080 8443 9000

# Run as non-root user
USER 1001

# Use tini as init system for proper signal handling
ENTRYPOINT ["/sbin/tini", "--", "/opt/keycloak/bin/bysamio-entrypoint.sh"]

# Default: start with auto-build support
CMD ["start"]
