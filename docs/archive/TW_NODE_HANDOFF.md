# TW Node Connection Issue - Handoff Summary

**Date:** 2026-01-28  
**Status:** 🔴 **BLOCKED** - Node Offline  
**Priority:** High

---

## Issue Summary

The TW remote node (`192.168.1.245`) is **not connecting** to the Clawdbot Gateway (`192.168.1.230:18789`) after the user accidentally deleted the entire `~/.clawdbot` directory on the TW machine.

**Objective:** Re-establish secure connection with full unattended remote execution capabilities.

---

## Background Context

### Previous State (Working)

- **Gateway:** `192.168.1.230:18789` (Jed's MacBook Pro)
- **TW Node:** `192.168.1.245` (tywhitaker@TW)
- **Auth Token:** `c224f9cb29565b62d56433386c82234f634c3c2a0d6e0cdabef27e20fb3e97b5`
- **Previous Device ID:** `eb8bf03650f91c6d67fddc4d1a427f4ce2fdcc9161c0a98c838e0155612f44a1`
- **Connection:** Previously ESTABLISHED and visible in dashboard as "TW" node

### Incident

User ran `rm -rf ~/.clawdbot` on TW machine, deleting:

- Configuration (`clawdbot.json`)
- Identity files (`device.json`, `device-auth.json`)
- Security policies (`exec-approvals.json`)
- All logs and session data

---

## Recovery Attempts

### 1. Re-Onboarding (Executed on TW)

```bash
clawdbot onboard --non-interactive --accept-risk \
  --remote-url ws://192.168.1.230:18789 \
  --remote-token c224f9cb29565b62d56433386c82234f634c3c2a0d6e0cdabef27e20fb3e97b5 \
  --install-daemon
```

**Result:** Command completed successfully, reported "Updated ~/.clawdbot/clawdbot.json"

### 2. Security Policy Configuration (Executed on TW)

Created `~/.clawdbot/exec-approvals.json` with full control settings:

```json
{
  "version": 1,
  "defaults": {
    "security": "full",
    "ask": "off",
    "askFallback": "deny",
    "autoAllowSkills": true
  },
  "agents": { "*": { "security": "full", "ask": "off" } }
}
```

**Result:** File created successfully with proper permissions (600)

### 3. Service Restart

User was instructed to run `clawdbot node restart` on TW.
**Result:** Unknown (no confirmation of execution or output received)

---

## Diagnostic Results

### Gateway Side (192.168.1.230)

#### CLI Checks

```bash
# Pending devices
CLAWDBOT_GATEWAY_TOKEN="c224..." clawdbot devices list --json
# Result: "pending": [] - EMPTY

# Connected nodes
CLAWDBOT_GATEWAY_TOKEN="c224..." clawdbot nodes status --json
# Result: No TW node listed
```

#### Network Check

```bash
lsof -i :18789 | grep 192
# Result: No connections from 192.168.1.245
```

#### Log Analysis (`~/.clawdbot/logs/gateway.log`)

- **Latest Entry:** 2026-01-28T18:52:44.703Z
- **Finding:** Zero connection attempts from `192.168.1.245` since re-onboarding
- **Note:** Only local webchat connections (`127.0.0.1`) visible

#### Dashboard Validation (Browser Agent)

- **Instances Tab:** TW node NOT listed (only local gateway + control-ui)
- **Nodes Tab:** TW NOT available in host selector
- **Pending Requests:** None
- **Screenshot:** `dashboard_tw_status_1769626855106.png`

### TW Node Side (192.168.1.245)

**🚨 CRITICAL:** No diagnostic access available (node is unreachable until connected)

---

## Current Hypothesis

The TW node service is **failing to start or crashing** on the remote machine. Possible causes:

### Most Likely

1. **Service Not Running**

   - The `clawdbot node restart` command was not executed
   - OR the LaunchAgent failed to start the service
   - OR the service crashed immediately after startup

2. **Configuration Error**
   - The `clawdbot onboard` command may have written an invalid `clawdbot.json`
   - The `exec-approvals.json` syntax may be incompatible with the current version

### Less Likely (but possible)

3. **Network Issue**

   - Firewall blocking outbound WebSocket connections from TW
   - Gateway IP changed (though highly unlikely)
   - DNS resolution failure

4. **Token Mismatch**
   - The token in `clawdbot.json` doesn't match gateway expectations
   - (Though this would typically show connection attempts with auth errors in logs)

---

## Blocked Action Items

The following diagnostics **MUST** be performed on the TW machine to proceed:

### Priority 1: Check Service Status

```bash
# On TW terminal
clawdbot node status
```

**Expected Outcomes:**

- ✅ "Running" → Proceed to Priority 2
- ❌ "Stopped" or error → Service failed to start (check logs)

### Priority 2: Check Error Logs

```bash
# On TW terminal
tail -n 50 ~/.clawdbot/logs/node.err.log
```

**Look for:**

- Connection errors (`ECONNREFUSED`, `ETIMEDOUT`)
- Authentication errors (`unauthorized`, `token mismatch`)
- Config parsing errors (`JSON parse error`, `invalid config`)

### Priority 3: Test Manual Startup (If service is stopped)

```bash
# On TW terminal (foreground mode)
clawdbot node run
```

**This will show real-time errors and confirm if config is valid.**

### Priority 4: Verify Configuration

```bash
# On TW terminal
cat ~/.clawdbot/clawdbot.json
cat ~/.clawdbot/exec-approvals.json
```

**Validate:**

- `gateway.remote.url` = `ws://192.168.1.230:18789`
- `gateway.remote.token` = `c224f9cb...`
- Valid JSON syntax

---

## Recommendations

### Immediate Next Steps

1. **Execute Priority 1-3 diagnostics on TW** (requires physical or SSH access to TW machine)
2. **If service is crashed:** Review error logs and fix configuration
3. **If service is stopped:** Start it manually and observe output
4. **If service is running:** Check if it's connecting to wrong URL or with wrong token

### Alternative Approach (If Unable to Access TW)

If direct access to TW is not possible:

1. **Remote SSH:** `ssh tywhitaker@192.168.1.245` (if SSH is enabled)
2. **Physical Access:** Walk to TW machine and open terminal
3. **Remote Desktop:** Use Screen Sharing if enabled on TW

### Once Connection is Re-established

After the node connects and appears in `clawdbot devices list --json` as pending:

```bash
# Approve the new device
CLAWDBOT_GATEWAY_TOKEN="c224..." clawdbot devices approve --device-id <NEW_ID>

# Test full control
CLAWDBOT_GATEWAY_TOKEN="c224..." clawdbot nodes run --node TW -- hostname
```

---

## Key Files & Credentials

### Gateway (192.168.1.230)

- **Config:** `~/.clawdbot/clawdbot.json`
- **Paired Devices:** `~/.clawdbot/devices/paired.json`
- **Logs:** `~/.clawdbot/logs/gateway.log`
- **Token:** `c224f9cb29565b62d56433386c82234f634c3c2a0d6e0cdabef27e20fb3e97b5`

### TW Node (192.168.1.245)

- **Config:** `/Users/tywhitaker/.clawdbot/clawdbot.json`
- **Security Policy:** `/Users/tywhitaker/.clawdbot/exec-approvals.json`
- **Error Logs:** `/Users/tywhitaker/.clawdbot/logs/node.err.log`
- **Startup Logs:** `/Users/tywhitaker/.clawdbot/logs/node.log`
- **User:** `tywhitaker`

### Scripts Created

- **Recovery Script:** `scripts/enable-tw-full-control.sh` (execution policy setup)
- **Resolution Doc:** `TW_NODE_RESOLUTION.md` (original fix documentation)

---

## Open Questions

1. **Was `clawdbot node restart` actually executed on TW?** (No confirmation received)
2. **Does TW have network connectivity to 192.168.1.230:18789?** (Was working before deletion)
3. **Is the LaunchAgent properly configured?** (Path: `~/Library/LaunchAgents/com.clawdbot.node.plist` on TW)

---

## Success Criteria

The issue will be considered **RESOLVED** when:

- [ ] `lsof -i :18789 | grep 192.168.1.245` shows ESTABLISHED connection on Gateway
- [ ] `clawdbot nodes status --json` shows TW node with `"connected": true`
- [ ] `clawdbot nodes run --node TW -- hostname` executes without approval prompt
- [ ] Dashboard shows "TW" in Instances with green status

---

**Next Agent Action:** Execute Priority 1-3 diagnostics on TW machine (`192.168.1.245` / user: `tywhitaker`).
