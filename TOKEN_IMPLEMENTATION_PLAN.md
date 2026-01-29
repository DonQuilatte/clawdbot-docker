# Implementation Plan: Token Architecture Fixes

**Date:** 2026-01-28  
**Priority:** HIGH  
**Timeline:** 1-4 weeks

---

## Overview

This document provides a concrete, step-by-step plan to migrate from the current brittle token system to a more robust architecture.

---

## Phase 1: Immediate Stabilization (This Week)

### Goal

Fix the current system to make it reliable without major architectural changes.

### Tasks

#### 1.1 Single Source of Truth for Tokens

**Problem:** Tokens are defined in 6+ locations and frequently get out of sync.

**Solution:**

```bash
# 1. Choose .env as the single source of truth
cat > .env << 'EOF'
# Gateway Configuration
CLAWDBOT_GATEWAY_TOKEN=<GENERATE_SECURE_TOKEN>

# Generate with: openssl rand -hex 32
EOF

# 2. Update all scripts to read from .env ONLY
# Modify scripts/lib/common.sh:

get_gateway_token() {
    # ONLY read from .env (remove environment variable fallback)
    if [ ! -f .env ]; then
        echo "ERROR: .env file not found" >&2
        return 1
    fi

    local token
    token=$(grep "^CLAWDBOT_GATEWAY_TOKEN=" .env 2>/dev/null | cut -d= -f2)

    if [ -z "$token" ]; then
        echo "ERROR: CLAWDBOT_GATEWAY_TOKEN not set in .env" >&2
        return 1
    fi

    echo "$token"
}
```

**Action Items:**

- [ ] Generate new secure token: `openssl rand -hex 32`
- [ ] Update `.env` with new token
- [ ] Update `~/.clawdbot/clawdbot.json` on gateway to read from env
- [ ] Update `~/.clawdbot/clawdbot.json` on TW node
- [ ] Remove hardcoded tokens from LaunchAgent plists
- [ ] Restart both gateway and node

**Validation:**

```bash
./scripts/validate-token-config.sh
# Should show all tokens matching
```

#### 1.2 Remove LaunchAgent Token Override

**Problem:** LaunchAgent plists have hardcoded tokens that override config files.

**Solution:**

```bash
# Gateway LaunchAgent
cat > ~/Library/LaunchAgents/com.clawdbot.gateway.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.clawdbot.gateway</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>
            # Source .env to get token
            cd /Users/jederlichman/Development/Projects/clawdbot
            set -a; source .env; set +a
            exec clawdbot gateway start --bind lan
        </string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/clawdbot-gateway.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/clawdbot-gateway.err.log</string>
</dict>
</plist>
EOF

# Reload
launchctl unload ~/Library/LaunchAgents/com.clawdbot.gateway.plist
launchctl load ~/Library/LaunchAgents/com.clawdbot.gateway.plist
```

**Action Items:**

- [ ] Update gateway LaunchAgent to source .env
- [ ] Update node LaunchAgent to source .env
- [ ] Test service restart
- [ ] Verify token is loaded from .env

#### 1.3 Add Token Validation Logging

**Problem:** Silent failures make debugging impossible.

**Solution:** Add verbose logging to clawdbot startup

```bash
# Add to gateway startup
CLAWDBOT_LOG_LEVEL=debug clawdbot gateway start

# Verify token is loaded
echo "Loaded token: ${CLAWDBOT_GATEWAY_TOKEN:0:8}..." >> /tmp/clawdbot-startup.log
```

**Action Items:**

- [ ] Enable debug logging: `CLAWDBOT_LOG_LEVEL=debug`
- [ ] Add token validation logging (first 8 chars only)
- [ ] Log all connection attempts with source IP
- [ ] Log auth failures with reason

#### 1.4 Create Token Sync Script

**Problem:** After changing token, must update multiple locations manually.

**Solution:**

