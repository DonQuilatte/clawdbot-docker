#!/bin/bash
# TW Mac Infrastructure Test Runner
# Runs all unit, integration, and system tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    echo "TW Mac Infrastructure Test Runner"
    echo ""
    echo "Usage: $0 [options] [category]"
    echo ""
    echo "Categories:"
    echo "  unit         Run unit tests only"
    echo "  integration  Run integration tests only"
    echo "  system       Run system tests only"
    echo "  all          Run all tests (default)"
    echo ""
    echo "Options:"
    echo "  -v, --verbose   Show detailed output"
    echo "  -q, --quiet     Minimal output"
    echo "  -h, --help      Show this help"
    echo ""
    echo "Examples:"
    echo "  $0              # Run all tests"
    echo "  $0 unit         # Run unit tests only"
    echo "  $0 -v system    # Run system tests with verbose output"
}

run_test() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .sh)

    echo -e "${CYAN}► Running: $test_name${NC}"

    if [ "$VERBOSE" = true ]; then
        if bash "$test_file"; then
            echo -e "${GREEN}✓ $test_name passed${NC}"
            ((TOTAL_PASS++))
        else
            echo -e "${RED}✗ $test_name failed${NC}"
            ((TOTAL_FAIL++))
        fi
    else
        if output=$(bash "$test_file" 2>&1); then
            passed=$(echo "$output" | grep -o "Passed: [0-9]*" | grep -o "[0-9]*" || echo "0")
            failed=$(echo "$output" | grep -o "Failed: [0-9]*" | grep -o "[0-9]*" || echo "0")
            echo -e "${GREEN}✓ $test_name${NC} (pass: $passed, fail: $failed)"
            ((TOTAL_PASS++))
        else
            echo -e "${RED}✗ $test_name failed${NC}"
            if [ "$QUIET" != true ]; then
                echo "$output" | tail -10
            fi
            ((TOTAL_FAIL++))
        fi
    fi
    echo ""
}

run_category() {
    local category="$1"
    local test_dir="$SCRIPT_DIR/$category"

    if [ ! -d "$test_dir" ]; then
        echo -e "${YELLOW}Warning: No $category tests found${NC}"
        return
    fi

    local category_upper=$(echo "$category" | tr '[:lower:]' '[:upper:]')
    echo -e "${BLUE}=========================================="
    echo -e "Running $category_upper Tests"
    echo -e "==========================================${NC}"
    echo ""

    for test_file in "$test_dir"/test-*.sh; do
        if [ -f "$test_file" ]; then
            run_test "$test_file"
        fi
    done
}

# Parse arguments
VERBOSE=false
QUIET=false
CATEGORY="all"

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        unit|integration|system|all)
            CATEGORY="$1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Make all test scripts executable
chmod +x "$SCRIPT_DIR"/unit/*.sh 2>/dev/null || true
chmod +x "$SCRIPT_DIR"/integration/*.sh 2>/dev/null || true
chmod +x "$SCRIPT_DIR"/system/*.sh 2>/dev/null || true

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════╗"
echo -e "║     TW Mac Infrastructure Test Suite     ║"
echo -e "╚══════════════════════════════════════════╝${NC}"
echo ""
echo "Date: $(date)"
echo "Category: $CATEGORY"
echo ""

# Run tests based on category
case $CATEGORY in
    unit)
        run_category "unit"
        ;;
    integration)
        run_category "integration"
        ;;
    system)
        run_category "system"
        ;;
    all)
        run_category "unit"
        run_category "integration"
        run_category "system"
        ;;
esac

# Summary
echo -e "${BLUE}╔══════════════════════════════════════════╗"
echo -e "║            Test Suite Summary            ║"
echo -e "╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Test Suites Passed: $TOTAL_PASS${NC}"
echo -e "${RED}Test Suites Failed: $TOTAL_FAIL${NC}"
echo ""

if [ $TOTAL_FAIL -gt 0 ]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All test suites passed!${NC}"
    exit 0
fi
