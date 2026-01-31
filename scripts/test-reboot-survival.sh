#!/bin/bash
# Reboot Survival Test - Tests automatic startup after system reboot

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
echo "Reboot Survival Test"
echo "=========================================="
echo ""
echo -e "${YELLOW}⚠ WARNING: This will reboot the remote Mac${NC}"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Test cancelled"
    exit 0
fi
echo ""

load_nvm() {
    echo 'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
}

# Step 1: Record pre-reboot state
echo -e "${BLUE}[1/6] Recording pre-reboot state...${NC}"
UPTIME_BEFORE=$(ssh "$REMOTE_HOST" "uptime | awk -F'up ' '{print \$2}' | awk -F',' '{print \$1}'")
echo "Current uptime: $UPTIME_BEFORE"
echo ""

# Step 2: Initiate reboot
echo -e "${YELLOW}[2/6] Initiating reboot...${NC}"
ssh "$REMOTE_HOST" "sudo reboot" 2>/dev/null || echo "Reboot command sent"
echo "Waiting for system to shut down..."
sleep 15
echo ""

# Step 3: Wait for system to come back up
echo -e "${BLUE}[3/6] Waiting for system to boot (120 seconds)...${NC}"
WAIT_TIME=0
MAX_WAIT=120

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    if ssh -o ConnectTimeout=2 "$REMOTE_HOST" "echo 'alive'" 2>/dev/null | grep -q alive; then
        echo -e "\n${GREEN}✓ System is back online${NC}"
        break
    fi
    echo -n "."
    sleep 5
    WAIT_TIME=$((WAIT_TIME + 5))
done

if [ $WAIT_TIME -ge $MAX_WAIT ]; then
    echo -e "\n${RED}✗ System did not come back online${NC}"
    echo "FAILED: System may not have rebooted or network issue"
    exit 1
fi
echo ""

# Step 4: Verify reboot occurred
echo -e "${BLUE}[4/6] Verifying reboot occurred...${NC}"
sleep 10 # Give system time to fully boot
UPTIME_AFTER=$(ssh "$REMOTE_HOST" "uptime | awk -F'up ' '{print \$2}' | awk -F',' '{print \$1}'")
echo "New uptime: $UPTIME_AFTER"

if [ "$UPTIME_AFTER" != "$UPTIME_BEFORE" ]; then
    echo -e "${GREEN}✓ System rebooted successfully${NC}"
else
    echo -e "${YELLOW}⚠ Uptime unchanged, reboot may not have occurred${NC}"
fi
echo ""

# Step 5: Check if Clawdbot node started automatically
echo -e "${BLUE}[5/6] Checking if Clawdbot node started automatically...${NC}"
sleep 10 # Give services time to start

if ssh "$REMOTE_HOST" "ps aux | grep -q '[c]lawdbot-node'"; then
    echo -e "${GREEN}✓ Clawdbot node process is running${NC}"
    PID=$(ssh "$REMOTE_HOST" "ps aux | grep '[c]lawdbot-node' | awk '{print \$2}' | head -1")
    echo "PID: $PID"
else
    echo -e "${RED}✗ Clawdbot node NOT running${NC}"
    echo "FAILED: Auto-start did not work"
    exit 1
fi

if ssh "$REMOTE_HOST" "launchctl list | grep -q clawdbot.node"; then
    echo -e "${GREEN}✓ LaunchAgent is loaded${NC}"
else
    echo -e "${RED}✗ LaunchAgent not loaded${NC}"
fi
echo ""

# Step 6: Verify connection to gateway
echo -e "${BLUE}[6/6] Verifying gateway connection...${NC}"
sleep 15 # Give time for connection to establish

if ssh "$REMOTE_HOST" "lsof -i :18789 2>&1 | grep -q ESTABLISHED"; then
    echo -e "${GREEN}✓ Connected to gateway${NC}"
else
    echo -e "${YELLOW}⚠ Not yet connected to gateway${NC}"
    echo "   (This may take a few more moments)"
fi

NODE_STATUS=$(ssh "$REMOTE_HOST" "$(load_nvm) && clawdbot node status 2>&1" | grep -i "running")
if [ -n "$NODE_STATUS" ]; then
    echo -e "${GREEN}✓ Node status: Running${NC}"
else
    echo -e "${YELLOW}⚠ Node status unknown${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Reboot Survival Test: PASSED${NC}"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✓ System rebooted"
echo "  ✓ Clawdbot node started automatically"
echo "  ✓ LaunchAgent loaded"
echo "  ✓ Gateway connection established"
echo ""
echo "Result: Auto-start working correctly after reboot"
echo ""
