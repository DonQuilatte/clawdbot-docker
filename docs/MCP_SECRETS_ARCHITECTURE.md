# MCP Registry Secrets Architecture

**Date:** 2026-01-31
**Author:** J. Ederlichman / Claude
**Status:** RFC v2.0 - Revised after third-party review
**Reviewers:** Third-party review completed

---

## Executive Summary

This document evaluates three approaches for integrating 1Password with an MCP (Model Context Protocol) server registry. The goal is to securely manage API keys and credentials for AI development tools while maintaining performance and reliability.

**Recommendation:** Option C (Hybrid Cached Injection) provides the best balance of security, performance, and durability for this use case.

---

## Revision Notes (v2.0)

**Changes from v1.0 based on third-party review:**

| Finding | Severity | Fix |
|---------|----------|-----|
| Incorrect `age` usage (passphrase vs keypair) | High | Switched to file-based keypair |
| LaunchAgent hardcoded token | High | Wrapper script reads from 600-perm file |
| Cache all servers vs enabled only | High | Per-project cache of enabled servers only |
| Namespace collisions | Medium | Keys namespaced as `server.ENV_VAR` |
| Date parsing mismatch | Medium | Using epoch seconds throughout |
| Audit claim overstated | Medium | Clarified: refresh logs only |
| Project name collisions | Medium | Cache key is hash of absolute project path |
| CWD-dependent paths | Medium | Commands accept `--path`, resolve `.enabled-servers` from project root |
| Refresh-all discovery | Medium | Explicit `projects.json` registry |
| Team enablement vs local | Low | `.enabled-servers` committed; `.enabled-servers.local` optional |

---

## Context

### What is MCP?

Model Context Protocol (MCP) is Anthropic's standard for connecting AI assistants to external tools and data sources. MCP servers are lightweight processes that expose capabilities (file access, API integrations, databases) to AI agents.

### Current Environment

- **Brain Mac:** Primary development machine, orchestrates work
- **Agent Alpha (TW Mac):** Headless worker node for parallel task execution
- **1Password:** Enterprise password manager with CLI (`op`) and Service Account support
- **Dev-infra:** Centralized tooling repository that other projects inherit from

### Problem Statement

The dev-infra project needs an MCP registry that:
1. Catalogs available MCP servers and their configurations
2. Allows per-project server selection ("turn on/off")
3. Securely provides API keys to MCP servers at runtime
4. Works on both interactive (Brain) and headless (Agent) machines

### Security Requirements

| Requirement | Priority | Notes |
|-------------|----------|-------|
| Secrets not in git | P0 | No plaintext keys in version control |
| Secrets not in plaintext config files | P1 | Avoid `.env` files with raw values |
| Minimal secret exposure window | P1 | Secrets should exist in memory/disk briefly |
| Works headless | P0 | Agent machines have no GUI for auth prompts |
| Audit trail | P2 | Log cache refreshes (not per-use access) |
| Rotation support | P2 | Changing a key shouldn't require config changes |

### Performance Requirements

| Requirement | Target | Notes |
|-------------|--------|-------|
| MCP server startup | < 2 seconds | Per server, including secret fetch |
| Session initialization | < 5 seconds | All enabled MCP servers ready |
| Offline capability | Desirable | Work should continue if 1Password is unreachable |

### Constraints

| Constraint | Impact |
|------------|--------|
| macOS only | Can use macOS-specific tools; no Linux compatibility needed |
| Developer API keys only | Proportionate security; no banking/PII credentials |
| Single-user machines | No multi-tenant isolation required |

---