```bash
#!/bin/bash
# scripts/sync-token.sh
# Synchronizes token across all locations

NEW_TOKEN="${1:-}"

if [ -z "$NEW_TOKEN" ]; then
    echo "Usage: $0 <new-token>"
    echo "Generate: openssl rand -hex 32"
    exit 1
fi

echo "Updating token to: ${NEW_TOKEN:0:8}..."

# 1. Update .env
sed -i.bak "s/^CLAWDBOT_GATEWAY_TOKEN=.*/CLAWDBOT_GATEWAY_TOKEN=$NEW_TOKEN/" .env

# 2. Update gateway config
python3 << EOF
import json
config_path = "$HOME/.clawdbot/clawdbot.json"
with open(config_path) as f:
    config = json.load(f)
config.setdefault('gateway', {})['token'] = '$NEW_TOKEN'
with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)
EOF

# 3. Update remote node (via SSH)
if [ -n "${REMOTE_HOST:-}" ]; then
    ssh "$REMOTE_USER@$REMOTE_HOST" python3 << 'EOF'
import json
config_path = "$HOME/.clawdbot/clawdbot.json"
with open(config_path) as f:
    config = json.load(f)
config['gateway']['remote']['token'] = '$NEW_TOKEN'
with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)
EOF
fi

# 4. Restart services
clawdbot gateway restart
ssh "$REMOTE_USER@$REMOTE_HOST" 'clawdbot node restart'

echo "✅ Token synchronized across all locations"
```

**Action Items:**

- [ ] Create sync-token.sh script
- [ ] Test token update process
- [ ] Document token rotation procedure

---

## Phase 2: Add Short-Lived Tokens (Week 2-3)

### Goal

Implement JWT-based access tokens while keeping API keys for initial auth.

### Architecture

```
                     Initial Connection
Node ──────────────────────────────────────────> Gateway
     { apiKey: "long-lived-key" }

                     JWT Response
Node <────────────────────────────────────────── Gateway
     { accessToken: "jwt", expiresIn: 3600 }

                   Regular Operations
Node ──────────────────────────────────────────> Gateway
     Authorization: Bearer <jwt>

                  Auto-refresh (50min)
Node ──────────────────────────────────────────> Gateway
     { refreshToken: "jwt" }
```

### Implementation

#### 2.1 Install JWT Library

```bash
npm install jsonwebtoken
```

#### 2.2 Create JWT Signing Service

```javascript
// ~/.clawdbot/lib/auth/jwt-service.js

const jwt = require("jsonwebtoken");
const crypto = require("crypto");

class JWTService {
  constructor() {
    // Use gateway token as JWT secret
    this.secret = process.env.CLAWDBOT_GATEWAY_TOKEN;
    if (!this.secret) {
      throw new Error("CLAWDBOT_GATEWAY_TOKEN not set");
    }
  }

  // Generate access token (1 hour)
  generateAccessToken(deviceId) {
    return jwt.sign(
      {
        iss: "clawdbot-gateway",
        sub: `device:${deviceId}`,
        aud: "clawdbot-api",
        scope: "node:execute node:status",
        device_id: deviceId,
      },
      this.secret,
      { expiresIn: "1h" },
    );
  }

  // Verify token
  verifyToken(token) {
    try {
      return jwt.verify(token, this.secret);
    } catch (err) {
      throw new Error(`Invalid token: ${err.message}`);
    }
  }

  // Check if token expires soon (within 10 min)
  shouldRefresh(token) {
    const decoded = jwt.decode(token);
    if (!decoded || !decoded.exp) return true;

    const expiresIn = decoded.exp - Math.floor(Date.now() / 1000);
    return expiresIn < 600; // 10 minutes
  }
}

module.exports = JWTService;
```

#### 2.3 Update Gateway to Issue JWTs

Add endpoint to exchange API key for JWT:

```javascript
// Gateway: Add to WebSocket connection handler

app.post("/auth/login", (req, res) => {
  const { apiKey, deviceId } = req.body;

  // Validate API key
  if (apiKey !== process.env.CLAWDBOT_GATEWAY_TOKEN) {
    return res.status(401).json({ error: "Invalid API key" });
  }

  // Generate JWT
  const jwtService = new JWTService();
  const accessToken = jwtService.generateAccessToken(deviceId);

  res.json({
    accessToken,
    tokenType: "Bearer",
    expiresIn: 3600,
  });
});
```

#### 2.4 Update Node to Use JWTs

