#!/bin/sh
set -eu
if [ "$(id -u)" = 0 ]; then
  echo 'This image requires UID/GID 1001; prepare volume ownership before startup.' >&2
  exit 1
fi
exec docker-entrypoint.sh "$@"
