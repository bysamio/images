#!/usr/bin/env bash
# Real CPU inference in a disposable restricted container; synthetic prompts only.
set -euo pipefail
CONTAINER_ENGINE=${CONTAINER_ENGINE:-docker}
IMAGE=${IMAGE:-ollama-cpu:local}
test_name=ollama-cpu-test-$(python3 -c 'import secrets; print(secrets.token_hex(16))')
test_volume=$test_name-state
test_network=$test_name-download
container_id=
volume_created=false
network_created=false
diagnostics=$(mktemp -d "${TMPDIR:-/tmp}/bysam-ollama-test.XXXXXXXX")
umask 077
owned() {
  test "$("$CONTAINER_ENGINE" "$1" inspect "$2" --format '{{index .Labels "io.bysam.ollama-test"}}' 2>/dev/null)" = "$test_name"
}
cleanup() {
  status=$?
  trap - EXIT
  set +e
  if [[ $container_id =~ ^[a-f0-9]{64}$ ]] && \
      test "$("$CONTAINER_ENGINE" inspect "$container_id" --format '{{index .Config.Labels "io.bysam.ollama-test"}}' 2>/dev/null)" = "$test_name"; then
    if [ "$status" != 0 ]; then
      "$CONTAINER_ENGINE" logs "$container_id" > "$diagnostics/runtime.log" 2>&1
    fi
    "$CONTAINER_ENGINE" rm -f "$container_id" >> "$diagnostics/cleanup.log" 2>&1 || { printf 'FAIL: retained exact container: %s\n' "$container_id" >&2; status=1; }
  fi
  if $network_created && owned network "$test_network"; then
    "$CONTAINER_ENGINE" network rm "$test_network" >> "$diagnostics/cleanup.log" 2>&1 || { printf 'FAIL: retained exact network: %s\n' "$test_network" >&2; status=1; }
  fi
  if $volume_created && owned volume "$test_volume"; then
    if [ "$status" = 0 ]; then
      "$CONTAINER_ENGINE" volume rm "$test_volume" >> "$diagnostics/cleanup.log" 2>&1 || { printf 'FAIL: retained exact volume: %s\n' "$test_volume" >&2; status=1; }
    else
      printf 'Failed synthetic state retained: %s; diagnostics: %s\n' "$test_volume" "$diagnostics" >&2
    fi
  fi
  exit "$status"
}
trap cleanup EXIT
test "$("$CONTAINER_ENGINE" run --rm --network none --entrypoint id "$IMAGE" -u)" = 1000
"$CONTAINER_ENGINE" volume create --label "io.bysam.ollama-test=$test_name" "$test_volume" >/dev/null
volume_created=true
owned volume "$test_volume" || exit 1
"$CONTAINER_ENGINE" network create --label "io.bysam.ollama-test=$test_name" "$test_network" >/dev/null
network_created=true
owned network "$test_network" || exit 1
# The image-owned mount target initializes the disposable volume as UID 1000.
container_id=$("$CONTAINER_ENGINE" create --name "$test_name" --label "io.bysam.ollama-test=$test_name" --network "$test_network" \
  --cap-drop ALL --security-opt no-new-privileges:true --read-only \
  --memory 2g --memory-swap 2g --cpus 2 --pids-limit 128 \
  --tmpfs /tmp:rw,nosuid,nodev,size=268435456,mode=1777 \
  --mount "type=volume,src=$test_volume,dst=/home/ollama/.ollama" "$IMAGE")
[[ $container_id =~ ^[a-f0-9]{64}$ ]] || exit 1
test "$("$CONTAINER_ENGINE" inspect "$container_id" --format '{{index .Config.Labels "io.bysam.ollama-test"}}')" = "$test_name"
"$CONTAINER_ENGINE" start "$container_id" >/dev/null
api() {
  case "$2" in api/version|api/pull|api/tags|api/generate|api/embed) ;; *) return 1;; esac
  result="$diagnostics/${2##*/}.json"
  if "$CONTAINER_ENGINE" exec "$container_id" curl --fail-with-body --silent --show-error --max-time "$1" \
      "http://127.0.0.1:11434/$2" "${@:3}" > "$result"; then
    cat "$result"
  else
    printf 'FAIL: API response retained in synthetic diagnostics: %s\n' "$diagnostics" >&2
    return 1
  fi
}
ready=false
for _ in {1..90}; do
  if api 3 api/version >/dev/null 2>&1; then ready=true; break; fi
  sleep 1
