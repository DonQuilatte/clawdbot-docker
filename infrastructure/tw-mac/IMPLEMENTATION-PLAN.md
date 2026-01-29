# TW Mac Distributed Development - Implementation Plan

**Date:** January 29, 2026
**Status:** Ready for Implementation
**Estimated Tasks:** 6 major components, ~15 individual items

---

## Overview

This plan implements full environment synchronization, context sharing, and orchestration capabilities between Controller Mac and TW Mac for distributed AI-assisted development.

---

## Phase 1: Environment Synchronization Scripts

### Task 1.1: Create tw-env-sync script
**Location:** `~/bin/tw-env-sync`
**Purpose:** Full environment sync between Macs

```bash
#!/bin/bash
# Full environment sync to TW Mac
# Syncs: CLAUDE.md, .claude/, shell configs, git config

set -e

REMOTE="tw"
LOCAL_CLAUDE="$HOME/.claude"
REMOTE_HOME="/Users/tywhitaker"

echo "═══════════════════════════════════════"
echo "TW Mac Environment Sync"
echo "═══════════════════════════════════════"

# 1. Global CLAUDE.md
echo "→ Syncing global CLAUDE.md..."
rsync -avz "$HOME/.claude/CLAUDE.md" "$REMOTE:$REMOTE_HOME/.claude/CLAUDE.md" 2>/dev/null || true

# 2. Project CLAUDE.md files
echo "→ Syncing project CLAUDE.md files..."
rsync -avz "$HOME/CLAUDE.md" "$REMOTE:$REMOTE_HOME/CLAUDE.md" 2>/dev/null || true
rsync -avz "$HOME/Development/Projects/clawdbot/CLAUDE.md" "$REMOTE:$REMOTE_HOME/Development/Projects/clawdbot/CLAUDE.md" 2>/dev/null || true

# 3. Claude skills directory
echo "→ Syncing Claude skills..."
if [ -d "$LOCAL_CLAUDE/commands" ]; then
    rsync -avz --delete "$LOCAL_CLAUDE/commands/" "$REMOTE:$REMOTE_HOME/.claude/commands/"
fi

# 4. Claude settings (excluding session-specific data)
echo "→ Syncing Claude settings..."
rsync -avz --exclude='*.log' --exclude='projects/' --exclude='statsig/' \
    "$LOCAL_CLAUDE/settings.json" "$REMOTE:$REMOTE_HOME/.claude/settings.json" 2>/dev/null || true

# 5. Shell configuration
echo "→ Syncing shell config..."
rsync -avz "$HOME/.zshrc" "$REMOTE:$REMOTE_HOME/.zshrc"
rsync -avz "$HOME/.zprofile" "$REMOTE:$REMOTE_HOME/.zprofile" 2>/dev/null || true

# 6. Git configuration
echo "→ Syncing git config..."
rsync -avz "$HOME/.gitconfig" "$REMOTE:$REMOTE_HOME/.gitconfig"

# 7. Sync the tw-mac infrastructure scripts
echo "→ Syncing infrastructure scripts..."
rsync -avz "$HOME/Development/Projects/clawdbot/infrastructure/tw-mac/" \
    "$REMOTE:$REMOTE_HOME/Development/Projects/clawdbot/infrastructure/tw-mac/"

# 8. Verify sync
echo ""
echo "═══════════════════════════════════════"
echo "Verification"
echo "═══════════════════════════════════════"
ssh $REMOTE 'echo "CLAUDE.md exists: $([ -f ~/.claude/CLAUDE.md ] && echo YES || echo NO)"'
ssh $REMOTE 'echo "Commands dir: $(ls ~/.claude/commands 2>/dev/null | wc -l | tr -d " ") skills"'
ssh $REMOTE 'echo "Settings.json: $([ -f ~/.claude/settings.json ] && echo YES || echo NO)"'

echo ""
echo "✓ Environment sync complete"
```

**Make executable:** `chmod +x ~/bin/tw-env-sync`

---

### Task 1.2: Create tw-sync-config script (lightweight)
**Location:** `~/bin/tw-sync-config`
**Purpose:** Quick config-only sync (no shell/git)

