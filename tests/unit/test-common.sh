#!/bin/bash
# Unit tests for scripts/lib/common.sh

# Source the common library
source "$PROJECT_ROOT/scripts/lib/common.sh"

echo "Testing common.sh library functions..."

# Test: Color variables are defined
print_test "Color variables are defined"
if [[ -n "$RED" && -n "$GREEN" && -n "$YELLOW" && -n "$BLUE" && -n "$NC" ]]; then
    print_pass "All color variables are defined"
else
    print_fail "Some color variables are missing"
fi

# Test: Timeout variables are defined
print_test "Timeout variables are defined"
if [[ -n "$SSH_TIMEOUT" && -n "$CURL_TIMEOUT" && -n "$PING_TIMEOUT" ]]; then
    print_pass "All timeout variables are defined"
else
    print_fail "Some timeout variables are missing"
fi

# Test: Default GATEWAY_PORT is set
print_test "Default GATEWAY_PORT is 18789"
assert_eq "18789" "$GATEWAY_PORT" "GATEWAY_PORT should default to 18789"

# Test: load_env function exists
print_test "load_env function exists"
if declare -f load_env &>/dev/null; then
    print_pass "load_env function is defined"
else
    print_fail "load_env function is not defined"
fi

# Test: load_env loads environment file
print_test "load_env loads environment variables"
TEST_ENV_FILE=$(mktemp)
echo "TEST_VAR_12345=hello_world" > "$TEST_ENV_FILE"
load_env "$TEST_ENV_FILE"
if [[ "${TEST_VAR_12345:-}" == "hello_world" ]]; then
    print_pass "load_env correctly loads environment variables"
else
    print_fail "load_env failed to load environment variables"
fi
rm -f "$TEST_ENV_FILE"
unset TEST_VAR_12345

# Test: print functions exist
print_test "Print functions are defined"
PRINT_FUNCS=("print_step" "print_success" "print_warning" "print_error" "print_header" "print_section")
all_defined=true
for func in "${PRINT_FUNCS[@]}"; do
    if ! declare -f "$func" &>/dev/null; then
        all_defined=false
        break
    fi
done
if $all_defined; then
    print_pass "All print functions are defined"
else
    print_fail "Some print functions are missing"
fi

# Test: test result functions exist
print_test "Test result functions are defined"
TEST_FUNCS=("test_pass" "test_fail" "test_warn")
all_defined=true
for func in "${TEST_FUNCS[@]}"; do
    if ! declare -f "$func" &>/dev/null; then
        all_defined=false
        break
    fi
done
if $all_defined; then
    print_pass "All test result functions are defined"
else
    print_fail "Some test result functions are missing"
fi

# Test: ssh_cmd function exists
print_test "ssh_cmd function exists"
if declare -f ssh_cmd &>/dev/null; then
    print_pass "ssh_cmd function is defined"
else
    print_fail "ssh_cmd function is not defined"
fi

# Test: ssh_check function exists
print_test "ssh_check function exists"
if declare -f ssh_check &>/dev/null; then
    print_pass "ssh_check function is defined"
else
    print_fail "ssh_check function is not defined"
fi

# Test: get_gateway_token function exists
print_test "get_gateway_token function exists"
if declare -f get_gateway_token &>/dev/null; then
    print_pass "get_gateway_token function is defined"
else
    print_fail "get_gateway_token function is not defined"
fi

# Test: get_gateway_token returns env variable if set
print_test "get_gateway_token returns CLAWDBOT_GATEWAY_TOKEN if set"
export CLAWDBOT_GATEWAY_TOKEN="test-token-12345"
TOKEN=$(get_gateway_token)
if [[ "$TOKEN" == "test-token-12345" ]]; then
    print_pass "get_gateway_token returns environment variable"
else
    print_fail "get_gateway_token did not return environment variable"
fi
unset CLAWDBOT_GATEWAY_TOKEN

# Test: require_config function exists
print_test "require_config function exists"
if declare -f require_config &>/dev/null; then
    print_pass "require_config function is defined"
else
    print_fail "require_config function is not defined"
fi

echo ""
echo "Unit tests for common.sh complete."
