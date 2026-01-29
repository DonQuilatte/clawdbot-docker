#!/bin/bash
# Unit Tests: Antigravity MCP Configuration
# Tests the MCP configuration files and structure

set -uo pipefail
# Note: Not using -e because arithmetic expressions can return false

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
assert_file_exists() {
    local file="$1"
    local description="${2:-File exists}"
    
    ((TESTS_RUN++))
    if [[ -f "$file" ]]; then
        echo -e "  ${GREEN}✓${NC} $description: $file"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $description: $file (NOT FOUND)"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_file_executable() {
    local file="$1"
    local description="${2:-File is executable}"
    
    ((TESTS_RUN++))
    if [[ -x "$file" ]]; then
        echo -e "  ${GREEN}✓${NC} $description: $file"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $description: $file (NOT EXECUTABLE)"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_json_valid() {
    local file="$1"
    local description="${2:-Valid JSON}"
    
    ((TESTS_RUN++))
    if command -v jq >/dev/null 2>&1; then
        if jq empty "$file" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $description: $file"
            ((TESTS_PASSED++))
            return 0
        else
            echo -e "  ${RED}✗${NC} $description: $file (INVALID JSON)"
            ((TESTS_FAILED++))
            return 1
        fi
    else
        echo -e "  ${YELLOW}⊘${NC} $description: $file (jq not installed, skipped)"
        return 0
    fi
}

assert_contains() {
    local file="$1"
    local pattern="$2"
    local description="${3:-File contains pattern}"
    
    ((TESTS_RUN++))
    if grep -q "$pattern" "$file" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $description: '$pattern'"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $description: '$pattern' (NOT FOUND)"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_json_key_exists() {
    local file="$1"
    local key="$2"
    local description="${3:-JSON key exists}"
    
    ((TESTS_RUN++))
    if command -v jq >/dev/null 2>&1; then
        if jq -e "$key" "$file" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} $description: $key"
            ((TESTS_PASSED++))
            return 0
        else
            echo -e "  ${RED}✗${NC} $description: $key (NOT FOUND)"
            ((TESTS_FAILED++))
            return 1
        fi
    else
        echo -e "  ${YELLOW}⊘${NC} $description: $key (jq not installed, skipped)"
        return 0
    fi
}

assert_json_value() {
    local file="$1"
    local key="$2"
    local expected="$3"
    local description="${4:-JSON value matches}"
    
    ((TESTS_RUN++))
    if command -v jq >/dev/null 2>&1; then
        local actual=$(jq -r "$key" "$file" 2>/dev/null)
        if [[ "$actual" == "$expected" ]]; then
            echo -e "  ${GREEN}✓${NC} $description: $key = $expected"
            ((TESTS_PASSED++))
            return 0
        else
            echo -e "  ${RED}✗${NC} $description: $key (expected: $expected, got: $actual)"
            ((TESTS_FAILED++))
            return 1
        fi
    else
        echo -e "  ${YELLOW}⊘${NC} $description: $key (jq not installed, skipped)"
        return 0
    fi
}

# Test Suite
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Unit Tests: Antigravity MCP Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test 1: Global direnvrc
echo "Test Group 1: Global direnvrc Configuration"
assert_file_exists "$HOME/.config/direnv/direnvrc" "Global direnvrc exists"
assert_file_executable "$HOME/.config/direnv/direnvrc" "Global direnvrc is executable"
assert_contains "$HOME/.config/direnv/direnvrc" "op_export" "direnvrc has op_export function"
assert_contains "$HOME/.config/direnv/direnvrc" "detect_docker_socket" "direnvrc has detect_docker_socket function"
echo ""

# Test 2: Project .envrc
echo "Test Group 2: Project .envrc File"
assert_file_exists "$PROJECT_ROOT/.envrc" "Project .envrc exists"
assert_contains "$PROJECT_ROOT/.envrc" "PROJECT_NAME" ".envrc defines PROJECT_NAME"
assert_contains "$PROJECT_ROOT/.envrc" "PROJECT_ROOT" ".envrc defines PROJECT_ROOT"
assert_contains "$PROJECT_ROOT/.envrc" "clawdbot" ".envrc contains project name"
echo ""

# Test 3: MCP Wrapper Scripts
echo "Test Group 3: MCP Wrapper Scripts"
assert_file_exists "$PROJECT_ROOT/scripts/mcp-gitkraken" "GitKraken wrapper exists"
assert_file_executable "$PROJECT_ROOT/scripts/mcp-gitkraken" "GitKraken wrapper is executable"
assert_contains "$PROJECT_ROOT/scripts/mcp-gitkraken" "gk mcp" "GitKraken wrapper has correct command"

