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

# Main monitoring loop
while true; do
    check_and_reconnect
    sleep 60
done
