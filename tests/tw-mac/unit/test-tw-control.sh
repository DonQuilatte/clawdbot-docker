#!/bin/bash
# Unit Tests for tw-control.sh
# Tests individual functions and command parsing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TW_CONTROL="$HOME/bin/tw"
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
echo "TW Control Script Unit Tests"
echo "=========================================="
echo ""

# Test 1: Script exists and is executable
echo "--- Test: Script existence ---"
if [ -x "$TW_CONTROL" ]; then
    log_pass "tw-control.sh exists and is executable"
else
    log_fail "tw-control.sh not found or not executable at $TW_CONTROL"
fi

# Test 2: Help command works
echo "--- Test: Help command ---"
HELP_OUTPUT=$("$TW_CONTROL" help 2>&1 || true)
if echo "$HELP_OUTPUT" | grep -q "TW Mac Control"; then
    log_pass "Help command returns expected output"
else
    log_fail "Help command failed"
fi

# Test 3: Status command syntax
echo "--- Test: Status command parsing ---"
if "$TW_CONTROL" --help 2>&1 | grep -q "status" || "$TW_CONTROL" help 2>&1 | grep -q "status"; then
    log_pass "Status command documented"
else
    log_fail "Status command not documented"
fi

# Test 4: Variables defined correctly
echo "--- Test: Configuration variables ---"
if grep -q "TW_TAILSCALE_IP=" "$HOME/Development/Projects/dev-infra/infrastructure/tw-mac/tw-control.sh"; then
    log_pass "Tailscale IP variable defined"
else
    log_fail "Tailscale IP variable not found"
fi

if grep -q "TW_LAN_IP=" "$HOME/Development/Projects/dev-infra/infrastructure/tw-mac/tw-control.sh"; then
    log_pass "LAN IP variable defined"
else
    log_fail "LAN IP variable not found"
fi

# Test 5: SSH options configured
echo "--- Test: SSH options ---"
if grep -q "SSH_OPTS=" "$HOME/Development/Projects/dev-infra/infrastructure/tw-mac/tw-control.sh"; then
    log_pass "SSH options defined"
else
    log_fail "SSH options not found"
fi

if grep -q "BatchMode=yes" "$HOME/Development/Projects/dev-infra/infrastructure/tw-mac/tw-control.sh"; then
    log_pass "BatchMode enabled for non-interactive SSH"
else
    log_fail "BatchMode not enabled"
fi

# Test 6: All commands documented
echo "--- Test: Command documentation ---"
COMMANDS=("status" "connect" "disconnect" "start-mcp" "stop-mcp" "shell" "tmux" "run")
for cmd in "${COMMANDS[@]}"; do
    # Check for command in case statement (cmd) pattern) or in echo statements
    if grep -qE "${cmd}\)|\"${cmd}\"|'${cmd}'" "$HOME/Development/Projects/dev-infra/infrastructure/tw-mac/tw-control.sh"; then
        log_pass "Command '$cmd' implemented"
    else
        log_fail "Command '$cmd' not found"
    fi
done

# Test 7: Color codes defined
echo "--- Test: Output formatting ---"
if grep -q "GREEN=" "$HOME/Development/Projects/dev-infra/infrastructure/tw-mac/tw-control.sh" && \
   grep -q "RED=" "$HOME/Development/Projects/dev-infra/infrastructure/tw-mac/tw-control.sh"; then
    log_pass "Color codes defined for output"
else
    log_fail "Color codes missing"
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
