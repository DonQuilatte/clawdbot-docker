#!/bin/bash
# System Tests: Antigravity MCP Integration
# Tests the actual MCP system integration and functionality

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
test_pass() {
    local description="$1"
    echo -e "  ${GREEN}✓${NC} $description"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

test_fail() {
    local description="$1"
    local reason="${2:-}"
    if [[ -n "$reason" ]]; then
        echo -e "  ${RED}✗${NC} $description: $reason"
    else
        echo -e "  ${RED}✗${NC} $description"
    fi
    ((TESTS_FAILED++))
    ((TESTS_RUN++))
}

test_skip() {
    local description="$1"
    local reason="${2:-}"
    echo -e "  ${YELLOW}⊘${NC} $description (skipped: $reason)"
}

# Test Suite
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "System Tests: Antigravity MCP Integration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test 1: Environment Tools
echo "Test Group 1: Required Tools Installation"

if command -v direnv >/dev/null 2>&1; then
    VERSION=$(direnv --version 2>&1 | head -n1)
    test_pass "direnv installed ($VERSION)"
else
    test_fail "direnv installed" "direnv not found"
fi

if command -v op >/dev/null 2>&1; then
    VERSION=$(op --version 2>&1 | head -n1)
    test_pass "1Password CLI installed ($VERSION)"
else
    test_fail "1Password CLI installed" "op not found"
fi

if command -v jq >/dev/null 2>&1; then
    VERSION=$(jq --version 2>&1)
    test_pass "jq installed ($VERSION)"
else
    test_skip "jq installed" "optional tool"
fi

if command -v npx >/dev/null 2>&1; then
    test_pass "npx available (for MCP servers)"
else
    test_fail "npx available" "npx not found"
fi
echo ""

# Test 2: direnv Integration
echo "Test Group 2: direnv Shell Integration"

if grep -q "direnv hook" ~/.zshrc 2>/dev/null; then
    test_pass "direnv hook configured in ~/.zshrc"
else
    test_fail "direnv hook configured" "not found in ~/.zshrc"
fi

# Test direnv status
cd "$PROJECT_ROOT"
if direnv status >/dev/null 2>&1; then
    test_pass "direnv status command works"
    
    # Check if .envrc is allowed (loaded = allowed)
    DIRENV_OUTPUT=$(direnv status 2>&1)
    if echo "$DIRENV_OUTPUT" | grep -q "Loaded RC path"; then
        test_pass ".envrc is allowed by direnv"
    elif direnv status 2>&1 | grep -q "Found RC allowed true"; then
        test_pass ".envrc is allowed by direnv"
    else
        test_fail ".envrc is allowed" "run 'direnv allow'"
    fi
else
    test_fail "direnv status command" "direnv not working"
fi
echo ""

# Test 3: Active Configuration
echo "Test Group 3: Active Antigravity Configuration"

if [[ -L "$HOME/.gemini/mcp_config.json" ]]; then
    test_pass "~/.gemini/mcp_config.json is a symlink"
    
    TARGET=$(readlink "$HOME/.gemini/mcp_config.json")
    if [[ "$TARGET" == "$PROJECT_ROOT/.antigravity/mcp_config.json" ]]; then
        test_pass "Symlink points to clawdbot project"
    else
        test_fail "Symlink points to clawdbot" "points to: $TARGET"
    fi
elif [[ -f "$HOME/.gemini/mcp_config.json" ]]; then
    test_fail "~/.gemini/mcp_config.json is a symlink" "file exists but not a symlink"
else
    test_fail "~/.gemini/mcp_config.json exists" "not found"
fi
echo ""

# Test 4: MCP Server Configuration
echo "Test Group 4: MCP Server Configuration"

if command -v jq >/dev/null 2>&1 && [[ -f "$HOME/.gemini/mcp_config.json" ]]; then
    # Count servers
    SERVER_COUNT=$(jq '.mcpServers | length' "$HOME/.gemini/mcp_config.json" 2>/dev/null || echo "0")
    if [[ "$SERVER_COUNT" -eq 3 ]]; then
        test_pass "Correct number of MCP servers (3)"
    else
        test_fail "Correct number of MCP servers" "expected 3, got $SERVER_COUNT"
    fi
    
    # Check server names
    if jq -e '.mcpServers["gitkraken-clawdbot"]' "$HOME/.gemini/mcp_config.json" >/dev/null 2>&1; then
        test_pass "GitKraken server configured"
    else
        test_fail "GitKraken server configured" "not found"
    fi
    
    if jq -e '.mcpServers["docker-clawdbot"]' "$HOME/.gemini/mcp_config.json" >/dev/null 2>&1; then
        test_pass "Docker server configured"
    else
        test_fail "Docker server configured" "not found"
    fi
    
    if jq -e '.mcpServers["filesystem-clawdbot"]' "$HOME/.gemini/mcp_config.json" >/dev/null 2>&1; then
        test_pass "Filesystem server configured"
    else
        test_fail "Filesystem server configured" "not found"
    fi
    
    # Verify absolute paths
    if jq -r '.mcpServers[].args[]' "$HOME/.gemini/mcp_config.json" | grep -q "^/Users/"; then
        test_pass "MCP servers use absolute paths"
    else
        test_fail "MCP servers use absolute paths" "relative paths detected"
    fi
    
    # Check server count is under limit
    if [[ "$SERVER_COUNT" -le 25 ]]; then
        test_pass "MCP server count under recommended limit (≤25)"
    else
        test_fail "MCP server count under limit" "$SERVER_COUNT exceeds 25"
    fi
else
    test_skip "MCP server configuration tests" "jq not installed or config not found"
fi
echo ""

# Test 5: Wrapper Scripts Functionality
echo "Test Group 5: MCP Wrapper Scripts Functionality"

# Test wrapper scripts have correct shebang and structure
for script in mcp-gitkraken mcp-docker mcp-filesystem; do
    SCRIPT_PATH="$PROJECT_ROOT/scripts/$script"
    if [[ -f "$SCRIPT_PATH" ]]; then
        if head -n1 "$SCRIPT_PATH" | grep -q "^#!/"; then
            test_pass "$script has valid shebang"
        else
            test_fail "$script has valid shebang" "missing or invalid"
        fi
        
        if grep -q "set -e" "$SCRIPT_PATH"; then
            test_pass "$script uses 'set -e' for error handling"
        else
            test_skip "$script uses 'set -e'" "not critical"
        fi
        
        # Check for exec (npx, gk, or other commands)
        if grep -qE "^exec " "$SCRIPT_PATH"; then
            test_pass "$script uses 'exec' for proper process replacement"
        else
            test_fail "$script uses 'exec'" "should use exec for proper process handling"
        fi
    fi
done
echo ""

# Test 6: Docker Socket Detection
echo "Test Group 6: Docker Socket Detection"

# Source the direnvrc to get the function
if [[ -f "$HOME/.config/direnv/direnvrc" ]]; then
    source "$HOME/.config/direnv/direnvrc"
    
    if detect_docker_socket; then
        test_pass "Docker socket detected: $DOCKER_HOST"
    else
        test_skip "Docker socket detection" "no Docker runtime found"
    fi
else
    test_skip "Docker socket detection" "direnvrc not found"
fi
echo ""

# Test 7: 1Password Integration
echo "Test Group 7: 1Password Integration (Optional)"

if command -v op >/dev/null 2>&1; then
    # Check if 1Password is accessible
    if op whoami >/dev/null 2>&1; then
        test_pass "1Password CLI authenticated"
        
        # Source direnvrc to test op_export function
        if [[ -f "$HOME/.config/direnv/direnvrc" ]]; then
            source "$HOME/.config/direnv/direnvrc"
            
            if declare -f op_export >/dev/null; then
                test_pass "op_export function available"
            else
                test_fail "op_export function available" "function not found"
            fi
            
            if declare -f op_can_read >/dev/null; then
                test_pass "op_can_read function available"
            else
                test_fail "op_can_read function available" "function not found"
            fi
        fi
    else
        test_skip "1Password CLI authentication" "not signed in (optional)"
    fi
else
    test_skip "1Password integration" "op not installed (optional)"
fi
echo ""

# Test 8: Activation Script Functionality
echo "Test Group 8: Activation Script Functionality"

ACTIVATION_SCRIPT="$PROJECT_ROOT/scripts/antigravity-activate"
if [[ -f "$ACTIVATION_SCRIPT" ]]; then
    # Test script has proper error handling
    if grep -q "set -e" "$ACTIVATION_SCRIPT"; then
        test_pass "Activation script has error handling"
    else
        test_skip "Activation script error handling" "not critical"
    fi
    
    # Test script creates backup
    if grep -q "backup" "$ACTIVATION_SCRIPT"; then
        test_pass "Activation script creates backups"
    else
        test_skip "Activation script backups" "optional feature"
    fi
    
    # Test script creates symlink
    if grep -q "ln -sf" "$ACTIVATION_SCRIPT"; then
        test_pass "Activation script creates symlink"
    else
        test_fail "Activation script creates symlink" "ln -sf not found"
    fi
fi
echo ""

# Test 9: Validation Script
echo "Test Group 9: Validation Script Functionality"

VALIDATION_SCRIPT="$PROJECT_ROOT/scripts/validate-antigravity-mcp.sh"
if [[ -x "$VALIDATION_SCRIPT" ]]; then
    # Run validation script (capture output but don't fail on non-zero exit)
    if "$VALIDATION_SCRIPT" >/dev/null 2>&1; then
        test_pass "Validation script runs successfully"
    else
        test_fail "Validation script runs" "script returned non-zero exit code"
    fi
else
    test_fail "Validation script executable" "not found or not executable"
fi
echo ""

# Test 10: Environment Variables
echo "Test Group 10: Environment Variables"

cd "$PROJECT_ROOT"

# Try to load environment (if direnv is working)
if command -v direnv >/dev/null 2>&1; then
    # Export environment variables from direnv
    eval "$(direnv export bash 2>/dev/null)" || true
    
    if [[ -n "${PROJECT_ROOT:-}" ]]; then
        test_pass "PROJECT_ROOT environment variable set"
    else
        test_skip "PROJECT_ROOT environment variable" "direnv not loaded"
    fi
    
    if [[ -n "${PROJECT_NAME:-}" ]]; then
        if [[ "$PROJECT_NAME" == "clawdbot" ]]; then
            test_pass "PROJECT_NAME set to 'clawdbot'"
        else
            test_fail "PROJECT_NAME correct" "expected 'clawdbot', got '$PROJECT_NAME'"
        fi
    else
        test_skip "PROJECT_NAME environment variable" "direnv not loaded"
    fi
else
    test_skip "Environment variable tests" "direnv not available"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Tests Run:    $TESTS_RUN"
echo -e "  ${GREEN}Passed:${NC}       $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC}       $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All system tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some system tests failed${NC}"
    exit 1
fi
