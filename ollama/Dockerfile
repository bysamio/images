# syntax=docker/dockerfile:1
ARG BUILDPLATFORM
# Retain the exact upstream native CPU payload; rebuild the vulnerable Go binary.
FROM --platform=linux/amd64 docker.io/ollama/ollama@sha256:44833c52df2a164cc1238a96ce100123c8e54082b85c5e235a9cb5a7adc55f27 AS native
RUN set -eu; mkdir /cpu; \
    find /usr/lib/ollama -mindepth 1 -maxdepth 1 ! -type d ! -name include -exec cp -a '{}' /cpu/ ';'; \
    test -x /cpu/llama-server; test -f /cpu/libggml-base.so

FROM --platform=${BUILDPLATFORM} docker.io/library/golang:1.27.2-bookworm@sha256:5cf287a799e6b94384bad13d16b14904c531f51ba65792237e122ce42b392f61 AS build
ENV GOTOOLCHAIN=local GOFLAGS=-mod=readonly
RUN apt-get update && apt-get install -y --no-install-recommends cmake binutils \
    && if [ "$(go env GOARCH)" != amd64 ]; then apt-get install -y --no-install-recommends gcc-x86-64-linux-gnu g++-x86-64-linux-gnu; fi \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /source
# Tag replacement fails the content hash; source commit is recorded below.
RUN curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 --max-time 120 \
      https://codeload.github.com/ollama/ollama/tar.gz/refs/tags/v0.40.3 -o /tmp/source.tar.gz \
    && echo '2c0eaba5f82b6eba7eb45338494f7dc3496bde674c8f487b20bd269695a362ba  /tmp/source.tar.gz' | sha256sum -c - \
    && tar -xzf /tmp/source.tar.gz --strip-components=1 -C /source && rm /tmp/source.tar.gz
COPY go.mod go.sum ./
RUN go mod download && go mod verify \
    && go test -timeout 180s ./api ./envconfig ./parser ./template ./format ./types/model ./server ./llm
RUN set -eu; export CC=gcc CXX=g++; \
    if [ "$(go env GOARCH)" != amd64 ]; then export CC=x86_64-linux-gnu-gcc CXX=x86_64-linux-gnu-g++; fi; \
    CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -trimpath -buildmode=pie \
      -ldflags='-w -s -X github.com/ollama/ollama/version.Version=0.40.3 -X github.com/ollama/ollama/server.mode=release' \
      -o /out/ollama .; \
    readelf -h /out/ollama | grep 'Advanced Micro Devices X86-64'
# Build the license tool natively, then scan the cross-compiled target graph.
RUN GOFLAGS= go install github.com/google/go-licenses/v2@v2.0.1 \
    && install -D /go/bin/go-licenses /tmp/license-build/go-licenses-v2.0.1/go-licenses
RUN set -eu; if [ "$(go env GOARCH)" != amd64 ]; then export CC=x86_64-linux-gnu-gcc CXX=x86_64-linux-gnu-g++; fi; \
    cmake -DGO_EXECUTABLE=/usr/local/go/bin/go -DSOURCE_DIR=/source \
      -DBINARY_DIR=/tmp/license-build -DOUTPUT_DIR=/out -DTARGETS=linux/amd64 \
      -P cmake/generate_go_license.cmake

FROM --platform=linux/amd64 docker.io/library/ubuntu:24.04@sha256:f610ab94648195aa356059f5b41d6085c9d4d903c072430cdd1af7bdb646106b AS runtime
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends ca-certificates curl libstdc++6 libgomp1 libopenblas0 \
    && rm -rf /var/lib/apt/lists/* \
    && if getent passwd 1000 >/dev/null; then \
         test "$(getent passwd 1000 | cut -d: -f1)" = ubuntu; \
         test "$(getent group 1000 | cut -d: -f1)" = ubuntu; \
         usermod --login ollama --home /home/ollama --shell /usr/sbin/nologin ubuntu; groupmod --new-name ollama ubuntu; \
       else groupadd --gid 1000 ollama; \
         useradd --uid 1000 --gid 1000 --no-create-home --home-dir /home/ollama --shell /usr/sbin/nologin ollama; fi \
    && install -d -m 700 -o 1000 -g 1000 /home/ollama /home/ollama/.ollama
COPY --from=native /cpu/ /usr/lib/ollama/
COPY --from=build /out/ollama /usr/bin/ollama
COPY --from=build /out/GO_LICENSE /usr/lib/ollama/GO_LICENSE
LABEL org.opencontainers.image.source="https://github.com/bysamio/images" \
      org.opencontainers.image.version="0.40.3-cpu-r1" \
      io.bysamio.ollama.upstream-commit="eab97e9f92b9a25c2d52d2cc6c1b1c99bd9fae21" \
      io.bysamio.ollama.native-payload="sha256:44833c52df2a164cc1238a96ce100123c8e54082b85c5e235a9cb5a7adc55f27"
ENV HOME=/home/ollama OLLAMA_HOST=0.0.0.0:11434 OLLAMA_NO_CLOUD=1 \
    OLLAMA_MODELS=/home/ollama/.ollama/models OLLAMA_MAX_LOADED_MODELS=1 OLLAMA_NUM_PARALLEL=1 \
    OLLAMA_CONTEXT_LENGTH=4096 OLLAMA_MAX_QUEUE=4
USER 1000:1000
EXPOSE 11434
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl --fail --silent --max-time 3 http://127.0.0.1:11434/api/version >/dev/null || exit 1
ENTRYPOINT ["/usr/bin/ollama"]
CMD ["serve"]
