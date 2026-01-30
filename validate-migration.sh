#!/usr/bin/env bash
# Phase A Migration Validation Test
# Tests that the mechanical migration executed correctly

set -e  # Exit on any error

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Phase A Migration Validation Test                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# Helper functions
pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
    ((PASS_COUNT++)) || true
}

fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    ((FAIL_COUNT++)) || true
}

warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}: $1"
    ((WARN_COUNT++)) || true
}

# Test 1: Repository renamed
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 1: Repository Renamed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -d "/Users/jederlichman/Development/Projects/dev-infra" ]; then
    pass "dev-infra directory exists"
else
    fail "dev-infra directory not found"
fi

if [ -d "/Users/jederlichman/Development/Projects/ClawdBot" ]; then
    fail "Old ClawdBot directory still exists (should be renamed)"
else
    pass "Old ClawdBot directory removed"
fi

echo ""

# Test 2: mcp-deployment consolidated
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 2: mcp-deployment Consolidated"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -d "/Users/jederlichman/Development/Projects/dev-infra/mcp" ]; then
    pass "mcp/ directory exists"
else
    fail "mcp/ directory not found"
fi

if [ -f "/Users/jederlichman/Development/Projects/dev-infra/mcp/scripts/project-setup.sh" ]; then
    pass "mcp/scripts/project-setup.sh exists"
else
    fail "mcp/scripts/project-setup.sh not found"
fi

if [ -f "/Users/jederlichman/Development/Projects/dev-infra/mcp/README.md" ]; then
    pass "mcp/README.md exists"
else
    fail "mcp/README.md not found"
fi

# Count files in mcp/
MCP_FILE_COUNT=$(find /Users/jederlichman/Development/Projects/dev-infra/mcp -type f 2>/dev/null | wc -l | xargs)
if [ "$MCP_FILE_COUNT" -gt 5 ]; then
    pass "mcp/ contains $MCP_FILE_COUNT files (sufficient content)"
else
    fail "mcp/ only contains $MCP_FILE_COUNT files (may be incomplete)"
fi

echo ""

# Test 3: Path references updated
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 3: Path References Updated"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd /Users/jederlichman/Development/Projects/dev-infra

# Check for old mcp-deployment references
OLD_MCP_REFS=$(grep -r "/Users/jederlichman/Development/mcp-deployment" . \
    --exclude-dir={node_modules,.git} \
    --exclude="*.md" \
    --exclude="DEPENDENCY_INVENTORY.txt" \
    --exclude="*backup*" \
    --exclude="validate-migration.sh" \
    2>/dev/null | wc -l | xargs)

if [ "$OLD_MCP_REFS" -eq 0 ]; then
    pass "No old mcp-deployment absolute paths found"
else
    fail "Found $OLD_MCP_REFS old mcp-deployment absolute path references"
    echo "   Run: grep -r '/Users/jederlichman/Development/mcp-deployment' . --exclude-dir={node_modules,.git}"
fi

# Check for old ClawdBot references in code (not docs)
OLD_CLAWDBOT_REFS=$(grep -r "ClawdBot" . \
    --exclude-dir={node_modules,.git} \
    --exclude="*.md" \
    --exclude="DEPENDENCY_INVENTORY.txt" \
    --exclude="*backup*" \
    --exclude="CLAWDBOT_REFERENCES_ALLOWLIST.txt" \
    --exclude="validate-migration.sh" \
    2>/dev/null | wc -l | xargs)

if [ "$OLD_CLAWDBOT_REFS" -eq 0 ]; then
    pass "No ClawdBot references in code files"
else
    warn "Found $OLD_CLAWDBOT_REFS ClawdBot references (check if in allowlist)"
fi

# Check .envrc doesn't have hardcoded PROJECT_ROOT
if [ -f ".envrc" ]; then
    if grep -q "PROJECT_ROOT=\"/Users/jederlichman" .envrc 2>/dev/null; then
        fail ".envrc has hardcoded PROJECT_ROOT"
    else
        pass ".envrc does not hardcode PROJECT_ROOT"
    fi
fi

echo ""

