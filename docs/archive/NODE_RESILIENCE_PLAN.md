# TW Node Resilience & Hardening Plan

**Date:** 2026-01-29  
**Status:** DRAFT (Implementation Phase)  
**Objective:** Eliminate connectivity brittleness and ensure 24/7 autonomous operation of the TW headless node.

---

## 1. The Problem Statement

**"The TW Mac is securely configured to refuse remote commands, preventing true headless operation."**

Our recent investigation revealed multiple single points of failure:

1.  **Gateway Binding:** Defaulted to `localhost`, making the node unreachable.
2.  **Silent Failure:** Node process restarted 1000+ times with generic `ECONNREFUSED` errors, unobserved.
3.  **Approval Lockout:** Headless nodes cannot click "Approve" buttons in a browser UI.
4.  **Legacy Monitoring:** The existing `tw-health-monitor.sh` watches SSH/Tmux but ignores the critical `clawdbot` node service.

---

## 2. Hardening Strategy

We will implement a defense-in-depth approach:

### Layer 1: Configuration Hardening (Prevention)

- **Enforce `bind: "lan"`:** Gateway must explicitly listen on `0.0.0.0` or a specific LAN IP.
- **Enforce `security: "full"`:** Headless nodes must be pre-configured to bypass approval prompts.
- **Token Consistency:** Use `paired.json` as the single source of truth for device tokens.

### Layer 2: Self-Healing Watchdog (Recovery)

- **New Script:** `scripts/tw-watchdog.sh` (replaces/augments `tw-health-monitor.sh`).
- **Logic:**
  - Poll `clawdbot nodes status` on the Gateway.
  - If TW node is `disconnected`:
    1. Check basic network (ping).
    2. Check Gateway port availability (netcat).
    3. SSH into node and check process status.
    4. **Restart Node Service** remotely if stuck.
    5. **Alert** if recovery fails after 3 attempts.

### Layer 3: Diagnostic Tooling (Observability)

- **New Tool:** `scripts/clawdbot-doctor-node.sh`
- **Function:** Runs on the node to verify:
  - DNS resolution of Gateway
  - TCP connectivity to Gateway port
  - Token validity (simple HTTP check)
  - Process uptime

---

## 3. Implementation Plan

### Step 1: Deploy Watchdog Script

Create `scripts/tw-watchdog.sh` to monitor the connection from the **Gateway** side (since the Gateway is the controller).

**Watchdog Logic:**

```bash
STATUS=$(clawdbot nodes status --json | jq -r '.nodes[] | select(.name=="TW") | .status')
if [ "$STATUS" != "connected" ]; then
    echo "⚠️ TW Node disconnected! Attempting recovery..."
    ssh tw "launchctl kickstart -k gui/501/com.clawdbot.node"
fi
```

### Step 2: Update Node Configuration

Ensure the node's `clawdbot.json` is immutable regarding critical connectivity settings.

### Step 3: Establish "Quick-Fix" Dashboard

Create a simple HTML/CLI output that shows:

- Gateway IP/Port
- Master Token
- Device Connection Status
- Pending Approvals

---

## 4. Immediate Action Items

1. [ ] Create `scripts/tw-watchdog.sh`
2. [ ] Install watchdog as a LaunchAgent on the Gateway Mac (`com.clawdbot.watchdog`).
3. [ ] Update `infrastructure/tw-mac/README.md` with new architecture.

---

## 5. Success Metrics

- **Uptime:** TW Node remains "Connected" > 99.9% of the time.
- **Recovery Time:** Disconnections are resolved within < 2 minutes (watchdog interval).
- **Maintenance:** Zero manual interventions required for standard operations.
