# Dev-Infra Implementation Plan

**Date:** 2026-01-31
**Version:** 2.0 (Revised after third-party review)
**Status:** Ready for Implementation

---

## Executive Summary

This plan aligns dev-infra with its intended purpose: a shared platform layer that other projects inherit from, equipped with tools (MCP servers) that can be enabled/disabled per-project context.

**Key deliverables:**
1. MCP registry with secure secrets management
2. Project scaffolding system (`dev-infra scaffold`)
3. Per-project MCP enable/disable commands
4. 1Password integration for headless operations

---

## Vision Alignment

### Intended Capability
> Dev-infra is scaffolding and tooling supporting other projects. It should be equipped with tools (e.g., MCP) that can be turned on/off or optimized for project contexts. It's where we add new capabilities that other projects can leverage, avoiding multiple devops/tooling infrastructures.

### Current Gaps (from DEV_INFRA_VISION_EVAL.md)

| Gap | Status | This Plan |
|-----|--------|-----------|
| No project inheritance mechanism | ❌ Missing | `dev-infra scaffold` command |
| No MCP "menu" to enable/disable | ❌ Missing | `dev-infra mcp enable/disable` |
| No versioning or sync | ❌ Missing | Symlink-based with sync command |
| Minimal project templates | ⚠️ Partial | Scaffold templates |
| 1Password broken on Agent | ❌ Missing | Token deployment + wrapper |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         DEV-INFRA                               │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │ MCP Registry│  │  Scaffold   │  │   Secrets Management    │ │
│  │             │  │  Templates  │  │                         │ │
│  │ - servers   │  │             │  │  ┌─────────────────┐    │ │
│  │ - configs   │  │ - .envrc    │  │  │ age keypair     │    │ │
│  │ - secrets   │  │ - .mcp.json │  │  │ (per-machine)   │    │ │
│  │   (op://)   │  │ - CLAUDE.md │  │  └─────────────────┘    │ │
│  └─────────────┘  └─────────────┘  │           │             │ │
│         │                │         │           ▼             │ │
│         │                │         │  ┌─────────────────┐    │ │
│         │                │         │  │ Encrypted cache │    │ │
│         │                │         │  │ (per-project)   │    │ │
│         │                │         │  └─────────────────┘    │ │
│         │                │         └─────────────────────────┘ │
└─────────┼────────────────┼─────────────────────────────────────┘
          │                │
          ▼                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      OTHER PROJECTS                             │
│                                                                 │
│  project-a/              project-b/              project-c/    │
│  ├── .envrc (sources     ├── .envrc              ├── .envrc    │
│  │   dev-infra)          ├── .mcp.json           ├── .mcp.json │
│  ├── .mcp.json           ├── .enabled-servers    ├── .enabled  │
│  ├── .enabled-servers    │   └── stitch          │   └── tiger │
│  │   ├── filesystem      │   └── filesystem      │   └── fs    │
│  │   └── context7        └── CLAUDE.md           └── CLAUDE.md │
│  └── CLAUDE.md                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Component Specifications

### 1. MCP Registry

**Location:** `~/.config/dev-infra/mcp-registry.json`

**Schema:**
```json
{
  "version": "1.0",
  "servers": {
    "stitch": {
      "name": "Google Stitch",
      "description": "AI UI design tool powered by Gemini",
      "command": ["npx", "@anthropic/stitch-mcp"],
      "secrets": {
        "stitch.STITCH_API_KEY": "op://Developer/Stitch/api-key"
      },
      "tags": ["frontend", "design", "ui"]
    },
    "filesystem": {
      "name": "Filesystem",
      "description": "Local filesystem access",
      "command": ["npx", "@anthropic/mcp-filesystem"],
      "secrets": {},
      "tags": ["core"]
    },
    "tiger": {
      "name": "Tiger (TimescaleDB)",
      "description": "PostgreSQL/TimescaleDB cloud",
      "command": ["npx", "@anthropic/mcp-tiger"],
      "secrets": {
        "tiger.TIGER_API_KEY": "op://Developer/Tiger/api-key"
      },
      "tags": ["database", "backend"]
    }
  }
}
```

**Key design decisions:**
- Secrets namespaced as `server.ENV_VAR` to prevent collisions
- `op://` references, not raw values
- Tags for filtering (`dev-infra mcp list --tag frontend`)

---

### 2. Project Registry (refresh-all)

**Location:** `~/.config/dev-infra/projects.json`

**Schema:**
```json
{
  "projects": [
    { "name": "project-a", "path": "/Users/jederlichman/Development/Projects/project-a" },
    { "name": "project-b", "path": "/Users/jederlichman/Development/Projects/project-b" }
  ]
}
```

**Purpose:** Source of truth for `dev-infra secrets refresh-all` (no filesystem scanning).

---

### 3. Secrets Management (Revised)

**Based on third-party review feedback. Fixes:**
- Correct `age` keypair usage (not passphrase)
- Cache only enabled servers per-project
- Namespaced secrets
- Epoch timestamps for TTL
- Wrapper script for LaunchAgent token injection

#### 3.1 Age Keypair Setup

**Location:** `~/.config/dev-infra/age/`

```bash
# One-time setup per machine
mkdir -p ~/.config/dev-infra/age
chmod 700 ~/.config/dev-infra/age

age-keygen -o ~/.config/dev-infra/age/identity.txt 2>&1 | \
  grep "public key:" | awk '{print $3}' > ~/.config/dev-infra/age/recipient.txt

chmod 600 ~/.config/dev-infra/age/identity.txt
chmod 644 ~/.config/dev-infra/age/recipient.txt
```

#### 3.2 Cache Structure (Per-Project)

```
~/.config/dev-infra/
├── age/
│   ├── identity.txt      # Private key (600)
│   └── recipient.txt     # Public key (644)
├── mcp-registry.json     # Server definitions
└── projects.json         # Registry of project paths (refresh-all)

~/.cache/dev-infra/
├── projects/
│   ├── <project-hash>/
│   │   ├── secrets.enc   # Encrypted, only enabled servers
│   │   └── secrets.meta  # Timestamps (epoch)
│   └── <project-hash>/
│       ├── secrets.enc
│       └── secrets.meta
└── refresh.log           # Audit log (refreshes only)
```

**Cache key:** `project-hash` = sha256 of the absolute project path (prevents name collisions).

#### 3.3 Cache Builder (Corrected)

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

# Load 1Password token from secure file (not hardcoded)
if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
    if [[ -f "$HOME/.config/op/service-account-token" ]]; then
        export OP_SERVICE_ACCOUNT_TOKEN=$(cat "$HOME/.config/op/service-account-token")
    else
        echo "ERROR: OP_SERVICE_ACCOUNT_TOKEN not set and token file missing" >&2
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

# Build namespaced secrets JSON (only enabled servers)
SECRETS_JSON="{}"
for server in "${ENABLED_SERVERS[@]}"; do
    if jq -e ".servers.\"$server\"" "$REGISTRY" >/dev/null 2>&1; then
        for row in $(jq -r ".servers.\"$server\".secrets // {} | to_entries[] | @base64" "$REGISTRY"); do
            key=$(echo "$row" | base64 -d | jq -r '.key')
            op_ref=$(echo "$row" | base64 -d | jq -r '.value')
            value=$(op read "$op_ref" 2>/dev/null || echo "")
            if [[ -n "$value" ]]; then
                # Key is already namespaced (server.ENV_VAR)
                SECRETS_JSON=$(echo "$SECRETS_JSON" | jq --arg k "$key" --arg v "$value" '. + {($k): $v}')
            fi
        done
    fi
done

# Encrypt with age keypair
echo "$SECRETS_JSON" | age -r "$(cat "$AGE_RECIPIENT")" -o "$CACHE_DIR/secrets.enc"
chmod 600 "$CACHE_DIR/secrets.enc"

# Write metadata with epoch timestamps
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

# Audit log
echo "$(date +%s) | $PROJECT_ID | $PROJECT_NAME | refreshed | servers: ${ENABLED_SERVERS[*]}" >> \
    "$HOME/.cache/dev-infra/refresh.log"
```

#### 3.4 MCP Launcher (Corrected)

```bash
#!/bin/bash
# mcp-launcher.sh

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

# Check cache freshness
NEEDS_REFRESH=true
if [[ -f "$CACHE_DIR/secrets.meta" ]]; then
    SOFT_EXPIRES=$(jq -r '.soft_expires_at' "$CACHE_DIR/secrets.meta")
    HARD_EXPIRES=$(jq -r '.hard_expires_at' "$CACHE_DIR/secrets.meta")

    if [[ $NOW -lt $SOFT_EXPIRES ]]; then
        NEEDS_REFRESH=false
    elif [[ $NOW -lt $HARD_EXPIRES ]]; then
        # Soft expired, try refresh but allow stale
        dev-infra secrets refresh --path "$PROJECT_PATH" 2>/dev/null || \
            echo "WARNING: Using stale cache (soft TTL exceeded) for $PROJECT_NAME" >&2
        NEEDS_REFRESH=false
    else
        # Hard expired, must refresh
        if ! dev-infra secrets refresh --path "$PROJECT_PATH"; then
            echo "ERROR: Cache hard-expired and refresh failed for $PROJECT_NAME" >&2
            exit 1
        fi
        NEEDS_REFRESH=false
    fi
fi

if [[ "$NEEDS_REFRESH" == "true" ]]; then
    dev-infra secrets refresh --path "$PROJECT_PATH"
fi

# Decrypt cache
SECRETS=$(age -d -i "$AGE_IDENTITY" "$CACHE_DIR/secrets.enc")

# Export secrets for this server (namespaced keys)
for row in $(jq -r ".servers.\"$SERVER\".secrets // {} | to_entries[] | @base64" "$REGISTRY"); do
    namespaced_key=$(echo "$row" | base64 -d | jq -r '.key')
    env_var=$(echo "$namespaced_key" | cut -d. -f2)  # Extract ENV_VAR from server.ENV_VAR
    value=$(echo "$SECRETS" | jq -r --arg k "$namespaced_key" '.[$k] // empty')
    if [[ -n "$value" ]]; then
        export "$env_var=$value"
    fi
done

# Launch server
readarray -t cmd < <(jq -r ".servers.\"$SERVER\".command[]" "$REGISTRY")
exec "${cmd[@]}"
```

#### 3.5 LaunchAgent with Wrapper (No Hardcoded Token)

**Wrapper script:** `scripts/secrets-refresh-wrapper.sh`
```bash
#!/bin/bash
# Load token from secure file, then run refresh

if [[ -f "$HOME/.config/op/service-account-token" ]]; then
    export OP_SERVICE_ACCOUNT_TOKEN=$(cat "$HOME/.config/op/service-account-token")
fi

exec "$HOME/Development/Projects/dev-infra/scripts/dev-infra" secrets refresh-all
```

`refresh-all` iterates `~/.config/dev-infra/projects.json`.

**LaunchAgent plist:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.dev-infra.secrets-refresh</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/jederlichman/Development/Projects/dev-infra/scripts/secrets-refresh-wrapper.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>14400</integer>
    <key>StandardOutPath</key>
    <string>/tmp/dev-infra-secrets-refresh.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/dev-infra-secrets-refresh.err</string>
</dict>
</plist>
```

---

### 4. Project Scaffolding

**Command:** `dev-infra scaffold <project-name> [--path <dir>]`

**Creates:**
```
<project>/
├── .envrc                    # Sources dev-infra helpers
├── .mcp.json                 # MCP config (generated)
├── .enabled-servers          # Committed list of required MCP servers
├── .enabled-servers.local    # Optional personal additions (gitignored)
├── .gitignore                # Includes .enabled-servers.local, .env*
└── CLAUDE.md                 # Project instructions with dev-infra reference
```

`dev-infra scaffold` creates `.enabled-servers`; `.enabled-servers.local` is optional for personal additions.
Scaffold should also register the project path in `~/.config/dev-infra/projects.json`.

**Template `.envrc`:**
```bash
# Auto-generated by dev-infra scaffold
# Sources dev-infra helpers and sets up MCP environment

source_url "https://raw.githubusercontent.com/direnv/direnv/master/stdlib.sh" "sha256-..."

# Dev-infra integration
export DEV_INFRA="$HOME/Development/Projects/dev-infra"
source "$DEV_INFRA/scripts/lib/helpers.sh"

# Project-specific MCP setup
dev_infra_load_mcp
```

---

### 5. CLI Commands

```bash
# Project scaffolding
dev-infra scaffold <name> [--path <dir>]           # Create new project with dev-infra integration
dev-infra scaffold <name> --minimal [--path <dir>] # Minimal setup (just .envrc)

# Project registry
dev-infra projects list                  # Show registered project paths
dev-infra projects add --path <dir>      # Register project for refresh-all
dev-infra projects remove --path <dir>   # Unregister project

# MCP management
dev-infra mcp list [--path <dir>]                # Show all available servers
dev-infra mcp list --enabled [--path <dir>]      # Show enabled for project
dev-infra mcp list --tag frontend [--path <dir>] # Filter by tag
dev-infra mcp enable <server> [--path <dir>]     # Writes .enabled-servers
dev-infra mcp enable <server> --local [--path <dir>]  # Writes .enabled-servers.local
dev-infra mcp disable <server> [--path <dir>]
dev-infra mcp disable <server> --local [--path <dir>]
dev-infra mcp status [--path <dir>]              # Show MCP health for project

# Secrets management
dev-infra secrets refresh [--path <dir>]   # Refresh cache for project
dev-infra secrets refresh-all              # Uses ~/.config/dev-infra/projects.json
dev-infra secrets status [--path <dir>]    # Show cache age, enabled servers
dev-infra secrets setup                    # One-time age keypair setup

# Sync/maintenance
dev-infra sync                      # Update project from dev-infra changes
dev-infra doctor                    # Check health of dev-infra installation
```

---

## Implementation Phases

### Phase 0: Prerequisites (Day 0) ✅ READY

| Task | Owner | Status |
|------|-------|--------|
| Deploy 1Password token to TW Mac | — | ⬜ Not started |
| Verify `op read` works headless on TW | — | ⬜ Blocked |

```bash
# Execute
scp ~/.config/op/claude-dev-token tw:~/.config/op/service-account-token
ssh tw "chmod 600 ~/.config/op/service-account-token"
ssh tw "export OP_SERVICE_ACCOUNT_TOKEN=\$(cat ~/.config/op/service-account-token) && op read 'op://Developer/OpenProject/credential'"
```

### Phase 1: Foundation (Day 1)

| Task | Deliverable |
|------|-------------|
| Create age keypair setup script | `scripts/dev-infra-secrets-setup.sh` |
| Create MCP registry schema | `~/.config/dev-infra/mcp-registry.json` |
| Create cache builder (corrected) | `scripts/secrets-refresh.sh` |
| Create MCP launcher (corrected) | `scripts/mcp-launcher.sh` |

### Phase 2: CLI (Day 2)

| Task | Deliverable |
|------|-------------|
| Implement `dev-infra` main CLI | `scripts/dev-infra` |
| Implement `projects list/add/remove` | Subcommands + `projects.json` management |
| Implement `mcp list/enable/disable` | Subcommands |
| Implement `secrets refresh/status` | Subcommands |
| Create wrapper for LaunchAgent | `scripts/secrets-refresh-wrapper.sh` |

### Phase 3: Scaffolding (Day 3)

| Task | Deliverable |
|------|-------------|
| Implement `scaffold` command | `scripts/scaffold.sh` |
| Create project templates | `templates/project/` |
| Create `.envrc` template | `templates/project/.envrc` |
| Create `CLAUDE.md` template | `templates/project/CLAUDE.md` |

### Phase 4: Integration (Day 4)

| Task | Deliverable |
|------|-------------|
| Deploy LaunchAgent to Brain | `~/Library/LaunchAgents/com.dev-infra.secrets-refresh.plist` |
| Deploy LaunchAgent to Agent Alpha | Same |
| Add Stitch to registry | Registry entry |
| Test end-to-end on sample project | Validation |

---

## Validation Checklist

### Security
- [ ] Age identity file has 600 permissions
- [ ] Service account token file has 600 permissions
- [ ] No secrets in git (check `.gitignore`)
- [ ] No hardcoded tokens in LaunchAgent plists
- [ ] Cache files are per-project isolated

### Functionality
- [ ] `dev-infra mcp enable stitch` adds server to project
- [ ] `dev-infra mcp disable stitch` removes server
- [ ] MCP server starts and can access its secrets
- [ ] Cache refresh works on schedule
- [ ] Stale cache with warning works (soft TTL exceeded)
- [ ] Hard TTL expired forces refresh or fails
- [ ] `projects.json` includes all projects targeted by refresh-all

### Headless (Agent Alpha)
- [ ] `op read` works without GUI prompts
- [ ] LaunchAgent refresh runs successfully
- [ ] MCP servers start in headless Claude sessions

---

## Open Questions Resolved

| Question | Decision | Rationale |
|----------|----------|-----------|
| Cache TTL | Soft 4h, Hard 24h | Balances freshness with reliability |
| Encryption | age keypair | Simple, correct, no prompts |
| Stale policy | Warn on soft, fail on hard | Pragmatic for dev keys |
| Multi-machine sync | No sync, each builds own | Different risk surfaces |
| Secret granularity | Per-project + namespaced | Isolation + no collisions |
| Audit scope | Refresh logs only | Per-use logging excessive for dev keys |
| Linux support | Not needed | macOS only for foreseeable future |
| `.enabled-servers` scope | Committed (team-shared) | Avoids per-dev drift |
| Local overrides | `.enabled-servers.local` | Allows personal additions without affecting team |
| Project discovery | Explicit `projects.json` | Avoids implicit filesystem scanning |

---

## Files for Review

After this plan is committed, the following files will be available:

| File | Purpose |
|------|---------|
| `docs/DEV_INFRA_IMPLEMENTATION_PLAN.md` | This document |
| `docs/MCP_SECRETS_ARCHITECTURE.md` | RFC v2 (to be updated) |
| `docs/DEV_INFRA_VISION_EVAL.md` | Vision gap analysis |
| `docs/ARCHITECTURE_EVAL.md` | 1Password headless eval |

---

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-31 | Initial RFC |
| 2.0 | 2026-01-31 | Incorporated third-party review feedback |

---

*Document version: 2.0*
*Last updated: 2026-01-31*
