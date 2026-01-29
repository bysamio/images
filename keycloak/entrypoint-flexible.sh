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
    local jar_files
    jar_files=$(find "$PROVIDERS_DIR" -type f -name "*.jar" 2>/dev/null | wc -l)
    if [ "$jar_files" -gt 0 ]; then
        find "$PROVIDERS_DIR" -type f -name "*.jar" -exec sha256sum {} \; 2>/dev/null | sort | sha256sum | cut -d' ' -f1
    else
        echo "no-providers"
    fi
}

# Function to compute a hash of our target build configuration
compute_config_hash() {
    # Create a hash of config that affects the build
    echo "${KC_DB:-}|${KC_FEATURES:-}|${KC_FEATURES_DISABLED:-}|${KC_HEALTH_ENABLED:-true}|${KC_METRICS_ENABLED:-true}|${KC_HTTP_RELATIVE_PATH:-}|${KC_CACHE:-}|${KC_CACHE_STACK:-}|${KC_TRANSACTION_XA_ENABLED:-}" | sha256sum | cut -d' ' -f1
}

# Function to check if rebuild is needed
needs_rebuild() {
    local current_providers_hash current_config_hash
    current_providers_hash=$(compute_providers_hash)
    current_config_hash=$(compute_config_hash)
    
    # Check if our build marker exists with matching config+providers hash
    if [ ! -f "$BUILD_MARKER" ]; then
        echo "No previous build marker found - first build needed"
        return 0
    fi
    
    # Read cached hashes (format: config_hash:providers_hash)
    local cached_hashes cached_config cached_providers
    cached_hashes=$(cat "$BUILD_MARKER" 2>/dev/null || echo "none:none")
    cached_config=$(echo "$cached_hashes" | cut -d':' -f1)
    cached_providers=$(echo "$cached_hashes" | cut -d':' -f2)
    
    # Check if config changed
    if [ "$current_config_hash" != "$cached_config" ]; then
        echo "Build config changed - rebuild needed"
        return 0
    fi
    
    # Check if providers changed
    if [ "$current_providers_hash" != "$cached_providers" ]; then
        echo "Providers changed (hash: ${current_providers_hash:0:12}... vs ${cached_providers:0:12}...)"
        return 0
    fi
    
    echo "Build is up-to-date"
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
        # Save config and providers hash (format: config_hash:providers_hash)
        echo "$(compute_config_hash):$(compute_providers_hash)" > "$BUILD_MARKER"
        echo ""
        echo "Build successful."
        return 0
    else
        echo "ERROR: Build failed!"
        exit 1
    fi
}

# Main logic
main() {
    # List custom providers if any
    if [ -d "$PROVIDERS_DIR" ]; then
        local jar_count
        jar_count=$(find "$PROVIDERS_DIR" -type f -name "*.jar" 2>/dev/null | wc -l)
        if [ "$jar_count" -gt 0 ]; then
            echo "Custom providers detected ($jar_count JAR files):"
            find "$PROVIDERS_DIR" -type f -name "*.jar" -exec basename {} \; 2>/dev/null
            echo ""
        else
            echo "No custom providers found"
            echo ""
        fi
    fi
    
    # List custom themes if any
    THEMES_DIR="${KC_HOME}/themes"
    if [ -d "$THEMES_DIR" ]; then
        custom_themes=$(find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d ! -name "keycloak*" 2>/dev/null | wc -l)
        if [ "$custom_themes" -gt 0 ]; then
            echo "Custom themes detected:"
            find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d ! -name "keycloak*" -exec basename {} \; 2>/dev/null
            echo ""
        fi
    fi
    
    # Handle build if needed
    if [ "$KC_AUTO_BUILD" = "true" ]; then
        local did_build_now=false
        
        if needs_rebuild; then
            run_build
            did_build_now=true
        fi
        
        echo ""
        if [ "$did_build_now" = "true" ]; then
            # We just ran a build - start WITHOUT --optimized for first initialization
            echo "Starting Keycloak (first start after build)..."
            echo "----------------------------------------"
            exec "${KC_HOME}/bin/kc.sh" "$@"
        else
            # Config and providers match cached build - use optimized mode
            echo "Starting Keycloak (optimized mode)..."
            echo "----------------------------------------"
            exec "${KC_HOME}/bin/kc.sh" "$@" --optimized
        fi
    else
        # No auto-build: start without optimized flag
        echo ""
        echo "Starting Keycloak..."
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