```bash
#!/bin/bash
# Lightweight config sync - just Claude-specific files

REMOTE="tw"
REMOTE_HOME="/Users/tywhitaker"

echo "Syncing Claude configuration..."

# CLAUDE.md files
rsync -avz "$HOME/.claude/CLAUDE.md" "$REMOTE:$REMOTE_HOME/.claude/CLAUDE.md" 2>/dev/null || true
rsync -avz "$HOME/CLAUDE.md" "$REMOTE:$REMOTE_HOME/CLAUDE.md" 2>/dev/null || true

# Skills/commands
if [ -d "$HOME/.claude/commands" ]; then
    rsync -avz --delete "$HOME/.claude/commands/" "$REMOTE:$REMOTE_HOME/.claude/commands/"
fi

echo "✓ Config sync complete"
```

---

## Phase 2: Context Handoff System

### Task 2.1: Create handoff script (Controller)
**Location:** `~/bin/tw-handoff`
**Purpose:** Create context handoff files for TW Mac sessions

```bash
#!/bin/bash
# Create handoff file for TW Mac session
# Usage: tw-handoff "task description" "context notes" "specific instructions"

HANDOFF_DIR="$HOME/tw-mac/handoffs"
mkdir -p "$HANDOFF_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
HANDOFF_FILE="$HANDOFF_DIR/handoff-$TIMESTAMP.md"

TASK="${1:-No task specified}"
CONTEXT="${2:-No additional context}"
INSTRUCTIONS="${3:-Follow standard procedures}"

# Get git context if in a repo
GIT_STATUS=""
GIT_BRANCH=""
GIT_RECENT=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    GIT_BRANCH=$(git branch --show-current 2>/dev/null)
    GIT_STATUS=$(git status --short 2>/dev/null | head -20)
    GIT_RECENT=$(git log --oneline -5 2>/dev/null)
fi

cat > "$HANDOFF_FILE" << EOF
# Session Handoff

**Created:** $(date)
**From:** Controller Mac (jederlichman)
**To:** TW Mac (tywhitaker)

---

## Task

$TASK

---

## Context

$CONTEXT

---

## Git State

**Branch:** $GIT_BRANCH

**Recent Changes:**
\`\`\`
$GIT_STATUS
\`\`\`

**Recent Commits:**
\`\`\`
$GIT_RECENT
\`\`\`

---

## Instructions

$INSTRUCTIONS

---

## Response Location

Write your response/results to:
\`/Users/tywhitaker/handoffs/response-$TIMESTAMP.md\`

Or output to tmux session for capture.

---

*Handoff ID: $TIMESTAMP*
EOF

echo "✓ Handoff created: $HANDOFF_FILE"
echo "  TW Mac path: /Users/tywhitaker/handoffs/handoff-$TIMESTAMP.md"
echo ""
echo "Start TW Mac session with:"
echo "  ~/bin/tw run 'tmux new-session -d -s task-$TIMESTAMP \"claude\"'"
echo "  ~/bin/tw run 'tmux send-keys -t task-$TIMESTAMP \"Read /Users/tywhitaker/handoffs/handoff-$TIMESTAMP.md and begin work\" Enter'"
```

---

### Task 2.2: Create handoff reader (TW Mac)
**Location:** `~/bin/read-handoff` (on TW Mac)
**Purpose:** List and display handoff files

```bash
#!/bin/bash
# Read handoff files from Controller Mac
# Run on TW Mac

HANDOFF_DIR="$HOME/handoffs"

if [ "$1" = "list" ] || [ -z "$1" ]; then
    echo "Available handoffs:"
    ls -lt "$HANDOFF_DIR"/handoff-*.md 2>/dev/null | head -10
    echo ""
    echo "Usage: read-handoff <timestamp> or read-handoff latest"
elif [ "$1" = "latest" ]; then
    LATEST=$(ls -t "$HANDOFF_DIR"/handoff-*.md 2>/dev/null | head -1)
    if [ -n "$LATEST" ]; then
        cat "$LATEST"
    else
        echo "No handoffs found"
    fi
else
    FILE="$HANDOFF_DIR/handoff-$1.md"
    if [ -f "$FILE" ]; then
        cat "$FILE"
    else
        echo "Handoff not found: $FILE"
    fi
fi
```

---

### Task 2.3: Create response script (TW Mac)
**Location:** `~/bin/report-back` (on TW Mac)
**Purpose:** Write response back to shared location