# Test 4: Git status
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 4: Git Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if git rev-parse --git-dir > /dev/null 2>&1; then
    pass "Git repository exists"
    
    # Check if on migration branch
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [ "$CURRENT_BRANCH" = "phase-a-mechanical-migration" ] || [ "$CURRENT_BRANCH" = "main" ]; then
        pass "On branch '$CURRENT_BRANCH'"
    else
        warn "On branch '$CURRENT_BRANCH' (expected: phase-a-mechanical-migration or main)"
    fi
    
    # Check for v2.0.0-alpha tag
    if git tag | grep -q "v2.0.0-alpha"; then
        pass "v2.0.0-alpha tag exists"
    else
        fail "v2.0.0-alpha tag not found"
    fi
    
    # Check commit count on branch
    COMMIT_COUNT=$(git rev-list --count phase-a-mechanical-migration 2>/dev/null || echo "0")
    if [ "$COMMIT_COUNT" -ge 6 ]; then
        pass "Branch has $COMMIT_COUNT commits (expected 6+ for all phases)"
    else
        warn "Branch has only $COMMIT_COUNT commits (expected 6+)"
    fi
else
    fail "Not a git repository"
fi

echo ""

# Test 5: Documentation updated
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 5: Documentation Updated"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "README.md" ]; then
    if grep -q "dev-infra" README.md; then
        pass "README.md mentions dev-infra"
    else
        fail "README.md does not mention dev-infra"
    fi
    
    if grep -q "ClawdBot" README.md && grep -q "Previously" README.md; then
        pass "README.md references previous name"
    else
        warn "README.md should reference previous ClawdBot name"
    fi
else
    fail "README.md not found"
fi

if [ -f "MIGRATION.md" ]; then
    pass "MIGRATION.md exists"
    
    if grep -q "ClawdBot" MIGRATION.md && grep -q "dev-infra" MIGRATION.md; then
        pass "MIGRATION.md documents rename"
    else
        fail "MIGRATION.md missing rename documentation"
    fi
else
    fail "MIGRATION.md not found"
fi

echo ""

# Test 6: Clean checkout test
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 6: Clean Checkout Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TEST_DIR="/tmp/dev-infra-validation-$$"
if [ -d "$TEST_DIR" ]; then
    rm -rf "$TEST_DIR"
fi

echo "Cloning to temporary directory: $TEST_DIR"
if git clone /Users/jederlichman/Development/Projects/dev-infra "$TEST_DIR" > /dev/null 2>&1; then
    pass "Repository can be cloned"
    
    cd "$TEST_DIR"
    git checkout "$CURRENT_BRANCH" > /dev/null 2>&1
    
    if [ -f "mcp/scripts/project-setup.sh" ]; then
        pass "project-setup.sh exists in clean checkout"
    else
        fail "project-setup.sh missing in clean checkout"
    fi
    
    cd - > /dev/null
    rm -rf "$TEST_DIR"
else
    fail "Could not clone repository"
fi

echo ""

# Test 7: Test deployment
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 7: Test Deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TEST_PROJECT="/tmp/test-migration-deploy-$$"
if [ -d "$TEST_PROJECT" ]; then
    rm -rf "$TEST_PROJECT"
fi

mkdir -p "$TEST_PROJECT"
cd "$TEST_PROJECT"

echo "Deploying to test project: $TEST_PROJECT"
if yes "" | bash /Users/jederlichman/Development/Projects/dev-infra/mcp/scripts/project-setup.sh test-migration > /dev/null 2>&1; then
    pass "Deployment script executed"
    
    # Check created files
    if [ -f ".antigravity/config.json" ]; then
        pass "Created .antigravity/config.json"
    else
        fail "Missing .antigravity/config.json"
    fi
    
    if [ -f "scripts/mcp-gitkraken" ]; then
        pass "Created scripts/mcp-gitkraken"
    else
        fail "Missing scripts/mcp-gitkraken"
    fi
    
    if [ -f "scripts/mcp-filesystem" ]; then
        pass "Created scripts/mcp-filesystem"
    else
        fail "Missing scripts/mcp-filesystem"
    fi
    
    # Run validation if available
    if [ -f "scripts/validate-mcp.sh" ]; then
        echo "Running MCP validation..."
        if bash scripts/validate-mcp.sh > /tmp/validation-output-$$ 2>&1; then
            PASS_TESTS=$(grep -o "[0-9]\+ passed" /tmp/validation-output-$$ | grep -o "[0-9]\+")
            if [ -n "$PASS_TESTS" ] && [ "$PASS_TESTS" -ge 6 ]; then
                pass "MCP validation passed ($PASS_TESTS tests)"
            else
                warn "MCP validation completed but may have issues"
            fi
        else
            warn "MCP validation script failed (may need setup)"
        fi
        rm -f /tmp/validation-output-$$
    fi
