# Distributed System Troubleshooting

This guide covers troubleshooting for the two-Mac Clawdbot distributed setup.

For Docker-specific issues, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

---

## Table of Contents

- [Quick Diagnostics](#quick-diagnostics)
- [Gateway Issues](#gateway-issues)
- [Remote Node Issues](#remote-node-issues)
- [Network Issues](#network-issues)
- [SSH Issues](#ssh-issues)
- [Auto-restart Issues](#auto-restart-issues)
- [Configuration Issues](#configuration-issues)
- [Complete Reset](#complete-reset)

---

## Quick Diagnostics

### Run Full Verification

```bash
# From main Mac
~/Development/Projects/clawdbot/scripts/verify-connection.sh

# Quick 3-point check
~/Development/Projects/clawdbot/scripts/verify-connection.sh --quick
```

### One-liner Health Check

```bash
# Check everything in one command
echo "Gateway: $(curl -s http://localhost:18789/health > /dev/null && echo OK || echo FAIL)" && \
echo "SSH: $(ssh -o ConnectTimeout=3 tywhitaker@192.168.1.245 'echo OK' 2>/dev/null || echo FAIL)" && \
echo "Node: $(ssh tywhitaker@192.168.1.245 'clawdbot node status 2>&1 | grep -qi connected && echo OK || echo FAIL' 2>/dev/null)"
```

---

## Gateway Issues

### Gateway Not Starting

**Symptoms:**
- `clawdbot gateway start` fails
- Port 18789 not listening
- Dashboard not accessible

**Diagnosis:**
```bash
# Check if port is in use
lsof -i :18789

# Check for existing processes
pgrep -f clawdbot

# View gateway logs
clawdbot gateway logs
```

**Solutions:**

```bash
# Kill existing processes
pkill -f clawdbot

# Clear lock files (if any)
rm -f ~/.clawdbot/*.lock

# Restart gateway
clawdbot gateway start

# Verify
curl http://localhost:18789/health
```

### Gateway Running But No Dashboard

**Symptoms:**
- Gateway shows running
- http://localhost:18789 not loading

**Solutions:**

```bash
# Check binding address
cat ~/.clawdbot/clawdbot.json | grep -A5 gateway

# Ensure bound to correct interface
# If bound to 127.0.0.1, dashboard only accessible locally

# Check firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# Test from command line
curl -v http://localhost:18789/health
```

### Gateway Crashes/Restarts

**Symptoms:**
- Gateway starts then stops
- Repeated restarts in logs

**Solutions:**

```bash
# Check logs for errors
clawdbot gateway logs | grep -i error

# Check system resources
top -l 1 | head -20

# Try with debug logging
CLAWDBOT_LOG_LEVEL=debug clawdbot gateway start

# Check configuration is valid
cat ~/.clawdbot/clawdbot.json | python3 -m json.tool
```

---

## Remote Node Issues

### Node Won't Connect

**Symptoms:**
- Node shows "disconnected"
- Gateway doesn't show remote node

**Diagnosis:**
```bash
# From remote Mac (via SSH)
ssh tywhitaker@192.168.1.245

# Check node status
clawdbot node status

# Check configuration
cat ~/.clawdbot/clawdbot.json

# Test gateway connectivity
curl http://192.168.1.230:18789/health
```

**Solutions:**

```bash
# Verify configuration
# Should show ws://192.168.1.230:18789 or ws://Mac.local:18789
cat ~/.clawdbot/clawdbot.json | grep -A3 remote

# Fix configuration if needed
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

# Restart node
clawdbot node restart
```

### Node Command Not Found

**Symptoms:**
- `clawdbot: command not found` on remote

**Solutions:**

```bash
# Load nvm first
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# Check node version
node --version

# Check if clawdbot is installed
npm list -g clawdbot

# Reinstall if needed
npm install -g clawdbot@latest

# Verify
clawdbot --version
```

### Node Connected But Not Working

**Symptoms:**
- Node shows connected
- Tasks not running on remote

**Diagnosis:**
```bash
# Check node logs
clawdbot node logs

# Check workspace permissions
ls -la ~/

# Verify agent configuration
cat ~/.clawdbot/clawdbot.json | grep -A5 agents
```

---

## Network Issues

### Cannot Reach Remote Mac

**Symptoms:**
- Ping fails
- SSH times out

**Diagnosis:**
```bash
# Test basic connectivity
ping 192.168.1.245

# Check if remote is on network
arp -a | grep 192.168.1.245

# Test SSH port
nc -zv 192.168.1.245 22
```

**Solutions:**

```bash
# Verify IP address hasn't changed
# On remote Mac, check: System Settings > Network > Wi-Fi > Details > IP Address

# If IP changed, update SSH config
vim ~/.ssh/config
# Update HostName to new IP

# Update Clawdbot config on remote
ssh tywhitaker@NEW_IP
# Update ~/.clawdbot/clawdbot.json with correct gateway IP
```

### Remote Cannot Reach Gateway

**Symptoms:**
- Remote node can't connect
- WebSocket connection fails

**Diagnosis (from remote):**
```bash
# Test HTTP connectivity
curl http://192.168.1.230:18789/health

# Test WebSocket (basic check)
curl -H "Upgrade: websocket" -H "Connection: Upgrade" http://192.168.1.230:18789

# Check DNS resolution
ping Mac.local
```

**Solutions:**

```bash
# On main Mac, ensure gateway binds to all interfaces
# Check config:
cat ~/.clawdbot/clawdbot.json | grep bind

# If bound to localhost only, change to 0.0.0.0:
# Edit config and restart gateway

# Check firewall allows incoming on 18789
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --listapps

# Use IP instead of hostname in remote config
# Change ws://Mac.local:18789 to ws://192.168.1.230:18789
```

### Intermittent Connection Drops

**Symptoms:**
- Node connects then disconnects
- Works sometimes, fails other times

**Solutions:**

```bash
# Check for IP conflicts
arp -a | grep -E "192.168.1.(230|245)"

# Assign static IPs to both Macs
# System Settings > Network > Wi-Fi > Details > TCP/IP > Configure IPv4: Manually

# Check router DHCP leases
# Most routers: http://192.168.1.1 > DHCP > Client List

# Enable keep-alive in SSH config
# Add to ~/.ssh/config:
# ServerAliveInterval 60
# ServerAliveCountMax 3
```

---

## SSH Issues

### Passwordless SSH Not Working

**Symptoms:**
- SSH prompts for password
- Key authentication fails

**Diagnosis:**
```bash
# Test with verbose output
ssh -v tywhitaker@192.168.1.245

# Check if key exists
ls -la ~/.ssh/id_ed25519_clawdbot

# Check key is loaded
ssh-add -l
```

**Solutions:**

```bash
# Generate new key if missing
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_clawdbot -N ""

# Copy key to remote
ssh-copy-id -i ~/.ssh/id_ed25519_clawdbot tywhitaker@192.168.1.245

# Fix SSH config
cat >> ~/.ssh/config << 'EOF'

Host 192.168.1.245
    User tywhitaker
    IdentityFile ~/.ssh/id_ed25519_clawdbot
    IdentitiesOnly yes
EOF

# Fix permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519_clawdbot
chmod 644 ~/.ssh/id_ed25519_clawdbot.pub
chmod 600 ~/.ssh/config

# Test
ssh tywhitaker@192.168.1.245 "echo Success"
```

### SSH Connection Refused

**Symptoms:**
- `Connection refused` error
- Port 22 not responding

**Solutions:**

```bash
# On remote Mac, enable Remote Login:
# System Settings > General > Sharing > Remote Login: ON

# Check Remote Login is enabled
ssh tywhitaker@192.168.1.245  # Will fail if disabled

# From remote Mac directly, verify sshd:
sudo launchctl list | grep ssh
```

---

## Auto-restart Issues

### Node Doesn't Start After Reboot

**Symptoms:**
- After remote Mac reboots, node is offline
- LaunchAgent not working

**Diagnosis:**
```bash
# Check if LaunchAgent exists
ssh tywhitaker@192.168.1.245 'ls -la ~/Library/LaunchAgents/com.clawdbot.node.plist'

# Check if loaded
ssh tywhitaker@192.168.1.245 'launchctl list | grep clawdbot'

# Check startup logs
ssh tywhitaker@192.168.1.245 'cat ~/.clawdbot/logs/startup.log'
```

**Solutions:**

```bash
# Run setup script
~/Development/Projects/clawdbot/scripts/fix-auto-restart.sh

# Or manually fix:
ssh tywhitaker@192.168.1.245 << 'EOF'
# Unload and reload
launchctl unload ~/Library/LaunchAgents/com.clawdbot.node.plist 2>/dev/null
launchctl load ~/Library/LaunchAgents/com.clawdbot.node.plist

# Verify
launchctl list | grep clawdbot
EOF
```

### LaunchAgent Plist Invalid

**Symptoms:**
- `launchctl load` fails with error
- Plist syntax errors

**Solutions:**

```bash
# Validate plist syntax
ssh tywhitaker@192.168.1.245 'plutil -lint ~/Library/LaunchAgents/com.clawdbot.node.plist'

# Recreate if invalid
~/Development/Projects/clawdbot/scripts/fix-auto-restart.sh
```

### Startup Script Fails

**Symptoms:**
- LaunchAgent loads but node doesn't start
- Errors in startup log

**Diagnosis:**
```bash
# Check startup log
ssh tywhitaker@192.168.1.245 'tail -50 ~/.clawdbot/logs/startup.log'

# Check launchd error log
ssh tywhitaker@192.168.1.245 'cat ~/.clawdbot/logs/launchd-stderr.log'
```

**Common fixes:**

```bash
# nvm not loading
# Edit ~/.clawdbot/scripts/start-node.sh to ensure correct nvm path

# Gateway not reachable at boot
# Increase sleep time in startup script (network may take longer)

# Clawdbot command not found
# Ensure nvm is sourced before calling clawdbot
```

---

## Configuration Issues

### Invalid JSON Configuration

**Symptoms:**
- Clawdbot commands fail with parse errors
- Config file corrupted

**Solutions:**

```bash
# Validate JSON
cat ~/.clawdbot/clawdbot.json | python3 -m json.tool

# Backup and recreate
cp ~/.clawdbot/clawdbot.json ~/.clawdbot/clawdbot.json.bak

# Create fresh config (adjust values as needed)
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
  }
}
EOF
```

### Token Mismatch

**Symptoms:**
- Node connects but authentication fails
- "Invalid token" errors

**Solutions:**

```bash
# Check tokens match
# Main Mac:
cat ~/.clawdbot/clawdbot.json | grep token

# Remote Mac:
ssh tywhitaker@192.168.1.245 'cat ~/.clawdbot/clawdbot.json | grep token'

# Update if different
# For local dev, both should use: "clawdbot-local-dev"
```

---

## Complete Reset

### Reset Remote Node

```bash
ssh tywhitaker@192.168.1.245 << 'EOF'
# Stop node
clawdbot node stop 2>/dev/null

# Unload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.clawdbot.node.plist 2>/dev/null

# Remove configuration
rm -rf ~/.clawdbot

# Reinstall
npm install -g clawdbot@latest

# Reconfigure
mkdir -p ~/.clawdbot
cat > ~/.clawdbot/clawdbot.json << 'INNEREOF'
{
  "gateway": {
    "mode": "remote",
    "remote": {
      "url": "ws://192.168.1.230:18789",
      "token": "clawdbot-local-dev"
    }
  }
}
INNEREOF

# Start
clawdbot node start --host Mac.local --port 18789
EOF

# Then reconfigure auto-restart
~/Development/Projects/clawdbot/scripts/fix-auto-restart.sh
```

### Reset Main Mac Gateway

```bash
# Stop gateway
clawdbot gateway stop

# Backup config
cp ~/.clawdbot/clawdbot.json ~/.clawdbot/clawdbot.json.bak

# Clear state
rm -rf ~/.clawdbot/*.lock

# Reinstall
npm install -g clawdbot@latest

# Restore/recreate config
cat > ~/.clawdbot/clawdbot.json << 'EOF'
{
  "gateway": {
    "mode": "local",
    "bind": "0.0.0.0",
    "port": 18789
  }
}
EOF

# Start
clawdbot gateway start

# Verify
curl http://localhost:18789/health
```

---

## Getting Help

If these solutions don't resolve your issue:

1. **Collect diagnostics:**
   ```bash
   # Run verification script and save output
   ./scripts/verify-connection.sh > diagnostics.txt 2>&1

   # Get logs
   clawdbot gateway logs > gateway-logs.txt
   ssh tywhitaker@192.168.1.245 'cat ~/.clawdbot/logs/startup.log' > remote-logs.txt
   ```

2. **Check documentation:**
   - [System Status](SYSTEM_STATUS.md) - Current configuration
   - [Auto-restart Fix](AUTO_RESTART_FIX.md) - LaunchAgent setup
   - [Remote Access Guide](REMOTE_ACCESS_GUIDE.md) - Network access methods

3. **Report issues:**
   - GitHub: https://github.com/clawdbot/clawdbot/issues

---

**Last Updated:** 2026-01-27
