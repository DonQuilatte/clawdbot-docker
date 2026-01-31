#!/bin/bash
# Stress/Load Test - Tests system under concurrent command load

set -euo pipefail

# Source common library for colors and utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    source "$SCRIPT_DIR/lib/common.sh"
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
fi

REMOTE_HOST="tywhitaker@192.168.1.245"

echo "=========================================="
echo "Stress/Load Test"
echo "=========================================="
echo ""

load_nvm() {
    echo 'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
}

# Test parameters
NUM_CONCURRENT=10
NUM_ITERATIONS=5

echo "Test parameters:"
echo "  Concurrent connections: $NUM_CONCURRENT"
echo "  Iterations per connection: $NUM_ITERATIONS"
echo "  Total commands: $((NUM_CONCURRENT * NUM_ITERATIONS))"
echo ""

# Baseline measurements
echo -e "${BLUE}[1/4] Recording baseline metrics...${NC}"
CPU_BEFORE=$(ssh "$REMOTE_HOST" "top -l 1 | grep 'CPU usage' | awk '{print \$3}' | sed 's/%//'")
MEM_BEFORE=$(ssh "$REMOTE_HOST" "top -l 1 | grep PhysMem | awk '{print \$2}' | sed 's/M//'")
echo "CPU before: ${CPU_BEFORE}%"
echo "Memory before: ${MEM_BEFORE}M"
echo ""

# Run stress test
echo -e "${BLUE}[2/4] Running concurrent command load...${NC}"
START_TIME=$(date +%s)

for i in $(seq 1 $NUM_CONCURRENT); do
    (
        for j in $(seq 1 $NUM_ITERATIONS); do
            ssh "$REMOTE_HOST" "echo 'test-$i-$j'" > /dev/null 2>&1
        done
    ) &
done

# Wait for all background jobs to complete
wait

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo -e "${GREEN}✓ Completed ${NUM_CONCURRENT}x${NUM_ITERATIONS} commands in ${DURATION}s${NC}"
echo ""

# Post-test measurements
echo -e "${BLUE}[3/4] Recording post-test metrics...${NC}"
sleep 5 # Let system stabilize
CPU_AFTER=$(ssh "$REMOTE_HOST" "top -l 1 | grep 'CPU usage' | awk '{print \$3}' | sed 's/%//'")
MEM_AFTER=$(ssh "$REMOTE_HOST" "top -l 1 | grep PhysMem | awk '{print \$2}' | sed 's/M//'")
echo "CPU after: ${CPU_AFTER}%"
echo "Memory after: ${MEM_AFTER}M"
echo ""

# Verify system health
echo -e "${BLUE}[4/4] Verifying system health...${NC}"

# Check if node is still running
if ssh "$REMOTE_HOST" "ps aux | grep -q '[c]lawdbot-node'"; then
    echo -e "${GREEN}✓ Node process still running${NC}"
else
    echo -e "${RED}✗ Node process crashed${NC}"
    exit 1
fi

# Check if connection is still active
if ssh "$REMOTE_HOST" "lsof -i :18789 2>&1 | grep -q ESTABLISHED"; then
    echo -e "${GREEN}✓ Gateway connection still active${NC}"
else
    echo -e "${RED}✗ Gateway connection lost${NC}"
    exit 1
fi

# Check response time
RESPONSE_START=$(date +%s%3N)
ssh "$REMOTE_HOST" "echo 'ping'" > /dev/null 2>&1
RESPONSE_END=$(date +%s%3N)
RESPONSE_TIME=$((RESPONSE_END - RESPONSE_START))
echo -e "${GREEN}✓ Response time: ${RESPONSE_TIME}ms${NC}"

echo ""
echo "=========================================="
echo -e "${GREEN}Stress Test: PASSED${NC}"
echo "=========================================="
echo ""
echo "Performance Summary:"
echo "  Commands executed: $((NUM_CONCURRENT * NUM_ITERATIONS))"
echo "  Total duration: ${DURATION}s"
echo "  Avg time/command: $((DURATION * 1000 / (NUM_CONCURRENT * NUM_ITERATIONS)))ms"
echo ""
echo "Resource Usage:"
echo "  CPU: ${CPU_BEFORE}% → ${CPU_AFTER}%"
echo "  Memory: ${MEM_BEFORE}M → ${MEM_AFTER}M"
echo ""
echo "System Status: Healthy under load"
echo ""