assert_file_exists "$PROJECT_ROOT/scripts/mcp-docker" "Docker wrapper exists"
assert_file_executable "$PROJECT_ROOT/scripts/mcp-docker" "Docker wrapper is executable"
assert_contains "$PROJECT_ROOT/scripts/mcp-docker" "@docker/mcp-server" "Docker wrapper has correct command"

assert_file_exists "$PROJECT_ROOT/scripts/mcp-filesystem" "Filesystem wrapper exists"
assert_file_executable "$PROJECT_ROOT/scripts/mcp-filesystem" "Filesystem wrapper is executable"
assert_contains "$PROJECT_ROOT/scripts/mcp-filesystem" "@modelcontextprotocol/server-filesystem" "Filesystem wrapper has correct command"
echo ""

# Test 4: Antigravity MCP Configuration
echo "Test Group 4: Antigravity MCP Configuration"
assert_file_exists "$PROJECT_ROOT/.antigravity/mcp_config.json" "MCP config exists"
assert_json_valid "$PROJECT_ROOT/.antigravity/mcp_config.json" "MCP config is valid JSON"
assert_json_key_exists "$PROJECT_ROOT/.antigravity/mcp_config.json" ".mcpServers" "MCP config has mcpServers key"
assert_json_key_exists "$PROJECT_ROOT/.antigravity/mcp_config.json" '.mcpServers["gitkraken-clawdbot"]' "GitKraken server configured"
assert_json_key_exists "$PROJECT_ROOT/.antigravity/mcp_config.json" '.mcpServers["docker-clawdbot"]' "Docker server configured"
assert_json_key_exists "$PROJECT_ROOT/.antigravity/mcp_config.json" '.mcpServers["filesystem-clawdbot"]' "Filesystem server configured"

# Test absolute paths
if command -v jq >/dev/null 2>&1; then
    ((TESTS_RUN++))
    if jq -r '.mcpServers[].args[]' "$PROJECT_ROOT/.antigravity/mcp_config.json" | grep -q "^/"; then
        echo -e "  ${GREEN}✓${NC} MCP config uses absolute paths"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}✗${NC} MCP config should use absolute paths"
        ((TESTS_FAILED++))
    fi
fi
echo ""

# Test 5: Activation Script
echo "Test Group 5: Activation Script"
assert_file_exists "$PROJECT_ROOT/scripts/antigravity-activate" "Activation script exists"
assert_file_executable "$PROJECT_ROOT/scripts/antigravity-activate" "Activation script is executable"
assert_contains "$PROJECT_ROOT/scripts/antigravity-activate" "PROJECT_CONFIG" "Activation script has PROJECT_CONFIG"
assert_contains "$PROJECT_ROOT/scripts/antigravity-activate" "ANTIGRAVITY_CONFIG" "Activation script has ANTIGRAVITY_CONFIG"
assert_contains "$PROJECT_ROOT/scripts/antigravity-activate" "ln -sf" "Activation script creates symlink"
echo ""

# Test 6: Validation Script
echo "Test Group 6: Validation Script"
assert_file_exists "$PROJECT_ROOT/scripts/validate-antigravity-mcp.sh" "Validation script exists"
assert_file_executable "$PROJECT_ROOT/scripts/validate-antigravity-mcp.sh" "Validation script is executable"
echo ""

# Test 7: Documentation
echo "Test Group 7: Documentation Files"
assert_file_exists "$PROJECT_ROOT/docs/ANTIGRAVITY-MCP-SETUP.md" "Setup guide exists"
assert_file_exists "$PROJECT_ROOT/docs/ANTIGRAVITY-MCP-QUICKREF.md" "Quick reference exists"
echo ""

# Test 8: .gitignore
echo "Test Group 8: .gitignore Configuration"
assert_file_exists "$PROJECT_ROOT/.gitignore" ".gitignore exists"
assert_contains "$PROJECT_ROOT/.gitignore" ".envrc.local" ".gitignore has .envrc.local"
assert_contains "$PROJECT_ROOT/.gitignore" ".direnv/" ".gitignore has .direnv/"
assert_contains "$PROJECT_ROOT/.gitignore" ".antigravity/\*\.backup" ".gitignore has .antigravity/*.backup"
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
    echo -e "${GREEN}✓ All unit tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some unit tests failed${NC}"
    exit 1
fi
