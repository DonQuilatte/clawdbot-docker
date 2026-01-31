#!/bin/bash
# Test shell integration without modifying your shell

set -euo pipefail

echo "=== Testing AGY Shell Integration ==="
echo ""

# Source the integration
source ~/Development/Projects/clawdbot/scripts/agy-shell-integration.sh

echo "✅ Shell integration loaded"
echo ""

# Test 1: cd to clawdbot project
echo "Test 1: Navigate to clawdbot project"
cd ~/Development/Projects/clawdbot
echo ""

# Test 2: Check if function exists
echo "Test 2: Verify agy_auto_engage function"
if type agy_auto_engage &>/dev/null; then
    echo "✅ agy_auto_engage function available"
else
    echo "❌ Function not found"
    exit 1
fi
echo ""

# Test 3: Test manual trigger
echo "Test 3: Manually trigger auto-engage"
agy_auto_engage
echo ""

# Test 4: Check aliases
echo "Test 4: Verify aliases"
if alias a &>/dev/null; then
    echo "✅ Alias 'a' → 'agy'"
else
    echo "⚠️  Alias 'a' not set"
fi

if alias agys &>/dev/null; then
    echo "✅ Alias 'agys' → 'agy -r status'"
else
    echo "⚠️  Alias 'agys' not set"
fi
echo ""

echo "=== Integration Test Complete ==="
echo ""
echo "To activate in your shell:"
echo "  source ~/.zshrc"
echo ""
echo "Then test by:"
echo "  cd ~/Development/Projects/clawdbot"
echo "  # Should see project detection message"
