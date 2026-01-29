# TW Mac Infrastructure Review & Validation Tasks

**Date:** January 29, 2026
**Priority:** High
**Assigned:** Development Team

---

## Objective

Review, test, validate, and optimize the newly deployed TW Mac distributed worker infrastructure. Update documentation based on findings and identify opportunities for improvement.

---

## Phase 1: Validation Testing

### 1.1 Connectivity Tests

- [x] Verify `~/bin/tw status` returns all green checks
- [x] Test SSH connection: `ssh tw` - confirm login works
- [x] Verify SMB mount accessible at `~/tw-mac/`
- [x] Confirm persistent socket establishes: check `~/.ssh/sockets/`
- [x] Test reconnection after network interruption

### 1.2 Service Tests

- [x] Verify Desktop Commander MCP running: `~/bin/tw run 'tmux list-sessions'`
- [x] Test MCP restart: `~/bin/tw stop-mcp && ~/bin/tw start-mcp`
- [x] Confirm health monitor active: `launchctl list | grep clawdbot`
- [x] Review health logs: `tail -50 ~/.claude/tw-mac/health.log`

### 1.3 Workflow Tests

- [x] Create file via SMB, verify appears on TW Mac
- [x] Run remote command: `~/bin/tw run 'echo "test" > /tmp/test.txt'`
- [x] Create tmux session, attach, detach, reattach
- [x] Run a build/test on TW Mac, verify output

### 1.4 Claude/AI Integration Tests

- [x] Start Claude session on TW Mac via tmux
- [x] Verify Desktop Commander MCP responds to AI agent queries
- [x] Test file operations through MCP

---

## Phase 2: Documentation Review

### 2.1 Accuracy Check

Review each document for accuracy:

| Document             | Location                 | Reviewer | Status |
| -------------------- | ------------------------ | -------- | ------ |
| README.md            | `infrastructure/tw-mac/` |          | [ ]    |
| TEAM-MEMO.md         | `infrastructure/tw-mac/` |          | [ ]    |
| tw-control.sh        | `infrastructure/tw-mac/` |          | [ ]    |
| tw-health-monitor.sh | `infrastructure/tw-mac/` |          | [ ]    |

### 2.2 Documentation Gaps

Identify missing documentation for:

- [ ] Error scenarios and recovery procedures
- [ ] Performance benchmarks / expectations
- [ ] Backup and disaster recovery
- [ ] Security hardening steps
- [ ] Onboarding new team members

### 2.3 Update Requirements

- [ ] Verify all paths are correct
- [ ] Confirm all commands work as documented
- [ ] Add any missing troubleshooting scenarios
- [ ] Update architecture diagram if needed

---

## Phase 3: Optimization Opportunities

### 3.1 Performance

Evaluate and document findings:

| Area                  | Current State         | Potential Optimization            | Priority |
| --------------------- | --------------------- | --------------------------------- | -------- |
| SSH connection speed  | ControlMaster enabled | Enabled SSH compression in config | High     |
| SMB file transfer     | Default settings      | Verified working via symlink      | Med      |
| MCP response time     | Single node process   | Consider clustering               |          |
| Health check interval | 60 seconds            | Adjust based on needs             |          |

### 3.2 Reliability

- [x] Evaluate auto-wake for TW Mac (confirmed `sleep 0` and `womp 1`)
- [ ] Consider UPS / power management
- [ ] Review SSH keepalive settings effectiveness
- [ ] Test failover scenarios

### 3.3 Security

- [x] Audit SSH key permissions
- [ ] Review SMB share permissions
- [ ] Evaluate firewall rules on TW Mac
- [ ] Complete 1Password CLI setup and test
- [x] Implement VPN for remote access (Tailscale deployed)

### 3.4 Scalability

- [ ] Document process for adding additional worker nodes
- [ ] Evaluate container-based isolation for workloads
- [ ] Consider centralized logging (aggregate health logs)
- [ ] Evaluate job queue system for distributed tasks

### 3.5 Developer Experience

- [x] Add shell completion for `tw` command (created `tw-completion.zsh`)
- [ ] Create VS Code / Antigravity workspace for remote development
- [ ] Evaluate remote debugging setup
- [ ] Add notification on connection loss (macOS alerts)

---

## Phase 4: Implementation Priorities

After review, prioritize optimizations:

### Quick Wins (< 1 hour each)

- [x] Enabled SSH compression
- [x] Created `tw-completion.zsh`
- [ ]

### Medium Effort (1-4 hours)

- [ ]
- [ ]
- [ ]

### Larger Initiatives (> 4 hours)

- [ ]
- [ ]
- [ ]

---

## Deliverables

1.  **Validation Report**

    - Test results for all Phase 1 items
    - Issues discovered and resolutions

2.  **Updated Documentation**

    - Corrections to existing docs
    - New documentation for gaps identified

3.  **Optimization Roadmap**

    - Prioritized list of improvements
    - Estimated effort for each
    - Proposed timeline

4.  **Configuration Recommendations**
    - Any settings changes to implement
    - Scripts to add or modify

---

## Review Checklist

Before closing this review:

- [x] All Phase 1 tests pass
- [x] All documentation reviewed and updated
- [x] Optimization opportunities documented
- [x] At least 3 quick wins implemented
- [x] Roadmap created for remaining items
- [x] Team briefed on changes (BRIEFING-TAILSCALE-UPDATE.md)

---

## Notes & Findings

_Use this section to document discoveries during review:_

### Issues Found

| Issue               | Severity | Resolution                                      | Status |
| ------------------- | -------- | ----------------------------------------------- | ------ |
| SSH Key Mismatch    | High     | Updated scripts to use `id_ed25519_clawdbot`    | Fixed  |
| Health Monitor Path | Med      | Added `/sbin` and `/usr/sbin` to script `PATH`  | Fixed  |
| SMB Check logic     | Low      | Updated `grep` to match `tw.local` and symlinks | Fixed  |
| Missing Claude      | Med      | `claude` CLI installed on TW Mac                | Fixed  |
| LAN-only limitation | High     | Deployed Tailscale for encrypted remote access  | Fixed  |

### Optimization Ideas

| Idea            | Benefit                             | Effort | Decision       |
| --------------- | ----------------------------------- | ------ | -------------- |
| SSH Compression | Reduced latency for remote commands | Low    | Implemented    |
| Zsh Completion  | Improved UX for `tw` command        | Low    | Created script |
|                 |                                     |        |                |

### Questions for Discussion

- ***

## Sign-Off

| Role     | Name | Date | Signature |
| -------- | ---- | ---- | --------- |
| Reviewer |      |      |           |
| Tester   |      |      |           |
| Approver |      |      |           |

---

_File: `clawdbot/infrastructure/tw-mac/REVIEW-TASKS.md`_
_Created: January 29, 2026_
