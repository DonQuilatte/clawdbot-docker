#!/bin/bash
# Integration Tests for SSH Connection
# Tests actual SSH connectivity to TW Mac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TW_HOST="tw"
TW_TAILSCALE_IP="100.81.110.81"
TW_LAN_IP="192.168.1.245"
SSH_KEY="$HOME/.ssh/id_ed25519_clawdbot"
SSH_OPTS="-o BatchMode=yes -o IdentitiesOnly=yes -i $SSH_KEY -o ConnectTimeout=10"
PASS=0
FAIL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASS++))
}

log_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((FAIL++))
}

log_skip() {
    echo -e "${YELLOW}○ SKIP${NC}: $1"
}

echo "=========================================="
echo "SSH Connection Integration Tests"
echo "=========================================="
echo ""

# Test 1: Tailscale ping
echo "--- Test: Tailscale connectivity ---"
if ping -c 1 -W 3 $TW_TAILSCALE_IP >/dev/null 2>&1; then
    log_pass "Tailscale IP reachable ($TW_TAILSCALE_IP)"
    TAILSCALE_OK=true
else
    log_fail "Tailscale IP unreachable"
    TAILSCALE_OK=false
fi

# Test 2: LAN ping
echo "--- Test: LAN connectivity ---"
if ping -c 1 -W 3 $TW_LAN_IP >/dev/null 2>&1; then
    log_pass "LAN IP reachable ($TW_LAN_IP)"
    LAN_OK=true
else
    log_fail "LAN IP unreachable"
    LAN_OK=false
fi

# Test 3: SSH key exists
echo "--- Test: SSH key file ---"
if [ -f "$SSH_KEY" ]; then
    log_pass "SSH key file exists"
else
    log_fail "SSH key file missing: $SSH_KEY"
    exit 1
fi

# Test 4: SSH key permissions
echo "--- Test: SSH key permissions ---"
KEY_PERMS=$(stat -f '%A' "$SSH_KEY" 2>/dev/null || stat -c '%a' "$SSH_KEY" 2>/dev/null)
if [ "$KEY_PERMS" = "600" ]; then
    log_pass "SSH key has correct permissions (600)"
else
    log_fail "SSH key has incorrect permissions: $KEY_PERMS (should be 600)"
fi

# Test 5: SSH connection via alias
echo "--- Test: SSH connection via alias ---"
if SSH_AUTH_SOCK="" ssh $SSH_OPTS -o ConnectTimeout=5 $TW_HOST 'exit 0' 2>/dev/null; then
    log_pass "SSH connection via 'tw' alias successful"
else
    log_fail "SSH connection via 'tw' alias failed"
fi

# Test 6: SSH command execution
echo "--- Test: SSH command execution ---"
REMOTE_HOSTNAME=$(SSH_AUTH_SOCK="" ssh $SSH_OPTS $TW_HOST 'hostname' 2>/dev/null || echo "FAILED")
if [ "$REMOTE_HOSTNAME" != "FAILED" ] && [ -n "$REMOTE_HOSTNAME" ]; then
    log_pass "Remote command execution works (hostname: $REMOTE_HOSTNAME)"
else
    log_fail "Remote command execution failed"
fi

# Test 7: SSH persistent socket
echo "--- Test: SSH persistent socket ---"
SOCKET_FILE="$HOME/.ssh/sockets/tywhitaker@$TW_TAILSCALE_IP-22"
if [ -S "$SOCKET_FILE" ]; then
    log_pass "Persistent socket exists"
else
    log_skip "Persistent socket not established (may need 'tw connect')"
fi

# Test 8: Remote user verification
echo "--- Test: Remote user ---"
REMOTE_USER=$(SSH_AUTH_SOCK="" ssh $SSH_OPTS $TW_HOST 'whoami' 2>/dev/null || echo "FAILED")
if [ "$REMOTE_USER" = "tywhitaker" ]; then
    log_pass "Connected as correct user: $REMOTE_USER"
else
    log_fail "Wrong user: $REMOTE_USER (expected tywhitaker)"
fi

# Test 9: Remote home directory
echo "--- Test: Remote home directory ---"
REMOTE_HOME=$(SSH_AUTH_SOCK="" ssh $SSH_OPTS $TW_HOST 'echo $HOME' 2>/dev/null || echo "FAILED")
if [ "$REMOTE_HOME" = "/Users/tywhitaker" ]; then
    log_pass "Correct home directory: $REMOTE_HOME"
else
    log_fail "Unexpected home directory: $REMOTE_HOME"
fi

# Test 10: tmux available
echo "--- Test: tmux available ---"
if SSH_AUTH_SOCK="" ssh $SSH_OPTS $TW_HOST 'which tmux' >/dev/null 2>&1; then
    log_pass "tmux is installed on TW Mac"
else
    log_fail "tmux not found on TW Mac"
fi

# Test 11: Node.js available
echo "--- Test: Node.js available ---"
NODE_VERSION=$(SSH_AUTH_SOCK="" ssh $SSH_OPTS $TW_HOST 'node --version' 2>/dev/null || echo "FAILED")
if [ "$NODE_VERSION" != "FAILED" ]; then
    log_pass "Node.js installed: $NODE_VERSION"
else
    log_fail "Node.js not found"
fi

# Test 12: Claude CLI available
echo "--- Test: Claude CLI ---"
if SSH_AUTH_SOCK="" ssh $SSH_OPTS $TW_HOST 'which claude' >/dev/null 2>&1; then
    log_pass "Claude CLI is installed"
else
    log_fail "Claude CLI not found"
fi

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo ""

if [ $FAIL -gt 0 ]; then
    exit 1
fi
exit 0
