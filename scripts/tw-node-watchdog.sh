#!/bin/bash
# ==============================================================================
# TW NODE WATCHDOG
# ==============================================================================
# Monitors the connectivity of the TW remote node.
# If disconnected, attempts to auto-heal by restarting the remote service.
# Run this on the GATEWAY machine (Primary Mac).
# ==============================================================================

set -uo pipefail

NODE_NAME="TW"
NODE_HOST="tw"  # SSH host alias
GATEWAY_PORT="18789"
LOG_FILE="$HOME/.clawdbot/logs/tw-watchdog.log"
MAX_RETRIES=3

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_gateway() {
    if ! lsof -i ":$GATEWAY_PORT" > /dev/null; then
        log "❌ Gateway service is NOT running on port $GATEWAY_PORT"
        return 1
    fi
    return 0
}

check_node_status() {
    # Parse status from CLI output (using grep until --json is fully stable/available)
    STATUS_LINE=$(clawdbot nodes status 2>/dev/null | grep "$NODE_NAME")
    
    if [[ "$STATUS_LINE" == *"connected"* ]]; then
        return 0 # Healthy
    else
        return 1 # Unhealthy
    fi
}

attempt_recovery() {
    log "🩹 Attempting recovery of $NODE_NAME node..."
    
    # Check if host is reachable via SSH
    if ! ssh -o ConnectTimeout=5 "$NODE_HOST" "echo ok" > /dev/null 2>&1; then
        log "❌ SSH ping failed. Host might be down or sleeping."
        return 1
    fi

    # Restart the service remotely
    log "🔄 Restarting remote node service..."
    
    # Try kickstart first (restart active service)
    if ssh "$NODE_HOST" "launchctl kickstart -k gui/501/com.clawdbot.node" 2>/dev/null; then
        log "✅ Kickstart command sent successfully."
        return 0
    fi
    
    # If kickstart failed, the service might be unloaded. Try loading it.
    log "⚠️ Kickstart failed (service unloaded?). Attempting 'launchctl load'..."
    if ssh "$NODE_HOST" "launchctl load -w ~/Library/LaunchAgents/com.clawdbot.node.plist"; then
        log "✅ Load command sent successfully."
        return 0
    else
        log "❌ Failed to restart (kickstart and load failed)."
        return 1
    fi
}

# --- Main Loop ---

log "🔍 Watchdog started for node: $NODE_NAME"

# 1. Check if Gateway is up (Prerequisite)
if ! check_gateway; then
    log "⚠️ Gateway down. Watchdog pausing."
    exit 0
fi

# 2. Check Node Status
if check_node_status; then
    # All good, exit silently (logging only errors reduces noise)
    exit 0
fi

# 3. Node Disconnected - Trigger Recovery
log "⚠️ Node $NODE_NAME detected as DISCONNECTED"
attempt_recovery

# 4. Verification Wait
sleep 15
if check_node_status; then
    log "✅ RECOVERY SUCCESSFUL. Node is connected."
else
    log "❌ RECOVERY FAILED. Node still disconnected."
    # Optional: Send notification here
fi
