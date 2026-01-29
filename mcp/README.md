# MCP Environment Management - Production Deployment

**Production-ready MCP configuration with secure credential management**

---

## **Quick Start** (20 minutes)

### **1. Global Setup** (once per machine)

```bash
git clone <this-repo>
cd mcp-deployment

bash scripts/global-setup.sh
exec zsh

op whoami  # Verify 1Password authentication
```

### **2. Project Setup** (per repository)

```bash
cd ~/Development/your-project

bash ~/mcp-deployment/scripts/project-setup.sh your-project

# Edit .envrc with your 1Password references
vim .envrc

# Validate
bash ~/mcp-deployment/scripts/validate-setup.sh
```

### **3. Done!**

```bash
# Environment automatically switches between projects
cd ~/Development/project-a  # Loads project-a secrets
cd ~/Development/project-b  # Loads project-b secrets

# MCP servers load automatically in Cursor/VS Code
open -a Cursor .
```

---

## **What This Provides**

✅ **Workspace-scoped MCP configs** - Each project has its own MCP servers  
✅ **Secure credential management** - 1Password CLI, zero secrets on disk  
✅ **Automatic context switching** - direnv loads environment per project  
✅ **Cross-IDE support** - Works with Cursor, VS Code, Antigravity  
✅ **Team collaboration** - Git-based config, personal credential isolation  
✅ **Production-ready** - Peer-validated, performance-optimized  

---

## **Documentation**

| Document | Purpose | Audience |
|----------|---------|----------|
| **[DEPLOYMENT.md](docs/DEPLOYMENT.md)** | Full rollout plan | Team leads |
| **[SETUP_GUIDE.md](docs/SETUP_GUIDE.md)** | Detailed instructions | Developers |
| **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** | Common issues | All users |
| **[ANTIGRAVITY_GUIDE.md](docs/ANTIGRAVITY_GUIDE.md)** | IDE-specific guide | Antigravity users |

---

## **Architecture**

```
Flow:
1. cd project/                  → direnv loads .envrc
2. .envrc runs op_export        → Resolves secrets with 'op read'
3. Secrets in shell environment → Available to all processes
4. IDE starts                   → Loads .cursor/mcp.json
5. MCP wrapper scripts launch   → Inherit environment from step 3
6. cd out                       → direnv unloads everything
```

**Key Components:**

```
~/.config/direnv/direnvrc       # Global: op_export, detect_docker_socket
project/.envrc                  # Per-project: Load specific secrets
project/scripts/mcp-*           # Wrappers: Inherit env, launch servers
project/.cursor/mcp.json        # Config: Use wrappers (not ${VAR})
```

---

## **Features**

### **Credential Management**

```bash
# .envrc (safe to commit)
op_export GITHUB_TOKEN "op://Development/GitHub Token/credential"

# Behind the scenes
# op read "op://Development/GitHub Token/credential" → ghp_xxx
# export GITHUB_TOKEN="ghp_xxx"
```

**Benefits:**
- ✅ No plaintext secrets on disk
- ✅ 1Password audit trail
- ✅ Touch ID authentication on macOS
- ✅ Multi-vault support (Personal, Team, Production)
- ✅ Session management (auto-unlock on expiration)

### **Context Isolation**

```bash
# Project A
cd ~/Development/clawdbot
echo $GITHUB_TOKEN  # → clawdbot token

# Project B  
cd ~/Development/data-science
echo $GITHUB_TOKEN  # → data-science token (or empty)
```

### **MCP Server Management**

```json
{
  "mcpServers": {
    "gitkraken": {
      "command": "bash",
      "args": ["./scripts/mcp-gitkraken"]
    }
  }
}
```

Wrapper inherits environment automatically:
```bash
#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"
exec npx -y @gitkraken/mcp-server
# GITHUB_TOKEN available from direnv
```

---

## **Validation**

```bash
cd your-project
bash ~/mcp-deployment/scripts/validate-setup.sh
```

**Expected output:**
```
✅ direnv is installed
✅ 1Password CLI is installed
✅ direnvrc file exists
✅ direnv hook configured in shell
✅ 1Password CLI authenticated
✅ .envrc exists in current directory
✅ Wrapper scripts present
✅ MCP config files present
✅ PROJECT_NAME environment variable set
✅ Docker socket detected

RESULTS: 10 passed, 0 failed
✅ ALL TESTS PASSED
```

---

## **Requirements**

- macOS (10.15+)
- Homebrew
- 1Password app
- 1Password CLI access
- Git
- Node.js (for MCP servers)

---

## **Scripts Reference**

| Script | Purpose | Run Frequency |
|--------|---------|---------------|
| `global-setup.sh` | Install tools, create direnvrc | Once per machine |
| `project-setup.sh` | Configure project MCP environment | Once per project |
| `validate-setup.sh` | Verify correct configuration | As needed |

---

## **IDE Support Matrix**

| IDE | Workspace Config | Auto-Switch | Status |
|-----|-----------------|-------------|--------|
| **Cursor** | ✅ `.cursor/mcp.json` | ✅ Automatic | Full support |
| **VS Code** | ✅ `.vscode/mcp.json` | ✅ Automatic | Full support |
| **Antigravity** | ⚠️ Global only | ⚠️ Manual | Requires activation script |
| **Claude Desktop** | ❌ Global only | ❌ Manual | Limited support |

---

## **Examples**

See `examples/` directory for complete project configurations:

- `examples/clawdbot/` - Full-stack application
- `examples/data-science/` - Data analysis project

---

## **Support**

- **Documentation:** See `docs/` directory
- **Issues:** [Issue Tracker]
- **Slack:** #mcp-environment-support
- **Contact:** [Your Name/Team]

---

## **Version**

**Version:** 1.0.0  
**Last Updated:** 2026-01-28  
**Status:** Production-ready, peer-validated

---

## **License**

Internal use only - [Your Organization]
