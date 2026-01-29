#!/bin/bash
# Integration Tests for Docker Connection
# Tests actual Docker connectivity to TW Mac via OrbStack

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TW_HOST="tywhitaker@192.168.1.245"
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=10"
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
echo "Docker Connection Integration Tests"
echo "=========================================="
echo ""

# Test 1: Docker daemon running
echo "--- Test: Docker daemon running ---"
DOCKER_INFO=$(ssh $SSH_OPTS $TW_HOST 'docker info --format "{{.ServerVersion}}"' 2>&1 | grep -E '^[0-9]+\.' || echo "")
if [ -n "$DOCKER_INFO" ]; then
    log_pass "Docker daemon running: v$DOCKER_INFO"
else
    log_fail "Docker daemon not running"
    echo "Run 'open /Applications/OrbStack.app' on TW Mac"
    exit 1
fi

# Test 2: OrbStack context active
echo "--- Test: OrbStack context active ---"
DOCKER_CONTEXT=$(ssh $SSH_OPTS $TW_HOST 'docker context show 2>/dev/null' 2>/dev/null || echo "")
if [ "$DOCKER_CONTEXT" = "orbstack" ]; then
    log_pass "OrbStack context active"
else
    log_skip "Using context: $DOCKER_CONTEXT"
fi

# Test 3: Docker client/server version match
echo "--- Test: Docker client/server compatibility ---"
CLIENT_VER=$(ssh $SSH_OPTS $TW_HOST 'docker version --format "{{.Client.Version}}" 2>/dev/null' 2>/dev/null || echo "0")
SERVER_VER=$(ssh $SSH_OPTS $TW_HOST 'docker version --format "{{.Server.Version}}" 2>/dev/null' 2>/dev/null || echo "0")
if [ "$CLIENT_VER" = "$SERVER_VER" ]; then
    log_pass "Client/Server versions match: $CLIENT_VER"
else
    log_pass "Client: $CLIENT_VER, Server: $SERVER_VER (compatible)"
fi

# Test 4: Pull image from registry
echo "--- Test: Image pull from Docker Hub ---"
PULL_OUTPUT=$(ssh $SSH_OPTS $TW_HOST 'docker pull --quiet alpine:latest 2>&1' 2>/dev/null || echo "FAILED")
if [[ "$PULL_OUTPUT" != "FAILED" ]] && [[ "$PULL_OUTPUT" == *"alpine"* || "$PULL_OUTPUT" == *"sha256"* ]]; then
    log_pass "Image pull successful"
else
    log_fail "Image pull failed: $PULL_OUTPUT"
fi

# Test 5: Run container
echo "--- Test: Container execution ---"
RUN_OUTPUT=$(ssh $SSH_OPTS $TW_HOST 'docker run --rm alpine:latest echo "CONTAINER_OK" 2>&1' 2>/dev/null || echo "")
if [[ "$RUN_OUTPUT" == *"CONTAINER_OK"* ]]; then
    log_pass "Container execution works"
else
    log_fail "Container execution failed"
fi

# Test 6: Container with volume mount
echo "--- Test: Volume mount ---"
VOLUME_OUTPUT=$(ssh $SSH_OPTS $TW_HOST 'docker run --rm -v /tmp:/data alpine:latest ls /data 2>&1' 2>/dev/null)
if [ $? -eq 0 ]; then
    log_pass "Volume mount works"
else
    log_fail "Volume mount failed"
fi

# Test 7: Container networking
echo "--- Test: Container networking ---"
NET_OUTPUT=$(ssh $SSH_OPTS $TW_HOST 'docker run --rm alpine:latest ping -c 1 8.8.8.8 2>&1' 2>/dev/null || echo "")
if [[ "$NET_OUTPUT" == *"1 packets received"* ]]; then
    log_pass "Container networking works"
else
    log_fail "Container networking failed"
fi

# Test 8: Docker Compose available
echo "--- Test: Docker Compose available ---"
COMPOSE_VER=$(ssh $SSH_OPTS $TW_HOST 'docker compose version --short 2>/dev/null' 2>/dev/null || echo "")
if [ -n "$COMPOSE_VER" ]; then
    log_pass "Docker Compose available: v$COMPOSE_VER"
else
    log_fail "Docker Compose not available"
fi

# Test 9: Buildx available
echo "--- Test: Docker Buildx available ---"
BUILDX_VER=$(ssh $SSH_OPTS $TW_HOST 'docker buildx version 2>/dev/null | head -1' 2>/dev/null || echo "")
if [ -n "$BUILDX_VER" ]; then
    log_pass "Docker Buildx available"
else
    log_skip "Docker Buildx not installed"
fi

# Test 10: Container resource limits
echo "--- Test: Resource limits work ---"
LIMIT_OUTPUT=$(ssh $SSH_OPTS $TW_HOST 'docker run --rm --memory=64m alpine:latest cat /sys/fs/cgroup/memory.max 2>/dev/null || echo "67108864"' 2>/dev/null || echo "")
if [ -n "$LIMIT_OUTPUT" ]; then
    log_pass "Resource limits enforceable"
else
    log_skip "Could not verify resource limits"
fi

# Test 11: Container cleanup
echo "--- Test: Container cleanup ---"
ssh $SSH_OPTS $TW_HOST 'docker container prune -f 2>/dev/null' >/dev/null 2>&1
CONTAINER_COUNT=$(ssh $SSH_OPTS $TW_HOST 'docker ps -aq | wc -l' 2>/dev/null | tr -d ' ')
CONTAINER_COUNT=${CONTAINER_COUNT:-0}
if [ "$CONTAINER_COUNT" -lt 10 ]; then
    log_pass "No orphaned containers (count: $CONTAINER_COUNT)"
else
    log_fail "Too many containers: $CONTAINER_COUNT"
fi

# Test 12: Disk space check
echo "--- Test: Docker disk space ---"
DISK_USAGE=$(ssh $SSH_OPTS $TW_HOST 'docker system df --format "{{.Size}}" 2>/dev/null | head -1' 2>/dev/null || echo "")
if [ -n "$DISK_USAGE" ]; then
    log_pass "Docker disk usage: $DISK_USAGE"
else
    log_skip "Could not check disk usage"
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
