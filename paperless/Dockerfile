# Source/entrypoint contract: https://github.com/paperless-ngx/paperless-ngx/blob/v3.3.0/Dockerfile
FROM ghcr.io/paperless-ngx/paperless-ngx:3.3.0@sha256:6b94799bc769a063b3340cc5847402e626d4d91d29a295a8e747f8e9bead4207 AS runtime

USER 0:0
ARG DEBIAN_FRONTEND=noninteractive
ARG LIBRSVG_VERSION="2.60.0+dfsg-1+deb13u1"
ARG CURL_VERSION="8.14.1-2+deb13u7"
ARG GHOSTSCRIPT_VERSION="10.05.1~dfsg-1+deb13u3"
LABEL org.opencontainers.image.source="https://github.com/bysamio/images" \
      org.opencontainers.image.documentation="https://github.com/bysamio/images/tree/main/paperless" \
      org.opencontainers.image.version="3.3.0-r1" \
      org.opencontainers.image.title="BySam.io Paperless-ngx" \
      org.opencontainers.image.licenses="GPL-3.0-only"

COPY requirements-patches.txt /tmp/bysamio-requirements-patches.txt
# Debian security backports fix document-parser sandbox escape and Pdfwrite
# overflow. Keep Trixie libraries together; never mix Debian distributions.
# SVG parser Trixie backport: https://security-tracker.debian.org/tracker/DSA-6555-1
# Curl Trixie backports: https://security-tracker.debian.org/tracker/DSA-6558-1
# https://security-tracker.debian.org/tracker/CVE-2026-101258
# https://security-tracker.debian.org/tracker/CVE-2026-103226
RUN set -eux; \
    apt-get update; \
    apt-get install --yes --no-install-recommends --only-upgrade \
      "librsvg2-2=${LIBRSVG_VERSION}" \
      "curl=${CURL_VERSION}" \
      "libcurl4t64=${CURL_VERSION}" \
      "libcurl3t64-gnutls=${CURL_VERSION}" \
      "ghostscript=${GHOSTSCRIPT_VERSION}" \
      "libgs-common=${GHOSTSCRIPT_VERSION}" \
      "libgs10=${GHOSTSCRIPT_VERSION}" \
      "libgs10-common=${GHOSTSCRIPT_VERSION}"; \
    uv --no-config pip install --system --no-cache --no-deps \
      --only-binary :all: --require-hashes --default-index https://pypi.org/simple \
      --requirements /tmp/bysamio-requirements-patches.txt; \
    # pip is not used by the application or upstream container startup. Its
    # bundled msgpack/setuptools/urllib3 copies remain vulnerable even when
    # the application's installed packages are patched. Keep upstream uv.
    uv pip uninstall --system pip; \
    rm -f /usr/local/lib/python3.14/ensurepip/_bundled/pip-*.whl; \
    uv pip check --system; \
    install -d /usr/share/bysamio; \
    dpkg-query -W > /usr/share/bysamio/debian-packages.txt; \
    uv pip freeze --system > /usr/share/bysamio/python-packages.txt; \
    rm -f /tmp/bysamio-requirements-patches.txt; \
    rm -rf /var/lib/apt/lists/*; \
    apt-get clean

# Upstream rootless mode uses the process UID directly. Consumers with bind
# mounts set `user: UID:GID`; USERMAP_UID/GID are for upstream root startup only.
# https://github.com/paperless-ngx/paperless-ngx/blob/v3.3.0/docs/setup.md
USER 1000:1000
