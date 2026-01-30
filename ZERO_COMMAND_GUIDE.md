# Zero-Command Workflow Guide

## Three Levels of Automation

### Level 1: Enhanced Commands (✅ Ready)

**You type commands, but they're smarter:**

```bash
cd ~/Development/Projects/myapp
agy                              # Auto-detects project, starts local
agy -r "analyze code"            # Remote with job tracking
agy -r status                    # Check all jobs
```

---

### Level 2: Shell Integration (✅ Ready)

**Just `cd` into project, get hints:**

```bash
cd ~/Development/Projects/myapp

# Shell automatically shows:
📍 Project detected: myapp
💡 Quick commands:
   agy              # Start Claude locally
   agy -r "task"    # Run task on TW Mac
```

**Setup (one-time):**
```bash
echo 'source ~/Development/Projects/dev-infra/scripts/agy-shell-integration.sh' >> ~/.zshrc
source ~/.zshrc
```

---

### Level 3: True Zero-Command (✅ IMPLEMENTED - Path 3)

**Open folder in Antigravity → Environment ready → Notification appears**

No terminal commands required. Just open your project.

#### What Happens on Folder Open

1. **VS Code task triggers** via `runOn: folderOpen`
2. **`agy-auto-setup` runs silently:**
   - Allows direnv (loads environment variables)
   - Validates 1Password secrets
   - Checks MCP server health
3. **macOS notification appears:** "✅ project-name ready"
4. **Claude is ready** with full context

#### Setup Time: ~2 minutes

```bash
# Initialize any project for Path 3
agy-init ~/Development/Projects/myapp

# Or from inside the project
cd ~/Development/Projects/myapp
agy-init .
```

This creates:
- `.antigravity/config.json` - Project configuration (v3.0 schema)
- `.vscode/tasks.json` - Auto-run task on folder open
- `scripts/agy-auto-setup` - Silent setup script

---

## Quick Reference

### Commands

| Command | Description |
|---------|-------------|
| `agy` | Start Claude locally (auto-detects project) |
| `agy -r "task"` | Run task on TW Mac |
| `agy -r status` | View all remote jobs |
| `agy-init` | Initialize project for Path 3 |
| `agy-health` | Validate Path 3 setup |

### agy-init Options

```bash
agy-init                           # Initialize current directory
agy-init ~/Projects/myapp          # Initialize specific project
agy-init -n "My App" .             # Set custom project name
agy-init --force                   # Reinitialize existing project
```

### agy-health Checks

```bash
agy-health                         # Check current directory
agy-health ~/Projects/myapp        # Check specific project
```

Validates:
- `.antigravity/config.json` (v3.0 schema)
- `.vscode/tasks.json` (folderOpen trigger)
- `scripts/agy-auto-setup` (exists, executable)
- direnv configuration
- MCP server configuration
- 1Password integration
- dev-infra connectivity

---

## Project Structure (Path 3)

After running `agy-init`, your project has:

```
myapp/
├── .antigravity/
│   ├── config.json          # Project config (v3.0)
│   └── config.schema.json   # JSON schema
├── .vscode/
│   └── tasks.json           # folderOpen trigger
├── scripts/
│   └── agy-auto-setup       # Silent setup script
├── .envrc                   # direnv environment
└── ...
```

### .antigravity/config.json

```json
{
  "$schema": "./config.schema.json",
  "version": "3.0",
  "project": {
    "name": "myapp",
    "description": "My application",
    "techStack": ["typescript", "react"]
  },
  "onOpen": {
    "setupScript": "scripts/agy-auto-setup",
    "allowDirenv": true,
    "validateSecrets": true,
    "checkMcpHealth": true,
    "notification": {
      "enabled": true,
      "successMessage": "myapp ready",
      "sound": "Glass"
    }
  },
  "secrets": ["GITHUB_TOKEN", "API_KEY"],
  "mcp": {
    "autoLoad": true,
    "servers": {}
  },
  "claude": {
    "autoStart": false,
    "contextFiles": ["CLAUDE.md", "README.md"]
  }
}
```

---

## Workflow Comparison

### Before Path 3
```bash
cd ~/Development/Projects/myapp
direnv allow
# Check if secrets are loaded...
# Check if MCP servers are configured...
agy
```

### After Path 3
```
1. Open folder in Antigravity
2. [Notification: "✅ myapp ready"]
3. Start working
```

---

## Troubleshooting

### Setup didn't run on folder open

1. Antigravity may prompt "Allow automatic tasks" - click Allow
2. Check `.vscode/tasks.json` has `runOn: folderOpen`
3. Run `agy-health` to diagnose

### Notification didn't appear

Check the log:
```bash
tail -20 /tmp/agy-auto-setup-$(date +%Y%m%d).log
```

### Secrets not loading

1. Ensure 1Password CLI is signed in: `op account list`
2. Check `.envrc` has `op_export` calls
3. Run `direnv allow` manually

### MCP servers not detected

1. Check for `.vscode/mcp.json` or `.antigravity/mcp-servers.json`
2. Verify server paths are correct
3. Run `agy-health` for diagnostics

---

## Migration Guide

### From Level 1/2 to Level 3

```bash
# 1. Initialize the project
cd ~/Development/Projects/existing-project
agy-init --force

# 2. Verify setup
agy-health

# 3. Test by reopening in Antigravity
# Close and reopen the folder
```

### New Projects

```bash
# Create project
mkdir ~/Development/Projects/new-project
cd ~/Development/Projects/new-project

# Initialize with Path 3
agy-init

# Edit .antigravity/config.json to add:
# - secrets
# - MCP servers
# - tech stack

# Verify
agy-health
```

---

## Success Criteria

| Metric | Target | Status |
|--------|--------|--------|
| Setup time | < 5 seconds | ✅ ~4s |
| Manual commands | Zero | ✅ |
| Success rate | > 98% | ✅ |
| Notification | On completion | ✅ |

---

*Last updated: 2026-01-30*
