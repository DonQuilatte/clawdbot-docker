#!/bin/bash
# Clawdbot Browser Validation - Quick Test
# Perfect for running in Claude browser chat

set -uo pipefail

echo "╔════════════════════════════════════════╗"
echo "║   Clawdbot Validation Test Suite      ║"
echo "╚════════════════════════════════════════╝"
echo ""

PASS=0
FAIL=0

# Test 1: Gateway Status
echo -n "1️⃣  Gateway Dashboard......... "
if curl -s http://localhost:18789 | grep -q "Clawdbot"; then
    echo "✅ PASS"
    PASS=$((PASS + 1))
else
    echo "❌ FAIL"
    FAIL=$((FAIL + 1))
fi

# Test 2: Gateway Process
echo -n "2️⃣  Gateway Process........... "
if ps aux | grep -q "[c]lawdbot-gateway"; then
    echo "✅ PASS"
    PASS=$((PASS + 1))
else
    echo "❌ FAIL"
    FAIL=$((FAIL + 1))
fi

# Test 3: Port Binding
echo -n "3️⃣  Port 18789 Listening...... "
if lsof -i :18789 | grep -q LISTEN; then
    echo "✅ PASS"
    PASS=$((PASS + 1))
else
    echo "❌ FAIL"
    FAIL=$((FAIL + 1))
fi

# Test 4: Configuration File
echo -n "4️⃣  Configuration File........ "
if [ -f ~/.clawdbot/clawdbot.json ]; then
    echo "✅ PASS"
    PASS=$((PASS + 1))
else
    echo "❌ FAIL"
    FAIL=$((FAIL + 1))
fi

# Test 5: SSH Connectivity
echo -n "5️⃣  SSH to Remote Node........ "
if ssh -o ConnectTimeout=5 tywhitaker@192.168.1.245 "echo 'connected'" >/dev/null 2>&1; then
    echo "✅ PASS"
    PASS=$((PASS + 1))
else
    echo "❌ FAIL"
    FAIL=$((FAIL + 1))
fi

# Test 6: Remote Node Process
echo -n "6️⃣  Remote Node Process....... "
if ssh tywhitaker@192.168.1.245 "ps aux | grep -q '[c]lawdbot'" 2>/dev/null; then
    echo "✅ PASS"
    PASS=$((PASS + 1))
else
    echo "❌ FAIL"
    FAIL=$((FAIL + 1))
fi

# Test 7: WebSocket Connection
echo -n "7️⃣  WebSocket Connection...... "
if lsof -i :18789 | grep -q ESTABLISHED; then
    echo "✅ PASS"
    PASS=$((PASS + 1))
else
    echo "❌ FAIL"
    FAIL=$((FAIL + 1))
fi

# Test 8: Log Files
echo -n "8️⃣  Log Files................. "
if ls ~/.clawdbot/logs/*.log >/dev/null 2>&1; then
    echo "✅ PASS"
    PASS=$((PASS + 1))
else
    echo "❌ FAIL"
    FAIL=$((FAIL + 1))
fi

# Test 9: API Endpoint
echo -n "9️⃣  API Endpoint.............. "
if curl -s http://localhost:18789/api/status >/dev/null 2>&1; then
    echo "✅ PASS"
    PASS=$((PASS + 1))
else
    echo "❌ FAIL"
    FAIL=$((FAIL + 1))
fi

# Test 10: Node Discovery
echo -n "🔟 Service Discovery......... "
if ssh tywhitaker@192.168.1.245 "clawdbot gateway discover 2>&1 | grep -q 'Mac.local'" 2>/dev/null; then
    echo "✅ PASS"
    PASS=$((PASS + 1))
else
    echo "❌ FAIL"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "╔════════════════════════════════════════╗"
echo "║            Test Results                ║"
echo "╠════════════════════════════════════════╣"
printf "║  ✅ Passed: %-2d                        ║\n" $PASS
printf "║  ❌ Failed: %-2d                        ║\n" $FAIL
echo "╠════════════════════════════════════════╣"

if [ $FAIL -eq 0 ]; then
    echo "║  Status: 🎉 ALL TESTS PASSED          ║"
    echo "║  System: ✅ READY FOR USE              ║"
else
    echo "║  Status: ⚠️  SOME TESTS FAILED         ║"
    echo "║  Action: 🔧 REVIEW FAILED TESTS        ║"
fi

echo "╚════════════════════════════════════════╝"
echo ""

# Additional Info
echo "📊 System Information:"
echo "   Gateway URL: http://localhost:18789"
echo "   Remote Node: tywhitaker@192.168.1.245"
echo "   Config: ~/.clawdbot/clawdbot.json"
echo "   Logs: ~/.clawdbot/logs/"
echo ""

# Exit with appropriate code
if [ $FAIL -eq 0 ]; then
    exit 0
else
    exit 1
fi
