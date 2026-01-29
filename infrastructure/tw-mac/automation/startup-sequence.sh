#!/bin/bash
# Startup Sequence - Run on login to establish TW Mac connection
# Add to Login Items or call from .zprofile

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$HOME/.claude/tw-mac/startup.log"
TW_CONTROL="$HOME/bin/tw"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

notify() {
    osascript -e "display notification \"$1\" with title \"Clawdbot Startup\"" 2>/dev/null
}

log "═══════════════════════════════════════"
log "Clawdbot Startup Sequence"
log "═══════════════════════════════════════"

# Step 1: Wait for network
log "Waiting for network..."
NETWORK_WAIT=0
while ! ping -c 1 8.8.8.8 >/dev/null 2>&1; do
    sleep 2
    ((NETWORK_WAIT++))
    if [ $NETWORK_WAIT -gt 30 ]; then
        log "Network timeout after 60 seconds"
        notify "Startup failed: No network"
        exit 1
    fi
done
log "Network available"

# Step 2: Check Tailscale
log "Checking Tailscale..."
TS_CLI=""
if command -v tailscale >/dev/null 2>&1; then
    TS_CLI="tailscale"
elif [ -x "/Applications/Tailscale.app/Contents/MacOS/Tailscale" ]; then
    TS_CLI="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
fi

if [ -n "$TS_CLI" ]; then
    if $TS_CLI status >/dev/null 2>&1; then
        log "Tailscale connected"
    else
        log "Tailscale not connected, waiting..."
        sleep 10
    fi
fi

# Step 3: Connect to TW Mac
log "Connecting to TW Mac..."
TW_CONNECTED=false

for attempt in 1 2 3 4 5; do
    if "$TW_CONTROL" run 'echo ok' >/dev/null 2>&1; then
        TW_CONNECTED=true
        log "TW Mac connected (attempt $attempt)"
        break
    fi
    log "Connection attempt $attempt failed, retrying..."
    sleep 5
done

if [ "$TW_CONNECTED" = false ]; then
    log "Could not connect to TW Mac"
    notify "TW Mac unreachable - will retry in background"
fi

# Step 4: Mount SMB if not mounted
log "Checking SMB mount..."
if ! mount | grep -qE "tw|tywhitaker"; then
    log "Mounting SMB share..."
    # Try to mount (may prompt for password first time)
    open "smb://tywhitaker@tw.local/tywhitaker" 2>/dev/null &
    sleep 3
fi

# Step 5: Sync configs
if [ "$TW_CONNECTED" = true ]; then
    log "Syncing configurations..."
    "$HOME/bin/tw-sync-config" >> "$LOG_FILE" 2>&1
fi

# Step 6: Check/start MCP server on TW Mac
if [ "$TW_CONNECTED" = true ]; then
    log "Checking MCP server..."
    if ! "$TW_CONTROL" run 'pgrep -f DesktopCommanderMCP' >/dev/null 2>&1; then
        log "Starting MCP server..."
        "$TW_CONTROL" start-mcp >> "$LOG_FILE" 2>&1
    else
        log "MCP server already running"
    fi
fi

# Step 7: Process any queued tasks
if [ "$TW_CONNECTED" = true ]; then
    QUEUE_FILE="$HOME/.claude/tw-mac/task-queue.txt"
    if [ -f "$QUEUE_FILE" ] && [ -s "$QUEUE_FILE" ]; then
        QUEUE_COUNT=$(wc -l < "$QUEUE_FILE" | tr -d ' ')
        log "Processing $QUEUE_COUNT queued tasks..."
        "$SCRIPT_DIR/smart-dispatcher.sh" process >> "$LOG_FILE" 2>&1
    fi
fi

# Step 8: Generate status report
log "Generating status..."
if [ "$TW_CONNECTED" = true ]; then
    SESSIONS=$("$TW_CONTROL" run 'tmux list-sessions 2>/dev/null | wc -l' 2>/dev/null || echo "0")
    PENDING=$(ls "$HOME/tw-mac/handoffs/response-"*.md 2>/dev/null | wc -l | tr -d ' ')

    STATUS="Connected | $SESSIONS sessions | $PENDING responses"
    notify "$STATUS"
    log "Status: $STATUS"
else
    notify "TW Mac offline - monitoring in background"
    log "TW Mac offline"
fi

log "Startup sequence complete"
log "═══════════════════════════════════════"
