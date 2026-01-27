#!/bin/bash
# Tailscale Setup Script for Clawdbot Distributed System
# Sets up secure internet access to remote Mac

set -e

echo "🌐 Tailscale Setup for Clawdbot"
echo "================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REMOTE_HOST="192.168.1.245"
REMOTE_USER="tywhitaker"
GATEWAY_PORT="18789"
CLAWDBOT_TOKEN="clawdbot-local-dev"

# Check prerequisites
check_prereqs() {
    echo "📋 Checking prerequisites..."
    
    # Check if running on main Mac
    if [ "$(hostname)" != "Mac.local" ] && [ "$(hostname)" != "Mac.lan" ]; then
        echo -e "${YELLOW}⚠️  Warning: This should be run on main Mac${NC}"
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check SSH access
    if ! ssh -o ConnectTimeout=5 ${REMOTE_USER}@${REMOTE_HOST} "echo test" &>/dev/null; then
        echo -e "${RED}❌ Cannot SSH to remote Mac${NC}"
        echo "Run: ssh-copy-id ${REMOTE_USER}@${REMOTE_HOST}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prerequisites OK${NC}"
    echo ""
}

# Install Tailscale on main Mac
install_local() {
    echo "📦 Installing Tailscale on main Mac..."
    
    if command -v tailscale &> /dev/null; then
        echo -e "${GREEN}✅ Tailscale already installed$(NC}"
        TAILSCALE_VERSION=$(tailscale version | head -1)
        echo "   Version: $TAILSCALE_VERSION"
    else
        echo "Installing via Homebrew..."
        brew install tailscale
        echo -e "${GREEN}✅ Tailscale installed${NC}"
    fi
    
    # Start Tailscale
    echo "Starting Tailscale..."
    sudo tailscale up
    
    # Get local Tailscale IP
    LOCAL_TS_IP=$(tailscale ip -4)
    echo -e "${GREEN}✅ Local Tailscale IP: $LOCAL_TS_IP${NC}"
    echo ""
}

# Install Tailscale on remote Mac
install_remote() {
    echo "📦 Installing Tailscale on remote Mac..."
    
    ssh ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
    set -e
    
    if command -v tailscale &> /dev/null; then
        echo "✅ Tailscale already installed"
        tailscale version | head -1
    else
        echo "Installing via Homebrew..."
        brew install tailscale
        echo "✅ Tailscale installed"
    fi
    
    # Start Tailscale
    echo "Starting Tailscale..."
    sudo tailscale up
    
    # Get remote Tailscale IP
    REMOTE_TS_IP=$(tailscale ip -4)
    echo "✅ Remote Tailscale IP: $REMOTE_TS_IP"
ENDSSH
    
    # Get remote Tailscale IP
    REMOTE_TS_IP=$(ssh ${REMOTE_USER}@${REMOTE_HOST} "tailscale ip -4")
    echo -e "${GREEN}✅ Remote Tailscale IP: $REMOTE_TS_IP${NC}"
    echo ""
}

# Update Clawdbot configuration
update_clawdbot_config() {
    echo "⚙️  Updating Clawdbot configuration..."
    
    # Get Tailscale IPs
    LOCAL_TS_IP=$(tailscale ip -4)
    
    # Update remote node config
    ssh ${REMOTE_USER}@${REMOTE_HOST} << ENDSSH
    cat > ~/.clawdbot/clawdbot.json << 'EOF'
{
  "meta": {
    "lastTouchedVersion": "2026.1.24-3"
  },
  "gateway": {
    "mode": "remote",
    "remote": {
      "url": "ws://${LOCAL_TS_IP}:${GATEWAY_PORT}",
      "token": "${CLAWDBOT_TOKEN}"
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/Users/tywhitaker",
      "maxConcurrent": 2
    }
  }
}
EOF

echo "✅ Clawdbot config updated"
cat ~/.clawdbot/clawdbot.json
ENDSSH
    
    echo -e "${GREEN}✅ Configuration updated${NC}"
    echo ""
}

# Update gateway binding
update_gateway() {
    echo "⚙️  Updating Clawdbot gateway..."
    
    # Allow connections from all interfaces (including Tailscale)
    clawdbot gateway config set bind 0.0.0.0
    
    # Restart gateway
    echo "Restarting gateway..."
    clawdbot gateway restart
    
    echo -e "${GREEN}✅ Gateway configured${NC}"
    echo ""
}

# Restart remote node
restart_remote_node() {
    echo "🔄 Restarting remote Clawdbot node..."
    
    ssh ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
    clawdbot node restart
    sleep 3
    clawdbot node status
ENDSSH
    
    echo -e "${GREEN}✅ Remote node restarted${NC}"
    echo ""
}

# Test connection
test_connection() {
    echo "🧪 Testing Tailscale connection..."
    
    REMOTE_TS_IP=$(ssh ${REMOTE_USER}@${REMOTE_HOST} "tailscale ip -4")
    
    # Test SSH over Tailscale
    if ssh -o ConnectTimeout=10 ${REMOTE_USER}@${REMOTE_TS_IP} "echo test" &>/dev/null; then
        echo -e "${GREEN}✅ SSH over Tailscale: Working${NC}"
    else
        echo -e "${RED}❌ SSH over Tailscale: Failed${NC}"
    fi
    
    # Test Clawdbot connection
    sleep 5
    if ssh ${REMOTE_USER}@${REMOTE_TS_IP} "clawdbot node status | grep -q Connected"; then
        echo -e "${GREEN}✅ Clawdbot connection: Working${NC}"
    else
        echo -e "${YELLOW}⚠️  Clawdbot connection: Check manually${NC}"
    fi
    
    echo ""
}

# Display summary
show_summary() {
    LOCAL_TS_IP=$(tailscale ip -4)
    REMOTE_TS_IP=$(ssh ${REMOTE_USER}@${REMOTE_HOST} "tailscale ip -4")
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}✅ Tailscale Setup Complete!${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📊 Tailscale IPs:"
    echo "   Main Mac:   $LOCAL_TS_IP"
    echo "   Remote Mac: $REMOTE_TS_IP"
    echo ""
    echo "🌐 Access from anywhere:"
    echo "   SSH: ssh ${REMOTE_USER}@${REMOTE_TS_IP}"
    echo "   Dashboard: http://localhost:${GATEWAY_PORT}"
    echo ""
    echo "📝 Next steps:"
    echo "   1. Test SSH: ssh ${REMOTE_USER}@${REMOTE_TS_IP}"
    echo "   2. Check dashboard shows remote node connected"
    echo "   3. Verify from outside your network (coffee shop, etc.)"
    echo ""
    echo "💡 Tips:"
    echo "   - Tailscale persists across reboots"
    echo "   - Works on mobile devices too (install Tailscale app)"
    echo "   - All traffic is encrypted automatically"
    echo ""
    echo "🔧 Management:"
    echo "   Status: tailscale status"
    echo "   Disable: sudo tailscale down"
    echo "   Enable: sudo tailscale up"
    echo ""
}

# Main execution
main() {
    check_prereqs
    install_local
    install_remote
    update_clawdbot_config
    update_gateway
    restart_remote_node
    test_connection
    show_summary
}

# Run main
main
