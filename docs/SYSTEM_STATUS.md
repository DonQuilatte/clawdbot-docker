# Clawdbot Distributed System Status

## Overview

This document tracks the current working configuration of the Clawdbot distributed system across two Macs.

---

## Network Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                     Home Network (192.168.1.x)                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────┐    ┌─────────────────────────┐ │
│  │       MAIN MAC              │    │       REMOTE MAC        │ │
│  │   (Gateway/Controller)      │    │     (Worker Node)       │ │
│  │                             │    │                         │ │
│  │  IP: 192.168.1.230          │    │  IP: 192.168.1.245      │ │
│  │  User: jederlichman         │    │  User: tywhitaker       │ │
│  │  Hostname: Mac              │    │  Hostname: TW           │ │
│  │                             │    │                         │ │
│  │  ┌─────────────────────┐   │    │  ┌─────────────────────┐│ │
│  │  │ Clawdbot Gateway    │   │◄───┼──│ Clawdbot Node       ││ │
│  │  │ Port: 18789         │   │    │  │ WebSocket Client    ││ │
│  │  │ Version: 2026.1.23-1│   │    │  │ Version: 2026.1.24-3││ │
│  │  └─────────────────────┘   │    │  └─────────────────────┘│ │
│  │                             │    │                         │ │
│  │  Services:                  │    │  Status:                │ │
│  │  ✅ Gateway Running         │    │  ✅ Connected to Gateway│ │
│  │  ✅ Dashboard Active        │    │  ✅ Auto-restart Active │ │
│  │  ✅ OrbStack + Docker       │    │  ✅ Firewall Enabled    │ │
│  │  ✅ Claude Code 2.1.20      │    │  ✅ Claude Code 2.1.20  │ │
│  │                             │    │                         │ │
│  └─────────────────────────────┘    └─────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## System Components

### Main Mac (192.168.1.230)

| Component | Version | Status | Notes |
|-----------|---------|--------|-------|
| **macOS** | Latest | ✅ | Primary workstation |
| **Clawdbot Gateway** | 2026.1.23-1 | ✅ Running | Listening on port 18789 |
| **Claude Code** | 2.1.20 | ✅ | Installed via npm |
| **Node.js** | v25.4.0 | ✅ | Managed via nvm |
| **OrbStack** | Latest | ✅ | Docker management |
| **Docker** | Latest | ✅ | Via OrbStack |
| **SSH Server** | Built-in | ✅ | Remote Login enabled |

**User Details:**
- Username: `jederlichman`
- Home: `/Users/jederlichman`
- Clawdbot Config: `~/.clawdbot/clawdbot.json`

### Remote Mac (192.168.1.245)

| Component | Version | Status | Notes |
|-----------|---------|--------|-------|
| **macOS** | Latest | ✅ | Worker node |
| **Clawdbot Node** | 2026.1.24-3 | ✅ Connected | Connected to gateway |
| **Claude Code** | 2.1.20 | ✅ | Installed via npm |
| **Node.js** | v24.13.0 | ✅ | Managed via nvm |
| **OrbStack** | N/A | ❌ Not Installed | Optional |
| **Docker** | N/A | ❌ Not Installed | Optional |
| **SSH Server** | Built-in | ✅ | Remote Login enabled |
| **Firewall** | Built-in | ✅ Enabled | Node.js allowed |
| **Auto-restart** | LaunchAgent | ✅ Configured | Auto-starts on boot |

**User Details:**
- Username: `tywhitaker`
- Home: `/Users/tywhitaker`
- Clawdbot Config: `~/.clawdbot/clawdbot.json`

---

## Configuration Files

### Main Mac Gateway Config

Location: `~/.clawdbot/clawdbot.json`

```json
{
  "meta": {
    "lastTouchedVersion": "2026.1.23-1"
  },
  "gateway": {
    "mode": "local",
    "bind": "0.0.0.0",
    "port": 18789
  },
  "agents": {
    "defaults": {
      "workspace": "/Users/jederlichman",
      "maxConcurrent": 4
    }
  }
}
```

### Remote Mac Node Config

Location: `~/.clawdbot/clawdbot.json`

```json
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
```

---

## SSH Configuration

### SSH Key Setup

**Key Location:** `~/.ssh/id_ed25519_clawdbot`

**SSH Config Entry:** `~/.ssh/config`
```
Host remote-mac
    HostName 192.168.1.245
    User tywhitaker
    IdentityFile ~/.ssh/id_ed25519_clawdbot
    IdentitiesOnly yes

Host 192.168.1.245
    User tywhitaker
    IdentityFile ~/.ssh/id_ed25519_clawdbot
    IdentitiesOnly yes
```

