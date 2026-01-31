#!/usr/bin/env bash
# mcp-launcher.sh - Launch MCP server with secrets from encrypted cache
# RFC v2.1: TTL check, namespace stripping, array-safe exec

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Usage check
if [[ $# -lt 1 ]]; then
    echo "Usage: mcp-launcher.sh <server> [--path <dir>]" >&2
    exit 1
fi

SERVER="$1"
shift

# Parse --path argument
PROJECT_PATH="$PWD"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            PROJECT_PATH="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Resolve to absolute path
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"
PROJECT_ID=$(printf '%s' "$PROJECT_PATH" | shasum -a 256 | cut -c1-12)
PROJECT_NAME=$(basename "$PROJECT_PATH")

# Directories
CONFIG_DIR="$HOME/.config/dev-infra"
CACHE_DIR="$HOME/.cache/dev-infra/projects/$PROJECT_ID"
REGISTRY="$CONFIG_DIR/mcp-registry.json"
AGE_IDENTITY="$CONFIG_DIR/age/identity.txt"
META_FILE="$CACHE_DIR/secrets.meta"
CACHE_FILE="$CACHE_DIR/secrets.enc"

# Check age identity exists
if [[ ! -f "$AGE_IDENTITY" ]]; then
    echo "ERROR: Age identity not found. Run: dev-infra secrets setup" >&2
    exit 1
fi

# Check registry exists
if [[ ! -f "$REGISTRY" ]]; then
    echo "ERROR: MCP registry not found at $REGISTRY" >&2
    exit 1
fi

# Verify server exists in registry
if ! jq -e ".servers.\"$SERVER\"" "$REGISTRY" >/dev/null 2>&1; then
    echo "ERROR: Server '$SERVER' not found in registry" >&2
    echo "Available servers:" >&2
    jq -r '.servers | keys[]' "$REGISTRY" >&2
    exit 1
fi

NOW=$(date +%s)

# TTL check and refresh logic
refresh_cache() {
    "$SCRIPT_DIR/secrets-refresh.sh" --path "$PROJECT_PATH"
}

check_and_refresh() {
    # No cache exists - must refresh
    if [[ ! -f "$META_FILE" ]] || [[ ! -f "$CACHE_FILE" ]]; then
        echo "No cache found, refreshing..." >&2
        refresh_cache
        return
    fi

    local soft_expires hard_expires
    soft_expires=$(jq -r '.soft_expires_at' "$META_FILE")
    hard_expires=$(jq -r '.hard_expires_at' "$META_FILE")

    if [[ $NOW -lt $soft_expires ]]; then
        # Fresh - no refresh needed
        return
    elif [[ $NOW -lt $hard_expires ]]; then
        # Soft expired: try refresh, allow stale on failure
        echo "Cache soft-expired, attempting refresh..." >&2
        if ! refresh_cache 2>/dev/null; then
            echo "WARNING: Using stale cache (soft TTL exceeded, refresh failed)" >&2
        fi
    else
        # Hard expired: must refresh
        echo "Cache hard-expired, refreshing..." >&2
        if ! refresh_cache; then
            echo "ERROR: Cache hard-expired and refresh failed for $PROJECT_NAME" >&2
            exit 1
        fi
    fi
}

check_and_refresh

# Decrypt cache using age keypair (correct usage: -i for identity)
if [[ ! -f "$CACHE_FILE" ]]; then
    echo "ERROR: Cache file not found after refresh" >&2
    exit 1
fi

SECRETS=$(age -d -i "$AGE_IDENTITY" "$CACHE_FILE")

# Export secrets for this server (strip namespace prefix)
# Registry keys are namespaced as "server.ENV_VAR", we export as "ENV_VAR"
while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    namespaced_key=$(echo "$row" | base64 -d | jq -r '.key')
    # Strip "server." prefix to get ENV_VAR
    env_var="${namespaced_key#*.}"
    value=$(echo "$SECRETS" | jq -r --arg k "$namespaced_key" '.[$k] // empty')
    if [[ -n "$value" ]]; then
        export "$env_var=$value"
    fi
done < <(jq -r ".servers.\"$SERVER\".secrets // {} | to_entries[] | @base64" "$REGISTRY")

# Array-safe command execution
# readarray preserves argument boundaries for commands with spaces
readarray -t cmd < <(jq -r ".servers.\"$SERVER\".command[]" "$REGISTRY")

if [[ ${#cmd[@]} -eq 0 ]]; then
    echo "ERROR: No command defined for server '$SERVER'" >&2
    exit 1
fi

# Launch the server
exec "${cmd[@]}"
