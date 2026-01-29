#!/bin/bash
# TW Mac Health Monitor - Auto-reconnect and service management
# Uses Tailscale (WireGuard) for encrypted connectivity with LAN fallback
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/bin"
# Run via LaunchAgent for persistent monitoring

LOG_FILE="$HOME/.claude/tw-mac/health.log"
LOCK_FILE="/tmp/tw-health-monitor.lock"
TW_HOST="tw"
TW_TAILSCALE_IP="100.81.110.81"
TW_LAN_IP="192.168.1.245"
SSH_KEY="$HOME/.ssh/id_ed25519_clawdbot"
SSH_OPTS="-o BatchMode=yes -o IdentitiesOnly=yes -i $SSH_KEY -o ConnectTimeout=10"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Prevent multiple instances
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

check_and_reconnect() {
    # Check Tailscale connectivity (primary)
    if ping -c 1 -W 2 $TW_TAILSCALE_IP >/dev/null 2>&1; then
        CURRENT_HOST=$TW_TAILSCALE_IP
    elif ping -c 1 -W 2 $TW_LAN_IP >/dev/null 2>&1; then
        # Fallback to LAN
        log "WARN: Tailscale unreachable, using LAN fallback"
        CURRENT_HOST=$TW_LAN_IP
    else
        log "WARN: TW Mac not reachable (Tailscale or LAN)"
        return 1
    fi

    # Check SSH connection
    if ! SSH_AUTH_SOCK="" ssh $SSH_OPTS $TW_HOST 'exit 0' 2>/dev/null; then
        log "WARN: SSH connection failed, attempting reconnect..."

        # Kill any stale control sockets
        rm -f "$HOME/.ssh/sockets/tywhitaker@$TW_TAILSCALE_IP-22" 2>/dev/null
        rm -f "$HOME/.ssh/sockets/tywhitaker@$TW_LAN_IP-22" 2>/dev/null

        # Re-establish master connection
        SSH_AUTH_SOCK="" ssh $SSH_OPTS -fNM $TW_HOST 2>/dev/null
        if [ $? -eq 0 ]; then
            log "INFO: SSH connection re-established via Tailscale"
        else
            log "ERROR: Failed to re-establish SSH connection"
            return 1
        fi
    fi

    # Check MCP server
    mcp_running=$(SSH_AUTH_SOCK="" ssh $SSH_OPTS $TW_HOST 'tmux has-session -t mcp 2>/dev/null && echo "yes" || echo "no"')
    if [ "$mcp_running" != "yes" ]; then
        log "WARN: MCP server not running, starting..."
        SSH_AUTH_SOCK="" ssh $SSH_OPTS $TW_HOST '
            tmux new-session -d -s mcp "cd ~/Development/DesktopCommanderMCP && NODE_ENV=production MCP_DXT=true node dist/index.js"
        ' 2>/dev/null
        if [ $? -eq 0 ]; then
            log "INFO: MCP server started"
        else
            log "ERROR: Failed to start MCP server"
        fi
    fi

    return 0
}

check_config_sync() {
    # Note: Global CLAUDE.md files are intentionally different
    # Controller has orchestrator config, TW Mac has worker config
    # Only check skills sync

    # Check skills count
    local LOCAL_SKILLS=$(ls "$HOME/.claude/commands" 2>/dev/null | wc -l | tr -d ' ')
    local REMOTE_SKILLS=$(SSH_AUTH_SOCK="" ssh $SSH_OPTS $TW_HOST 'ls ~/.claude/commands 2>/dev/null | wc -l | tr -d " "' || echo "0")

    if [ "$LOCAL_SKILLS" != "$REMOTE_SKILLS" ]; then
        log "WARN: Skills out of sync (local: $LOCAL_SKILLS, remote: $REMOTE_SKILLS) - run tw-sync-config"
        return 1
    fi

    return 0
}

check_pending_handoffs() {
    # Check for stale handoffs (older than 2 hours with no response)
    local STALE_COUNT=0
    local TWO_HOURS_AGO=$(date -v-2H +%Y%m%d-%H%M%S 2>/dev/null || date -d '2 hours ago' +%Y%m%d-%H%M%S 2>/dev/null)

    for handoff in "$HOME/tw-mac/handoffs"/handoff-*.md 2>/dev/null; do
        if [ -f "$handoff" ]; then
            local ID=$(basename "$handoff" | sed 's/handoff-//' | sed 's/.md//')
            if [ ! -f "$HOME/tw-mac/handoffs/response-$ID.md" ]; then
                # Check if handoff is older than 2 hours
                if [[ "$ID" < "$TWO_HOURS_AGO" ]]; then
                    ((STALE_COUNT++))
                fi
            fi
        fi
    done

    if [ $STALE_COUNT -gt 0 ]; then
        log "WARN: $STALE_COUNT stale handoff(s) without response (>2 hours old)"
    fi

    return 0
}

check_orphan_sessions() {
    # Check for tmux sessions that might be orphaned
    local SESSIONS=$(SSH_AUTH_SOCK="" ssh $SSH_OPTS $TW_HOST 'tmux list-sessions -F "#{session_name}:#{session_activity}" 2>/dev/null' || echo "")
    local NOW=$(date +%s)

    for session in $SESSIONS; do
        local NAME=$(echo "$session" | cut -d: -f1)
        local ACTIVITY=$(echo "$session" | cut -d: -f2)

        # Skip mcp session
        [ "$NAME" = "mcp" ] && continue

        # Check if session has been idle for more than 4 hours (14400 seconds)
        if [ -n "$ACTIVITY" ]; then
            local IDLE=$((NOW - ACTIVITY))
            if [ $IDLE -gt 14400 ]; then
                log "WARN: Session '$NAME' idle for $((IDLE / 3600)) hours - may be orphaned"
            fi
        fi
    done

    return 0
}

# Main monitoring loop
ITERATION=0
while true; do
    check_and_reconnect

    # Run additional checks every 5 minutes (5 iterations)
    if [ $((ITERATION % 5)) -eq 0 ]; then
        check_config_sync
        check_pending_handoffs
        check_orphan_sessions
    fi

    ((ITERATION++))
    sleep 60
done
