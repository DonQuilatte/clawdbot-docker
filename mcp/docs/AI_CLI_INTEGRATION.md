# AI CLI Integration Guide

## **Integrating AI CLIs with MCP Environment**

This guide covers configuring Claude Code, Codex, Gemini, and other AI CLIs to work seamlessly with your MCP environment management solution.

---

## **Overview**

**Goal:** AI CLIs should:
- ✅ Load project-specific MCP servers automatically
- ✅ Inherit credentials from direnv environment
- ✅ Respect workspace isolation
- ✅ Use same configuration as IDEs (Cursor, VS Code)

**Strategy:**
1. **Environment inheritance** - CLIs inherit from direnv (automatic)
2. **MCP configuration** - Create CLI-specific configs pointing to wrappers
3. **Launch wrappers** - Ensure CLIs start from project directory

---

## **CLAUDE CODE Configuration**

### **Architecture**

Claude Code MCP config location:
```bash
# Global config (not recommended for multi-project)
~/.config/claude/mcp.json

# Project-scoped config (RECOMMENDED)
.claude/mcp.json  # Per-project configuration
```

### **Setup: Per-Project Configuration**

Add this to your `project-setup.sh`:

```bash
# Add to scripts/project-setup.sh after creating .cursor/mcp.json

echo ""
echo "⚙️  Creating Claude Code configuration..."

mkdir -p .claude

# Claude Code uses same wrapper pattern
cat > .claude/mcp.json << 'CLAUDE_CODE_EOF'
{
  "mcpServers": {
    "gitkraken": {
      "command": "bash",
      "args": ["./scripts/mcp-gitkraken"]
    },
    "filesystem": {
      "command": "bash",
      "args": ["./scripts/mcp-filesystem"]
    }
  }
}
CLAUDE_CODE_EOF

echo "✅ Created .claude/mcp.json"
```

### **Verification**

```bash
cd ~/Development/clawdbot

# Check Claude Code detects config
cat .claude/mcp.json

# Start Claude Code from project directory
cd ~/Development/clawdbot
claude  # Should load .claude/mcp.json automatically

# Verify MCP servers loaded
# (Check Claude Code's MCP server status)
```

### **Environment Inheritance**

Claude Code automatically inherits shell environment:

```bash
cd ~/Development/clawdbot
# direnv loads: GITHUB_TOKEN, PROJECT_NAME, etc.

claude  # Inherits all environment variables
# MCP wrapper scripts have access to GITHUB_TOKEN
```

---

## **CODEX Configuration**

### **GitHub Copilot CLI (Codex)**

Codex doesn't support MCP servers directly, but can work with the environment:

```bash
# .envrc additions for Codex
export OPENAI_API_KEY="..."  # Already handled by op_export
export CODEX_MODEL="gpt-4"   # If using custom model
```

### **Codex Usage Pattern**

```bash
cd ~/Development/clawdbot
# direnv loads environment

# Codex commands inherit environment
gh copilot suggest "write a function to parse JSON"
gh copilot explain "git commit -m 'feat: add parser'"
```

**Note:** Codex doesn't use MCP. Environment variables are sufficient.

---

## **GEMINI CLI Configuration**

### **Gemini CLI MCP Support**

Gemini CLI (version 0.26.0+) supports project-local configuration via `.gemini/settings.json`. It merges this with your global `~/.gemini/settings.json`.

### **Setup: Per-Project Configuration**

Add this to your `project-setup.sh`:

```bash
mkdir -p .gemini

cat > .gemini/settings.json << 'GEMINI_EOF'
{
  "security": {
    "auth": {
      "selectedType": "gemini-api-key"
    }
  },
  "mcpServers": {
    "gitkraken": {
      "command": "bash",
      "args": ["./scripts/mcp-gitkraken"]
    },
    "filesystem": {
      "command": "bash",
      "args": ["./scripts/mcp-filesystem"]
    }
  }
}
GEMINI_EOF
```

### **Authentication**

To use Gemini CLI with 1Password and direnv, you must set `selectedType` to `gemini-api-key`.

**Add to .envrc:**
```bash
op_export GEMINI_API_KEY "op://Development/Gemini/api_key"
```

### **Verification**

```bash
cd ~/Development/project
gemini mcp list
# Should show your project-local servers and global ones
```

---

## **GENERAL AI CLI PATTERN**

### **For Any AI CLI with MCP Support**

**Step 1: Identify Config Location**

```bash
# Check documentation or help
<ai-cli> --help | grep -i config
<ai-cli> config --help

# Common locations:
~/.config/<ai-cli>/mcp.json    # Global
./<ai-cli>/mcp.json            # Project-scoped (preferred)
```

**Step 2: Create Project Config**