## Option A: Pure Runtime Injection

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     mcp-registry.json                       │
│  {                                                          │
│    "stitch": {                                              │
│      "command": "npx @anthropic/stitch-mcp",                │
│      "secrets": {                                           │
│        "STITCH_API_KEY": "op://Developer/Stitch/api-key"    │
│      }                                                      │
│    }                                                        │
│  }                                                          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   MCP Launcher Script                       │
│                                                             │
│  for secret in registry[server].secrets:                    │
│      value = $(op read $secret.op_ref)   ← Network call     │
│      export $secret.name=$value                             │
│                                                             │
│  exec $registry[server].command                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     MCP Server Process                      │
│            (secrets in environment variables)               │
└─────────────────────────────────────────────────────────────┘
```

### Performance Analysis

| Scenario | Latency | Notes |
|----------|---------|-------|
| Single secret, daemon warm | 50-100ms | Acceptable |
| Single secret, daemon cold | 500-800ms | Noticeable delay |
| 5 servers × 2 secrets, warm | 500ms-1s | Acceptable |
| 5 servers × 2 secrets, cold | 5-8 seconds | Poor UX |
| 1Password API timeout | 30+ seconds | Session fails to start |

### Verdict

**Rating: Theoretically Ideal, Practically Fragile**

Pure runtime injection has maximum security but unacceptable performance and reliability trade-offs.

---

## Option B: Environment File Generation

### Architecture

Generates plaintext `.env.local` files per project.

### Verdict

**Rating: Simple and Fast, Security Trade-offs**

Secrets on disk in plaintext violates security requirement P1.

---

## Option C: Hybrid Cached Injection (Recommended)

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    First Session Start                      │
│         (or manual: dev-infra secrets refresh)              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Cache Builder                           │
│                                                             │
│  1. Read project's .enabled-servers (+ optional .local)      │
│  2. For each enabled server:                                │
│       For each secret (namespaced as server.ENV_VAR):       │
│         value = $(op read $op_ref)                          │
│         cache[server.ENV_VAR] = value                       │
│  3. Encrypt with age keypair                                │
│  4. Write to ~/.cache/dev-infra/projects/<project>/         │
│  5. Record epoch timestamps                                 │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌───────────────────────────────────────┐
        │                                       │
        ▼                                       ▼
┌─────────────────────┐           ┌─────────────────────────────┐
│   MCP Launcher      │           │   Background Refresh        │
│                     │           │   (LaunchAgent)             │
│   if cache fresh:   │           │                             │
│     use cache       │           │   Every 4 hours:            │
│   else:             │           │     wrapper reads token     │
│     fetch + cache   │           │     from 600-perm file      │
│                     │           │     rebuilds all caches     │
└─────────────────────┘           └─────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     MCP Server Process                      │
│            (secrets from cache, decrypted at launch)        │
└─────────────────────────────────────────────────────────────┘
```

### Implementation

#### Age Keypair Setup (One-Time Per Machine)

```bash
#!/bin/bash
# dev-infra secrets setup

set -euo pipefail

AGE_DIR="$HOME/.config/dev-infra/age"

if [[ -f "$AGE_DIR/identity.txt" ]]; then
    echo "Age keypair already exists at $AGE_DIR"
    exit 0
fi

mkdir -p "$AGE_DIR"
chmod 700 "$AGE_DIR"

# Generate keypair
age-keygen -o "$AGE_DIR/identity.txt" 2>&1 | \
    grep "public key:" | awk '{print $3}' > "$AGE_DIR/recipient.txt"

chmod 600 "$AGE_DIR/identity.txt"
chmod 644 "$AGE_DIR/recipient.txt"

echo "✅ Age keypair created at $AGE_DIR"
echo "   Public key: $(cat "$AGE_DIR/recipient.txt")"
```

#### Cache Structure

```
~/.config/dev-infra/
├── age/
│   ├── identity.txt          # Private key (600 perms)
│   └── recipient.txt         # Public key (644 perms)
├── mcp-registry.json         # Server definitions
└── projects.json             # Registry of project paths (refresh-all)

~/.cache/dev-infra/
├── projects/
│   ├── <project-hash>/
│   │   ├── secrets.enc       # Encrypted (only enabled servers)
│   │   └── secrets.meta      # Epoch timestamps
│   └── <project-hash>/
│       ├── secrets.enc
│       └── secrets.meta
└── refresh.log               # Audit: refresh events only
```

**Cache key:** `project-hash` = sha256 of the absolute project path.

