#!/bin/bash
# Install all TW Mac automation components
# Run: ./install-automation.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_step() { echo -e "${BLUE}→${NC} $1"; }
log_done() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}!${NC} $1"; }

echo ""
echo "═══════════════════════════════════════════"
echo "TW Mac Automation Installation"
echo "═══════════════════════════════════════════"
echo ""

# 1. Install fswatch if needed
log_step "Checking dependencies..."
if ! command -v fswatch >/dev/null 2>&1; then
    log_warn "fswatch not found, installing..."
    brew install fswatch
fi
log_done "Dependencies ready"

# 2. Make scripts executable
log_step "Setting permissions..."
chmod +x "$SCRIPT_DIR"/*.sh
chmod +x "$SCRIPT_DIR/git-hooks"/*
log_done "Permissions set"

# 3. Install git hooks
log_step "Installing git hooks..."
if [ -d "$PROJECT_ROOT/.git" ]; then
    ln -sf "$SCRIPT_DIR/git-hooks/pre-commit" "$PROJECT_ROOT/.git/hooks/pre-commit"
    ln -sf "$SCRIPT_DIR/git-hooks/post-commit" "$PROJECT_ROOT/.git/hooks/post-commit"
    log_done "Git hooks installed"
else
    log_warn "Not a git repository, skipping hooks"
fi

# 4. Create directories
log_step "Creating directories..."
mkdir -p "$HOME/.claude/tw-mac"
mkdir -p "$HOME/tw-mac/handoffs"
log_done "Directories created"

# 5. Install LaunchAgents
log_step "Installing LaunchAgents..."
LAUNCHD_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCHD_DIR"

# Expand $HOME in plist files and install
for plist in "$SCRIPT_DIR/launchd"/*.plist; do
    PLIST_NAME=$(basename "$plist")
    DEST="$LAUNCHD_DIR/$PLIST_NAME"

    # Replace $HOME with actual path
    sed "s|\$HOME|$HOME|g" "$plist" > "$DEST"

    # Unload if already loaded, then load
    launchctl unload "$DEST" 2>/dev/null || true
    launchctl load "$DEST"
    log_done "Loaded $PLIST_NAME"
done

# 6. Create symlinks for easy access
log_step "Creating command shortcuts..."
mkdir -p "$HOME/bin"

# Smart dispatcher shortcut
cat > "$HOME/bin/tw-dispatch" << 'EOF'
#!/bin/bash
exec "$HOME/Development/Projects/clawdbot/infrastructure/tw-mac/automation/smart-dispatcher.sh" dispatch "$@"
EOF
chmod +x "$HOME/bin/tw-dispatch"

# Queue shortcut
cat > "$HOME/bin/tw-queue" << 'EOF'
#!/bin/bash
exec "$HOME/Development/Projects/clawdbot/infrastructure/tw-mac/automation/smart-dispatcher.sh" queue "$@"
EOF
chmod +x "$HOME/bin/tw-queue"

log_done "Command shortcuts created"

# 7. Initial sync
log_step "Running initial sync..."
"$HOME/bin/tw-sync-config" 2>/dev/null || log_warn "Sync skipped (TW Mac may be offline)"

# 8. Verify installation
echo ""
echo "═══════════════════════════════════════════"
echo "Installation Summary"
echo "═══════════════════════════════════════════"
echo ""
echo "Git Hooks:"
[ -L "$PROJECT_ROOT/.git/hooks/pre-commit" ] && log_done "pre-commit" || log_warn "pre-commit not linked"
[ -L "$PROJECT_ROOT/.git/hooks/post-commit" ] && log_done "post-commit" || log_warn "post-commit not linked"
echo ""
echo "LaunchAgents:"
launchctl list | grep -q "com.clawdbot.config-watcher" && log_done "Config watcher running" || log_warn "Config watcher not running"
launchctl list | grep -q "com.clawdbot.scheduled-periodic" && log_done "Periodic tasks scheduled" || log_warn "Periodic tasks not scheduled"
launchctl list | grep -q "com.clawdbot.scheduled-daily" && log_done "Daily tasks scheduled" || log_warn "Daily tasks not scheduled"
echo ""
echo "Commands available:"
echo "  tw-dispatch 'task'  - Smart task dispatch"
echo "  tw-queue 'task'     - Queue task for later"
echo "  tw-handoff 'task'   - Manual handoff"
echo "  tw-status           - Check status"
echo ""
echo "═══════════════════════════════════════════"
echo -e "${GREEN}Installation complete!${NC}"
echo "═══════════════════════════════════════════"
