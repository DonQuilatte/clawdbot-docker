# Path 3: Antigravity IDE Zero-Command Integration

## Goal

**Open project in Antigravity → Claude ready with full MCP stack. No commands.**

---

## Architecture

### Components

1. **Project Config** (`.antigravity/config.json`) - Per-project settings
2. **Auto-Setup Script** (`scripts/agy-auto-setup`) - Runs on project open
3. **MCP Server Manifest** (`.mcp-servers.json`) - Server definitions
4. **Antigravity Hooks** - IDE integration points

### Data Flow

```
User Opens Project in Antigravity
           ↓
Antigravity detects .antigravity/config.json
           ↓
Runs onOpen.setupScript (agy-auto-setup)
           ↓
    • project-setup.sh executes
    • direnv allowed automatically
    • MCP servers registered
    • Environment variables loaded
           ↓
Notification: "Project Ready"
           ↓
User: "analyze the auth flow"
           ↓
Claude uses MCP tools (Desktop Commander, GitKraken, etc.)
```

---

## Implementation Plan

### Phase 3A: Project Configuration Template (Week 1)

**Create:** `.antigravity/config.json` template

```json
{
  "version": "1.0",
  "onOpen": {
    "setupScript": "scripts/agy-auto-setup",
    "allowDirenv": true,
    "notification": {
      "enabled": true,
      "title": "Project Setup",
      "message": "${projectName} ready"
    }
  },
  "mcp": {
    "autoLoad": true,
    "manifestPath": ".mcp-servers.json",
    "servers": {
      "desktop-commander": {
        "command": "bash",
        "args": ["${workspaceFolder}/scripts/mcp-desktop-commander"]
      },
      "gitkraken": {
        "command": "bash",
        "args": ["${workspaceFolder}/scripts/mcp-gitkraken"]
      },
      "filesystem": {
        "command": "bash",
        "args": ["${workspaceFolder}/scripts/mcp-filesystem"]
      }
    }
  },
  "environment": {
    "inheritDirenv": true,
    "validateVars": ["GITHUB_TOKEN", "OPENAI_API_KEY"]
  },
  "claude": {
    "autoStart": false,
    "contextPath": "${workspaceFolder}",
    "systemPrompt": "You are working in the ${projectName} project."
  }
}
```

**Deliverables:**
- Template file
- JSON schema for validation
- Documentation

---

### Phase 3B: Auto-Setup Script Enhancement (Week 1)

**Enhance:** `scripts/agy-auto-setup`

Current capabilities:
- ✅ Runs project-setup.sh
- ✅ Allows direnv
- ✅ Sends notification

Add:
- Environment validation
- MCP server verification
- Health checks
- Error recovery

```bash
#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="${1:-$PWD}"
PROJECT_NAME=$(basename "$PROJECT_PATH")

cd "$PROJECT_PATH"

# Silent execution with detailed logging
exec > /tmp/agy-auto-setup-${PROJECT_NAME}.log 2>&1

echo "[$(date)] Auto-setup for ${PROJECT_NAME}"

# Step 1: Validate environment
validate_environment() {
    local missing_vars=()
    
    for var in GITHUB_TOKEN OPENAI_API_KEY; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        notify_error "Missing environment variables: ${missing_vars[*]}"
        return 1
    fi
}

# Step 2: Run project setup
if [ -f "scripts/project-setup.sh" ]; then
    if ! timeout 60s bash scripts/project-setup.sh "$PROJECT_NAME"; then
        notify_error "Project setup failed or timed out"
        return 1
    fi
fi

# Step 3: Configure direnv
if [ -f ".envrc" ]; then
    direnv allow || notify_warning "direnv configuration incomplete"
fi

# Step 4: Verify MCP servers
if [ -f ".mcp-servers.json" ]; then
    verify_mcp_servers || notify_warning "Some MCP servers unavailable"
fi

# Step 5: Success notification
notify_success "${PROJECT_NAME} ready"
```

**Deliverables:**
- Enhanced auto-setup script
- Health check utilities
- Error recovery logic

---

### Phase 3C: Antigravity IDE Integration (Week 2-3)

**Research Required:**

