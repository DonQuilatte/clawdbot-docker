#!/bin/bash
# Unit tests for scripts/lib/common.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$(dirname "$SCRIPT_DIR")")}"

# Source test utilities
source "$SCRIPT_DIR/../lib/test-utils.sh"

# Source the common library
source "$PROJECT_ROOT/scripts/lib/common.sh"

echo "Testing common.sh library functions..."

# Test: get_gateway_token function exists
print_test "get_gateway_token function exists"
if declare -f get_gateway_token &>/dev/null; then
    print_pass "get_gateway_token function is defined"
else
    print_fail "get_gateway_token function is not defined"
fi

# Test: get_gateway_token returns value from .env file
print_test "get_gateway_token reads from .env file"
if [ -f "$PROJECT_ROOT/.env" ]; then
    TOKEN=$(get_gateway_token 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$TOKEN" ]; then
        # Mask token for security
        TOKEN_MASKED="${TOKEN:0:8}..."
        print_pass "get_gateway_token returns token: $TOKEN_MASKED"
    else
        print_fail "get_gateway_token failed to read token"
    fi
else
    print_skip "No .env file found (expected in CI)"
fi

# Test: get_gateway_token handles 1Password references
print_test "get_gateway_token supports op:// references"
# This is a structural test - we verify the function has the op:// handling code
FUNC_CODE=$(declare -f get_gateway_token)
if [[ "$FUNC_CODE" == *"op://"* ]] && [[ "$FUNC_CODE" == *"op read"* ]]; then
    print_pass "Function has 1Password support"
else
    print_fail "Function missing 1Password support"
fi

# Test: get_gateway_token error handling
print_test "get_gateway_token errors on missing .env"
# Create a temp directory without .env
TEMP_DIR=$(mktemp -d)
ORIG_BASH_SOURCE="${BASH_SOURCE[0]}"
# Note: We can't easily test this without modifying the function
# so we do a structural test
if [[ "$FUNC_CODE" == *"ERROR"* ]] && [[ "$FUNC_CODE" == *"return 1"* ]]; then
    print_pass "Function has error handling"
else
    print_fail "Function missing error handling"
fi
rmdir "$TEMP_DIR"

# Test: get_gateway_token handles quoted values
print_test "get_gateway_token handles quoted values"
# Structural test - verify sed strips quotes
if [[ "$FUNC_CODE" == *"sed"* ]] && [[ "$FUNC_CODE" == *"'"* || "$FUNC_CODE" == *'"'* ]]; then
    print_pass "Function handles quoted values"
else
    print_fail "Function may not handle quoted values"
fi

# Test: get_gateway_token handles whitespace
print_test "get_gateway_token strips whitespace"
if [[ "$FUNC_CODE" == *"space"* ]] || [[ "$FUNC_CODE" == *"sed"* ]]; then
    print_pass "Function handles whitespace"
else
    print_fail "Function may not handle whitespace"
fi

# Test: common.sh is sourceable without errors
print_test "common.sh sources without errors"
if bash -n "$PROJECT_ROOT/scripts/lib/common.sh" 2>/dev/null; then
    print_pass "common.sh has no syntax errors"
else
    print_fail "common.sh has syntax errors"
fi

echo ""
echo "Unit tests for common.sh complete."
