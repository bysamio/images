#!/usr/bin/env bash
set -euo pipefail

: "${IMAGE:?Set IMAGE to the Paperless image to verify}"
CONTAINER_ENGINE=${CONTAINER_ENGINE:-docker}
case "${1:-all}" in
  all) modes=(default explicit custom) ;;
  default|explicit|custom) modes=("$1") ;;
  *) echo 'Usage: IMAGE=<image> CONTAINER_ENGINE=docker|podman ./test/init.sh [all|default|explicit|custom]' >&2; exit 2 ;;
esac
# Multi-architecture index: the broker is test-only and never sees host data.
BROKER_IMAGE=docker.io/valkey/valkey:9.0.6-alpine3.24@sha256:187679e3bd4036959631e3f03983ab2ba503ab21e6fd0454d508e909db2ee989
containers=()
network=
cleanup() {
  status=$?
  trap - EXIT
  if [ "$status" -ne 0 ] && [ "${#containers[@]}" -gt 0 ]; then
    for container in "${containers[@]}"; do
      if ! "$CONTAINER_ENGINE" logs --tail 100 "$container" >&2; then
        echo "Unable to read test container logs: $container" >&2
      fi
    done
  fi
  if [ "${#containers[@]}" -gt 0 ]; then
    if ! "$CONTAINER_ENGINE" rm -f -v "${containers[@]}" >/dev/null; then status=1; fi
  fi
  if [ -n "$network" ]; then
    if ! "$CONTAINER_ENGINE" network rm "$network" >/dev/null; then status=1; fi
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

network=$("$CONTAINER_ENGINE" network create --internal "paperless-image-test-$$-$RANDOM")
broker=$("$CONTAINER_ENGINE" create --network "$network" --network-alias broker \
  --cap-drop ALL --security-opt no-new-privileges:true --user 1000:1000 \
  --tmpfs /data:rw,mode=1777 --entrypoint valkey-server "$BROKER_IMAGE" \
  --save '' --appendonly no)
containers+=("$broker")
"$CONTAINER_ENGINE" start "$broker" >/dev/null

for mode in "${modes[@]}"; do
  app_args=(create --network "$network" --cap-drop ALL --security-opt no-new-privileges:true)
  expected_uid=1000
  expected_gid=1000
  if [ "$mode" = explicit ]; then app_args+=(--user 1000:1000); fi
  if [ "$mode" = custom ]; then
    expected_uid=1234
    expected_gid=1234
    app_args+=(--user "$expected_uid:$expected_gid")
    for directory in data media consume export; do
      if [ "$(basename "$CONTAINER_ENGINE")" = podman ]; then
        app_args+=(--mount "type=tmpfs,destination=/usr/src/paperless/$directory,tmpfs-mode=0700,U=true,notmpcopyup")
      else
        app_args+=(--tmpfs "/usr/src/paperless/$directory:rw,uid=$expected_uid,gid=$expected_gid,mode=0700")
      fi
    done
  fi
  # Anonymous volumes or owned tmpfs provide fresh synthetic application state.
  app=$("$CONTAINER_ENGINE" "${app_args[@]}" \
    --env PAPERLESS_REDIS=redis://broker:6379 \
    --env PAPERLESS_DBENGINE=sqlite --env PAPERLESS_SECRET_KEY=synthetic-image-test-only \
    --env PAPERLESS_TASK_WORKERS=1 --env PAPERLESS_THREADS_PER_WORKER=1 "$IMAGE")
  containers+=("$app")
  "$CONTAINER_ENGINE" start "$app" >/dev/null
  healthy=false
  for ((attempt=0; attempt<90; attempt++)); do
    state=$("$CONTAINER_ENGINE" inspect --format '{{.State.Status}}' "$app")
    [ "$state" = running ] || { echo "FAIL: /init exited ($mode user): $state" >&2; exit 1; }
    health=$("$CONTAINER_ENGINE" inspect --format '{{.State.Health.Status}}' "$app")
    if [ "$health" = healthy ]; then healthy=true; break; fi
    sleep 2
  done
  [ "$healthy" = true ] || { echo "FAIL: inherited /init health timed out ($mode user)" >&2; exit 1; }
  "$CONTAINER_ENGINE" exec -i --env EXPECTED_UID="$expected_uid" --env EXPECTED_GID="$expected_gid" "$app" python3 - <<'PY'
from pathlib import Path
import os
import sqlite3
import subprocess
import urllib.request

status = dict(line.split(":", 1) for line in Path("/proc/1/status").read_text().splitlines() if ":" in line)
assert set(status["Uid"].split()) == {os.environ["EXPECTED_UID"]}, status["Uid"]
assert set(status["Gid"].split()) == {os.environ["EXPECTED_GID"]}, status["Gid"]
if os.environ["EXPECTED_UID"] != "1000":
    for name in ("data", "media", "consume", "export"):
        info = Path(f"/usr/src/paperless/{name}").stat()
        assert (info.st_uid, info.st_gid, info.st_mode & 0o777) == (
            int(os.environ["EXPECTED_UID"]), int(os.environ["EXPECTED_GID"]), 0o700), (name, info)
assert int(status["CapEff"].strip(), 16) == 0, status["CapEff"]
assert status["NoNewPrivs"].strip() == "1", status["NoNewPrivs"]
assert b"s6-svscan" in Path("/proc/1/cmdline").read_bytes(), "inherited /init supervisor missing"
for service in ("webserver", "worker", "scheduler", "consumer"):
    state = subprocess.check_output(["s6-svstat", "-u", f"/run/service/svc-{service}"], text=True).strip()
    assert state == "true", (service, state)
worker = subprocess.check_output(["celery", "--app", "paperless", "inspect", "--timeout", "5", "ping"],
                                 text=True, timeout=10)
assert "pong" in worker, worker
with sqlite3.connect("/usr/src/paperless/data/db.sqlite3") as database:
    assert database.execute("SELECT COUNT(*) FROM django_migrations").fetchone()[0] > 0
with urllib.request.urlopen("http://localhost:8000", timeout=2) as response:
    assert response.status == 200 and response.read(), "empty application response"
print(f"PASS: /init supervisor, services, worker ping, SQLite migrations and HTTP; UID/GID {os.environ['EXPECTED_UID']}:{os.environ['EXPECTED_GID']}, no capabilities, no-new-privileges")
PY
  echo "PASS: inherited image health check is healthy ($mode user)"
  "$CONTAINER_ENGINE" stop --time 10 "$app" >/dev/null
done
