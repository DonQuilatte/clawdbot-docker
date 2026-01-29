# Token Architecture Review & Alternative Best Practices

**Date:** 2026-01-28  
**Status:** 🔴 CRITICAL - System is Brittle and Bug-Prone  
**Priority:** High

---

## Executive Summary

The current token-based connection system in Clawdbot exhibits **severe architectural brittleness** that has led to repeated connection failures, configuration mismatches, and operational instability. This document analyzes the root causes and proposes industry-standard alternatives.

### Key Findings

1. **Multiple Token Sources of Truth** - Tokens are configured in 6+ different locations
2. **No Token Lifecycle Management** - Manual rotation, no expiration, no revocation
3. **Configuration Drift** - Environment variables, config files, and LaunchAgents frequently diverge
4. **Poor Error Messages** - Silent failures make debugging extremely difficult
5. **Device Pairing Complexity** - Separate device identity tokens add additional failure points

---

## Current Architecture Problems

### Problem 1: Token Configuration Sprawl

**Current State:** Tokens are defined in multiple locations without synchronization:

```
1. ~/.clawdbot/clawdbot.json (gateway.remote.token)
2. .env file (CLAWDBOT_GATEWAY_TOKEN)
3. Environment variables (exported in shell)
4. LaunchAgent plist (hardcoded in EnvironmentVariables section)
5. Docker Compose files (docker-compose.secure.yml)
6. Scripts and CLI commands (passed via --token flag)
7. Device pairing files (~/.clawdbot/devices/paired.json)
```

**Impact:**

- Configuration drift causes "token mismatch" errors
- Changes in one location don't propagate to others
- No single source of truth
- Debugging requires checking 6+ locations

**Evidence from Recent Issues:**

```
TW_NODE_RESOLUTION.md:
"The Gateway LaunchAgent had a hardcoded placeholder token
(clawdbot-local-dev) that overrode the configuration file."

"A hidden Docker container was intercepting all traffic to the
gateway port, configured with the old clawdbot-local-dev token."

TW_NODE_TROUBLESHOOTING_SESSION_2026-01-28.md:
"32 minutes of intensive troubleshooting - all configuration verified
correct (token, URL, network), device pairing approved successfully,
LaunchAgent properly configured. Result: WebSocket error 1006 with
EMPTY error message. Zero connection attempts in gateway logs despite
node running. No diagnostic information available to identify root
cause. BLOCKED - requires source code access or developer support."
```

### Problem 2: Weak Token Security

**Current Practice:**

```bash
# From .env file
CLAWDBOT_GATEWAY_TOKEN=clawdbot-local-dev

# From README.md
"token": "clawdbot-local-dev"
```

**Issues:**

- Placeholder tokens (`clawdbot-local-dev`) are used in production
- Tokens are stored in plaintext in multiple files
- No token rotation policy
- No expiration dates
- Tokens are committed to documentation examples

**Best Practice Violations:**

- ❌ No token rotation
- ❌ No expiration dates
- ❌ Plaintext storage
- ❌ Weak default tokens
- ❌ Same token for dev and prod

### Problem 3: Device Pairing Adds Complexity

**Current System:** Two-layer authentication:

1. **Gateway Token** - Authenticates node to gateway
2. **Device Identity** - Separate device ID and token in `paired.json`

```json
// ~/.clawdbot/devices/paired.json
{
  "deviceId": "eb8bf03650f91c6d67fddc4d1a427f4ce2fdcc9161c0a98c838e0155612f44a1",
  "token": "f653..."
}
```

**Problems:**

- Two tokens must match for connection to work
- Manual editing of `paired.json` required after token changes
- Device re-pairing loses execution history
- No automated device approval workflow
- Deleting `~/.clawdbot` requires full re-pairing (current blocker)

### Problem 4: Silent Failures

**Current Behavior:**

```bash
# TW Node logs show:
node host PATH: /Users/tywhitaker/.nvm/versions/node/v24.13.0/bin:/usr/local/bin
[No additional output]

# Gateway logs show:
[No connection attempts from 192.168.1.245 since restart]
```

**Issues:**

- TCP connection succeeds but WebSocket handshake fails silently
- No error messages indicating auth failures
- No verbose/debug mode for troubleshooting
- Logs don't show which token was attempted
- No token validation endpoint

### Problem 5: Configuration Precedence Ambiguity

**Current Lookup Order (from `scripts/lib/common.sh`):**

