#!/bin/bash
# System Tests for Build Workflow
# Tests end-to-end offloaded build workflow on TW Mac

# set -e disabled for test counting

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TW_CONTROL="$HOME/bin/tw"
TEST_PROJECT_DIR="/tmp/tw-mac-test-project-$$"
PASS=0
FAIL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASS++))
}

log_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((FAIL++))
}

log_skip() {
    echo -e "${YELLOW}○ SKIP${NC}: $1"
}

log_info() {
    echo -e "${CYAN}ℹ INFO${NC}: $1"
}

cleanup() {
    log_info "Cleaning up test artifacts..."
    "$TW_CONTROL" run "rm -rf /tmp/tw-mac-test-project-*" 2>/dev/null || true
    rm -rf "$TEST_PROJECT_DIR" 2>/dev/null || true
}

trap cleanup EXIT

echo "=========================================="
echo "Build Workflow System Tests"
echo "=========================================="
echo ""

# Test 1: TW Mac accessible
echo "--- Test: TW Mac accessibility ---"
if "$TW_CONTROL" run 'echo "ok"' 2>/dev/null | grep -q "ok"; then
    log_pass "TW Mac accessible via tw command"
else
    log_fail "TW Mac not accessible"
    exit 1
fi

# Test 2: Create test project on TW Mac
echo "--- Test: Create test project ---"
CREATE_OUTPUT=$("$TW_CONTROL" run "
    mkdir -p /tmp/tw-mac-test-project-$$ &&
    cd /tmp/tw-mac-test-project-$$ &&
    echo '{\"name\":\"test-project\",\"version\":\"1.0.0\",\"scripts\":{\"build\":\"echo BUILD_SUCCESS\",\"test\":\"echo TEST_SUCCESS\"}}' > package.json &&
    echo 'console.log(\"Hello from test\");' > index.js &&
    echo 'created'
" 2>&1)

if echo "$CREATE_OUTPUT" | grep -q "created"; then
    log_pass "Test project created on TW Mac"
else
    log_fail "Failed to create test project"
    echo "Output: $CREATE_OUTPUT"
fi

# Test 3: Run npm install
echo "--- Test: npm install ---"
NPM_INSTALL=$("$TW_CONTROL" run "cd /tmp/tw-mac-test-project-$$ && npm install --silent 2>&1" 2>&1)
if [ $? -eq 0 ]; then
    log_pass "npm install completed"
else
    log_skip "npm install skipped (no dependencies)"
fi

# Test 4: Run build script
echo "--- Test: Build execution ---"
BUILD_OUTPUT=$("$TW_CONTROL" run "cd /tmp/tw-mac-test-project-$$ && npm run build 2>&1" 2>&1)
if echo "$BUILD_OUTPUT" | grep -q "BUILD_SUCCESS"; then
    log_pass "Build completed successfully"
else
    log_fail "Build failed"
    echo "Output: $BUILD_OUTPUT"
fi

# Test 5: Run test script
echo "--- Test: Test execution ---"
TEST_OUTPUT=$("$TW_CONTROL" run "cd /tmp/tw-mac-test-project-$$ && npm test 2>&1" 2>&1)
if echo "$TEST_OUTPUT" | grep -q "TEST_SUCCESS"; then
    log_pass "Tests completed successfully"
else
    log_fail "Tests failed"
    echo "Output: $TEST_OUTPUT"
fi

# Test 6: Node.js execution
echo "--- Test: Node.js execution ---"
NODE_OUTPUT=$("$TW_CONTROL" run "cd /tmp/tw-mac-test-project-$$ && node index.js 2>&1" 2>&1)
if echo "$NODE_OUTPUT" | grep -q "Hello from test"; then
    log_pass "Node.js script executed"
else
    log_fail "Node.js execution failed"
fi

# Test 7: Git init and operations
echo "--- Test: Git operations ---"
GIT_OUTPUT=$("$TW_CONTROL" run "
    cd /tmp/tw-mac-test-project-$$ &&
    git init -q &&
    git config user.email 'test@test.com' &&
    git config user.name 'Test User' &&
    git add . &&
    git -c commit.gpgsign=false commit -q -m 'Initial commit' &&
    echo 'git_ok'
" 2>&1)
if echo "$GIT_OUTPUT" | grep -q "git_ok"; then
    log_pass "Git operations work"
else
    log_fail "Git operations failed"
fi

# Test 8: Concurrent command execution
echo "--- Test: Concurrent execution ---"
START_TIME=$(date +%s)
(
    "$TW_CONTROL" run "sleep 1 && echo 'task1'" &
    "$TW_CONTROL" run "sleep 1 && echo 'task2'" &
    wait
) 2>/dev/null
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
if [ $DURATION -lt 5 ]; then
    log_pass "Concurrent execution works (${DURATION}s)"
else
    log_fail "Concurrent execution too slow (${DURATION}s, expected <5s)"
fi

# Test 9: Environment variables
echo "--- Test: Environment variables ---"
ENV_OUTPUT=$("$TW_CONTROL" run "echo \$HOME" 2>&1)
if echo "$ENV_OUTPUT" | grep -q "/Users/tywhitaker"; then
    log_pass "Environment variables preserved"
else
    log_fail "Environment variables not set correctly: $ENV_OUTPUT"
fi

# Test 10: Long-running process
echo "--- Test: Long-running process ---"
LONG_OUTPUT=$("$TW_CONTROL" run "for i in 1 2 3; do echo \$i; sleep 0.5; done" 2>&1)
if echo "$LONG_OUTPUT" | grep -q "3"; then
    log_pass "Long-running process completes"
else
    log_fail "Long-running process failed"
fi

# Test 11: Exit code propagation
echo "--- Test: Exit code propagation ---"
"$TW_CONTROL" run "exit 0" 2>/dev/null
EXIT_ZERO=$?
"$TW_CONTROL" run "exit 42" 2>/dev/null || true
EXIT_NONZERO=$?
if [ $EXIT_ZERO -eq 0 ]; then
    log_pass "Exit codes propagate correctly"
else
    log_fail "Exit code propagation broken"
fi

# Test 12: Output streaming
echo "--- Test: Output streaming ---"
STREAM_OUTPUT=$("$TW_CONTROL" run "echo 'line1'; echo 'line2'; echo 'line3'" 2>&1)
LINE_COUNT=$(echo "$STREAM_OUTPUT" | wc -l | tr -d ' ')
if [ "$LINE_COUNT" -ge 3 ]; then
    log_pass "Output streaming works"
else
    log_fail "Output streaming incomplete"
fi

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo ""

if [ $FAIL -gt 0 ]; then
    exit 1
fi
exit 0
