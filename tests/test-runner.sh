#!/bin/bash
# Clawdbot Test Runner
# Runs unit and system tests for the distributed Clawdbot setup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test result tracking
FAILED_TESTS=()

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
}

print_test() {
    echo -e "  ${YELLOW}TEST:${NC} $1"
}

print_pass() {
    echo -e "  ${GREEN}✓ PASS:${NC} $1"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

print_fail() {
    echo -e "  ${RED}✗ FAIL:${NC} $1"
    ((TESTS_FAILED++))
    ((TESTS_RUN++))
    FAILED_TESTS+=("$1")
}

print_skip() {
    echo -e "  ${YELLOW}⊘ SKIP:${NC} $1"
    ((TESTS_SKIPPED++))
}

# Assert functions
assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"

    if [[ "$expected" == "$actual" ]]; then
        print_pass "$message"
        return 0
    else
        print_fail "$message (expected: '$expected', got: '$actual')"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"

    if [[ "$haystack" == *"$needle"* ]]; then
        print_pass "$message"
        return 0
    else
        print_fail "$message (string does not contain '$needle')"
        return 1
    fi
}

assert_cmd_success() {
    local cmd="$1"
    local message="${2:-Command should succeed}"

    if eval "$cmd" &>/dev/null; then
        print_pass "$message"
        return 0
    else
        print_fail "$message (command failed: $cmd)"
        return 1
    fi
}

assert_cmd_fails() {
    local cmd="$1"
    local message="${2:-Command should fail}"

    if ! eval "$cmd" &>/dev/null; then
        print_pass "$message"
        return 0
    else
        print_fail "$message (command succeeded but should have failed)"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"

    if [[ -f "$file" ]]; then
        print_pass "$message"
        return 0
    else
        print_fail "$message (file not found: $file)"
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    local message="${2:-Directory should exist}"

    if [[ -d "$dir" ]]; then
        print_pass "$message"
        return 0
    else
        print_fail "$message (directory not found: $dir)"
        return 1
    fi
}

# Run all tests in a directory
run_test_suite() {
    local suite_dir="$1"
    local suite_name="$2"

    if [[ ! -d "$suite_dir" ]]; then
        echo -e "${YELLOW}No $suite_name tests found${NC}"
        return
    fi

    print_header "$suite_name Tests"

    for test_file in "$suite_dir"/test-*.sh; do
        if [[ -f "$test_file" ]]; then
            echo -e "\n${BLUE}Running: $(basename "$test_file")${NC}"
            # Source the test file to run its tests
            source "$test_file"
        fi
    done
}

# Print summary
print_summary() {
    print_header "Test Summary"

    echo -e "  Tests Run:     $TESTS_RUN"
    echo -e "  ${GREEN}Passed:${NC}        $TESTS_PASSED"
    echo -e "  ${RED}Failed:${NC}        $TESTS_FAILED"
    echo -e "  ${YELLOW}Skipped:${NC}       $TESTS_SKIPPED"
    echo ""

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}Failed Tests:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  - $test"
        done
        echo ""
    fi

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        return 1
    fi
}

# Main
main() {
    local test_type="${1:-all}"

    print_header "Clawdbot Test Suite"
    echo "Project Root: $PROJECT_ROOT"
    echo "Test Type: $test_type"

    case "$test_type" in
        unit)
            run_test_suite "$SCRIPT_DIR/unit" "Unit"
            ;;
        system)
            run_test_suite "$SCRIPT_DIR/system" "System"
            ;;
        all)
            run_test_suite "$SCRIPT_DIR/unit" "Unit"
            run_test_suite "$SCRIPT_DIR/system" "System"
            ;;
        *)
            echo "Usage: $0 [unit|system|all]"
            exit 1
            ;;
    esac

    print_summary
}

# Export functions for test files
export -f print_test print_pass print_fail print_skip
export -f assert_eq assert_contains assert_cmd_success assert_cmd_fails
export -f assert_file_exists assert_dir_exists
export PROJECT_ROOT SCRIPT_DIR

main "$@"
