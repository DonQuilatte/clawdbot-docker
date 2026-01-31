# Distributed System Quick Reference

Daily commands for managing the Brain/Agent distributed development setup.

For Docker commands, see [QUICK_REFERENCE.md](QUICK_REFERENCE.md).

---

## 🧠 Brain/Agent Architecture

| Role | Machine | Purpose |
|------|---------|---------|
| **Brain** | Main Mac (192.168.1.230) | Decision-making, orchestration, user interaction |
| **Agent Alpha** | TW Mac (192.168.1.245) | Task execution, builds, long-running processes |

### Primary Commands (New)

```bash
agent status              # Check all agent connectivity
agent dispatch "task"     # Send task to agent
agent results             # Collect results from agent
agent shell               # Open shell to agent
agent list                # Show configured agents
```

### Legacy Commands (Still Work)

```bash
tw status                 # Check TW Mac connectivity
tw run '<cmd>'            # Execute command on TW Mac
tw-handoff                # Create task handoff
```

---

## 🚀 Daily Operations

### Start Everything

```bash
# 1. Start gateway on main Mac
clawdbot gateway start

# 2. Verify remote node connected (should auto-connect if auto-restart configured)
clawdbot gateway status

# 3. Open dashboard
open http://localhost:18789
```

### Stop Everything

```bash
# Stop gateway (main Mac)
clawdbot gateway stop

# Stop remote node (optional - it will reconnect when gateway restarts)
ssh tywhitaker@192.168.1.245 'clawdbot node stop'
```

### Check Status

```bash
# Quick check
./scripts/verify-connection.sh --quick

# Full verification
./scripts/verify-connection.sh
```

---

## 📊 Status Commands

### Main Mac (Gateway)

```bash
# Gateway status
clawdbot gateway status

# Gateway logs
clawdbot gateway logs

# Follow logs
clawdbot gateway logs -f

# Dashboard
open http://localhost:18789

# Health check
curl http://localhost:18789/health
```

### Remote Mac (Node)

```bash
# Quick status check
ssh tywhitaker@192.168.1.245 'clawdbot node status'

# Full status with nvm
ssh tywhitaker@192.168.1.245 'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && clawdbot node status'

# View logs
ssh tywhitaker@192.168.1.245 'clawdbot node logs'

# Check auto-restart status
ssh tywhitaker@192.168.1.245 'launchctl list | grep clawdbot'
```

---

## 🔧 Restart Commands

### Restart Gateway

```bash
clawdbot gateway restart
# or
clawdbot gateway stop && clawdbot gateway start
```

### Restart Remote Node

```bash
ssh tywhitaker@192.168.1.245 'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && clawdbot node restart'
```

### Restart Auto-start Service

```bash
ssh tywhitaker@192.168.1.245 'launchctl unload ~/Library/LaunchAgents/com.clawdbot.node.plist && launchctl load ~/Library/LaunchAgents/com.clawdbot.node.plist'
```

---

## 🔍 Troubleshooting Commands

### Network Tests

```bash
# Test gateway reachable
curl -s http://localhost:18789/health && echo "OK"

# Test remote Mac reachable
ping -c 1 192.168.1.245

# Test SSH
ssh -o ConnectTimeout=5 tywhitaker@192.168.1.245 'echo OK'

# Test gateway from remote
ssh tywhitaker@192.168.1.245 'curl -s http://192.168.1.230:18789/health'
```

### Process Checks

```bash
# Gateway processes
pgrep -fl clawdbot

# Port 18789 usage
lsof -i :18789

# Remote processes
ssh tywhitaker@192.168.1.245 'pgrep -fl clawdbot'
```

### Log Checks

```bash
# Gateway errors
clawdbot gateway logs | grep -i error

# Remote startup log
ssh tywhitaker@192.168.1.245 'tail -20 ~/.clawdbot/logs/startup.log'

# Remote LaunchAgent errors
ssh tywhitaker@192.168.1.245 'cat ~/.clawdbot/logs/launchd-stderr.log'
```

---

## 📝 Configuration

### View Configs

