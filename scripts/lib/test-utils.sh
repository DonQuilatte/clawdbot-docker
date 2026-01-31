#!/bin/bash
# scripts/lib/test-utils.sh
# Common test utilities for Clawdbot test suites
#
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/lib/test-utils.sh"
#
# This library provides:
#   - Test result tracking
#   - Remote data collection
#   - Cache management
#   - Test summary functions

# Source common.sh for colors
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

#------------------------------------------------------------------------------
# Test Counters (global)
#------------------------------------------------------------------------------
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

#------------------------------------------------------------------------------
# Cache Management
#------------------------------------------------------------------------------
init_test_cache() {
    local prefix="${1:-clawdbot-test}"
    CACHE_DIR="/tmp/${prefix}-cache-$$"
    mkdir -p "$CACHE_DIR"
    # Set trap to cleanup on exit
    trap "rm -rf '$CACHE_DIR'" EXIT
    echo "$CACHE_DIR"
}

#------------------------------------------------------------------------------
# Test Result Functions
#------------------------------------------------------------------------------
test_result() {
    local test_name="$1"
    local result="$2"
    local details="${3:-}"
    local log_file="${4:-/tmp/test-results.log}"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [[ "$result" == "PASS" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $test_name"
        [[ -n "$log_file" ]] && echo "PASS: $test_name - $details" >> "$log_file"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $test_name"
        [[ -n "$log_file" ]] && echo "FAIL: $test_name - $details" >> "$log_file"
    fi
}

test_pass() {
    local test_name="$1"
    local details="${2:-}"
    test_result "$test_name" "PASS" "$details"
}

test_fail() {
    local test_name="$1"
    local details="${2:-}"
    test_result "$test_name" "FAIL" "$details"
}

#------------------------------------------------------------------------------
# Test Summary
#------------------------------------------------------------------------------
print_test_summary() {
    local log_file="${1:-}"

    echo ""
    echo "=========================================="
    echo -e "${BLUE}Test Summary${NC}"
    echo "=========================================="
    echo ""
    echo -e "Total Tests: $TESTS_TOTAL"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""

    if [[ $TESTS_TOTAL -gt 0 ]]; then
        SUCCESS_RATE=$((TESTS_PASSED * 100 / TESTS_TOTAL))
        echo -e "Success Rate: ${SUCCESS_RATE}%"
        echo ""

        if [[ $TESTS_FAILED -eq 0 ]]; then
            echo -e "${GREEN}✓ All tests passed! System is healthy.${NC}"
            echo "Status: PRODUCTION READY"
            return 0
        elif [[ $SUCCESS_RATE -ge 80 ]]; then
            echo -e "${YELLOW}⚠ System operational with minor issues${NC}"
            echo "Status: OPERATIONAL (review failed tests)"
            return 0
        else
            echo -e "${RED}✗ Critical issues detected${NC}"
            echo "Status: NEEDS ATTENTION"
            return 2
        fi
    fi

    [[ -n "$log_file" ]] && echo "" && echo "Detailed results saved to: $log_file"
}

#------------------------------------------------------------------------------
# SSH/Remote Utilities
#------------------------------------------------------------------------------
# Helper to load nvm on remote
load_nvm_remote() {
    echo 'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
}

# Collect remote data in batch (reduces SSH overhead)
collect_remote_data() {
    local remote_host="$1"
    local cache_dir="$2"
    local script="$3"

    ssh "$remote_host" bash -s <<< "$script" > "$cache_dir/remote_data" 2>/dev/null
}

# Parse section from collected data
parse_remote_section() {
    local data_file="$1"
    local start_marker="$2"
    local end_marker="$3"

    awk "/$start_marker/,/$end_marker/" "$data_file" | grep -v "===" || true
}

#------------------------------------------------------------------------------
# Assertion Helpers
#------------------------------------------------------------------------------
assert_process_running() {
    local process_name="$1"
    local ps_output="$2"

    if grep -q "$process_name" "$ps_output" 2>/dev/null; then
        return 0
    fi
    return 1
}

assert_port_listening() {
    local port="$1"
    local lsof_output="$2"

    if grep -q "LISTEN" "$lsof_output" 2>/dev/null && grep -q ":$port" "$lsof_output" 2>/dev/null; then
        return 0
    fi
    return 1
}

assert_file_exists() {
    local file="$1"
    [[ -f "$file" ]]
}

assert_connection_established() {
    local lsof_output="$1"

    grep -q "ESTABLISHED" "$lsof_output" 2>/dev/null
}
