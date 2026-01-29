# TW Mac Automation

Automated task dispatch, synchronization, and maintenance for the TW Mac distributed development environment.

## Quick Start

```bash
# Install all automation
./install-automation.sh
```

## Components

### Git Hooks

| Hook | Trigger | Action |
|------|---------|--------|
| `pre-commit` | Before commit | Dispatch lint/format checks to TW Mac |
| `post-commit` | After commit | Auto-run tests on TW Mac in background |

### File Watcher

Monitors CLAUDE.md and skills directories. Auto-syncs to TW Mac on any change.

- **Service:** `com.clawdbot.config-watcher`
- **Log:** `~/.claude/tw-mac/config-watcher.log`

### Scheduled Tasks

| Schedule | Service | Actions |
|----------|---------|---------|
| Every 15 min | `com.clawdbot.scheduled-periodic` | Health check, sync, process queue |
| Daily 6am | `com.clawdbot.scheduled-daily` | Cleanup, generate report |

### Smart Dispatcher

Intelligent task routing with load balancing and queuing.

```bash
# Dispatch immediately (if capacity available)
tw-dispatch "Refactor the auth module"

# Queue for later processing
tw-queue "Generate API documentation" low

# Check status
./smart-dispatcher.sh status
```

**Features:**
- Complexity estimation
- TW Mac load checking
- Priority queue (high/normal/low)
- Auto-retry from queue

## Commands

| Command | Description |
|---------|-------------|
| `tw-dispatch 'task'` | Smart dispatch with load balancing |
| `tw-queue 'task' [priority]` | Add to queue |
| `tw-handoff 'task'` | Manual handoff with full context |
| `tw-status` | Show all sessions |
| `tw-collect session` | Get results |

## What's Automated

### On Every Commit
1. Pre-commit: Lint checks run on TW Mac
2. Post-commit: Tests auto-dispatched in background

### Every 15 Minutes
1. Health check (reconnect if needed)
2. Config sync (if changed)
3. Process queued tasks

### Daily (6am)
1. Clean up old sessions (>24h)
2. Remove old handoffs (>7 days)
3. Trim log files
4. Generate daily report

### On Config Change
1. CLAUDE.md modifications auto-sync
2. New skills auto-sync
3. Commands auto-sync

## Log Files

| Log | Purpose |
|-----|---------|
| `~/.claude/tw-mac/config-watcher.log` | Config sync events |
| `~/.claude/tw-mac/dispatcher.log` | Task dispatch events |
| `~/.claude/tw-mac/scheduled.log` | Scheduled task output |
| `~/.claude/tw-mac/daily-report-*.md` | Daily summaries |

## Manual Control

```bash
# Stop config watcher
launchctl unload ~/Library/LaunchAgents/com.clawdbot.config-watcher.plist

# Stop scheduled tasks
launchctl unload ~/Library/LaunchAgents/com.clawdbot.scheduled-periodic.plist
launchctl unload ~/Library/LaunchAgents/com.clawdbot.scheduled-daily.plist

# Restart all
launchctl load ~/Library/LaunchAgents/com.clawdbot.*.plist
```

## Uninstall

```bash
# Remove LaunchAgents
launchctl unload ~/Library/LaunchAgents/com.clawdbot.*.plist
rm ~/Library/LaunchAgents/com.clawdbot.*.plist

# Remove git hooks
rm .git/hooks/pre-commit .git/hooks/post-commit

# Remove commands
rm ~/bin/tw-dispatch ~/bin/tw-queue
```

---

*Part of clawdbot distributed infrastructure*