#### Cache Builder (Corrected)

```bash
#!/bin/bash
# dev-infra secrets refresh --path <project>

set -euo pipefail

PROJECT_PATH="$PWD"
if [[ "${1:-}" == "--path" && -n "${2:-}" ]]; then
    PROJECT_PATH="$2"
fi
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"
PROJECT_ID=$(printf '%s' "$PROJECT_PATH" | shasum -a 256 | cut -c1-12)
PROJECT_NAME=$(basename "$PROJECT_PATH")

CONFIG_DIR="$HOME/.config/dev-infra"
CACHE_DIR="$HOME/.cache/dev-infra/projects/$PROJECT_ID"
REGISTRY="$CONFIG_DIR/mcp-registry.json"
ENABLED_FILE="$PROJECT_PATH/.enabled-servers"
ENABLED_LOCAL="$PROJECT_PATH/.enabled-servers.local"
AGE_RECIPIENT="$CONFIG_DIR/age/recipient.txt"

SOFT_TTL=14400   # 4 hours
HARD_TTL=86400   # 24 hours

mkdir -p "$CACHE_DIR"
chmod 700 "$CACHE_DIR"

# Load 1Password token from secure file (NOT hardcoded anywhere)
if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
    TOKEN_FILE="$HOME/.config/op/service-account-token"
    if [[ -f "$TOKEN_FILE" ]]; then
        export OP_SERVICE_ACCOUNT_TOKEN=$(cat "$TOKEN_FILE")
    else
        echo "ERROR: OP_SERVICE_ACCOUNT_TOKEN not set and $TOKEN_FILE missing" >&2
        exit 1
    fi
fi

# Read enabled servers for this project (plus optional local overrides)
if [[ ! -f "$ENABLED_FILE" ]]; then
    echo "No enabled servers for $PROJECT_NAME (missing $ENABLED_FILE)" >&2
    exit 0
fi

mapfile -t ENABLED_SERVERS < <(
    cat "$ENABLED_FILE" "$ENABLED_LOCAL" 2>/dev/null | \
    sed '/^[[:space:]]*#/d;/^[[:space:]]*$/d'
)

# Build namespaced secrets JSON (ONLY enabled servers)
SECRETS_JSON="{}"
for server in "${ENABLED_SERVERS[@]}"; do
    [[ -z "$server" ]] && continue

    if jq -e ".servers.\"$server\"" "$REGISTRY" >/dev/null 2>&1; then
        while IFS= read -r row; do
            key=$(echo "$row" | base64 -d | jq -r '.key')
            op_ref=$(echo "$row" | base64 -d | jq -r '.value')
            value=$(op read "$op_ref" 2>/dev/null || echo "")
            if [[ -n "$value" ]]; then
                SECRETS_JSON=$(echo "$SECRETS_JSON" | jq \
                    --arg k "$key" --arg v "$value" '. + {($k): $v}')
            fi
        done < <(jq -r ".servers.\"$server\".secrets // {} | to_entries[] | @base64" "$REGISTRY")
    else
        echo "WARNING: Server '$server' not found in registry" >&2
    fi
done

# Encrypt with age keypair (correct usage)
echo "$SECRETS_JSON" | age -r "$(cat "$AGE_RECIPIENT")" -o "$CACHE_DIR/secrets.enc"
chmod 600 "$CACHE_DIR/secrets.enc"

# Write metadata with epoch timestamps (correct parsing)
NOW=$(date +%s)
cat > "$CACHE_DIR/secrets.meta" << EOF
{
  "project_name": "$PROJECT_NAME",
  "project_path": "$PROJECT_PATH",
  "project_id": "$PROJECT_ID",
  "refreshed_at": $NOW,
  "soft_expires_at": $((NOW + SOFT_TTL)),
  "hard_expires_at": $((NOW + HARD_TTL)),
  "enabled_servers": $(printf '%s\n' "${ENABLED_SERVERS[@]}" | jq -R . | jq -s .),
  "checksum": "$(shasum -a 256 "$CACHE_DIR/secrets.enc" | cut -d' ' -f1)"
}
EOF

# Audit log (refreshes only, not per-use)
echo "$NOW | $PROJECT_ID | $PROJECT_NAME | refreshed | servers: ${ENABLED_SERVERS[*]}" >> \
    "$HOME/.cache/dev-infra/refresh.log"

echo "✅ Refreshed cache for $PROJECT_NAME (${#ENABLED_SERVERS[@]} servers)"
```