```bash
get_gateway_token() {
    # Try environment first
    if [ -n "${CLAWDBOT_GATEWAY_TOKEN:-}" ]; then
        echo "$CLAWDBOT_GATEWAY_TOKEN"
        return 0
    fi

    # Try .env file
    if [ -f .env ]; then
        token=$(grep "^CLAWDBOT_GATEWAY_TOKEN=" .env 2>/dev/null | cut -d= -f2)
        ...
    fi
}
```

**Problems:**

- LaunchAgent environment variables override config files
- No clear precedence documented
- Different tools may use different precedence orders
- Race conditions when multiple sources exist
- No validation that all sources match

---

## Root Causes

### 1. **Stateful Authentication** vs **Stateless Tokens**

Current system uses long-lived static tokens that require state synchronization across:

- Gateway configuration
- Remote node configuration
- Device pairing database
- Environment variables
- LaunchAgent configurations

**Better Approach:** Modern authentication uses stateless tokens (JWT) or certificate-based auth that don't require database lookups.

### 2. **No Secrets Management**

Tokens are managed manually with copy/paste and shell variables.

**Missing:**

- Secret rotation automation
- Centralized secrets store (1Password CLI mentioned but not enforced)
- Audit trail of secret access
- Automatic secret injection

### 3. **Monolithic Token Design**

Single token grants full gateway access with no:

- Scopes/permissions
- Role-based access control (RBAC)
- Temporary access tokens
- Service accounts vs user accounts

### 4. **No Health/Validation Endpoints**

Missing critical observability:

- No `/auth/validate` endpoint to test tokens
- No `/devices/pending` to list waiting approvals
- No connection status in logs
- No token expiration warnings

---

## Industry Best Practices

### 1. **Certificate-Based Mutual TLS (mTLS)**

**How it Works:**

```
Gateway (Server)          Remote Node (Client)
    |                            |
    |<-- TLS Handshake -------->|
    |    Client Certificate     |
    |    Server Certificate     |
    |                            |
    |<-- Encrypted Channel ---->|
```

**Benefits:**

- ✅ Automatic expiration (certificate validity period)
- ✅ No shared secrets to synchronize
- ✅ Strong cryptographic identity
- ✅ Built-in revocation (certificate revocation lists)
- ✅ Industry standard (used by Kubernetes, gRPC, etc.)

**Implementation:**

```bash
# Generate CA
openssl genrsa -out ca-key.pem 4096
openssl req -new -x509 -days 365 -key ca-key.pem -out ca.pem

# Generate client certificate
openssl genrsa -out client-key.pem 4096
openssl req -new -key client-key.pem -out client.csr
openssl x509 -req -days 90 -in client.csr -CA ca.pem -CAkey ca-key.pem -out client.pem

# Gateway validates client certificate against CA
# Automatic rotation after 90 days
```

### 2. **Short-Lived Tokens with Refresh Mechanism**

**Standard Pattern (OAuth2-style):**

```
Access Token:  Expires in 1 hour  (used for API calls)
Refresh Token: Expires in 30 days (used to get new access tokens)
```

**Example Flow:**

```javascript
// Node connects with refresh token
POST /auth/token
{
  "refresh_token": "long-lived-refresh-token",
  "device_id": "tw-node"
}

// Gateway responds
{
  "access_token": "jwt-token-expires-1h",
  "expires_in": 3600
}

// Node uses access token for all requests
// Automatically refreshes when expired
```

**Benefits:**

- ✅ Short-lived tokens reduce blast radius
- ✅ Automatic rotation every hour
- ✅ Can revoke refresh tokens to force re-auth
- ✅ Standard pattern (used by Google, GitHub, etc.)

### 3. **JWT with Claims and Scopes**

**Token Structure:**

```json
{
  "iss": "clawdbot-gateway",
  "sub": "device:tw-node",
  "aud": "clawdbot-api",
  "exp": 1706476800,
  "iat": 1706473200,
  "scope": "node:execute node:status",
  "device_id": "tw-node-uuid"
}
```

**Benefits:**

- ✅ Self-contained (no database lookup)
- ✅ Automatic expiration enforcement
- ✅ Granular permissions (scopes)
- ✅ Tamper-proof (signed by gateway)
- ✅ Can include device metadata

### 4. **Secrets Management Integration**

**Use 1Password CLI (already referenced in config/.env.example):**

