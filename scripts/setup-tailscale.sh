#!/bin/bash
# Tailscale Setup Script for Clawdbot Distributed System
# Sets up secure internet access to remote Mac

set -e

# shellcheck source=lib/common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

echo "🌐 Tailscale Setup for Clawdbot"
echo "================================"
echo ""

# Load configuration
load_env

# Configuration from environment (no hardcoded values)
: "${REMOTE_HOST:?Set REMOTE_HOST in .env or environment}"
: "${REMOTE_USER:?Set REMOTE_USER in .env or environment}"
: "${GATEWAY_PORT:=18789}"

# Cache for Tailscale IPs (performance optimization)
LOCAL_TS_IP=""
REMOTE_TS_IP=""

# Get and cache local Tailscale IP
get_local_ts_ip() {
    if [ -z "$LOCAL_TS_IP" ]; then
        LOCAL_TS_IP=$(tailscale ip -4 2>/dev/null || echo "")
    fi
    echo "$LOCAL_TS_IP"
}

# Get and cache remote Tailscale IP
get_remote_ts_ip() {
    if [ -z "$REMOTE_TS_IP" ]; then
        REMOTE_TS_IP=$(ssh_cmd "${REMOTE_USER}@${REMOTE_HOST}" "tailscale ip -4" 2>/dev/null || echo "")
    fi
    echo "$REMOTE_TS_IP"
}

# Check prerequisites
check_prereqs() {
    echo "📋 Checking prerequisites..."

    # Check SSH access
    if ! ssh_check "${REMOTE_USER}@${REMOTE_HOST}"; then
        print_error "Cannot SSH to remote Mac"
        echo "Run: ssh-copy-id ${REMOTE_USER}@${REMOTE_HOST}"
        exit 1
    fi

    print_success "Prerequisites OK"
    echo ""
}

# Install Tailscale on main Mac
install_local() {
    echo "📦 Installing Tailscale on main Mac..."

    if command -v tailscale &> /dev/null; then
        print_success "Tailscale already installed"
        TAILSCALE_VERSION=$(tailscale version | head -1)
        echo "   Version: $TAILSCALE_VERSION"
    else
        echo "Installing via Homebrew..."
        brew install tailscale
        print_success "Tailscale installed"
    fi

    # Check if already authenticated
    if tailscale status &>/dev/null; then
        print_success "Tailscale already authenticated"
    else
        # Start Tailscale (requires auth)
        echo "Starting Tailscale (authentication required)..."
        sudo tailscale up
    fi

    # Get local Tailscale IP
    LOCAL_TS_IP=$(get_local_ts_ip)
    if [ -n "$LOCAL_TS_IP" ]; then
        print_success "Local Tailscale IP: $LOCAL_TS_IP"
    else
        print_error "Could not get Tailscale IP"
        exit 1
    fi
    echo ""
}

# Install Tailscale on remote Mac
install_remote() {
    echo "📦 Installing Tailscale on remote Mac..."

    ssh_cmd "${REMOTE_USER}@${REMOTE_HOST}" << 'ENDSSH'
    set -e

    if command -v tailscale &> /dev/null; then
        echo "✅ Tailscale already installed"
        tailscale version | head -1
    else
        echo "Installing via Homebrew..."
        brew install tailscale
        echo "✅ Tailscale installed"
    fi

    # Check if already authenticated
    if tailscale status &>/dev/null; then
        echo "✅ Tailscale already authenticated"
    else
        # Start Tailscale (requires auth)
        echo "Starting Tailscale (authentication required)..."
        sudo tailscale up
    fi

    # Get remote Tailscale IP
    TS_IP=$(tailscale ip -4)
    echo "✅ Remote Tailscale IP: $TS_IP"
ENDSSH

    # Cache remote Tailscale IP
    REMOTE_TS_IP=$(get_remote_ts_ip)
    print_success "Remote Tailscale IP: $REMOTE_TS_IP"
    echo ""
}

