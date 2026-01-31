#!/bin/bash
# scripts/lib/common.sh
# Common infrastructure functions for dev-infra.
#
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# Or:    source "$HOME/Development/Projects/dev-infra/scripts/lib/common.sh"
#
# This library provides:
#   - Color definitions and output functions
#   - Environment loading (.env, 1Password)
#   - SSH utilities
#   - Token management
#   - Script initialization (strict mode)

#------------------------------------------------------------------------------
# Strict Mode Initialization
#------------------------------------------------------------------------------
# Call this at the start of scripts for consistent error handling
init_strict_mode() {
    set -euo pipefail
    # Trap errors and provide context
    trap 'echo -e "${RED:-}Error on line $LINENO${NC:-}" >&2' ERR
}

#------------------------------------------------------------------------------
# Color Definitions (centralized - source this file instead of duplicating)
#------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

#------------------------------------------------------------------------------
# Output Functions
#------------------------------------------------------------------------------
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BOLD}${CYAN}$1${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

print_section() {
    echo ""
    echo -e "${BOLD}$1${NC}"
    echo "---------------------------------------------------"
}

#------------------------------------------------------------------------------
# Environment Functions
#------------------------------------------------------------------------------
# Determine repo root from this script's location
get_repo_root() {
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

# Load environment variables from .env file
load_env() {
    local repo_root
    repo_root="$(get_repo_root)"

    if [[ -f "$repo_root/.env" ]]; then
        # Export variables from .env, ignoring comments and empty lines
        set -a
        # shellcheck source=/dev/null
        source "$repo_root/.env"
        set +a
    fi
}

#------------------------------------------------------------------------------
# SSH Functions
#------------------------------------------------------------------------------
# Default SSH options for reliability
SSH_OPTS="${SSH_OPTS:--o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new}"
CURL_TIMEOUT="${CURL_TIMEOUT:-5}"
PING_TIMEOUT="${PING_TIMEOUT:-3}"

# Execute command on remote host via SSH
ssh_cmd() {
    local host="$1"
    shift
    ssh $SSH_OPTS "$host" "$@"
}

# Check if SSH connection works (returns 0 if successful)
ssh_check() {
    local host="$1"
    ssh $SSH_OPTS "$host" "echo ok" &>/dev/null
}

#------------------------------------------------------------------------------
# Token Functions
#------------------------------------------------------------------------------
# Get the gateway token, supporting .env and 1Password (op://)
get_gateway_token() {
    local token_ref
    
    # Identify repo root (assuming scripts/lib is 2 levels deep)
    local repo_root
    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    if [ ! -f "$repo_root/.env" ]; then
        echo "❌ ERROR: .env file not found in $repo_root" >&2
        return 1
    fi

    # Parse token value, handling quoted values and special characters
    local raw_line
    raw_line=$(grep -E "^CLAWDBOT_GATEWAY_TOKEN=" "$repo_root/.env" 2>/dev/null)

    if [ -z "$raw_line" ]; then
        echo "❌ ERROR: CLAWDBOT_GATEWAY_TOKEN not set in .env" >&2
        return 1
    fi

    # Extract value after first '=', then strip surrounding quotes (single or double)
    token_ref=$(echo "$raw_line" | sed 's/^[^=]*=//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

    if [ -z "$token_ref" ]; then
        echo "❌ ERROR: CLAWDBOT_GATEWAY_TOKEN is empty in .env" >&2
        return 1
    fi

    # Check if it's a 1Password reference
    if [[ "$token_ref" == op://* ]]; then
        # Fetch from 1Password
        if ! command -v op &> /dev/null; then
            echo "❌ ERROR: 1Password CLI (op) not found but reference used" >&2
            return 1
        fi
        
        local token
        if ! token=$(op read "$token_ref" 2>/dev/null); then
            echo "❌ ERROR: Failed to read from 1Password" >&2
            return 1
        fi
        echo "$token"
    else
        # Return literal value
        echo "$token_ref"
    fi
}

#------------------------------------------------------------------------------
# Path Resolution
#------------------------------------------------------------------------------
# Get the dev-infra root directory
get_dev_infra_root() {
    echo "$HOME/Development/Projects/dev-infra"
}

# Resolve script directory (call from within your script)
# Usage: SCRIPT_DIR="$(get_script_dir)"
get_script_dir() {
    cd "$(dirname "${BASH_SOURCE[1]}")" && pwd
}

#------------------------------------------------------------------------------
# Validation Functions
#------------------------------------------------------------------------------
# Check if a command exists
require_cmd() {
    local cmd="$1"
    local msg="${2:-$cmd is required but not installed}"
    if ! command -v "$cmd" &>/dev/null; then
        print_error "$msg"
        exit 1
    fi
}

# Check if a file exists
require_file() {
    local file="$1"
    local msg="${2:-Required file not found: $file}"
    if [[ ! -f "$file" ]]; then
        print_error "$msg"
        exit 1
    fi
}

# Check if a directory exists
require_dir() {
    local dir="$1"
    local msg="${2:-Required directory not found: $dir}"
    if [[ ! -d "$dir" ]]; then
        print_error "$msg"
        exit 1
    fi
}

#------------------------------------------------------------------------------
# Logging Functions
#------------------------------------------------------------------------------
# Log to stderr (for scripts that output to stdout)
log_debug() {
    [[ "${DEBUG:-}" == "1" ]] && echo -e "${CYAN}[DEBUG]${NC} $1" >&2
}

log_verbose() {
    [[ "${VERBOSE:-}" == "1" ]] && echo -e "${BLUE}[INFO]${NC} $1" >&2
}

#------------------------------------------------------------------------------
# Progress Indicators
#------------------------------------------------------------------------------
# Simple spinner for long-running operations
# Usage: long_command & spinner $! "Processing..."
spinner() {
    local pid=$1
    local msg="${2:-Working...}"
    local spin='-\|/'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % 4 ))
        printf "\r${BLUE}%s${NC} %s" "${spin:$i:1}" "$msg"
        sleep 0.1
    done
    printf "\r"
}

#------------------------------------------------------------------------------
# Retry Logic
#------------------------------------------------------------------------------
# Retry a command with exponential backoff
# Usage: retry 3 some_command arg1 arg2
retry() {
    local max_attempts=$1
    shift
    local attempt=1
    local delay=2

    while [[ $attempt -le $max_attempts ]]; do
        if "$@"; then
            return 0
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            print_warning "Attempt $attempt/$max_attempts failed. Retrying in ${delay}s..."
            sleep $delay
            delay=$((delay * 2))
        fi

        ((attempt++))
    done

    print_error "All $max_attempts attempts failed"
    return 1
}
