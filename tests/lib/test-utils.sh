#!/bin/bash
# Test utility functions
# Source this file in test scripts

# Determine project root
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
fi

# Source common library for colors and shared functions
# shellcheck source=../../scripts/lib/common.sh
source "$PROJECT_ROOT/scripts/lib/common.sh"

print_test() {
    echo -e "  ${YELLOW}TEST:${NC} $1"
}

print_pass() {
    echo -e "  ${GREEN}✓ PASS:${NC} $1"
}

print_fail() {
    echo -e "  ${RED}✗ FAIL:${NC} $1"
}

print_skip() {
    echo -e "  ${YELLOW}⊘ SKIP:${NC} $1"
}

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
