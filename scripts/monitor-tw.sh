#!/bin/bash
# TW Remote Node Health Monitor
# Checks Load and Thermal state. Escalates via iMessage if critical.

set -uo pipefail

REMOTE_HOST="tywhitaker@192.168.1.245"
ALERT_RECIPIENT="roller-erasers.0b@icloud.com"  # Using your git email
# Alternatively, you can put a phone number here: ALERT_RECIPIENT="+15550000000"

# --- Thresholds ---
LOAD_THRESHOLD=10.0   # High load for 4-core machine
THERMAL_THRESHOLD=1   # 0=Normal, 1=Fair, 2=Serious, 3=Critical

# --- Check Function ---
check_status() {
    # Get stats from remote (Low timeout to detect unresponsive node)
    STATS=$(ssh -o ConnectTimeout=10 "$REMOTE_HOST" '
        LOAD=$(sysctl -n vm.loadavg | cut -d" " -f2) # 1-min load
        THERM=$(pmset -g therm | grep "Thermal Warning" | awk "{print $5}" || echo 0)
        echo "$LOAD $THERM"
    ' 2>/dev/null)

    if [ -z "$STATS" ]; then
        echo "CRITICAL: Could not reach TW Node!"
        send_alert "🚨 CRITICAL: TW Node is UNREACHABLE. Connection failed."
        exit 1
    fi

    # Parse output
    LOAD_VAL=$(echo "$STATS" | awk '{print $1}')
    THERM_VAL=$(echo "$STATS" | awk '{print $2}')

    # Validate numeric (handle empty or errors)
    if ! [[ "$LOAD_VAL" =~ ^[0-9.]+$ ]]; then LOAD_VAL=0; fi
    if ! [[ "$THERM_VAL" =~ ^[0-9]+$ ]]; then THERM_VAL=0; fi

    # Log Check
    echo "$(date): TW Status - Load: $LOAD_VAL, Thermals: $THERM_VAL"

    # --- Logic ---
    ISSUES=""

    # 1. Check Load
    if (( $(echo "$LOAD_VAL > $LOAD_THRESHOLD" | bc -l) )); then
        ISSUES="$ISSUES High Load: $LOAD_VAL."
    fi

    # 2. Check Thermals
    if [ "$THERM_VAL" -ge "$THERMAL_THRESHOLD" ]; then
        ISSUES="$ISSUES Thermal Warning Level: $THERM_VAL."
    fi

    # --- Escalation ---
    if [ ! -z "$ISSUES" ]; then
        send_alert "⚠️ ALERT TW Node: $ISSUES"
    fi
}

send_alert() {
    MSG="$1"
    echo "Sending Alert: $MSG"
    
    # 1. Desktop Notification (Always works locally)
    osascript -e "display notification \"$MSG\" with title \"Clawdbot Monitor\" sound name \"Submarine\""

    # 2. iMessage via imsg CLI (Native Clawdbot Tool)
    # Ensure this recipient is correct! Phone numbers work best (e.g. +1415...)
    # Current: Git Email
    if command -v imsg &>/dev/null; then
        imsg send --to "$ALERT_RECIPIENT" --text "$MSG" || echo "❌ iMessage send failed."
    else
        echo "⚠️ 'imsg' tool not found. Skipping iMessage alert."
    fi
}

# Run
check_status
