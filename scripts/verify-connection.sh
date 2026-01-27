#!/bin/bash
# Verify Clawdbot Distributed System Connectivity
# Tests all connections between main and remote Macs

set -e

echo "🔍 Clawdbot Connection Verification"
echo "===================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
MAIN_IP="192.168.1.230"
REMOTE_IP="192.168.1.245"
REMOTE_USER="tywhitaker"
GATEWAY_PORT="18789"

# Counters
PASS=0
FAIL=0
WARN=0

# Test functions
test_pass() {
    echo -e "  ${GREEN}✅ PASS${NC}: $1"
    ((PASS++))
}

test_fail() {
    echo -e "  ${RED}❌ FAIL${NC}: $1"
    ((FAIL++))
}

test_warn() {
    echo -e "  ${YELLOW}⚠️  WARN${NC}: $1"
    ((WARN++))
}

print_section() {
    echo ""
    echo -e "${CYAN}━━━ $1 ━━━${NC}"
}

# Tests
test_local_gateway() {
    print_section "1. Local Gateway"

    # Check if gateway is running
    if pgrep -f "clawdbot.*gateway" > /dev/null 2>&1; then
        test_pass "Gateway process running"
    else
        # Try checking via clawdbot status
        if clawdbot gateway status 2>/dev/null | grep -qi "running"; then
            test_pass "Gateway process running"
        else
            test_fail "Gateway process not found"
            return
        fi
    fi

    # Check port is listening
    if lsof -i :${GATEWAY_PORT} > /dev/null 2>&1; then
        test_pass "Port ${GATEWAY_PORT} is listening"
    else
        test_fail "Port ${GATEWAY_PORT} not listening"
    fi

    # Check health endpoint
    if curl -s --connect-timeout 5 "http://localhost:${GATEWAY_PORT}/health" > /dev/null 2>&1; then
        test_pass "Health endpoint responding"
    else
        test_fail "Health endpoint not responding"
    fi

    # Check clawdbot gateway status
    if clawdbot gateway status 2>/dev/null | head -3; then
        test_pass "Gateway status command works"
    else
        test_warn "Could not get gateway status"
    fi
}

test_network_connectivity() {
    print_section "2. Network Connectivity"

    # Ping remote Mac
    if ping -c 1 -W 2 ${REMOTE_IP} > /dev/null 2>&1; then
        test_pass "Remote Mac pingable at ${REMOTE_IP}"
    else
        test_fail "Cannot ping remote Mac at ${REMOTE_IP}"
        return
    fi

    # Check SSH port
    if nc -z -w 2 ${REMOTE_IP} 22 2>/dev/null; then
        test_pass "SSH port 22 reachable"
    else
        test_fail "SSH port 22 not reachable"
    fi

    # Check gateway port from remote perspective
    REMOTE_CAN_REACH=$(ssh -o ConnectTimeout=5 ${REMOTE_USER}@${REMOTE_IP} \
        "curl -s --connect-timeout 3 http://${MAIN_IP}:${GATEWAY_PORT}/health > /dev/null 2>&1 && echo yes || echo no" 2>/dev/null)

    if [ "$REMOTE_CAN_REACH" = "yes" ]; then
        test_pass "Remote can reach gateway at ${MAIN_IP}:${GATEWAY_PORT}"
    else
        test_fail "Remote cannot reach gateway"
    fi
}