```bash
# .env (no secrets stored)
CLAWDBOT_GATEWAY_TOKEN=op://Developer/Clawdbot/gateway-token

# Scripts automatically fetch
export CLAWDBOT_GATEWAY_TOKEN=$(op read "op://Developer/Clawdbot/gateway-token")
```

**Or HashiCorp Vault:**

```bash
vault kv get -field=token clawdbot/gateway
```

**Benefits:**

- ✅ Single source of truth
- ✅ Audit trail of access
- ✅ Automatic rotation support
- ✅ No plaintext secrets in files
- ✅ Team access control

### 5. **Device Registration Workflow**

**Better Pattern:**

```
1. New node generates device keypair
2. Node sends certificate signing request (CSR) to gateway
3. Gateway admin approves via CLI/dashboard
4. Gateway signs certificate and returns
5. Node uses certificate for all future connections
```

**CLI Example:**

```bash
# On new node
clawdbot node register --gateway ws://192.168.1.230:18789

Output:
Registration pending. Ask admin to approve:
  clawdbot devices approve tw-node-abc123

# On gateway
clawdbot devices list --pending
  - tw-node-abc123 (192.168.1.245) - Pending approval

clawdbot devices approve tw-node-abc123
  ✅ Approved. Node will connect automatically.
```

**Benefits:**

- ✅ Interactive approval process
- ✅ No manual token sharing
- ✅ Clear pending/approved state
- ✅ One-time setup per device

---

## Recommended Architecture

### Option A: mTLS (Recommended for Production)

**Architecture:**

```
┌─────────────────────────────────────────────────────────┐
│ Gateway (192.168.1.230)                                 │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ TLS Server                                          │ │
│ │ - Requires client certificates                     │ │
│ │ - Validates against CA                             │ │
│ │ - Extracts device ID from certificate CN          │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                          ▲
                          │ mTLS (WSS://)
                          │
┌─────────────────────────┼───────────────────────────────┐
│ Remote Node (192.168.1.245)                             │
│ ┌───────────────────────────────────────────────────┐   │
│ │ TLS Client                                        │   │
│ │ - Presents client certificate                     │   │
│ │ - Validates server certificate                    │   │
│ │ - Auto-reconnect with same certificate           │   │
│ └───────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**Configuration:**

```json
// Gateway: ~/.clawdbot/clawdbot.json
{
  "gateway": {
    "mode": "local",
    "tls": {
      "enabled": true,
      "cert": "~/.clawdbot/certs/server.pem",
      "key": "~/.clawdbot/certs/server-key.pem",
      "ca": "~/.clawdbot/certs/ca.pem",
      "requireClientCert": true
    }
  }
}

// Node: ~/.clawdbot/clawdbot.json
{
  "gateway": {
    "mode": "remote",
    "remote": {
      "url": "wss://192.168.1.230:18789",
      "tls": {
        "cert": "~/.clawdbot/certs/tw-node.pem",
        "key": "~/.clawdbot/certs/tw-node-key.pem",
        "ca": "~/.clawdbot/certs/ca.pem"
      }
    }
  }
}
```

### Option B: JWT with API Key (Simpler, Still Better)

**Architecture:**

```
Gateway                           Node
   │                               │
   │<── POST /auth/login ──────────│
   │    { apiKey: "..." }          │
   │                               │
   │─── {accessToken: "jwt"} ────>│
   │    { expiresIn: 3600 }        │
   │                               │
   │<── WS upgrade (JWT) ──────────│
   │    Authorization: Bearer jwt  │
   │                               │
   │<──── Commands (JWT) ──────────│
   │                               │
   │── (Auto-refresh at 50min) ──>│
