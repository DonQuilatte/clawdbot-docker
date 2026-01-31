#!/bin/bash
# Integration Tests for SMB Mount
# Tests SMB file sharing connectivity to TW Mac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SMB_MOUNT="$HOME/tw-mac"
PASS=0
FAIL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

echo "=========================================="
echo "SMB Mount Integration Tests"
echo "=========================================="
echo ""

# Test 1: SMB mount point exists
echo "--- Test: Mount point exists ---"
if [ -e "$SMB_MOUNT" ]; then
    log_pass "Mount point exists at $SMB_MOUNT"
else
    log_fail "Mount point not found at $SMB_MOUNT"
fi

# Test 2: Check if symlink or mount
echo "--- Test: Mount point type ---"
if [ -L "$SMB_MOUNT" ]; then
    SYMLINK_TARGET=$(readlink "$SMB_MOUNT")
    log_pass "Symlink to: $SYMLINK_TARGET"
elif [ -d "$SMB_MOUNT" ]; then
    log_pass "Directory mount point"
else
    log_fail "Unexpected mount point type"
fi

# Test 3: SMB mount active
echo "--- Test: SMB mount active ---"
if mount | grep -qiE "192.168.1.245|tw\.local|tywhitaker"; then
    log_pass "SMB mount is active"
    SMB_ACTIVE=true
else
    log_fail "SMB mount not active"
    SMB_ACTIVE=false
fi

# Test 4: Mount is readable
echo "--- Test: Mount readability ---"
if [ -r "$SMB_MOUNT" ]; then
    log_pass "Mount is readable"
else
    log_fail "Mount is not readable"
fi

# Test 5: Mount is writable
echo "--- Test: Mount writability ---"
if [ -w "$SMB_MOUNT" ]; then
    log_pass "Mount is writable"
else
    log_fail "Mount is not writable"
fi

# Test 6: Development directory accessible
echo "--- Test: Development directory ---"
if [ -d "$SMB_MOUNT/Development" ]; then
    log_pass "Development directory accessible"
else
    log_fail "Development directory not accessible"
fi

# Test 7: Projects directory accessible
echo "--- Test: Projects directory ---"
if [ -d "$SMB_MOUNT/Development/Projects" ]; then
    log_pass "Projects directory accessible"
else
    log_skip "Projects directory not accessible (may not exist)"
fi

# Test 8: File listing works
echo "--- Test: File listing ---"
if ls "$SMB_MOUNT" >/dev/null 2>&1; then
    FILE_COUNT=$(ls -1 "$SMB_MOUNT" 2>/dev/null | wc -l | tr -d ' ')
    log_pass "File listing works ($FILE_COUNT items)"
else
    log_fail "File listing failed"
fi

# Test 9: File read test
echo "--- Test: File read ---"
TEST_FILE="$SMB_MOUNT/.zshrc"
if [ -f "$TEST_FILE" ]; then
    if head -1 "$TEST_FILE" >/dev/null 2>&1; then
        log_pass "Can read files from mount"
    else
        log_fail "Cannot read files from mount"
    fi
else
    log_skip "Test file not found, skipping read test"
fi

# Test 10: Write test (create temp file)
echo "--- Test: File write ---"
WRITE_TEST_FILE="$SMB_MOUNT/.smb-write-test-$$"
if echo "test" > "$WRITE_TEST_FILE" 2>/dev/null; then
    rm -f "$WRITE_TEST_FILE" 2>/dev/null
    log_pass "Can write files to mount"
else
    log_fail "Cannot write files to mount"
fi

# Test 11: Large file access
echo "--- Test: Large file access ---"
LARGE_FILES=$(find "$SMB_MOUNT" -maxdepth 2 -size +1M -type f 2>/dev/null | head -1)
if [ -n "$LARGE_FILES" ]; then
    log_pass "Can access larger files"
else
    log_skip "No large files found to test"
fi

# Test 12: DesktopCommanderMCP accessible
echo "--- Test: DesktopCommanderMCP directory ---"
if [ -d "$SMB_MOUNT/Development/DesktopCommanderMCP" ]; then
    log_pass "DesktopCommanderMCP accessible via SMB"
else
    log_skip "DesktopCommanderMCP not found via SMB"
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