```javascript
// Node: Update connection logic

class NodeClient {
  constructor() {
    this.apiKey = process.env.CLAWDBOT_GATEWAY_TOKEN;
    this.accessToken = null;
    this.deviceId = this.loadDeviceId();
  }

  async connect() {
    // 1. Get JWT
    await this.login();

    // 2. Connect WebSocket with JWT
    this.ws = new WebSocket(this.gatewayUrl, {
      headers: {
        Authorization: `Bearer ${this.accessToken}`,
      },
    });

    // 3. Setup auto-refresh
    setInterval(() => this.refreshTokenIfNeeded(), 60000); // Check every minute
  }

  async login() {
    const response = await fetch(`${this.gatewayUrl}/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        apiKey: this.apiKey,
        deviceId: this.deviceId,
      }),
    });

    const { accessToken } = await response.json();
    this.accessToken = accessToken;
  }

  async refreshTokenIfNeeded() {
    const jwtService = new JWTService();
    if (jwtService.shouldRefresh(this.accessToken)) {
      await this.login();
    }
  }
}
```

**Action Items:**

- [ ] Install jsonwebtoken package
- [ ] Create JWTService class
- [ ] Add /auth/login endpoint to gateway
- [ ] Update node client to use JWTs
- [ ] Add auto-refresh logic
- [ ] Test token expiration and refresh

---

## Phase 3: Secrets Management (Week 3-4)

### Goal

Remove plaintext tokens from files using 1Password CLI.

### Implementation

#### 3.1 Install 1Password CLI

```bash
brew install --cask 1password-cli
```

#### 3.2 Store Token in 1Password

```bash
# Create item in 1Password
op item create \
  --category=password \
  --title="Clawdbot Gateway Token" \
  --vault=Developer \
  token=$(openssl rand -hex 32)

# Reference in .env
cat > .env << 'EOF'
CLAWDBOT_GATEWAY_TOKEN=op://Developer/Clawdbot Gateway Token/token
EOF
```

#### 3.3 Update Scripts to Fetch from 1Password

```bash
# scripts/lib/common.sh

get_gateway_token() {
    local token_ref
    token_ref=$(grep "^CLAWDBOT_GATEWAY_TOKEN=" .env | cut -d= -f2)

    # Check if it's a 1Password reference
    if [[ "$token_ref" == op://* ]]; then
        # Fetch from 1Password
        op read "$token_ref"
    else
        # Return literal value
        echo "$token_ref"
    fi
}
```

**Action Items:**

- [ ] Install 1Password CLI
- [ ] Store token in 1Password vault
- [ ] Update .env with op:// reference
- [ ] Update get_gateway_token() to fetch from 1Password
- [ ] Test token retrieval
- [ ] Remove plaintext tokens from all files

---

## Phase 4: mTLS Migration (Long-term)

### Goal

Replace token auth with certificate-based mTLS (most secure).

### Implementation

See `TOKEN_ARCHITECTURE_REVIEW.md` → "Option A: mTLS" section for full details.

**High-level steps:**

1. Generate CA certificate
2. Generate server certificate for gateway
3. Generate client certificates for each node
4. Update gateway to require client certificates
5. Update nodes to present client certificates
6. Setup certificate rotation (90 days)

---

## Rollback Plan

If any phase causes issues:

### Rollback Phase 2/3 (JWT or 1Password)

```bash
# Revert to Phase 1 (static tokens)
git checkout main -- .env
git checkout main -- scripts/lib/common.sh
clawdbot gateway restart
ssh $REMOTE_USER@$REMOTE_HOST 'clawdbot node restart'
```

### Rollback Phase 1

```bash
# Restore from backup
cp .env.backup .env
cp ~/.clawdbot/clawdbot.json.backup ~/.clawdbot/clawdbot.json

# Restart services
clawdbot gateway restart
```

---

## Success Metrics

### Phase 1

- [ ] Token validation script passes with 0 errors
- [ ] All connection attempts succeed on first try
- [ ] No token mismatch errors in logs
- [ ] TW node connects within 5 seconds of startup

### Phase 2

- [ ] JWTs are issued and validated successfully
- [ ] Tokens auto-refresh before expiration
- [ ] No connection drops during token refresh
- [ ] Average token lifetime is ~50 minutes

### Phase 3

- [ ] No plaintext tokens in any files
- [ ] All scripts fetch tokens from 1Password
- [ ] Token rotation takes < 1 minute
- [ ] No service downtime during rotation

### Phase 4

- [ ] All connections use mTLS
- [ ] Certificate rotation is automated
- [ ] No token-related errors in logs
- [ ] Zero-trust authentication model

---

## Testing Checklist

After each phase:

- [ ] Gateway starts successfully
- [ ] Node connects to gateway
- [ ] Dashboard shows node as "Connected"
- [ ] Remote command execution works: `clawdbot nodes run --node TW -- hostname`
- [ ] Service survives restart (LaunchAgent test)
- [ ] Token validation script passes
- [ ] No errors in gateway logs
- [ ] No errors in node logs

---

## Documentation Updates

After implementation:

- [ ] Update README.md with new token setup instructions
- [ ] Update DISTRIBUTED_TROUBLESHOOTING.md with new debugging steps
- [ ] Create TOKEN_ROTATION.md guide
- [ ] Update all script help/usage messages
- [ ] Update LaunchAgent examples

---

**Next Step:** Begin Phase 1.1 - Single Source of Truth for Tokens
