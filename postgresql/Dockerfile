# BySamio PostgreSQL - Security-Hardened Alpine Image
# Near-zero vulnerability PostgreSQL image based on official PostgreSQL Alpine
#
# Build: docker build -t ghcr.io/bysamio/postgresql:latest .
# Run:   docker run -p 5432:5432 -e POSTGRES_PASSWORD=secret ghcr.io/bysamio/postgresql:latest

ARG POSTGRESQL_VERSION=17.7

# =============================================================================
# Stage 1: Builder - Install security updates and prepare image
# =============================================================================
FROM postgres:${POSTGRESQL_VERSION}-alpine AS builder

# Install security updates and remove unnecessary packages
RUN apk update && \
    apk upgrade --no-cache && \
    # Remove unnecessary packages to reduce attack surface
    apk del --no-cache \
        fortify-headers \
        apk-tools 2>/dev/null || true && \
    # Clean up
    rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# =============================================================================
# Stage 2: Runtime - Hardened production image
# =============================================================================
FROM postgres:${POSTGRESQL_VERSION}-alpine AS runtime

LABEL org.opencontainers.image.title="BySamio PostgreSQL"
LABEL org.opencontainers.image.description="Security-hardened PostgreSQL image with near-zero vulnerabilities"
LABEL org.opencontainers.image.vendor="BySam.io"
LABEL org.opencontainers.image.source="https://github.com/bysamio/images"
LABEL org.opencontainers.image.licenses="PostgreSQL"
LABEL org.opencontainers.image.base.name="postgres:${POSTGRESQL_VERSION}-alpine"

# Apply security updates
RUN apk update && \
    apk upgrade --no-cache && \
    # Clean up package cache to reduce image size
    rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# Create bysamio user with UID 1001 (matching Helm chart expectations)
# The official postgres image uses UID 70, but Bitnami charts expect 1001
RUN deluser postgres 2>/dev/null || true && \
    addgroup -g 1001 -S postgres && \
    adduser -u 1001 -S -D -G postgres -H -h /var/lib/postgresql -s /bin/sh postgres && \
    # Ensure directories exist with correct permissions
    mkdir -p /var/lib/postgresql/data /var/run/postgresql /docker-entrypoint-initdb.d && \
    chown -R 1001:1001 /var/lib/postgresql /var/run/postgresql /docker-entrypoint-initdb.d && \
    chmod 700 /var/lib/postgresql/data && \
    chmod 775 /var/run/postgresql

# Copy custom entrypoint that wraps the official one
COPY --chmod=755 entrypoint.sh /usr/local/bin/bysamio-entrypoint.sh

# Environment variables
ENV PGDATA=/var/lib/postgresql/data \
    POSTGRES_INITDB_ARGS="--auth-host=scram-sha-256 --auth-local=scram-sha-256" \
    LANG=en_US.utf8

# Health check
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=5 \
    CMD pg_isready -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-postgres}" || exit 1

# Expose PostgreSQL port
EXPOSE 5432

# Set working directory
WORKDIR /var/lib/postgresql

# Run as non-root user (UID 1001)
USER 1001

# Use custom entrypoint
ENTRYPOINT ["/usr/local/bin/bysamio-entrypoint.sh"]
CMD ["postgres"]
