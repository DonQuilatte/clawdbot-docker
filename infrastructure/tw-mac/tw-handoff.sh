#!/bin/bash
# Create handoff file for TW Mac session
# Usage: tw-handoff "task description" "context notes" "specific instructions"

HANDOFF_DIR="$HOME/tw-mac/handoffs"
mkdir -p "$HANDOFF_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
HANDOFF_FILE="$HANDOFF_DIR/handoff-$TIMESTAMP.md"

TASK="${1:-No task specified}"
CONTEXT="${2:-No additional context}"
INSTRUCTIONS="${3:-Follow standard procedures}"

# Get git context if in a repo
GIT_STATUS=""
GIT_BRANCH=""
GIT_RECENT=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    GIT_BRANCH=$(git branch --show-current 2>/dev/null)
    GIT_STATUS=$(git status --short 2>/dev/null | head -20)
    GIT_RECENT=$(git log --oneline -5 2>/dev/null)
fi

cat > "$HANDOFF_FILE" << EOF
# Session Handoff

**Created:** $(date)
**From:** Controller Mac (jederlichman)
**To:** TW Mac (tywhitaker)

---

## Task

$TASK

---

## Context

$CONTEXT

---

## Git State

**Branch:** $GIT_BRANCH

**Recent Changes:**
\`\`\`
$GIT_STATUS
\`\`\`

**Recent Commits:**
\`\`\`
$GIT_RECENT
\`\`\`

---

## Instructions

$INSTRUCTIONS

---

## Response Location

Write your response/results to:
\`~/handoffs/response-$TIMESTAMP.md\`

Or use: \`report-back $TIMESTAMP "summary"\`

---

*Handoff ID: $TIMESTAMP*
EOF

echo "✓ Handoff created: $HANDOFF_FILE"
echo "  Handoff ID: $TIMESTAMP"
echo ""
echo "TW Mac can read with:"
echo "  read-handoff latest"
echo "  read-handoff $TIMESTAMP"
