#!/bin/bash
# Full environment sync to TW Mac
# Syncs: CLAUDE.md, .claude/, shell configs, git config

set -e

REMOTE="tw"
LOCAL_CLAUDE="$HOME/.claude"
REMOTE_HOME="/Users/tywhitaker"

echo "═══════════════════════════════════════"
echo "TW Mac Environment Sync"
echo "═══════════════════════════════════════"

# 1. Global CLAUDE.md - SKIP for TW Mac (has worker-specific config)
# TW Mac uses its own CLAUDE.md with worker node instructions
# To update TW Mac's CLAUDE.md, edit infrastructure/tw-mac/TW-CLAUDE.md and push manually
echo "→ Skipping global CLAUDE.md (TW Mac has worker-specific config)"

# 2. Project CLAUDE.md files
echo "→ Syncing project CLAUDE.md files..."
rsync -avz "$HOME/CLAUDE.md" "$REMOTE:$REMOTE_HOME/CLAUDE.md" 2>/dev/null || true
rsync -avz "$HOME/Development/Projects/clawdbot/CLAUDE.md" "$REMOTE:$REMOTE_HOME/Development/Projects/clawdbot/CLAUDE.md" 2>/dev/null || true

# 3. Claude skills directory
echo "→ Syncing Claude skills..."
if [ -d "$LOCAL_CLAUDE/commands" ]; then
    rsync -avz --delete "$LOCAL_CLAUDE/commands/" "$REMOTE:$REMOTE_HOME/.claude/commands/"
fi

# 4. Claude settings (excluding session-specific data)
echo "→ Syncing Claude settings..."
rsync -avz --exclude='*.log' --exclude='projects/' --exclude='statsig/' \
    "$LOCAL_CLAUDE/settings.json" "$REMOTE:$REMOTE_HOME/.claude/settings.json" 2>/dev/null || true

# 5. Shell configuration
echo "→ Syncing shell config..."
rsync -avz "$HOME/.zshrc" "$REMOTE:$REMOTE_HOME/.zshrc"
rsync -avz "$HOME/.zprofile" "$REMOTE:$REMOTE_HOME/.zprofile" 2>/dev/null || true

# 6. Git configuration
echo "→ Syncing git config..."
rsync -avz "$HOME/.gitconfig" "$REMOTE:$REMOTE_HOME/.gitconfig"

# 7. Sync the tw-mac infrastructure scripts
echo "→ Syncing infrastructure scripts..."
rsync -avz "$HOME/Development/Projects/clawdbot/infrastructure/tw-mac/" \
    "$REMOTE:$REMOTE_HOME/Development/Projects/clawdbot/infrastructure/tw-mac/"

# 8. Verify sync
echo ""
echo "═══════════════════════════════════════"
echo "Verification"
echo "═══════════════════════════════════════"
ssh $REMOTE "echo \"CLAUDE.md exists: \$([ -f ~/.claude/CLAUDE.md ] && echo YES || echo NO)\""
ssh $REMOTE "echo \"Commands dir: \$(ls ~/.claude/commands 2>/dev/null | wc -l | tr -d ' ') skills\""
ssh $REMOTE "echo \"Settings.json: \$([ -f ~/.claude/settings.json ] && echo YES || echo NO)\""

echo ""
echo "✓ Environment sync complete"
