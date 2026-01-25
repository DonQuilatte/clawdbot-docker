# Clawdbot Companion Guide

**Production-grade deployment and security guide for Clawdbot on macOS**

> ⚠️ **Important**: This is a **companion guide** to the [official Clawdbot repository](https://github.com/clawdbot/clawdbot). It provides comprehensive documentation, security hardening, and best practices to enhance the official setup.

## 🎯 Choose Your Deployment Path

| Profile                   | Security Level          | Guide                                                  | Setup Time |
| ------------------------- | ----------------------- | ------------------------------------------------------ | ---------- |
| **Personal/Development**  | Standard                | [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)           | 10 min     |
| **Production/Enterprise** | 🔒 **Secure Container** | [docs/SECURE_DEPLOYMENT.md](docs/SECURE_DEPLOYMENT.md) | 15 min     |

### 🔒 Secure Container Deployment (Recommended for Production)

Enterprise-grade security with:

- ✅ Read-only root filesystem
- ✅ Non-root user (UID 1000)
- ✅ All Linux capabilities dropped
- ✅ Custom seccomp profile
- ✅ Localhost-only binding
- ✅ Resource limits enforced

**→ [Start Secure Deployment](docs/SECURE_DEPLOYMENT.md)**

### 📚 Standard Deployment (Personal Use)

Basic security with configuration flexibility:

- ✅ Configurable sandbox mode
- ✅ Optional security hardening
- ✅ Faster setup

**→ [Start Standard Deployment](INTEGRATION_GUIDE.md)**

## 📖 Documentation

### Getting Started

- **[INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)** - How to use with official Clawdbot
- **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)** - Standard deployment guide
- **[docs/SECURE_DEPLOYMENT.md](docs/SECURE_DEPLOYMENT.md)** - 🔒 Secure container deployment

### Operations

- **[docs/QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md)** - Daily command reference
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Problem solving
- **[docs/SECURITY.md](docs/SECURITY.md)** - Security best practices

### Reference

- **[docs/DOCKER_GUIDE.md](docs/DOCKER_GUIDE.md)** - Docker configuration
- **[docs/FILE_STRUCTURE.md](docs/FILE_STRUCTURE.md)** - Repository structure
- **[docs/INDEX.md](docs/INDEX.md)** - Complete navigation

## 🛠️ Configuration Files

### Secure Deployment

- **[config/docker-compose.secure.yml](config/docker-compose.secure.yml)** - Hardened Docker Compose
- **[config/Dockerfile.secure](config/Dockerfile.secure)** - Security-focused image
- **[config/seccomp-profile.json](config/seccomp-profile.json)** - Custom syscall filtering

### Standard Deployment

- **[config/docker-compose.yml](config/docker-compose.yml)** - Standard Docker Compose
- **[config/.env.example](config/.env.example)** - Environment template
- **[config/.gitignore](config/.gitignore)** - Git exclusions

## 🔧 Automation Scripts

- **[scripts/deploy-secure.sh](scripts/deploy-secure.sh)** - Automated secure deployment
- **[scripts/verify-security.sh](scripts/verify-security.sh)** - Security verification
- **[scripts/preflight-check.sh](scripts/preflight-check.sh)** - Pre-deployment checks
- **[scripts/install-aliases.sh](scripts/install-aliases.sh)** - Shell shortcuts

## 🚀 Quick Start

### Secure Deployment (Production)

```bash
# 1. Clone official Clawdbot
git clone https://github.com/clawdbot/clawdbot.git ~/Development/Projects/clawdbot-official
cd ~/Development/Projects/clawdbot-official

# 2. Copy secure configuration
cp ~/Development/Projects/clawdbot/config/docker-compose.secure.yml ./docker-compose.yml
cp ~/Development/Projects/clawdbot/config/Dockerfile.secure ./Dockerfile
cp ~/Development/Projects/clawdbot/config/seccomp-profile.json ./
cp ~/Development/Projects/clawdbot/scripts/deploy-secure.sh ./
cp ~/Development/Projects/clawdbot/scripts/verify-security.sh ./

# 3. Run automated secure deployment
chmod +x deploy-secure.sh verify-security.sh
./deploy-secure.sh

# 4. Authenticate
claude auth login && claude setup-token
docker compose run --rm clawdbot-cli models auth paste-token --provider anthropic

# 5. Verify security
./verify-security.sh
```

**Complete guide**: [docs/SECURE_DEPLOYMENT.md](docs/SECURE_DEPLOYMENT.md)

### Standard Deployment (Personal)

