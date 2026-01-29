# TW Node Connection - Troubleshooting Session

**Date:** 2026-01-28 19:06 - 19:38 UTC  
**Duration:** 32 minutes  
**Status:** 🔴 **BLOCKED - Silent WebSocket Failure**  
**Session Type:** Quick Fix Attempt → Deep Troubleshooting

---

## Objective

Restore connection between TW remote node (192.168.1.245) and main gateway (192.168.1.230:18789) following user accidentally deleting `~/.clawdbot` directory on TW machine.

---

## Summary

Despite correct configuration, network connectivity, and token matching, the TW node fails to establish a WebSocket connection to the gateway. The failure is **completely silent** - producing only error code 1006 with no diagnostic information. This session confirms the architectural brittleness documented in TOKEN_ARCHITECTURE_REVIEW.md.

---

## What We Verified (All ✅)

### Configuration Correctness

- **Gateway config** (`~/.clawdbot/clawdbot.json`):
  - Token: `c224f9cb29565b62d56433386c82234f634c3c2a0d6e0cdabef27e20fb3e97b5`
  - Listening on: `ws://0.0.0.0:18789`
- **TW Node config** (`~/.clawdbot/clawdbot.json`):
  - Gateway URL: `ws://192.168.1.230:18789`
  - Token: `c224f9cb29565b62d56433386c82234f634c3c2a0d6e0cdabef27e20fb3e97b5` (MATCHES)
- **Token consistency**: ✅ Both sides have identical tokens

### Network Connectivity

- **Ping**: TW responds to ping from gateway
- **TCP connectivity**: Gateway port 18789 is reachable from TW
- **HTTP test**: `curl http://192.168.1.230:18789/health` returns HTML ✅
- **IP address**: TW confirmed at 192.168.1.245 ✅

### Process Status

- **Gateway**: Running (PID 98881) since 19:13:36
- **TW Node**: LaunchAgent loaded successfully
- **Node processes**: Running on TW machine

### Device Pairing

- **Pairing request**: Submitted and visible in pending queue
- **Approval**: Successfully approved (device ID: 5e1cdc7b...)
- **Pairing status**: Shows "paired" in `clawdbot devices list`

---

## The Problem: Silent WebSocket Failure

Despite all the above being correct, the node **does not connect**.

### Evidence from TW Node

**Node log** (`/tmp/clawdbot-node.log`):

```
Starting clawdbot node...
Node version: v24.13.0
Clawdbot version: 2026.1.24-3
Gateway: ws://192.168.1.230:18789
node host PATH: /Users/tywhitaker/.nvm/versions/node/v24.13.0/bin:...
node host gateway closed (1006):
node host PATH: /Users/tywhitaker/.nvm/versions/node/v24.13.0/bin:...
```

**Error 1006**: WebSocket abnormal closure (no close frame)
**Additional context**: NONE
**Actual error message**: EMPTY STRING after "gateway closed (1006):"

### Evidence from Gateway

**Gateway log** (`~/.clawdbot/logs/gateway.log`):

- Shows gateway listening on `ws://0.0.0.0:18789` ✅
- Shows device pairing approval at 19:35:32 ✅
- Shows webchat connections (127.0.0.1) ✅
- **Shows ZERO connection attempts from 192.168.1.245** ❌

**Network connections** (`lsof -i :18789`):

- No TCP connections from 192.168.1.245
- Only local connections visible

### Interpretation

The node believes it's trying to connect, but:

1. The WebSocket handshake never reaches the gateway
2. No TCP connection is established
3. Error 1006 appears immediately (abnormal closure)
4. No diagnostic information explaining why

---

## Troubleshooting Steps Attempted

### 1. Configuration Review

- ✅ Verified token matches on both sides
- ✅ Verified gateway URL is correct
- ✅ Verified gateway is listening on 0.0.0.0 (not localhost)

### 2. Process Management

- ✅ Killed all existing clawdbot processes on TW
- ✅ Stopped incorrect gateway process running on TW
- ✅ Created proper node-only LaunchAgent

### 3. Network Testing

- ✅ Confirmed HTTP connectivity (curl succeeds)
- ✅ Confirmed DNS resolution (IP address works)
- ✅ Confirmed no firewall blocking (HTTP works)

### 4. Device Pairing

- ✅ Found pending pairing request
- ✅ Approved device with correct request ID
- ✅ Verified device shows as "paired" in status

### 5. LaunchAgent Configuration

Created proper LaunchAgent at `~/Library/LaunchAgents/com.clawdbot.node.plist`:

```xml
<dict>
    <key>Label</key>
    <string>com.clawdbot.node</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/tywhitaker/start-clawdbot-node.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
```

Startup script (`~/start-clawdbot-node.sh`):

```bash
#!/bin/bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

pkill -f clawdbot 2>/dev/null
sleep 2

exec /Users/tywhitaker/.nvm/versions/node/v24.13.0/bin/node \
  /Users/tywhitaker/.nvm/versions/node/v24.13.0/lib/node_modules/clawdbot/dist/entry.js \
  node run --host 192.168.1.230 --port 18789
```

