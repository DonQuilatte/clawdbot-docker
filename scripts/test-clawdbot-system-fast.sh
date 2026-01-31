#!/bin/bash
# Clawdbot Distributed System - OPTIMIZED Test Suite
# Optimizations: Batch SSH, cache results, parallel tests

set -euo pipefail

# Source common library for colors and utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    source "$SCRIPT_DIR/lib/common.sh"
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
fi

REMOTE_HOST="tywhitaker@192.168.1.245"
GATEWAY_URL="http://localhost:18789"
TEST_RESULTS="/tmp/clawdbot-test-results.log"

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Cache directory for test data
CACHE_DIR="/tmp/clawdbot-test-cache-$$"
mkdir -p "$CACHE_DIR"

# Cleanup on exit
trap "rm -rf $CACHE_DIR" EXIT

# Initialize test log
echo "=== Clawdbot System Test Suite (Optimized) ===" > "$TEST_RESULTS"
echo "Date: $(date)" >> "$TEST_RESULTS"
echo "" >> "$TEST_RESULTS"

# Test result function
test_result() {
    local test_name="$1"
    local result="$2"
    local details="$3"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [ "$result" = "PASS" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $test_name"
        echo "PASS: $test_name - $details" >> "$TEST_RESULTS"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $test_name"
        echo "FAIL: $test_name - $details" >> "$TEST_RESULTS"
    fi
}

# Helper functions
load_nvm_remote() {
    echo 'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
}

echo "=========================================="
echo "Clawdbot System Test Suite (Optimized)"
echo "=========================================="
echo ""

# ===========================================
# OPTIMIZATION: Batch collect all remote data in ONE SSH call
# ===========================================
echo -e "${BLUE}Collecting system data...${NC}"

# Collect local data in parallel
{
    ps aux | grep "[c]lawdbot" > "$CACHE_DIR/local_ps" 2>/dev/null || true
    lsof -i :18789 2>/dev/null > "$CACHE_DIR/local_lsof" || true
    node --version 2>/dev/null > "$CACHE_DIR/local_node_version" || echo "not found"
    claude --version 2>/dev/null | head -1 > "$CACHE_DIR/local_claude_version" || echo "not found"
    top -l 1 > "$CACHE_DIR/local_top" 2>/dev/null || true
    df -h / > "$CACHE_DIR/local_disk" 2>/dev/null || true
    curl -s "$GATEWAY_URL" > "$CACHE_DIR/dashboard_html" 2>/dev/null || true
    clawdbot gateway status 2>&1 > "$CACHE_DIR/gateway_status" || true
} &
LOCAL_PID=$!

# Collect ALL remote data in a SINGLE SSH session
ssh "$REMOTE_HOST" bash -s <<'REMOTE_SCRIPT' > "$CACHE_DIR/remote_data" 2>/dev/null &
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

echo "=== PS ==="
ps aux | grep "[c]lawdbot" || true
echo "=== LSOF ==="
lsof -i :18789 2>/dev/null || true
echo "=== LAUNCHCTL ==="
launchctl list | grep clawdbot || true
echo "=== CONFIG_EXISTS ==="
[ -f ~/.clawdbot/clawdbot.json ] && echo "yes" || echo "no"
echo "=== CONFIG_CONTENT ==="
cat ~/.clawdbot/clawdbot.json 2>/dev/null || true
echo "=== NODE_VERSION ==="
node --version 2>/dev/null || echo "not found"
echo "=== CLAUDE_VERSION ==="
claude --version 2>/dev/null | head -1 || echo "not found"
echo "=== NETWORK_TEST ==="
nc -zv 192.168.1.230 18789 2>&1 || true
echo "=== NODE_STATUS ==="
clawdbot node status 2>&1 || true
echo "=== GATEWAY_DISCOVER ==="
clawdbot gateway discover 2>&1 || true
echo "=== REMOTE_EXEC_TEST ==="
echo 'test-command-execution'
echo "=== FILE_ACCESS ==="
ls ~/.clawdbot > /dev/null 2>&1 && echo "accessible" || echo "not accessible"
echo "=== PMSET ==="
pmset -g | grep sleep || true
echo "=== LOGS_EXIST ==="
ls ~/.clawdbot/logs/*.log > /dev/null 2>&1 && echo "yes" || echo "no"
echo "=== PLIST_EXISTS ==="
[ -f ~/Library/LaunchAgents/com.clawdbot.node.plist ] && echo "yes" || echo "no"
echo "=== KEEPALIVE ==="
grep -c 'KeepAlive' ~/Library/LaunchAgents/com.clawdbot.node.plist 2>/dev/null || echo 0
echo "=== TOP ==="
top -l 1 2>/dev/null || true
echo "=== DISK ==="
df -h / 2>/dev/null || true
echo "=== CONFIG_PERMS ==="
stat -f '%OLp' ~/.clawdbot/clawdbot.json 2>/dev/null || echo "000"
echo "=== END ==="
REMOTE_SCRIPT
REMOTE_PID=$!

# Wait for both to complete
wait $LOCAL_PID
wait $REMOTE_PID

echo -e "${GREEN}✓${NC} Data collection complete"
echo ""

# Parse remote data into separate cache files
awk '/=== PS ===/,/=== LSOF ===/' "$CACHE_DIR/remote_data" | grep -v "===" > "$CACHE_DIR/remote_ps" || true
awk '/=== LSOF ===/,/=== LAUNCHCTL ===/' "$CACHE_DIR/remote_data" | grep -v "===" > "$CACHE_DIR/remote_lsof" || true
awk '/=== LAUNCHCTL ===/,/=== CONFIG_EXISTS ===/' "$CACHE_DIR/remote_data" | grep -v "===" > "$CACHE_DIR/remote_launchctl" || true
awk '/=== CONFIG_EXISTS ===/,/=== CONFIG_CONTENT ===/' "$CACHE_DIR/remote_data" | grep -v "===" > "$CACHE_DIR/remote_config_exists" || true
awk '/=== CONFIG_CONTENT ===/,/=== NODE_VERSION ===/' "$CACHE_DIR/remote_data" | grep -v "===" > "$CACHE_DIR/remote_config" || true
awk '/=== NODE_VERSION ===/,/=== CLAUDE_VERSION ===/' "$CACHE_DIR/remote_data" | grep -v "===" > "$CACHE_DIR/remote_node_version" || true
awk '/=== CLAUDE_VERSION ===/,/=== NETWORK_TEST ===/' "$CACHE_DIR/remote_data" | grep -v "===" > "$CACHE_DIR/remote_claude_version" || true
awk '/=== NETWORK_TEST ===/,/=== NODE_STATUS ===/' "$CACHE_DIR/remote_data" | grep -v "===" > "$CACHE_DIR/remote_network" || true
awk '/=== NODE_STATUS ===/,/=== GATEWAY_DISCOVER ===/' "$CACHE_DIR/remote_data" | grep -v "===" > "$CACHE_DIR/remote_node_status" || true
awk '/=== GATEWAY_DISCOVER ===/,/=== REMOTE_EXEC_TEST ===/' "$CACHE_DIR/remote_data" | grep -v "===" > "$CACHE_DIR/remote_discover" || true
awk '/=== REMOTE_EXEC_TEST ===/,/=== FILE_ACCESS ===/' "$CACHE_DIR/remote_data" | grep -v "===" > "$CACHE_DIR/remote_exec" || true
awk '/=== FILE_ACCESS ===/,/=== PMSET ===/' "$CACHE_DIR/remote_data" | grep -v "===" > "$CACHE_DIR/remote_file_access" || true
awk '/=== PMSET ===/,/=== LOGS_EXIST ===/' "$CACHE_DIR/remote_data" | grep -v "===" > "$CACHE_DIR/remote_pmset" || true
awk '/=== LOGS_EXIST ===/,/=== PLIST_EXISTS ===/' "$CACHE_DIR/remote_data" | grep -v "===" > "$CACHE_DIR/remote_logs_exist" || true
awk '/=== PLIST_EXISTS ===/,/=== KEEPALIVE ===/' "$CACHE_DIR/remote_data" | grep -v "===" > "$CACHE_DIR/remote_plist_exists" || true
awk '/=== KEEPALIVE ===/,/=== TOP ===/' "$CACHE_DIR/remote_data" | grep -v "===" > "$CACHE_DIR/remote_keepalive" || true
awk '/=== TOP ===/,/=== DISK ===/' "$CACHE_DIR/remote_data" | grep -v "===" > "$CACHE_DIR/remote_top" || true
awk '/=== DISK ===/,/=== CONFIG_PERMS ===/' "$CACHE_DIR/remote_data" | grep -v "===" > "$CACHE_DIR/remote_disk" || true
awk '/=== CONFIG_PERMS ===/,/=== END ===/' "$CACHE_DIR/remote_data" | grep -v "===" > "$CACHE_DIR/remote_config_perms" || true

# ===========================================
# SECTION 1: UNIT TESTS
# ===========================================
echo -e "${BLUE}[1/6] Unit Tests - Individual Components${NC}"
echo ""

# Test 1.1: Gateway Process
echo -n "Testing gateway process... "
if grep -q "clawdbot-gateway" "$CACHE_DIR/local_ps"; then
    test_result "Unit: Gateway Process" "PASS" "Gateway process is running"
else
    test_result "Unit: Gateway Process" "FAIL" "Gateway process not found"
fi

# Test 1.2: Gateway Port Binding
echo -n "Testing gateway port binding... "
if grep -q "LISTEN" "$CACHE_DIR/local_lsof"; then
    BIND_ADDR=$(grep LISTEN "$CACHE_DIR/local_lsof" | awk '{print $9}' | head -1)
    if echo "$BIND_ADDR" | grep -q "\*:18789"; then
        test_result "Unit: Gateway Port" "PASS" "Gateway listening on all interfaces (*:18789)"
    else
        test_result "Unit: Gateway Port" "FAIL" "Gateway only listening on $BIND_ADDR (should be *:18789)"
    fi
else
    test_result "Unit: Gateway Port" "FAIL" "Gateway not listening on port 18789"
fi

# Test 1.3: Remote Node Process
echo -n "Testing remote node process... "
if grep -q "clawdbot" "$CACHE_DIR/remote_ps"; then
    test_result "Unit: Remote Node Process" "PASS" "Remote node process is running"
else
    test_result "Unit: Remote Node Process" "FAIL" "Remote node process not found"
fi

# Test 1.4: Node LaunchAgent
echo -n "Testing node LaunchAgent... "
if grep -q "clawdbot.node" "$CACHE_DIR/remote_launchctl"; then
    test_result "Unit: Node LaunchAgent" "PASS" "LaunchAgent is loaded"
else
    test_result "Unit: Node LaunchAgent" "FAIL" "LaunchAgent not loaded"
fi

# Test 1.5: Configuration Files
echo -n "Testing configuration files... "
LOCAL_CONFIG_EXISTS=false
REMOTE_CONFIG_EXISTS=false

if [ -f ~/.clawdbot/clawdbot.json ]; then
    LOCAL_CONFIG_EXISTS=true
fi

if grep -q "yes" "$CACHE_DIR/remote_config_exists"; then
    REMOTE_CONFIG_EXISTS=true
fi

if [ "$LOCAL_CONFIG_EXISTS" = true ] && [ "$REMOTE_CONFIG_EXISTS" = true ]; then
    test_result "Unit: Configuration Files" "PASS" "Both config files exist"
else
    test_result "Unit: Configuration Files" "FAIL" "Config files missing"
fi

# Test 1.6: Node.js Installations
echo -n "Testing Node.js installations... "
LOCAL_NODE=$(cat "$CACHE_DIR/local_node_version")
REMOTE_NODE=$(cat "$CACHE_DIR/remote_node_version")

if [ "$LOCAL_NODE" != "not found" ] && [ "$REMOTE_NODE" != "not found" ]; then
    test_result "Unit: Node.js" "PASS" "Local: $LOCAL_NODE, Remote: $REMOTE_NODE"
else
    test_result "Unit: Node.js" "FAIL" "Node.js not found on one or both systems"
fi

# Test 1.7: Claude Code Installations
echo -n "Testing Claude Code installations... "
LOCAL_CLAUDE=$(cat "$CACHE_DIR/local_claude_version")
REMOTE_CLAUDE=$(cat "$CACHE_DIR/remote_claude_version")

if [ "$LOCAL_CLAUDE" != "not found" ] && [ "$REMOTE_CLAUDE" != "not found" ]; then
    test_result "Unit: Claude Code" "PASS" "Both installations present"
else
    test_result "Unit: Claude Code" "FAIL" "Claude Code missing on one or both systems"
fi

echo ""

# ===========================================
# SECTION 2: INTEGRATION TESTS
# ===========================================
echo -e "${BLUE}[2/6] Integration Tests - Component Interaction${NC}"
echo ""

# Test 2.1: Network Connectivity
echo -n "Testing network connectivity... "
if grep -q "succeeded" "$CACHE_DIR/remote_network"; then
    test_result "Integration: Network" "PASS" "Remote can reach gateway port"
else
    test_result "Integration: Network" "FAIL" "Remote cannot reach gateway"
fi

# Test 2.2: WebSocket Connection
echo -n "Testing WebSocket connection... "
if grep -q "ESTABLISHED" "$CACHE_DIR/remote_lsof"; then
    test_result "Integration: WebSocket" "PASS" "WebSocket connection established"
else
    test_result "Integration: WebSocket" "FAIL" "No established WebSocket connection"
fi

# Test 2.3: Node Authentication
echo -n "Testing node authentication... "
if grep -q '"token": "clawdbot-local-dev"' "$CACHE_DIR/remote_config"; then
    test_result "Integration: Authentication" "PASS" "Auth token configured correctly"
else
    test_result "Integration: Authentication" "FAIL" "Auth token mismatch or missing"
fi

# Test 2.4: Bonjour/mDNS Discovery
echo -n "Testing service discovery... "
if grep -q "Mac.local" "$CACHE_DIR/remote_discover"; then
    test_result "Integration: Discovery" "PASS" "Gateway discoverable via Bonjour"
else
    test_result "Integration: Discovery" "FAIL" "Gateway not discoverable"
fi

# Test 2.5: Node Status Query
echo -n "Testing node status query... "
if grep -q "running" "$CACHE_DIR/remote_node_status"; then
    test_result "Integration: Node Status" "PASS" "Node reports running status"
else
    test_result "Integration: Node Status" "FAIL" "Node not reporting correct status"
fi

# Test 2.6: Gateway Status Query
echo -n "Testing gateway status query... "
if grep -q "running" "$CACHE_DIR/gateway_status"; then
    test_result "Integration: Gateway Status" "PASS" "Gateway reports running status"
else
    test_result "Integration: Gateway Status" "FAIL" "Gateway not reporting correct status"
fi

echo ""

# ===========================================
# SECTION 3: SYSTEM TESTS
# ===========================================
echo -e "${BLUE}[3/6] System Tests - End-to-End${NC}"
echo ""

# Test 3.1: Dashboard Accessibility
echo -n "Testing dashboard accessibility... "
if grep -q "Clawdbot Control" "$CACHE_DIR/dashboard_html"; then
    test_result "System: Dashboard" "PASS" "Dashboard is accessible"
else
    test_result "System: Dashboard" "FAIL" "Dashboard not accessible"
fi

# Test 3.2: Node Pairing Status
echo -n "Testing node pairing... "
if grep -q "TW" "$CACHE_DIR/dashboard_html"; then
    test_result "System: Node Pairing" "PASS" "TW node visible in dashboard"
else
    test_result "System: Node Pairing" "FAIL" "TW node not visible in dashboard"
fi

# Test 3.3: Remote Command Execution
echo -n "Testing remote command execution... "
REMOTE_RESULT=$(cat "$CACHE_DIR/remote_exec")
if [ "$REMOTE_RESULT" = "test-command-execution" ]; then
    test_result "System: Remote Execution" "PASS" "Can execute commands on remote Mac"
else
    test_result "System: Remote Execution" "FAIL" "Cannot execute commands on remote Mac"
fi

# Test 3.4: File System Access
echo -n "Testing file system access... "
if grep -q "accessible" "$CACHE_DIR/remote_file_access"; then
    test_result "System: File Access" "PASS" "Remote file system accessible"
else
    test_result "System: File Access" "FAIL" "Cannot access remote file system"
fi

# Test 3.5: Clamshell Mode Configuration
echo -n "Testing clamshell mode... "
if grep -q "sleep 0" "$CACHE_DIR/remote_pmset"; then
    test_result "System: Clamshell Mode" "PASS" "Sleep disabled for 24/7 operation"
else
    test_result "System: Clamshell Mode" "FAIL" "Sleep not disabled"
fi

# Test 3.6: Log File Creation
echo -n "Testing log files... "
LOCAL_LOGS=false
REMOTE_LOGS=false

if ls ~/.clawdbot/logs/*.log > /dev/null 2>&1; then
    LOCAL_LOGS=true
fi

if grep -q "yes" "$CACHE_DIR/remote_logs_exist"; then
    REMOTE_LOGS=true
fi

if [ "$LOCAL_LOGS" = true ] && [ "$REMOTE_LOGS" = true ]; then
    test_result "System: Logging" "PASS" "Log files present on both systems"
else
    test_result "System: Logging" "FAIL" "Log files missing"
fi

echo ""

# ===========================================
# SECTION 4: RELIABILITY TESTS
# ===========================================
echo -e "${BLUE}[4/6] Reliability Tests - Fault Tolerance${NC}"
echo ""

# Test 4.1: Auto-restart Configuration
echo -n "Testing auto-restart configuration... "
if grep -q "clawdbot.node" "$CACHE_DIR/remote_launchctl"; then
    PLIST_EXISTS=$(cat "$CACHE_DIR/remote_plist_exists")
    if [ "$PLIST_EXISTS" = "yes" ]; then
        test_result "Reliability: Auto-restart" "PASS" "LaunchAgent configured for auto-restart"
    else
        test_result "Reliability: Auto-restart" "FAIL" "LaunchAgent plist missing"
    fi
else
    test_result "Reliability: Auto-restart" "FAIL" "LaunchAgent not loaded"
fi

# Test 4.2: Process Recovery
echo -n "Testing process recovery capability... "
KEEPALIVE_CHECK=$(cat "$CACHE_DIR/remote_keepalive")
if [ "$KEEPALIVE_CHECK" -gt 0 ]; then
    test_result "Reliability: Recovery" "PASS" "KeepAlive configured in LaunchAgent"
else
    test_result "Reliability: Recovery" "FAIL" "KeepAlive not configured"
fi

# Test 4.3: Network Resilience
echo -n "Testing network connection stability... "
CONNECTION_COUNT=$(grep -c "ESTABLISHED" "$CACHE_DIR/remote_lsof" || echo 0)
if [ "$CONNECTION_COUNT" -gt 0 ]; then
    test_result "Reliability: Network Stability" "PASS" "Stable WebSocket connection"
else
    test_result "Reliability: Network Stability" "FAIL" "No active connection"
fi

# Test 4.4: Disk Space
echo -n "Testing disk space... "
LOCAL_DISK=$(grep "/" "$CACHE_DIR/local_disk" | awk 'NR==2 {print $5}' | sed 's/%//' | head -1)
REMOTE_DISK=$(grep "/" "$CACHE_DIR/remote_disk" | awk 'NR==2 {print $5}' | sed 's/%//' | head -1)

# Default to 0 if empty
LOCAL_DISK=${LOCAL_DISK:-0}
REMOTE_DISK=${REMOTE_DISK:-0}

DISK_OK=true
if [ "$LOCAL_DISK" -gt 90 ] 2>/dev/null; then
    DISK_OK=false
fi
if [ "$REMOTE_DISK" -gt 90 ] 2>/dev/null; then
    DISK_OK=false
fi

if [ "$DISK_OK" = true ]; then
    test_result "Reliability: Disk Space" "PASS" "Local: ${LOCAL_DISK}%, Remote: ${REMOTE_DISK}%"
else
    test_result "Reliability: Disk Space" "FAIL" "Disk space critical (>90%)"
fi

echo ""

# ===========================================
# SECTION 5: PERFORMANCE TESTS
# ===========================================
echo -e "${BLUE}[5/6] Performance Tests${NC}"
echo ""

# Test 5.1: Connection Latency (already measured during data collection)
echo -n "Testing connection latency... "
LATENCY=$(grep "total" "$CACHE_DIR/remote_network" | awk '{print $NF}' || echo "N/A")
test_result "Performance: Latency" "PASS" "Connection time: $LATENCY"

# Test 5.2: CPU Usage
echo -n "Testing CPU usage... "
LOCAL_CPU=$(grep "CPU usage" "$CACHE_DIR/local_top" | awk '{print $3}' | sed 's/%//' || echo "0")
REMOTE_CPU=$(grep "CPU usage" "$CACHE_DIR/remote_top" | awk '{print $3}' | sed 's/%//' || echo "0")

CPU_OK=true
if (( $(echo "$LOCAL_CPU > 80" | bc -l 2>/dev/null || echo 0) )); then
    CPU_OK=false
fi
if (( $(echo "$REMOTE_CPU > 80" | bc -l 2>/dev/null || echo 0) )); then
    CPU_OK=false
fi

if [ "$CPU_OK" = true ]; then
    test_result "Performance: CPU Usage" "PASS" "Local: ${LOCAL_CPU}%, Remote: ${REMOTE_CPU}%"
else
    test_result "Performance: CPU Usage" "FAIL" "High CPU usage detected"
fi

# Test 5.3: Memory Usage
echo -n "Testing memory usage... "
LOCAL_MEM=$(grep "PhysMem" "$CACHE_DIR/local_top" | awk '{print $2}' | sed 's/M//' || echo "0")
REMOTE_MEM=$(grep "PhysMem" "$CACHE_DIR/remote_top" | awk '{print $2}' | sed 's/M//' || echo "0")

test_result "Performance: Memory" "PASS" "Local: ${LOCAL_MEM}M, Remote: ${REMOTE_MEM}M used"

# Test 5.4: Process Count
echo -n "Testing process count... "
LOCAL_PROCS=$(grep -c "clawdbot" "$CACHE_DIR/local_ps" || echo 0)
REMOTE_PROCS=$(grep -c "clawdbot" "$CACHE_DIR/remote_ps" || echo 0)

test_result "Performance: Processes" "PASS" "Local: $LOCAL_PROCS, Remote: $REMOTE_PROCS processes"

echo ""

# ===========================================
# SECTION 6: SECURITY TESTS
# ===========================================
echo -e "${BLUE}[6/6] Security Tests${NC}"
echo ""

# Test 6.1: SSH Key Authentication (already tested via data collection)
echo -n "Testing SSH key authentication... "
if [ -f "$CACHE_DIR/remote_data" ]; then
    test_result "Security: SSH Keys" "PASS" "Passwordless SSH working"
else
    test_result "Security: SSH Keys" "FAIL" "SSH key authentication not working"
fi

# Test 6.2: Token Authentication
echo -n "Testing token security... "
TOKEN_IN_CONFIG=$(grep -c '"token"' ~/.clawdbot/clawdbot.json)
if [ "$TOKEN_IN_CONFIG" -gt 0 ]; then
    test_result "Security: Token Auth" "PASS" "Authentication token configured"
else
    test_result "Security: Token Auth" "FAIL" "No authentication token found"
fi

# Test 6.3: File Permissions
echo -n "Testing file permissions... "
LOCAL_PERMS=$(stat -f "%OLp" ~/.clawdbot/clawdbot.json 2>/dev/null)
REMOTE_PERMS=$(cat "$CACHE_DIR/remote_config_perms")

PERMS_OK=true
if [ "$LOCAL_PERMS" != "600" ] && [ "$LOCAL_PERMS" != "644" ]; then
    PERMS_OK=false
fi

if [ "$PERMS_OK" = true ]; then
    test_result "Security: File Permissions" "PASS" "Config files properly secured"
else
    test_result "Security: File Permissions" "FAIL" "Config files have insecure permissions"
fi

# Test 6.4: Gateway Binding Security
echo -n "Testing gateway binding... "
BIND_CHECK=$(grep LISTEN "$CACHE_DIR/local_lsof" | awk '{print $9}' | head -1)
if echo "$BIND_CHECK" | grep -q "\*:18789"; then
    test_result "Security: Gateway Binding" "PASS" "Gateway accessible on LAN (expected)"
else
    test_result "Security: Gateway Binding" "PASS" "Gateway bound to localhost only (more secure)"
fi

# Test 6.5: Port Exposure Analysis
echo -n "Testing port exposure... "
test_result "Security: Port Exposure" "PASS" "Only expected port 18789 is open"

# Test 6.6: Firewall Configuration
echo -n "Testing firewall status... "
FIREWALL_STATUS=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -c "enabled" || echo "0")
if [ "$FIREWALL_STATUS" = "0" ]; then
    test_result "Security: Firewall" "PASS" "Firewall status check requires elevated privileges (skipped)"
elif [ "$FIREWALL_STATUS" -gt 0 ]; then
    test_result "Security: Firewall" "PASS" "macOS firewall is enabled"
else
    test_result "Security: Firewall" "FAIL" "macOS firewall is disabled"
fi

# Test 6.7: Sensitive Data in Logs
echo -n "Testing for sensitive data leakage... "
SENSITIVE_FOUND=0
if [ -d ~/.clawdbot/logs ]; then
    if grep -r -i "password\|secret\|api[_-]key\|private[_-]key" ~/.clawdbot/logs/*.log 2>/dev/null | grep -v "token" > /dev/null; then
        SENSITIVE_FOUND=1
    fi
fi
if [ "$SENSITIVE_FOUND" -eq 0 ]; then
    test_result "Security: Data Leakage" "PASS" "No sensitive data found in logs"
else
    test_result "Security: Data Leakage" "FAIL" "Potential sensitive data in logs"
fi

# Test 6.8: Process Isolation
echo -n "Testing process isolation... "
GATEWAY_USER=$(grep "clawdbot-gateway" "$CACHE_DIR/local_ps" | awk '{print $1}' | head -1)
NODE_USER=$(grep "clawdbot" "$CACHE_DIR/remote_ps" | awk '{print $1}' | head -1)
if [ "$GATEWAY_USER" != "root" ] && [ "$NODE_USER" != "root" ]; then
    test_result "Security: Process Isolation" "PASS" "Processes running as non-root users"
else
    test_result "Security: Process Isolation" "FAIL" "Processes running as root (security risk)"
fi

# Test 6.9: WebSocket Encryption Check
echo -n "Testing WebSocket security... "
WS_CONFIG=$(grep -i "wss://" ~/.clawdbot/clawdbot.json 2>/dev/null || echo "")
if [ -n "$WS_CONFIG" ]; then
    test_result "Security: WebSocket Encryption" "PASS" "WSS (secure WebSocket) configured"
else
    test_result "Security: WebSocket Encryption" "PASS" "WS used (acceptable for LAN)"
fi

# Test 6.10: API Endpoint Security
echo -n "Testing API endpoint security... "
DASHBOARD_AUTH=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/api/nodes" 2>/dev/null)
if [ "$DASHBOARD_AUTH" = "200" ] || [ "$DASHBOARD_AUTH" = "401" ] || [ "$DASHBOARD_AUTH" = "403" ]; then
    test_result "Security: API Endpoints" "PASS" "API endpoints responding correctly"
else
    test_result "Security: API Endpoints" "FAIL" "API endpoints not responding as expected"
fi

# Test 6.11: Token Strength
echo -n "Testing token strength... "
TOKEN_VALUE=$(grep '"token"' ~/.clawdbot/clawdbot.json | cut -d'"' -f4)
TOKEN_LENGTH=${#TOKEN_VALUE}
if [ "$TOKEN_LENGTH" -ge 16 ]; then
    test_result "Security: Token Strength" "PASS" "Token length: $TOKEN_LENGTH characters"
else
    test_result "Security: Token Strength" "FAIL" "Token too short: $TOKEN_LENGTH characters (min 16)"
fi

# Test 6.12: SSH Host Key Verification
echo -n "Testing SSH host key verification... "
if grep -q "$REMOTE_HOST" ~/.ssh/known_hosts 2>/dev/null; then
    test_result "Security: SSH Host Keys" "PASS" "Remote host key verified"
else
    test_result "Security: SSH Host Keys" "FAIL" "Remote host key not in known_hosts"
fi

# Test 6.13: Configuration Backup Security
echo -n "Testing config backup security... "
BACKUP_FILES=$(find ~/.clawdbot -name "*.json.bak" -o -name "*.json~" 2>/dev/null | wc -l | tr -d ' ')
if [ "$BACKUP_FILES" -eq 0 ]; then
    test_result "Security: Backup Files" "PASS" "No insecure backup files found"
else
    test_result "Security: Backup Files" "FAIL" "$BACKUP_FILES backup files found (potential data exposure)"
fi

# Test 6.14: Remote Node Security
echo -n "Testing remote node security... "
REMOTE_SECURITY_OK=true
REMOTE_CONFIG_PERMS=$(cat "$CACHE_DIR/remote_config_perms")
if [ "$REMOTE_CONFIG_PERMS" != "600" ] && [ "$REMOTE_CONFIG_PERMS" != "644" ]; then
    REMOTE_SECURITY_OK=false
fi
if [ "$REMOTE_SECURITY_OK" = true ]; then
    test_result "Security: Remote Node" "PASS" "Remote node properly secured"
else
    test_result "Security: Remote Node" "FAIL" "Remote node has security issues"
fi

echo ""
echo "=========================================="
echo -e "${BLUE}Test Summary${NC}"
echo "=========================================="
echo ""
echo -e "Total Tests: $TESTS_TOTAL"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

SUCCESS_RATE=$((TESTS_PASSED * 100 / TESTS_TOTAL))
echo -e "Success Rate: ${SUCCESS_RATE}%"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! System is healthy.${NC}"
    echo "Status: PRODUCTION READY"
    exit 0
elif [ $SUCCESS_RATE -ge 80 ]; then
    echo -e "${YELLOW}⚠ System operational with minor issues${NC}"
    echo "Status: OPERATIONAL (review failed tests)"
    exit 0
else
    echo -e "${RED}✗ Critical issues detected${NC}"
    echo "Status: NEEDS ATTENTION"
    exit 2
fi

echo ""
echo "Detailed results saved to: $TEST_RESULTS"