```bash
mkdir -p .<ai-cli>

cat > .<ai-cli>/mcp.json << 'EOF'
{
  "mcpServers": {
    "gitkraken": {
      "command": "bash",
      "args": ["./scripts/mcp-gitkraken"]
    },
    "filesystem": {
      "command": "bash",
      "args": ["./scripts/mcp-filesystem"]
    }
  }
}
EOF
```

**Step 3: Test**

```bash
cd ~/Development/project
<ai-cli>  # Should load project MCP config
```

---

## **UPDATED PROJECT SETUP SCRIPT**

Add AI CLI support to your deployment:

```bash
# Add this section to scripts/project-setup.sh

echo ""
echo "⚙️  Creating AI CLI configurations..."

# Claude Code
mkdir -p .claude
cp .cursor/mcp.json .claude/mcp.json
echo "✅ Created .claude/mcp.json"

# Codex (GitHub Copilot) - environment only, no MCP
echo "✅ Codex will use environment variables (no MCP config needed)"

# Gemini (if applicable)
if command -v gemini &>/dev/null; then
  mkdir -p .gemini
  cp .cursor/mcp.json .gemini/settings.json
  echo "✅ Created .gemini/settings.json"
fi

# Other AI CLIs (add as needed)
# mkdir -p .ai-cli-name
# cp .cursor/mcp.json .ai-cli-name/mcp.json
```

---

## **ENVIRONMENT VARIABLE HANDLING**

### **AI CLIs Access Secrets via Environment**

All AI CLIs inherit direnv environment automatically:

```bash
# .envrc loads these
op_export GITHUB_TOKEN "op://Development/GitHub/credential"
op_export OPENAI_API_KEY "op://Development/OpenAI/api_key"
op_export ANTHROPIC_API_KEY "op://Development/Anthropic/api_key"
op_export GEMINI_API_KEY "op://Development/Gemini/api_key"

# When you run any CLI from this directory:
cd ~/Development/clawdbot
claude         # Has ANTHROPIC_API_KEY
gh copilot     # Has OPENAI_API_KEY (if configured)
gemini         # Has GEMINI_API_KEY
```

**This already works!** No additional configuration needed for environment inheritance.

---

## **LAUNCH PATTERNS**

### **Pattern 1: Direct Launch (Recommended)**

```bash
# Always cd to project first
cd ~/Development/clawdbot
# direnv loads environment
claude  # Inherits env + loads .claude/mcp.json
```

### **Pattern 2: Wrapper Script**

Create project-specific launcher:

```bash
# scripts/claude-here
#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"
exec claude "$@"
```

Usage:
```bash
./scripts/claude-here "implement user authentication"
```

### **Pattern 3: Shell Alias**

```bash
# Add to ~/.zshrc
alias clcode='cd $(git rev-parse --show-toplevel 2>/dev/null || pwd) && claude'

# Usage from anywhere in project
cd ~/Development/clawdbot/src/components
clcode "refactor this component"
# Automatically cd's to project root first
```

---

## **VALIDATION TESTS**

Add AI CLI tests to `validate-setup.sh`:

```bash
# Add to scripts/validate-setup.sh

echo "Test 11: Claude Code configuration"
if [ -f .claude/mcp.json ]; then
  test_result 0 "Claude Code MCP config exists"
else
  test_result 1 "Claude Code MCP config exists"
fi

echo "Test 12: AI CLI environment inheritance"
if [ -n "$ANTHROPIC_API_KEY" ] || [ -n "$OPENAI_API_KEY" ]; then
  test_result 0 "AI CLI credentials loaded"
else
  test_result 1 "AI CLI credentials loaded"
fi
```

---

## **COMPATIBILITY MATRIX**

| AI CLI | MCP Support | Config Location | Environment Inheritance | Status |
|--------|-------------|-----------------|------------------------|--------|
| **Claude Code** | ✅ Yes | `.claude/mcp.json` | ✅ Automatic | Full support |
| **GitHub Copilot** | ❌ No | N/A | ✅ Automatic | Environment only |
| **Cursor** | ✅ Yes | `.cursor/mcp.json` | ✅ Automatic | Full support |
| **VS Code** | ✅ Yes | `.vscode/mcp.json` | ✅ Automatic | Full support |
| **Gemini CLI** | ✅ Yes | `.gemini/settings.json` | ✅ Automatic | Full support |
| **Codex** | ❌ No | N/A | ✅ Automatic | Environment only |

---

## **COMMON ISSUES & SOLUTIONS**

### **Issue: AI CLI doesn't load project MCP config**

**Solution 1: Check config location**
```bash
# Find where AI CLI looks for config
<ai-cli> --help | grep -i config
strace <ai-cli> 2>&1 | grep -i mcp.json  # Linux
dtruss <ai-cli> 2>&1 | grep -i mcp.json  # macOS
```