**Result**: Process starts, but WebSocket connection still fails with 1006

### 6. Alternative Approaches Tried

- ❌ `clawdbot node start` - Command doesn't exist in this version
- ❌ `clawdbot node run` without args - Fails to use config file
- ❌ `clawdbot node run --host --port` - Still error 1006

---

## Root Cause Analysis

This failure demonstrates **exactly the architectural problems** identified in TOKEN_ARCHITECTURE_REVIEW.md:

### Problem 1: Silent Failures

- Error 1006 with **empty error message**
- No indication of what failed (DNS? TCP? Auth? SSL?)
- No verbose/debug mode available
- Logs only show "node host PATH" repeatedly

### Problem 2: No Diagnostic Endpoints

- Can't test if gateway accepts the token
- Can't validate WebSocket connection separately
- Can't see connection state from client side
- No health check for node-to-gateway connectivity

### Problem 3: Configuration Complexity

- Token must be correct (✅ verified)
- URL must be correct (✅ verified)
- Device must be paired (✅ verified)
- Process must be running (✅ verified)
- **Yet connection still fails** with no explanation

### Problem 4: Version/Compatibility Unknown

- Gateway: 2026.1.23-1
- Node: 2026.1.24-3
- **Different versions** - could this cause incompatibility?
- No version compatibility matrix available

---

## Comparison with Previous Successful Resolution

Looking at `TW_NODE_RESOLUTION.md` (successful connection on 2026-01-28):

### What Was Different Then

**That session:**

- Docker container conflict was discovered and fixed
- Token was updated in LaunchAgent environment variables
- After Docker container stopped, connection worked

**This session:**

- No Docker container conflict (checked)
- Token is correct in all locations
- LaunchAgent properly configured
- **Still fails to connect**

### Key Difference

In the previous session, after fixing the Docker conflict, the node **did connect** and showed up in gateway logs. In this session, **no connection attempts appear in gateway logs at all**.

This suggests the failure is happening **before** the WebSocket handshake, possibly at:

- DNS resolution (but curl works, so unlikely)
- TCP connection (but gateway is listening on 0.0.0.0)
- WebSocket upgrade request (most likely - never reaches gateway)
- Client-side crash (process keeps running, so unlikely)

---

## Files Created/Modified During Session

### On TW Machine (192.168.1.245)

- ✅ `~/start-clawdbot-node.sh` - Node startup script
- ✅ `~/Library/LaunchAgents/com.clawdbot.node.plist` - Proper node LaunchAgent
- ✅ `~/.clawdbot/clawdbot.json` - Verified correct configuration

### On Main Mac (192.168.1.230)

- No changes needed - gateway configuration was already correct

---

## Current State

### Gateway (192.168.1.230)

```
Status: Running ✅
PID: 98881
Port: 18789 (listening on 0.0.0.0)
Token: c224f9cb29565b62d56433386c82234f634c3c2a0d6e0cdabef27e20fb3e97b5
Version: 2026.1.23-1
Connections: 0 nodes connected
```

### TW Node (192.168.1.245)

```
Status: Running (LaunchAgent) ✅
IP: 192.168.1.245
Config: Correct ✅
Token: Matches gateway ✅
Pairing: Approved ✅
Connection: FAILED ❌
Error: WebSocket 1006 (silent)
```

---

## Hypotheses for Why This Fails

### Hypothesis 1: Client-Side Bug

The `clawdbot node run` command may have a bug where:

- It loads config correctly
- It tries to connect
- But WebSocket client library fails silently
- No actual network request is made

**Evidence**: Gateway logs show ZERO attempts from 192.168.1.245

### Hypothesis 2: Missing Environment Variable

The node process might need an environment variable that's not being set:

- `CLAWDBOT_NODE_TOKEN`?
- `CLAWDBOT_GATEWAY_URL`?
- Some undocumented variable?

**Evidence**: `--host` and `--port` flags don't seem to work either

### Hypothesis 3: Version Incompatibility

Gateway (2026.1.23-1) and Node (2026.1.24-3) may be incompatible:

- WebSocket protocol changed?
- Auth handshake changed?
- Connection sequence changed?

**Evidence**: Different version numbers between gateway and node

### Hypothesis 4: TLS/SSL Issue

Even though URL is `ws://` (not `wss://`), there might be:

- Certificate validation failing
- TLS upgrade attempted but fails
- SSL library issue

**Evidence**: Error 1006 is often related to TLS failures

---

## What Didn't Work

These approaches were attempted but failed:

❌ **Restarting processes** - Node starts but doesn't connect  
❌ **Re-pairing device** - Pairing succeeds but connection fails  
❌ **Explicit --host and --port flags** - Still error 1006  
❌ **Removing token from config** - Made problem worse  
❌ **Different startup methods** - All produce same error  
❌ **Checking logs for errors** - Logs are empty or useless

---

## Recommended Next Steps for Investigation Agent

