#!/bin/bash
# Shutdown Handler - Graceful shutdown procedures
# Can be run manually or triggered by system events

TW_CONTROL="$HOME/bin/tw"
LOG_FILE="$HOME/.claude/tw-mac/shutdown.log"
STATE_DIR="$HOME/.claude/tw-mac"

mkdir -p "$STATE_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "═══════════════════════════════════════"
log "Clawdbot Shutdown Handler"
log "═══════════════════════════════════════"

# Check if TW Mac is reachable
TW_AVAILABLE=false
if "$TW_CONTROL" run 'echo ok' >/dev/null 2>&1; then
    TW_AVAILABLE=true
fi

# Step 1: Save current state
log "Saving state..."
cat > "$STATE_DIR/pre-shutdown-state.json" << EOF
{
    "shutdown_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "tw_available": $TW_AVAILABLE,
    "active_sessions": "$("$TW_CONTROL" run 'tmux list-sessions -F "#{session_name}" 2>/dev/null' 2>/dev/null | tr '\n' ',' || echo "")",
    "pending_handoffs": $(ls "$HOME/tw-mac/handoffs/handoff-"*.md 2>/dev/null | wc -l | tr -d ' '),
    "pending_responses": $(ls "$HOME/tw-mac/handoffs/response-"*.md 2>/dev/null | wc -l | tr -d ' ')
}
EOF
log "State saved"

# Step 2: Notify TW Mac
if [ "$TW_AVAILABLE" = true ]; then
    log "Notifying TW Mac..."
    "$TW_CONTROL" run "cat > ~/handoffs/.controller-shutdown << EOF
Controller Mac shutting down
Time: $(date)
Resume expected: $(date -v+1H '+%Y-%m-%d %H:%M') (estimated)
Queued tasks will be processed on reconnection
EOF" 2>/dev/null
    log "TW Mac notified"
fi

# Step 3: Save session states from TW Mac
if [ "$TW_AVAILABLE" = true ]; then
    log "Capturing TW Mac session states..."

    SESSIONS=$("$TW_CONTROL" run 'tmux list-sessions -F "#{session_name}" 2>/dev/null' 2>/dev/null)

    for session in $SESSIONS; do
        log "Capturing session: $session"
        "$TW_CONTROL" run "tmux capture-pane -t $session -p -S -500" > "$STATE_DIR/session-$session-$(date +%Y%m%d-%H%M%S).txt" 2>/dev/null
    done
    log "Sessions captured"
fi

# Step 4: Stop LaunchAgents gracefully
log "Stopping automation services..."
for agent in "connection-monitor" "config-watcher" "scheduled-periodic"; do
    PLIST="$HOME/Library/LaunchAgents/com.clawdbot.$agent.plist"
    if [ -f "$PLIST" ]; then
        launchctl unload "$PLIST" 2>/dev/null && log "Stopped $agent"
    fi
done

# Step 5: Close SSH connections gracefully
log "Closing SSH connections..."
rm -f "$HOME/.ssh/sockets/tywhitaker@"* 2>/dev/null
log "SSH sockets cleaned"

# Step 6: Generate shutdown report
REPORT_FILE="$STATE_DIR/shutdown-report-$(date +%Y%m%d-%H%M%S).md"
cat > "$REPORT_FILE" << EOF
# Shutdown Report

**Time:** $(date)
**TW Mac Status:** $([ "$TW_AVAILABLE" = true ] && echo "Available" || echo "Unavailable")

## State at Shutdown

- **Active TW Mac Sessions:** $(echo "$SESSIONS" | wc -w | tr -d ' ')
- **Pending Handoffs:** $(ls "$HOME/tw-mac/handoffs/handoff-"*.md 2>/dev/null | wc -l | tr -d ' ')
- **Pending Responses:** $(ls "$HOME/tw-mac/handoffs/response-"*.md 2>/dev/null | wc -l | tr -d ' ')
- **Queued Tasks:** $(wc -l < "$HOME/.claude/tw-mac/task-queue.txt" 2>/dev/null || echo "0")

## Sessions Captured

$(for f in "$STATE_DIR"/session-*.txt; do [ -f "$f" ] && echo "- $(basename "$f")"; done || echo "None")

## On Resume

The startup sequence will:
1. Reconnect to TW Mac
2. Sync configurations
3. Process queued tasks
4. Resume monitoring

EOF

log "Shutdown report: $REPORT_FILE"
log "═══════════════════════════════════════"
log "Shutdown complete"