**Solution 2: Force config path**
```bash
# Some CLIs support --config flag
<ai-cli> --config ./<ai-cli>/mcp.json
```

### **Issue: Environment variables not available in AI CLI**

**Diagnosis:**
```bash
cd ~/Development/clawdbot
echo $GITHUB_TOKEN  # Should show token

# Launch AI CLI and check
<ai-cli> --debug
# Or check if CLI can access env
```

**Solution: Ensure launching from project directory**
```bash
# WRONG - launches from home directory
cd ~
claude ~/Development/clawdbot/file.py

# RIGHT - cd to project first
cd ~/Development/clawdbot
claude file.py
```

### **Issue: MCP servers not connecting**

**Check wrapper scripts:**
```bash
# Test wrapper manually
cd ~/Development/clawdbot
bash ./scripts/mcp-gitkraken
# Should start MCP server without errors
```

**Check permissions:**
```bash
ls -la scripts/mcp-*
# Should be executable (rwxr-xr-x)
chmod +x scripts/mcp-*
```

---

## **COMPLETE UPDATED PROJECT SETUP**

Here's the full addition to `project-setup.sh` for AI CLI support:

```bash
# ============================================================
# STEP 4: CREATE AI CLI CONFIGURATIONS
# ============================================================

echo ""
echo "⚙️  Creating AI CLI configurations..."

# Claude Code
if command -v claude &>/dev/null; then
  mkdir -p .claude
  
  cat > .claude/mcp.json << 'CLAUDE_CODE_MCP_EOF'
{
  "mcpServers": {
    "gitkraken": {
      "command": "bash",
      "args": ["./scripts/mcp-gitkraken"]
    },
    "filesystem": {
      "command": "bash",
      "args": ["./scripts/mcp-filesystem"]
    }
  }
}
CLAUDE_CODE_MCP_EOF
  
  echo "✅ Created .claude/mcp.json"
else
  echo "⚠️  Claude Code not installed (skipping)"
fi

# Gemini CLI
if command -v gemini &>/dev/null; then
  mkdir -p .gemini
  cp .cursor/mcp.json .gemini/settings.json
  echo "✅ Created .gemini/settings.json"
fi

# GitHub Copilot (no MCP support)
if command -v gh &>/dev/null && gh copilot --version &>/dev/null; then
  echo "✅ GitHub Copilot detected (uses environment variables only)"
fi

# Add to .gitignore
if ! grep -q ".claude/" .gitignore 2>/dev/null; then
  cat >> .gitignore << 'GITIGNORE_AI_EOF'

# AI CLI configs
.claude/
.gemini/
GITIGNORE_AI_EOF
  echo "✅ Updated .gitignore for AI CLI configs"
fi
```

---

## **ENVIRONMENT ADDITIONS**

Add AI-specific credentials to `.envrc`:

```bash
# Add to .envrc template

# AI CLI Credentials
op_export ANTHROPIC_API_KEY "op://Development/Anthropic/api_key"  # Claude Code
op_export OPENAI_API_KEY "op://Development/OpenAI/api_key"        # Codex
op_export GEMINI_API_KEY "op://Development/Gemini/api_key"        # Gemini CLI
```

---

## **QUICK REFERENCE**

### **Setup Commands**

```bash
# One-time: Update project-setup.sh with AI CLI support
# (Use updated script above)

# Per project: Run updated setup
cd ~/Development/project
bash ~/mcp-deployment/scripts/project-setup.sh

# Verify AI CLI configs
ls -la .claude/ .gemini/

# Test AI CLI
claude "list available MCP servers"
```

### **Daily Usage**

```bash
# Switch projects (automatic)
cd ~/Development/clawdbot
claude "implement feature X"  # Uses clawdbot MCP servers

cd ~/Development/data-science
claude "analyze dataset"      # Uses data-science MCP servers
```

---

## **SUMMARY**

### **✅ What Works Out of the Box:**
- Environment variable inheritance (all AI CLIs)
- Credentials from 1Password (via direnv)
- Project isolation (via direnv)

### **✅ What Needs Configuration:**
- MCP server configs per AI CLI (`.claude/mcp.json`, etc.)
- Launch patterns (cd to project first)

### **✅ What to Update:**
1. Add AI CLI config section to `project-setup.sh`
2. Add AI CLI credentials to `.envrc`
3. Add AI CLI validation to `validate-setup.sh`
4. Document AI CLI usage in project README

**Result:** AI CLIs work seamlessly with your MCP environment across all projects.

---

**Next Step:** Update your `project-setup.sh` script with the AI CLI configuration section above.
