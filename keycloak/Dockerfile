# BySamio Keycloak - Security-Hardened Distroless Image
# Near-zero vulnerability Keycloak image based on official Keycloak with distroless runtime
#
# Build: docker build -t ghcr.io/bysamio/keycloak:latest .
# Run:   docker run -p 8080:8080 -e KC_BOOTSTRAP_ADMIN_USERNAME=admin -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin ghcr.io/bysamio/keycloak:latest

ARG KEYCLOAK_VERSION=26.5.2

# =============================================================================
# Stage 1: Builder - Build optimized Keycloak server
# =============================================================================
FROM keycloak/keycloak:${KEYCLOAK_VERSION} AS builder

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
# Stage 2: Runtime - Distroless production image
# =============================================================================
FROM gcr.io/distroless/java21-debian12:nonroot AS runtime

LABEL org.opencontainers.image.title="BySamio Keycloak"
LABEL org.opencontainers.image.description="Security-hardened Keycloak image with near-zero vulnerabilities"
LABEL org.opencontainers.image.vendor="BySam.io"
LABEL org.opencontainers.image.source="https://github.com/bysamio/images"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.base.name="gcr.io/distroless/java21-debian12:nonroot"

# Copy the built Keycloak server from builder stage
# Using --chown to set ownership to nonroot user (65532 in distroless)
COPY --from=builder --chown=65532:65532 /opt/keycloak /opt/keycloak

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
# Stage 3: Debug variant - For troubleshooting (optional build target)
# =============================================================================
FROM gcr.io/distroless/java21-debian12:debug-nonroot AS debug

LABEL org.opencontainers.image.title="BySamio Keycloak (Debug)"
LABEL org.opencontainers.image.description="Debug variant of BySamio Keycloak with shell access"
LABEL org.opencontainers.image.vendor="BySam.io"

COPY --from=builder --chown=65532:65532 /opt/keycloak /opt/keycloak

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
