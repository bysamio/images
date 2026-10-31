ARG POSTGRES_BASE=postgres:17.11-alpine@sha256:266d3c257594e195b309ae9d1805e54c788f1d7b375f56bf6c367aac6c917e7b
FROM ${POSTGRES_BASE} AS extensions
USER root
# Compile against THIS server's pg_config and musl, never Debian extension .so files.
RUN apk upgrade --no-cache && apk add --no-cache \
    build-base clang21 clang21-dev llvm21-dev rust cargo rustfmt linux-headers openssl-dev
WORKDIR /build
ADD https://codeload.github.com/pgvector/pgvector/tar.gz/refs/tags/v0.8.7 /build/pgvector.tar.gz
ADD https://codeload.github.com/supervc-stack/VectorChord/tar.gz/refs/tags/1.1.1 /build/vchord.tar.gz
RUN echo 'cac0b10c360f05b2d521200105ba3697e773d4cd3731f5a915a7e37ebe0bea85  pgvector.tar.gz' | sha256sum -c - && \
    echo 'd70b5595bfc852f1f24c05c0a40272e7deecbb0ddf8ffdddec5afa42c2392b1e  vchord.tar.gz' | sha256sum -c - && \
    tar -xzf pgvector.tar.gz && tar -xzf vchord.tar.gz
RUN make -C pgvector-0.8.7 OPTFLAGS='' -j2 && \
    make -C pgvector-0.8.7 install DESTDIR=/extensions
WORKDIR /build/VectorChord-1.1.1
ENV PG_CONFIG=/usr/local/bin/pg_config \
    CC=clang-21 \
    CARGO_BUILD_JOBS=2
# xtask invokes cargo internally. Verify that its offline build preserves the lock.
RUN cargo fetch --locked && sha256sum Cargo.lock > /tmp/cargo-lock.sha256 && \
    CARGO_NET_OFFLINE=true make build && sha256sum -c /tmp/cargo-lock.sha256 && \
    make install DESTDIR=/extensions

FROM ${POSTGRES_BASE} AS runtime
USER root
LABEL org.opencontainers.image.title="BySamio PostgreSQL for Immich" \
    org.opencontainers.image.source="https://github.com/bysamio/images" \
    org.opencontainers.image.version="17.11-vchord1.1.1-vector0.8.7-r1" \
    org.opencontainers.image.licenses="PostgreSQL AND Apache-2.0 AND AGPL-3.0-only"
RUN apk upgrade --no-cache && apk add --no-cache libgcc libstdc++ && \
    rm -f /usr/local/bin/gosu && \
    deluser postgres && addgroup -g 1001 -S postgres && \
    adduser -u 1001 -S -D -G postgres -H -h /var/lib/postgresql -s /bin/sh postgres && \
    mkdir -p /var/lib/postgresql/pgdata /var/run/postgresql /docker-entrypoint-initdb.d && \
    chown -R 1001:1001 /var/lib/postgresql /var/run/postgresql /docker-entrypoint-initdb.d && \
    chmod 700 /var/lib/postgresql/pgdata && chmod 775 /var/run/postgresql
COPY --from=extensions /extensions/ /
COPY --chmod=755 entrypoint.sh /usr/local/bin/bysamio-entrypoint.sh
ENV PGDATA=/var/lib/postgresql/pgdata \
    POSTGRES_INITDB_ARGS="--auth-host=scram-sha-256 --auth-local=scram-sha-256"
WORKDIR /var/lib/postgresql
USER 1001:1001
ENTRYPOINT ["/usr/local/bin/bysamio-entrypoint.sh"]
CMD ["postgres", "-c", "shared_preload_libraries=vchord.so"]
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=5 \
    CMD pg_isready -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-postgres}"
