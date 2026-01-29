#!/bin/bash
# Scheduled automation tasks - run via cron or launchd
# Cron example: */15 * * * * ~/Development/Projects/clawdbot/infrastructure/tw-mac/automation/scheduled-tasks.sh periodic

TW_CONTROL="$HOME/bin/tw"
DISPATCHER="$HOME/Development/Projects/clawdbot/infrastructure/tw-mac/automation/smart-dispatcher.sh"
LOG_FILE="$HOME/.claude/tw-mac/scheduled.log"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Health check and auto-recovery
health_check() {
    log "Running health check..."

    # Check TW Mac connectivity
    if ! "$TW_CONTROL" run 'echo ok' >/dev/null 2>&1; then
        log "TW Mac unreachable, attempting reconnect..."
        "$TW_CONTROL" connect 2>/dev/null
        sleep 5

        if ! "$TW_CONTROL" run 'echo ok' >/dev/null 2>&1; then
            log "Reconnect failed"
            return 1
        fi
        log "Reconnected successfully"
    fi

    # Check MCP server
    if ! "$TW_CONTROL" run 'pgrep -f DesktopCommanderMCP' >/dev/null 2>&1; then
        log "MCP server not running, restarting..."
        "$TW_CONTROL" start-mcp 2>/dev/null
    fi

    # Clean up old sessions (>24h)
    local OLD_SESSIONS=$("$TW_CONTROL" run 'tmux list-sessions -F "#{session_name}:#{session_created}" 2>/dev/null' | while read line; do
        SESSION=$(echo "$line" | cut -d: -f1)
        CREATED=$(echo "$line" | cut -d: -f2)
        NOW=$(date +%s)
        AGE=$((NOW - CREATED))
        if [ $AGE -gt 86400 ]; then
            echo "$SESSION"
        fi
    done)

    for session in $OLD_SESSIONS; do
        log "Killing old session: $session"
        "$TW_CONTROL" run "tmux kill-session -t $session" 2>/dev/null
    done

    log "Health check complete"
}

# Sync configs if changed
sync_if_needed() {
    local LOCAL_HASH=$(md5 -q "$HOME/.claude/CLAUDE.md" 2>/dev/null || echo "none")
    local REMOTE_HASH=$("$TW_CONTROL" run 'md5 -q ~/.claude/CLAUDE.md 2>/dev/null' 2>/dev/null || echo "none")

    if [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
        log "Config out of sync, syncing..."
        "$HOME/bin/tw-sync-config" >> "$LOG_FILE" 2>&1
    fi
}

# Process any queued tasks
process_queue() {
    if [ -x "$DISPATCHER" ]; then
        "$DISPATCHER" process >> "$LOG_FILE" 2>&1
    fi
}

# Cleanup old handoffs and logs
cleanup() {
    log "Running cleanup..."

    # Remove handoffs older than 7 days
    find "$HOME/tw-mac/handoffs" -name "*.md" -mtime +7 -delete 2>/dev/null

    # Remove old test logs
    "$TW_CONTROL" run 'find /tmp -name "test-*.log" -mtime +3 -delete' 2>/dev/null
    "$TW_CONTROL" run 'find /tmp -name "task-*.log" -mtime +3 -delete' 2>/dev/null

    # Trim log files
    for logfile in "$HOME/.claude/tw-mac/"*.log; do
        if [ -f "$logfile" ] && [ $(wc -l < "$logfile") -gt 10000 ]; then
            tail -5000 "$logfile" > "${logfile}.tmp" && mv "${logfile}.tmp" "$logfile"
        fi
    done

    log "Cleanup complete"
}

# Generate daily report
daily_report() {
    local REPORT_FILE="$HOME/.claude/tw-mac/daily-report-$(date +%Y%m%d).md"

    cat > "$REPORT_FILE" << EOF
# TW Mac Daily Report - $(date +%Y-%m-%d)

## Sessions Summary
$("$TW_CONTROL" run 'tmux list-sessions 2>/dev/null' || echo "No active sessions")

## Completed Tasks (last 24h)
$(ls -lt "$HOME/tw-mac/handoffs/response-"*.md 2>/dev/null | head -20 | awk '{print $NF}')

## Resource Usage
$("$TW_CONTROL" run 'top -l 1 | head -10' 2>/dev/null)

## Errors (last 24h)
$(grep -i "error\|fail" "$LOG_FILE" 2>/dev/null | tail -20)

---
Generated: $(date)
EOF

    log "Daily report generated: $REPORT_FILE"
}

# Main task router
case "$1" in
    periodic)
        # Run every 15 minutes
        health_check
        sync_if_needed
        process_queue
        ;;
    hourly)
        health_check
        sync_if_needed
        process_queue
        ;;
    daily)
        health_check
        sync_if_needed
        cleanup
        daily_report
        ;;
    health)
        health_check
        ;;
    sync)
        sync_if_needed
        ;;
    cleanup)
        cleanup
        ;;
    report)
        daily_report
        ;;
    *)
        echo "Usage: $0 {periodic|hourly|daily|health|sync|cleanup|report}"
        echo ""
        echo "Schedules:"
        echo "  periodic - Every 15 min (health, sync, queue)"
        echo "  hourly   - Every hour (health, sync, queue)"
        echo "  daily    - Once daily (cleanup, report)"
        ;;
esac
