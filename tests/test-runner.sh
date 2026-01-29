#!/bin/bash
# Clawdbot Test Runner
# Runs unit and system tests for the distributed Clawdbot setup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
export PROJECT_ROOT

# Source common library for colors and shared functions
# shellcheck source=../scripts/lib/common.sh
source "$PROJECT_ROOT/scripts/lib/common.sh"

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
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
            # Run the test file
            if bash "$test_file"; then
                ((TESTS_PASSED++)) || true
            else
                ((TESTS_FAILED++)) || true
            fi
            ((TESTS_RUN++)) || true
        fi
    done
}

# Print summary
print_summary() {
    print_header "Test Summary"

    echo -e "  Test Files Run:  $TESTS_RUN"
    echo -e "  ${GREEN}Passed:${NC}          $TESTS_PASSED"
    echo -e "  ${RED}Failed:${NC}          $TESTS_FAILED"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All test suites passed!${NC}"
        return 0
    else
        echo -e "${RED}Some test suites failed.${NC}"
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

main "$@"
