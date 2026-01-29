#!/bin/bash
# Lightweight config sync - just Claude-specific files

REMOTE="tw"
REMOTE_HOME="/Users/tywhitaker"

echo "Syncing Claude configuration..."

# CLAUDE.md files - skip global (TW Mac has worker-specific config)
# Only sync project-level CLAUDE.md
rsync -avz "$HOME/CLAUDE.md" "$REMOTE:$REMOTE_HOME/CLAUDE.md" 2>/dev/null || true

# Skills/commands
if [ -d "$HOME/.claude/commands" ]; then
    rsync -avz --delete "$HOME/.claude/commands/" "$REMOTE:$REMOTE_HOME/.claude/commands/"
fi

echo "✓ Config sync complete"
