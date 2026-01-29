# Clawdbot Docker Wrapper & Distributed System

## Overview

This repository provides:

1. **Enterprise-grade Docker security hardening** for [Clawdbot](https://clawd.bot)
2. **Distributed multi-Mac setup** for running Clawdbot across multiple machines

---

## Current System Status

```
┌─────────────────────────────────────────────────────────────────┐
│                    Distributed Clawdbot Setup                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Main Mac (192.168.1.230)          Remote Mac (192.168.1.245)   │
│  ┌─────────────────────────┐       ┌─────────────────────────┐  │
│  │ Clawdbot Gateway        │◄──────│ Clawdbot Node           │  │
│  │ Version: 2026.1.24-3    │  WS   │ Version: 2026.1.24-3    │  │
│  │ Port: 18789             │       │ Status: Connected       │  │
│  │ Status: Running         │       │                         │  │
│  └─────────────────────────┘       └─────────────────────────┘  │
│                                                                 │
│  Dashboard: http://localhost:18789                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Status:** ✅ Distributed system operational

---

## Quick Start

### Option 1: Native Installation (Recommended)

```bash
# Install Clawdbot
npm install -g clawdbot@latest

# Run onboarding
clawdbot onboard

# Start gateway
clawdbot gateway start --port 18789

# Open dashboard
open http://localhost:18789
```

### Option 2: Docker Deployment

```bash
# Build secure container
docker compose --env-file .env -f config/docker-compose.secure.yml build

# Deploy with security hardening
./scripts/deploy-secure.sh

# Verify security
./scripts/verify-security.sh
```

### Option 3: Distributed Setup (Two Macs)

See [Distributed Setup](#distributed-setup-two-macs) below.

---

## Distributed Setup (Two Macs)

### Prerequisites

- Two Macs on same network
- Node.js and npm installed on both
- SSH access between machines

### Main Mac (Gateway)

```bash
# Install Clawdbot
npm install -g clawdbot@latest

# Start gateway (allow remote connections)
clawdbot gateway start --bind 0.0.0.0 --port 18789
```

### Remote Mac (Node)

```bash
# Install Clawdbot
npm install -g clawdbot@latest

# Configure as remote node
mkdir -p ~/.clawdbot
cat > ~/.clawdbot/clawdbot.json << 'EOF'
{
  "gateway": {
    "mode": "remote",
    "remote": {
      "url": "ws://192.168.1.230:18789",
      "token": "clawdbot-local-dev"
    }
  }
}
EOF

# Connect to gateway
clawdbot node start --host 192.168.1.230 --port 18789
```

### Configure Auto-restart

```bash
# Run from main Mac to configure remote auto-restart
./scripts/fix-auto-restart.sh
```

### Verify Setup

```bash
# Verify all connections
./scripts/verify-connection.sh

# Quick check
./scripts/verify-connection.sh --quick
```

---

## Scripts

| Script                               | Description                                  |
| ------------------------------------ | -------------------------------------------- |
| `scripts/deploy-secure.sh`           | Deploy Docker with security hardening        |
| `scripts/verify-security.sh`         | Verify Docker security configuration         |
| `scripts/verify-connection.sh`       | Verify distributed system connectivity       |
| `scripts/fix-auto-restart.sh`        | Configure auto-restart on remote Mac         |
| `scripts/setup-tailscale.sh`         | Setup Tailscale for remote internet access   |
| `scripts/install-orbstack-remote.sh` | Install OrbStack/Docker on remote (optional) |

### AntiGravity (agy) Scripts

Project engagement scripts for quickly starting Claude sessions on local or remote machines.

| Script              | Description                                           |
| ------------------- | ----------------------------------------------------- |
| `scripts/agy`       | Smart router - auto-detects project and execution mode |
| `scripts/agy-local` | Start Claude session locally on current Mac           |
| `scripts/agy-project` | Start Claude session on TW Mac with job tracking    |

#### Quick Usage

```bash
# Smart mode - run from any project directory
cd ~/Development/Projects/myapp
agy                                    # Auto-detect & start local

# Explicit local
agy myapp                              # Open existing project
agy git@github.com:you/repo.git        # Clone + open locally
agy myapp "Review the auth module"     # Open + send prompt

# Remote (TW Mac) with job tracking
agy -r myapp "Analyze performance"     # Execute on TW Mac
agy -r status                          # View all jobs
agy -r logs <job-id>                   # View job output
agy -r attach <job-id>                 # Attach to live session
```

#### How It Works

1. **`agy`** (router): Detects if you're in a project directory. If so, starts locally. Otherwise shows usage.
2. **`agy-local`**: Clones repo (if URL), runs `project-setup.sh` if present, configures direnv, starts Claude.
3. **`agy-project`**: Creates tracked job on TW Mac, clones/updates repo, starts Claude in tmux session, supports job management subcommands.

#### Job Management (Remote)

```bash
agy -r status              # List all jobs with status
agy -r logs <job-id>       # View setup/execution logs
agy -r result <job-id>     # Get structured result (if available)
agy -r attach <job-id>     # Attach to tmux session (Ctrl-b d to detach)
```

---

## Documentation

### Distributed System Docs

| Document                                                           | Description                            |
| ------------------------------------------------------------------ | -------------------------------------- |
| [System Status](docs/SYSTEM_STATUS.md)                             | Current configuration and versions     |
| [Auto-restart Fix](docs/AUTO_RESTART_FIX.md)                       | LaunchAgent setup for remote Mac       |
| [Remote Access Guide](docs/REMOTE_ACCESS_GUIDE.md)                 | LAN, Tailscale, and VPN access methods |
| [Distributed Troubleshooting](docs/DISTRIBUTED_TROUBLESHOOTING.md) | Fixing distributed setup issues        |
| [Distributed Quick Reference](docs/DISTRIBUTED_QUICK_REFERENCE.md) | Daily commands cheat sheet             |

### Docker Docs

| Document                                       | Description                |
| ---------------------------------------------- | -------------------------- |
| [Docker Guide](docs/DOCKER_GUIDE.md)           | Complete Docker setup      |
| [Secure Deployment](docs/SECURE_DEPLOYMENT.md) | Security hardening details |
| [Troubleshooting](docs/TROUBLESHOOTING.md)     | Docker troubleshooting     |
| [Quick Reference](docs/QUICK_REFERENCE.md)     | Docker commands            |

### Additional Docs

| Document                                                        | Description                           |
| --------------------------------------------------------------- | ------------------------------------- |
| [Documentation Index](docs/README.md)                           | All documentation                     |
| [Security](docs/SECURITY.md)                                    | Security best practices               |
| [macOS Integration](docs/MACOS_INTEGRATION.md)                  | macOS-specific features               |
| [Antigravity MCP Setup](docs/ANTIGRAVITY-MCP-SETUP.md)          | MCP configuration for Antigravity IDE |
| [Antigravity Quick Reference](docs/ANTIGRAVITY-MCP-QUICKREF.md) | MCP quick reference                   |

---

## Architecture

### Native Mode

```
Clawdbot (npm) → System Service → Gateway/Node
```

### Docker Mode

```
Clawdbot (npm) → Docker Container → Security Hardening → Gateway
```

### Distributed Mode

```
Main Mac                          Remote Mac(s)
┌──────────────────┐              ┌──────────────────┐
│ Clawdbot Gateway │◄────────────►│ Clawdbot Node    │
│ (Coordinator)    │   WebSocket  │ (Worker)         │
└──────────────────┘              └──────────────────┘
```

---

## What Clawdbot Is

- WhatsApp/Telegram/Discord/iMessage gateway
- Claude AI integration via subscription or API key
- Node.js CLI tool that runs as system service
- Supports distributed multi-machine deployments

## What This Repository Adds

- Secure Docker containerization
- Read-only filesystem & non-root user
- Custom seccomp profile & dropped capabilities
- Apple Silicon optimized (M1/M2/M3)
- Distributed system setup guides
- Automated deployment and verification scripts
- Comprehensive documentation

---

## Quick Commands

### Gateway Control (Main Mac)

```bash
clawdbot gateway start     # Start gateway
clawdbot gateway stop      # Stop gateway
clawdbot gateway status    # Check status
clawdbot gateway logs -f   # Follow logs
```

### Remote Node (via SSH)

```bash
# Check remote status
ssh tywhitaker@192.168.1.245 'clawdbot node status'

# Restart remote node
ssh tywhitaker@192.168.1.245 'clawdbot node restart'
```

### Verification

```bash
./scripts/verify-connection.sh       # Full check
./scripts/verify-connection.sh -q    # Quick check
curl http://localhost:18789/health   # Gateway health
```

---

## Links

- **Official Clawdbot**: https://clawd.bot
- **GitHub**: https://github.com/clawdbot/clawdbot
- **Documentation**: https://docs.clawd.bot
- **npm Package**: https://www.npmjs.com/package/clawdbot

---

**Status:** ✅ Distributed system operational | Gateway 2026.1.24-3 | Node 2026.1.24-3
**Last Updated:** 2026-01-29