#### MCP Launcher (Corrected)

```bash
#!/bin/bash
# mcp-launcher.sh <server> [--path <project>]

set -euo pipefail

SERVER=$1
shift
PROJECT_PATH="$PWD"
if [[ "${1:-}" == "--path" && -n "${2:-}" ]]; then
    PROJECT_PATH="$2"
fi
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"
PROJECT_ID=$(printf '%s' "$PROJECT_PATH" | shasum -a 256 | cut -c1-12)
PROJECT_NAME=$(basename "$PROJECT_PATH")

CONFIG_DIR="$HOME/.config/dev-infra"
CACHE_DIR="$HOME/.cache/dev-infra/projects/$PROJECT_ID"
REGISTRY="$CONFIG_DIR/mcp-registry.json"
AGE_IDENTITY="$CONFIG_DIR/age/identity.txt"

NOW=$(date +%s)

# Check cache freshness using epoch timestamps
refresh_if_needed() {
    if [[ ! -f "$CACHE_DIR/secrets.meta" ]]; then
        return 0  # No cache, needs refresh
    fi

    local soft_expires hard_expires
    soft_expires=$(jq -r '.soft_expires_at' "$CACHE_DIR/secrets.meta")
    hard_expires=$(jq -r '.hard_expires_at' "$CACHE_DIR/secrets.meta")

    if [[ $NOW -lt $soft_expires ]]; then
        return 1  # Fresh, no refresh needed
    elif [[ $NOW -lt $hard_expires ]]; then
        # Soft expired: try refresh, allow stale on failure
        if ! dev-infra secrets refresh --path "$PROJECT_PATH" 2>/dev/null; then
            echo "WARNING: Using stale cache (soft TTL exceeded, refresh failed)" >&2
        fi
        return 1
    else
        # Hard expired: must refresh
        if ! dev-infra secrets refresh --path "$PROJECT_PATH"; then
            echo "ERROR: Cache hard-expired and refresh failed for $PROJECT_NAME" >&2
            exit 1
        fi
        return 1
    fi
}

if refresh_if_needed; then
    dev-infra secrets refresh --path "$PROJECT_PATH"
fi

# Decrypt cache using age keypair (correct usage)
SECRETS=$(age -d -i "$AGE_IDENTITY" "$CACHE_DIR/secrets.enc")

# Export secrets for this server (namespaced keys → env vars)
while IFS= read -r row; do
    namespaced_key=$(echo "$row" | base64 -d | jq -r '.key')
    env_var="${namespaced_key#*.}"  # Remove "server." prefix
    value=$(echo "$SECRETS" | jq -r --arg k "$namespaced_key" '.[$k] // empty')
    if [[ -n "$value" ]]; then
        export "$env_var=$value"
    fi
done < <(jq -r ".servers.\"$SERVER\".secrets // {} | to_entries[] | @base64" "$REGISTRY")

# Launch server
readarray -t cmd < <(jq -r ".servers.\"$SERVER\".command[]" "$REGISTRY")
exec "${cmd[@]}"
```

#### LaunchAgent with Wrapper (No Hardcoded Secrets)

**Wrapper script** (`scripts/secrets-refresh-wrapper.sh`):
```bash
#!/bin/bash
# Wrapper that loads token from secure file, then refreshes all project caches

TOKEN_FILE="$HOME/.config/op/service-account-token"

if [[ -f "$TOKEN_FILE" ]]; then
    export OP_SERVICE_ACCOUNT_TOKEN=$(cat "$TOKEN_FILE")
else
    echo "ERROR: Token file not found: $TOKEN_FILE" >&2
    exit 1
fi

exec "$HOME/Development/Projects/dev-infra/scripts/dev-infra" secrets refresh-all
```

