#!/bin/bash
# Remote Developer Environment Setup for TW (192.168.1.245)
# Installs: Git Identity, OrbStack, GitHub CLI, Codex, Gemini, Kilocode

REMOTE_USER="tywhitaker"
REMOTE_HOST="192.168.1.245"
GIT_NAME="Don Quilatte"
GIT_EMAIL="roller-erasers.0b@icloud.com"

# Setup script to run on remote
REMOTE_SCRIPT=$(cat <<EOF
set -e

echo "🔹 [Remote] Starting Setup on \$(hostname)..."

# 1. Setup Homebrew Path
if [ -f "/opt/homebrew/bin/brew" ]; then
    eval "\$(/opt/homebrew/bin/brew shellenv)"
elif [ -f "/usr/local/bin/brew" ]; then
    eval "\$(/usr/local/bin/brew shellenv)"
fi

# 2. Configure Git
echo "🔹 [Remote] Configuring Git Identity..."
git config --global user.name "${GIT_NAME}"
git config --global user.email "${GIT_EMAIL}"
echo "   ✅ Git Configured: \$(git config --global user.name) <\$(git config --global user.email)>"

# 3. Install OrbStack (Docker)
if ! command -v orbstack &>/dev/null; then
    echo "🔹 [Remote] Installing OrbStack..."
    brew install orbstack
    echo "   ✅ OrbStack Installed. Starting..."
    # Note: 'orbstack start' might require GUI session or specific permissions
    # We attempt it, but don't fail if it needs manual first-run
    orbstack start || echo "   ⚠️ OrbStack start require manual intervention on first run"
    orbstack config set autostart true || true
else
    echo "   ✅ OrbStack already installed status: \$(orbstack status 2>/dev/null || echo 'Unknown')"
fi

# 4. Install Developer CLIs
echo "🔹 [Remote] Installing AI & Dev Tools..."
TOOLS_TO_INSTALL=(gh codex gemini kilocode)

for tool in "\${TOOLS_TO_INSTALL[@]}"; do
    if ! command -v \$tool &>/dev/null; then
        echo "   Installing \$tool..."
        # Try brew first
        if brew info \$tool &>/dev/null; then
             brew install \$tool
        else
             echo "   ⚠️  Could not find '\$tool' in default brew taps. Attempting npm/pip fallback checks..."
             # Fallback logic could go here, or we report failure
             echo "   ❌ Failed to install \$tool via brew."
        fi
    else
        echo "   ✅ \$tool is already installed"
    fi
done

# 5. Verify Docker
if command -v docker &>/dev/null; then
   echo "🔹 [Remote] Docker Check:"
   docker --version
else
   echo "   ⚠️ Docker CLI not found (is OrbStack running?)"
fi

echo "✅ [Remote] Setup Complete!"
EOF
)

echo "🚀 Deploying Setup to ${REMOTE_USER}@${REMOTE_HOST}..."
ssh -t "${REMOTE_USER}@${REMOTE_HOST}" "bash -s" <<< "$REMOTE_SCRIPT"
