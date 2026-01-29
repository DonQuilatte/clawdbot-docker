#!/usr/bin/env bash
set -e

cat << "BANNER"
╔════════════════════════════════════════════════════════════╗
║  MCP Environment Setup - Global Configuration              ║
║  Version: 1.0.0                                            ║
║  Time required: ~10 minutes                                ║
╚════════════════════════════════════════════════════════════╝
BANNER

echo ""
echo "🔍 Checking prerequisites..."

if ! command -v brew &>/dev/null; then
  echo "❌ Homebrew not found. Install from https://brew.sh"
  exit 1
fi
echo "✅ Homebrew installed"

if [ ! -d "/Applications/1Password.app" ]; then
  echo "⚠️  1Password app not found. Please install from https://1password.com"
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

echo ""
echo "📦 Installing required tools..."

if ! command -v op &>/dev/null; then
  brew install --cask 1password-cli
  echo "✅ Installed 1Password CLI"
else
  echo "✅ 1Password CLI already installed"
fi

if ! command -v direnv &>/dev/null; then
  brew install direnv
  echo "✅ Installed direnv"
else
  echo "✅ direnv already installed"
fi

echo ""
echo "📝 Creating direnv configuration..."

mkdir -p ~/.config/direnv

if [ -f ~/.config/direnv/direnvrc ]; then
  cp ~/.config/direnv/direnvrc ~/.config/direnv/direnvrc.backup.$(date +%Y%m%d_%H%M%S)
  echo "📦 Backed up existing direnvrc"
fi

cat > ~/.config/direnv/direnvrc << 'DIRENVRC_EOF'
#!/usr/bin/env bash

op_can_read() {
  if [ "${DIRENV_OP_CAN_READ:-}" = "1" ]; then
    return 0
  fi
  if [ "${DIRENV_OP_CAN_READ:-}" = "0" ]; then
    return 1
  fi

  command -v op >/dev/null 2>&1 || { 
    export DIRENV_OP_CAN_READ=0
    return 1
  }

  if op whoami >/dev/null 2>&1; then
    export DIRENV_OP_CAN_READ=1
    return 0
  fi

  if op account list >/dev/null 2>&1; then
    export DIRENV_OP_CAN_READ=1
    return 0
  fi

  export DIRENV_OP_CAN_READ=0
  return 1
}

op_export() {
  local var="$1"
  local ref="$2"

  [ -n "$var" ] || return 1
  [ -n "$ref" ] || return 1

  if ! op_can_read; then
    echo "direnv: 1Password unavailable" >&2
    return 1
  fi

  local val
  if command -v perl &>/dev/null; then
    val="$(op read "$ref" 2>/dev/null | perl -pe 'chomp if eof')"
  else
    val="$(op read "$ref" 2>/dev/null | tr -d '\n')"
  fi

  if [ -z "$val" ]; then
    echo "direnv: failed to read $var" >&2
    return 1
  fi

  export "$var=$val"
}

detect_docker_socket() {
  local sockets=(
    "$HOME/.orbstack/run/docker.sock"
    "$HOME/.docker/run/docker.sock"
    "/var/run/docker.sock"
    "$HOME/.colima/default/docker.sock"
    "$HOME/.lima/docker.sock"
    "$HOME/.rd/docker.sock"
  )

  for s in "${sockets[@]}"; do
    if [ -S "$s" ]; then
      export DOCKER_HOST="unix://$s"
      return 0
    fi
  done

  return 1
}
DIRENVRC_EOF

chmod +x ~/.config/direnv/direnvrc
echo "✅ Created ~/.config/direnv/direnvrc"

echo ""
echo "🔧 Configuring shell integration..."

SHELL_RC="$HOME/.zshrc"
if [ ! -f "$SHELL_RC" ]; then
  SHELL_RC="$HOME/.bashrc"
fi

if ! grep -q "direnv hook" "$SHELL_RC" 2>/dev/null; then
  echo "" >> "$SHELL_RC"
  echo '# direnv integration' >> "$SHELL_RC"
  echo 'eval "$(direnv hook zsh)"' >> "$SHELL_RC"
  echo "✅ Added direnv hook to $SHELL_RC"
else
  echo "✅ direnv hook already present"
fi

echo ""
echo "🔐 Testing 1Password CLI..."

if op whoami &>/dev/null; then
  echo "✅ 1Password CLI authenticated"
else
  echo "⚠️  Enable CLI integration in 1Password app:"
  echo "   Settings → Developer → CLI"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ GLOBAL SETUP COMPLETE"
echo ""
echo "Next steps:"
echo "  1. Reload shell: exec zsh"
echo "  2. Run project-setup.sh in each repo"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
