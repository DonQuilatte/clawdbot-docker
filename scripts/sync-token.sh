#!/bin/bash
# scripts/sync-token.sh
# Synchronizes the CLAWDBOT_GATEWAY_TOKEN from .env to local and remote config files.

set -euo pipefail

# Check for .env
if [ ! -f .env ]; then
    echo "❌ ERROR: .env file not found"
    exit 1
fi

# Load token from .env
TOKEN=$(grep "^CLAWDBOT_GATEWAY_TOKEN=" .env | cut -d= -f2)

if [ -z "$TOKEN" ]; then
    echo "❌ ERROR: CLAWDBOT_GATEWAY_TOKEN not set in .env"
    exit 1
fi

echo "🔄 Synchronizing token: ${TOKEN:0:8}..."

# 1. Update local clawdbot.json
LOCAL_CONFIG="$HOME/.clawdbot/clawdbot.json"
if [ -f "$LOCAL_CONFIG" ]; then
    echo "📝 Updating local config: $LOCAL_CONFIG"
    TOKEN="$TOKEN" LOCAL_CONFIG="$LOCAL_CONFIG" python3 -c "
import json, os
token = os.environ['TOKEN']
path = os.environ['LOCAL_CONFIG']
with open(path) as f: config = json.load(f)
config.setdefault('gateway', {})['token'] = token
with open(path, 'w') as f: json.dump(config, f, indent=2)
"
    echo "✅ Local config updated"
fi

# 2. Update TW Mac remote node
echo "📡 Updating TW Mac remote node..."
TOKEN="$TOKEN" ~/bin/tw run "TOKEN=\"\$TOKEN\" python3 -c \"
import json, os
token = os.environ['TOKEN']
path = os.path.expanduser('~/.clawdbot/clawdbot.json')
with open(path) as f: config = json.load(f)
if 'gateway' in config and 'remote' in config['gateway']:
    config['gateway']['remote']['token'] = token
with open(path, 'w') as f: json.dump(config, f, indent=2)
\""

if [ $? -eq 0 ]; then
    echo "✅ TW Mac remote node updated"
else
    echo "❌ Failed to update TW Mac"
    exit 1
fi

# 3. Update Gateway Pairing Table
# We update the pairing table so that the gateway recognizes the node's new token.
PAIRED_CONFIG="$HOME/.clawdbot/devices/paired.json"
if [ -f "$PAIRED_CONFIG" ]; then
    echo "📝 Updating gateway pairing table for TW..."
    TOKEN="$TOKEN" PAIRED_CONFIG="$PAIRED_CONFIG" python3 -c "
import json, os
token = os.environ['TOKEN']
path = os.environ['PAIRED_CONFIG']
with open(path) as f: d = json.load(f)
for k, v in d.items():
    if v.get('displayName') == 'TW':
        v['tokens']['node']['token'] = token
with open(path, 'w') as f: json.dump(d, f, indent=2)
"
    echo "✅ Gateway pairing updated"
fi

echo "🚀 Restarting services..."
# Restart local gateway
launchctl unload ~/Library/LaunchAgents/com.clawdbot.gateway.plist 2>/dev/null
launchctl load ~/Library/LaunchAgents/com.clawdbot.gateway.plist
echo "✅ Local gateway reloaded"

# TW Mac node doesn't have a direct restart command in tw-control.sh, 
# but we can trigger it via launchctl on remote.
~/bin/tw run "launchctl unload ~/Library/LaunchAgents/com.clawdbot.node.plist 2>/dev/null; launchctl load ~/Library/LaunchAgents/com.clawdbot.node.plist"
echo "✅ TW Mac node reloaded"

echo "✨ Sync complete. Running validation..."
./scripts/validate-token-config.sh