1. **Does Antigravity support workspace hooks?**
   - Check documentation
   - Test with simple example
   - Determine API surface

2. **Configuration locations:**
   - Per-project: `.antigravity/config.json`?
   - Global: `~/.antigravity/settings.json`?
   - Workspace: `.antigravity/workspace.json`?

3. **Hook types:**
   - `onOpen` - Project opened
   - `onClose` - Project closed
   - `onFileChange` - File modified
   - `onActivate` - Antigravity focused

4. **MCP Integration:**
   - How does Antigravity load MCP servers?
   - Global config vs. workspace config?
   - Dynamic registration?

**Action Items:**
- [ ] Read Antigravity documentation
- [ ] Test workspace hooks
- [ ] Prototype simple integration
- [ ] Identify limitations

---

### Phase 3D: MCP Server Registration (Week 3)

**Goal:** Automatic MCP server loading based on project config

**Two approaches:**

#### Approach 1: Static Config (Simpler)

Antigravity reads `.mcp-servers.json` on project open:

```json
{
  "mcpServers": {
    "desktop-commander": {
      "command": "bash",
      "args": [
        "/Users/jederlichman/Development/Projects/clawdbot/scripts/mcp-desktop-commander"
      ]
    }
  }
}
```

**Pros:** Simple, declarative
**Cons:** Absolute paths, not portable

#### Approach 2: Dynamic Registration (Better)

Auto-setup script registers servers dynamically:

```bash
#!/usr/bin/env bash
# In agy-auto-setup

register_mcp_servers() {
    local project_root="$PWD"
    
    # Generate MCP config with resolved paths
    cat > /tmp/agy-mcp-${PROJECT_NAME}.json << EOF
{
  "mcpServers": {
    "desktop-commander": {
      "command": "bash",
      "args": ["${project_root}/scripts/mcp-desktop-commander"]
    },
    "gitkraken": {
      "command": "bash",
      "args": ["${project_root}/scripts/mcp-gitkraken"]
    }
  }
}
EOF
    
    # Tell Antigravity to load this config
    if command -v antigravity-ctl &>/dev/null; then
        antigravity-ctl load-mcp /tmp/agy-mcp-${PROJECT_NAME}.json
    fi
}
```

**Pros:** Dynamic, portable, context-aware
**Cons:** Requires Antigravity CLI support

---

### Phase 3E: Project Template Generator (Week 4)

**Create:** `agy-init` command to set up new projects

```bash
#!/usr/bin/env bash
# agy-init - Initialize a project with full AGY integration

PROJECT_NAME="$1"
PROJECT_PATH="${2:-$HOME/Development/Projects/$PROJECT_NAME}"

mkdir -p "$PROJECT_PATH"
cd "$PROJECT_PATH"

# Create directory structure
mkdir -p scripts .antigravity

# Copy templates
cp ~/Development/Projects/clawdbot/templates/.antigravity/config.json .antigravity/
cp ~/Development/Projects/clawdbot/templates/scripts/project-setup.sh scripts/
cp ~/Development/Projects/clawdbot/templates/scripts/mcp-* scripts/
cp ~/Development/Projects/clawdbot/templates/.envrc.template .envrc

# Customize for project
sed -i '' "s/__PROJECT_NAME__/$PROJECT_NAME/g" .antigravity/config.json
sed -i '' "s/__PROJECT_NAME__/$PROJECT_NAME/g" scripts/project-setup.sh

# Initialize git
git init
git add .
git commit -m "feat: initialize project with AGY integration"

# Allow direnv
direnv allow

echo "✅ Project initialized: $PROJECT_PATH"
echo ""
echo "Next steps:"
echo "  cd $PROJECT_PATH"
echo "  agy                    # Start working"
```

**Deliverables:**
- Project initialization script
- Template files
- Documentation

---

### Phase 3F: Testing & Validation (Week 4-5)

**Test scenarios:**

1. **Fresh project setup**
   - Clone repo → open in Antigravity → verify auto-setup

2. **Existing project migration**
   - Add config → reopen → verify migration

3. **MCP server loading**
   - Verify all servers available
   - Test tool calls