```bash
#!/bin/bash
# Report results back to Controller
# Usage: report-back <handoff-id> "summary"
# Or pipe content: echo "results" | report-back <handoff-id>

HANDOFF_ID="$1"
SUMMARY="$2"
RESPONSE_DIR="$HOME/handoffs"

if [ -z "$HANDOFF_ID" ]; then
    echo "Usage: report-back <handoff-id> [summary]"
    echo "   or: cat results.txt | report-back <handoff-id>"
    exit 1
fi

RESPONSE_FILE="$RESPONSE_DIR/response-$HANDOFF_ID.md"

# Check if content is being piped
if [ ! -t 0 ]; then
    CONTENT=$(cat)
else
    CONTENT="$SUMMARY"
fi

cat > "$RESPONSE_FILE" << EOF
# Task Response

**Handoff ID:** $HANDOFF_ID
**Completed:** $(date)
**From:** TW Mac (tywhitaker)

---

## Summary

$SUMMARY

---

## Results

$CONTENT

---

*Response complete*
EOF

echo "✓ Response written: $RESPONSE_FILE"
echo "  Controller can read: ~/tw-mac/handoffs/response-$HANDOFF_ID.md"
```

---

## Phase 3: Orchestration Skills

### Task 3.1: Create /tw-task skill (Controller)
**Location:** `~/.claude/commands/tw-task.md`

```markdown
---
name: tw-task
description: Dispatch a task to TW Mac worker
arguments:
  - name: task
    description: Task description for TW Mac
    required: true
  - name: session
    description: Session name (default: auto-generated)
    required: false
---

# TW Mac Task Dispatch

Dispatch a task to TW Mac for parallel execution.

## Process

1. Create handoff file with task context
2. Start tmux session on TW Mac
3. Launch Claude in session with handoff reference
4. Return session ID for monitoring

## Commands

```bash
# Generate session ID
SESSION="${session:-task-$(date +%H%M%S)}"

# Create handoff
~/bin/tw-handoff "$task" "Dispatched via /tw-task skill" "Complete task and report back"

# Start session on TW Mac
~/bin/tw run "tmux new-session -d -s $SESSION 'claude'"

# Send task
~/bin/tw run "tmux send-keys -t $SESSION 'Read the latest handoff file in ~/handoffs/ and complete the task described' Enter"

echo "Task dispatched to TW Mac"
echo "Session: $SESSION"
echo "Monitor: ~/bin/tw run 'tmux capture-pane -t $SESSION -p | tail -50'"
```
```

---

### Task 3.2: Create /tw-status skill (Controller)
**Location:** `~/.claude/commands/tw-status.md`

```markdown
---
name: tw-status
description: Check status of all TW Mac sessions
---

# TW Mac Status

Check the status of all running sessions on TW Mac.

## Commands

```bash
echo "═══════════════════════════════════════"
echo "TW Mac Status Report"
echo "═══════════════════════════════════════"
echo ""

# Connection status
echo "Connection:"
~/bin/tw status | head -5
echo ""

# Active tmux sessions
echo "Active Sessions:"
~/bin/tw run 'tmux list-sessions 2>/dev/null' || echo "  No active sessions"
echo ""

# Pending handoffs
echo "Pending Handoffs:"
ls -lt ~/tw-mac/handoffs/handoff-*.md 2>/dev/null | head -5 || echo "  None"
echo ""

# Completed responses
echo "Recent Responses:"
ls -lt ~/tw-mac/handoffs/response-*.md 2>/dev/null | head -5 || echo "  None"
echo ""

# System resources
echo "TW Mac Resources:"
~/bin/tw run 'echo "CPU: $(top -l 1 | grep "CPU usage" | head -1)"'
~/bin/tw run 'echo "Memory: $(top -l 1 | grep "PhysMem" | head -1)"'
```
```

---

### Task 3.3: Create /tw-collect skill (Controller)
**Location:** `~/.claude/commands/tw-collect.md`

```markdown
---
name: tw-collect
description: Collect results from TW Mac session
arguments:
  - name: session
    description: Session name to collect from
    required: true
---

# Collect TW Mac Results

Capture output from a TW Mac session and any response files.

## Commands

```bash
SESSION="$session"
echo "Collecting results from session: $SESSION"
echo ""

# Capture tmux output
echo "═══════════════════════════════════════"
echo "Session Output (last 200 lines)"
echo "═══════════════════════════════════════"
~/bin/tw run "tmux capture-pane -t $SESSION -p -S -200" 2>/dev/null || echo "Session not found or ended"

# Check for response files
echo ""
echo "═══════════════════════════════════════"
echo "Response Files"
echo "═══════════════════════════════════════"
RESPONSES=$(ls -t ~/tw-mac/handoffs/response-*.md 2>/dev/null | head -3)
if [ -n "$RESPONSES" ]; then
    for f in $RESPONSES; do
        echo "--- $f ---"
        cat "$f"
        echo ""
    done
