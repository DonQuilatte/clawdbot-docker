#!/bin/bash
# tests/system/test-brain-agent-e2e.sh
# Brain/Agent E2E System Test
# Run from Brain: ./tests/system/test-brain-agent-e2e.sh
#
# Requirements:
#   - SSH access to Agent Alpha (tw)
#   - agent command in PATH
#   - Claude Code installed on Agent Alpha
#
# Optional:
#   - SMB mount for faster file access (Finder: Cmd+K → smb://192.168.1.245/tywhitaker)
#
# CI: Triggered manually via GitHub Actions workflow brain-agent-e2e.yml

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/scripts/lib/common.sh"

# Test configuration
AGENT_HOST="tw"
TEST_SESSION="e2e-test-$$"
TEST_BRANCH="test/e2e-string-utils-$$"
TIMEOUT=120

# Results tracking
PHASES_PASSED=0
PHASES_TOTAL=7
START_TIME=$(date +%s)

print_header "Brain/Agent E2E System Test"
echo "Session: $TEST_SESSION"
echo "Branch: $TEST_BRANCH"
echo ""

#------------------------------------------------------------------------------
# Phase 1: Connectivity
#------------------------------------------------------------------------------
print_section "Phase 1: Connectivity Check"

if agent status &>/dev/null; then
    print_success "Agent status command works"
    ((PHASES_PASSED++))
else
    print_error "Agent status failed"
    exit 1
fi

# Verify SSH
if ssh "$AGENT_HOST" "echo ok" &>/dev/null; then
    print_success "SSH connection verified"
else
    print_error "SSH connection failed"
    exit 1
fi

# Check dev-infra repo
AGENT_VERSION=$(ssh "$AGENT_HOST" "cd ~/Development/Projects/dev-infra && git log -1 --oneline" 2>/dev/null)
print_info "Agent dev-infra version: $AGENT_VERSION"

#------------------------------------------------------------------------------
# Phase 2: Dispatch Task
#------------------------------------------------------------------------------
print_section "Phase 2: Dispatch Task"

# Create handoff content
HANDOFF_ID="$(date +%Y%m%d-%H%M%S)"
HANDOFF_FILE="/tmp/handoff-$HANDOFF_ID.md"

cat > "$HANDOFF_FILE" << 'HANDOFF'
# E2E Test Task: String Utils Implementation

## Objective
Create a string utility function with tests to validate Brain/Agent distributed workflow.

## Instructions

1. **Create feature branch**
   ```bash
   cd ~/Development/Projects/dev-infra
   git checkout main
   git pull origin main
   git checkout -b TEST_BRANCH_PLACEHOLDER
   ```

2. **Create utility script** at `scripts/string-utils.sh`:
   ```bash
   #!/bin/bash
   # String utility functions

   reverse_string() {
       local input="$1"
       echo "$input" | rev
   }

   uppercase_string() {
       local input="$1"
       echo "$input" | tr '[:lower:]' '[:upper:]'
   }

   # Allow sourcing or direct execution
   if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
       case "${1:-}" in
           reverse) shift; reverse_string "$@" ;;
           upper) shift; uppercase_string "$@" ;;
           *) echo "Usage: $0 {reverse|upper} <string>" ;;
       esac
   fi
   ```

3. **Create test script** at `tests/unit/test-string-utils.sh`:
   ```bash
   #!/bin/bash
   # Unit tests for string-utils.sh

   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "$SCRIPT_DIR/../../scripts/string-utils.sh"

   TESTS_PASSED=0
   TESTS_FAILED=0

   test_reverse() {
       local result=$(reverse_string "hello")
       if [[ "$result" == "olleh" ]]; then
           echo "✅ test_reverse: PASS"
           ((TESTS_PASSED++))
       else
           echo "❌ test_reverse: FAIL (expected 'olleh', got '$result')"
           ((TESTS_FAILED++))
       fi
   }

   test_uppercase() {
       local result=$(uppercase_string "hello")
       if [[ "$result" == "HELLO" ]]; then
           echo "✅ test_uppercase: PASS"
           ((TESTS_PASSED++))
       else
           echo "❌ test_uppercase: FAIL (expected 'HELLO', got '$result')"
           ((TESTS_FAILED++))
       fi
   }

   # Run tests
   echo "=== String Utils Test Suite ==="
   test_reverse
   test_uppercase

   echo ""
   echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"

   [[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1
   ```

4. **Make scripts executable**
   ```bash
   chmod +x scripts/string-utils.sh tests/unit/test-string-utils.sh
   ```

5. **Run tests**
   ```bash
   ./tests/unit/test-string-utils.sh
   ```

6. **Report results** - Write to `~/handoffs/response-HANDOFF_ID_PLACEHOLDER.md`:
   ```markdown
   # Response: HANDOFF_ID_PLACEHOLDER

   ## Status
   [Complete/Failed]

   ## Test Results
   [Paste test output]

   ## Files Created
   - scripts/string-utils.sh
   - tests/unit/test-string-utils.sh

   ## Branch
   TEST_BRANCH_PLACEHOLDER

   ## Completed
   [timestamp]
   ```

