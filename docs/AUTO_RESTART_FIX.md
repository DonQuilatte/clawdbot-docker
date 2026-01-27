# Auto-restart Fix for Remote Node

## Overview

This guide configures the remote Mac (192.168.1.245) to automatically start the Clawdbot node after system boot. Without this, you must manually start the node after every reboot.

---

## The Problem

**Current Behavior:**
- When remote Mac restarts, Clawdbot node does not start automatically
- User must SSH in and manually run `clawdbot node start`
- Results in downtime and manual intervention

**Desired Behavior:**
- Clawdbot node starts automatically at boot
- Reconnects to gateway within 30 seconds of startup
- Zero manual intervention required

---

## Solution: macOS LaunchAgent

macOS uses `launchd` for service management. We'll create a LaunchAgent that:
1. Runs at user login
2. Loads nvm environment
3. Starts Clawdbot node
4. Restarts on failure

---

## Quick Setup (Recommended)

**Run the automated script from your main Mac:**

```bash
# From main Mac - runs setup on remote automatically
~/Development/Projects/clawdbot/scripts/fix-auto-restart.sh
```

Or continue below for manual setup.

---

## Manual Setup Steps

### Step 1: SSH to Remote Mac

```bash
ssh tywhitaker@192.168.1.245
```

### Step 2: Create the Startup Script

This script handles nvm loading before starting Clawdbot:

```bash
mkdir -p ~/.clawdbot/scripts

cat > ~/.clawdbot/scripts/start-node.sh << 'EOF'
#!/bin/bash
# Clawdbot Node Startup Script
# Loads nvm and starts the node

# Log file for debugging
LOG_FILE="$HOME/.clawdbot/logs/startup.log"
mkdir -p "$(dirname "$LOG_FILE")"

exec >> "$LOG_FILE" 2>&1
echo "=========================================="
echo "Clawdbot Node Startup - $(date)"
echo "=========================================="

# Load nvm
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    echo "Loading nvm..."
    . "$NVM_DIR/nvm.sh"
else
    echo "ERROR: nvm not found at $NVM_DIR/nvm.sh"
    exit 1
fi

# Verify node is available
echo "Node version: $(node --version)"
echo "NPM version: $(npm --version)"

# Check if clawdbot is installed
if ! command -v clawdbot &> /dev/null; then
    echo "ERROR: clawdbot command not found"
    echo "PATH: $PATH"
    exit 1
fi

echo "Clawdbot version: $(clawdbot --version)"

# Wait for network to be available
echo "Waiting for network..."
sleep 10

# Test gateway connectivity
GATEWAY_URL="192.168.1.230"
GATEWAY_PORT="18789"
echo "Testing gateway connectivity to $GATEWAY_URL:$GATEWAY_PORT..."

for i in {1..30}; do
    if curl -s --connect-timeout 2 "http://$GATEWAY_URL:$GATEWAY_PORT/health" > /dev/null 2>&1; then
        echo "Gateway reachable on attempt $i"
        break
    fi
    echo "Attempt $i: Gateway not reachable, waiting..."
    sleep 2
done

# Start the node
echo "Starting Clawdbot node..."
clawdbot node start --host Mac.local --port 18789

echo "Startup script completed at $(date)"
EOF

chmod +x ~/.clawdbot/scripts/start-node.sh
```

### Step 3: Create the LaunchAgent plist

```bash
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
        <string>$HOME/.clawdbot/scripts/start-node.sh</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>

    <key>ThrottleInterval</key>
    <integer>30</integer>

    <key>StandardOutPath</key>
    <string>/Users/tywhitaker/.clawdbot/logs/launchd-stdout.log</string>

    <key>StandardErrorPath</key>
    <string>/Users/tywhitaker/.clawdbot/logs/launchd-stderr.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key>
        <string>/Users/tywhitaker</string>
    </dict>

    <key>WorkingDirectory</key>
    <string>/Users/tywhitaker</string>
</dict>
</plist>
EOF
```

### Step 4: Create Log Directory

```bash
mkdir -p ~/.clawdbot/logs
```

### Step 5: Load the LaunchAgent

```bash
# Unload if already loaded (ignore errors)
launchctl unload ~/Library/LaunchAgents/com.clawdbot.node.plist 2>/dev/null

# Load the new agent
launchctl load ~/Library/LaunchAgents/com.clawdbot.node.plist

# Verify it's loaded
launchctl list | grep clawdbot
```

### Step 6: Verify Setup

```bash
# Check LaunchAgent status
launchctl list | grep clawdbot

# View startup logs
cat ~/.clawdbot/logs/startup.log

# Check node status
clawdbot node status
```

---

## Verification

### Test Without Reboot

```bash
# Stop the node first
clawdbot node stop

# Unload and reload the agent
launchctl unload ~/Library/LaunchAgents/com.clawdbot.node.plist
launchctl load ~/Library/LaunchAgents/com.clawdbot.node.plist

# Wait 15 seconds for startup
sleep 15

# Check status
clawdbot node status
```

### Test With Reboot

