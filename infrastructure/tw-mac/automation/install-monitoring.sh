#!/bin/bash
# Install monitoring, reporting, and resilient connection handling
# Run: ./install-monitoring.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_step() { echo -e "${BLUE}→${NC} $1"; }
log_done() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}!${NC} $1"; }

echo ""
echo "═══════════════════════════════════════════"
echo "TW Mac Monitoring & Resilience Installation"
echo "═══════════════════════════════════════════"
echo ""

# 1. Make scripts executable
log_step "Setting permissions..."
chmod +x "$SCRIPT_DIR"/*.sh
log_done "Permissions set"

# 2. Create directories
log_step "Creating directories..."
mkdir -p "$HOME/.claude/tw-mac/reports"
mkdir -p "$HOME/.claude/tw-mac"
log_done "Directories created"

# 3. Install alert script
log_step "Installing alert configuration..."
ALERT_DEST="$HOME/.claude/tw-mac/alert.sh"
if [ ! -f "$ALERT_DEST" ]; then
    cp "$SCRIPT_DIR/alert-config.sh" "$ALERT_DEST"
    chmod +x "$ALERT_DEST"
    log_done "Alert script installed (customize at $ALERT_DEST)"
else
    log_warn "Alert script exists, skipping (edit $ALERT_DEST to customize)"
fi

# 4. Install LaunchAgent for connection monitor
log_step "Installing connection monitor..."
LAUNCHD_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCHD_DIR"

PLIST_SRC="$SCRIPT_DIR/launchd/com.clawdbot.connection-monitor.plist"
PLIST_DEST="$LAUNCHD_DIR/com.clawdbot.connection-monitor.plist"

# Replace $HOME with actual path
sed "s|\$HOME|$HOME|g" "$PLIST_SRC" > "$PLIST_DEST"

launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load "$PLIST_DEST"
log_done "Connection monitor installed and started"

# 5. Create command shortcuts
log_step "Creating command shortcuts..."
mkdir -p "$HOME/bin"

# Daily report command
cat > "$HOME/bin/tw-report" << 'EOF'
#!/bin/bash
exec "$HOME/Development/Projects/clawdbot/infrastructure/tw-mac/automation/daily-report-generator.sh" "$@"
EOF
chmod +x "$HOME/bin/tw-report"

# Connection check command
cat > "$HOME/bin/tw-check" << 'EOF'
#!/bin/bash
exec "$HOME/Development/Projects/clawdbot/infrastructure/tw-mac/automation/connection-monitor.sh" check
EOF
chmod +x "$HOME/bin/tw-check"

# Reconnect command
cat > "$HOME/bin/tw-reconnect" << 'EOF'
#!/bin/bash
exec "$HOME/Development/Projects/clawdbot/infrastructure/tw-mac/automation/connection-monitor.sh" reconnect
EOF
chmod +x "$HOME/bin/tw-reconnect"

log_done "Commands created: tw-report, tw-check, tw-reconnect"

# 6. Add startup sequence to login items (optional)
log_step "Configuring startup sequence..."
STARTUP_SCRIPT="$SCRIPT_DIR/startup-sequence.sh"
chmod +x "$STARTUP_SCRIPT"

# Check if already in zprofile
if ! grep -q "startup-sequence.sh" "$HOME/.zprofile" 2>/dev/null; then
    echo "" >> "$HOME/.zprofile"
    echo "# Clawdbot startup (added by install-monitoring.sh)" >> "$HOME/.zprofile"
    echo "[ -x \"$STARTUP_SCRIPT\" ] && \"$STARTUP_SCRIPT\" &" >> "$HOME/.zprofile"
    log_done "Startup sequence added to .zprofile"
else
    log_warn "Startup already in .zprofile"
fi

# 7. Create shutdown alias
log_step "Creating shutdown handler..."
SHUTDOWN_SCRIPT="$SCRIPT_DIR/shutdown-handler.sh"
chmod +x "$SHUTDOWN_SCRIPT"

# Add alias to zshrc
if ! grep -q "tw-shutdown" "$HOME/.zshrc" 2>/dev/null; then
    echo "" >> "$HOME/.zshrc"
    echo "# Clawdbot shutdown (added by install-monitoring.sh)" >> "$HOME/.zshrc"
    echo "alias tw-shutdown='$SHUTDOWN_SCRIPT'" >> "$HOME/.zshrc"
    log_done "Shutdown alias added (tw-shutdown)"
else
    log_warn "Shutdown alias already exists"
fi

# 8. Run initial report
log_step "Generating initial report..."
"$HOME/bin/tw-report" --quiet 2>/dev/null || log_warn "Report generation skipped (TW Mac may be offline)"

# 9. Verify installation
echo ""
echo "═══════════════════════════════════════════"
echo "Installation Summary"
echo "═══════════════════════════════════════════"
echo ""

echo "Services:"
launchctl list | grep -q "com.clawdbot.connection-monitor" && log_done "Connection monitor running" || log_warn "Connection monitor not running"
echo ""

echo "Commands installed:"
echo "  tw-report     - Generate daily report"
echo "  tw-check      - Quick connectivity check"
echo "  tw-reconnect  - Force reconnection"
echo "  tw-shutdown   - Graceful shutdown"
echo ""

echo "Startup:"
echo "  On login: Automatic connection + sync"
echo "  On wake:  Connection monitor reconnects"
echo ""

echo "Alerts:"
echo "  Edit: $HOME/.claude/tw-mac/alert.sh"
echo "  Log:  $HOME/.claude/tw-mac/alerts.log"
echo ""

echo "Reports:"
echo "  Daily: $HOME/.claude/tw-mac/reports/"
echo "  Generate: tw-report"
echo ""

echo "═══════════════════════════════════════════"
echo -e "${GREEN}Monitoring installation complete!${NC}"
echo "═══════════════════════════════════════════"
echo ""
echo "Quick test: tw-check"
