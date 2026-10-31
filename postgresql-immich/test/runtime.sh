#!/bin/sh
set -eu
engine=${CONTAINER_ENGINE:-docker}
image=${IMAGE:-postgresql-immich:local}
name=pg-immich-test-$$
volume=$name-data
cleanup() {
  "$engine" rm -f "$name" >/dev/null 2>&1 || :
  "$engine" volume rm "$volume" >/dev/null 2>&1 || :
}
trap cleanup EXIT HUP INT TERM
test "$("$engine" run --rm --entrypoint id "$image" -u)" = 1001
if "$engine" run --rm --user 0:0 "$image" postgres --version; then
  echo 'FAIL: root startup accepted' >&2; exit 1
fi
"$engine" volume create "$volume" >/dev/null
# Docker initializes the empty volume from the image with UID 1001 ownership.
"$engine" run -d --name "$name" --cap-drop ALL \
  --security-opt no-new-privileges --memory 1g --shm-size 128m \
  -e POSTGRES_PASSWORD=disposable-runtime-test -e POSTGRES_DB=immich \
  -v "$volume:/var/lib/postgresql/pgdata" "$image" >/dev/null
ready=false
for attempt in $(seq 1 60); do
  if "$engine" exec -e PGPASSWORD=disposable-runtime-test "$name" \
    psql -h 127.0.0.1 -U postgres -d immich -Atc 'SELECT 1' >/dev/null 2>&1; then
    ready=true; break
  fi
  sleep 1
done
if [ "$ready" != true ]; then "$engine" logs "$name"; exit 1; fi
sql() {
  "$engine" exec -i -e PGPASSWORD=disposable-runtime-test "$name" \
    psql -h 127.0.0.1 -U postgres -d immich -v ON_ERROR_STOP=1 "$@"
}
sql <<'SQL'
CREATE EXTENSION vchord CASCADE;
CREATE EXTENSION earthdistance CASCADE;
DO $$ BEGIN
  IF current_setting('server_version_num')::int < 170011 THEN RAISE EXCEPTION 'old PostgreSQL'; END IF;
  IF (SELECT extversion FROM pg_extension WHERE extname='vector') <> '0.8.7' THEN RAISE EXCEPTION 'wrong vector'; END IF;
  IF (SELECT extversion FROM pg_extension WHERE extname='vchord') <> '1.1.1' THEN RAISE EXCEPTION 'wrong vchord'; END IF;
END $$;
CREATE TABLE pilot (id integer PRIMARY KEY, embedding vector(3));
INSERT INTO pilot SELECT n, ARRAY[n::real, 2::real, 3::real]::vector FROM generate_series(1,1024) n;
CREATE INDEX pilot_vector ON pilot USING vchordrq (embedding vector_l2_ops)
WITH (options = $$[build.internal]
lists = [1]
$$);
SET enable_seqscan=off;
SET vchordrq.probes='1';
DO $$ BEGIN
  IF (SELECT id FROM pilot ORDER BY embedding <-> '[1,2,3]' LIMIT 1) <> 1 THEN RAISE EXCEPTION 'incorrect nearest neighbour'; END IF;
  IF earth_distance(ll_to_earth(0,0),ll_to_earth(0,0)) <> 0 THEN RAISE EXCEPTION 'earthdistance failed'; END IF;
END $$;
SQL
"$engine" restart "$name" >/dev/null
for attempt in $(seq 1 30); do
  if sql -Atc 'SELECT count(*) FROM pilot' 2>/dev/null | rg -qx 1024; then break; fi
  sleep 1
done
test "$(sql -Atc 'SELECT count(*) FROM pilot')" = 1024
"$engine" exec -e PGPASSWORD=disposable-runtime-test "$name" \
  pg_dump -h 127.0.0.1 -U postgres -d immich -Fc -f /tmp/pilot.dump
sql -c 'CREATE DATABASE restored'
"$engine" exec -e PGPASSWORD=disposable-runtime-test "$name" \
  pg_restore -h 127.0.0.1 -U postgres -d restored --exit-on-error /tmp/pilot.dump
test "$("$engine" exec -e PGPASSWORD=disposable-runtime-test "$name" \
  psql -h 127.0.0.1 -U postgres -d restored -Atc 'SELECT count(*) FROM pilot')" = 1024
echo 'PASS: restricted PostgreSQL, extension index/query, restart and logical restore'
