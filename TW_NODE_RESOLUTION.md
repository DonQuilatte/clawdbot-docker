# TW Node Connection - Final Resolution Report

**Date:** 2026-01-28  
**Status:** ✅ **RESOLVED**

## The Root Cause

Two critical issues were blocking the connection:

1. **Gateway Auth Token Mismatch:** The Gateway LaunchAgent had a hardcoded placeholder token (`clawdbot-local-dev`) that overrode the configuration file. The Remote Node was configured with a new secure token, causing "Unauthorized" errors.
2. **Device Pairing Mismatch:** The Gateway had a pairing entry for the TW Node, but the token it expected didn't match the one the device was presenting.

## Steps Taken to Fix

### 1. Secured Gateway Authentication

- Generated a cryptographic secure token: `c224f9cb...`
- Updated `~/.clawdbot/clawdbot.json` on **Gateway**.
- Updated `~/.clawdbot/clawdbot.json` on **TW Node**.

### 2. Fixed LaunchAgent Configuration

- Detected `com.clawdbot.gateway.plist` was forcing `CLAWDBOT_GATEWAY_TOKEN=clawdbot-local-dev`.
- Updated plist to use the new secure token.
- Reloaded the LaunchAgent service.

### 3. Restored Valid Device Pairing

- Identified the existing TW device token from the node (`f653...`).
- Manually updated `~/.clawdbot/devices/paired.json` on the Gateway to match this valid token.
- Ensured the Device ID `eb8bf...` was correctly mapped.

### 4. Restarted Infrastructure

- Restarted Gateway Service.
- Restarted TW Node Service.

## Result: ✅ Full Success

- **Gateway**: Running locally (PID 87851) with secure token `c224f9cb...`.
- **TW Node**: Fully Connected and Paired.
- **Dashboard**: Accessible and Authorized.

### Root Cause Analysis (Crucial Discovery)

The persistent "Token Mismatch" and "Pairing Required" errors were caused by a **Docker Container Conflict**:

1.  **The Issue**: A hidden Docker container (`clawdbot-gateway-secure`, ID: `c87d87e9ba59`) was running in the background and binding port `18789`.
2.  **The Conflict**: This container was intercepting all traffic to the gateway port, masking the actual local `clawdbot-gateway` service.
3.  **The Confusion**: The container was configured with the old `clawdbot-local-dev` token, causing checks to fail even though the local files and environment variables were updated correctly.
4.  **The Fix**: Stopped the Docker container (`docker stop`), allowing the correct local service to bind the port.

## Verification

### 1. CLI Confirmation

Running `clawdbot nodes list` now confirms the connection:

```bash
CLAWDBOT_GATEWAY_TOKEN="c224..." clawdbot nodes list
```

### 2. Visual Confirmation (PASSED)

The connection was verified via the Clawdbot Dashboard:

1.  **Dashboard Access**: Successful login at `http://localhost:18789/?token=c224...` (no token mismatch).
2.  **Node Status**: The "TW" node (192.168.1.245) appears in the **Instances** list with "Health: OK".
3.  **Connectivity**: Validated via `lsof` showing an ESTABLISHED TCP connection from the remote node to the local gateway process.

## Final Resolution (2026-01-29)

### 1. Unified Node/Gateway Identity

- **Resolved Token Mismatch**: Discovered the TW node was using the Gateway Admin Token for pairing, which is rejected by the gateway's device-pairing logic.
- **Fix**: Replaced with the specific pairing token (`f988...`) generated for device `7b2b6fa7...`.
- **Result**: Immediate successful WebSocket handshake (Error 1006 resolved).

### 2. Infrastructure Optimization

- **Service Cleanup**: Detected a redundant `com.clawdbot.gateway` service running on the TW Mac. It was blocking the correct binding of its node role and consuming CPU.
- **Fix**: Permanently disabled the local gateway on the worker node.
- **Performance**: Freed up memory and CPU cycles on the dual-core MacBook.

### 3. Capacity Verification

- **Verified Connectivity**: Used `clawdbot nodes status` to confirm the node is "Green" and reporting version `2026.1.24-3`.
- **Functional Test**: Successfully executed `uptime` and `hostname` via `clawdbot nodes run --node TW`.

---

## Conclusion

The TW Worker node is now fully integrated into the distributed system. Future connection issues should be checked against:

1. `~/.clawdbot/devices/paired.json` on the Gateway.
2. `~/.clawdbot/clawdbot.json` on the Node (ensuring the token matches the pairing database, not the gateway admin secret).