```bash
# From remote Mac
sudo reboot

# Wait 2-3 minutes, then from main Mac:
ssh tywhitaker@192.168.1.245 'clawdbot node status'
```

---

## Troubleshooting

### Node Doesn't Start After Boot

**Check LaunchAgent is loaded:**
```bash
launchctl list | grep clawdbot
# Should show: -  0  com.clawdbot.node
```

**Check startup logs:**
```bash
cat ~/.clawdbot/logs/startup.log
cat ~/.clawdbot/logs/launchd-stdout.log
cat ~/.clawdbot/logs/launchd-stderr.log
```

**Check nvm is accessible:**
```bash
# Should show nvm directory
ls -la ~/.nvm
```

### Node Starts But Doesn't Connect

**Check gateway is reachable:**
```bash
curl -s http://192.168.1.230:18789/health
```

**Check configuration:**
```bash
cat ~/.clawdbot/clawdbot.json
```

**Expected output:**
```json
{
  "gateway": {
    "mode": "remote",
    "remote": {
      "url": "ws://192.168.1.230:18789",
      "token": "clawdbot-local-dev"
    }
  }
}
```

### LaunchAgent Won't Load

**Check plist syntax:**
```bash
plutil -lint ~/Library/LaunchAgents/com.clawdbot.node.plist
```

**Check file permissions:**
```bash
ls -la ~/Library/LaunchAgents/com.clawdbot.node.plist
# Should be: -rw-r--r--
```

**Fix permissions if needed:**
```bash
chmod 644 ~/Library/LaunchAgents/com.clawdbot.node.plist
```

### Multiple Instances Running

**Check for multiple processes:**
```bash
ps aux | grep clawdbot
```

**Kill all and restart:**
```bash
pkill -f clawdbot
launchctl unload ~/Library/LaunchAgents/com.clawdbot.node.plist
launchctl load ~/Library/LaunchAgents/com.clawdbot.node.plist
```

---

## Managing the LaunchAgent

### Start Service
```bash
launchctl load ~/Library/LaunchAgents/com.clawdbot.node.plist
```

### Stop Service
```bash
launchctl unload ~/Library/LaunchAgents/com.clawdbot.node.plist
```

### Restart Service
```bash
launchctl unload ~/Library/LaunchAgents/com.clawdbot.node.plist
launchctl load ~/Library/LaunchAgents/com.clawdbot.node.plist
```

### Check Status
```bash
launchctl list | grep clawdbot
```

### View Logs
```bash
# Startup script log
tail -f ~/.clawdbot/logs/startup.log

# LaunchAgent output
tail -f ~/.clawdbot/logs/launchd-stdout.log

# LaunchAgent errors
tail -f ~/.clawdbot/logs/launchd-stderr.log
```

### Disable Auto-start
```bash
launchctl unload ~/Library/LaunchAgents/com.clawdbot.node.plist
rm ~/Library/LaunchAgents/com.clawdbot.node.plist
```

---

## Remote Setup Commands

**Run all setup from main Mac:**

```bash
# Complete setup via SSH
ssh tywhitaker@192.168.1.245 << 'ENDSSH'
# Create directories
mkdir -p ~/.clawdbot/scripts
mkdir -p ~/.clawdbot/logs

# Create startup script
cat > ~/.clawdbot/scripts/start-node.sh << 'INNEREOF'
#!/bin/bash
LOG_FILE="$HOME/.clawdbot/logs/startup.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec >> "$LOG_FILE" 2>&1
echo "=========================================="
echo "Clawdbot Node Startup - $(date)"
echo "=========================================="
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
echo "Node: $(node --version), Clawdbot: $(clawdbot --version)"
sleep 10
for i in {1..30}; do
    curl -s --connect-timeout 2 "http://192.168.1.230:18789/health" > /dev/null 2>&1 && break
    sleep 2
done
clawdbot node start --host Mac.local --port 18789
echo "Startup completed at $(date)"
INNEREOF
chmod +x ~/.clawdbot/scripts/start-node.sh

# Create LaunchAgent
cat > ~/Library/LaunchAgents/com.clawdbot.node.plist << 'INNEREOF'
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
        <string>$HOME/.clawdbot/scripts/start-node.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>ThrottleInterval</key>
    <integer>30</integer>
    <key>StandardOutPath</key>
    <string>/Users/tywhitaker/.clawdbot/logs/launchd-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/tywhitaker/.clawdbot/logs/launchd-stderr.log</string>
    <key>WorkingDirectory</key>
    <string>/Users/tywhitaker</string>
</dict>
</plist>
INNEREOF

# Load agent
launchctl unload ~/Library/LaunchAgents/com.clawdbot.node.plist 2>/dev/null
launchctl load ~/Library/LaunchAgents/com.clawdbot.node.plist

echo "✅ Auto-restart configured!"
launchctl list | grep clawdbot
ENDSSH
```

---

## See Also

- [System Status](SYSTEM_STATUS.md) - Current system configuration
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues
- [Quick Reference](QUICK_REFERENCE.md) - Command cheat sheet

---

**Last Updated:** 2026-01-27
**Status:** ⚠️ Setup Required - Run `fix-auto-restart.sh` to configure
