#!/usr/bin/env bash
# secrets-refresh.sh - Build/refresh encrypted secrets cache for a project
# RFC v2.1: age keypair encryption, per-project cache, namespaced secrets

set -euo pipefail

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
AGE_RECIPIENT="$CONFIG_DIR/age/recipient.txt"
ENABLED_FILE="$PROJECT_PATH/.enabled-servers"
ENABLED_LOCAL="$PROJECT_PATH/.enabled-servers.local"
LOG_FILE="$HOME/.cache/dev-infra/refresh.log"

# TTL values (seconds)
SOFT_TTL=14400   # 4 hours
HARD_TTL=86400   # 24 hours

# Ensure cache directory exists with correct permissions
mkdir -p "$CACHE_DIR"
chmod 700 "$CACHE_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# Check age keypair exists
if [[ ! -f "$AGE_RECIPIENT" ]]; then
    echo "ERROR: Age keypair not found. Run: dev-infra secrets setup" >&2
    exit 1
fi

# Check registry exists
if [[ ! -f "$REGISTRY" ]]; then
    echo "ERROR: MCP registry not found at $REGISTRY" >&2
    echo "Copy from: templates/config/mcp-registry.json.example" >&2
    exit 1
fi

# Load 1Password token from secure file (NOT hardcoded anywhere)
if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
    TOKEN_FILE="$HOME/.config/op/service-account-token"
    if [[ -f "$TOKEN_FILE" ]]; then
        export OP_SERVICE_ACCOUNT_TOKEN=$(cat "$TOKEN_FILE")
    else
        echo "ERROR: OP_SERVICE_ACCOUNT_TOKEN not set and $TOKEN_FILE missing" >&2
        exit 1
    fi
fi

# Read enabled servers for this project (plus optional local overrides)
if [[ ! -f "$ENABLED_FILE" ]]; then
    echo "No enabled servers for $PROJECT_NAME (missing $ENABLED_FILE)" >&2
    # Create empty cache
    echo "{}" | age -r "$(cat "$AGE_RECIPIENT")" -o "$CACHE_DIR/secrets.enc"
    chmod 600 "$CACHE_DIR/secrets.enc"
    NOW=$(date +%s)
    cat > "$CACHE_DIR/secrets.meta" << EOF
{
  "project_name": "$PROJECT_NAME",
  "project_path": "$PROJECT_PATH",
  "project_id": "$PROJECT_ID",
  "refreshed_at": $NOW,
  "soft_expires_at": $((NOW + SOFT_TTL)),
  "hard_expires_at": $((NOW + HARD_TTL)),
  "enabled_servers": [],
  "checksum": "$(shasum -a 256 "$CACHE_DIR/secrets.enc" | cut -d' ' -f1)"
}
EOF
    exit 0
fi

# Merge .enabled-servers and .enabled-servers.local
mapfile -t ENABLED_SERVERS < <(
    { cat "$ENABLED_FILE" 2>/dev/null; cat "$ENABLED_LOCAL" 2>/dev/null; } | \
    sed '/^[[:space:]]*#/d;/^[[:space:]]*$/d' | \
    sort -u
)

if [[ ${#ENABLED_SERVERS[@]} -eq 0 ]]; then
    echo "No enabled servers found in $ENABLED_FILE" >&2
    exit 0
fi

# Build namespaced secrets JSON (ONLY enabled servers)
SECRETS_JSON="{}"
FETCH_ERRORS=0

for server in "${ENABLED_SERVERS[@]}"; do
    [[ -z "$server" ]] && continue

    if ! jq -e ".servers.\"$server\"" "$REGISTRY" >/dev/null 2>&1; then
        echo "WARNING: Server '$server' not found in registry" >&2
        continue
    fi

    # Read secrets for this server
    while IFS= read -r row; do
        [[ -z "$row" ]] && continue
        key=$(echo "$row" | base64 -d | jq -r '.key')
        op_ref=$(echo "$row" | base64 -d | jq -r '.value')

        if value=$(op read "$op_ref" 2>/dev/null); then
            if [[ -n "$value" ]]; then
                SECRETS_JSON=$(echo "$SECRETS_JSON" | jq \
                    --arg k "$key" --arg v "$value" '. + {($k): $v}')
            fi
        else
            echo "WARNING: Failed to read secret for $key" >&2
            ((FETCH_ERRORS++)) || true
        fi
    done < <(jq -r ".servers.\"$server\".secrets // {} | to_entries[] | @base64" "$REGISTRY")
done

# Encrypt with age keypair (correct usage: -r for recipient)
echo "$SECRETS_JSON" | age -r "$(cat "$AGE_RECIPIENT")" -o "$CACHE_DIR/secrets.enc"
chmod 600 "$CACHE_DIR/secrets.enc"

# Write metadata with epoch timestamps
NOW=$(date +%s)
cat > "$CACHE_DIR/secrets.meta" << EOF
{
  "project_name": "$PROJECT_NAME",
  "project_path": "$PROJECT_PATH",
  "project_id": "$PROJECT_ID",
  "refreshed_at": $NOW,
  "soft_expires_at": $((NOW + SOFT_TTL)),
  "hard_expires_at": $((NOW + HARD_TTL)),
  "enabled_servers": $(printf '%s\n' "${ENABLED_SERVERS[@]}" | jq -R . | jq -s .),
  "checksum": "$(shasum -a 256 "$CACHE_DIR/secrets.enc" | cut -d' ' -f1)"
}
EOF

# Audit log (refreshes only, not per-use)
echo "$NOW | $PROJECT_ID | $PROJECT_NAME | refreshed | servers: ${ENABLED_SERVERS[*]}" >> "$LOG_FILE"

echo "✅ Refreshed cache for $PROJECT_NAME (${#ENABLED_SERVERS[@]} servers)"
if [[ $FETCH_ERRORS -gt 0 ]]; then
    echo "⚠️  $FETCH_ERRORS secret(s) failed to fetch"
fi
