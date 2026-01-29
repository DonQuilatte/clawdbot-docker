#!/bin/bash
# Report results back to Controller
# Usage: report-back <handoff-id> "summary"
# Or pipe content: echo "results" | report-back <handoff-id>

HANDOFF_ID="$1"
SUMMARY="$2"
RESPONSE_DIR="$HOME/handoffs"
mkdir -p "$RESPONSE_DIR"

if [ -z "$HANDOFF_ID" ]; then
    echo "Usage: report-back <handoff-id> [summary]"
    echo "   or: cat results.txt | report-back <handoff-id>"
    echo ""
    echo "Recent handoffs:"
    ls -t "$RESPONSE_DIR"/handoff-*.md 2>/dev/null | head -3 | while read f; do
        ID=$(basename "$f" | sed 's/handoff-//' | sed 's/.md//')
        echo "  $ID"
    done
    exit 1
fi

RESPONSE_FILE="$RESPONSE_DIR/response-$HANDOFF_ID.md"

# Check if content is being piped
if [ ! -t 0 ]; then
    CONTENT=$(cat)
else
    CONTENT="${SUMMARY:-No details provided}"
fi

cat > "$RESPONSE_FILE" << EOF
# Task Response

**Handoff ID:** $HANDOFF_ID
**Completed:** $(date)
**From:** TW Mac (tywhitaker)

---

## Summary

${SUMMARY:-Task completed}

---

## Results

$CONTENT

---

*Response complete*
EOF

echo "✓ Response written: $RESPONSE_FILE"
echo "  Controller can view via SMB mount"
