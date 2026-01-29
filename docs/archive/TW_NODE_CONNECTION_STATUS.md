# TW Node Connection Status Report

**Date:** 2026-01-28  
**Objective:** Restore distributed connectivity for TW node  
**Status:** ⚠️ **BLOCKED - Application Layer Issue**

## Network Architecture

- **Main Gateway:** 192.168.1.230:18789 (binding on 0.0.0.0)
- **Remote Node (TW):** 192.168.1.245
- **Protocol:** WebSocket over TCP
- **Auth Token:** `clawdbot-local-dev`

## Progress Summary

### ✅ What We Fixed

1. **Gateway Binding** - Changed from `127.0.0.1` to `0.0.0.0` (LAN accessible)
2. **DNS Resolution** - Replaced `.local` mDNS with static IP `192.168.1.230`
3. **Node Configuration** - Verified `~/.clawdbot/clawdbot.json` has correct URL and token
4. **LaunchAgent Plist** - Removed invalid `--token` command-line argument
5. **TCP Connectivity** - Verified with `lsof` and `nc` tests

### ✅ Current State - Network Layer

```
TW Node → Gateway TCP Connection: ESTABLISHED
- Source: 192.168.1.245:52046
- Destination: 192.168.1.230:18789
- Process: node (PID 63171) - clawdbot-node
- Service: com.clawdbot.node (LaunchAgent loaded)
```

### ❌ Current State - Application Layer

```
Gateway Status: NO NODES REGISTERED
- `clawdbot status`: Shows 0 remote nodes
- `clawdbot gateway nodes`: Returns empty
- Gateway logs: No connection attempts from 192.168.1.245 since 13:45
```

## The Problem

**TCP connection exists, but WebSocket handshake is NOT happening.**

### Evidence

1. **Node side:**

   - TCP connection: ✅ ESTABLISHED
   - Node logs: Only shows "node host PATH" line
   - Error logs: Empty (after cleaning old --token errors)
   - Process running: ✅ PID 63170 (parent), 63171 (child)

2. **Gateway side:**
   - Listening on: ✅ ws://0.0.0.0:18789
   - Logs show: ❌ NO connection attempts from 192.168.1.245
   - Last TW reference: 01:07 this morning (disconnected state)

### Theory

The node process is:

- Successfully resolving the gateway address
- Successfully establishing TCP connection
- **NOT** sending WebSocket upgrade request
- **NOT** attempting authentication handshake

This suggests either:

1. The node client code isn't initiating the WebSocket protocol
2. There's a silent failure in the node startup that isn't being logged
3. The node is waiting for something (pairing token?) before connecting

## Diagnostics Run

### TW Node (192.168.1.245)

```bash
✅ Config file: Correct (ws://192.168.1.230:18789, token present)
✅ Process status: Running (2 processes)
✅ Network: TCP ESTABLISHED to gateway
✅ Connectivity: Port 18789 reachable
⚠️  Logs: Minimal output (only PATH line)
```

### Main Gateway (192.168.1.230)

```bash
✅ Binding: 0.0.0.0:18789 (LAN accessible)
✅ Service: Running (PID 41725)
✅ Port: Open and accepting connections
❌ Node registry: Empty
❌ Connection logs: No WebSocket handshakes from TW
```

## Next Steps / Recommendations

### Option 1: Enable Debug Logging

Try running node with verbose/debug flags to see what's happening:

```bash
# On TW node
/Users/tywhitaker/.nvm/versions/node/v24.13.0/bin/node \
  /Users/tywhitaker/.nvm/versions/node/v24.13.0/lib/node_modules/clawdbot/dist/entry.js \
  node run --host 192.168.1.230 --port 18789 --verbose 2>&1
```

### Option 2: Check for Version Mismatch

```bash
# On TW
clawdbot --version

# On Main
clawdbot --version
```

### Option 3: Pairing/Registration Issue

The node might need explicit pairing/registration. Check if there's a:

- Pairing token that needs to be generated
- Registration step via `clawdbot node install` with different flags
- Gateway-side approval/allowlist for new nodes

### Option 4: Code-Level Investigation

Since TCP works but WebSocket doesn't, this might be a bug in the clawdbot node client:

- Check the clawdbot source code for WebSocket initialization
- Look for environment variables that control logging verbosity
- Check if there's a heartbeat/ping mechanism that's failing

## Files Modified

- TW: `~/Library/LaunchAgents/com.clawdbot.node.plist` (removed --token arg)
- TW: `~/Library/LaunchAgents/com.clawdbot.node.plist.backup` (created)
- Main: `~/Library/LaunchAgents/com.clawdbot.gateway.plist` (--bind lan)

## Critical Logs

### Gateway (Last 5 entries)

```
2026-01-28T13:45:14.971Z [gateway] listening on ws://0.0.0.0:18789 (PID 41725)
2026-01-28T13:45:14.992Z [imessage] [default] starting provider (imsg)
[No entries from 192.168.1.245 since restart]
```

### TW Node (Full output)

```
node host PATH: /Users/tywhitaker/.nvm/versions/node/v24.13.0/bin:/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin
[No additional output]
```

## Conclusion

We've successfully resolved all **network-level** issues. The TCP tunnel is functional and stable. However, the **application-level** WebSocket handshake is not occurring, preventing the node from registering with the gateway. This appears to be a client-side issue where the node process isn't initiating the WebSocket protocol, despite having a valid TCP connection.

**Recommendation:** This requires either:

1. Access to verbose/debug mode in clawdbot to see what the node client is doing
2. Investigation of the clawdbot source code to understand the connection lifecycle
3. Consultation with clawdbot documentation or support for pairing/registration procedures