done
$ready || { printf 'FAIL: restricted fresh startup did not become ready\n' >&2; exit 1; }
api 5 api/version | python3 -c 'import json,sys; assert json.load(sys.stdin)=={"version":"0.40.3"}'
# Expand these checks inside the container shell.
# shellcheck disable=SC2016
"$CONTAINER_ENGINE" exec "$test_name" sh -ec 'test -s "$HOME/.ollama/id_ed25519"; test "$(stat -c %a "$HOME/.ollama/id_ed25519")" = 600; test "$(id -u)" = 1000; grep -Eq "^CapEff:[[:space:]]+0+$" /proc/1/status; grep -Eq "^NoNewPrivs:[[:space:]]+1$" /proc/1/status; test ! -d /usr/lib/ollama/cuda_v12; test ! -d /usr/lib/ollama/vulkan'
printf 'PASS: non-root fresh private-state contract, read-only root, zero capabilities and release version\n'
code=$("$CONTAINER_ENGINE" exec "$test_name" curl --silent --max-time 5 -o /dev/null -w '%{http_code}' \
  http://127.0.0.1:11434/api/generate -H 'Content-Type: application/json' -d '{"model":"does-not-exist","prompt":"synthetic","stream":false}')
test "$code" = 404
printf 'INFO: pulling the exact synthetic generation model\n'
api 600 api/pull -H 'Content-Type: application/json' -d '{"model":"qwen2.5:0.5b","stream":false}' >/dev/null
printf 'INFO: pulling the exact synthetic embedding model\n'
api 600 api/pull -H 'Content-Type: application/json' -d '{"model":"all-minilm:latest","stream":false}' >/dev/null
api 5 api/tags | python3 -c 'import json,sys; models={x["name"]:x["digest"] for x in json.load(sys.stdin)["models"]}; assert models["qwen2.5:0.5b"]=="a8b0c51577010a279d933d14c2a8ab4b268079d44c5c8830c0a93900f1827c67"; assert models["all-minilm:latest"]=="1b226e2802dbb772b5fc32a58f103ca1804ef7501331012de126ab22f67475ef"'
# Remove the only external network before exercising model parsing/inference.
"$CONTAINER_ENGINE" network disconnect "$test_network" "$test_name"
printf 'INFO: testing actual CPU generation without external networking\n'
api 240 api/generate -H 'Content-Type: application/json' \
  -d '{"model":"qwen2.5:0.5b","prompt":"Answer with one German word: What color is grass?","stream":false,"keep_alive":0,"options":{"num_predict":16,"num_ctx":512,"num_thread":2,"temperature":0}}' \
  | python3 -c 'import json,sys; j=json.load(sys.stdin); assert j["done"] is True and j["eval_count"]>0 and j["response"].strip()'
printf 'INFO: testing actual CPU embeddings without external networking\n'
api 120 api/embed -H 'Content-Type: application/json' \
  -d '{"model":"all-minilm:latest","input":["Synthetischer Archivtest.","Synthetic archive test."],"keep_alive":0}' \
  | python3 -c 'import json,sys,math; e=json.load(sys.stdin)["embeddings"]; assert len(e)==2 and all(len(x)==384 and all(math.isfinite(v) for v in x) and sum(v*v for v in x)>0 for x in e)'
# Expand these checks inside the container shell.
# shellcheck disable=SC2016
"$CONTAINER_ENGINE" exec "$test_name" sh -ec 'test "$(find /usr/lib/ollama -mindepth 1 -maxdepth 1 -type d | wc -l)" = 0'
printf 'PASS: exact model digests, real CPU generation/embeddings and no external network during inference\n'