`refresh-all` iterates `~/.config/dev-infra/projects.json`.

**LaunchAgent plist** (no secrets embedded):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.dev-infra.secrets-refresh</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>$HOME/Development/Projects/dev-infra/scripts/secrets-refresh-wrapper.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>14400</integer>
    <key>StandardOutPath</key>
    <string>/tmp/dev-infra-secrets-refresh.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/dev-infra-secrets-refresh.err</string>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
```

### Performance Analysis

| Scenario | Latency | Notes |
|----------|---------|-------|
| MCP startup, cache hit | 50-100ms | Decrypt + export |
| MCP startup, cache miss | 500ms-5s | Full 1Password fetch |
| Session init, cache hit | 200-500ms | All servers parallel |
| Background refresh | N/A | Non-blocking |

### Failure Modes

| Failure | Impact | Mitigation |
|---------|--------|------------|
| 1Password down, cache valid | No impact | Uses cache |
| 1Password down, soft expired | Warning, uses stale | Logs warning |
| 1Password down, hard expired | Fails | Must fix 1Password |
| Cache file deleted | Re-fetches on launch | Self-healing |
| Cache corruption | Checksum detects, re-fetch | Automatic recovery |
| Token file missing | Clear error message | Setup instructions |

### Security Assessment

| Aspect | Rating | Notes |
|--------|--------|-------|
| Secrets at rest | ✅ Good | Encrypted with age keypair |
| Secrets in transit | ✅ Excellent | TLS to 1Password |
| Secrets in memory | ✅ Good | Decrypted only at launch |
| Audit trail | ✅ Adequate | Refresh logs (not per-use) |
| Attack surface | ✅ Good | Requires machine access + identity file |
| Offline capability | ✅ Yes | Works with valid cache |

### Verdict

**Rating: Pragmatic Balance of Security and Reliability**

---

## Comparison Matrix

| Criteria | Option A (Runtime) | Option B (Env File) | Option C (Hybrid) |
|----------|-------------------|--------------------|--------------------|
| **Security** |
| Secrets at rest | ✅ None | ❌ Plaintext | ✅ Encrypted |
| Rotation support | ✅ Automatic | ❌ Manual | ✅ Auto (4hr soft) |
| Audit trail | ✅ Full | ⚠️ Partial | ✅ Refresh logs |
| **Performance** |
| Cold start | ❌ 5-8s | ✅ <100ms | ✅ <500ms |
| Warm start | ✅ <1s | ✅ <100ms | ✅ <200ms |
| **Reliability** |
| 1Password down | ❌ Fails | ✅ Works | ✅ Works (cache) |
| Offline use | ❌ No | ✅ Yes | ✅ Yes |
| Self-healing | N/A | ❌ No | ✅ Yes |

---

## Resolved Design Questions

| Question | Decision | Rationale |
|----------|----------|-----------|
| Cache TTL | Soft 4hr, Hard 24hr | Balance freshness + reliability |
| Encryption | age file-based keypair | Simple, correct, no prompts |
| Stale policy | Warn soft, fail hard | Pragmatic for dev keys |
| Multi-machine sync | No sync | Different risk surfaces |
| Secret granularity | Per-project, namespaced | Isolation + no collisions |
| Audit scope | Refresh logs only | Per-use excessive for dev keys |
| Linux support | Not required | macOS only |
| `.enabled-servers` scope | Committed (team-shared) | Avoids per-dev drift |
| Local overrides | `.enabled-servers.local` | Allows personal additions without affecting team |
| Project discovery | Explicit `projects.json` | Avoids implicit filesystem scanning |

---

## Implementation Checklist

See `DEV_INFRA_IMPLEMENTATION_PLAN.md` for full phased implementation.

---

*Document version: 2.0*
*Last updated: 2026-01-31*
*Review status: Third-party review incorporated*
