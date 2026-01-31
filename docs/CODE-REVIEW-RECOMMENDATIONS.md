# Code Review Recommendations

> Generated from code review session. These improvements can be implemented incrementally.

## Priority: HIGH - Error Handling

**Issue:** 48+ scripts lack `set -euo pipefail`

**Fix:** Add to top of each bash script:
```bash
set -euo pipefail
```

**Scripts needing this:**
- `agy-sync`, `agy-health`, `agy-local`, `agy-project`
- `run-all-tests.sh`, `weekly-health-check.sh`
- `test-*.sh` (all test scripts)
- `browser-validate.sh`, `monitor-tw.sh`, `sync-token.sh`
- `tw-node-watchdog.sh`, `validate-token-config.sh`
- `setup-automated-testing.sh`, `test-shell-integration.sh`

---

## Priority: HIGH - Shellcheck CI

**Issue:** No automated shell script linting

**Fix:** Create `.github/workflows/shellcheck.yml`:
```yaml
name: Shellcheck

on:
  push:
    paths:
      - 'scripts/**'
      - 'config/*.sh'
  pull_request:
    paths:
      - 'scripts/**'
      - 'config/*.sh'

jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: sudo apt-get install -y shellcheck
      - run: |
          find scripts -type f \( -name "*.sh" -o -exec grep -l '^#!/.*bash' {} \; \) 2>/dev/null | \
            xargs -r shellcheck --severity=warning
```

---

## Priority: MEDIUM - Color Duplication

**Issue:** 12 scripts duplicate color definitions instead of sourcing `common.sh`

**Fix:** Replace color definitions with:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    source "$SCRIPT_DIR/lib/common.sh"
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
fi
```

**Scripts to update:**
- `gateway-startup-check.sh`
- `setup-mcp.sh`
- `test-crash-recovery.sh`, `test-reboot-survival.sh`, `test-stress-load.sh`
- `test-clawdbot-system-fast.sh`
- `agy-local`, `agy-project`
- `post-restart-setup.sh`
- `agent-tasks/dispatch-all.sh`

---

## Priority: MEDIUM - Enhance common.sh

**Proposed additions to `scripts/lib/common.sh`:**

```bash
#------------------------------------------------------------------------------
# Strict Mode Initialization
#------------------------------------------------------------------------------
init_strict_mode() {
    set -euo pipefail
    trap 'echo -e "${RED:-}Error on line $LINENO${NC:-}" >&2' ERR
}

#------------------------------------------------------------------------------
# Validation Functions
#------------------------------------------------------------------------------
require_cmd() {
    local cmd="$1"
    local msg="${2:-$cmd is required but not installed}"
    if ! command -v "$cmd" &>/dev/null; then
        print_error "$msg"
        exit 1
    fi
}

require_file() {
    local file="$1"
    local msg="${2:-Required file not found: $file}"
    if [[ ! -f "$file" ]]; then
        print_error "$msg"
        exit 1
    fi
}

#------------------------------------------------------------------------------
# Retry Logic
#------------------------------------------------------------------------------
retry() {
    local max_attempts=$1
    shift
    local attempt=1
    local delay=2

    while [[ $attempt -le $max_attempts ]]; do
        if "$@"; then
            return 0
        fi
        if [[ $attempt -lt $max_attempts ]]; then
            print_warning "Attempt $attempt/$max_attempts failed. Retrying in ${delay}s..."
            sleep $delay
            delay=$((delay * 2))
        fi
        ((attempt++))
    done
    print_error "All $max_attempts attempts failed"
    return 1
}
```

---

## Priority: MEDIUM - Test Utilities Library

**Proposed:** Create `scripts/lib/test-utils.sh` for shared test infrastructure:

- `test_result()`, `test_pass()`, `test_fail()` - Test assertions
- `print_test_summary()` - Standardized test output
- `init_test_cache()` - Cache management
- Remote data collection helpers

---

## Priority: LOW - Pre-commit Hook

**File:** `.git/hooks/pre-commit`
```bash
#!/bin/bash
shellcheck scripts/*.sh scripts/**/*.sh 2>/dev/null || {
    echo "Shellcheck found issues"
    exit 1
}
```

---

## Priority: LOW - Future Considerations

1. **TypeScript migration** for complex scripts (agy-project: 297 lines)
2. **Integration tests** in CI that run `test-clawdbot-system-fast.sh`
3. **Script dependency graph** documentation

---

*Last updated: 2026-01-31*
