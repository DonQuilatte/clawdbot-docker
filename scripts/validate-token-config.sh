#!/bin/bash
# scripts/validate-token-config.sh
# Validates that tokens are consistent across all local and remote configurations.

set -euo pipefail

# Load common lib
# shellcheck source=lib/common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

TOKEN=$(get_gateway_token)

if [ -z "$TOKEN" ]; then
    echo "❌ ERROR: Failed to fetch CLAWDBOT_GATEWAY_TOKEN"
    exit 1
fi

echo "🔍 Validating tokens against .env (${TOKEN:0:8}...)"

# 1. Check local clawdbot.json
LOCAL_CONFIG="$HOME/.clawdbot/clawdbot.json"
if [ -f "$LOCAL_CONFIG" ]; then
    LOCAL_TOKEN=$(python3 -c "import json; print(json.load(open('$LOCAL_CONFIG')).get('gateway', {}).get('token', ''))" 2>/dev/null)
    if [ "$LOCAL_TOKEN" == "$TOKEN" ]; then
        echo "✅ Local config match"
    else
        echo "❌ Local config mismatch: ${LOCAL_TOKEN:0:8}..."
    fi
else
    echo "⚠️  Local config not found"
fi

# 2. Check TW Mac remote node
echo "📡 Checking TW Mac remote node..."
REMOTE_TOKEN=$(~/bin/tw run "python3 -c \"import json; print(json.load(open('.clawdbot/clawdbot.json')).get('gateway', {}).get('remote', {}).get('token', ''))\"" 2>/dev/null)

if [ "$REMOTE_TOKEN" == "$TOKEN" ]; then
    echo "✅ TW Mac remote node match"
else
    echo "❌ TW Mac remote node mismatch: ${REMOTE_TOKEN:0:8}..."
fi

# 3. Check Paired Devices on Gateway
PAIRED_CONFIG="$HOME/.clawdbot/devices/paired.json"
if [ -f "$PAIRED_CONFIG" ]; then
    # Find the TW device token
    TW_PAIRED_TOKEN=$(python3 -c "import json; d=json.load(open('$PAIRED_CONFIG')); print([v['tokens']['node']['token'] for k,v in d.items() if v.get('displayName') == 'TW'][0])" 2>/dev/null)
    if [ "$TW_PAIRED_TOKEN" == "$TOKEN" ]; then
         echo "✅ Gateway pairing match (TW)"
    else
         # Note: Remote nodes usually use device tokens, not the admin gateway token.
         # This check is subtle because Phase 1.1 aims to unify them or at least sync them.
         echo "ℹ️  Gateway pairing for TW is: ${TW_PAIRED_TOKEN:0:8}..."
    fi
fi

echo "---"
if [[ "$LOCAL_TOKEN" == "$TOKEN" ]] && [[ "$REMOTE_TOKEN" == "$TOKEN" ]]; then
    echo "✨ ALL TOKENS SYNCED"
else
    echo "⚠️  MISMATCH DETECTED"
    exit 1
fi
