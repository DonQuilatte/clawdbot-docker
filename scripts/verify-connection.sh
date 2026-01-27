#!/bin/bash
# Verify Clawdbot Distributed System Connectivity
# Tests all connections between main and remote Macs

set -e

# shellcheck source=lib/common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

echo "🔍 Clawdbot Connection Verification"
echo "===================================="
echo ""

# Load configuration
load_env

# Configuration from environment (no hardcoded values)
: "${GATEWAY_IP:?Set GATEWAY_IP in .env or environment}"
: "${REMOTE_HOST:?Set REMOTE_HOST in .env or environment}"
: "${REMOTE_USER:?Set REMOTE_USER in .env or environment}"
: "${GATEWAY_PORT:=18789}"

# Counters
PASS=0
FAIL=0
WARN=0

# Override test functions to use counters
test_pass() {
    echo -e "  ${GREEN}✅ PASS${NC}: $1"
    ((PASS++)) || true
}

test_fail() {
    echo -e "  ${RED}❌ FAIL${NC}: $1"
    ((FAIL++)) || true
}

test_warn() {
    echo -e "  ${YELLOW}⚠️  WARN${NC}: $1"
    ((WARN++)) || true
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
    if lsof -i :"${GATEWAY_PORT}" > /dev/null 2>&1; then
        test_pass "Port ${GATEWAY_PORT} is listening"
    else
        test_fail "Port ${GATEWAY_PORT} not listening"
    fi

    # Check health endpoint
    if curl -s --connect-timeout "$CURL_TIMEOUT" "http://localhost:${GATEWAY_PORT}/health" > /dev/null 2>&1; then
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
    if ping -c 1 -W "$PING_TIMEOUT" "${REMOTE_HOST}" > /dev/null 2>&1; then
        test_pass "Remote Mac pingable at ${REMOTE_HOST}"
    else
        test_fail "Cannot ping remote Mac at ${REMOTE_HOST}"
        return
    fi

    # Check SSH port
    if nc -z -w "$PING_TIMEOUT" "${REMOTE_HOST}" 22 2>/dev/null; then
        test_pass "SSH port 22 reachable"
    else
        test_fail "SSH port 22 not reachable"
    fi

    # Check gateway port from remote perspective
    local remote_can_reach
    remote_can_reach=$(ssh_cmd "${REMOTE_USER}@${REMOTE_HOST}" \
        "curl -s --connect-timeout 3 http://${GATEWAY_IP}:${GATEWAY_PORT}/health > /dev/null 2>&1 && echo yes || echo no" 2>/dev/null || echo "no")

    if [ "$remote_can_reach" = "yes" ]; then
        test_pass "Remote can reach gateway at ${GATEWAY_IP}:${GATEWAY_PORT}"
    else
        test_fail "Remote cannot reach gateway"
    fi
}

test_ssh_connection() {
    print_section "3. SSH Connection"

    # Test passwordless SSH
    if ssh_check "${REMOTE_USER}@${REMOTE_HOST}"; then
        test_pass "Passwordless SSH working"
    else
        test_fail "Passwordless SSH not working"
        echo "      Run: ssh-copy-id ${REMOTE_USER}@${REMOTE_HOST}"
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
    if grep -q "${REMOTE_HOST}" ~/.ssh/config 2>/dev/null; then
        test_pass "SSH config entry exists for ${REMOTE_HOST}"
    else
        test_warn "No SSH config entry for ${REMOTE_HOST}"
    fi
}

