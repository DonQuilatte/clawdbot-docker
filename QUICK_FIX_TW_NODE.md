# Quick Fix: TW Node Connection Issue

**Date:** 2026-01-28  
**Duration:** 30 minutes  
**Goal:** Get TW node connected right now

---

## The Problem

Your TW node can't connect because:

1. Tokens are inconsistent across multiple locations
2. The node was deleted (`rm -rf ~/.clawdbot`) and needs reconfiguration
3. Device pairing is broken

## The Quick Fix

### Step 1: Check Current Token (On Gateway)

```bash
cd ~/Development/Projects/clawdbot

# What token is the gateway expecting?
grep "CLAWDBOT_GATEWAY_TOKEN" .env
```

Expected output:

```
CLAWDBOT_GATEWAY_TOKEN=clawdbot-local-dev
```

**Note this token.** We'll use it for the node.

### Step 2: Check Gateway Config

```bash
# Check if gateway has token override
cat ~/.clawdbot/clawdbot.json
```

Look for:

```json
{
  "gateway": {
    "token": "some-token-here"
  }
}
```

If the token in the config file is DIFFERENT from `.env`, that's your problem.

**Fix:** Remove the token from the config file (let it use the environment variable):

```bash
python3 << 'EOF'
import json

# Read config
with open('/Users/jederlichman/.clawdbot/clawdbot.json') as f:
    config = json.load(f)

# Remove token from gateway config (use env var instead)
if 'gateway' in config and 'token' in config['gateway']:
    del config['gateway']['token']

# Write back
with open('/Users/jederlichman/.clawdbot/clawdbot.json', 'w') as f:
    json.dump(config, f, indent=2)

print("✅ Removed token from gateway config - will use .env")
EOF
```

### Step 3: Restart Gateway with Token

```bash
# Make sure token is in environment
source .env

# Restart gateway
clawdbot gateway stop
clawdbot gateway start --bind lan

# Verify it's running
curl http://localhost:18789/health
```

### Step 4: Reconfigure TW Node (SSH to TW)

```bash
# SSH to TW node
ssh tywhitaker@192.168.1.245

# Verify clawdbot is installed
clawdbot --version
```

If `clawdbot: command not found`:

```bash
# Load nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# Check again
clawdbot --version
```

### Step 5: Create Node Configuration

```bash
# On TW node (via SSH)
mkdir -p ~/.clawdbot

# Use the SAME token from gateway .env
cat > ~/.clawdbot/clawdbot.json << 'EOF'
{
  "meta": {
    "lastTouchedVersion": "2026.1.24-3"
  },
  "gateway": {
    "mode": "remote",
    "remote": {
      "url": "ws://192.168.1.230:18789",
      "token": "clawdbot-local-dev"
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/Users/tywhitaker",
      "maxConcurrent": 2
    }
  }
}
EOF

echo "✅ Created node configuration"
```

**IMPORTANT:** Replace `clawdbot-local-dev` with the actual token from your gateway's `.env` file.

### Step 6: Start Node

```bash
# On TW node
clawdbot node start --host 192.168.1.230 --port 18789

# Check if it's running
clawdbot node status
```

Expected output:

```
Status: Connected
Gateway: ws://192.168.1.230:18789
```

### Step 7: Verify Connection (On Gateway)

```bash
# Back on your main Mac
cd ~/Development/Projects/clawdbot

# Check if gateway sees the node
CLAWDBOT_GATEWAY_TOKEN=$(grep "CLAWDBOT_GATEWAY_TOKEN" .env | cut -d= -f2) \
  clawdbot nodes status

# Should show TW node
```

### Step 8: Check Device Pairing

```bash
# On gateway
CLAWDBOT_GATEWAY_TOKEN=$(grep "CLAWDBOT_GATEWAY_TOKEN" .env | cut -d= -f2) \
  clawdbot devices list --json
```

If the TW device is in `"pending"`:

```bash
# Get the device ID
DEVICE_ID=$(clawdbot devices list --json | jq -r '.pending[0].id')

# Approve it
CLAWDBOT_GATEWAY_TOKEN=$(grep "CLAWDBOT_GATEWAY_TOKEN" .env | cut -d= -f2) \
  clawdbot devices approve --device-id "$DEVICE_ID"
```

