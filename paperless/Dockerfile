# Source/entrypoint contract: https://github.com/paperless-ngx/paperless-ngx/blob/v3.3.2/Dockerfile
FROM ghcr.io/paperless-ngx/paperless-ngx:3.3.2@sha256:d232cba37cc0bab0d6c6581ecd320383b7a6f49f33e0fd16adda4d009eb600dd AS dependencies

USER 0:0
ARG DEBIAN_FRONTEND=noninteractive
ARG LIBRSVG_VERSION="2.60.0+dfsg-1+deb13u1"
ARG CURL_VERSION="8.14.1-2+deb13u7"
ARG GHOSTSCRIPT_VERSION="10.05.1~dfsg-1+deb13u3"
LABEL org.opencontainers.image.source="https://github.com/bysamio/images" \
      org.opencontainers.image.documentation="https://github.com/bysamio/images/tree/main/paperless" \
      org.opencontainers.image.version="3.3.2-r1" \
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
# https://github.com/paperless-ngx/paperless-ngx/blob/v3.3.2/docs/setup.md
USER 1000:1000

# The source hash pins the upstream code this correction was tested against.
# Keep permission filters, citations, read-lock lifetime and streaming unchanged.
FROM dependencies AS runtime
USER 0:0
COPY apply-ai-chat-fix.py /tmp/bysamio-ai-chat-fix.py
RUN python3 -I -B /tmp/bysamio-ai-chat-fix.py && rm /tmp/bysamio-ai-chat-fix.py
LABEL org.opencontainers.image.version="3.3.2-r1"
USER 1000:1000

# Public tokenizer data only; fixed revision, independent checksum and license.
# No Hugging Face client, model weights, remote code or runtime download is used.
# https://huggingface.co/Qwen/Qwen3-4B-Instruct-2507/tree/cdbee75f17c01a7cc42f958dc650907174af0554
USER 0:0
COPY token-budget.py /usr/src/paperless/src/paperless_ai/token_budget.py
COPY apply-ai-context-fix.py /tmp/bysamio-ai-context-fix.py
RUN set -eux; \
    curl --proto '=https' --proto-redir '=https' --tlsv1.2 --fail --location --max-redirs 3 \
      --connect-timeout 15 --max-time 120 --max-filesize 16777216 \
      https://huggingface.co/Qwen/Qwen3-4B-Instruct-2507/resolve/cdbee75f17c01a7cc42f958dc650907174af0554/tokenizer.json \
      --output /usr/share/bysamio/qwen3-4b-tokenizer.json; \
    echo 'aeb13307a71acd8fe81861d94ad54ab689df773318809eed3cbe794b4492dae4  /usr/share/bysamio/qwen3-4b-tokenizer.json' | sha256sum --check --strict; \
    curl --proto '=https' --proto-redir '=https' --tlsv1.2 --fail --location --max-redirs 3 \
      --connect-timeout 15 --max-time 60 --max-filesize 65536 \
      https://huggingface.co/Qwen/Qwen3-4B-Instruct-2507/resolve/cdbee75f17c01a7cc42f958dc650907174af0554/LICENSE \
      --output /usr/share/bysamio/qwen3-tokenizer.LICENSE; \
    echo '832dd9e00a68dd83b3c3fb9f5588dad7dcf337a0db50f7d9483f310cd292e92e  /usr/share/bysamio/qwen3-tokenizer.LICENSE' | sha256sum --check --strict; \
    chmod 0444 /usr/share/bysamio/qwen3-4b-tokenizer.json /usr/share/bysamio/qwen3-tokenizer.LICENSE; \
    python3 -I -B /tmp/bysamio-ai-context-fix.py; \
    rm /tmp/bysamio-ai-context-fix.py
USER 1000:1000
