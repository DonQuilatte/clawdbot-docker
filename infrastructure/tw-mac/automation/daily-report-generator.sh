#!/bin/bash
# Daily Report Generator - Comprehensive activity report for both Macs
# Generates detailed metrics, task summaries, and health status

REPORT_DIR="$HOME/.claude/tw-mac/reports"
TW_CONTROL="$HOME/bin/tw"
DATE=$(date +%Y-%m-%d)
REPORT_FILE="$REPORT_DIR/daily-report-$DATE.md"

mkdir -p "$REPORT_DIR"

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "$1"; }

# Collect Controller Mac metrics
collect_controller_metrics() {
    cat << EOF
## Controller Mac (Primary)

### System Status
- **Hostname:** $(hostname)
- **Uptime:** $(uptime | awk -F'up ' '{print $2}' | awk -F', ' '{print $1}')
- **Load Average:** $(uptime | awk -F'load averages: ' '{print $2}')
- **Memory:** $(top -l 1 | grep PhysMem | awk '{print $2, $3, $4, $5, $6}')
- **Disk:** $(df -h / | tail -1 | awk '{print $4 " available of " $2}')

### Claude Code Activity (Last 24h)
$(if [ -d "$HOME/.claude/projects" ]; then
    SESSIONS=$(find "$HOME/.claude/projects" -name "*.jsonl" -mtime -1 2>/dev/null | wc -l | tr -d ' ')
    echo "- **Sessions:** $SESSIONS"
else
    echo "- **Sessions:** N/A"
fi)

### Git Activity (Last 24h)
$(cd "$HOME/Development/Projects/clawdbot" 2>/dev/null && git log --since="24 hours ago" --oneline 2>/dev/null | head -10 || echo "No recent commits")

### Dispatched Tasks
$(ls -lt "$HOME/tw-mac/handoffs/handoff-"*.md 2>/dev/null | head -10 | while read line; do
    FILE=$(echo "$line" | awk '{print $NF}')
    TASK=$(grep "^## Task" -A 3 "$FILE" 2>/dev/null | tail -1 | head -c 80)
    echo "- $(basename "$FILE"): $TASK..."
done || echo "No tasks dispatched")

### Received Responses
$(ls -lt "$HOME/tw-mac/handoffs/response-"*.md 2>/dev/null | head -10 | while read line; do
    FILE=$(echo "$line" | awk '{print $NF}')
    echo "- $(basename "$FILE")"
done || echo "No responses received")

EOF
}

