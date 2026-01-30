# Claude Rules: Dev-Infra

## Project Overview

**Purpose:** Distributed development infrastructure for Mac environments, including ClawdBot messaging gateway deployment

**Architecture:**
- Main Mac (192.168.1.230): Gateway/Controller
- TW Mac (192.168.1.245): Worker node
- Communication: WebSocket, SMB, SSH

## Tech Stack

**Primary Languages:** Bash, Node.js
**Infrastructure:** Docker, direnv, 1Password CLI
**Deployment:** OrbStack, LaunchAgents
**Security:** Seccomp, read-only rootfs, non-root user

## Key Files

```
config/docker-compose.secure.yml  # Main Docker config
scripts/deploy-secure.sh          # Deployment script
scripts/verify-security.sh        # Security audit
.env                              # Secrets (1Password refs)
.envrc                            # direnv config
```

## Workflow Rules

### File Operations
- **Always use absolute paths** starting with `/Users/jederlichman/`
- **Use Desktop Commander tools** for persistence (not bash_tool)
- **Verify writes immediately** with `ls -la` or `cat`

### Security Posture
- **Never commit secrets** - use `op://` references
- **Rotate credentials** if exposed
- **Check .gitignore** before adding sensitive files

### Communication Style
- **Direct, no pleasantries** - execute immediately
- **Show initiative** - iterate rapidly without asking
- **Assume competence** - skip basic explanations
- **Concise confirmations** - "✅ Done" not paragraphs

### Code Standards
- **Bash scripts:** Use `set -e`, validate inputs, log steps
- **Docker configs:** Pin versions, drop capabilities, read-only rootfs
- **Documentation:** Update README.md when architecture changes

## Project-Specific Context

### Authentication
- **Native mode:** Claude subscription (OAuth) - no API key needed
- **Docker mode:** API key via 1Password (`op://Developer/Anthropic Claude/API Key`)
- **Current deployment:** Native mode (subscription auth)

### Secrets Management
```bash
ANTHROPIC_API_KEY=op://Developer/Anthropic Claude/API Key
CLAWDBOT_GATEWAY_TOKEN=op://Private/Clawdbot Gateway Token/token
```

### Common Tasks
```bash
# Local development
cd ~/Development/Projects/dev-infra
agy                              # Start Claude locally

# Remote execution
agy -r "analyze scripts"         # Dispatch to TW Mac
agy -r status                    # Check all jobs

# Docker deployment
./scripts/deploy-secure.sh       # Full deployment
./scripts/verify-security.sh     # Security audit

# TW Mac operations
~/bin/tw run "command"           # Execute on worker
~/bin/tw-health                  # Check worker status
```

## Domain Knowledge

**Abbreviations:**
- MCP: Model Context Protocol
- TW: TyWhitaker (worker Mac identifier)
- AGY: Antigravity IDE
- SMB: Server Message Block (file sharing)

**Conventions:**
- `agy` command family for Claude engagement
- `tw-*` scripts for worker management
- `op://` prefixes for 1Password references

## Anti-Patterns

**Don't:**
- Ask permission for routine operations
- Use relative paths without justification
- Suggest breaking changes without migration plan
- Create files in ephemeral containers
- Commit plaintext secrets

**Do:**
- Verify file operations succeeded
- Update documentation when changing architecture
- Test security configs after modifications
- Use structured error messages
- Report actual file sizes/paths after writes

---

*Last updated: 2026-01-29*
