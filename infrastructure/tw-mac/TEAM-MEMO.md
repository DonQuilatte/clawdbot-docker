# Team Memo: TW Mac Distributed Worker Setup

**Date:** January 29, 2026
**From:** DevOps / Infrastructure
**To:** Development Team
**Re:** TW Mac as Persistent AI Development Worker

---

## Overview

We now have a second Mac (TW) configured as a **persistent AI development worker** that can be controlled from your primary workstation. This enables:

- Offloading long-running builds, tests, and AI tasks
- Parallel development workflows
- Persistent tmux sessions for continuous operations
- Direct file access via SMB mount

---

## Quick Start

### Check Status

```bash
~/bin/tw status
```

### Open Shell on TW Mac

```bash
~/bin/tw shell
```

### Run Command on TW Mac

```bash
~/bin/tw run 'npm test'
~/bin/tw run 'git pull && npm install'
```

### Attach to tmux Sessions

```bash
~/bin/tw tmux
```

---

## Access Methods

| Method         | Command/Path     | Use Case              |
| -------------- | ---------------- | --------------------- |
| **tw command** | `~/bin/tw [cmd]` | Quick operations      |
| **SSH**        | `ssh tw`         | Interactive shell     |
| **SMB Mount**  | `~/tw-mac/`      | Direct file editing   |
| **tmux**       | `~/bin/tw tmux`  | Long-running sessions |

---

## File Locations

### On Your Mac (Controller)

```
~/tw-mac/                          # SMB mount to TW Mac home
~/bin/tw                           # Control script symlink
~/.claude/tw-mac/health.log        # Health monitor logs
```

### In Repo

```
clawdbot/infrastructure/tw-mac/
├── README.md                      # Full documentation
├── tw-control.sh                  # Control script
├── tw-health-monitor.sh           # Auto-reconnect daemon
└── TEAM-MEMO.md                   # This memo
```

### On TW Mac

```
~/Development/Projects/clawdbot/   # Cloned repo (synced via git, not SMB)
~/Development/DesktopCommanderMCP/ # MCP server for AI agents
```

---

## Common Workflows

### 1. Run Tests on TW Mac (Offload CPU)

```bash
# Start test runner in background tmux session
~/bin/tw run 'tmux new-session -d -s tests "cd ~/Development/Projects/clawdbot && npm test -- --watch"'

# Check results later
~/bin/tw run 'tmux capture-pane -t tests -p | tail -30'

# Stop when done
~/bin/tw run 'tmux kill-session -t tests'
```

### 2. Edit Files Directly

```bash
# Files edited here appear instantly on TW Mac
code ~/tw-mac/Development/Projects/clawdbot/

# Or use any editor - changes sync via SMB
vim ~/tw-mac/Development/Projects/clawdbot/src/index.ts
```

### 3. Run Claude/AI Agent on TW Mac

```bash
# Start Claude in a dedicated session
~/bin/tw run 'tmux new-session -d -s claude "cd ~/Development/Projects/clawdbot && claude"'

# Attach to interact
~/bin/tw tmux
# Then Ctrl-b, s, select 'claude'
```

### 4. Sync Code Changes

```bash
# Pull latest on TW Mac
~/bin/tw run 'cd ~/Development/Projects/clawdbot && git pull'

# Or push from TW Mac
~/bin/tw run 'cd ~/Development/Projects/clawdbot && git push'
```

---

## Services Running on TW Mac

| Service                   | Status Check              | Purpose                       |
| ------------------------- | ------------------------- | ----------------------------- |
| **Desktop Commander MCP** | `tmux has-session -t mcp` | AI agent file/terminal access |
| **SSH Server**            | Always on                 | Remote access                 |
| **SMB File Sharing**      | Always on                 | Direct file mount             |

### Managing Desktop Commander MCP

```bash
~/bin/tw start-mcp    # Start MCP server
~/bin/tw stop-mcp     # Stop MCP server
```

---

## Health Monitoring

A LaunchAgent runs on your Mac that:

- Checks TW Mac connectivity every 60 seconds
- Auto-reconnects SSH if dropped
- Auto-restarts MCP server if stopped

**Logs:** `~/.claude/tw-mac/health.log`

**Manage LaunchAgent:**

```bash
# Stop monitoring
launchctl unload ~/Library/LaunchAgents/com.clawdbot.tw-health-monitor.plist

# Start monitoring
launchctl load ~/Library/LaunchAgents/com.clawdbot.tw-health-monitor.plist
```

---

## Troubleshooting

### "TW Mac unreachable"

1. Check if TW Mac is awake (may need physical wake)
2. Verify Tailscale is active: `tailscale status`
3. Verify network: `ping tw` (Tailscale) or `ping 192.168.1.245` (LAN)

### SSH Connection Issues

```bash
# Reset and reconnect
rm ~/.ssh/sockets/tywhitaker@100.81.110.81-22
~/bin/tw connect
```

### SMB Mount Missing

1. Finder → Go → Connect to Server (⌘K)
2. Enter: `smb://192.168.1.245`
3. Login with TW Mac credentials

### MCP Not Responding

```bash
~/bin/tw stop-mcp
~/bin/tw start-mcp
```

---

## Security Notes

- SSH uses key-based auth (no passwords)
- SMB requires TW Mac user credentials
- **Traffic is encrypted via Tailscale (WireGuard)**
- 1Password CLI available on TW Mac (needs manual `op signin`)
- Access works from both local LAN and remote networks

---

## Next Steps: Infrastructure Review

We are entering a validation and optimization phase for this infrastructure. Please refer to **[REVIEW-TASKS.md](./REVIEW-TASKS.md)** for the full checklist and tracking.

### Phase 1: Validation Testing

- Connectivity, services, workflows, and AI integration.

### Phase 2: Documentation Review

- Accuracy checks and gap analysis.

### Phase 3: Optimization Opportunities

- **Performance:** SSH, SMB, and MCP tuning.
- **Reliability:** Auto-wake and failover.
- **Security:** Keys, firewall, and 1Password.
- **Scalability:** Multi-node and job queues.
- **Developer Experience:** Shell completion and remote debugging.

### Phase 4: Implementation Roadmap

- Prioritized fixes and sign-off checklist.

---

## Contact

For infrastructure issues, check:

1. `~/bin/tw status` for diagnostics
2. Health logs at `~/.claude/tw-mac/health.log`
3. Full docs at `clawdbot/infrastructure/tw-mac/README.md`

---

_TW Mac: 100.81.110.81 (Tailscale) / 192.168.1.245 (LAN)_
_Controller: jederlichman@Jeds-MacBook-Pro_