else
    echo "No response files found"
fi
```
```

---

## Phase 4: CLAUDE.md Rules

### Task 4.1: Add distributed development rules to global CLAUDE.md
**Location:** `~/.claude/CLAUDE.md` (append)

```markdown
---

## Distributed Development (TW Mac)

### Architecture
- **Controller Mac**: Primary development, orchestration, user interaction
- **TW Mac**: Worker node for parallel tasks, builds, long-running processes

### Available Commands
- `~/bin/tw status` - Check TW Mac connectivity and status
- `~/bin/tw run '<cmd>'` - Execute command on TW Mac
- `~/bin/tw tmux` - Attach to TW Mac tmux
- `~/bin/tw-handoff` - Create task handoff
- `~/bin/tw-env-sync` - Sync full environment
- `~/bin/tw-sync-config` - Sync Claude config only

### Skills
- `/tw-task` - Dispatch task to TW Mac
- `/tw-status` - Check all TW Mac sessions
- `/tw-collect` - Gather results from session

### Workflow Rules

1. **Before delegating complex tasks**: Create a handoff file with full context
2. **Session naming**: Use descriptive names (`review-auth`, `build-v2`, not `session1`)
3. **Always capture output**: Use tmux capture or write to response files
4. **Sync before major work**: Run `tw-sync-config` to ensure skills/rules match
5. **Check status regularly**: Use `/tw-status` to monitor running work

### Context Sharing
- Handoffs go to: `~/tw-mac/handoffs/`
- Responses come from: `~/tw-mac/handoffs/response-*.md`
- Files sync via: SMB mount at `~/tw-mac/`
- Code syncs via: Git (push/pull)

### Do NOT
- Start TW Mac sessions without handoff context for complex tasks
- Leave orphaned tmux sessions running
- Assume TW Mac has latest code without git pull
- Forget to collect results before ending sessions
```

---

### Task 4.2: Create TW Mac specific CLAUDE.md
**Location:** `/Users/tywhitaker/.claude/CLAUDE.md` (on TW Mac)

```markdown
# TW Mac Worker Node Configuration

## Role
This Mac operates as a **worker node** for distributed development. Tasks are dispatched from the Controller Mac.

## Startup Checklist
1. Check for handoff files: `ls ~/handoffs/handoff-*.md`
2. Read latest handoff: `~/bin/read-handoff latest`
3. Confirm task understanding before proceeding

## Available Commands
- `~/bin/read-handoff [id|latest|list]` - Read task handoffs
- `~/bin/report-back <id> "summary"` - Report results to Controller

## Workflow Rules

1. **Always read handoff first**: Before starting work, read the handoff file
2. **Report completion**: Use `report-back` or write to response file
3. **Log significant output**: Write to `/tmp/` for debugging
4. **Keep sessions named**: Match handoff ID when possible

## Communication
- Handoffs arrive in: `~/handoffs/`
- Responses go to: `~/handoffs/response-<id>.md`
- Controller can see via: SMB mount

## Git Sync
Always pull latest before starting work:
```bash
cd ~/Development/Projects/clawdbot && git pull
```

## Do NOT
- Start work without reading handoff
- Modify files without confirming task scope
- Leave work unreported
- Assume context from previous sessions
```

---

## Phase 5: Integration with Health Monitor

### Task 5.1: Add sync check to health monitor
**Location:** Update `infrastructure/tw-mac/tw-health-monitor.sh`

Add to the health check routine:

```bash
# Check config sync status
check_config_sync() {
    local LOCAL_HASH=$(md5 -q "$HOME/.claude/CLAUDE.md" 2>/dev/null || echo "none")
    local REMOTE_HASH=$(ssh $SSH_OPTS $TW_HOST "md5 -q ~/.claude/CLAUDE.md 2>/dev/null" || echo "none")

    if [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
        log "WARN" "CLAUDE.md out of sync - consider running tw-sync-config"
    fi
}
```

---

## Phase 6: Testing

### Task 6.1: Add sync tests
**Location:** `tests/tw-mac/integration/test-env-sync.sh`