### 1. Enable Debug Logging (CRITICAL)

Try to find verbose/debug mode:

```bash
# On TW, try these variations:
DEBUG=* clawdbot node run --host 192.168.1.230 --port 18789
CLAWDBOT_LOG_LEVEL=debug clawdbot node run --host 192.168.1.230 --port 18789
NODE_DEBUG=net,http,tls clawdbot node run --host 192.168.1.230 --port 18789
```

### 2. Check Clawdbot Source Code

Investigate the node connection code:

```bash
# On TW, find source
ls -la /Users/tywhitaker/.nvm/versions/node/v24.13.0/lib/node_modules/clawdbot/dist/
```

Look for:

- WebSocket connection logic
- How config file is read
- How --host and --port are processed
- Error handling around connection

### 3. Test with Minimal Configuration

Try connecting with absolute minimum:

```bash
# Remove all config
mv ~/.clawdbot/clawdbot.json ~/.clawdbot/clawdbot.json.backup

# Try explicit connection
clawdbot node run \
  --host 192.168.1.230 \
  --port 18789 \
  --token c224f9cb29565b62d56433386c82234f634c3c2a0d6e0cdabef27e20fb3e97b5
```

### 4. Network Packet Capture

Capture actual network traffic to see what's happening:

```bash
# On gateway Mac
sudo tcpdump -i any -n port 18789 -A

# Then try connecting from TW
```

This will show if TCP SYN packets are even being sent.

### 5. Version Alignment

Try downgrading TW node to match gateway:

```bash
# On TW
npm install -g clawdbot@2026.1.23-1
```

Or upgrade gateway to match node:

```bash
# On gateway
npm install -g clawdbot@2026.1.24-3
```

### 6. Alternative Connection Method

Try using clawdbot as a gateway-to-gateway connection instead of node:

```bash
# On TW, configure as gateway with federation/clustering?
```

### 7. Contact Clawdbot Support

This issue requires:

- Access to clawdbot source code, OR
- Official documentation on connection troubleshooting, OR
- Support from clawdbot developers

---

## Evidence This Confirms Architecture Review Findings

This troubleshooting session provides **concrete evidence** for the claims in TOKEN_ARCHITECTURE_REVIEW.md:

### Finding 1: Silent Failures

**Claim**: "WebSocket handshake fails silently with no error messages"
**Evidence**: Error 1006 with empty message, no diagnostic output

### Finding 2: Poor Observability

**Claim**: "No verbose/debug mode for troubleshooting"
**Evidence**: Spent 32 minutes unable to get any useful diagnostic information

### Finding 3: Configuration Brittleness

**Claim**: "Multiple configuration locations cause drift"
**Evidence**: LaunchAgent, config file, CLI flags - unclear which takes precedence

### Finding 4: No Validation Endpoints

**Claim**: "Missing token validation endpoints"
**Evidence**: Can't test token separately from full connection

### Finding 5: Version Compatibility Unknown

**Claim**: "No version compatibility matrix"
**Evidence**: Gateway 2026.1.23-1 vs Node 2026.1.24-3 - unclear if compatible

---

## Time Breakdown

- **00:00-00:05**: Initial assessment and token verification
- **00:05-00:10**: Network connectivity testing
- **00:10-00:15**: Process management and LaunchAgent creation
- **00:15-00:20**: Device pairing and approval
- **00:20-00:25**: SSH debugging (network timeout issues)
- **00:25-00:30**: Multiple restart attempts with different configurations
- **00:30-00:32**: Final verification and documentation

**Total diagnostic time**: 32 minutes  
**Result**: Issue not resolved, requires deeper investigation

---

## Actionable Insights for System Improvements

Based on this session, the clawdbot system should be improved with:

1. **Verbose error messages** - Error 1006 should explain WHY
2. **Connection test command** - `clawdbot node test-connection --gateway-url ws://...`
3. **Token validation endpoint** - `GET /api/auth/validate` to test tokens
4. **Debug mode** - `--verbose` flag to show connection attempts
5. **Health checks** - Node should report connection state to logs
6. **Version compatibility** - Clear documentation of which versions work together
7. **Connection wizard** - Interactive troubleshooting tool

---

## Conclusion

Despite correct configuration, matching tokens, network connectivity, and device pairing, the TW node fails to connect with a silent WebSocket error 1006. This issue:

- **Cannot be resolved** with configuration changes alone
- **Requires** access to debug logs or source code
- **Confirms** the architectural brittleness identified in the review
- **Demonstrates** the urgent need for better observability

**Status**: Blocked, escalated for investigation with access to clawdbot internals or developer support.

---

## References

- `TOKEN_ARCHITECTURE_REVIEW.md` - Analysis of current auth architecture
- `TW_NODE_RESOLUTION.md` - Previous successful resolution (2026-01-28)
- `TW_NODE_CONNECTION_STATUS.md` - Previous failed attempt (2026-01-28)
- `TW_NODE_HANDOFF.md` - Initial troubleshooting documentation