# Collect TW Mac metrics
collect_tw_metrics() {
    local TW_AVAILABLE=false

    if "$TW_CONTROL" run 'echo ok' >/dev/null 2>&1; then
        TW_AVAILABLE=true
    fi

    cat << EOF
## TW Mac (Worker)

### Connection Status
EOF

    if [ "$TW_AVAILABLE" = true ]; then
        cat << EOF
- **Status:** ✅ Connected
- **Hostname:** $("$TW_CONTROL" run 'hostname' 2>/dev/null)
- **Uptime:** $("$TW_CONTROL" run "uptime | awk -F'up ' '{print \$2}' | awk -F', ' '{print \$1}'" 2>/dev/null)
- **Load Average:** $("$TW_CONTROL" run "uptime | awk -F'load averages: ' '{print \$2}'" 2>/dev/null)
- **Memory:** $("$TW_CONTROL" run "top -l 1 | grep PhysMem | awk '{print \$2, \$3, \$4, \$5, \$6}'" 2>/dev/null)

### Active Sessions
\`\`\`
$("$TW_CONTROL" run 'tmux list-sessions 2>/dev/null' || echo "No active sessions")
\`\`\`

### MCP Server
- **Status:** $("$TW_CONTROL" run 'pgrep -f DesktopCommanderMCP >/dev/null && echo "✅ Running" || echo "❌ Not running"' 2>/dev/null)

### Completed Tasks (Last 24h)
$("$TW_CONTROL" run 'find ~/handoffs -name "response-*.md" -mtime -1 2>/dev/null | wc -l | tr -d " "' 2>/dev/null || echo "0") responses generated

### Resource Usage
$("$TW_CONTROL" run 'ps aux --sort=-%mem | head -6' 2>/dev/null || "$TW_CONTROL" run 'ps aux | head -6' 2>/dev/null || echo "Unable to collect")

EOF
    else
        cat << EOF
- **Status:** ❌ Disconnected
- **Last Seen:** $(stat -f "%Sm" "$HOME/.ssh/sockets/tywhitaker@"* 2>/dev/null | head -1 || echo "Unknown")

⚠️ TW Mac is currently unreachable. Check network connectivity.

EOF
    fi
}

# Collect sync status
collect_sync_status() {
    cat << EOF
## Synchronization Status

### Config Sync
EOF

    local LOCAL_CLAUDE_HASH=$(md5 -q "$HOME/.claude/CLAUDE.md" 2>/dev/null || echo "missing")
    local REMOTE_CLAUDE_HASH=$("$TW_CONTROL" run 'md5 -q ~/.claude/CLAUDE.md 2>/dev/null' 2>/dev/null || echo "unavailable")

    if [ "$LOCAL_CLAUDE_HASH" = "$REMOTE_CLAUDE_HASH" ]; then
        echo "- **CLAUDE.md:** ✅ In sync"
    else
        echo "- **CLAUDE.md:** ⚠️ Out of sync (run tw-sync-config)"
    fi

    local LOCAL_SKILLS=$(ls "$HOME/.claude/commands" 2>/dev/null | wc -l | tr -d ' ')
    local REMOTE_SKILLS=$("$TW_CONTROL" run 'ls ~/.claude/commands 2>/dev/null | wc -l | tr -d " "' 2>/dev/null || echo "0")

    if [ "$LOCAL_SKILLS" = "$REMOTE_SKILLS" ]; then
        echo "- **Skills:** ✅ In sync ($LOCAL_SKILLS skills)"
    else
        echo "- **Skills:** ⚠️ Mismatch (local: $LOCAL_SKILLS, remote: $REMOTE_SKILLS)"
    fi

    cat << EOF

### SMB Mount
EOF
    if mount | grep -qE "tw|tywhitaker"; then
        echo "- **Status:** ✅ Mounted at ~/tw-mac/"
    else
        echo "- **Status:** ❌ Not mounted"
    fi

    cat << EOF

### Tailscale
EOF
    local TS_CLI=""
    if command -v tailscale >/dev/null 2>&1; then
        TS_CLI="tailscale"
    elif [ -x "/Applications/Tailscale.app/Contents/MacOS/Tailscale" ]; then
        TS_CLI="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
    fi

    if [ -n "$TS_CLI" ]; then
        if $TS_CLI status >/dev/null 2>&1; then
            echo "- **Status:** ✅ Connected"
            echo "- **Controller IP:** $($TS_CLI ip -4 2>/dev/null)"
            echo "- **TW Mac IP:** 100.81.110.81"
        else
            echo "- **Status:** ❌ Disconnected"
        fi
    else
        echo "- **Status:** ⚠️ CLI not found"
    fi
}

# Collect automation status
collect_automation_status() {
    cat << EOF

## Automation Status

### LaunchAgents
EOF

    for agent in "config-watcher" "scheduled-periodic" "scheduled-daily" "tw-health-monitor"; do
        if launchctl list 2>/dev/null | grep -q "com.clawdbot.$agent"; then
            echo "- **$agent:** ✅ Running"
        else
            echo "- **$agent:** ❌ Not running"
        fi
    done

    cat << EOF

### Git Hooks
EOF
    local PROJECT_ROOT="$HOME/Development/Projects/clawdbot"
    [ -L "$PROJECT_ROOT/.git/hooks/pre-commit" ] && echo "- **pre-commit:** ✅ Installed" || echo "- **pre-commit:** ❌ Not installed"
    [ -L "$PROJECT_ROOT/.git/hooks/post-commit" ] && echo "- **post-commit:** ✅ Installed" || echo "- **post-commit:** ❌ Not installed"

    cat << EOF

### Task Queue
EOF
    local QUEUE_FILE="$HOME/.claude/tw-mac/task-queue.txt"
    if [ -f "$QUEUE_FILE" ]; then
        local QUEUE_COUNT=$(wc -l < "$QUEUE_FILE" | tr -d ' ')
        echo "- **Queued tasks:** $QUEUE_COUNT"
    else
        echo "- **Queued tasks:** 0"
    fi
}

# Collect error summary
collect_errors() {
    cat << EOF

## Errors & Warnings (Last 24h)

### Health Monitor
\`\`\`
$(grep -iE "error|fail|warn" "$HOME/.claude/tw-mac/health.log" 2>/dev/null | tail -10 || echo "No errors")
\`\`\`

### Dispatcher
\`\`\`
$(grep -iE "error|fail|warn" "$HOME/.claude/tw-mac/dispatcher.log" 2>/dev/null | tail -10 || echo "No errors")
\`\`\`

### Scheduled Tasks
\`\`\`
$(grep -iE "error|fail|warn" "$HOME/.claude/tw-mac/scheduled.log" 2>/dev/null | tail -10 || echo "No errors")
\`\`\`

EOF
}

# Generate recommendations
generate_recommendations() {
    cat << EOF
## Recommendations

EOF

    local RECS=0

    # Check TW Mac connection
    if ! "$TW_CONTROL" run 'echo ok' >/dev/null 2>&1; then
        echo "- ⚠️ **Reconnect TW Mac:** Run \`~/bin/tw connect\`"
        ((RECS++))
    fi

    # Check config sync
    local LOCAL_HASH=$(md5 -q "$HOME/.claude/CLAUDE.md" 2>/dev/null || echo "a")
    local REMOTE_HASH=$("$TW_CONTROL" run 'md5 -q ~/.claude/CLAUDE.md 2>/dev/null' 2>/dev/null || echo "b")
    if [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
        echo "- ⚠️ **Sync configs:** Run \`tw-sync-config\`"
        ((RECS++))
    fi

    # Check SMB mount
    if ! mount | grep -qE "tw|tywhitaker"; then
        echo "- ⚠️ **Mount SMB:** Run \`open smb://tywhitaker@tw.local/tywhitaker\`"
        ((RECS++))
    fi

    # Check for old sessions
    local OLD_SESSIONS=$("$TW_CONTROL" run 'tmux list-sessions 2>/dev/null | wc -l' 2>/dev/null || echo "0")
    if [ "$OLD_SESSIONS" -gt 5 ]; then
        echo "- ⚠️ **Clean sessions:** $OLD_SESSIONS active sessions, consider cleanup"
        ((RECS++))
    fi

    if [ $RECS -eq 0 ]; then
        echo "✅ No issues detected. System operating normally."
    fi
}

# Main report generation
generate_report() {
    cat << EOF > "$REPORT_FILE"
# Clawdbot Daily Report

**Date:** $DATE
**Generated:** $(date)

---

$(collect_controller_metrics)

---

$(collect_tw_metrics)

---

$(collect_sync_status)

$(collect_automation_status)

$(collect_errors)

---

$(generate_recommendations)

---

*Report generated by clawdbot automation*
EOF

    echo "$REPORT_FILE"
}

# Terminal summary
print_summary() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo "Clawdbot Daily Report - $DATE"
    echo "═══════════════════════════════════════════"
    echo ""

    # Quick status
    if "$TW_CONTROL" run 'echo ok' >/dev/null 2>&1; then
        log "${GREEN}✓${NC} TW Mac: Connected"
    else
        log "${RED}✗${NC} TW Mac: Disconnected"
    fi

    if mount | grep -qE "tw|tywhitaker"; then
        log "${GREEN}✓${NC} SMB Mount: Active"
    else
        log "${RED}✗${NC} SMB Mount: Inactive"
    fi

    local SESSIONS=$("$TW_CONTROL" run 'tmux list-sessions 2>/dev/null | wc -l' 2>/dev/null || echo "0")
    log "${GREEN}✓${NC} Active Sessions: $SESSIONS"

    local TASKS=$(ls "$HOME/tw-mac/handoffs/handoff-"*.md 2>/dev/null | wc -l | tr -d ' ')
    local RESPONSES=$(ls "$HOME/tw-mac/handoffs/response-"*.md 2>/dev/null | wc -l | tr -d ' ')
    log "${GREEN}✓${NC} Tasks: $TASKS dispatched, $RESPONSES completed"

    echo ""
    echo "Full report: $REPORT_FILE"
    echo ""
}

# Run
case "$1" in
    --quiet|-q)
        generate_report
        ;;
    --json)
        # Future: JSON output for integrations
        echo "JSON output not yet implemented"
        ;;
    *)
        REPORT=$(generate_report)
        print_summary
        ;;
esac
