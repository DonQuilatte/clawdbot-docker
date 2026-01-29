# TW Mac Pair Programming & Co-Development Workflows

**Date:** January 29, 2026
**Version:** 1.0
**Stack:** Controller Mac (Antigravity) ↔ TW Mac (Worker Node)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DISTRIBUTED DEVELOPMENT ENVIRONMENT                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  CONTROLLER MAC (Primary)              TW MAC (Worker/Agent)                 │
│  ├── Antigravity IDE                   ├── Antigravity IDE                   │
│  ├── Claude Code (orchestrator)        ├── Claude Code (executor)            │
│  ├── Git (primary repo)                ├── Git (synced repo)                 │
│  ├── tw-control.sh                     ├── Desktop Commander MCP             │
│  └── Health Monitor                    └── tmux sessions                     │
│           │                                      │                           │
│           └──────── Tailscale (WireGuard) ───────┘                           │
│                                                                              │
│  Communication:                                                              │
│  ├── SSH (commands, tmux)                                                    │
│  ├── SMB (file sync at ~/tw-mac/)                                           │
│  └── Git (code sync)                                                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Core Workflows

### 1. Parallel Development (Driver/Navigator)

**Use Case:** One developer codes while AI assists on TW Mac

```bash
# Controller: Start coding session
code ~/Development/Projects/clawdbot/

# TW Mac: Start AI assistant for research/review
~/bin/tw run 'tmux new-session -d -s assistant "cd ~/Development/Projects/clawdbot && claude"'

# Send task to TW Mac assistant
~/bin/tw run 'tmux send-keys -t assistant "Research best practices for X and summarize" Enter'

# Check assistant progress
~/bin/tw run 'tmux capture-pane -t assistant -p | tail -50'
```

**Workflow Steps:**
1. Developer works on Controller Mac (primary IDE)
2. AI assistant runs on TW Mac for parallel tasks
3. Results reviewed via tmux capture or SMB file access
4. Code merged via git

---

### 2. Offloaded Build & Test

**Use Case:** Run CPU-intensive builds/tests on TW Mac

```bash
# Start build on TW Mac
~/bin/tw run 'tmux new-session -d -s build "cd ~/Development/Projects/clawdbot && npm run build 2>&1 | tee /tmp/build.log"'

# Monitor build progress
~/bin/tw run 'tail -f /tmp/build.log' &

# Run tests on TW Mac
~/bin/tw run 'tmux new-session -d -s tests "cd ~/Development/Projects/clawdbot && npm test 2>&1 | tee /tmp/test.log"'

# Get test results
~/bin/tw run 'cat /tmp/test.log'
```

**Workflow Steps:**
1. Push code to git from Controller
2. TW Mac pulls and builds
3. Tests run in isolated tmux session
4. Results retrieved via SSH or SMB

---

### 3. Code Review Pipeline

**Use Case:** AI-assisted code review on TW Mac

```bash
# Sync latest code to TW Mac
~/bin/tw run 'cd ~/Development/Projects/clawdbot && git pull'

# Start code review session
~/bin/tw run 'tmux new-session -d -s review "cd ~/Development/Projects/clawdbot && claude"'

# Send review request
~/bin/tw run 'tmux send-keys -t review "Review the changes in the last 3 commits for security issues, performance concerns, and code quality" Enter'

# Capture review output
~/bin/tw run 'tmux capture-pane -t review -p -S -1000' > /tmp/review-output.txt
```

---

### 4. Documentation Generation

**Use Case:** Auto-generate docs on TW Mac

```bash
# Start documentation session
~/bin/tw run 'tmux new-session -d -s docs "cd ~/Development/Projects/clawdbot && claude"'

# Request documentation
~/bin/tw run 'tmux send-keys -t docs "Generate API documentation for the scripts/ directory" Enter'

# Retrieve generated docs (via SMB)
cat ~/tw-mac/Development/Projects/clawdbot/docs/generated/
```

---

### 5. Long-Running Development Server

**Use Case:** Run dev server on TW Mac, develop on Controller

```bash
# Start dev server on TW Mac
~/bin/tw run 'tmux new-session -d -s devserver "cd ~/Development/Projects/clawdbot && npm run dev"'

# Access via Tailscale IP
curl http://100.81.110.81:3000/api/health

# Edit files on Controller (changes sync via SMB or git)
code ~/tw-mac/Development/Projects/clawdbot/src/

# Restart server when needed
~/bin/tw run 'tmux send-keys -t devserver C-c && sleep 1 && tmux send-keys -t devserver "npm run dev" Enter'
```

---

### 6. Container Workloads (OrbStack)

