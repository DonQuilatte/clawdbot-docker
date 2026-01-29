# 🎯 Quick Guide: Testing Clawdbot with Browser Claude

## Copy This Command to Claude in Browser Chat

### ⚡ Single Command - Full Validation

```bash
~/Development/Projects/clawdbot/scripts/browser-validate.sh
```

**What happens:**

- Runs 10 validation tests
- Takes ~10 seconds
- Shows visual results with ✅/❌
- Reports system status

---

## Expected Output

```
╔════════════════════════════════════════╗
║   Clawdbot Validation Test Suite      ║
╚════════════════════════════════════════╝

1️⃣  Gateway Dashboard......... ✅ PASS
2️⃣  Gateway Process........... ✅ PASS
3️⃣  Port 18789 Listening...... ✅ PASS
4️⃣  Configuration File........ ✅ PASS
5️⃣  SSH to Remote Node........ ✅ PASS
6️⃣  Remote Node Process....... ✅ PASS
7️⃣  WebSocket Connection...... ✅ PASS
8️⃣  Log Files................. ✅ PASS
9️⃣  API Endpoint.............. ✅ PASS
🔟 Service Discovery......... ✅ PASS

╔════════════════════════════════════════╗
║            Test Results                ║
╠════════════════════════════════════════╣
║  ✅ Passed: 10                         ║
║  ❌ Failed: 0                          ║
╠════════════════════════════════════════╣
║  Status: 🎉 ALL TESTS PASSED          ║
║  System: ✅ READY FOR USE              ║
╚════════════════════════════════════════╝

📊 System Information:
   Gateway URL: http://localhost:18789
   Remote Node: tywhitaker@192.168.1.245
   Config: ~/.clawdbot/clawdbot.json
   Logs: ~/.clawdbot/logs/
```

---

## Alternative: Super Quick One-Liner

```bash
echo "Gateway: $(curl -s http://localhost:18789 | grep -q Clawdbot && echo ✅ || echo ❌) | Process: $(ps aux | grep -q [c]lawdbot-gateway && echo ✅ || echo ❌) | SSH: $(ssh -o ConnectTimeout=3 tywhitaker@192.168.1.245 'echo ✅' 2>/dev/null || echo ❌) | Remote: $(ssh tywhitaker@192.168.1.245 'ps aux | grep -q [c]lawdbot && echo ✅ || echo ❌' 2>/dev/null) | WebSocket: $(lsof -i :18789 | grep -q ESTABLISHED && echo ✅ || echo ❌)"
```

**Expected:** All show ✅

---

## Individual Quick Tests

### Test Gateway

```bash
curl -s http://localhost:18789 | grep "Clawdbot" && echo "✅ OK" || echo "❌ FAIL"
```

### Test Remote Connection

```bash
ssh tywhitaker@192.168.1.245 "echo '✅ Connected'" || echo "❌ FAIL"
```

### Test WebSocket

```bash
lsof -i :18789 | grep ESTABLISHED && echo "✅ Connected" || echo "❌ No connection"
```

---

## 📖 More Information

- **Detailed Tests:** `~/Development/Projects/clawdbot/docs/BROWSER-VALIDATION-TESTS.md`
- **Quick Reference:** `~/Development/Projects/clawdbot/docs/BROWSER-TESTING-README.md`
- **Full Test Suite:** `~/Development/Projects/clawdbot/scripts/test-clawdbot-system-fast.sh`

---

**Just copy the command above and paste it to Claude in your browser!** 🚀
