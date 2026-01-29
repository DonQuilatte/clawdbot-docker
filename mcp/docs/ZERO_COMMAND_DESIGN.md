# Antigravity Auto-Engagement Design

## Goal: Zero Commands

**Developer opens project in Antigravity → Stack automatically engages**

No `agy-project`, no `agy-local`. Just work.

---

## How It Works

### Method 1: Antigravity Workspace Detection

When Antigravity opens a folder, trigger project setup automatically.

**Implementation via Antigravity's settings:**

```json
{
  "workspace.onOpen": {
    "command": "~/bin/agy-auto-setup",
    "args": ["${workspaceFolder}"]
  }
}
```

**~/bin/agy-auto-setup:**
```bash
#!/usr/bin/env bash
PROJECT_PATH="$1"
PROJECT_NAME=$(basename "$PROJECT_PATH")

# Run project setup silently in background
if [ -f "${PROJECT_PATH}/scripts/project-setup.sh" ]; then
    (cd "$PROJECT_PATH" && bash scripts/project-setup.sh "$PROJECT_NAME" &>/dev/null) &
fi

# Allow direnv
if [ -f "${PROJECT_PATH}/.envrc" ]; then
    (cd "$PROJECT_PATH" && direnv allow 2>/dev/null) &
fi
```

### Method 2: .antigravity/config.json in Each Project

Add to project root:

```json
{
  "onOpen": {
    "setupScript": "scripts/project-setup.sh",
    "allowDirenv": true,
    "mcpServers": {
      "desktop-commander": {
        "command": "bash",
        "args": ["${workspaceFolder}/scripts/mcp-desktop-commander"]
      },
      "gitkraken": {
        "command": "bash", 
        "args": ["${workspaceFolder}/scripts/mcp-gitkraken"]
      }
    }
  }
}
```

Antigravity reads this, runs setup automatically.

### Method 3: direnv + chpwd Hook

Most elegant - uses existing direnv:

**In ~/.config/direnv/direnvrc:**
```bash
# Auto-notify Antigravity when entering project
layout_antigravity() {
    local project_root="$PWD"
    local project_name=$(basename "$project_root")
    
    # If Antigravity is running, send project context
    if pgrep -x "Antigravity" > /dev/null; then
        osascript -e "tell application \"Antigravity\" to open \"$project_root\""
    fi
    
    # Register MCP servers for this project
    export AGY_MCP_SERVERS="${project_root}/.mcp-servers.json"
}
```

**In project .envrc:**
```bash
layout antigravity
```

When you `cd` into project, Antigravity automatically engages.

---

## Revised Developer Experience

### Opening a Project

**Option A: From Terminal**
```bash
cd ~/Development/Projects/payment-service
# direnv triggers → Antigravity opens → MCP stack loads
```

**Option B: From Antigravity**
```
File → Open Folder → Select payment-service
# .antigravity/config.json triggers setup → MCP stack loads
```

**Option C: From Finder**
```
Right-click project folder → Open With → Antigravity
# Workspace onOpen hook triggers → MCP stack loads
```

### Working in Antigravity

**Just talk to Claude:**

```
You: "analyze the authentication flow"
```

Claude has full context:
- Desktop Commander MCP (file operations)
- GitKraken MCP (git operations)
- Project environment variables loaded
- All credentials available

**No commands. Just conversation.**

### Remote Execution (TW Mac)

**Add to .antigravity/config.json:**
```json
{
  "execution": {
    "remote": {
      "enabled": true,
      "host": "tw-mac",
      "jobNotifications": true
    }
  }
}
```

**In Antigravity, Claude detects long-running tasks:**

```
You: "refactor the entire auth module and generate tests"

Claude: "This looks like a long-running task. Should I:
1. Run locally (you'll wait)
2. Submit to TW Mac (you'll be notified)

[2]"

You: "2"

Claude: "📤 Submitted job auth-module-20260129-153045 to TW Mac. 
I'll notify you when complete."
```

---

## Implementation Priority

### Phase 1: Local Auto-Setup (Immediate)
- Create `agy-auto-setup` script
- Add to Antigravity workspace settings
- Projects auto-configure on open

### Phase 2: Project Config Files (Next)
- Add `.antigravity/config.json` to project template
- Antigravity reads and applies on open

### Phase 3: direnv Integration (Elegant)
- Add `layout_antigravity` to direnvrc
- Projects auto-open when you `cd` into them

### Phase 4: Smart Remote Delegation (Advanced)
- Claude detects long-running tasks
- Offers local vs remote execution
- Manages job lifecycle transparently

---

## Zero-Command Workflow

**Morning:**
```bash
cd ~/Development/Projects/payment-service
```

Antigravity opens automatically. MCP stack loaded. Credentials ready.

**In Antigravity:**
```
You: "what are the main security concerns in this codebase?"
```

Claude analyzes using Desktop Commander MCP.

```
You: "generate a comprehensive security audit report"
```

Claude: "This will take ~15 minutes. Run on TW Mac? [y/n]"

You: "y"

Claude: "📤 Job submitted. You'll be notified."

**You work on something else.**

**20 minutes later:**
```
[macOS Notification]
Security audit complete
payment-service: 47 findings identified
```

**Back in Antigravity:**
```
You: "show me the audit results"
```

Claude retrieves from `~/Development/.agy-jobs/{job-id}/result.md` and displays.

**No commands typed. Pure conversation.**

---

## What Developers Type

### Before (Manual)
```bash
cd ~/Development/Projects/myapp
source .envrc
cursor .
# or
agy-project myapp "do something"
```

### After (Automated)
```bash
cd ~/Development/Projects/myapp
# Done. Antigravity opens, stack ready.
```

Or just open from Antigravity GUI.

---

## Still Need CLI Tools?

**Yes, for:**
- CI/CD pipelines
- Scripting/automation
- Power users who prefer terminal
- Debugging when GUI fails

**But 90% of developers never type a command.**

They:
1. Open project in Antigravity
2. Talk to Claude
3. Claude uses MCP tools
4. Work gets done

