#!/bin/bash
# Integration tests for environment sync and distributed development
# Tests Phase 1-5 implementation

PASS=0
FAIL=0
SKIP=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

log_pass() { echo -e "${GREEN}✓ PASS${NC}: $1"; PASS=$((PASS + 1)); }
log_fail() { echo -e "${RED}✗ FAIL${NC}: $1"; FAIL=$((FAIL + 1)); }
log_skip() { echo -e "${YELLOW}○ SKIP${NC}: $1"; SKIP=$((SKIP + 1)); }

echo "=========================================="
echo "Environment Sync & Distributed Dev Tests"
echo "=========================================="
echo ""

# ==========================================
# Phase 1: Sync Scripts
# ==========================================
echo "--- Phase 1: Sync Scripts ---"

# Test 1.1: tw-env-sync exists and is executable
if [ -x "$HOME/bin/tw-env-sync" ]; then
    log_pass "tw-env-sync script exists and is executable"
else
    log_fail "tw-env-sync script missing or not executable"
fi

# Test 1.2: tw-sync-config exists and is executable
if [ -x "$HOME/bin/tw-sync-config" ]; then
    log_pass "tw-sync-config script exists and is executable"
else
    log_fail "tw-sync-config script missing or not executable"
fi

# Test 1.3: Scripts are symlinked to infrastructure
if [ -L "$HOME/bin/tw-env-sync" ]; then
    TARGET=$(readlink "$HOME/bin/tw-env-sync")
    if [[ "$TARGET" == *"infrastructure/tw-mac"* ]]; then
        log_pass "tw-env-sync properly symlinked to infrastructure"
    else
        log_fail "tw-env-sync symlink points to wrong location: $TARGET"
    fi
else
    log_fail "tw-env-sync is not a symlink"
fi

echo ""

# ==========================================
# Phase 2: Handoff System
# ==========================================
echo "--- Phase 2: Handoff System ---"

# Test 2.1: tw-handoff exists
if [ -x "$HOME/bin/tw-handoff" ]; then
    log_pass "tw-handoff script exists and is executable"
else
    log_fail "tw-handoff script missing or not executable"
fi

# Test 2.2: Handoffs directory exists and is accessible
if [ -d "$HOME/tw-mac/handoffs" ]; then
    log_pass "Handoffs directory exists locally"
else
    log_fail "Handoffs directory not found at ~/tw-mac/handoffs"
fi

# Test 2.3: TW Mac has read-handoff
TW_READ=$(ssh tw '[ -x ~/bin/read-handoff ] && echo "yes" || echo "no"' 2>/dev/null)
if [ "$TW_READ" = "yes" ]; then
    log_pass "TW Mac has read-handoff script"
else
    log_fail "TW Mac missing read-handoff script"
fi

# Test 2.4: TW Mac has report-back
TW_REPORT=$(ssh tw '[ -x ~/bin/report-back ] && echo "yes" || echo "no"' 2>/dev/null)
if [ "$TW_REPORT" = "yes" ]; then
    log_pass "TW Mac has report-back script"
else
    log_fail "TW Mac missing report-back script"
fi

# Test 2.5: TW Mac handoffs directory exists
TW_HANDOFF_DIR=$(ssh tw '[ -d ~/handoffs ] && echo "yes" || echo "no"' 2>/dev/null)
if [ "$TW_HANDOFF_DIR" = "yes" ]; then
    log_pass "TW Mac handoffs directory exists"
else
    log_fail "TW Mac handoffs directory missing"
fi

echo ""

# ==========================================
# Phase 3: Orchestration Skills
# ==========================================
echo "--- Phase 3: Orchestration Skills ---"

# Test 3.1: tw-task skill exists
if [ -f "$HOME/.claude/commands/tw-task.md" ]; then
    log_pass "/tw-task skill exists"
else
    log_fail "/tw-task skill missing"
fi

# Test 3.2: tw-status skill exists
if [ -f "$HOME/.claude/commands/tw-status.md" ]; then
    log_pass "/tw-status skill exists"
else
    log_fail "/tw-status skill missing"
fi

# Test 3.3: tw-collect skill exists
if [ -f "$HOME/.claude/commands/tw-collect.md" ]; then
    log_pass "/tw-collect skill exists"
else
    log_fail "/tw-collect skill missing"
fi

# Test 3.4: Skills synced to TW Mac
LOCAL_SKILLS=$(ls "$HOME/.claude/commands" 2>/dev/null | wc -l | tr -d ' ')
REMOTE_SKILLS=$(ssh tw 'ls ~/.claude/commands 2>/dev/null | wc -l | tr -d " "' 2>/dev/null || echo "0")
if [ "$LOCAL_SKILLS" = "$REMOTE_SKILLS" ]; then
    log_pass "Skills count matches ($LOCAL_SKILLS local, $REMOTE_SKILLS remote)"
