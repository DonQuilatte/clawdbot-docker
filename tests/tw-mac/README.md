# TW Mac Infrastructure Tests

Comprehensive test suite for the distributed TW Mac worker node infrastructure.

**Last Updated:** January 29, 2026

---

## Test Categories

```
tests/tw-mac/
├── README.md               # This file
├── run-all.sh              # Test runner (all categories)
├── unit/                   # Unit tests - no network required
│   ├── test-tw-control.sh      # Control script structure tests
│   ├── test-health-monitor.sh  # Health monitor structure tests
│   └── test-ssh-config.sh      # SSH configuration validation
├── integration/            # Integration tests - requires TW Mac online
│   ├── test-ssh-connection.sh  # SSH connectivity tests
│   ├── test-smb-mount.sh       # SMB file sharing tests
│   └── test-tailscale.sh       # Tailscale VPN tests
└── system/                 # System tests - full workflow validation
    ├── test-workflow-build.sh  # Build/test offload workflow
    ├── test-workflow-agent.sh  # AI agent operation workflow
    └── test-workflow-sync.sh   # File synchronization workflow
```

---

## Running Tests

### Run All Tests
```bash
./tests/tw-mac/run-all.sh
```

### Run by Category
```bash
# Unit tests only (offline capable)
./tests/tw-mac/run-all.sh unit

# Integration tests (requires TW Mac)
./tests/tw-mac/run-all.sh integration

# System tests (requires full setup)
./tests/tw-mac/run-all.sh system
```

### Run Individual Tests
```bash
# Specific unit test
./tests/tw-mac/unit/test-tw-control.sh

# Specific integration test
./tests/tw-mac/integration/test-ssh-connection.sh

# Specific system test
./tests/tw-mac/system/test-workflow-build.sh
```

### Verbose Mode
```bash
./tests/tw-mac/run-all.sh -v          # Detailed output
./tests/tw-mac/run-all.sh -v system   # Verbose system tests
```

---

## Test Descriptions

### Unit Tests

| Test | Purpose |
|------|---------|
| `test-tw-control.sh` | Validates tw-control.sh script structure, commands, variables |
| `test-health-monitor.sh` | Validates health monitor script configuration |
| `test-ssh-config.sh` | Validates SSH config entries for TW Mac |

### Integration Tests

| Test | Purpose |
|------|---------|
| `test-ssh-connection.sh` | Tests live SSH connectivity, key auth, command execution |
| `test-smb-mount.sh` | Tests SMB file sharing mount and operations |
| `test-tailscale.sh` | Tests Tailscale VPN connectivity and routing |

### System Tests

| Test | Purpose |
|------|---------|
| `test-workflow-build.sh` | End-to-end build/test workflow on TW Mac |
| `test-workflow-agent.sh` | AI agent/MCP server operations |
| `test-workflow-sync.sh` | File synchronization via SSH and SMB |

---

## Prerequisites

### For Unit Tests
- No network required
- Scripts must exist at documented paths

### For Integration Tests
- TW Mac must be online
- Tailscale connected (or LAN access)
- SSH keys configured
- SMB mount available (for SMB tests)

### For System Tests
- All integration prerequisites
- Node.js installed on TW Mac
- tmux installed on TW Mac
- Claude CLI available on TW Mac
- MCP server operational

---

## Test Output

Tests follow a consistent output format:

```
==========================================
Test Name
==========================================

--- Test: Description ---
✓ PASS: Passed test
✗ FAIL: Failed test
○ SKIP: Skipped test

==========================================
Test Summary
==========================================
Passed: X
Failed: Y
```

### Exit Codes
- `0` - All tests passed
- `1` - One or more tests failed

---

## Troubleshooting

### Tests Can't Connect to TW Mac
```bash
# Check TW Mac status
~/bin/tw status

# Test basic connectivity
ping 100.81.110.81

# Test SSH directly
ssh tw 'echo ok'
```

### SMB Tests Failing
```bash
# Check mount status
mount | grep tw

# Re-mount SMB
open smb://tywhitaker@tw.local/tywhitaker
```

### System Tests Timeout
```bash
# Check for stuck tmux sessions
~/bin/tw run 'tmux list-sessions'

# Kill orphaned sessions
~/bin/tw run 'tmux kill-server'
```

---

## Adding New Tests

1. Create test file in appropriate directory
2. Follow naming convention: `test-<name>.sh`
3. Include standard header with shebang and description
4. Use provided logging functions: `log_pass`, `log_fail`, `log_skip`
5. Return exit code 0 on success, 1 on failure
6. Update this README

### Template
```bash
#!/bin/bash
# Description of test
set -e

PASS=0
FAIL=0

log_pass() { echo -e "\\033[0;32m✓ PASS\\033[0m: $1"; ((PASS++)); }
log_fail() { echo -e "\\033[0;31m✗ FAIL\\033[0m: $1"; ((FAIL++)); }

# Tests here...

echo "Passed: $PASS"
echo "Failed: $FAIL"
[ $FAIL -gt 0 ] && exit 1
exit 0
```

---

## Related Documentation

- [`infrastructure/tw-mac/README.md`](../../infrastructure/tw-mac/README.md) - Main infrastructure docs
- [`infrastructure/tw-mac/WORKFLOWS.md`](../../infrastructure/tw-mac/WORKFLOWS.md) - Workflow documentation
- [`infrastructure/tw-mac/BRIEFING-TAILSCALE-UPDATE.md`](../../infrastructure/tw-mac/BRIEFING-TAILSCALE-UPDATE.md) - Tailscale details

---

*Part of clawdbot distributed infrastructure*
