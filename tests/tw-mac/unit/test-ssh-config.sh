#!/bin/bash
# Unit Tests for SSH Configuration
# Tests SSH config entries for TW Mac connectivity

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_CONFIG="$HOME/.ssh/config"
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
echo "SSH Configuration Unit Tests"
echo "=========================================="
echo ""

# Test 1: SSH config file exists
echo "--- Test: Config file existence ---"
if [ -f "$SSH_CONFIG" ]; then
    log_pass "SSH config file exists"
else
    log_fail "SSH config file not found"
    exit 1
fi

# Test 2: TW Mac host entry exists
echo "--- Test: TW Mac host entry ---"
if grep -q "Host.*tw" "$SSH_CONFIG"; then
    log_pass "TW Mac host entry found"
else
    log_fail "TW Mac host entry not found"
fi

# Test 3: Tailscale IP configured
echo "--- Test: Tailscale IP ---"
if grep -q "100.81.110.81" "$SSH_CONFIG"; then
    log_pass "Tailscale IP (100.81.110.81) configured"
else
    log_fail "Tailscale IP not found in config"
fi

# Test 4: LAN fallback configured
echo "--- Test: LAN fallback entry ---"
if grep -q "192.168.1.245" "$SSH_CONFIG"; then
    log_pass "LAN fallback IP configured"
else
    log_fail "LAN fallback IP not found"
fi

# Test 5: Correct user configured
echo "--- Test: User configuration ---"
if grep -A5 "Host.*tw" "$SSH_CONFIG" | grep -q "User tywhitaker"; then
    log_pass "User 'tywhitaker' configured"
else
    log_fail "User not configured correctly"
fi

# Test 6: SSH key specified
echo "--- Test: SSH key ---"
if grep -q "id_ed25519_clawdbot" "$SSH_CONFIG"; then
    log_pass "SSH key (id_ed25519_clawdbot) specified"
else
    log_fail "SSH key not specified"
fi

# Test 7: ControlMaster enabled
echo "--- Test: ControlMaster ---"
if grep -q "ControlMaster" "$SSH_CONFIG"; then
    log_pass "ControlMaster configured"
else
    log_fail "ControlMaster not configured"
fi

# Test 8: ControlPath configured
echo "--- Test: ControlPath ---"
if grep -q "ControlPath" "$SSH_CONFIG"; then
    log_pass "ControlPath configured"
else
    log_fail "ControlPath not configured"
fi

# Test 9: ControlPersist enabled
echo "--- Test: ControlPersist ---"
if grep -q "ControlPersist" "$SSH_CONFIG"; then
    log_pass "ControlPersist configured"
else
    log_fail "ControlPersist not configured"
fi

# Test 10: Keepalive settings
echo "--- Test: Keepalive settings ---"
if grep -q "ServerAliveInterval" "$SSH_CONFIG"; then
    log_pass "ServerAliveInterval configured"
else
    log_fail "ServerAliveInterval not configured"
fi

# Test 11: ForwardAgent configured
echo "--- Test: ForwardAgent ---"
if grep -q "ForwardAgent" "$SSH_CONFIG"; then
    log_pass "ForwardAgent configured"
else
    log_fail "ForwardAgent not configured"
fi

# Test 12: Compression enabled
echo "--- Test: Compression ---"
if grep -q "Compression yes" "$SSH_CONFIG"; then
    log_pass "SSH compression enabled"
else
    log_fail "SSH compression not enabled"
fi

# Test 13: Sockets directory exists
echo "--- Test: Sockets directory ---"
if [ -d "$HOME/.ssh/sockets" ]; then
    log_pass "SSH sockets directory exists"
else
    log_fail "SSH sockets directory missing"
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