# Batch remote checks into single SSH call for performance
test_remote_node_and_config() {
    print_section "4. Remote Node"

    # Batch all remote checks in single SSH session
    local remote_info
    remote_info=$(ssh_cmd "${REMOTE_USER}@${REMOTE_HOST}" 'bash -s' 2>/dev/null <<'ENDSSH' || echo "SSH_FAILED"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# Get version
echo "VERSION=$(clawdbot --version 2>/dev/null || echo '')"

# Get node status
NODE_STATUS=$(clawdbot node status 2>&1 || echo "error")
echo "NODE_STATUS=$NODE_STATUS"

# Get config
CONFIG=$(cat ~/.clawdbot/clawdbot.json 2>/dev/null || echo '{}')
echo "CONFIG=$CONFIG"

# Check LaunchAgent
AGENT_EXISTS=$([ -f ~/Library/LaunchAgents/com.clawdbot.node.plist ] && echo yes || echo no)
echo "AGENT_EXISTS=$AGENT_EXISTS"

# Check LaunchAgent loaded
AGENT_LOADED=$(launchctl list 2>/dev/null | grep -c clawdbot || echo "0")
echo "AGENT_LOADED=$AGENT_LOADED"

# Check startup script
SCRIPT_EXISTS=$([ -x ~/.clawdbot/scripts/start-node.sh ] && echo yes || echo no)
echo "SCRIPT_EXISTS=$SCRIPT_EXISTS"
ENDSSH
)

    if [ "$remote_info" = "SSH_FAILED" ]; then
        test_fail "Could not connect to remote"
        return
    fi

    # Parse results
    local version node_status config
    version=$(echo "$remote_info" | grep "^VERSION=" | cut -d= -f2-)
    node_status=$(echo "$remote_info" | grep "^NODE_STATUS=" | cut -d= -f2-)
    config=$(echo "$remote_info" | grep "^CONFIG=" | cut -d= -f2-)

    # Check version
    if [ -n "$version" ]; then
        test_pass "Clawdbot installed: ${version}"
    else
        test_fail "Clawdbot not found on remote"
        return
    fi

    # Check node status
    if echo "$node_status" | grep -qi "connected\|running\|online"; then
        test_pass "Node status: Connected"
        echo "      $node_status" | head -3
    elif echo "$node_status" | grep -qi "disconnected\|stopped\|offline"; then
        test_fail "Node status: Disconnected"
        echo "      $node_status" | head -3
    else
        test_warn "Node status unclear"
        echo "      $node_status" | head -3
    fi

    # Check node configuration
    if echo "$config" | grep -q "ws://${GATEWAY_IP}:${GATEWAY_PORT}"; then
        test_pass "Node configured to connect to gateway"
    elif echo "$config" | grep -q "ws://.*:${GATEWAY_PORT}"; then
        test_pass "Node configured to connect to gateway (hostname)"
    else
        test_warn "Node configuration may be incorrect"
        echo "      Expected: ws://${GATEWAY_IP}:${GATEWAY_PORT}"
    fi

    # Auto-restart checks
    print_section "5. Auto-restart Configuration"

    local agent_exists agent_loaded script_exists
    agent_exists=$(echo "$remote_info" | grep "^AGENT_EXISTS=" | cut -d= -f2)
    agent_loaded=$(echo "$remote_info" | grep "^AGENT_LOADED=" | cut -d= -f2)
    script_exists=$(echo "$remote_info" | grep "^SCRIPT_EXISTS=" | cut -d= -f2)

    if [ "$agent_exists" = "yes" ]; then
        test_pass "LaunchAgent plist exists"
    else
        test_fail "LaunchAgent plist not found"
        echo "      Run: ./scripts/fix-auto-restart.sh"
    fi

    if [ "$agent_loaded" -gt 0 ] 2>/dev/null; then
        test_pass "LaunchAgent is loaded"
    else
        test_fail "LaunchAgent not loaded"
        echo "      Run: launchctl load ~/Library/LaunchAgents/com.clawdbot.node.plist"
    fi

    if [ "$script_exists" = "yes" ]; then
        test_pass "Startup script exists and is executable"
    else
        test_warn "Startup script missing or not executable"
    fi
}

test_optional_components() {
    print_section "6. Optional Components"

    # Check OrbStack/Docker on remote
    local docker_installed
    docker_installed=$(ssh_cmd "${REMOTE_USER}@${REMOTE_HOST}" \
        'command -v docker > /dev/null 2>&1 && echo yes || echo no' 2>/dev/null || echo "no")

    if [ "$docker_installed" = "yes" ]; then
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

    if [ "$FAIL" -eq 0 ]; then
        print_success "All critical tests passed!"
        echo ""
        echo "Your distributed Clawdbot system is working correctly."
    else
        print_error "Some tests failed."
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
    if ssh_check "${REMOTE_USER}@${REMOTE_HOST}"; then
        echo -e "${GREEN}✅${NC} SSH: Connected"
    else
        echo -e "${RED}❌${NC} SSH: Cannot connect"
    fi

    # Remote node
    local node_ok
    node_ok=$(ssh_cmd "${REMOTE_USER}@${REMOTE_HOST}" \
        'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && clawdbot node status 2>&1 | grep -qi "connected\|running" && echo yes || echo no' 2>/dev/null || echo "no")

    if [ "$node_ok" = "yes" ]; then
        echo -e "${GREEN}✅${NC} Remote Node: Connected"
    else
        echo -e "${RED}❌${NC} Remote Node: Not connected"
    fi

    echo ""
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Verifies connectivity of Clawdbot distributed system."
    echo ""
    echo "Options:"
    echo "  --quick, -q     Quick 3-point check (gateway, SSH, node)"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Required environment variables (set in .env):"
    echo "  GATEWAY_IP      IP address of gateway Mac"
    echo "  REMOTE_HOST     IP address of remote Mac"
    echo "  REMOTE_USER     Username on remote Mac"
    echo ""
    echo "Optional:"
    echo "  GATEWAY_PORT    Gateway port (default: 18789)"
    echo ""
    exit 0
}

# Main execution
main() {
    test_local_gateway
    test_network_connectivity
    test_ssh_connection
    test_remote_node_and_config
    test_optional_components
    print_summary
}

# Handle arguments
case "${1:-}" in
    --quick|-q)
        quick_test
        ;;
    --help|-h)
        show_help
        ;;
    *)
        main
        ;;
esac