```bash
# Main Mac config
cat ~/.clawdbot/clawdbot.json

# Remote config
ssh tywhitaker@192.168.1.245 'cat ~/.clawdbot/clawdbot.json'

# SSH config
cat ~/.ssh/config
```

### Edit Remote Config

```bash
ssh tywhitaker@192.168.1.245 'vim ~/.clawdbot/clawdbot.json'
```

---

## 🔐 SSH Commands

```bash
# Connect to remote
ssh tywhitaker@192.168.1.245

# Run command on remote
ssh tywhitaker@192.168.1.245 'command here'

# Copy file to remote
scp localfile tywhitaker@192.168.1.245:~/

# Copy file from remote
scp tywhitaker@192.168.1.245:~/remotefile ./
```

---

## ⚡ One-Liners

### Start Node Manually on Remote

```bash
ssh tywhitaker@192.168.1.245 'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && clawdbot node start --host Mac.local --port 18789'
```

### Full Health Check

```bash
echo "Gateway: $(curl -s http://localhost:18789/health > /dev/null && echo ✅ || echo ❌)" && echo "SSH: $(ssh -o ConnectTimeout=3 tywhitaker@192.168.1.245 'echo OK' 2>/dev/null && echo ✅ || echo ❌)" && echo "Node: $(ssh tywhitaker@192.168.1.245 'clawdbot node status 2>&1' | grep -qi connected && echo ✅ || echo ❌)"
```

### View All Logs

```bash
# Gateway + remote in parallel
clawdbot gateway logs & ssh tywhitaker@192.168.1.245 'tail -f ~/.clawdbot/logs/startup.log'
```

---

## 📁 Important Paths

### Main Mac

| Path | Description |
|------|-------------|
| `~/.clawdbot/clawdbot.json` | Gateway configuration |
| `~/.ssh/config` | SSH configuration |
| `~/.ssh/id_ed25519_clawdbot` | SSH key for remote |
| `~/Development/Projects/clawdbot/` | Project directory |

### Remote Mac

| Path | Description |
|------|-------------|
| `~/.clawdbot/clawdbot.json` | Node configuration |
| `~/.clawdbot/logs/startup.log` | Startup script log |
| `~/.clawdbot/logs/launchd-*.log` | LaunchAgent logs |
| `~/.clawdbot/scripts/start-node.sh` | Startup script |
| `~/Library/LaunchAgents/com.clawdbot.node.plist` | Auto-start config |

---

## 🌐 Network Info

| Resource | Address |
|----------|---------|
| Main Mac | 192.168.1.230 |
| Remote Mac | 192.168.1.245 |
| Gateway Port | 18789 |
| Dashboard | http://localhost:18789 |
| SSH | tywhitaker@192.168.1.245 |

---

## 📜 Scripts

```bash
# Verify all connections
./scripts/verify-connection.sh

# Fix auto-restart
./scripts/fix-auto-restart.sh

# Setup Tailscale (optional)
./scripts/setup-tailscale.sh

# Install OrbStack on remote (optional)
./scripts/install-orbstack-remote.sh
```

---

## 🆘 Emergency

### Kill All Clawdbot Processes

```bash
# Main Mac
pkill -f clawdbot

# Remote
ssh tywhitaker@192.168.1.245 'pkill -f clawdbot'
```

### Clear Locks and Restart

```bash
# Main Mac
rm -f ~/.clawdbot/*.lock
clawdbot gateway start

# Remote
ssh tywhitaker@192.168.1.245 'rm -f ~/.clawdbot/*.lock && clawdbot node start'
```

### Reboot Remote Mac

```bash
ssh tywhitaker@192.168.1.245 'sudo reboot'
# Wait 2-3 minutes, then verify:
./scripts/verify-connection.sh --quick
```

---

## 📚 Documentation

- [System Status](SYSTEM_STATUS.md) - Current configuration
- [Auto-restart Fix](AUTO_RESTART_FIX.md) - LaunchAgent setup
- [Remote Access Guide](REMOTE_ACCESS_GUIDE.md) - Access methods & Tailscale
- [Distributed Troubleshooting](DISTRIBUTED_TROUBLESHOOTING.md) - Problem solving

---

**Last Updated:** 2026-01-31