```

**Benefits:**

- ✅ Simpler than mTLS
- ✅ Still provides automatic expiration
- ✅ Easy to implement refresh logic
- ✅ Can revoke API keys independently

---

## Migration Plan

### Phase 1: Immediate Fixes (Week 1)

1. **Consolidate Token Configuration**

   ```bash
   # Single source of truth: .env file
   # All scripts read from .env only
   # Remove hardcoded tokens from LaunchAgents
   # Add validation script to check consistency
   ```

2. **Add Token Validation Endpoint**

   ```bash
   curl -H "Authorization: Bearer $TOKEN" \
        http://localhost:18789/api/auth/validate

   # Returns: {"valid": true, "deviceId": "tw-node"}
   ```

3. **Improve Error Logging**
   ```javascript
   // Add to gateway
   logger.warn("WebSocket auth failed", {
     remoteIp: "192.168.1.245",
     tokenPrefix: token.substring(0, 8),
     reason: "token mismatch",
   });
   ```

### Phase 2: Architecture Upgrade (Week 2-3)

1. **Implement JWT Access Tokens**

   - Keep existing API keys as long-lived credentials
   - Exchange API key → JWT at connection time
   - JWT expires in 1 hour, auto-refresh

2. **Add Device Registration Flow**
   - `clawdbot node register` command
   - Gateway approval workflow
   - Automatic certificate/token provisioning

### Phase 3: Security Hardening (Week 4)

1. **Integrate Secrets Manager**

   - Use 1Password CLI for token storage
   - Remove plaintext tokens from files
   - Audit trail of token access

2. **Add Token Rotation**
   - Monthly rotation schedule
   - Automated rollover process
   - Zero-downtime rotation

---

## Debugging Improvements

### Add Verbose Diagnostics

```bash
# Node should show
clawdbot node status --verbose

Output:
Status: Disconnected
Config: ~/.clawdbot/clawdbot.json
Gateway URL: ws://192.168.1.230:18789
Token: c224f9cb... (first 8 chars)
Last Connection Attempt: 2026-01-28T19:00:00Z
Last Error: WebSocket upgrade failed: 401 Unauthorized
Network: Gateway reachable ✅
Certificate: Valid until 2026-04-28 ✅
```

### Add Connection Testing Tool

```bash
clawdbot node test-connection --gateway ws://192.168.1.230:18789

Output:
1. DNS Resolution: 192.168.1.230 ✅
2. TCP Connection: port 18789 ✅
3. HTTP Health Check: /health OK ✅
4. WebSocket Upgrade: ❌ 401 Unauthorized
   → Check token in ~/.clawdbot/clawdbot.json
   → Token prefix: c224f9cb
   → Expected by gateway: a1b2c3d4
```

---

## Comparison: Current vs Proposed

| Aspect                 | Current System      | Proposed (mTLS)      | Proposed (JWT)       |
| ---------------------- | ------------------- | -------------------- | -------------------- |
| **Token Lifespan**     | Infinite            | 90 days (cert)       | 1 hour (access)      |
| **Rotation**           | Manual              | Automatic            | Automatic            |
| **Revocation**         | Delete config file  | CRL/OCSP             | Revoke API key       |
| **Configuration**      | 6+ locations        | 2 files (cert + key) | 1 file (.env)        |
| **Secrets Management** | Plaintext           | Key storage          | 1Password CLI        |
| **Error Messages**     | Silent failures     | TLS errors visible   | HTTP 401 with reason |
| **Device Pairing**     | Manual JSON editing | Automated CSR flow   | API key provisioning |
| **Debugging**          | Check 6+ locations  | Check certificate    | Check JWT claims     |
| **Security**           | Weak (static token) | Strong (mTLS)        | Good (time-limited)  |

---

## Recommendations Summary

### Immediate (This Week)

1. ✅ **Consolidate token configuration** to `.env` file only
2. ✅ **Remove hardcoded tokens** from LaunchAgent plists
3. ✅ **Add token validation endpoint** for testing
4. ✅ **Improve error logging** with token prefix and failure reason
5. ✅ **Create token sync validation script**

### Short-Term (Next 2 Weeks)

1. ✅ **Implement JWT access tokens** (keep API keys for bootstrapping)
2. ✅ **Add device registration workflow** (approve/deny via CLI)
3. ✅ **Integrate 1Password CLI** for secret storage
4. ✅ **Add connection testing tool** (`clawdbot node test-connection`)

### Long-Term (Next Month)

1. ✅ **Migrate to mTLS** for production deployments
2. ✅ **Implement automated token rotation**
3. ✅ **Add role-based access control** (RBAC)
4. ✅ **Create audit logging** for all auth events

---

## References

- **OAuth 2.0 Best Practices:** https://datatracker.ietf.org/doc/html/draft-ietf-oauth-security-topics
- **mTLS in Practice:** https://www.cloudflare.com/learning/access-management/what-is-mutual-tls/
- **JWT Handbook:** https://auth0.com/resources/ebooks/jwt-handbook
- **1Password CLI:** https://developer.1password.com/docs/cli/
- **HashiCorp Vault:** https://www.vaultproject.io/docs

---

**Status:** 📋 Review Complete - Awaiting Implementation Decision
**Next Step:** Choose between mTLS (secure) or JWT (simpler) approach
