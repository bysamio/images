#!/bin/sh
set -e

# BySamio PostgreSQL Entrypoint
# This script wraps the official PostgreSQL entrypoint for non-root execution.
# The image intentionally removes gosu and does not support root startup.

echo "BySamio PostgreSQL - Starting as user $(id -u):$(id -g)"

# Verify we're running as non-root
if [ "$(id -u)" = "0" ]; then
    echo "ERROR: This image does not support running as root."
    echo "Run it as UID 1001, or enable the chart's volumePermissions init container to fix PVC ownership before startup."
    exit 1
fi

# Ensure data directory has correct permissions
if [ ! -d "$PGDATA" ]; then
    mkdir -p "$PGDATA"
fi

# Check if data directory is writable
if [ ! -w "$PGDATA" ]; then
    echo "WARNING: $PGDATA is not writable by current user."
    echo "Ensure the volume has correct permissions (UID: $(id -u), GID: $(id -g))"
fi

# Execute the original PostgreSQL entrypoint
exec docker-entrypoint.sh "$@"
