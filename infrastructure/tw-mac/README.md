# TW Mac - Distributed AI Worker Node

> Pair programmer and agentic AI assistant controlled from the main Mac

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        CONTROLLER MAC                           │
│                    (jederlichman@Jeds-MacBook-Pro)              │
├─────────────────────────────────────────────────────────────────┤
│  Antigravity IDE + Claude Code                                  │
│  ├── Clawdbot Gateway (192.168.1.230:18789)                     │
│  ├── Node Watchdog (LaunchAgent: com.clawdbot.watchdog)         │
│  └── tw-control.sh (orchestration)                              │
│                                                                 │
│  Access Methods:                                                │
│  ├── SSH: ssh tw                                                │
│  └── Clawdbot: clawdbot nodes run --node TW                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ 1. Persistent SSH (ControlMaster)
                              │ 2. Clawdbot Network (WebSocket)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         WORKER MAC (TW)                         │
│                    (192.168.1.245)                              │
├─────────────────────────────────────────────────────────────────┤
│  Antigravity IDE + Claude Code                                  │
│  ├── Clawdbot Node Service (LaunchAgent)                        │
│  ├── Direnv + 1Password CLI                                     │
│  └── clawdbot repo                                              │
│                                                                 │
│  Services:                                                      │
│  ├── com.clawdbot.node (Agentic Worker)                         │
│  ├── Desktop Commander (Legacy MCP via tmux)                    │
│  └── SSH: OpenSSH server                                        │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Reference

### Clawdbot Node (Agentic)

```bash
# Check status
clawdbot nodes status

# Execute headless command
clawdbot nodes run --node TW -- echo "Hello World"

# Force restart remote service (via Watchdog logic)
scripts/tw-node-watchdog.sh
```

### Legacy tw Command

```bash
tw status      # Show TW Mac connection status
tw connect     # Establish persistent SSH connection
tw shell       # Open interactive shell on TW Mac
```

### File Access

```bash
# Direct file access via SMB mount
ls ~/tw-mac/Development/Projects/
```

### SSH Access

```bash
ssh tw
```

## Services

### Clawdbot Agent Node (NEW)

- **Role:** Autonomous execution, file access, agent tasks.
- **Service:** `com.clawdbot.node` (on TW Mac).
- **Monitoring:** `com.clawdbot.watchdog.tw` (on Controller Mac).
- **Recovery:** Watchdog checks every 5 mins and restarts via SSH if disconnected.

### Desktop Commander MCP (Legacy)

- Runs in tmux session `mcp` on TW Mac
- Provides file/terminal access for AI agents
- Auto-started by health monitor

### Health Monitor (Legacy SSH)

- LaunchAgent: `com.clawdbot.tw-health-monitor`
- Checks every 60 seconds
- Auto-reconnects SSH if dropped

### SSH Multiplexing

- ControlMaster enabled for faster connections
- ControlPersist 600 (10 minutes)

## Manual Setup Required

### 1Password on TW Mac

Sign in interactively on TW Mac:

```bash
# On TW Mac terminal
op account add --address my.1password.com
op signin
```

### SMB Mount (if disconnected)

1. Finder → Go → Connect to Server (⌘K)
2. Enter: `smb://TW.local` (or `smb://192.168.1.245`)
3. Login with TW Mac credentials (user: `1`)
4. Select `tywhitaker` share for home directory access

## Paths

| Location              | Path                                      |
| --------------------- | ----------------------------------------- |
| TW Mac Home (via SMB) | `~/tw-mac/`                               |
| TW Mac Projects       | `~/tw-mac/Development/Projects/`          |
| clawdbot on TW        | `~/tw-mac/Development/Projects/clawdbot/` |
| Control scripts       | `~/.claude/tw-mac/`                       |
| Health logs           | `~/.claude/tw-mac/health.log`             |
| SSH sockets           | `~/.ssh/sockets/`                         |

## Troubleshooting

### TW Mac unreachable

```bash
# Check network
ping 192.168.1.245

# Check if TW Mac is awake (may need to wake manually)
```

### SSH connection fails

```bash
# Reset control socket
rm ~/.ssh/sockets/tywhitaker@100.81.110.81-22
tw connect
```

### MCP not responding

```bash
tw stop-mcp
tw start-mcp

# Check tmux session
tw run 'tmux list-sessions'
```

### SMB mount missing

```bash
# Check if mounted (case-insensitive)
mount | grep -iE "192.168.1.245|tw\.local|tywhitaker"

# Remount via Finder: ⌘K → smb://TW.local
# Or from terminal:
open "smb://TW.local"
```

## Development Workflows

### Run Claude on TW Mac

```bash
# Start Claude in a tmux session
tw run 'tmux new-session -d -s claude "cd ~/Development/Projects/clawdbot && claude"'

# Attach to watch
tw tmux
# Then: Ctrl-b, then s, select 'claude' session
```

### Parallel Development

1. Run builds/tests on TW Mac (offload CPU)
2. Edit files from Controller Mac
3. Monitor via `tw run` or tmux

### Long-running Tasks

```bash
# Start task in tmux
tw run 'tmux new-session -d -s build "cd ~/Development/Projects/clawdbot && npm run build:watch"'

# Check progress anytime
tw run 'tmux capture-pane -t build -p | tail -20'
```

---

_Generated: $(date)_
_Controller: jederlichman@Jeds-MacBook-Pro (100.73.138.46)_
_Worker: tywhitaker@TW.lan (100.81.110.81 / 192.168.1.245)_