**Use Case:** Run Docker containers on TW Mac

```bash
# Build container on TW Mac
~/bin/tw run 'cd ~/Development/Projects/clawdbot && docker build -t clawdbot:dev .'

# Run container
~/bin/tw run 'docker run -d --name clawdbot-dev -p 8080:8080 clawdbot:dev'

# Check logs
~/bin/tw run 'docker logs -f clawdbot-dev'

# Access service via Tailscale
curl http://100.81.110.81:8080/
```

---

### 7. Multi-Agent Collaboration

**Use Case:** Multiple Claude agents working on different tasks

```bash
# Agent 1: Feature development
~/bin/tw run 'tmux new-session -d -s agent-feature "cd ~/Development/Projects/clawdbot && claude"'
~/bin/tw run 'tmux send-keys -t agent-feature "Implement feature X following the spec in docs/specs/feature-x.md" Enter'

# Agent 2: Test writing
~/bin/tw run 'tmux new-session -d -s agent-tests "cd ~/Development/Projects/clawdbot && claude"'
~/bin/tw run 'tmux send-keys -t agent-tests "Write unit tests for the new feature in src/feature-x/" Enter'

# Agent 3: Documentation
~/bin/tw run 'tmux new-session -d -s agent-docs "cd ~/Development/Projects/clawdbot && claude"'
~/bin/tw run 'tmux send-keys -t agent-docs "Update README and API docs for feature X" Enter'

# Monitor all agents
~/bin/tw run 'tmux list-sessions'
```

---

## Use Cases Matrix

| Use Case | Controller Role | TW Mac Role | Communication |
|----------|-----------------|-------------|---------------|
| **Pair Programming** | Driver (coding) | Navigator (AI review) | tmux + SSH |
| **Build Offload** | Trigger + monitor | Execute build | SSH + logs |
| **Test Execution** | Code changes | Run tests | Git + SSH |
| **Code Review** | Commit code | AI review | tmux capture |
| **Doc Generation** | Request docs | Generate with AI | SMB + Git |
| **Dev Server** | Edit code | Serve application | Tailscale + SMB |
| **Container Ops** | Orchestrate | Run containers | SSH + Docker |
| **Multi-Agent** | Coordinate | Execute agents | tmux sessions |

---

## Session Management

### List Active Sessions
```bash
~/bin/tw run 'tmux list-sessions'
```

### Attach to Session
```bash
~/bin/tw tmux
# Then Ctrl-b, s to select session
```

### Kill Session
```bash
~/bin/tw run 'tmux kill-session -t <session-name>'
```

### Capture Session Output
```bash
# Last 100 lines
~/bin/tw run 'tmux capture-pane -t <session> -p -S -100'

# Full history
~/bin/tw run 'tmux capture-pane -t <session> -p -S -' > output.txt
```

---

## Git Synchronization Workflows

### Push from Controller, Pull on TW Mac
```bash
# Controller
git add . && git commit -m "Feature update" && git push

# TW Mac
~/bin/tw run 'cd ~/Development/Projects/clawdbot && git pull'
```

### Direct File Edit via SMB
```bash
# Edit directly (instant sync)
vim ~/tw-mac/Development/Projects/clawdbot/src/file.ts

# Commit from TW Mac
~/bin/tw run 'cd ~/Development/Projects/clawdbot && git add . && git commit -m "Edit from SMB"'
```

---

## Error Handling & Recovery

### Session Crashed
```bash
# Check session status
~/bin/tw run 'tmux list-sessions'

# Restart crashed session
~/bin/tw run 'tmux kill-session -t <session>' 2>/dev/null
~/bin/tw run 'tmux new-session -d -s <session> "<command>"'
```

### Connection Lost
```bash
# Reset SSH socket
rm ~/.ssh/sockets/tywhitaker@100.81.110.81-22
~/bin/tw connect

# Verify
~/bin/tw status
```

### TW Mac Unresponsive
```bash
# Check via LAN fallback
ssh tw-lan 'uptime'

# Force restart services
ssh tw-lan 'killall node; ~/bin/start-desktop-commander-mcp.sh &'
```

---

## Best Practices

1. **Use tmux for all long-running tasks** - Survives disconnections
2. **Git sync before and after** - Keep repos in sync
3. **Log everything** - Redirect output to files for review
4. **Name sessions descriptively** - `agent-feature-x`, `build-v2`, etc.
5. **Monitor health logs** - `tail -f ~/.claude/tw-mac/health.log`
6. **Use Tailscale IPs** - More reliable than LAN for remote work

---

*Part of clawdbot distributed infrastructure documentation*
