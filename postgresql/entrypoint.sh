#!/bin/sh
set -e

# BySamio PostgreSQL Entrypoint
# This script wraps the official PostgreSQL entrypoint for non-root execution

echo "BySamio PostgreSQL - Starting as user $(id -u):$(id -g)"

# Verify we're running as non-root
if [ "$(id -u)" = "0" ]; then
    echo "WARNING: Container is running as root. This is not recommended."
    echo "The image is designed to run as UID 1001 (postgres user)."
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
