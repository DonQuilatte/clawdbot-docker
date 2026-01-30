# MCP Setup Issues & Blockers

> Lessons learned from setting up MCP servers for dev-infra project
> Date: 2025-01-25

---

## Summary

During setup of Docker MCP Toolkit with 1Password integration, we encountered multiple issues that should inform future setup scripts and documentation.

---

## Issues Encountered

### 1. DockerHub Secret Naming Convention

**Problem:** Docker MCP Toolkit expects specific secret names that aren't obvious.

| What We Tried | What Actually Works |
|---------------|---------------------|
| `HUB_PAT_TOKEN` | ❌ Not recognized |
| `DOCKERHUB_PAT` | ❌ Not recognized |
| `dockerhub.pat_token` | ✅ Correct format |

**Root Cause:** The catalog defines secrets with a namespaced format (`<server>.<secret_name>`) that maps to environment variables internally.

**Fix:** Check catalog definition first:
```bash
curl -s "https://desktop.docker.com/mcp/catalog/v2/catalog.yaml" | grep -A10 "dockerhub:" | grep -A5 "secrets:"
```

**Recommendation for scripts:**
```bash
# Always use the catalog-defined secret name
docker mcp secret set "dockerhub.pat_token=$PAT"
# NOT: docker mcp secret set "HUB_PAT_TOKEN=$PAT"
```

---

### 2. 1Password Shell Integration Conflicts

**Problem:** The `_op_inject_secrets` function in zsh profile causes errors with Docker MCP commands.

**Error Message:**
```
docker:1: command not found: _op_inject_secrets
```

**Root Cause:** The docker command is wrapped by 1Password's shell integration, which fails in certain contexts.

**Workaround:**
```bash
# Use /bin/bash -c to bypass the zsh integration
/bin/bash -c 'docker mcp server ls'

# Or call docker binary directly
/usr/local/bin/docker login ...
```

**Recommendation:** Setup scripts should detect and handle this:
```bash
if type _op_inject_secrets &>/dev/null; then
    DOCKER_CMD="/usr/local/bin/docker"
else
    DOCKER_CMD="docker"
fi
```

---

### 3. MCP Server Requires Restart After Secret Changes

**Problem:** After setting secrets, the MCP tools still fail with token errors until Claude Code is restarted.

**Symptom:**
```
Error getting personal namespace: InvalidTokenError: Invalid token specified
```

**Root Cause:** The MCP gateway caches credentials and doesn't hot-reload secrets.

**Required Steps:**
1. Set the secret: `docker mcp secret set "dockerhub.pat_token=..."`
2. Reconnect client: `docker mcp client connect claude-code`
3. **Restart Claude Code** (mandatory)

**Recommendation:** Add explicit restart step to all setup scripts:
```bash
echo "⚠️  IMPORTANT: Restart Claude Code to apply changes"
echo "   Run: Cmd+Q then reopen, or /exit in Claude Code"
```

---

### 4. Expired/Invalid Credentials in 1Password

**Problem:** Stored credentials were outdated and no longer valid.

**Symptoms:**
- `unauthorized: incorrect username or password`
- Multiple credential fields with different values (old PAT, password, new PAT)

**1Password Item Structure Found:**
```
Fields:
  username:      juniperdocent
  password:      [old password - invalid]
  text:          dckr_pat_xxx (old PAT - invalid)
  notesPlain:    Contains old setup instructions with outdated tokens
```

**Recommendation:** Setup scripts should validate credentials before storing:
```bash
# Test before saving
echo "$NEW_PAT" | docker login -u "$USERNAME" --password-stdin
if [ $? -eq 0 ]; then
    op item edit "$ITEM_ID" "text=$NEW_PAT"
    docker mcp secret set "dockerhub.pat_token=$NEW_PAT"
else
    echo "❌ Token validation failed - not saving"
    exit 1
fi
```

---

### 5. Interactive Commands Don't Work in Claude Code

**Problem:** Commands requiring TTY input fail.

**Error:**
```
Error: Cannot perform an interactive login from a non TTY device
```

**Affected Commands:**
- `docker login -u username` (without --password-stdin)
- Any command expecting keyboard input

**Workaround:** Always use non-interactive alternatives:
```bash
# Instead of:
docker login -u juniperdocent

# Use:
echo "$PAT" | docker login -u juniperdocent --password-stdin
```

---

### 6. Exa MCP Not in Docker MCP Catalog

**Problem:** Exa isn't available via `docker mcp add exa`.

**Workaround:** Manual configuration in `.mcp.json`:
```json
{
  "exa": {
    "type": "http",
    "url": "https://mcp.exa.ai/mcp?exaApiKey=${EXA_API_KEY}"
  }
}
```

**Alternative:** Use npx-based local server:
```json
{
  "exa": {
    "command": "npx",
    "args": ["-y", "exa-mcp-server"],
    "env": { "EXA_API_KEY": "..." }
  }
}
```

---

### 7. Config Write Command Format Confusion

**Problem:** `docker mcp config write` expects JSON as argument, not stdin.

**What Doesn't Work:**
```bash
echo '{"dockerhub": {...}}' | docker mcp config write
```

**What Works:**
```bash
docker mcp config write '{"dockerhub": {"username": "juniperdocent"}}'
```

---

### 8. Context7 Library ID Discovery

