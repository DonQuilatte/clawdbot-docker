# Clawdbot Docker Setup - Companion Guide

**Production-grade deployment and security guide for Clawdbot on macOS**

> ⚠️ **Important**: This is a **companion guide** to the [official Clawdbot repository](https://github.com/clawdbot/clawdbot). It provides comprehensive documentation, security hardening, and best practices to enhance the official setup. See [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) for how to use this with the official repo.

Complete Docker-based setup guide for Clawdbot with Claude Code authentication and Google Antigravity integration.

## 📚 Documentation

- **[INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)** - **START HERE** - How to use this guide with official Clawdbot
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Step-by-step deployment guide
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Essential commands for daily use
- **[SECURITY.md](SECURITY.md)** - Security best practices and configuration
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions
- **[DOCKER_GUIDE.md](DOCKER_GUIDE.md)** - Detailed Docker configuration reference
- **[FILE_STRUCTURE.md](FILE_STRUCTURE.md)** - Repository structure overview
- **[INDEX.md](INDEX.md)** - Complete navigation index

## 🛠️ Utility Scripts

- **[docker-setup.sh](docker-setup.sh)** - Automated setup script
- **[preflight-check.sh](preflight-check.sh)** - Pre-deployment verification
- **[install-aliases.sh](install-aliases.sh)** - Install helpful shell aliases

## 🎯 Quick Start

### Using with Official Clawdbot Repository

```bash
# 1. Clone official Clawdbot
git clone https://github.com/clawdbot/clawdbot.git ~/Development/Projects/clawdbot-official
cd ~/Development/Projects/clawdbot-official

# 2. Run official setup (builds images locally)
./docker-setup.sh

# 3. Authenticate and configure (using this guide)
claude auth login && claude setup-token
docker compose run --rm clawdbot-cli models auth paste-token --provider anthropic

# 4. Apply security hardening (from this guide's SECURITY.md)
docker compose run --rm clawdbot-cli config set gateway.sandbox.enabled true
docker compose run --rm clawdbot-cli config set gateway.sandbox.mode strict

# 5. Launch gateway
docker compose up -d clawdbot-gateway

# 6. Verify
docker compose run --rm clawdbot-cli doctor
curl http://localhost:3000/health

# 7. Install helpful aliases (optional)
cp /Users/jederlichman/Development/Projects/clawdbot/install-aliases.sh ./
./install-aliases.sh
```

**Complete integration instructions**: [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)

## 📦 What's Included

- **docker-compose.yml** - Docker Compose configuration
- **docker-setup.sh** - Automated setup script
- **.env.example** - Environment variable template
- **.gitignore** - Git ignore rules
- **Documentation** - Comprehensive guides

## 🔧 Requirements

- macOS 10.15+
- Docker Desktop for Mac
- Node.js 18+ and npm
- Active Claude subscription
- Git

## 📖 Getting Started

For detailed setup instructions, see [README.md](README.md).

For quick command reference, see [QUICK_REFERENCE.md](QUICK_REFERENCE.md).

## 🔒 Security

This setup includes comprehensive security features:

- Strict sandboxing
- Localhost-only binding
- Restrictive tool policies
- Audit logging
- Prompt injection protection
- Rate limiting

See [SECURITY.md](SECURITY.md) for detailed security configuration.

## 🆘 Need Help?

- Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues
- Run diagnostics: `docker compose run --rm clawdbot-cli doctor`
- View logs: `docker compose logs -f clawdbot-gateway`
- GitHub Issues: https://github.com/clawdbot/clawdbot/issues
- Discord: https://discord.gg/clawdbot

## 📄 License

See LICENSE file in the repository.

---

**Note**: This is a setup repository for Clawdbot. For the main Clawdbot project, visit https://github.com/clawdbot/clawdbot