### Step 9: Test Remote Execution

```bash
# Try running a command on TW
CLAWDBOT_GATEWAY_TOKEN=$(grep "CLAWDBOT_GATEWAY_TOKEN" .env | cut -d= -f2) \
  clawdbot nodes run --node TW -- hostname

# Should return: TW
```

---

## If This Doesn't Work

### Diagnostic Checklist

1. **Gateway not reachable from TW?**

   ```bash
   # On TW node
   curl http://192.168.1.230:18789/health

   # Should return: OK
   ```

2. **Token mismatch?**

   ```bash
   # Run the validator
   cd ~/Development/Projects/clawdbot
   ./scripts/validate-token-config.sh
   ```

3. **WebSocket connection failing?**

   ```bash
   # Check gateway logs
   tail -f ~/.clawdbot/logs/gateway.log

   # Look for connections from 192.168.1.245
   ```

4. **Node process not running?**

   ```bash
   # On TW
   ps aux | grep clawdbot

   # Check error logs
   tail -f ~/.clawdbot/logs/node.err.log
   ```

---

## Make It Permanent (LaunchAgent)

Once the node is connected, make it auto-start on boot:

```bash
# On TW node
cat > ~/Library/LaunchAgents/com.clawdbot.node.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.clawdbot.node</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>
            # Load nvm
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] &amp;&amp; . "$NVM_DIR/nvm.sh"

            # Start node
            exec clawdbot node start --host 192.168.1.230 --port 18789
        </string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/clawdbot-node.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/clawdbot-node.err.log</string>
</dict>
</plist>
EOF

# Load it
launchctl load ~/Library/LaunchAgents/com.clawdbot.node.plist

# Verify
launchctl list | grep clawdbot
```

---

## Success Checklist

- [ ] Gateway is running on 192.168.1.230:18789
- [ ] Gateway health check returns OK: `curl http://localhost:18789/health`
- [ ] Node config exists: `ls ~/.clawdbot/clawdbot.json` (on TW)
- [ ] Node is running: `clawdbot node status` shows "Connected" (on TW)
- [ ] Gateway sees node: `clawdbot nodes status` shows TW (on gateway)
- [ ] Device is approved: `clawdbot devices list` shows TW in "paired" (on gateway)
- [ ] Remote execution works: `clawdbot nodes run --node TW -- hostname` (on gateway)
- [ ] LaunchAgent is loaded: `launchctl list | grep clawdbot` (on TW)

---

## Common Issues

### Issue: "command not found: clawdbot"

**On TW node:**

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
clawdbot --version
```

### Issue: "WebSocket connection failed"

**Check token matches:**

```bash
# Gateway
grep "CLAWDBOT_GATEWAY_TOKEN" ~/Development/Projects/clawdbot/.env

# TW Node
grep "token" ~/.clawdbot/clawdbot.json
```

They must be IDENTICAL.

### Issue: "Device pending approval"

```bash
# List pending devices
clawdbot devices list --json | jq '.pending'

# Approve the first one
DEVICE_ID=$(clawdbot devices list --json | jq -r '.pending[0].id')
clawdbot devices approve --device-id "$DEVICE_ID"
```

### Issue: "Gateway not accessible"

```bash
# Check gateway is bound to LAN
lsof -i :18789

# Should show:
# node ... *:18789 (LISTEN)
# Or: 0.0.0.0:18789

# If it shows 127.0.0.1:18789, restart with:
clawdbot gateway start --bind lan
```

---

## Next Steps

After you get it working:

1. **Run the validator** to check for other issues:

   ```bash
   ./scripts/validate-token-config.sh
   ```

2. **Read the full review** (optional):

   ```bash
   cat TOKEN_SUMMARY.md
   ```

3. **Implement long-term fix** (recommended):
   - Follow Phase 1 in `TOKEN_IMPLEMENTATION_PLAN.md`
   - Takes ~2 hours
   - Prevents this issue from happening again

---

**Need help?** Check the detailed troubleshooting in:

- `TW_NODE_HANDOFF.md` - Previous debugging session
- `TOKEN_ARCHITECTURE_REVIEW.md` - Full analysis
- `docs/DISTRIBUTED_TROUBLESHOOTING.md` - General troubleshooting
