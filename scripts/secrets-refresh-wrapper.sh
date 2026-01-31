#!/usr/bin/env bash
# secrets-refresh-wrapper.sh - LaunchAgent wrapper for headless secrets refresh
# RFC v2.1: Loads token from secure file, then refreshes all registered projects

set -euo pipefail

# Load service account token from secure file (NOT hardcoded anywhere)
TOKEN_FILE="$HOME/.config/op/service-account-token"

if [[ -f "$TOKEN_FILE" ]]; then
    export OP_SERVICE_ACCOUNT_TOKEN=$(cat "$TOKEN_FILE")
else
    echo "ERROR: Token file not found: $TOKEN_FILE" >&2
    exit 1
fi

# Refresh all registered projects
exec "$HOME/Development/Projects/dev-infra/scripts/dev-infra" secrets refresh-all
