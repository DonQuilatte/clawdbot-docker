#!/bin/bash
# Connection Monitor - Resilient reconnection with alerts
# Handles shutdown/restart of either Mac gracefully

TW_CONTROL="$HOME/bin/tw"
LOG_FILE="$HOME/.claude/tw-mac/connection.log"
STATE_FILE="$HOME/.claude/tw-mac/connection-state.json"
ALERT_SCRIPT="$HOME/.claude/tw-mac/alert.sh"

# Configuration
MAX_RETRIES=10
RETRY_DELAY=30
ALERT_AFTER_FAILURES=3
CHECK_INTERVAL=60

# Tailscale and LAN IPs
TW_TAILSCALE_IP="100.81.110.81"
TW_LAN_IP="192.168.1.245"

mkdir -p "$(dirname "$LOG_FILE")"

# Logging
log() {
    local LEVEL="$1"
    local MSG="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$LEVEL] $MSG" | tee -a "$LOG_FILE"
}

# State management
save_state() {
    cat > "$STATE_FILE" << EOF
{
    "last_check": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "connected": $1,
    "consecutive_failures": $2,
    "last_successful": "$3",
    "connection_type": "$4"
}
EOF
}

load_state() {
    if [ -f "$STATE_FILE" ]; then
        CONSECUTIVE_FAILURES=$(grep "consecutive_failures" "$STATE_FILE" | grep -o '[0-9]*' || echo "0")
        LAST_SUCCESSFUL=$(grep "last_successful" "$STATE_FILE" | cut -d'"' -f4 || echo "never")
    else
        CONSECUTIVE_FAILURES=0
        LAST_SUCCESSFUL="never"
    fi
}

# Alert mechanisms
send_alert() {
    local SUBTITLE="$1"
    local MESSAGE="$2"
    local URGENCY="${3:-normal}"

    log "ALERT" "$SUBTITLE: $MESSAGE"

    # macOS notification with subtitle for better visibility
    osascript -e "display notification \"$MESSAGE\" with title \"Clawdbot\" subtitle \"$SUBTITLE\"" 2>/dev/null

    # Terminal bell
    if [ "$URGENCY" = "critical" ]; then
        echo -e "\a"
    fi

    # Custom alert script if exists
    if [ -x "$ALERT_SCRIPT" ]; then
        "$ALERT_SCRIPT" "$TITLE" "$MESSAGE" "$URGENCY"
    fi

    # Log to alert history
    echo "[$(date)] $URGENCY: $TITLE - $MESSAGE" >> "$HOME/.claude/tw-mac/alerts.log"
}

# Check connectivity via multiple methods
check_connectivity() {
    local METHOD=""
    local SUCCESS=false

    # Method 1: Tailscale (preferred)
    if ping -c 1 -W 3 "$TW_TAILSCALE_IP" >/dev/null 2>&1; then
        if ssh -o BatchMode=yes -o ConnectTimeout=5 -i "$HOME/.ssh/id_ed25519_clawdbot" "tywhitaker@$TW_TAILSCALE_IP" 'echo ok' >/dev/null 2>&1; then
            METHOD="tailscale"
            SUCCESS=true
        fi
    fi

    # Method 2: LAN fallback
    if [ "$SUCCESS" = false ]; then
        if ping -c 1 -W 3 "$TW_LAN_IP" >/dev/null 2>&1; then
            if ssh -o BatchMode=yes -o ConnectTimeout=5 -i "$HOME/.ssh/id_ed25519_clawdbot" "tywhitaker@$TW_LAN_IP" 'echo ok' >/dev/null 2>&1; then
                METHOD="lan"
                SUCCESS=true
            fi
        fi
    fi

    # Method 3: Hostname resolution
    if [ "$SUCCESS" = false ]; then
        if ssh -o BatchMode=yes -o ConnectTimeout=5 tw 'echo ok' >/dev/null 2>&1; then
            METHOD="hostname"
            SUCCESS=true
        fi
    fi

    if [ "$SUCCESS" = true ]; then
        echo "$METHOD"
        return 0
    else
        echo "none"
        return 1
    fi
}

# Attempt reconnection
attempt_reconnect() {
    local ATTEMPT=1

    log "INFO" "Attempting reconnection..."

    while [ $ATTEMPT -le $MAX_RETRIES ]; do
        log "INFO" "Reconnection attempt $ATTEMPT/$MAX_RETRIES"

        # Clear stale SSH sockets
        rm -f "$HOME/.ssh/sockets/tywhitaker@"* 2>/dev/null

        # Try to establish connection
        local METHOD=$(check_connectivity)

        if [ "$METHOD" != "none" ]; then
            log "INFO" "Reconnected via $METHOD"

            # Re-establish SSH multiplexing
            ssh -o ControlMaster=yes -o ControlPersist=600 -o ControlPath="$HOME/.ssh/sockets/%r@%h-%p" \
                -i "$HOME/.ssh/id_ed25519_clawdbot" -fN tw 2>/dev/null

            # Verify MCP server
            if ! "$TW_CONTROL" run 'pgrep -f DesktopCommanderMCP' >/dev/null 2>&1; then
                log "INFO" "Restarting MCP server..."
                "$TW_CONTROL" start-mcp 2>/dev/null
            fi

            return 0
        fi

        sleep $RETRY_DELAY
        ((ATTEMPT++))
    done

    log "ERROR" "Failed to reconnect after $MAX_RETRIES attempts"
    return 1
}

