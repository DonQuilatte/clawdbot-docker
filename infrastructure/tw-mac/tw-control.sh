#!/bin/bash
# TW Mac Control Script - Distributed AI Worker Management
# Usage: tw-control.sh [command]
#
# Connection: Tailscale (WireGuard encrypted) with LAN fallback

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Source common library for colors (with fallback if not found)
if [[ -f "$PROJECT_ROOT/scripts/lib/common.sh" ]]; then
    # shellcheck source=../../scripts/lib/common.sh
    source "$PROJECT_ROOT/scripts/lib/common.sh"
else
    # Fallback colors if common.sh not available
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
fi

# Configuration from environment (with defaults)
# SECURITY NOTE: Default IPs are internal network addresses only accessible via:
#   - Tailscale VPN (100.x.x.x) - WireGuard encrypted, requires authentication
#   - Local LAN (192.168.x.x) - Only reachable from same network segment
# Override via environment variables for different deployments:
#   export TW_TAILSCALE_IP=100.x.x.x TW_LAN_IP=192.168.x.x
TW_TAILSCALE_IP="${TW_TAILSCALE_IP:-100.81.110.81}"
TW_LAN_IP="${TW_LAN_IP:-192.168.1.245}"
TW_HOST="${TW_HOST:-tw}"  # Uses SSH config which points to Tailscale
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_clawdbot}"
SSH_OPTS="-o BatchMode=yes -o IdentitiesOnly=yes -i $SSH_KEY"
CONTROL_SOCKET="$HOME/.ssh/sockets/tywhitaker@${TW_TAILSCALE_IP}-22"

status() {
    echo -e "${BLUE}=== TW Mac Status ===${NC}"

    # Check Tailscale
    if ping -c 1 -W 2 $TW_TAILSCALE_IP >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Tailscale: Connected ($TW_TAILSCALE_IP)${NC}"
    else
        echo -e "${RED}✗ Tailscale: Not reachable${NC}"
        # Fallback to LAN check
        if ping -c 1 -W 2 $TW_LAN_IP >/dev/null 2>&1; then
            echo -e "${YELLOW}○ LAN Fallback: Available ($TW_LAN_IP)${NC}"
        else
            echo -e "${RED}✗ LAN: Unreachable${NC}"
            return 1
        fi
    fi

    # Check SSH
    if SSH_AUTH_SOCK="" ssh $SSH_OPTS -o ConnectTimeout=5 $TW_HOST 'exit 0' 2>/dev/null; then
        echo -e "${GREEN}✓ SSH: Connected${NC}"
    else
        echo -e "${RED}✗ SSH: Failed${NC}"
        return 1
    fi

    # Check control socket
    if [ -S "$CONTROL_SOCKET" ]; then
        echo -e "${GREEN}✓ Persistent Socket: Active${NC}"
    else
        echo -e "${YELLOW}○ Persistent Socket: Not established${NC}"
    fi

    # Check SMB mount
    if mount | grep -qiE "192.168.1.245|tw\.local|tw-mac|tywhitaker"; then
        echo -e "${GREEN}✓ SMB Mount: Active${NC}"
    else
        echo -e "${YELLOW}○ SMB Mount: Not mounted${NC}"
    fi

    # Remote status
    echo -e "\n${BLUE}=== Remote System ===${NC}"
    SSH_AUTH_SOCK="" ssh $SSH_OPTS $TW_HOST '
        echo "Hostname: $(hostname)"
        echo "Uptime: $(uptime | sed "s/.*up /up /" | sed "s/,.*load.*//")"
        echo "Load: $(uptime | sed "s/.*load averages: //")"
        echo ""
        echo "tmux sessions: $(tmux list-sessions 2>/dev/null | wc -l | tr -d " ")"
        echo "Desktop Commander: $(pgrep -f "DesktopCommanderMCP" >/dev/null && echo "Running" || echo "Not running")"
    '
}

connect() {
    echo -e "${BLUE}Establishing persistent SSH connection...${NC}"
    SSH_AUTH_SOCK="" ssh $SSH_OPTS -fNM $TW_HOST 2>/dev/null && \
        echo -e "${GREEN}✓ Persistent connection established${NC}" || \
        echo -e "${YELLOW}Connection already exists or failed${NC}"
}

disconnect() {
    echo -e "${BLUE}Closing persistent SSH connection...${NC}"
    SSH_AUTH_SOCK="" ssh $SSH_OPTS -O exit $TW_HOST 2>/dev/null && \
        echo -e "${GREEN}✓ Connection closed${NC}" || \
        echo -e "${YELLOW}No active connection${NC}"
}

start-mcp() {
    echo -e "${BLUE}Starting Desktop Commander MCP on TW Mac...${NC}"
    SSH_AUTH_SOCK="" ssh $SSH_OPTS $TW_HOST '
        tmux has-session -t mcp 2>/dev/null && tmux kill-session -t mcp
        tmux new-session -d -s mcp "cd ~/Development/DesktopCommanderMCP && NODE_ENV=production MCP_DXT=true node dist/index.js"
        sleep 1
        tmux has-session -t mcp 2>/dev/null && echo "MCP server started in tmux session: mcp" || echo "Failed to start"
    '
}

stop-mcp() {
    echo -e "${BLUE}Stopping Desktop Commander MCP on TW Mac...${NC}"
    SSH_AUTH_SOCK="" ssh $SSH_OPTS $TW_HOST '
        tmux kill-session -t mcp 2>/dev/null && echo "MCP session stopped" || echo "No MCP session running"
    '
}

shell() {
    echo -e "${BLUE}Opening shell on TW Mac...${NC}"
    SSH_AUTH_SOCK="" ssh $SSH_OPTS -t $TW_HOST
}

tmux-attach() {
    echo -e "${BLUE}Attaching to tmux on TW Mac...${NC}"
    SSH_AUTH_SOCK="" ssh $SSH_OPTS -t $TW_HOST 'tmux attach 2>/dev/null || tmux new-session -s main'
}

run() {
    shift
    SSH_AUTH_SOCK="" ssh $SSH_OPTS $TW_HOST "$@"
}

case "${1:-status}" in
    status)     status ;;
    connect)    connect ;;
    disconnect) disconnect ;;
    start-mcp)  start-mcp ;;
    stop-mcp)   stop-mcp ;;
    shell)      shell ;;
    tmux)       tmux-attach ;;
    run)        run "$@" ;;
    *)
        echo "TW Mac Control - Distributed AI Worker Management"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  status      - Show TW Mac status (default)"
        echo "  connect     - Establish persistent SSH connection"
        echo "  disconnect  - Close persistent SSH connection"
        echo "  start-mcp   - Start Desktop Commander MCP server"
        echo "  stop-mcp    - Stop Desktop Commander MCP server"
        echo "  shell       - Open interactive shell"
        echo "  tmux        - Attach to tmux session"
        echo "  run <cmd>   - Run command on TW Mac"
        ;;
esac
