#!/bin/bash
# System tests for distributed Clawdbot connectivity

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$(dirname "$SCRIPT_DIR")")}"

# Source test utilities
source "$SCRIPT_DIR/../lib/test-utils.sh"

# Load environment and configuration
source "$PROJECT_ROOT/scripts/lib/common.sh"
load_env

# Configuration from environment (with defaults for backwards compatibility)
MAIN_MAC_IP="${GATEWAY_IP:-${MAIN_MAC_IP:-192.168.1.230}}"
REMOTE_MAC_IP="${REMOTE_HOST:-${REMOTE_MAC_IP:-192.168.1.245}}"
REMOTE_USER="${REMOTE_USER:-tywhitaker}"
GATEWAY_PORT="${GATEWAY_PORT:-18789}"

echo "Testing distributed system connectivity..."

# Test: Main Mac gateway is reachable
print_test "Main Mac gateway is reachable on port $GATEWAY_PORT"
if curl -s --connect-timeout 5 "http://$MAIN_MAC_IP:$GATEWAY_PORT" &>/dev/null; then
    print_pass "Gateway is reachable"
else
    print_fail "Gateway is not reachable"
fi

# Test: Gateway health endpoint responds
print_test "Gateway health endpoint responds"
HEALTH_RESPONSE=$(curl -s --connect-timeout 5 "http://localhost:$GATEWAY_PORT/health" 2>/dev/null || echo "")
if [[ -n "$HEALTH_RESPONSE" ]]; then
    print_pass "Health endpoint responds"
else
    print_fail "Health endpoint not responding"
fi

# Test: SSH to remote Mac works
print_test "SSH to remote Mac ($REMOTE_USER@$REMOTE_MAC_IP)"
if ssh -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_USER@$REMOTE_MAC_IP" "echo ok" &>/dev/null; then
    print_pass "SSH connection works"
else
    print_fail "SSH connection failed"
fi

# Test: Remote Mac can reach gateway
print_test "Remote Mac can reach gateway"
REMOTE_HEALTH=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_USER@$REMOTE_MAC_IP" \
    "curl -s --connect-timeout 5 -o /dev/null -w '%{http_code}' http://$MAIN_MAC_IP:$GATEWAY_PORT/health" 2>/dev/null || echo "000")
if [[ "$REMOTE_HEALTH" == "200" ]]; then
    print_pass "Remote Mac can reach gateway (HTTP 200)"
else
    print_fail "Remote Mac cannot reach gateway (HTTP $REMOTE_HEALTH)"
fi

# Test: Docker is available on remote Mac (primary deployment method)
print_test "Docker is available on remote Mac"
DOCKER_VERSION=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_USER@$REMOTE_MAC_IP" \
    'docker version --format "{{.Server.Version}}"' 2>&1 | grep -E '^[0-9]+\.' || echo "")
if [[ -n "$DOCKER_VERSION" ]]; then
    print_pass "Docker available: v$DOCKER_VERSION"
else
    print_fail "Docker not available on remote Mac"
fi

# Test: Docker can run containers on remote Mac
print_test "Docker containers work on remote Mac"
DOCKER_TEST=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$REMOTE_USER@$REMOTE_MAC_IP" \
    'docker run --rm alpine:latest echo "DOCKER_OK" 2>&1' 2>&1 || echo "")
if [[ "$DOCKER_TEST" == *"DOCKER_OK"* ]]; then
    print_pass "Docker containers work"
else
    print_fail "Docker containers not working: $DOCKER_TEST"
fi

# Test: Clawdbot node service (optional - legacy deployment)
print_test "Clawdbot node service (legacy, optional)"
NODE_STATUS=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_USER@$REMOTE_MAC_IP" \
    'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && clawdbot node status 2>/dev/null | grep -o "running"' 2>/dev/null || echo "")
if [[ "$NODE_STATUS" == "running" ]]; then
    print_pass "Clawdbot node is running"
else
    print_skip "Clawdbot node not running (using Docker instead)"
fi

# Test: Remote node has clawdbot CLI installed
print_test "Clawdbot CLI is installed on remote Mac"
CLAWDBOT_VERSION=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_USER@$REMOTE_MAC_IP" \
    'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && clawdbot --version 2>/dev/null' || echo "")
if [[ -n "$CLAWDBOT_VERSION" ]]; then
    print_pass "Clawdbot installed: $CLAWDBOT_VERSION"
else
    print_skip "Clawdbot CLI not installed (not required for Docker mode)"
fi

# Test: Remote node config exists (optional)
print_test "Remote node config file (optional)"
CONFIG_EXISTS=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_USER@$REMOTE_MAC_IP" \
    'test -f ~/.clawdbot/clawdbot.json && echo "yes"' 2>/dev/null || echo "no")
if [[ "$CONFIG_EXISTS" == "yes" ]]; then
    print_pass "Config file exists"
else
    print_skip "Config file not present (using Docker mode)"
fi

# Test: LaunchAgent (optional - legacy deployment)
print_test "LaunchAgent auto-restart (legacy, optional)"
LAUNCHAGENT_EXISTS=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_USER@$REMOTE_MAC_IP" \
    'test -f ~/Library/LaunchAgents/com.clawdbot.node.plist && echo "yes"' 2>/dev/null || echo "no")
if [[ "$LAUNCHAGENT_EXISTS" == "yes" ]]; then
    print_pass "LaunchAgent is installed"
else
    print_skip "LaunchAgent not installed (using Docker mode)"
fi

# Test: OrbStack is running on remote Mac
print_test "OrbStack is running on remote Mac"
ORBSTACK_RUNNING=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$REMOTE_USER@$REMOTE_MAC_IP" \
    'pgrep -l OrbStack 2>/dev/null | grep -q OrbStack && echo "yes" || echo "no"' 2>&1 | grep -o "yes\|no" | head -1)
if [[ "$ORBSTACK_RUNNING" == "yes" ]]; then
    print_pass "OrbStack is running"
else
    print_fail "OrbStack is not running"
fi

echo ""
echo "Connectivity tests complete."
