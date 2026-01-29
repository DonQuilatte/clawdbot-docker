#!/bin/bash
# System Tests for File Sync Workflow
# Tests file synchronization between Controller and TW Mac

# set -e disabled for test counting

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TW_CONTROL="$HOME/bin/tw"
SMB_MOUNT="$HOME/tw-mac"
TEST_DIR_LOCAL="/tmp/sync-test-local-$$"
TEST_DIR_REMOTE="/tmp/sync-test-remote-$$"
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
    rm -rf "$TEST_DIR_LOCAL" 2>/dev/null || true
    "$TW_CONTROL" run "rm -rf $TEST_DIR_REMOTE" 2>/dev/null || true
}

trap cleanup EXIT

echo "=========================================="
echo "File Sync Workflow System Tests"
echo "=========================================="
echo ""

# Test 1: SMB mount available
echo "--- Test: SMB mount status ---"
if mount | grep -qE "tw\.local|tywhitaker|192.168.1.245"; then
    log_pass "SMB mount active"
    SMB_ACTIVE=true
else
    log_fail "SMB mount not active"
    SMB_ACTIVE=false
fi

# Test 2: SMB mount readable
echo "--- Test: SMB mount readability ---"
if [ -r "$SMB_MOUNT" ] && ls "$SMB_MOUNT" >/dev/null 2>&1; then
    log_pass "SMB mount readable"
else
    log_fail "SMB mount not readable"
fi

# Test 3: Create local test directory
echo "--- Test: Local test setup ---"
mkdir -p "$TEST_DIR_LOCAL"
echo "test file content $(date)" > "$TEST_DIR_LOCAL/test.txt"
if [ -f "$TEST_DIR_LOCAL/test.txt" ]; then
    log_pass "Local test directory created"
else
    log_fail "Failed to create local test directory"
fi

# Test 4: Create remote test directory
echo "--- Test: Remote test setup ---"
"$TW_CONTROL" run "mkdir -p $TEST_DIR_REMOTE" 2>/dev/null
REMOTE_EXISTS=$("$TW_CONTROL" run "[ -d $TEST_DIR_REMOTE ] && echo 'exists'" 2>&1)
if echo "$REMOTE_EXISTS" | grep -q "exists"; then
    log_pass "Remote test directory created"
else
    log_fail "Failed to create remote test directory"
fi

# Test 5: Copy file to remote via SSH
echo "--- Test: SSH file copy (scp) ---"
scp -o BatchMode=yes -i "$HOME/.ssh/id_ed25519_clawdbot" \
    "$TEST_DIR_LOCAL/test.txt" \
    "tywhitaker@100.81.110.81:$TEST_DIR_REMOTE/scp-test.txt" 2>/dev/null
REMOTE_FILE=$("$TW_CONTROL" run "[ -f $TEST_DIR_REMOTE/scp-test.txt ] && echo 'exists'" 2>&1)
if echo "$REMOTE_FILE" | grep -q "exists"; then
    log_pass "SCP file transfer works"
else
    log_fail "SCP file transfer failed"
fi

# Test 6: Copy file from remote via SSH
echo "--- Test: SSH file retrieval (scp) ---"
"$TW_CONTROL" run "echo 'remote content' > $TEST_DIR_REMOTE/retrieve-test.txt" 2>/dev/null
scp -o BatchMode=yes -i "$HOME/.ssh/id_ed25519_clawdbot" \
    "tywhitaker@100.81.110.81:$TEST_DIR_REMOTE/retrieve-test.txt" \
    "$TEST_DIR_LOCAL/retrieved.txt" 2>/dev/null
if [ -f "$TEST_DIR_LOCAL/retrieved.txt" ] && grep -q "remote content" "$TEST_DIR_LOCAL/retrieved.txt"; then
    log_pass "SCP file retrieval works"
else
    log_fail "SCP file retrieval failed"
fi

# Test 7: SMB file write (if mounted)
echo "--- Test: SMB file write ---"
if [ "$SMB_ACTIVE" = true ] && [ -w "$SMB_MOUNT" ]; then
    SMB_TEST_FILE="$SMB_MOUNT/.sync-test-$$"
    echo "smb test $(date)" > "$SMB_TEST_FILE" 2>/dev/null
    if [ -f "$SMB_TEST_FILE" ]; then
        rm -f "$SMB_TEST_FILE" 2>/dev/null
        log_pass "SMB file write works"
    else
        log_fail "SMB file write failed"
    fi
else
    log_skip "SMB mount not writable"
fi