test_ssh_connection() {
    print_section "3. SSH Connection"

    # Test passwordless SSH
    if ssh -o ConnectTimeout=5 -o BatchMode=yes ${REMOTE_USER}@${REMOTE_IP} "echo test" > /dev/null 2>&1; then
        test_pass "Passwordless SSH working"
    else
        test_fail "Passwordless SSH not working"
        echo "      Run: ssh-copy-id ${REMOTE_USER}@${REMOTE_IP}"
        return
    fi

    # Check SSH key exists
    if [ -f ~/.ssh/id_ed25519_clawdbot ]; then
        test_pass "SSH key exists (~/.ssh/id_ed25519_clawdbot)"
    elif [ -f ~/.ssh/id_rsa ] || [ -f ~/.ssh/id_ed25519 ]; then
        test_pass "SSH key exists (default key)"
    else
        test_warn "No dedicated SSH key found"
    fi

    # Check SSH config entry
    if grep -q "${REMOTE_IP}" ~/.ssh/config 2>/dev/null; then
        test_pass "SSH config entry exists for ${REMOTE_IP}"
    else
        test_warn "No SSH config entry for ${REMOTE_IP}"
    fi
}

test_remote_node() {
    print_section "4. Remote Node"

    # Check if clawdbot is installed
    REMOTE_VERSION=$(ssh -o ConnectTimeout=5 ${REMOTE_USER}@${REMOTE_IP} \
        'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && clawdbot --version' 2>/dev/null)

    if [ -n "$REMOTE_VERSION" ]; then
        test_pass "Clawdbot installed: ${REMOTE_VERSION}"
    else
        test_fail "Clawdbot not found on remote"
        return
    fi

    # Check node status
    NODE_STATUS=$(ssh ${REMOTE_USER}@${REMOTE_IP} \
        'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && clawdbot node status 2>&1' 2>/dev/null || echo "error")

    if echo "$NODE_STATUS" | grep -qi "connected\|running\|online"; then
        test_pass "Node status: Connected"
        echo "      $NODE_STATUS" | head -3
    elif echo "$NODE_STATUS" | grep -qi "disconnected\|stopped\|offline"; then
        test_fail "Node status: Disconnected"
        echo "      $NODE_STATUS" | head -3
    else
        test_warn "Node status unclear"
        echo "      $NODE_STATUS" | head -3
    fi

    # Check node configuration
    REMOTE_CONFIG=$(ssh ${REMOTE_USER}@${REMOTE_IP} 'cat ~/.clawdbot/clawdbot.json 2>/dev/null' || echo "{}")

    if echo "$REMOTE_CONFIG" | grep -q "ws://${MAIN_IP}:${GATEWAY_PORT}"; then
        test_pass "Node configured to connect to gateway"
    elif echo "$REMOTE_CONFIG" | grep -q "ws://Mac.local:${GATEWAY_PORT}"; then
        test_pass "Node configured to connect to gateway (hostname)"
    else
        test_warn "Node configuration may be incorrect"
        echo "      Expected: ws://${MAIN_IP}:${GATEWAY_PORT}"
    fi
}

test_auto_restart() {
    print_section "5. Auto-restart Configuration"

    # Check LaunchAgent exists
    AGENT_EXISTS=$(ssh ${REMOTE_USER}@${REMOTE_IP} \
        '[ -f ~/Library/LaunchAgents/com.clawdbot.node.plist ] && echo yes || echo no' 2>/dev/null)

    if [ "$AGENT_EXISTS" = "yes" ]; then
        test_pass "LaunchAgent plist exists"
    else
        test_fail "LaunchAgent plist not found"
        echo "      Run: ./scripts/fix-auto-restart.sh"
        return
    fi

    # Check LaunchAgent is loaded
    AGENT_LOADED=$(ssh ${REMOTE_USER}@${REMOTE_IP} \
        'launchctl list 2>/dev/null | grep -c clawdbot' 2>/dev/null || echo "0")

    if [ "$AGENT_LOADED" -gt 0 ]; then
        test_pass "LaunchAgent is loaded"
    else
        test_fail "LaunchAgent not loaded"
        echo "      Run: launchctl load ~/Library/LaunchAgents/com.clawdbot.node.plist"
    fi

    # Check startup script exists
    SCRIPT_EXISTS=$(ssh ${REMOTE_USER}@${REMOTE_IP} \
        '[ -x ~/.clawdbot/scripts/start-node.sh ] && echo yes || echo no' 2>/dev/null)

    if [ "$SCRIPT_EXISTS" = "yes" ]; then
        test_pass "Startup script exists and is executable"
    else
        test_warn "Startup script missing or not executable"
    fi
}

