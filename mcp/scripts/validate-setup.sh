#!/usr/bin/env bash
set -e

cat << "BANNER"
╔════════════════════════════════════════════════════════════╗
║  MCP Environment Validation                                ║
╚════════════════════════════════════════════════════════════╝
BANNER

echo ""
PASS=0
FAIL=0

test_result() {
  if [ $1 -eq 0 ]; then
    echo "✅ $2"
    ((PASS++))
  else
    echo "❌ $2"
    ((FAIL++))
  fi
}

echo "🔍 Running validation tests..."
echo ""

# Test 1: direnv installed
echo "Test 1: direnv installation"
command -v direnv &>/dev/null
test_result $? "direnv is installed"

# Test 2: 1Password CLI installed
echo "Test 2: 1Password CLI installation"
command -v op &>/dev/null
test_result $? "1Password CLI is installed"

# Test 3: direnvrc exists
echo "Test 3: direnvrc configuration"
[ -f ~/.config/direnv/direnvrc ]
test_result $? "direnvrc file exists"

# Test 4: Shell hook configured
echo "Test 4: Shell integration"
grep -q "direnv hook" ~/.zshrc 2>/dev/null || grep -q "direnv hook" ~/.bashrc 2>/dev/null
test_result $? "direnv hook configured in shell"

# Test 5: 1Password authenticated
echo "Test 5: 1Password authentication"
op whoami &>/dev/null
test_result $? "1Password CLI authenticated"

# Test 6: Project .envrc exists
echo "Test 6: Project configuration"
if [ -f .envrc ]; then
  test_result 0 ".envrc exists in current directory"
else
  test_result 1 ".envrc exists in current directory"
fi

# Test 7: Wrapper scripts exist
echo "Test 7: Wrapper scripts"
if [ -d scripts ] && [ -f scripts/mcp-gitkraken ]; then
  test_result 0 "Wrapper scripts present"
else
  test_result 1 "Wrapper scripts present"
fi

# Test 8: MCP configs exist
echo "Test 8: MCP configurations"
if [ -f .cursor/mcp.json ] || [ -f .vscode/mcp.json ]; then
  test_result 0 "MCP config files present"
else
  test_result 1 "MCP config files present"
fi

# Test 9: Environment variables loaded
echo "Test 9: Environment loading"
if [ -n "$PROJECT_NAME" ]; then
  test_result 0 "PROJECT_NAME environment variable set"
else
  test_result 1 "PROJECT_NAME environment variable set"
fi

# Test 10: Docker socket detection
echo "Test 10: Docker socket"
if [ -n "$DOCKER_HOST" ]; then
  test_result 0 "Docker socket detected: $DOCKER_HOST"
else
  echo "⚠️  Docker socket not detected (optional)"
fi

# Test 11: Gemini CLI configuration
echo "Test 11: Gemini CLI configuration"
if command -v gemini &>/dev/null; then
  if [ -f .gemini/settings.json ]; then
    test_result 0 "Gemini CLI settings.json exists"
  else
    test_result 1 "Gemini CLI settings.json exists"
  fi
else
  echo "⚠️  Gemini CLI not installed (skipping)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "RESULTS: $PASS passed, $FAIL failed"
echo ""

if [ $FAIL -eq 0 ]; then
  echo "✅ ALL TESTS PASSED"
  echo "Your MCP environment is ready!"
  exit 0
else
  echo "❌ SOME TESTS FAILED"
  echo "Please review the failures above"
  exit 1
fi
