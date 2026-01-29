#!/bin/bash
set -e

# ==========================================
# REMOTE NODE FULL CONTROL ENABLER
# ==========================================
# Run this script ON THE REMOTE NODE (TW) to
# allow the gateway to execute commands
# WITHOUT manual approvals.
# ==========================================

CONFIG_FILE="$HOME/.clawdbot/exec-approvals.json"
CONFIG_DIR=$(dirname "$CONFIG_FILE")

echo "🔧 Configuring Clawdbot Node for Full Unattended Access..."

# Ensure directory exists
mkdir -p "$CONFIG_DIR"

# Write permissive configuration
# - security: full (Allows all commands)
# - ask: off (Disables approval prompts)
cat > "$CONFIG_FILE" <<EOF
{
  "version": 1,
  "defaults": {
    "security": "full",
    "ask": "off",
    "askFallback": "deny",
    "autoAllowSkills": true
  },
  "agents": {
    "*": {
      "security": "full",
      "ask": "off"
    }
  }
}
EOF

# Secure the file
chmod 600 "$CONFIG_FILE"

echo "✅ Configuration written to: $CONFIG_FILE"
echo "   - Security Mode: FULL"
echo "   - Approval Prompts: OFF"
echo ""

# Restart service to apply changes
if command -v clawdbot >/dev/null 2>&1; then
    echo "🔄 Restarting Clawdbot Node Service..."
    clawdbot node restart
    echo "✅ Service restarted."
else
    echo "⚠️ 'clawdbot' command not found in PATH."
    echo "   Please restart the service manually to apply changes."
fi

echo ""
echo "🚀 Node is now ready for full remote control."
