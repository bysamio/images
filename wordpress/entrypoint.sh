#!/bin/bash
set -e

# BySamio WordPress Entrypoint
# This script wraps the official WordPress entrypoint for non-root execution

echo "BySamio WordPress - Starting as non-root user (UID: $(id -u))"

# Verify we're running as non-root
if [ "$(id -u)" = "0" ]; then
    echo "WARNING: Container is running as root. This is not recommended."
    echo "The image is designed to run as UID 1001 (bysamio user)."
fi

# Check if wp-content is writable
if [ ! -w "/var/www/html/wp-content" ]; then
    echo "WARNING: /var/www/html/wp-content is not writable by current user."
    echo "Ensure the volume has correct permissions (UID: $(id -u), GID: $(id -g))"
fi

# Create necessary directories if they don't exist
for dir in plugins themes uploads upgrade; do
    if [ ! -d "/var/www/html/wp-content/${dir}" ]; then
        mkdir -p "/var/www/html/wp-content/${dir}" 2>/dev/null || true
    fi
done

# WordPress configuration via environment variables
# The official WordPress image handles most of this, but we add some defaults

# Set default table prefix if not provided
: "${WORDPRESS_TABLE_PREFIX:=wp_}"

# Handle wp-config.php creation
# The official entrypoint (docker-entrypoint.sh) handles this
# We just need to ensure the environment is ready

# If wp-config.php doesn't exist and we have DB credentials, let the original entrypoint handle it
if [ ! -f /var/www/html/wp-config.php ]; then
    echo "wp-config.php not found, will be created by WordPress on first run"
fi

# Execute the original WordPress entrypoint
# The official image's entrypoint is at /usr/local/bin/docker-entrypoint.sh
if [ -f /usr/local/bin/docker-entrypoint.sh ]; then
    exec /usr/local/bin/docker-entrypoint.sh "$@"
else
    # Fallback: just execute the command directly
    exec "$@"
fi
