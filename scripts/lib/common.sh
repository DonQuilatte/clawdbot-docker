#!/bin/bash
# Shared library for Clawdbot scripts
# Source this file: source "$(dirname "$0")/lib/common.sh"

# shellcheck disable=SC2034  # Variables used by sourcing scripts

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Timeouts (seconds)
SSH_TIMEOUT=5
CURL_TIMEOUT=5
PING_TIMEOUT=2
HEALTH_CHECK_TIMEOUT=10

# Default configuration (override via environment or .env file)
: "${REMOTE_HOST:=}"
: "${REMOTE_USER:=}"
: "${GATEWAY_HOST:=}"
: "${GATEWAY_IP:=}"
: "${GATEWAY_PORT:=18789}"

# Load .env file if present
load_env() {
    local env_file="${1:-.env}"
    if [ -f "$env_file" ]; then
        # shellcheck disable=SC1090
        set -a
        source "$env_file"
        set +a
    fi
}

# Print functions
print_step() {
    echo -e "${BLUE}➤${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_section() {
    echo ""
    echo -e "${CYAN}━━━ $1 ━━━${NC}"
}

# Test result functions
test_pass() {
    echo -e "  ${GREEN}✅ PASS${NC}: $1"
}

test_fail() {
    echo -e "  ${RED}❌ FAIL${NC}: $1"
}

test_warn() {
    echo -e "  ${YELLOW}⚠️  WARN${NC}: $1"
}

# Validate required configuration
require_config() {
    local missing=0
    for var in "$@"; do
        if [ -z "${!var:-}" ]; then
            print_error "Required variable $var is not set"
            missing=1
        fi
    done
    if [ $missing -eq 1 ]; then
        echo ""
        echo "Set variables in .env file or export them:"
        for var in "$@"; do
            echo "  export $var=<value>"
        done
        exit 1
    fi
}

# SSH wrapper with consistent options
ssh_cmd() {
    ssh -o ConnectTimeout="$SSH_TIMEOUT" -o BatchMode=yes "$@"
}

# SSH check (returns 0 if connection works)
ssh_check() {
    local host="$1"
    ssh_cmd "$host" "echo ok" &>/dev/null
}

# Get gateway token securely
get_gateway_token() {
    # Try environment first
    if [ -n "${CLAWDBOT_GATEWAY_TOKEN:-}" ]; then
        echo "$CLAWDBOT_GATEWAY_TOKEN"
        return 0
    fi

    # Try .env file
    if [ -f .env ]; then
        local token
        token=$(grep "^CLAWDBOT_GATEWAY_TOKEN=" .env 2>/dev/null | cut -d= -f2)
        if [ -n "$token" ]; then
            echo "$token"
            return 0
        fi
    fi

    # No token found
    return 1
}