**Problem:** Finding the correct Context7 library ID requires trial and error.

**Solution:** Use `resolve-library-id` tool first:
```bash
# Via MCP tool
mcp__MCP_DOCKER__resolve-library-id(libraryName="docker compose")

# Returns multiple options with trust scores
```

**Recommendation:** Document known-good library IDs:
| Technology | Library ID | Trust Score |
|------------|------------|-------------|
| Docker | `/docker/docs` | 9.9 |
| Docker Compose | `/docker/compose` | 9.9 |
| Clawdbot | `/clawdbot/clawdbot` | 6.9 |
| Exa | `/websites/exa_ai` | 9.7 |

---

## Recommended Setup Script Improvements

### Pre-flight Checks
```bash
#!/bin/bash
set -e

# 1. Check dependencies
command -v op >/dev/null || { echo "❌ 1Password CLI required"; exit 1; }
command -v docker >/dev/null || { echo "❌ Docker required"; exit 1; }

# 2. Check 1Password signin
op account get >/dev/null 2>&1 || { echo "❌ Run: eval \$(op signin)"; exit 1; }

# 3. Check Docker Desktop running
docker info >/dev/null 2>&1 || { echo "❌ Start Docker Desktop"; exit 1; }

# 4. Detect 1Password shell integration issues
DOCKER_CMD="docker"
if [[ "$SHELL" == *"zsh"* ]] && type _op_inject_secrets &>/dev/null; then
    DOCKER_CMD="/usr/local/bin/docker"
fi
```

### Credential Validation
```bash
validate_dockerhub() {
    local username="$1"
    local pat="$2"

    if echo "$pat" | $DOCKER_CMD login -u "$username" --password-stdin 2>/dev/null; then
        echo "✅ DockerHub credentials valid"
        return 0
    else
        echo "❌ DockerHub credentials invalid"
        return 1
    fi
}

validate_exa() {
    local api_key="$1"

    response=$(curl -s -X POST "https://api.exa.ai/search" \
        -H "x-api-key: $api_key" \
        -H "Content-Type: application/json" \
        -d '{"query": "test", "numResults": 1}')

    if echo "$response" | grep -q "results"; then
        echo "✅ Exa API key valid"
        return 0
    else
        echo "❌ Exa API key invalid"
        return 1
    fi
}
```

### Secret Setup with Validation
```bash
setup_dockerhub() {
    # Get from 1Password
    local username=$(op item get "Docker" --fields label=username)
    local pat=$(op item get "Docker" --fields label=text)

    # Validate first
    if ! validate_dockerhub "$username" "$pat"; then
        echo "Generate new PAT at: https://app.docker.com/settings/personal-access-tokens"
        read -p "Paste new PAT: " new_pat

        # Test new PAT
        if validate_dockerhub "$username" "$new_pat"; then
            # Update 1Password
            op item edit "Docker" "text=$new_pat"
            pat="$new_pat"
        else
            echo "❌ New PAT also invalid"
            exit 1
        fi
    fi

    # Set in Docker MCP (use correct secret name!)
    /bin/bash -c "docker mcp secret set 'dockerhub.pat_token=$pat'"
    /bin/bash -c "docker mcp config write '{\"dockerhub\": {\"username\": \"$username\"}}'"

    echo "✅ DockerHub configured"
    echo "⚠️  Restart Claude Code to apply changes"
}
```

---

## Quick Reference: Correct Commands

### Docker MCP Secrets
```bash
# List secrets
docker mcp secret ls

# Set secret (use namespaced format!)
docker mcp secret set "dockerhub.pat_token=dckr_pat_xxx"
docker mcp secret set "github.personal_access_token=ghp_xxx"

# Set config
docker mcp config write '{"dockerhub": {"username": "xxx"}}'
```

### 1Password Integration
```bash
# Get field value
op item get "ItemName" --fields label=fieldname

# Update field
op item edit "ItemID" "fieldname=newvalue"

# List items
op item list | grep -i docker
```

### Validation Commands
```bash
# Test DockerHub
echo "$PAT" | docker login -u username --password-stdin

# Test Exa
curl -X POST "https://api.exa.ai/search" \
  -H "x-api-key: $EXA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "test", "numResults": 1}'

# Test GitHub (via MCP)
docker mcp tools list --server github-official
```

---

## Files Created/Modified During Setup

| File | Purpose |
|------|---------|
| `.mcp.json` | Project MCP server configuration |
| `.claude/skills/exa-search.md` | Exa skill documentation |
| `~/.docker/mcp/config.yaml` | Docker MCP config (username) |
| `~/.zshrc` | Added `EXA_API_KEY` export |

---

## Final Working Configuration

### MCP Servers Status
```
context7          ✓ ready
docker            ✓ ready
dockerhub         ✓ ready (after restart)
exa               ✓ ready
fetch             ✓ ready
git               ✓ ready
github-official   ✓ ready
puppeteer         ✓ ready
```

### 1Password Items Used
- `exa.ai` → API Key field
- `Docker` → text field (PAT), username field

---

## TODO for Future Scripts

- [ ] Add pre-flight validation for all credentials
- [ ] Auto-detect and handle 1Password shell integration
- [ ] Include restart reminder with countdown
- [ ] Add rollback capability if setup fails
- [ ] Create health check command for all MCP servers
- [ ] Add `--dry-run` flag for testing without changes