4. **Environment inheritance**
   - Verify direnv variables loaded
   - Test 1Password integration

5. **Error scenarios**
   - Missing dependencies
   - Invalid config
   - Setup script failure

**Deliverables:**
- Test suite
- CI/CD integration
- Smoke tests

---

## Technical Requirements

### Must Have

- ✅ Project detection (when Antigravity opens folder)
- ✅ Auto-setup execution (project-setup.sh, direnv)
- ✅ MCP server registration (automatic loading)
- ✅ Environment validation (check required vars)
- ✅ Success notification (macOS notification)

### Should Have

- Error recovery (retry failed setups)
- Health checks (verify MCP servers responding)
- Status indicators (in Antigravity UI)
- Quick commands (restart setup, reload servers)

### Nice to Have

- Project dashboard (all projects with status)
- Remote delegation (auto-detect long tasks, offer TW Mac)
- Completion tracking (detect when Claude finishes)
- Result artifacts (auto-save outputs)

---

## Risks & Mitigation

### Risk 1: Antigravity Doesn't Support Hooks

**Mitigation:**
- Use direnv integration as fallback
- Shell aliases for quick setup
- Manual workflow with good UX

### Risk 2: MCP Server Loading Issues

**Mitigation:**
- Comprehensive validation
- Clear error messages
- Fallback to manual registration

### Risk 3: Environment Conflicts

**Mitigation:**
- Isolated per-project configs
- Clear precedence rules
- Validation before execution

### Risk 4: Performance Issues

**Mitigation:**
- Async setup execution
- Lazy MCP server loading
- Caching of validation results

---

## Success Criteria

### Phase 3 Complete When:

- [ ] User opens project in Antigravity
- [ ] Auto-setup runs without user intervention
- [ ] MCP servers load automatically
- [ ] Environment variables available
- [ ] User can immediately start conversing with Claude
- [ ] All tools work (file ops, git ops, etc.)
- [ ] Error states handled gracefully
- [ ] Documentation complete
- [ ] Team can replicate setup

### Metrics:

- Time from open → ready: < 5 seconds
- Setup success rate: > 95%
- MCP server availability: 100%
- User satisfaction: High (survey)

---

## Timeline

**Week 1:** Configuration templates + auto-setup enhancement
**Week 2:** Antigravity integration research + prototyping
**Week 3:** MCP registration + testing
**Week 4:** Project templates + validation
**Week 5:** Documentation + team rollout

**Total:** 5 weeks to production-ready zero-command workflow

---

## Next Actions

### Immediate (This Week)

1. **Research Antigravity capabilities:**
   - Read docs on workspace hooks
   - Test simple onOpen example
   - Document API surface

2. **Create config templates:**
   - `.antigravity/config.json`
   - `.mcp-servers.json`
   - Validation schema

3. **Enhance auto-setup:**
   - Add environment validation
   - Add MCP verification
   - Add health checks

### Short-term (Next 2 Weeks)

1. **Prototype integration:**
   - Test with clawdbot project
   - Iterate based on findings
   - Document lessons learned

2. **Build MCP registration:**
   - Dynamic server loading
   - Error handling
   - Status reporting

### Long-term (Month 2)

1. **Team rollout:**
   - Migration guide
   - Training sessions
   - Support process

2. **Continuous improvement:**
   - Gather feedback
   - Fix issues
   - Add requested features

---

## Dependencies

**Antigravity:**
- Workspace hook support (TBD)
- MCP configuration API (TBD)
- CLI tools (if available)

**System:**
- direnv (✅ installed)
- 1Password CLI (✅ installed)
- jq (✅ installed)

**Project:**
- project-setup.sh (✅ standard)
- MCP server scripts (✅ available)
- .envrc files (✅ standard)

---

## Questions to Answer

1. Does Antigravity support `workspace.onOpen` hooks?
2. Where does Antigravity look for MCP configs?
3. Can MCP servers be registered dynamically?
4. How does Antigravity handle environment variables?
5. Is there an Antigravity CLI for automation?
6. Can we show custom notifications in Antigravity UI?
7. How do we handle multi-project workspaces?

**Action:** Research Antigravity documentation and experiment.
