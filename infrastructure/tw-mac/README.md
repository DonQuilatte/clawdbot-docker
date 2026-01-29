# TW Mac - Distributed AI Worker Node

> Pair programmer and agentic AI assistant controlled from the main Mac

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        CONTROLLER MAC                           │
│                    (jederlichman@Jeds-MacBook-Pro)              │
├─────────────────────────────────────────────────────────────────┤
│  Antigravity IDE + Claude Code                                  │
│  ├── Desktop Commander MCP (local)                              │
│  ├── tw-control.sh (orchestration)                              │
│  └── Health Monitor (LaunchAgent)                               │
│                                                                  │
│  Access Methods:                                                 │
│  ├── SMB Mount: ~/tw-mac/                                       │
│  ├── SSH: ssh tw                                                │
│  └── tw command: tw [status|shell|run|tmux|...]                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Persistent SSH (ControlMaster)
                              │ Auto-reconnect (Health Monitor)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         WORKER MAC (TW)                          │
│                    (100.81.110.81 / 192.168.1.245)               │
├─────────────────────────────────────────────────────────────────┤
│  Antigravity IDE + Claude Code                                  │
│  ├── Desktop Commander MCP Server (tmux session)                │
│  ├── direnv + 1Password CLI                                     │
│  └── clawdbot repo                                              │
│                                                                  │
│  Services:                                                       │
│  ├── Tailscale VPN (Primary)                                     │
│  ├── Desktop Commander: tmux session "mcp"                      │
│  ├── File Sharing: SMB enabled                                  │
│  └── SSH: OpenSSH server                                        │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Reference

### tw Command (run from Controller Mac)

```bash
tw status      # Show TW Mac connection status
tw connect     # Establish persistent SSH connection
tw disconnect  # Close persistent SSH connection
tw start-mcp   # Start Desktop Commander MCP server
tw stop-mcp    # Stop Desktop Commander MCP server
tw shell       # Open interactive shell on TW Mac
tw tmux        # Attach to tmux session on TW Mac
tw run <cmd>   # Run command on TW Mac
```

### File Access

```bash
# Direct file access via SMB mount
ls ~/tw-mac/Development/Projects/

# Copy files
cp localfile.txt ~/tw-mac/Development/Projects/clawdbot/

# Edit files (appears on TW Mac instantly)
vim ~/tw-mac/Development/Projects/clawdbot/src/main.py
```

### SSH Access

```bash
# Interactive shell
ssh tw

# Run remote command
ssh tw 'cd ~/Development/Projects/clawdbot && git status'

# Port forwarding (e.g., for web dev)
ssh -L 8080:localhost:8080 tw
```

## Services

### Desktop Commander MCP

- Runs in tmux session `mcp` on TW Mac
- Provides file/terminal access for AI agents
- Auto-started by health monitor

### Health Monitor

- LaunchAgent: `com.clawdbot.tw-health-monitor`
- Checks every 60 seconds
- Auto-reconnects SSH if dropped
- Auto-restarts MCP if stopped
- Logs: `~/.claude/tw-mac/health.log`

### SSH Multiplexing

- ControlMaster enabled for faster connections
- ControlPersist 600 (10 minutes)
- ServerAliveInterval 60 (keepalive)

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
2. Enter: `smb://192.168.1.245`
3. Login with TW Mac credentials

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
# Check if mounted
mount | grep 192.168.1.245

# Remount via Finder: ⌘K → smb://192.168.1.245
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