test_optional_components() {
    print_section "6. Optional Components"

    # Check OrbStack/Docker on remote
    DOCKER_INSTALLED=$(ssh ${REMOTE_USER}@${REMOTE_IP} \
        'command -v docker > /dev/null 2>&1 && echo yes || echo no' 2>/dev/null)

    if [ "$DOCKER_INSTALLED" = "yes" ]; then
        test_pass "Docker available on remote (optional)"
    else
        test_warn "Docker not installed on remote (optional)"
    fi

    # Check Tailscale on main
    if command -v tailscale > /dev/null 2>&1; then
        test_pass "Tailscale available locally (optional)"
    else
        test_warn "Tailscale not installed locally (optional for remote access)"
    fi
}

# Print summary
print_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}Summary${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "  ${GREEN}Passed${NC}: $PASS"
    echo -e "  ${RED}Failed${NC}: $FAIL"
    echo -e "  ${YELLOW}Warnings${NC}: $WARN"
    echo ""

    if [ $FAIL -eq 0 ]; then
        echo -e "${GREEN}✅ All critical tests passed!${NC}"
        echo ""
        echo "Your distributed Clawdbot system is working correctly."
    else
        echo -e "${RED}❌ Some tests failed.${NC}"
        echo ""
        echo "Please review the failures above and consult:"
        echo "  - docs/TROUBLESHOOTING.md"
        echo "  - docs/AUTO_RESTART_FIX.md"
    fi

    echo ""
}

# Quick test mode
quick_test() {
    echo "Quick connectivity test..."
    echo ""

    # Gateway
    if curl -s --connect-timeout 3 "http://localhost:${GATEWAY_PORT}/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✅${NC} Gateway: Running"
    else
        echo -e "${RED}❌${NC} Gateway: Not responding"
    fi

    # SSH
    if ssh -o ConnectTimeout=3 -o BatchMode=yes ${REMOTE_USER}@${REMOTE_IP} "echo ok" > /dev/null 2>&1; then
        echo -e "${GREEN}✅${NC} SSH: Connected"
    else
        echo -e "${RED}❌${NC} SSH: Cannot connect"
    fi

    # Remote node
    NODE_OK=$(ssh -o ConnectTimeout=5 ${REMOTE_USER}@${REMOTE_IP} \
        'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && clawdbot node status 2>&1 | grep -qi "connected\|running" && echo yes || echo no' 2>/dev/null || echo "no")

    if [ "$NODE_OK" = "yes" ]; then
        echo -e "${GREEN}✅${NC} Remote Node: Connected"
    else
        echo -e "${RED}❌${NC} Remote Node: Not connected"
    fi

    echo ""
}

# Main execution
main() {
    test_local_gateway
    test_network_connectivity
    test_ssh_connection
    test_remote_node
    test_auto_restart
    test_optional_components
    print_summary
}

# Handle arguments
case "${1:-}" in
    --quick|-q)
        quick_test
        ;;
    --help|-h)
        echo "Usage: $0 [--quick|-q]"
        echo ""
        echo "Verifies connectivity of Clawdbot distributed system."
        echo ""
        echo "Options:"
        echo "  --quick, -q     Quick 3-point check (gateway, SSH, node)"
        echo "  --help, -h      Show this help message"
        echo ""
        echo "Configuration:"
        echo "  Main Mac:    ${MAIN_IP}"
        echo "  Remote Mac:  ${REMOTE_USER}@${REMOTE_IP}"
        echo "  Gateway:     port ${GATEWAY_PORT}"
        exit 0
        ;;
    *)
        main
        ;;
esac
