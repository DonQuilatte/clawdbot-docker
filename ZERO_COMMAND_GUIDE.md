# Zero-Command Workflow Guide

## Three Levels of Automation

### Level 1: Enhanced Commands (✅ CURRENT - Ready Now)

**You type commands, but they're better:**

```bash
cd ~/Development/Projects/myapp
agy                              # Auto-detects project, starts local
agy -r "analyze code"            # Remote with job tracking
agy -r status                    # Check all jobs
```

**What changed:**
- Smart detection: `agy` with no args auto-detects project
- Job tracking: Remote execution tracked automatically
- Status dashboard: See everything at once

---

### Level 2: Shell Integration (🔄 NEXT - 5 minutes)

**Just `cd` into project, get hints:**

```bash
cd ~/Development/Projects/myapp

# Shell automatically shows:
📍 Project detected: myapp
💡 Quick commands:
   agy              # Start Claude locally
   agy -r "task"    # Run task on TW Mac

# Then just type:
agy
# Claude starts with full context
```

**Setup:**
```bash
# Add to ~/.zshrc
echo 'source ~/Development/Projects/clawdbot/scripts/agy-shell-integration.sh' >> ~/.zshrc
source ~/.zshrc
```

---

### Level 3: True Zero-Command (🎯 FUTURE - Phase 2)

**Just open project in Antigravity → Claude ready:**

#### Option A: Antigravity Workspace Hook

If Antigravity supports `workspace.onOpen`:

```json
// Antigravity settings
{
  "workspace.onOpen": {
    "command": "${workspaceFolder}/scripts/agy-auto-setup"
  }
}
```

When you: `File → Open Folder → myapp`
System does:
1. Runs project-setup.sh
2. Loads direnv environment  
3. Configures MCP servers
4. Shows "Project ready" notification

#### Option B: Project Config File

Add to each project: `.antigravity/config.json`

```json
{
  "onOpen": {
    "setupScript": "scripts/project-setup.sh",
    "allowDirenv": true,
    "autoStartClaude": true,
    "mcpServers": {
      "desktop-commander": {
        "command": "bash",
        "args": ["${workspaceFolder}/scripts/mcp-desktop-commander"]
      }
    }
  }
}
```

Antigravity reads this, auto-configures on open.

#### Option C: direnv + Antigravity Integration

In `~/.config/direnv/direnvrc`:

```bash
layout_antigravity() {
    # Export MCP config path
    export AGY_MCP_SERVERS="${PWD}/.mcp-servers.json"
    
    # Auto-open in Antigravity if not already open
    if ! pgrep -f "Antigravity.*${PWD}" > /dev/null; then
        open -a Antigravity "${PWD}"
    fi
}
```

In project `.envrc`:
```bash
layout antigravity
```

When you `cd myapp`:
- direnv triggers
- Antigravity opens automatically
- MCP servers load
- Environment ready

---

## Your Current Options

### Immediate Use (No Setup Required)

**From any project directory:**
```bash
cd ~/Development/Projects/clawdbot
agy                      # Smart: detects project, starts local Claude
```

**With explicit project:**
```bash
agy myapp                # Start local
agy -r myapp "task"      # Remote + tracked
```

**Job management:**
```bash
agy -r status            # View all remote jobs
agy -r logs <job-id>     # View job logs
agy -r attach <job-id>   # Attach to session
```

### 5-Minute Setup (Shell Integration)

**Add to ~/.zshrc:**
```bash
source ~/Development/Projects/clawdbot/scripts/agy-shell-integration.sh
```

**Then just:**
```bash
cd ~/Development/Projects/myapp
# Automatically shows project detection + hints

agy
# Claude starts with full context
```

### Future Vision (Antigravity IDE Integration)

**No commands at all:**

1. Open Finder
2. Double-click project folder
3. Antigravity opens
4. Claude ready with full MCP stack
5. Just start talking: "analyze the authentication flow"

---

## Comparison

### Today (With Shell Integration)
```bash
$ cd ~/Development/Projects/payment-service

📍 Project detected: payment-service
💡 Quick commands:
   agy              # Start Claude locally
   agy -r "task"    # Run task on TW Mac

$ agy
[Claude starts with full context, MCP servers loaded]

You: "analyze the authentication flow"
[Claude uses Desktop Commander MCP to read files]
```

### Future (Antigravity Integration)
```
[Open project in Antigravity]

[Notification: "payment-service ready"]

You: "analyze the authentication flow"
[Claude already running, MCP loaded, environment ready]
```

---

## What to Do Now

### Option 1: Use Enhanced Commands (Ready Now)

```bash
cd ~/Development/Projects/clawdbot
agy -r "analyze scripts directory"
agy -r status
```

### Option 2: Add Shell Integration (5 minutes)

```bash
echo 'source ~/Development/Projects/clawdbot/scripts/agy-shell-integration.sh' >> ~/.zshrc
source ~/.zshrc

cd ~/Development/Projects/clawdbot
# See automatic detection
agy
```

### Option 3: Wait for Antigravity Integration (Future)

We need to:
1. Determine if Antigravity supports workspace hooks
2. Create `.antigravity/config.json` template
3. Add to project-setup.sh
4. Test and iterate

---

## Bottom Line

**Right now:** You still type `agy`, but it's smart about context.

**With shell integration (5 min):** You `cd` to project, see hints, type `agy`.

**Future vision:** Open project in Antigravity → everything just works.

**Which level do you want to implement?**
