#!/bin/bash
# System Tests for Agent Workflow
# Tests AI agent operations via Desktop Commander MCP

# set -e disabled for test counting

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TW_CONTROL="$HOME/bin/tw"
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

echo "=========================================="
echo "Agent Workflow System Tests"
echo "=========================================="
echo ""

# Test 1: MCP session exists
echo "--- Test: MCP tmux session ---"
MCP_SESSION=$("$TW_CONTROL" run "tmux has-session -t mcp 2>/dev/null && echo 'exists' || echo 'missing'" 2>&1)
if echo "$MCP_SESSION" | grep -q "exists"; then
    log_pass "MCP tmux session exists"
else
    log_info "Starting MCP session..."
    "$TW_CONTROL" start-mcp 2>/dev/null || true
    sleep 2
    MCP_SESSION=$("$TW_CONTROL" run "tmux has-session -t mcp 2>/dev/null && echo 'exists' || echo 'missing'" 2>&1)
    if echo "$MCP_SESSION" | grep -q "exists"; then
        log_pass "MCP tmux session started"
    else
        log_fail "Could not start MCP session"
    fi
fi

# Test 2: DesktopCommanderMCP directory exists
echo "--- Test: DesktopCommanderMCP installation ---"
MCP_DIR=$("$TW_CONTROL" run "[ -d ~/Development/DesktopCommanderMCP ] && echo 'exists'" 2>&1)
if echo "$MCP_DIR" | grep -q "exists"; then
    log_pass "DesktopCommanderMCP installed"
else
    log_fail "DesktopCommanderMCP not found"
fi

# Test 3: MCP dist/index.js exists
echo "--- Test: MCP build artifacts ---"
MCP_INDEX=$("$TW_CONTROL" run "[ -f ~/Development/DesktopCommanderMCP/dist/index.js ] && echo 'exists'" 2>&1)
if echo "$MCP_INDEX" | grep -q "exists"; then
    log_pass "MCP build artifacts exist"
else
    log_fail "MCP not built (dist/index.js missing)"
fi

# Test 4: tmux sessions listing
echo "--- Test: tmux session management ---"
TMUX_LIST=$("$TW_CONTROL" run "tmux list-sessions 2>/dev/null" 2>&1)
if [ -n "$TMUX_LIST" ]; then
    SESSION_COUNT=$(echo "$TMUX_LIST" | wc -l | tr -d ' ')
    log_pass "tmux sessions accessible ($SESSION_COUNT active)"
else
    log_skip "No tmux sessions active"
fi

# Test 5: Create and destroy test session
echo "--- Test: tmux session lifecycle ---"
"$TW_CONTROL" run "tmux new-session -d -s test-agent-$$ 'sleep 60'" 2>/dev/null
sleep 1
SESSION_EXISTS=$("$TW_CONTROL" run "tmux has-session -t test-agent-$$ 2>/dev/null && echo 'yes'" 2>&1)
if echo "$SESSION_EXISTS" | grep -q "yes"; then
    "$TW_CONTROL" run "tmux kill-session -t test-agent-$$" 2>/dev/null
    log_pass "tmux session lifecycle works"
else
    log_fail "Could not create tmux session"
fi

# Test 6: File operations via agent
echo "--- Test: File operations ---"
TEST_FILE="/tmp/agent-test-$$"
"$TW_CONTROL" run "echo 'test content' > $TEST_FILE" 2>/dev/null
FILE_CONTENT=$("$TW_CONTROL" run "cat $TEST_FILE 2>/dev/null" 2>&1)
"$TW_CONTROL" run "rm -f $TEST_FILE" 2>/dev/null
if echo "$FILE_CONTENT" | grep -q "test content"; then
    log_pass "File operations work"
else
    log_fail "File operations failed"
fi

# Test 7: Process management
echo "--- Test: Process management ---"
PROC_LIST=$("$TW_CONTROL" run "ps aux | head -5" 2>&1)
if [ -n "$PROC_LIST" ]; then
    log_pass "Process listing works"
else
    log_fail "Process listing failed"
fi

# Test 8: Background process execution
echo "--- Test: Background process ---"
"$TW_CONTROL" run "nohup sleep 5 > /dev/null 2>&1 &" 2>/dev/null
BG_PROC=$("$TW_CONTROL" run "pgrep -f 'sleep 5' | head -1" 2>&1)
if [ -n "$BG_PROC" ]; then
    "$TW_CONTROL" run "pkill -f 'sleep 5'" 2>/dev/null || true
    log_pass "Background process execution works"
else
    log_skip "Background process may have completed"
fi

# Test 9: Claude CLI availability
echo "--- Test: Claude CLI ---"
CLAUDE_PATH=$("$TW_CONTROL" run "which claude 2>/dev/null" 2>&1)
if [ -n "$CLAUDE_PATH" ]; then
    log_pass "Claude CLI available at: $CLAUDE_PATH"
else
    log_fail "Claude CLI not found"
fi

# Test 10: Environment for AI operations
echo "--- Test: AI environment ---"
ENV_CHECK=$("$TW_CONTROL" run "
    [ -d ~/Development ] && echo 'dev_ok'
    [ -d ~/.claude ] && echo 'claude_ok'
    which node >/dev/null && echo 'node_ok'
" 2>&1)
if echo "$ENV_CHECK" | grep -q "dev_ok" && echo "$ENV_CHECK" | grep -q "node_ok"; then
    log_pass "AI development environment configured"
else
    log_fail "AI environment incomplete"
fi

# Test 11: MCP health check
echo "--- Test: MCP health ---"
MCP_RUNNING=$("$TW_CONTROL" run "pgrep -f 'DesktopCommanderMCP' >/dev/null && echo 'running'" 2>&1)
if echo "$MCP_RUNNING" | grep -q "running"; then
    log_pass "MCP process running"
else
    log_skip "MCP process not detected (may be in tmux only)"
fi

# Test 12: Inter-session communication
echo "--- Test: Inter-session communication ---"
COMM_TEST=$("$TW_CONTROL" run "
    echo 'message' > /tmp/ipc-test-$$
    cat /tmp/ipc-test-$$
    rm /tmp/ipc-test-$$
" 2>&1)
if echo "$COMM_TEST" | grep -q "message"; then
    log_pass "Inter-session file IPC works"
else
    log_fail "Inter-session communication failed"
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