```bash
# 1. Clone official Clawdbot
git clone https://github.com/clawdbot/clawdbot.git ~/Development/Projects/clawdbot-official
cd ~/Development/Projects/clawdbot-official

# 2. Run official setup
./docker-setup.sh

# 3. Authenticate and configure
claude auth login && claude setup-token
docker compose run --rm clawdbot-cli models auth paste-token --provider anthropic

# 4. Apply security hardening (from this guide)
docker compose run --rm clawdbot-cli config set gateway.sandbox.enabled true
docker compose run --rm clawdbot-cli config set gateway.sandbox.mode strict

# 5. Launch
docker compose up -d clawdbot-gateway
```

**Complete guide**: [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)

## 🔒 Security Comparison

| Feature          | Standard        | Secure Container            |
| ---------------- | --------------- | --------------------------- |
| Root Filesystem  | Read-write      | **Read-only**               |
| User             | Configurable    | **Non-root (UID 1000)**     |
| Capabilities     | Default (~14)   | **All dropped**             |
| Seccomp          | Default profile | **Custom restrictive**      |
| Network          | Configurable    | **Localhost-only enforced** |
| Resource Limits  | Optional        | **Enforced**                |
| Setup Complexity | Simple          | Moderate                    |
| **Best For**     | Personal/Dev    | Production/Enterprise       |

## ✨ What This Guide Provides

The official Clawdbot provides the code. This companion guide adds:

✅ **Secure Container Deployment** - Enterprise-grade security hardening  
✅ **Automated Security Scripts** - One-command secure deployment  
✅ **Security Verification** - Automated security checks  
✅ **Comprehensive Documentation** - 11 detailed guides (~90 KB)  
✅ **Troubleshooting Procedures** - Common issues and solutions  
✅ **Quick Reference Guides** - Daily operation commands  
✅ **Shell Aliases** - Convenience shortcuts  
✅ **Best Practices** - Production deployment guidance

## 📊 Repository Structure

```
clawdbot/
├── README.md                      # This file
├── INTEGRATION_GUIDE.md           # Integration with official repo
├── config/                        # Configuration files
│   ├── docker-compose.secure.yml  # 🔒 Secure deployment
│   ├── Dockerfile.secure          # 🔒 Security-hardened image
│   ├── seccomp-profile.json       # 🔒 Syscall filtering
│   ├── docker-compose.yml         # Standard deployment
│   ├── .env.example               # Environment template
│   └── .gitignore                 # Git exclusions
├── scripts/                       # Automation scripts
│   ├── deploy-secure.sh           # 🔒 Automated secure deployment
│   ├── verify-security.sh         # 🔒 Security verification
│   ├── preflight-check.sh         # Pre-deployment checks
│   └── install-aliases.sh         # Shell aliases
└── docs/                          # Documentation
    ├── SECURE_DEPLOYMENT.md       # 🔒 Secure deployment guide
    ├── DEPLOYMENT.md              # Standard deployment guide
    ├── SECURITY.md                # Security best practices
    ├── TROUBLESHOOTING.md         # Problem solving
    ├── QUICK_REFERENCE.md         # Command reference
    ├── DOCKER_GUIDE.md            # Docker configuration
    ├── FILE_STRUCTURE.md          # Repository structure
    └── INDEX.md                   # Complete navigation
```

## 🎯 Use Cases

### Use Secure Deployment If:

- ✅ Deploying in production or enterprise environments
- ✅ Processing untrusted or sensitive data
- ✅ Require compliance (SOC 2, ISO 27001, etc.)
- ✅ Need defense-in-depth security
- ✅ Want minimal attack surface

### Use Standard Deployment If:

- ✅ Testing locally on personal Mac
- ✅ Development environment
- ✅ Only processing trusted data
- ✅ Need maximum flexibility

## 🆘 Getting Help

- **Documentation**: All guides in `docs/` directory
- **Security Issues**: See `docs/SECURITY.md`
- **Troubleshooting**: See `docs/TROUBLESHOOTING.md`
- **GitHub**: https://github.com/clawdbot/clawdbot/issues
- **Discord**: https://discord.gg/clawdbot

## 📄 License

This companion guide is provided as-is for use with Clawdbot.

**Clawdbot itself** is maintained at [clawdbot/clawdbot](https://github.com/clawdbot/clawdbot).

---

**Version**: 1.1.0  
**Created**: 2026-01-25  
**Security Level**: 🔒 Enterprise-Ready  
**Status**: ✅ Production Ready

**🔒 For production deployment, start here**: [docs/SECURE_DEPLOYMENT.md](docs/SECURE_DEPLOYMENT.md)
