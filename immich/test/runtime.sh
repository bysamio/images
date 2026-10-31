#!/bin/sh
set -eu
engine=${CONTAINER_ENGINE:-docker}
image=${IMAGE:-immich:local}
database=${DB_IMAGE:-postgresql-immich:local}
valkey='docker.io/valkey/valkey:9.1.2-alpine@sha256:48332870af354a799964c0012ae1194a0bf2bf894eb508f945810596dc2d8d11'
name=immich-test-$$
cleanup() {
  for container in "$name" "$name-db" "$name-cache"; do
    "$engine" rm -f "$container" >/dev/null 2>&1 || :
  done
  "$engine" network rm "$name" >/dev/null 2>&1 || :
  "$engine" volume rm "$name-media" "$name-db" >/dev/null 2>&1 || :
}
trap cleanup EXIT HUP INT TERM
test "$("$engine" run --rm --entrypoint id "$image" -u)" = 1000
"$engine" network create --internal "$name" >/dev/null
"$engine" volume create "$name-media" >/dev/null
"$engine" volume create "$name-db" >/dev/null
"$engine" run --rm --user 0:0 --cap-drop ALL --cap-add CHOWN \
  -v "$name-media:/data" --entrypoint chown "$image" 1000:1000 /data
"$engine" run -d --name "$name-db" --network "$name" --network-alias database \
  --cap-drop ALL --security-opt no-new-privileges --memory 1g \
  -e POSTGRES_PASSWORD=disposable-runtime-test -e POSTGRES_DB=immich \
  -v "$name-db:/var/lib/postgresql/pgdata" "$database" >/dev/null
"$engine" run -d --name "$name-cache" --network "$name" --network-alias redis \
  --user 1000:1000 --cap-drop ALL --security-opt no-new-privileges --memory 256m \
  "$valkey" valkey-server --save '' --appendonly no >/dev/null
"$engine" create --name "$name" --network "$name" \
  --user 1000:1000 --cap-drop ALL --security-opt no-new-privileges \
  --memory 2g --cpus 1.5 --pids-limit 256 \
  -e DB_HOSTNAME=database -e DB_USERNAME=postgres -e DB_DATABASE_NAME=immich \
  -e DB_PASSWORD=disposable-runtime-test -e REDIS_HOSTNAME=redis \
  -e IMMICH_CONFIG_FILE=/tmp/pilot-settings.json \
  -v "$name-media:/data" "$image" >/dev/null
"$engine" cp test/settings.json "$name:/tmp/pilot-settings.json"
"$engine" cp test/functional.cjs "$name:/tmp/functional.cjs"
"$engine" start "$name" >/dev/null
ready=false
for attempt in $(seq 1 180); do
  if "$engine" exec "$name" immich-healthcheck >/dev/null 2>&1; then ready=true; break; fi
  if [ "$("$engine" inspect --format '{{.State.Running}}' "$name")" != true ]; then break; fi
  sleep 1
done
if [ "$ready" != true ]; then
  "$engine" logs "$name"; "$engine" logs "$name-db"; exit 1
fi
if ! "$engine" exec "$name" node /tmp/functional.cjs; then
  "$engine" logs "$name"; exit 1
fi
echo 'PASS: bounded non-root Immich with new PostgreSQL, API, upload and thumbnail'
