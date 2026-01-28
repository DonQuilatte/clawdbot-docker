#!/usr/bin/env bash
# Gateway Docker Configuration Tests
# Validates docker-compose.secure.yml settings to prevent deployment issues

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/config/docker-compose.secure.yml"
ENV_FILE="$PROJECT_ROOT/.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "=== Gateway Docker Configuration Tests ==="
echo ""

# Test 1: Check compose file exists
echo "--- File Existence ---"
if [[ -f "$COMPOSE_FILE" ]]; then
    pass "docker-compose.secure.yml exists"
else
    fail "docker-compose.secure.yml not found at $COMPOSE_FILE"
    exit 1
fi

# Test 2: Validate bind option
echo ""
echo "--- Bind Configuration ---"
BIND_VALUE=$(grep -A1 '"--bind"' "$COMPOSE_FILE" | tail -1 | tr -d ' ",' || true)
if [[ "$BIND_VALUE" == "lan" || "$BIND_VALUE" == "loopback" || "$BIND_VALUE" == "auto" ]]; then
    pass "Bind mode is valid: $BIND_VALUE"
else
    fail "Invalid bind mode: '$BIND_VALUE' (must be lan, loopback, or auto)"
fi

# Test 3: Check bind mode for Docker compatibility
if [[ "$BIND_VALUE" == "lan" ]]; then
    pass "Bind mode 'lan' allows Docker port forwarding"
elif [[ "$BIND_VALUE" == "loopback" ]]; then
    warn "Bind mode 'loopback' may not work with Docker port forwarding"
fi

# Test 4: Validate tmpfs UID/GID for macOS
echo ""
echo "--- tmpfs Configuration ---"
TMPFS_LINE=$(grep '/tmp:mode=' "$COMPOSE_FILE" | head -1 || true)
if [[ -n "$TMPFS_LINE" ]]; then
    if echo "$TMPFS_LINE" | grep -q 'uid=501'; then
        pass "tmpfs uid=501 (macOS compatible)"
    elif echo "$TMPFS_LINE" | grep -q 'uid=1000'; then
        fail "tmpfs uid=1000 - will cause permission errors on macOS (should be 501)"
    elif echo "$TMPFS_LINE" | grep -q '\${'; then
        fail "tmpfs uses variables - Docker Compose doesn't support variable interpolation in tmpfs"
    else
        warn "tmpfs uid not explicitly set"
    fi

    if echo "$TMPFS_LINE" | grep -q 'gid=20'; then
        pass "tmpfs gid=20 (macOS compatible)"
    elif echo "$TMPFS_LINE" | grep -q 'gid=1000'; then
        fail "tmpfs gid=1000 - will cause permission errors on macOS (should be 20)"
    fi
else
    warn "No tmpfs configuration found"
fi

# Test 5: Check volume configuration
echo ""
echo "--- Volume Configuration ---"
if grep -q '\${HOME}/.clawdbot' "$COMPOSE_FILE"; then
    pass "Using host directory mount for config (correct ownership)"
elif grep -q 'clawdbot-config:/home/node/.clawdbot' "$COMPOSE_FILE"; then
    warn "Using named volume - may have ownership issues on macOS (uid mismatch)"
fi

# Test 6: Check for gateway token configuration
echo ""
echo "--- Token Configuration ---"
if grep -q 'CLAWDBOT_GATEWAY_TOKEN' "$COMPOSE_FILE"; then
    pass "Gateway token configured in compose file"
else
    fail "CLAWDBOT_GATEWAY_TOKEN not found in compose file"
fi

if [[ -f "$ENV_FILE" ]] && grep -q 'CLAWDBOT_GATEWAY_TOKEN=' "$ENV_FILE"; then
    TOKEN_VALUE=$(grep 'CLAWDBOT_GATEWAY_TOKEN=' "$ENV_FILE" | cut -d= -f2)
    if [[ -n "$TOKEN_VALUE" && "$TOKEN_VALUE" != "" ]]; then
        pass "CLAWDBOT_GATEWAY_TOKEN set in .env (value: ${TOKEN_VALUE:0:10}...)"
    else
        fail "CLAWDBOT_GATEWAY_TOKEN is empty in .env"
    fi
else
    warn ".env file missing or CLAWDBOT_GATEWAY_TOKEN not set"
fi

# Test 7: Check user configuration
echo ""
echo "--- User Configuration ---"
USER_LINE=$(grep -E '^\s+user:' "$COMPOSE_FILE" | head -1 || true)
if echo "$USER_LINE" | grep -q '501'; then
    pass "Container user includes uid 501 (macOS)"
elif echo "$USER_LINE" | grep -q 'USER_UID'; then
    pass "Container user uses USER_UID variable"
else
    warn "Container user may not match macOS uid"
fi

# Test 8: Runtime tests (if container is running)
echo ""
echo "--- Runtime Tests ---"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'clawdbot-gateway'; then
    CONTAINER_NAME=$(docker ps --format '{{.Names}}' | grep 'clawdbot-gateway' | head -1)
    pass "Gateway container is running: $CONTAINER_NAME"

    # Test HTTP endpoint
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:18789/ 2>/dev/null | grep -q '200'; then
        pass "HTTP endpoint responds (200)"
    else
        fail "HTTP endpoint not responding"
    fi

    # Test gateway bind address inside container
    BIND_ADDR=$(docker logs "$CONTAINER_NAME" 2>&1 | grep "listening on" | tail -1 | grep -o 'ws://[^[:space:]]*' || true)
    if echo "$BIND_ADDR" | grep -q '0.0.0.0'; then
        pass "Gateway bound to 0.0.0.0 (Docker compatible)"
    elif echo "$BIND_ADDR" | grep -q '127.0.0.1'; then
        fail "Gateway bound to 127.0.0.1 - Docker port forwarding won't work"
    fi

    # Test for permission errors
    if docker logs "$CONTAINER_NAME" 2>&1 | grep -q 'EACCES: permission denied'; then
        fail "Permission errors in container logs"
    else
        pass "No permission errors in logs"
    fi

    # Test for WebSocket connections
    WS_CONNECTED=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -c 'webchat connected' || true)
    if [[ "$WS_CONNECTED" -gt 0 ]]; then
        pass "WebSocket connections established ($WS_CONNECTED connections)"
    else
        warn "No WebSocket connections in logs"
    fi
else
    warn "Gateway container not running - skipping runtime tests"
fi

# Summary
echo ""
echo "=== Summary ==="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo ""
    echo "See docs/GATEWAY-DOCKER-FIXES.md for fix instructions"
    exit 1
fi

exit 0
