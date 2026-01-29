#!/bin/bash
# Read handoff files from Controller Mac
# Run on TW Mac
# Usage: read-handoff [list|latest|<timestamp>]

HANDOFF_DIR="$HOME/handoffs"
mkdir -p "$HANDOFF_DIR"

if [ "$1" = "list" ] || [ -z "$1" ]; then
    echo "Available handoffs:"
    echo ""
    ls -lt "$HANDOFF_DIR"/handoff-*.md 2>/dev/null | head -10 || echo "  No handoffs found"
    echo ""
    echo "Usage: read-handoff <timestamp> or read-handoff latest"
elif [ "$1" = "latest" ]; then
    LATEST=$(ls -t "$HANDOFF_DIR"/handoff-*.md 2>/dev/null | head -1)
    if [ -n "$LATEST" ]; then
        echo "Reading: $LATEST"
        echo ""
        cat "$LATEST"
    else
        echo "No handoffs found in $HANDOFF_DIR"
    fi
else
    FILE="$HANDOFF_DIR/handoff-$1.md"
    if [ -f "$FILE" ]; then
        cat "$FILE"
    else
        echo "Handoff not found: $FILE"
        echo ""
        echo "Available handoffs:"
        ls -t "$HANDOFF_DIR"/handoff-*.md 2>/dev/null | head -5
    fi
fi
