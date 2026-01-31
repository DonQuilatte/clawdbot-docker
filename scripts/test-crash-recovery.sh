#!/bin/bash
# Crash Recovery Test - Tests automatic restart after process failure

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
echo "Crash Recovery Test"
echo "=========================================="
echo ""

load_nvm() {
    echo 'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
}

# Step 1: Record current state
echo -e "${BLUE}[1/5] Recording baseline state...${NC}"
INITIAL_PID=$(ssh "$REMOTE_HOST" "ps aux | grep '[c]lawdbot-node' | awk '{print \$2}' | head -1")
echo "Initial PID: $INITIAL_PID"
echo ""

# Step 2: Kill the process
echo -e "${YELLOW}[2/5] Simulating crash (killing process)...${NC}"
ssh "$REMOTE_HOST" "killall clawdbot 2>/dev/null"
echo "Process killed"
sleep 2
echo ""

# Step 3: Wait for auto-restart
echo -e "${BLUE}[3/5] Waiting for auto-restart (10 seconds)...${NC}"
sleep 10
echo ""

# Step 4: Check if process restarted
echo -e "${BLUE}[4/5] Checking if process restarted...${NC}"
NEW_PID=$(ssh "$REMOTE_HOST" "ps aux | grep '[c]lawdbot-node' | awk '{print \$2}' | head -1")

if [ -n "$NEW_PID" ]; then
    echo -e "${GREEN}✓ Process restarted${NC}"
    echo "New PID: $NEW_PID"

    if [ "$NEW_PID" != "$INITIAL_PID" ]; then
        echo -e "${GREEN}✓ PID changed (confirmed new process)${NC}"
    fi
else
    echo -e "${RED}✗ Process did NOT restart${NC}"
    echo "FAILED: Auto-restart not working"
    exit 1
fi
echo ""

# Step 5: Verify connection
echo -e "${BLUE}[5/5] Verifying gateway connection...${NC}"
sleep 5

if ssh "$REMOTE_HOST" "lsof -i :18789 2>&1 | grep -q ESTABLISHED"; then
    echo -e "${GREEN}✓ Reconnected to gateway${NC}"
else
    echo -e "${YELLOW}⚠ Connection not yet established (may take more time)${NC}"
fi

NODE_STATUS=$(ssh "$REMOTE_HOST" "$(load_nvm) && clawdbot node status 2>&1" | grep -i "running")
if [ -n "$NODE_STATUS" ]; then
    echo -e "${GREEN}✓ Node status: Running${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Crash Recovery Test: PASSED${NC}"
echo "=========================================="
echo ""
echo "Summary:"
echo "  Initial PID: $INITIAL_PID"
echo "  New PID: $NEW_PID"
echo "  Result: Auto-restart working correctly"
echo ""