else
    log_fail "Skills count mismatch (local: $LOCAL_SKILLS, remote: $REMOTE_SKILLS)"
fi

echo ""

# ==========================================
# Phase 4: CLAUDE.md Configuration
# ==========================================
echo "--- Phase 4: CLAUDE.md Configuration ---"

# Test 4.1: Controller CLAUDE.md has distributed dev section
if grep -q "Distributed Development" "$HOME/.claude/CLAUDE.md" 2>/dev/null; then
    log_pass "Controller CLAUDE.md has distributed development section"
else
    log_fail "Controller CLAUDE.md missing distributed development section"
fi

# Test 4.2: TW Mac has worker-specific CLAUDE.md
TW_WORKER=$(ssh tw 'grep -q "Worker Node" ~/.claude/CLAUDE.md 2>/dev/null && echo "yes" || echo "no"' 2>/dev/null)
if [ "$TW_WORKER" = "yes" ]; then
    log_pass "TW Mac has worker-specific CLAUDE.md"
else
    log_fail "TW Mac CLAUDE.md is not worker-specific"
fi

# Test 4.3: CLAUDE.md files are intentionally different
LOCAL_HASH=$(md5 -q "$HOME/.claude/CLAUDE.md" 2>/dev/null)
REMOTE_HASH=$(ssh tw 'md5 -q ~/.claude/CLAUDE.md 2>/dev/null' 2>/dev/null)
if [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
    log_pass "CLAUDE.md files are different (as expected)"
else
    log_fail "CLAUDE.md files are identical (should be different)"
fi

echo ""

# ==========================================
# Phase 5: Health Monitor
# ==========================================
echo "--- Phase 5: Health Monitor ---"

# Test 5.1: Health monitor has config sync check
if grep -q "check_config_sync" "$HOME/Development/Projects/clawdbot/infrastructure/tw-mac/tw-health-monitor.sh" 2>/dev/null; then
    log_pass "Health monitor has config sync check"
else
    log_fail "Health monitor missing config sync check"
fi

# Test 5.2: Health monitor has pending handoffs check
if grep -q "check_pending_handoffs" "$HOME/Development/Projects/clawdbot/infrastructure/tw-mac/tw-health-monitor.sh" 2>/dev/null; then
    log_pass "Health monitor has pending handoffs check"
else
    log_fail "Health monitor missing pending handoffs check"
fi

# Test 5.3: Health monitor has orphan sessions check
if grep -q "check_orphan_sessions" "$HOME/Development/Projects/clawdbot/infrastructure/tw-mac/tw-health-monitor.sh" 2>/dev/null; then
    log_pass "Health monitor has orphan sessions check"
else
    log_fail "Health monitor missing orphan sessions check"
fi

echo ""

# ==========================================
# Functional Tests
# ==========================================
echo "--- Functional Tests ---"

# Test F1: Can create a handoff
TEST_HANDOFF=$("$HOME/bin/tw-handoff" "Integration test" "Automated test" "No action needed" 2>&1)
if echo "$TEST_HANDOFF" | grep -q "Handoff created"; then
    log_pass "Can create handoff files"
    # Extract handoff ID for cleanup
    TEST_ID=$(echo "$TEST_HANDOFF" | grep "Handoff ID:" | awk '{print $NF}')
else
    log_fail "Failed to create handoff file"
fi

# Test F2: TW Mac can read handoff
if [ -n "$TEST_ID" ]; then
    TW_CAN_READ=$(ssh tw "~/bin/read-handoff $TEST_ID 2>/dev/null | grep -q 'Integration test' && echo 'yes' || echo 'no'" 2>/dev/null)
    if [ "$TW_CAN_READ" = "yes" ]; then
        log_pass "TW Mac can read handoff files"
    else
        log_fail "TW Mac cannot read handoff files"
    fi
fi

# Test F3: TW Mac can report back
if [ -n "$TEST_ID" ]; then
    ssh tw "~/bin/report-back $TEST_ID 'Test response from integration test'" 2>/dev/null
    sleep 1
    if [ -f "$HOME/tw-mac/handoffs/response-$TEST_ID.md" ]; then
        log_pass "TW Mac report-back creates response file"
    else
        log_fail "TW Mac report-back did not create response file"
    fi
fi

# Cleanup test files
if [ -n "$TEST_ID" ]; then
    rm -f "$HOME/tw-mac/handoffs/handoff-$TEST_ID.md" 2>/dev/null
    rm -f "$HOME/tw-mac/handoffs/response-$TEST_ID.md" 2>/dev/null
fi

echo ""
echo "=========================================="
echo -e "Results: ${GREEN}$PASS passed${NC} | ${RED}$FAIL failed${NC} | ${YELLOW}$SKIP skipped${NC}"
echo "=========================================="

[ $FAIL -gt 0 ] && exit 1
exit 0