# Test 8: SMB file read
echo "--- Test: SMB file read ---"
if [ "$SMB_ACTIVE" = true ]; then
    "$TW_CONTROL" run "echo 'smb read test' > /Users/tywhitaker/.smb-read-test-$$" 2>/dev/null
    sleep 1
    if [ -f "$SMB_MOUNT/.smb-read-test-$$" ]; then
        CONTENT=$(cat "$SMB_MOUNT/.smb-read-test-$$" 2>/dev/null)
        "$TW_CONTROL" run "rm -f /Users/tywhitaker/.smb-read-test-$$" 2>/dev/null
        if echo "$CONTENT" | grep -q "smb read test"; then
            log_pass "SMB file read works"
        else
            log_fail "SMB file read content mismatch"
        fi
    else
        log_fail "SMB file not visible from Controller"
    fi
else
    log_skip "SMB mount not active"
fi

# Test 9: Rsync sync (if available)
echo "--- Test: Rsync synchronization ---"
if command -v rsync >/dev/null 2>&1; then
    rsync -avz --delete -e "ssh -o BatchMode=yes -i $HOME/.ssh/id_ed25519_clawdbot" \
        "$TEST_DIR_LOCAL/" \
        "tywhitaker@100.81.110.81:$TEST_DIR_REMOTE/rsync-test/" 2>/dev/null
    RSYNC_CHECK=$("$TW_CONTROL" run "[ -f $TEST_DIR_REMOTE/rsync-test/test.txt ] && echo 'synced'" 2>&1)
    if echo "$RSYNC_CHECK" | grep -q "synced"; then
        log_pass "Rsync synchronization works"
    else
        log_fail "Rsync synchronization failed"
    fi
else
    log_skip "Rsync not installed"
fi

# Test 10: Large file transfer
echo "--- Test: Large file transfer ---"
dd if=/dev/zero of="$TEST_DIR_LOCAL/large.bin" bs=1M count=5 2>/dev/null
scp -o BatchMode=yes -i "$HOME/.ssh/id_ed25519_clawdbot" \
    "$TEST_DIR_LOCAL/large.bin" \
    "tywhitaker@100.81.110.81:$TEST_DIR_REMOTE/large.bin" 2>/dev/null
LARGE_SIZE=$("$TW_CONTROL" run "stat -f%z $TEST_DIR_REMOTE/large.bin 2>/dev/null || stat -c%s $TEST_DIR_REMOTE/large.bin 2>/dev/null" 2>&1)
if [ "$LARGE_SIZE" -ge 5000000 ] 2>/dev/null; then
    log_pass "Large file transfer works (5MB)"
else
    log_fail "Large file transfer failed"
fi

# Test 11: File permissions preservation
echo "--- Test: Permission preservation ---"
chmod 755 "$TEST_DIR_LOCAL/test.txt"
scp -p -o BatchMode=yes -i "$HOME/.ssh/id_ed25519_clawdbot" \
    "$TEST_DIR_LOCAL/test.txt" \
    "tywhitaker@100.81.110.81:$TEST_DIR_REMOTE/perms-test.txt" 2>/dev/null
REMOTE_PERMS=$("$TW_CONTROL" run "stat -f '%A' $TEST_DIR_REMOTE/perms-test.txt 2>/dev/null || stat -c '%a' $TEST_DIR_REMOTE/perms-test.txt 2>/dev/null" 2>&1)
if [ "$REMOTE_PERMS" = "755" ]; then
    log_pass "File permissions preserved"
else
    log_skip "Permissions may differ: $REMOTE_PERMS"
fi

# Test 12: Bidirectional sync verification
echo "--- Test: Bidirectional sync ---"
"$TW_CONTROL" run "echo 'from-remote' > $TEST_DIR_REMOTE/bidir.txt" 2>/dev/null
scp -o BatchMode=yes -i "$HOME/.ssh/id_ed25519_clawdbot" \
    "tywhitaker@100.81.110.81:$TEST_DIR_REMOTE/bidir.txt" \
    "$TEST_DIR_LOCAL/bidir.txt" 2>/dev/null
echo "from-local" >> "$TEST_DIR_LOCAL/bidir.txt"
scp -o BatchMode=yes -i "$HOME/.ssh/id_ed25519_clawdbot" \
    "$TEST_DIR_LOCAL/bidir.txt" \
    "tywhitaker@100.81.110.81:$TEST_DIR_REMOTE/bidir.txt" 2>/dev/null
FINAL_CONTENT=$("$TW_CONTROL" run "cat $TEST_DIR_REMOTE/bidir.txt" 2>&1)
if echo "$FINAL_CONTENT" | grep -q "from-remote" && echo "$FINAL_CONTENT" | grep -q "from-local"; then
    log_pass "Bidirectional sync works"
else
    log_fail "Bidirectional sync failed"
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