else
    fail "Deployment script failed"
fi

cd - > /dev/null
rm -rf "$TEST_PROJECT"

echo ""

# Test 8: Existing project validation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 8: Existing Project (iphone-tco-planner)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

EXISTING_PROJECT="/Users/jederlichman/Development/Projects/iphone-tco-planner"

if [ -d "$EXISTING_PROJECT" ]; then
    pass "iphone-tco-planner exists"
    
    cd "$EXISTING_PROJECT"
    
    if [ -f "scripts/validate-mcp.sh" ]; then
        echo "Running validation on existing project..."
        if bash scripts/validate-mcp.sh > /tmp/existing-validation-$$ 2>&1; then
            EXISTING_PASS=$(grep -o "[0-9]\+ passed" /tmp/existing-validation-$$ | grep -o "[0-9]\+")
            if [ -n "$EXISTING_PASS" ] && [ "$EXISTING_PASS" -ge 6 ]; then
                pass "Existing project still validates ($EXISTING_PASS tests pass)"
            else
                fail "Existing project validation degraded"
                cat /tmp/existing-validation-$$
            fi
        else
            fail "Existing project validation failed"
            cat /tmp/existing-validation-$$
        fi
        rm -f /tmp/existing-validation-$$
    else
        warn "No validation script in existing project"
    fi
    
    cd - > /dev/null
else
    warn "iphone-tco-planner not found (skip test)"
fi

echo ""

# Test 9: Backup verification
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 9: Backup Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

BACKUP_DIR="/Users/jederlichman/Development/Projects"
CLAWDBOT_BACKUPS=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "ClawdBot-backup-*" 2>/dev/null | wc -l | xargs)
MCP_BACKUPS=$(find /Users/jederlichman/Development -maxdepth 1 -type d -name "mcp-deployment-backup-*" 2>/dev/null | wc -l | xargs)

if [ "$CLAWDBOT_BACKUPS" -gt 0 ]; then
    pass "Found $CLAWDBOT_BACKUPS ClawdBot backup(s)"
else
    warn "No ClawdBot backups found (should exist for rollback)"
fi

if [ "$MCP_BACKUPS" -gt 0 ]; then
    pass "Found $MCP_BACKUPS mcp-deployment backup(s)"
else
    warn "No mcp-deployment backups found (should exist for rollback)"
fi

echo ""

# Test 10: Rollback readiness
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 10: Rollback Readiness"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "/Users/jederlichman/Development/Projects/dev-infra/ROLLBACK.md" ]; then
    pass "ROLLBACK.md exists"
else
    warn "ROLLBACK.md not found"
fi

# Verify latest backup has content
if [ "$CLAWDBOT_BACKUPS" -gt 0 ]; then
    LATEST_BACKUP=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "ClawdBot-backup-*" 2>/dev/null | sort -r | head -1)
    if [ -d "$LATEST_BACKUP/scripts" ]; then
        pass "Latest backup has scripts/ directory"
    else
        fail "Latest backup missing scripts/ directory"
    fi
fi

echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Results:"
echo "  ${GREEN}✅ PASS: $PASS_COUNT${NC}"
echo "  ${RED}❌ FAIL: $FAIL_COUNT${NC}"
echo "  ${YELLOW}⚠️  WARN: $WARN_COUNT${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ ALL CRITICAL TESTS PASSED                              ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Phase A migration validation: SUCCESS"
    echo ""
    if [ $WARN_COUNT -gt 0 ]; then
        echo "Note: $WARN_COUNT warnings found (review above)"
    fi
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ❌ VALIDATION FAILED                                      ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Phase A migration validation: FAILED"
    echo ""
    echo "Critical failures found. Review errors above."
    echo "Consider rollback if issues cannot be resolved."
    exit 1
fi
