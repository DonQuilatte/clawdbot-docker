#!/bin/bash
# Config file watcher - auto-syncs CLAUDE.md and skills on change
# Uses fswatch (install: brew install fswatch)
# Run: ./config-watcher.sh &

WATCH_PATHS=(
    "$HOME/.claude/CLAUDE.md"
    "$HOME/.claude/commands"
    "$HOME/CLAUDE.md"
    "$HOME/Development/Projects/clawdbot/CLAUDE.md"
)

SYNC_SCRIPT="$HOME/bin/tw-sync-config"
LOG_FILE="$HOME/.claude/tw-mac/config-watcher.log"
DEBOUNCE_SECONDS=5
LAST_SYNC=0

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

sync_config() {
    local NOW=$(date +%s)
    local DIFF=$((NOW - LAST_SYNC))

    # Debounce - don't sync more than once per 5 seconds
    if [ $DIFF -lt $DEBOUNCE_SECONDS ]; then
        return
    fi

    LAST_SYNC=$NOW
    log "Config change detected, syncing to TW Mac..."

    if "$SYNC_SCRIPT" >> "$LOG_FILE" 2>&1; then
        log "Sync complete"
    else
        log "Sync failed"
    fi
}

# Check for fswatch
if ! command -v fswatch >/dev/null 2>&1; then
    echo "fswatch not installed. Install with: brew install fswatch"
    exit 1
fi

log "Config watcher started"
log "Watching: ${WATCH_PATHS[*]}"

# Build watch path arguments
WATCH_ARGS=""
for path in "${WATCH_PATHS[@]}"; do
    if [ -e "$path" ]; then
        WATCH_ARGS="$WATCH_ARGS $path"
    fi
done

if [ -z "$WATCH_ARGS" ]; then
    log "No valid paths to watch"
    exit 1
fi

# Start watching
fswatch -o $WATCH_ARGS | while read -r; do
    sync_config
done
