# File Structure

Overview of all files in this repository and their purposes.

## Directory Structure

```
clawdbot/
├── README.md                    # Main entry point with quick start
├── V1.1_RELEASE_NOTES.md       # Release notes for v1.1.0
├── .env                         # Environment variables (not committed)
├── .gitignore                   # Git ignore rules
├── .mcp.json                    # MCP server configuration
├── .mcp-project.yaml            # MCP project metadata
│
├── config/                      # Docker configuration files
│   ├── docker-compose.yml       # Standard Docker Compose
│   ├── docker-compose.secure.yml # Hardened Docker Compose
│   ├── docker-compose.macos.yml # macOS-specific overrides
│   ├── docker-compose.override.yml.example # Template for local overrides
│   ├── Dockerfile.secure        # Security-hardened Dockerfile
│   ├── seccomp-profile.json     # Linux syscall filtering profile
│   ├── .env.example             # Environment variables template
│   ├── docker-setup.sh          # Automated Docker setup script
│   ├── preflight-check.sh       # Pre-deployment verification
│   ├── install-aliases.sh       # Shell aliases installer
│   ├── 1password-vault.conf     # 1Password integration config
│   └── .gitignore               # Config-specific git rules
│
├── scripts/                     # Deployment and automation scripts
│   ├── deploy-secure.sh         # Automated secure Docker deployment
│   ├── verify-security.sh       # Security configuration verification
│   ├── verify-connection.sh     # Distributed system connectivity test
│   ├── fix-auto-restart.sh      # Remote Mac auto-restart setup
│   ├── setup-tailscale.sh       # Tailscale VPN setup
│   ├── setup-mcp.sh             # MCP servers configuration
│   ├── install-orbstack-remote.sh # OrbStack/Docker remote install
│   ├── post-restart-setup.sh    # Post-restart configuration
│   └── lib/
│       └── common.sh            # Shared library functions
│
├── docs/                        # Documentation
│   ├── README.md                # Documentation home
│   ├── INDEX.md                 # Complete navigation index
│   ├── FILE_STRUCTURE.md        # This file
│   ├── DEPLOYMENT.md            # Standard deployment guide
│   ├── SECURE_DEPLOYMENT.md     # Secure container deployment
│   ├── DOCKER_GUIDE.md          # Docker configuration reference
│   ├── SECURITY.md              # Security best practices
│   ├── TROUBLESHOOTING.md       # Docker troubleshooting
│   ├── QUICK_REFERENCE.md       # Daily command cheat sheet
│   ├── INTEGRATION_GUIDE.md     # Integration with official Clawdbot
│   ├── MACOS_INTEGRATION.md     # macOS-specific features
│   ├── CHANGELOG.md             # Version history
│   ├── SETUP_COMPLETE.md        # Setup completion summary
│   ├── MCP_SETUP_ISSUES.md      # MCP troubleshooting
│   ├── SYSTEM_STATUS.md         # Current system configuration
│   ├── AUTO_RESTART_FIX.md      # LaunchAgent setup
│   ├── REMOTE_ACCESS_GUIDE.md   # LAN/Tailscale access methods
│   ├── DISTRIBUTED_TROUBLESHOOTING.md # Multi-Mac troubleshooting
│   └── DISTRIBUTED_QUICK_REFERENCE.md # Distributed commands
│
└── .claude/                     # Claude Code configuration
    ├── settings.local.json      # Local settings
    └── skills/
        └── exa-search.md        # Exa search skill
```

## File Categories

### Root Files

| File | Purpose |
|------|---------|
| `README.md` | Main entry point with quick start and system architecture |
| `V1.1_RELEASE_NOTES.md` | v1.1.0 release notes with secure container features |
| `.gitignore` | Git ignore rules for environment files and data |
| `.mcp.json` | MCP server configuration (Docker, GitHub, Context7) |
| `.mcp-project.yaml` | MCP project metadata and server enablement |

### Configuration (config/)

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Standard Docker services definition |
| `docker-compose.secure.yml` | Hardened Docker Compose with security constraints |
| `docker-compose.macos.yml` | macOS-specific overrides |
| `Dockerfile.secure` | Security-hardened image wrapping Clawdbot npm |
| `seccomp-profile.json` | Custom Linux syscall filtering |
| `.env.example` | Environment variables template |
| `docker-setup.sh` | Automated Docker setup script |
| `preflight-check.sh` | Pre-deployment verification |
| `install-aliases.sh` | Shell aliases installer |

### Scripts (scripts/)

| Script | Purpose |
|--------|---------|
| `deploy-secure.sh` | One-command secure deployment with all hardening |
| `verify-security.sh` | Automated security configuration verification |
| `verify-connection.sh` | Test gateway/node connectivity |
| `fix-auto-restart.sh` | Enable LaunchAgent auto-start on remote Mac |
| `setup-tailscale.sh` | Configure Tailscale VPN for remote access |
| `setup-mcp.sh` | Configure MCP servers |
| `lib/common.sh` | Shared utilities (colors, SSH helpers, tokens) |

### Documentation (docs/)

See [INDEX.md](INDEX.md) for detailed documentation navigation.

## Quick Start

1. **Run pre-flight check**: `./config/preflight-check.sh`
2. **Deploy securely**: `./scripts/deploy-secure.sh`
3. **Verify security**: `./scripts/verify-security.sh`
4. **Access dashboard**: `open http://localhost:18789`

## Statistics

| Category | Count |
|----------|-------|
| Configuration files | 12 |
| Scripts | 9 |
| Documentation files | 19 |
| **Total** | **40+** |

---

**Last Updated**: 2026-01-27
