#!/usr/bin/env bash
set -e

PROJECT_NAME="${1:-$(basename $(pwd))}"
PROJECT_ROOT="$(pwd)"

cat << "BANNER"
╔════════════════════════════════════════════════════════════╗
║  MCP Environment Setup - Project Configuration             ║
╚════════════════════════════════════════════════════════════╝
BANNER

echo ""
echo "📍 Project: $PROJECT_NAME"
echo "📂 Path: $PROJECT_ROOT"
echo ""

read -p "Continue with setup? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
  exit 0
fi

echo ""
echo "📝 Creating .envrc..."

if [ -f .envrc ]; then
  echo "⚠️  .envrc already exists"
  read -p "Overwrite? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Skipping .envrc creation"
  else
    cat > .envrc << ENVRC_EOF
#!/usr/bin/env bash

export PROJECT_NAME="$PROJECT_NAME"
export PROJECT_ROOT="$PWD"

detect_docker_socket

# TODO: Update these references for your 1Password vaults
op_export GITHUB_TOKEN "op://Development/GitHub Token/credential"
op_export OPENAI_API_KEY "op://Development/OpenAI/api_key"
op_export GEMINI_API_KEY "op://Development/Gemini/api_key"

export DC_LOG_LEVEL="info"
export DC_CONFIG_DIR="\$PROJECT_ROOT/config"
ENVRC_EOF
    echo "✅ Created .envrc"
  fi
else
  cat > .envrc << ENVRC_EOF
#!/usr/bin/env bash

export PROJECT_NAME="$PROJECT_NAME"
export PROJECT_ROOT="$PWD"

detect_docker_socket

# TODO: Update these references for your 1Password vaults
op_export GITHUB_TOKEN "op://Development/GitHub Token/credential"
op_export OPENAI_API_KEY "op://Development/OpenAI/api_key"
op_export GEMINI_API_KEY "op://Development/Gemini/api_key"

export DC_LOG_LEVEL="info"
export DC_CONFIG_DIR="\$PROJECT_ROOT/config"
ENVRC_EOF
  echo "✅ Created .envrc"
fi

echo ""
echo "📜 Creating wrapper scripts..."

mkdir -p scripts

cat > scripts/mcp-gitkraken << 'SCRIPT_EOF'
#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Ensure Homebrew is in PATH (macOS)
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Use github MCP server (gitkraken doesn't exist publicly)
exec npx -y @modelcontextprotocol/server-github
SCRIPT_EOF

cat > scripts/mcp-filesystem << 'SCRIPT_EOF'
#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Ensure Homebrew is in PATH (macOS)
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

exec npx -y @modelcontextprotocol/server-filesystem "$PROJECT_ROOT"
SCRIPT_EOF

chmod +x scripts/mcp-*
echo "✅ Created wrapper scripts"

echo ""
echo "⚙️  Creating MCP configurations..."

mkdir -p .cursor .vscode

cat > .cursor/mcp.json << 'MCP_EOF'
{
  "mcpServers": {
    "github": {
      "command": "bash",
      "args": ["./scripts/mcp-gitkraken"]
    },
    "filesystem": {
      "command": "bash",
      "args": ["./scripts/mcp-filesystem"]
    }
  }
}
MCP_EOF

cp .cursor/mcp.json .vscode/mcp.json
echo "✅ Created MCP configs"

echo ""
echo "📝 Updating .gitignore..."

if [ ! -f .gitignore ]; then
  touch .gitignore
fi

if ! grep -q ".envrc.local" .gitignore 2>/dev/null; then
  cat >> .gitignore << 'GITIGNORE_EOF'

# direnv
.envrc.local
.direnv/
GITIGNORE_EOF
  echo "✅ Updated .gitignore"
else
  echo "✅ .gitignore already configured"
fi

echo ""
echo "🔐 Activating direnv..."

direnv allow

echo ""
echo "⚙️  Creating AI CLI configurations..."

# Claude Code
if command -v claude &>/dev/null; then
  mkdir -p .claude
  cp .cursor/mcp.json .claude/mcp.json
  echo "✅ Created .claude/mcp.json"
else
  echo "⚠️  Claude Code not installed (skipping)"
fi

# Gemini CLI (supports project-local settings.json)
if command -v gemini &>/dev/null; then
  mkdir -p .gemini
  cat > .gemini/settings.json << 'GEMINI_EOF'
{
  "security": {
    "auth": {
      "selectedType": "gemini-api-key"
    }
  },
  "mcpServers": {
    "github": {
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
  echo "✅ Created .gemini/settings.json"
fi

# GitHub Copilot (uses environment only)
if command -v gh &>/dev/null && gh copilot --version &>/dev/null 2>&1; then
  echo "✅ GitHub Copilot detected (uses environment variables)"
fi

# Antigravity IDE
if command -v antigravity &>/dev/null || [ -d "$HOME/.antigravity" ]; then
  mkdir -p .antigravity
  cat > .antigravity/config.json << 'ANTIGRAVITY_EOF'
{
  "onOpen": {
    "setupScript": "scripts/project-setup.sh",
    "allowDirenv": true,
    "notification": {
      "enabled": true,
      "message": "Project MCP environment loaded"
    }
  },
  "mcp": {
    "autoLoad": true,
    "servers": {
      "github": {
        "command": "bash",
        "args": ["${workspaceFolder}/scripts/mcp-gitkraken"]
      },
      "filesystem": {
        "command": "bash",
        "args": ["${workspaceFolder}/scripts/mcp-filesystem"]
      }
    }
  },
  "execution": {
    "remote": {
      "enabled": false
    }
  }
}
ANTIGRAVITY_EOF
  echo "✅ Created .antigravity/config.json"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ PROJECT SETUP COMPLETE: $PROJECT_NAME"
echo ""
echo "Next steps:"
echo "  1. Edit .envrc - update 1Password references"
echo "  2. Test: echo \$GITHUB_TOKEN"
echo "  3. Restart your IDE to load MCP servers"
echo "  4. Commit: git add .envrc scripts/ .cursor/ .vscode/ .claude/ .antigravity/"
echo ""
echo "AI CLI Support:"
echo "  Claude Code: .claude/mcp.json"
echo "  GitHub Copilot: environment variables"
echo "  Gemini: .gemini/settings.json (if installed)"
echo "  Antigravity: .antigravity/config.json (if installed)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
