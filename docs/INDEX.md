# Clawdbot Docker Setup - Documentation Index

## Quick Navigation by Task

### "I want to deploy Clawdbot"

1. Run `./config/preflight-check.sh` to verify prerequisites
2. Follow [DEPLOYMENT.md](DEPLOYMENT.md) for standard deployment
3. Or use `./scripts/deploy-secure.sh` for secure deployment
4. Use [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for daily commands

### "I want to understand the setup"

1. Read the main [README.md](../README.md) for overview
2. Check [FILE_STRUCTURE.md](FILE_STRUCTURE.md) for organization
3. Review [DOCKER_GUIDE.md](DOCKER_GUIDE.md) for details

### "I want to secure my installation"

1. Read [SECURITY.md](SECURITY.md) thoroughly
2. Follow [SECURE_DEPLOYMENT.md](SECURE_DEPLOYMENT.md) for hardening
3. Run `./scripts/verify-security.sh` to verify

### "Something is broken"

1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for Docker issues
2. Check [DISTRIBUTED_TROUBLESHOOTING.md](DISTRIBUTED_TROUBLESHOOTING.md) for multi-Mac issues
3. Run `./scripts/verify-connection.sh` to test connectivity

### "I want to set up distributed system (two Macs)"

1. Read [SYSTEM_STATUS.md](SYSTEM_STATUS.md) for overview
2. Follow [REMOTE_ACCESS_GUIDE.md](REMOTE_ACCESS_GUIDE.md) for setup
3. Run `./scripts/fix-auto-restart.sh` for auto-start
4. Reference [DISTRIBUTED_QUICK_REFERENCE.md](DISTRIBUTED_QUICK_REFERENCE.md) for commands

---

## Complete File List

### Core Files

| File | Location | Purpose |
|------|----------|---------|
| README.md | Root | Main entry point with quick start |
| V1.1_RELEASE_NOTES.md | Root | v1.1.0 release notes |

### Configuration (config/)

| File | Purpose |
|------|---------|
| docker-compose.yml | Standard Docker services |
| docker-compose.secure.yml | Hardened Docker Compose |
| docker-compose.macos.yml | macOS-specific overrides |
| Dockerfile.secure | Security-hardened image |
| seccomp-profile.json | Syscall filtering profile |
| .env.example | Environment template |
| docker-setup.sh | Automated setup script |
| preflight-check.sh | Pre-deployment checks |
| install-aliases.sh | Shell aliases installer |

### Scripts (scripts/)

| Script | Purpose |
|--------|---------|
| deploy-secure.sh | Automated secure deployment |
| verify-security.sh | Security verification |
| verify-connection.sh | Connectivity testing |
| fix-auto-restart.sh | LaunchAgent setup |
| setup-tailscale.sh | Tailscale VPN setup |
| setup-mcp.sh | MCP configuration |
| lib/common.sh | Shared library functions |

### Documentation - Docker (docs/)

| File | Purpose |
|------|---------|
| README.md | Documentation home |
| DEPLOYMENT.md | Standard deployment guide |
| SECURE_DEPLOYMENT.md | Secure container deployment |
| DOCKER_GUIDE.md | Docker configuration reference |
| QUICK_REFERENCE.md | Daily command reference |
| TROUBLESHOOTING.md | Problem solving guide |
| SECURITY.md | Security best practices |

### Documentation - Distributed System (docs/)

| File | Purpose |
|------|---------|
| SYSTEM_STATUS.md | Current system configuration |
| AUTO_RESTART_FIX.md | LaunchAgent setup for remote |
| REMOTE_ACCESS_GUIDE.md | LAN/Tailscale access methods |
| DISTRIBUTED_TROUBLESHOOTING.md | Multi-Mac troubleshooting |
| DISTRIBUTED_QUICK_REFERENCE.md | Distributed system commands |

### Documentation - Reference (docs/)

| File | Purpose |
|------|---------|
| INDEX.md | This file - complete index |
| FILE_STRUCTURE.md | Repository structure |
| INTEGRATION_GUIDE.md | Integration with official Clawdbot |
| MACOS_INTEGRATION.md | macOS-specific features |
| MCP_SETUP_ISSUES.md | MCP troubleshooting |
| CHANGELOG.md | Version history |
| SETUP_COMPLETE.md | Setup summary |

---

## Documentation by Audience

### For Beginners

1. [README.md](../README.md) - Start here
2. [DEPLOYMENT.md](DEPLOYMENT.md) - Follow step-by-step
3. [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Learn commands

### For Operators

1. [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Daily commands
2. [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Problem solving
3. [SECURITY.md](SECURITY.md) - Security maintenance

### For Developers

1. [DOCKER_GUIDE.md](DOCKER_GUIDE.md) - Configuration details
2. [FILE_STRUCTURE.md](FILE_STRUCTURE.md) - Repository layout
3. [CHANGELOG.md](CHANGELOG.md) - Version history

---

## Reading Order

### First-Time Setup

1. [README.md](../README.md) - Understand the system
2. Run `./config/preflight-check.sh` - Verify prerequisites
3. [SECURITY.md](SECURITY.md) - Understand security
4. [DEPLOYMENT.md](DEPLOYMENT.md) or `./scripts/deploy-secure.sh`
5. [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Learn commands

### Daily Operations

1. [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Command reference
2. [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - When issues arise

### Distributed Setup

1. [SYSTEM_STATUS.md](SYSTEM_STATUS.md) - Architecture overview
2. [REMOTE_ACCESS_GUIDE.md](REMOTE_ACCESS_GUIDE.md) - Setup guide
3. [DISTRIBUTED_QUICK_REFERENCE.md](DISTRIBUTED_QUICK_REFERENCE.md) - Commands

---

## Scripts Usage

### Deploy Securely

```bash
./scripts/deploy-secure.sh
```

### Verify Security

```bash
./scripts/verify-security.sh
```

### Verify Distributed Connectivity

```bash
./scripts/verify-connection.sh      # Full check
./scripts/verify-connection.sh -q   # Quick check
```

### Pre-flight Check

```bash
./config/preflight-check.sh
```

### Install Aliases

```bash
./config/install-aliases.sh
```

---

## External Links

- **Official Clawdbot**: https://clawd.bot
- **Documentation**: https://docs.clawd.bot
- **GitHub**: https://github.com/clawdbot/clawdbot
- **Discord**: https://discord.gg/clawdbot

---

**Last Updated**: 2026-01-27
**Total Files**: 40+