# Main monitoring loop
monitor_loop() {
    log "INFO" "Connection monitor started"

    while true; do
        load_state

        local METHOD=$(check_connectivity)

        if [ "$METHOD" != "none" ]; then
            # Connected
            if [ $CONSECUTIVE_FAILURES -gt 0 ]; then
                local DOWNTIME=$((CONSECUTIVE_FAILURES * CHECK_INTERVAL / 60))
                log "INFO" "Connection restored via $METHOD after $CONSECUTIVE_FAILURES failures"
                send_alert "TW Mac Online" "Reconnected via ${METHOD} after ~${DOWNTIME}min downtime. Ready for tasks." "normal"
            fi

            save_state "true" "0" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$METHOD"
            CONSECUTIVE_FAILURES=0

        else
            # Disconnected
            ((CONSECUTIVE_FAILURES++))
            log "WARN" "Connection failed (attempt $CONSECUTIVE_FAILURES)"

            save_state "false" "$CONSECUTIVE_FAILURES" "$LAST_SUCCESSFUL" "none"

            # Alert thresholds
            if [ $CONSECUTIVE_FAILURES -eq $ALERT_AFTER_FAILURES ]; then
                send_alert "TW Mac Disconnected" "Lost connection after ${CONSECUTIVE_FAILURES} checks (~$((CONSECUTIVE_FAILURES * CHECK_INTERVAL / 60))min). Trying Tailscale → LAN → hostname fallbacks..." "normal"
            fi

            if [ $CONSECUTIVE_FAILURES -eq $((ALERT_AFTER_FAILURES * 2)) ]; then
                local MINS=$((CONSECUTIVE_FAILURES * CHECK_INTERVAL / 60))
                send_alert "TW Mac Offline ${MINS}min" "All reconnect methods failed. Check: 1) TW Mac powered on 2) Tailscale running 3) Network connectivity" "critical"
            fi

            # Attempt reconnection
            if attempt_reconnect; then
                CONSECUTIVE_FAILURES=0
                save_state "true" "0" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "reconnected"
                send_alert "TW Mac Recovered" "Auto-reconnect succeeded. MCP server verified. Worker node ready." "normal"
            fi
        fi

        sleep $CHECK_INTERVAL
    done
}

# Startup checks
startup_check() {
    log "INFO" "Running startup connectivity check..."

    local METHOD=$(check_connectivity)

    if [ "$METHOD" != "none" ]; then
        log "INFO" "TW Mac reachable via $METHOD"
        save_state "true" "0" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$METHOD"

        # Sync configs on startup
        log "INFO" "Syncing configurations..."
        "$HOME/bin/tw-sync-config" >> "$LOG_FILE" 2>&1

        # Check for pending work
        local PENDING=$("$TW_CONTROL" run 'ls ~/handoffs/handoff-*.md 2>/dev/null | wc -l' 2>/dev/null || echo "0")
        if [ "$PENDING" -gt 0 ]; then
            log "INFO" "$PENDING pending handoffs found on TW Mac"
        fi

        return 0
    else
        log "WARN" "TW Mac not reachable at startup"
        send_alert "TW Mac Unavailable" "Worker node not found at boot. Retrying every ${CHECK_INTERVAL}s. IP: ${TW_TAILSCALE_IP}" "normal"
        return 1
    fi
}

# Graceful shutdown handler
shutdown_handler() {
    log "INFO" "Shutdown signal received"

    # Save final state
    save_state "$(check_connectivity >/dev/null 2>&1 && echo true || echo false)" "$CONSECUTIVE_FAILURES" "$LAST_SUCCESSFUL" "shutdown"

    # Notify TW Mac if possible
    "$TW_CONTROL" run "echo 'Controller Mac shutting down at $(date)' >> ~/handoffs/.controller-status" 2>/dev/null

    log "INFO" "Connection monitor stopped"
    exit 0
}

trap shutdown_handler SIGTERM SIGINT

# Command interface
case "$1" in
    start)
        startup_check
        monitor_loop
        ;;
    check)
        METHOD=$(check_connectivity)
        if [ "$METHOD" != "none" ]; then
            echo "Connected via $METHOD"
            exit 0
        else
            echo "Disconnected"
            exit 1
        fi
        ;;
    reconnect)
        attempt_reconnect
        ;;
    status)
        if [ -f "$STATE_FILE" ]; then
            cat "$STATE_FILE"
        else
            echo "No state file found"
        fi
        ;;
    startup)
        startup_check
        ;;
    *)
        echo "Usage: $0 {start|check|reconnect|status|startup}"
        echo ""
        echo "Commands:"
        echo "  start     - Start continuous monitoring"
        echo "  check     - One-time connectivity check"
        echo "  reconnect - Force reconnection attempt"
        echo "  status    - Show current state"
        echo "  startup   - Run startup checks"
        ;;
esac
