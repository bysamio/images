# Retain upstream web/CLI interface, media tools and plugins; rebuild Node code
# from the exact release source with the committed pnpm security patch.
FROM ghcr.io/immich-app/base-server-dev:202610211607@sha256:f99c605b44b291834cb680b80fd606f2b7c4bee5d8f9591bfdac51fdbd68c21d AS builder
ENV CI=1 PNPM_HOME=/opt/pnpm PATH="/opt/pnpm/bin:$PATH"
ADD https://registry.npmjs.org/pnpm/-/pnpm-11.27.1.tgz /tmp/pnpm.tgz
RUN echo 'a81d4c21b9b09a4b0aebf90ef5e527d4262bdda322d26082978cb549023ac6d9cafc98b19fffaa5c71db438a65f70224edb78d7311187861ff96480d1cdca23c  /tmp/pnpm.tgz' | sha512sum -c - && \
    mkdir -p /opt/pnpm && tar -xzf /tmp/pnpm.tgz --strip-components=1 -C /opt/pnpm && \
    chmod 755 /opt/pnpm/bin/pnpm.cjs && \
    ln -s pnpm.cjs /opt/pnpm/bin/pnpm
ADD https://codeload.github.com/immich-app/immich/tar.gz/8303cb117e197c700332b33b61b45314c9cc5bb4 /tmp/source.tar.gz
RUN echo '9f5abc150129033e42adf7cc881c08b557c891d13142ce116c801be807f7572d  /tmp/source.tar.gz' | sha256sum -c - && \
    mkdir -p /usr/src/app && tar -xzf /tmp/source.tar.gz --strip-components=1 -C /usr/src/app
WORKDIR /usr/src/app
COPY patches/dependencies.patch /tmp/dependencies.patch
COPY patches/nestjs-zod-5.5.0.patch /usr/src/app/patches/nestjs-zod@5.5.0.patch
RUN patch -p1 < /tmp/dependencies.patch && \
    pnpm --filter immich... --filter @immich/cli... install --frozen-lockfile --ignore-scripts
# The source policy allows only bcrypt/sharp native builds for these packages.
# Keep scripts disabled during initial resolution; the two builds are explicit.
RUN pnpm --filter immich rebuild bcrypt sharp && \
    pnpm --filter @immich/sdk build && pnpm --filter @immich/plugin-sdk build && \
    pnpm --filter immich build && pnpm --filter @immich/cli build && \
    pnpm --filter immich --prod --no-optional deploy /output/server-pruned && \
    pnpm --filter @immich/cli --prod --no-optional deploy /output/cli-pruned
RUN SHARP_FORCE_GLOBAL_LIBVIPS=true pnpm --config.verify-deps-before-run=false \
    --dir /output/server-pruned/node_modules/sharp exec npm run build
# Audit the deployed lockfiles: unrelated docs/web development dependencies are
# not part of either deployed workspace. HIGH/CRITICAL still fail this build.
RUN mkdir -p /output/audits && \
    (cd /output/server-pruned && pnpm audit --prod --audit-level high --json > /output/audits/server.json) && \
    (cd /output/cli-pruned && pnpm audit --prod --audit-level high --json > /output/audits/cli.json)

FROM ghcr.io/immich-app/immich-server:v3.3.5@sha256:485d546a2e31d6a8b4db8423fcba5c109de8c218d93410af115fd1ccfc4352a6 AS runtime
USER root
LABEL org.opencontainers.image.title="BySamio Immich" \
    org.opencontainers.image.source="https://github.com/bysamio/images" \
    org.opencontainers.image.version="3.3.5-r1" \
    org.opencontainers.image.licenses="AGPL-3.0-only"
# CVE-2026-111497: native image decoders use Debian Brotli, distinct from Node's
# bundled decoder (already fixed in upstream Node 24.22.1).
RUN apt-get update && apt-get upgrade -y && \
    dpkg --compare-versions "$(dpkg-query -W -f='${Version}' libbrotli1)" ge '1.1.0-2+deb13u1' && \
    rm -rf /var/lib/apt/lists/* /usr/src/app/server /usr/src/app/cli && \
    rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack && \
    rm -f /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack /usr/local/bin/pnpm /usr/local/bin/pnpx
COPY --from=builder /output/server-pruned /usr/src/app/server
COPY --from=builder /output/cli-pruned /usr/src/app/cli
COPY --from=builder /output/audits /usr/share/bysamio/audits
RUN ln -s ../../cli/bin/immich /usr/src/app/server/bin/immich
ENV HOME=/tmp
USER 1000:1000
