#!/bin/bash
# Integration Tests for Tailscale VPN
# Tests Tailscale connectivity and configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TW_TAILSCALE_IP="100.81.110.81"
CONTROLLER_TAILSCALE_IP="100.73.138.46"
PASS=0
FAIL=0

# Find Tailscale CLI (may be in app bundle on macOS)
if command -v tailscale >/dev/null 2>&1; then
    TAILSCALE_CLI="tailscale"
elif [ -x "/Applications/Tailscale.app/Contents/MacOS/Tailscale" ]; then
    TAILSCALE_CLI="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
else
    TAILSCALE_CLI=""
fi

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
echo "Tailscale VPN Integration Tests"
echo "=========================================="
echo ""

# Test 1: Tailscale installed
echo "--- Test: Tailscale installation ---"
if [ -n "$TAILSCALE_CLI" ]; then
    log_pass "Tailscale CLI found at: $TAILSCALE_CLI"
else
    log_fail "Tailscale CLI not found"
    # Continue with ping-based tests only
fi

# Test 2: Tailscale running
echo "--- Test: Tailscale daemon ---"
if pgrep -f "tailscaled" >/dev/null 2>&1 || $TAILSCALE_CLI status >/dev/null 2>&1; then
    log_pass "Tailscale daemon running"
else
    log_fail "Tailscale daemon not running"
fi

# Test 3: Tailscale connected
echo "--- Test: Tailscale connection status ---"
TS_STATUS=$($TAILSCALE_CLI status 2>/dev/null | head -1 || echo "error")
if echo "$TS_STATUS" | grep -qv "error\|stopped\|disconnected"; then
    log_pass "Tailscale connected"
else
    log_fail "Tailscale not connected"
fi

# Test 4: Controller has Tailscale IP
echo "--- Test: Controller Tailscale IP ---"
LOCAL_TS_IP=$($TAILSCALE_CLI ip -4 2>/dev/null || echo "")
if [ -n "$LOCAL_TS_IP" ]; then
    log_pass "Controller has Tailscale IP: $LOCAL_TS_IP"
else
    log_fail "Controller has no Tailscale IP"
fi

# Test 5: TW Mac visible in Tailscale
echo "--- Test: TW Mac in Tailscale network ---"
if $TAILSCALE_CLI status 2>/dev/null | grep -q "$TW_TAILSCALE_IP\|tw"; then
    log_pass "TW Mac visible in Tailscale network"
else
    log_fail "TW Mac not visible in Tailscale network"
fi

# Test 6: Ping TW Mac via Tailscale
echo "--- Test: Ping TW Mac via Tailscale ---"
if ping -c 1 -W 3 $TW_TAILSCALE_IP >/dev/null 2>&1; then
    log_pass "TW Mac reachable via Tailscale ($TW_TAILSCALE_IP)"
else
    log_fail "TW Mac unreachable via Tailscale"
fi

# Test 7: SSH port open via Tailscale
echo "--- Test: SSH port via Tailscale ---"
if nc -z -w 3 $TW_TAILSCALE_IP 22 2>/dev/null; then
    log_pass "SSH port 22 open via Tailscale"
else
    log_fail "SSH port 22 not reachable via Tailscale"
fi

# Test 8: Latency check
echo "--- Test: Tailscale latency ---"
LATENCY=$(ping -c 3 -W 3 $TW_TAILSCALE_IP 2>/dev/null | tail -1 | awk -F'/' '{print $5}' || echo "999")
if [ -n "$LATENCY" ] && [ "$(echo "$LATENCY < 100" | bc 2>/dev/null || echo 0)" = "1" ]; then
    log_pass "Latency acceptable: ${LATENCY}ms"
elif [ -n "$LATENCY" ]; then
    log_pass "Latency: ${LATENCY}ms (may be high)"
else
    log_fail "Could not measure latency"
fi

# Test 9: DNS resolution
echo "--- Test: Tailscale DNS ---"
if $TAILSCALE_CLI status 2>/dev/null | grep -q "tw\s"; then
    log_pass "TW Mac has Tailscale hostname"
else
    log_skip "Tailscale hostname not set"
fi

# Test 10: Tailscale version
echo "--- Test: Tailscale version ---"
TS_VERSION=$($TAILSCALE_CLI version 2>/dev/null | head -1 || echo "unknown")
if [ "$TS_VERSION" != "unknown" ]; then
    log_pass "Tailscale version: $TS_VERSION"
else
    log_fail "Could not determine Tailscale version"
fi

# Test 11: Both peers online
echo "--- Test: Peer status ---"
PEER_STATUS=$($TAILSCALE_CLI status 2>/dev/null | grep -E "$TW_TAILSCALE_IP|tw" | head -1)
if echo "$PEER_STATUS" | grep -qi "active\|online\|direct"; then
    log_pass "TW Mac peer is active"
else
    log_skip "Could not verify peer status"
fi

# Test 12: Direct connection (not relayed)
echo "--- Test: Direct connection ---"
if $TAILSCALE_CLI status 2>/dev/null | grep -E "$TW_TAILSCALE_IP|tw" | grep -q "direct"; then
    log_pass "Direct connection (not relayed)"
else
    log_skip "Connection may be relayed through DERP"
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