```bash
#!/bin/bash
# Integration tests for environment sync

PASS=0
FAIL=0

log_pass() { echo -e "\033[0;32m✓ PASS\033[0m: $1"; ((PASS++)); }
log_fail() { echo -e "\033[0;31m✗ FAIL\033[0m: $1"; ((FAIL++)); }

echo "=========================================="
echo "Environment Sync Tests"
echo "=========================================="

# Test 1: tw-env-sync exists
if [ -x "$HOME/bin/tw-env-sync" ]; then
    log_pass "tw-env-sync script exists"
else
    log_fail "tw-env-sync script missing"
fi

# Test 2: tw-handoff exists
if [ -x "$HOME/bin/tw-handoff" ]; then
    log_pass "tw-handoff script exists"
else
    log_fail "tw-handoff script missing"
fi

# Test 3: Handoffs directory accessible via SMB
if [ -d "$HOME/tw-mac/handoffs" ] || ssh tw '[ -d ~/handoffs ]'; then
    log_pass "Handoffs directory accessible"
else
    log_fail "Handoffs directory not found"
fi

# Test 4: CLAUDE.md synced
LOCAL_EXISTS=$([ -f "$HOME/.claude/CLAUDE.md" ] && echo "yes" || echo "no")
REMOTE_EXISTS=$(ssh tw '[ -f ~/.claude/CLAUDE.md ] && echo "yes" || echo "no"' 2>/dev/null)
if [ "$LOCAL_EXISTS" = "yes" ] && [ "$REMOTE_EXISTS" = "yes" ]; then
    log_pass "CLAUDE.md exists on both Macs"
else
    log_fail "CLAUDE.md missing (local: $LOCAL_EXISTS, remote: $REMOTE_EXISTS)"
fi

# Test 5: Skills directory synced
LOCAL_SKILLS=$(ls "$HOME/.claude/commands" 2>/dev/null | wc -l | tr -d ' ')
REMOTE_SKILLS=$(ssh tw 'ls ~/.claude/commands 2>/dev/null | wc -l | tr -d " "' 2>/dev/null || echo "0")
if [ "$LOCAL_SKILLS" = "$REMOTE_SKILLS" ]; then
    log_pass "Skills count matches ($LOCAL_SKILLS)"
else
    log_fail "Skills count mismatch (local: $LOCAL_SKILLS, remote: $REMOTE_SKILLS)"
fi

echo ""
echo "=========================================="
echo "Passed: $PASS | Failed: $FAIL"
echo "=========================================="

[ $FAIL -gt 0 ] && exit 1
exit 0
```

---

## Implementation Order

| Phase | Task | Priority | Dependencies |
|-------|------|----------|--------------|
| 1 | tw-env-sync | High | None |
| 1 | tw-sync-config | High | None |
| 2 | tw-handoff | High | Phase 1 |
| 2 | read-handoff (TW) | High | Phase 1 |
| 2 | report-back (TW) | Medium | Phase 2.1 |
| 3 | /tw-task skill | Medium | Phase 2 |
| 3 | /tw-status skill | Medium | Phase 1 |
| 3 | /tw-collect skill | Medium | Phase 2 |
| 4 | CLAUDE.md rules | High | None |
| 4 | TW Mac CLAUDE.md | High | Phase 1 |
| 5 | Health monitor update | Low | Phase 4 |
| 6 | Sync tests | Medium | All above |

---

## Handoff to Agents

Each task above can be implemented by a Claude Code agent with the following pattern:

```bash
# Example: Implement Phase 1, Task 1.1
~/bin/tw run 'tmux new-session -d -s impl-sync "claude"'
~/bin/tw run 'tmux send-keys -t impl-sync "Read /Users/tywhitaker/Development/Projects/clawdbot/infrastructure/tw-mac/IMPLEMENTATION-PLAN.md and implement Phase 1, Task 1.1 (tw-env-sync script). Create the script at ~/bin/tw-env-sync and make it executable." Enter'
```

Or from Controller directly:
```bash
# Implement locally
claude "Read infrastructure/tw-mac/IMPLEMENTATION-PLAN.md and implement Phase 1, Task 1.1"
```

---

## Verification Checklist

After implementation, verify:

- [ ] `~/bin/tw-env-sync` runs without errors
- [ ] `~/bin/tw-sync-config` syncs CLAUDE.md and skills
- [ ] `~/bin/tw-handoff` creates handoff files
- [ ] TW Mac can read handoffs via `read-handoff`
- [ ] TW Mac can report back via `report-back`
- [ ] `/tw-task` dispatches tasks successfully
- [ ] `/tw-status` shows accurate status
- [ ] `/tw-collect` retrieves results
- [ ] All tests pass: `./tests/tw-mac/run-all.sh`

---

*Implementation plan ready for agent handoff*
