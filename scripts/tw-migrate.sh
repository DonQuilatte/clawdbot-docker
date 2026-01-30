#!/bin/bash
# tw-migrate.sh - Run migration on TW Mac from Controller Mac
# Usage: ./scripts/tw-migrate.sh

set -e

# Use same SSH config as ~/bin/tw
TW_HOST="tw"  # SSH config alias
SSH_KEY="$HOME/.ssh/id_ed25519_clawdbot"
SSH_OPTS="-o BatchMode=yes -o IdentitiesOnly=yes -o ConnectTimeout=10"

if [ -f "$SSH_KEY" ]; then
    SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
fi

echo "TW Mac Migration: clawdbot → dev-infra"
echo "======================================="
echo ""

# Try to connect
echo "Connecting to TW Mac..."
if SSH_AUTH_SOCK="" ssh $SSH_OPTS "$TW_HOST" "echo ok" >/dev/null 2>&1; then
    TARGET="$TW_HOST"
else
    echo "ERROR: Cannot connect to TW Mac"
    echo "Check: ~/bin/tw status"
    exit 1
fi

echo "Connected via: $TARGET"
echo ""

# Step 1: Ensure repo exists and is updated
echo "Step 1: Updating repository on TW Mac..."
SSH_AUTH_SOCK="" ssh $SSH_OPTS "$TARGET" << 'REMOTE_SCRIPT'
set -e
PROJECT_DIR="$HOME/Development/Projects/dev-infra"
OLD_DIR="$HOME/Development/Projects/clawdbot"

# Check if we need to rename the directory
if [ -d "$OLD_DIR" ] && [ ! -d "$PROJECT_DIR" ]; then
    echo "Moving clawdbot → dev-infra..."
    mv "$OLD_DIR" "$PROJECT_DIR"
fi

# Ensure directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Cloning repository..."
    mkdir -p "$HOME/Development/Projects"
    git clone git@github.com:DonQuilatte/dev-infra.git "$PROJECT_DIR"
fi

cd "$PROJECT_DIR"

# Update remote URL if needed
REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$REMOTE" == *"clawdbot"* ]]; then
    git remote set-url origin git@github.com:DonQuilatte/dev-infra.git
    echo "Updated git remote"
fi

# Pull latest
git fetch origin
git pull origin main --ff-only || echo "Warning: Could not fast-forward"

echo "Repository updated"
REMOTE_SCRIPT

echo ""
echo "Step 2: Running migration script..."
SSH_AUTH_SOCK="" ssh $SSH_OPTS "$TARGET" "cd ~/Development/Projects/dev-infra && ./infrastructure/tw-mac/migrate-to-dev-infra.sh"

echo ""
echo "Step 3: Verifying from Controller Mac..."
if ~/bin/tw run 'echo ok' >/dev/null 2>&1; then
    echo "✓ TW Mac connection verified"
else
    echo "⚠ TW Mac connection issue - check manually"
fi

echo ""
echo "Migration complete!"
echo ""
echo "Test commands:"
echo "  ~/bin/tw status"
echo "  agy -r status"