## Success Criteria
- Both files created and executable
- Tests pass (2/2)
- Response file written
HANDOFF

# Replace placeholders (use | delimiter to avoid conflicts with / in branch name)
sed -i '' "s|TEST_BRANCH_PLACEHOLDER|$TEST_BRANCH|g" "$HANDOFF_FILE"
sed -i '' "s|HANDOFF_ID_PLACEHOLDER|$HANDOFF_ID|g" "$HANDOFF_FILE"

# Copy handoff to agent
scp "$HANDOFF_FILE" "$AGENT_HOST:~/handoffs/handoff-$HANDOFF_ID.md"
print_success "Handoff created: $HANDOFF_ID"

# Start Claude session on agent
ssh "$AGENT_HOST" "tmux new-session -d -s '$TEST_SESSION' 'claude --dangerously-skip-permissions \"Read ~/handoffs/handoff-$HANDOFF_ID.md and complete the E2E test task. Create the files exactly as specified.\"'"
print_success "Claude session started: $TEST_SESSION"
((PHASES_PASSED++))

#------------------------------------------------------------------------------
# Phase 3: Monitor Progress
#------------------------------------------------------------------------------
print_section "Phase 3: Monitor Progress"

echo "Waiting for task completion (timeout: ${TIMEOUT}s)..."
ELAPSED=0
RESPONSE_FILE="response-$HANDOFF_ID.md"

while [[ $ELAPSED -lt $TIMEOUT ]]; do
    # Check if response file exists
    if ssh "$AGENT_HOST" "test -f ~/handoffs/$RESPONSE_FILE" 2>/dev/null; then
        print_success "Response file detected after ${ELAPSED}s"
        ((PHASES_PASSED++))
        break
    fi

    # Show progress indicator
    printf "."
    sleep 5
    ((ELAPSED+=5))
done
echo ""

if [[ $ELAPSED -ge $TIMEOUT ]]; then
    print_warning "Timeout waiting for response - checking partial progress"
fi

#------------------------------------------------------------------------------
# Phase 4: Verify Artifacts
#------------------------------------------------------------------------------
print_section "Phase 4: Verify Artifacts"

ARTIFACTS_OK=true

if ssh "$AGENT_HOST" "test -f ~/Development/Projects/dev-infra/scripts/string-utils.sh" 2>/dev/null; then
    print_success "scripts/string-utils.sh exists"
else
    print_error "scripts/string-utils.sh missing"
    ARTIFACTS_OK=false
fi

if ssh "$AGENT_HOST" "test -f ~/Development/Projects/dev-infra/tests/unit/test-string-utils.sh" 2>/dev/null; then
    print_success "tests/unit/test-string-utils.sh exists"
else
    print_error "tests/unit/test-string-utils.sh missing"
    ARTIFACTS_OK=false
fi

if [[ "$ARTIFACTS_OK" == "true" ]]; then
    ((PHASES_PASSED++))
fi

#------------------------------------------------------------------------------
# Phase 5: Verify Test Execution
#------------------------------------------------------------------------------
print_section "Phase 5: Verify Test Execution"

if ssh "$AGENT_HOST" "test -f ~/handoffs/$RESPONSE_FILE" 2>/dev/null; then
    RESPONSE=$(ssh "$AGENT_HOST" "cat ~/handoffs/$RESPONSE_FILE")
    echo "$RESPONSE"

    if echo "$RESPONSE" | grep -qi "pass\|complete"; then
        print_success "Tests reported as passing"
        ((PHASES_PASSED++))
    else
        print_warning "Test status unclear"
    fi
else
    print_error "No response file found"
fi

#------------------------------------------------------------------------------
# Phase 6: Collect Results
#------------------------------------------------------------------------------
print_section "Phase 6: Collect Results"

if ssh "$AGENT_HOST" "test -f ~/handoffs/$RESPONSE_FILE" 2>/dev/null; then
    print_success "Results collected successfully"
    ((PHASES_PASSED++))
else
    print_error "Failed to collect results"
fi

#------------------------------------------------------------------------------
# Phase 7: Cleanup
#------------------------------------------------------------------------------
print_section "Phase 7: Cleanup"

# Kill tmux session
ssh "$AGENT_HOST" "tmux kill-session -t '$TEST_SESSION' 2>/dev/null || true"
print_success "Session terminated"

# Clean up test branch (optional - leave for inspection)
# ssh "$AGENT_HOST" "cd ~/Development/Projects/dev-infra && git checkout main && git branch -D '$TEST_BRANCH' 2>/dev/null || true"

# Clean up local handoff
rm -f "$HANDOFF_FILE"
print_success "Local cleanup complete"
((PHASES_PASSED++))

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

print_header "Test Summary"
echo "Phases Passed: $PHASES_PASSED / $PHASES_TOTAL"
echo "Duration: ${DURATION}s"
echo ""

if [[ $PHASES_PASSED -eq $PHASES_TOTAL ]]; then
    print_success "ALL TESTS PASSED"
    exit 0
else
    print_error "SOME TESTS FAILED"
    exit 1
fi
