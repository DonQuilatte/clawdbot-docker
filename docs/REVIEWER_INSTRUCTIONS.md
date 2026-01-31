# Reviewer Instructions: Dev-Infra Implementation Plan

**Date:** 2026-01-31
**Repo:** dev-infra
**Branch:** awesome-sinoussi

---

## Overview

We are implementing a shared development infrastructure platform that enables:
1. MCP (Model Context Protocol) server registry with secure secrets management
2. Per-project enable/disable of MCP servers
3. Headless operation on worker machines (no GUI prompts)
4. Integration with 1Password for secrets

This RFC has been revised based on your initial feedback. Please review the updated documents.

---

## Files for Review

### Primary Documents

| File | Description | Key Sections |
|------|-------------|--------------|
| `docs/DEV_INFRA_IMPLEMENTATION_PLAN.md` | **Main implementation plan** (NEW) | Architecture, CLI commands, phased implementation |
| `docs/MCP_SECRETS_ARCHITECTURE.md` | RFC v2.0 - Secrets management | Option C implementation (corrected) |

### Supporting Context

| File | Description |
|------|-------------|
| `docs/DEV_INFRA_VISION_EVAL.md` | Vision alignment and gap analysis |
| `docs/ARCHITECTURE_EVAL.md` | 1Password headless operations evaluation |

---

## What Changed (v2.0)

Based on your review, we made the following corrections:

| Your Finding | Our Fix |
|--------------|---------|
| `age` passphrase usage incorrect | Switched to file-based keypair (`age-keygen` + `-r`/`-i` flags) |
| LaunchAgent hardcoded token | Wrapper script reads from 600-perm file |
| Caches all servers, not just enabled | Per-project cache, reads `.enabled-servers` file |
| Namespace collisions possible | Keys namespaced as `server.ENV_VAR` |
| Date parsing mismatch | Using epoch seconds throughout |
| Audit claim overstated | Clarified: refresh logs only (acceptable for dev keys) |
| Project name collisions | Cache key is hash of absolute project path |
| CWD-dependent paths | Commands accept `--path` and resolve files from project root |
| Refresh-all discovery | Explicit `projects.json` registry |
| Team enablement vs local | `.enabled-servers` committed; `.enabled-servers.local` optional |

---

## Specific Review Requests

### 1. Age Keypair Implementation

**Location:** `MCP_SECRETS_ARCHITECTURE.md` → “Age Keypair Setup”

Questions:
- Is the keypair generation correct?
- Is the encrypt/decrypt usage correct?
- Any concerns with storing identity.txt at 600 perms?

### 2. Per-Project Cache Isolation + Hashing

**Location:** `DEV_INFRA_IMPLEMENTATION_PLAN.md` → “Cache Structure” + “Cache Builder”

Questions:
- Is the `.enabled-servers` + `.enabled-servers.local` approach sound?
- Any concerns with hashing absolute paths for cache keys?
- Any issues with the namespace scheme (`server.ENV_VAR`)?

### 3. TTL Strategy

**Location:** `MCP_SECRETS_ARCHITECTURE.md` → “MCP Launcher (Corrected)”

Implemented: Soft TTL 4hr (warn on stale), Hard TTL 24hr (fail)

Questions:
- Is the soft/hard TTL distinction correctly implemented?
- Any edge cases in the refresh_if_needed logic?

### 4. Project Registry + `--path` Semantics

**Location:** `DEV_INFRA_IMPLEMENTATION_PLAN.md` → “Project Registry” + CLI Commands

Questions:
- Is `projects.json` the right source of truth for refresh-all?
- Are there better ergonomics for `--path` across commands?

### 5. LaunchAgent Token Injection

**Location:** `DEV_INFRA_IMPLEMENTATION_PLAN.md` → “LaunchAgent with Wrapper”

Questions:
- Does the wrapper pattern satisfy "no hardcoded secrets in plists"?
- Any issues with the token file path convention?

---

## How to Access

### Option A: Pull the Branch

```bash
git fetch origin awesome-sinoussi
git checkout awesome-sinoussi
```

### Option B: View Files Directly

Files are at:
```
/Users/jederlichman/.claude-worktrees/dev-infra/awesome-sinoussi/docs/
├── DEV_INFRA_IMPLEMENTATION_PLAN.md  (NEW - main plan)
├── MCP_SECRETS_ARCHITECTURE.md       (UPDATED - v2.0)
├── DEV_INFRA_VISION_EVAL.md          (context)
├── ARCHITECTURE_EVAL.md              (context)
└── REVIEWER_INSTRUCTIONS.md          (this file)
```

### Option C: GitHub (after push)

Once pushed, files will be at:
```
https://github.com/<org>/dev-infra/blob/awesome-sinoussi/docs/DEV_INFRA_IMPLEMENTATION_PLAN.md
https://github.com/<org>/dev-infra/blob/awesome-sinoussi/docs/MCP_SECRETS_ARCHITECTURE.md
```

---

## Response Format

Please provide feedback in the same format as before:

```
• Findings
  - [Severity]: [file:lines] [Description of issue]

• Recommendations
  - [Suggestion]

• Open questions
  - [Any clarifying questions]
```

---

## Timeline

Targeting implementation start after review approval.

---

*Thank you for your thorough review on v1.0. It significantly improved the design.*