# Update Clawdbot configuration
update_clawdbot_config() {
    echo "⚙️  Updating Clawdbot configuration..."

    # Get token securely
    local token
    if ! token=$(get_gateway_token); then
        print_error "CLAWDBOT_GATEWAY_TOKEN not set"
        echo "   Set it in .env or export CLAWDBOT_GATEWAY_TOKEN=<token>"
        exit 1
    fi

    # Get Tailscale IPs
    local local_ip
    local_ip=$(get_local_ts_ip)

    # Get remote user's home directory
    local remote_home
    remote_home=$(ssh_cmd "${REMOTE_USER}@${REMOTE_HOST}" 'echo $HOME')

    # Update remote node config (quoted heredoc prevents local expansion)
    # Variables are passed explicitly via environment
    ssh_cmd "${REMOTE_USER}@${REMOTE_HOST}" \
        "GATEWAY_URL='ws://${local_ip}:${GATEWAY_PORT}' GATEWAY_TOKEN='${token}' REMOTE_HOME='${remote_home}'" \
        'bash -s' << 'ENDSSH'
    cat > ~/.clawdbot/clawdbot.json << EOF
{
  "meta": {
    "lastTouchedVersion": "2026.1.24-3"
  },
  "gateway": {
    "mode": "remote",
    "remote": {
      "url": "${GATEWAY_URL}",
      "token": "${GATEWAY_TOKEN}"
    }
  },
  "agents": {
    "defaults": {
      "workspace": "${REMOTE_HOME}",
      "maxConcurrent": 2
    }
  }
}
EOF

echo "✅ Clawdbot config updated"
ENDSSH

    print_success "Configuration updated"
    echo ""
}

# Update gateway binding
update_gateway() {
    echo "⚙️  Updating Clawdbot gateway..."

    # SECURITY: Bind only to Tailscale interface, not 0.0.0.0
    local local_ip
    local_ip=$(get_local_ts_ip)

    if [ -n "$local_ip" ]; then
        # Bind to Tailscale IP only (secure)
        clawdbot gateway config set bind "$local_ip"
        print_success "Gateway bound to Tailscale IP: $local_ip"
    else
        print_error "Cannot get Tailscale IP - gateway not updated"
        exit 1
    fi

    # Restart gateway
    echo "Restarting gateway..."
    clawdbot gateway restart

    print_success "Gateway configured"
    echo ""
}

# Restart remote node
restart_remote_node() {
    echo "🔄 Restarting remote Clawdbot node..."

    ssh_cmd "${REMOTE_USER}@${REMOTE_HOST}" << 'ENDSSH'
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    clawdbot node restart
    sleep 3
    clawdbot node status
ENDSSH

    print_success "Remote node restarted"
    echo ""
}

# Test connection
test_connection() {
    echo "🧪 Testing Tailscale connection..."

    local remote_ip
    remote_ip=$(get_remote_ts_ip)

    # Test SSH over Tailscale
    if ssh_cmd "${REMOTE_USER}@${remote_ip}" "echo test" &>/dev/null; then
        print_success "SSH over Tailscale: Working"
    else
        print_error "SSH over Tailscale: Failed"
    fi

    # Test Clawdbot connection
    sleep 5
    if ssh_cmd "${REMOTE_USER}@${remote_ip}" 'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && clawdbot node status | grep -qi "connected"'; then
        print_success "Clawdbot connection: Working"
    else
        print_warning "Clawdbot connection: Check manually"
    fi

    echo ""
}

# Display summary
show_summary() {
    local local_ip remote_ip
    local_ip=$(get_local_ts_ip)
    remote_ip=$(get_remote_ts_ip)

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_success "Tailscale Setup Complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📊 Tailscale IPs:"
    echo "   Main Mac:   $local_ip"
    echo "   Remote Mac: $remote_ip"
    echo ""
    echo "🌐 Access from anywhere:"
    echo "   SSH: ssh ${REMOTE_USER}@${remote_ip}"
    echo "   Dashboard: http://localhost:${GATEWAY_PORT}"
    echo ""
    echo "📝 Next steps:"
    echo "   1. Test SSH: ssh ${REMOTE_USER}@${remote_ip}"
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

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Sets up Tailscale VPN for secure remote access to Clawdbot."
    echo ""
    echo "Options:"
    echo "  --help, -h      Show this help message"
    echo "  --check         Only check Tailscale status"
    echo ""
    echo "Required environment variables (set in .env):"
    echo "  REMOTE_HOST              IP address of remote Mac"
    echo "  REMOTE_USER              Username on remote Mac"
    echo "  CLAWDBOT_GATEWAY_TOKEN   Gateway authentication token"
    echo ""
    echo "Optional:"
    echo "  GATEWAY_PORT             Gateway port (default: 18789)"
    echo ""
    exit 0
}

# Check status only
check_status() {
    echo "Checking Tailscale status..."
    echo ""

    echo "Local:"
    if command -v tailscale &>/dev/null; then
        tailscale status || echo "  Not connected"
    else
        echo "  Not installed"
    fi
    echo ""

    echo "Remote:"
    if ssh_check "${REMOTE_USER}@${REMOTE_HOST}"; then
        ssh_cmd "${REMOTE_USER}@${REMOTE_HOST}" 'tailscale status 2>/dev/null || echo "  Not connected"'
    else
        echo "  Cannot SSH to remote"
    fi
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

# Handle arguments
case "${1:-}" in
    --help|-h)
        show_help
        ;;
    --check)
        check_status
        ;;
    *)
        main
        ;;
esac
