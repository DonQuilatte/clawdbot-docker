#!/usr/bin/env bash
# Gateway startup validation - run before starting clawdbot gateway
# Catches configuration issues early with clear error messages

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
    NC='\033[0m'
fi

ERRORS=0

error() {
    echo -e "${RED}ERROR:${NC} $1"
    ((ERRORS++))
}

warn() {
    echo -e "${YELLOW}WARN:${NC} $1"
}

ok() {
    echo -e "${GREEN}OK:${NC} $1"
}

echo "=== Gateway Startup Validation ==="

# Check 1: Writable directories
for dir in "${HOME}/.clawdbot" "/tmp"; do
    if [[ -d "$dir" ]]; then
        if touch "$dir/.write-test" 2>/dev/null; then
            rm -f "$dir/.write-test"
            ok "$dir is writable"
        else
            error "$dir is not writable (uid=$(id -u), dir owned by $(stat -c '%u' "$dir" 2>/dev/null || stat -f '%u' "$dir"))"
        fi
    else
        if mkdir -p "$dir" 2>/dev/null; then
            ok "$dir created successfully"
        else
            error "Cannot create $dir"
        fi
    fi
done

# Check 2: Gateway token
if [[ -n "${CLAWDBOT_GATEWAY_TOKEN:-}" ]]; then
    ok "CLAWDBOT_GATEWAY_TOKEN is set (${#CLAWDBOT_GATEWAY_TOKEN} chars)"
else
    warn "CLAWDBOT_GATEWAY_TOKEN not set - gateway will be unauthenticated"
fi

# Check 3: Network binding (check if we can bind to 0.0.0.0)
if command -v nc &>/dev/null; then
    TEST_PORT=$((RANDOM % 1000 + 50000))
    if timeout 1 nc -l 0.0.0.0 $TEST_PORT &>/dev/null & then
        sleep 0.1
        kill %1 2>/dev/null || true
        ok "Can bind to 0.0.0.0"
    fi
fi

# Check 4: DNS resolution
if command -v getent &>/dev/null; then
    if getent hosts host.docker.internal &>/dev/null; then
        ok "host.docker.internal resolves"
    else
        warn "host.docker.internal does not resolve"
    fi
fi

# Check 5: Memory/resource limits
if [[ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]]; then
    MEM_LIMIT=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
    MEM_MB=$((MEM_LIMIT / 1024 / 1024))
    if [[ $MEM_MB -lt 256 ]]; then
        warn "Memory limit is low: ${MEM_MB}MB"
    else
        ok "Memory limit: ${MEM_MB}MB"
    fi
fi

echo ""
if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}Startup validation failed with $ERRORS error(s)${NC}"
    echo "See docs/GATEWAY-DOCKER-FIXES.md for solutions"
    exit 1
fi

echo -e "${GREEN}Startup validation passed${NC}"
exit 0