**Verification:**
```bash
# Test passwordless SSH
ssh tywhitaker@192.168.1.245 "echo Connection successful"
```

---

## Network Connectivity

### Required Ports

| Service | Port | Protocol | Direction | Status |
|---------|------|----------|-----------|--------|
| Clawdbot Gateway | 18789 | TCP/WebSocket | Inbound | ✅ Open |
| SSH | 22 | TCP | Inbound/Outbound | ✅ Open |
| Dashboard | 18789 | HTTP | Local | ✅ Accessible |

### Firewall Status

**Main Mac:**
```bash
# Check firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# Allow incoming connections for Node.js if needed
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/local/bin/node
```

**Remote Mac:**
- Firewall should allow outbound WebSocket connections
- No inbound ports needed (node initiates connection)

---

## Health Checks

### Quick Health Check Commands

```bash
# Main Mac - Check gateway
curl -s http://localhost:18789/health

# Main Mac - Check nodes connected
clawdbot gateway status

# Remote Mac - Check node status
ssh tywhitaker@192.168.1.245 'clawdbot node status'

# Test WebSocket connectivity
ssh tywhitaker@192.168.1.245 'curl -s -o /dev/null -w "%{http_code}" http://192.168.1.230:18789/health'
```

### Dashboard Access

**URL:** http://localhost:18789

**What to check:**
- Gateway status shows "Running"
- At least one node shows "Connected"
- No error messages in logs

---

## Known Issues

### Minor: OrbStack Not on Remote

**Impact:** Cannot run Docker containers on remote Mac.

**Symptoms:**
- Docker commands fail on remote
- Cannot use containerized tools

**Resolution:** See [scripts/install-orbstack-remote.sh](../scripts/install-orbstack-remote.sh) (optional)

---

## Verification Checklist

Run these checks after any changes:

- [ ] Main Mac gateway running: `clawdbot gateway status`
- [ ] Dashboard accessible: Open http://localhost:18789
- [ ] SSH to remote works: `ssh tywhitaker@192.168.1.245`
- [ ] Remote node connected: Check dashboard or `ssh tywhitaker@192.168.1.245 'clawdbot node status'`
- [ ] WebSocket healthy: Check for heartbeat in logs

---

## Quick Commands Reference

### Main Mac
```bash
# Start gateway
clawdbot gateway start

# Stop gateway
clawdbot gateway stop

# View status
clawdbot gateway status

# View logs
clawdbot gateway logs -f

# Open dashboard
open http://localhost:18789
```

### Remote Mac (via SSH)
```bash
# Start node
ssh tywhitaker@192.168.1.245 'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && clawdbot node start'

# Stop node
ssh tywhitaker@192.168.1.245 'clawdbot node stop'

# Check status
ssh tywhitaker@192.168.1.245 'clawdbot node status'

# View logs
ssh tywhitaker@192.168.1.245 'clawdbot node logs'
```

---

## Version History

| Date | Change | Status |
|------|--------|--------|
| 2026-01-27 | Initial distributed setup | ✅ Working |
| 2026-01-27 | SSH passwordless auth | ✅ Configured |
| 2026-01-27 | Remote node connected | ✅ Working |
| 2026-01-27 | Auto-restart configuration | ✅ Configured |
| 2026-01-27 | Firewall enabled on TW | ✅ Working |
| Pending | OrbStack on remote | ❓ Optional |

---

## Firewall Configuration

### Remote Mac (TW) Firewall

The macOS firewall is enabled on TW with Node.js allowed for outbound connections.

**Current Configuration:**
```bash
# Check firewall status
ssh tywhitaker@192.168.1.245 '/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate'
# Returns: Firewall is enabled. (State = 1)

# Verify Node.js is allowed
ssh tywhitaker@192.168.1.245 '/usr/libexec/ApplicationFirewall/socketfilterfw --listapps | grep node'
# Returns: /Users/tywhitaker/.nvm/versions/node/v24.13.0/bin/node
```

**If Node.js needs to be re-added after nvm update:**
```bash
# On TW (requires sudo)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add ~/.nvm/versions/node/$(node -v)/bin/node
```

---

## See Also

- [Remote Access Guide](REMOTE_ACCESS_GUIDE.md) - Access methods and Tailscale setup
- [Auto-restart Fix](AUTO_RESTART_FIX.md) - LaunchAgent configuration
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions
- [Quick Reference](QUICK_REFERENCE.md) - Daily command cheat sheet

---

**Last Updated:** 2026-01-27
**Status:** ✅ Distributed System Operational | ✅ Firewall Enabled | ✅ Auto-restart Active
