#!/bin/bash
# Unit Tests for tw-health-monitor.sh
# Tests health monitor script configuration and logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEALTH_MONITOR="$HOME/Development/Projects/clawdbot/infrastructure/tw-mac/tw-health-monitor.sh"
PASS=0
FAIL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASS++))
}

log_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((FAIL++))
}

echo "=========================================="
echo "Health Monitor Unit Tests"
echo "=========================================="
echo ""

# Test 1: Script exists
echo "--- Test: Script existence ---"
if [ -f "$HEALTH_MONITOR" ]; then
    log_pass "Health monitor script exists"
else
    log_fail "Health monitor script not found"
    exit 1
fi

# Test 2: Executable permissions
echo "--- Test: Permissions ---"
if [ -x "$HEALTH_MONITOR" ]; then
    log_pass "Script is executable"
else
    log_fail "Script is not executable"
fi

# Test 3: Shebang correct
echo "--- Test: Shebang ---"
if head -1 "$HEALTH_MONITOR" | grep -q "#!/bin/bash"; then
    log_pass "Bash shebang present"
else
    log_fail "Bash shebang missing"
fi

# Test 4: Required variables
echo "--- Test: Configuration variables ---"
REQUIRED_VARS=("LOG_FILE" "LOCK_FILE" "TW_HOST" "TW_TAILSCALE_IP" "TW_LAN_IP" "SSH_KEY" "SSH_OPTS")
for var in "${REQUIRED_VARS[@]}"; do
    if grep -q "${var}=" "$HEALTH_MONITOR"; then
        log_pass "Variable $var defined"
    else
        log_fail "Variable $var missing"
    fi
done

# Test 5: Lock file handling with flock (atomic locking)
echo "--- Test: Lock file handling ---"
if grep -q "flock" "$HEALTH_MONITOR" && grep -q 'trap.*rm.*LOCK_FILE' "$HEALTH_MONITOR"; then
    log_pass "Atomic flock with cleanup trap"
else
    log_fail "Atomic flock or cleanup missing"
fi

# Test 5b: SSH timeout configuration
echo "--- Test: SSH timeout ---"
if grep -q "SSH_TIMEOUT" "$HEALTH_MONITOR" && grep -q "timeout.*SSH_TIMEOUT" "$HEALTH_MONITOR"; then
    log_pass "SSH timeout configured"
else
    log_fail "SSH timeout missing"
fi

# Test 5c: ServerAliveInterval for keepalive
echo "--- Test: SSH keepalive ---"
if grep -q "ServerAliveInterval" "$HEALTH_MONITOR"; then
    log_pass "SSH keepalive configured"
else
    log_fail "SSH keepalive missing"
fi

# Test 6: Tailscale primary, LAN fallback
echo "--- Test: Connectivity logic ---"
if grep -q "TW_TAILSCALE_IP" "$HEALTH_MONITOR" && grep -q "TW_LAN_IP" "$HEALTH_MONITOR"; then
    log_pass "Dual connectivity (Tailscale + LAN) configured"
else
    log_fail "Connectivity fallback missing"
fi

# Test 7: MCP check function
echo "--- Test: MCP monitoring ---"
if grep -q "mcp" "$HEALTH_MONITOR" && grep -q "tmux" "$HEALTH_MONITOR"; then
    log_pass "MCP server monitoring included"
else
    log_fail "MCP monitoring missing"
fi

# Test 8: Logging function
echo "--- Test: Logging ---"
if grep -q "log()" "$HEALTH_MONITOR" || grep -q "log " "$HEALTH_MONITOR"; then
    log_pass "Logging function present"
else
    log_fail "Logging function missing"
fi

# Test 9: Main loop
echo "--- Test: Main loop ---"
if grep -q "while true" "$HEALTH_MONITOR" && grep -q "sleep" "$HEALTH_MONITOR"; then
    log_pass "Main monitoring loop present"
else
    log_fail "Main loop missing"
fi

# Test 10: PATH includes required directories
echo "--- Test: PATH configuration ---"
if grep -q 'PATH.*sbin' "$HEALTH_MONITOR"; then
    log_pass "PATH includes sbin directories"
else
    log_fail "PATH may be missing required directories"
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
