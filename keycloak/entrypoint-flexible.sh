#!/bin/bash
# BySamio Keycloak - Flexible Variant Entrypoint
# Supports runtime provider loading and auto-build
#
# Features:
# - Detects custom providers in /opt/keycloak/providers
# - Auto-builds Keycloak when providers change
# - Caches build state to avoid unnecessary rebuilds
# - Supports all Keycloak environment variables

set -e

KC_HOME="${KC_HOME:-/opt/keycloak}"
KC_AUTO_BUILD="${KC_AUTO_BUILD:-true}"
KC_CACHE_PROVIDERS="${KC_CACHE_PROVIDERS:-true}"
BUILD_MARKER="${KC_HOME}/data/.build-marker"
PROVIDERS_DIR="${KC_HOME}/providers"

echo "=========================================="
echo "BySamio Keycloak - Flexible Variant"
echo "=========================================="
echo "User: $(id -u):$(id -g)"
echo "Auto-build: ${KC_AUTO_BUILD}"
echo ""

# Function to compute checksum of providers directory
compute_providers_hash() {
    if [ -d "$PROVIDERS_DIR" ] && [ "$(ls -A $PROVIDERS_DIR 2>/dev/null)" ]; then
        find "$PROVIDERS_DIR" -type f -name "*.jar" -exec sha256sum {} \; 2>/dev/null | sort | sha256sum | cut -d' ' -f1
    else
        echo "empty"
    fi
}

# Function to check if rebuild is needed
needs_rebuild() {
    local current_hash=$(compute_providers_hash)
    
    # If no build marker exists, we need to build
    if [ ! -f "$BUILD_MARKER" ]; then
        echo "No previous build found"
        return 0
    fi
    
    # Check if providers have changed
    local cached_hash=$(cat "$BUILD_MARKER" 2>/dev/null || echo "none")
    if [ "$current_hash" != "$cached_hash" ]; then
        echo "Providers changed (hash: ${current_hash:0:12}... vs cached: ${cached_hash:0:12}...)"
        return 0
    fi
    
    echo "Build is up-to-date (hash: ${current_hash:0:12}...)"
    return 1
}

# Function to run Keycloak build
run_build() {
    echo ""
    echo "Building Keycloak with current configuration..."
    echo "----------------------------------------"
    
    # Construct build arguments from environment variables
    local build_args=""
    
    # Database
    [ -n "$KC_DB" ] && build_args="$build_args --db=$KC_DB"
    
    # Features
    [ -n "$KC_FEATURES" ] && build_args="$build_args --features=$KC_FEATURES"
    [ -n "$KC_FEATURES_DISABLED" ] && build_args="$build_args --features-disabled=$KC_FEATURES_DISABLED"
    
    # Health and metrics (always enable for production)
    build_args="$build_args --health-enabled=${KC_HEALTH_ENABLED:-true}"
    build_args="$build_args --metrics-enabled=${KC_METRICS_ENABLED:-true}"
    
    # HTTP settings that affect build
    [ -n "$KC_HTTP_RELATIVE_PATH" ] && build_args="$build_args --http-relative-path=$KC_HTTP_RELATIVE_PATH"
    
    # Cache
    [ -n "$KC_CACHE" ] && build_args="$build_args --cache=$KC_CACHE"
    [ -n "$KC_CACHE_STACK" ] && build_args="$build_args --cache-stack=$KC_CACHE_STACK"
    
    # Transaction
    [ -n "$KC_TRANSACTION_XA_ENABLED" ] && build_args="$build_args --transaction-xa-enabled=$KC_TRANSACTION_XA_ENABLED"
    
    echo "Build arguments: $build_args"
    echo ""
    
    # Run the build
    if "${KC_HOME}/bin/kc.sh" build $build_args; then
        # Save the providers hash for cache checking
        if [ "$KC_CACHE_PROVIDERS" = "true" ]; then
            compute_providers_hash > "$BUILD_MARKER"
            echo ""
            echo "Build successful. Cache marker updated."
        fi
    else
        echo "ERROR: Build failed!"
        exit 1
    fi
}

# Main logic
main() {
    # List custom providers if any
    if [ -d "$PROVIDERS_DIR" ] && [ "$(ls -A $PROVIDERS_DIR 2>/dev/null)" ]; then
        echo "Custom providers detected:"
        ls -la "$PROVIDERS_DIR"/*.jar 2>/dev/null || echo "  (no JAR files found)"
        echo ""
    else
        echo "No custom providers found in $PROVIDERS_DIR"
        echo ""
    fi
    
    # List custom themes if any
    THEMES_DIR="${KC_HOME}/themes"
    if [ -d "$THEMES_DIR" ]; then
        custom_themes=$(find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d ! -name "keycloak*" 2>/dev/null | wc -l)
        if [ "$custom_themes" -gt 0 ]; then
            echo "Custom themes detected:"
            ls -la "$THEMES_DIR" 2>/dev/null | grep -v "^total" | grep -v "keycloak"
            echo ""
        fi
    fi
    
    # Handle build if needed
    if [ "$KC_AUTO_BUILD" = "true" ]; then
        if needs_rebuild; then
            run_build
        fi
        
        # Start with --optimized flag since we've built
        echo ""
        echo "Starting Keycloak (optimized mode)..."
        echo "----------------------------------------"
        exec "${KC_HOME}/bin/kc.sh" "$@" --optimized
    else
        # No auto-build: start in development/auto-build mode
        echo ""
        echo "Starting Keycloak (auto-build mode)..."
        echo "----------------------------------------"
        exec "${KC_HOME}/bin/kc.sh" "$@"
    fi
}

# Handle special commands
case "$1" in
    build)
        # Manual build command
        shift
        run_build "$@"
        ;;
    start-dev)
        # Development mode - no build needed
        echo "Starting Keycloak in development mode..."
        exec "${KC_HOME}/bin/kc.sh" "$@"
        ;;
    export|import|show-config)
        # Pass-through commands
        exec "${KC_HOME}/bin/kc.sh" "$@"
        ;;
    *)
        main "$@"
        ;;
esac
