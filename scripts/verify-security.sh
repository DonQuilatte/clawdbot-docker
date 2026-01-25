#!/bin/bash

# Security Verification Script for Clawdbot
# Verifies all security settings after deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

check_pass() {
    echo -e "${GREEN}✅ $1${NC}"
    ((CHECKS_PASSED++))
}

check_fail() {
    echo -e "${RED}❌ $1${NC}"
    ((CHECKS_FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((CHECKS_WARNING++))
}

print_header "Clawdbot Security Configuration Verification"

# Check if container is running
if ! docker compose ps | grep -q "clawdbot-gateway.*running"; then
    check_fail "Gateway container is not running"
    echo -e "\n${RED}Cannot verify security - container not running${NC}"
    exit 1
fi

# 1. Check user
print_header "User Configuration"
USER_CHECK=$(docker compose exec -T clawdbot-gateway id 2>/dev/null || echo "failed")
if echo "$USER_CHECK" | grep -q "uid=1000"; then
    check_pass "Running as non-root user (UID 1000)"
elif echo "$USER_CHECK" | grep -q "uid=0"; then
    check_fail "Running as root (SECURITY RISK)"
else
    check_warn "Could not verify user"
fi

# 2. Check read-only filesystem
print_header "Filesystem Security"
RO_CHECK=$(docker compose exec -T clawdbot-gateway touch /test 2>&1 || true)
if echo "$RO_CHECK" | grep -q "Read-only file system"; then
    check_pass "Root filesystem is read-only"
else
    check_fail "Root filesystem is writable (SECURITY RISK)"
fi

# 3. Check capabilities
print_header "Linux Capabilities"
CAP_CHECK=$(docker inspect clawdbot-gateway-secure 2>/dev/null | grep -A 5 "CapDrop" || echo "")
if echo "$CAP_CHECK" | grep -q "ALL"; then
    check_pass "All capabilities dropped"
else
    check_warn "Not all capabilities dropped"
fi

# 4. Check no-new-privileges
print_header "Privilege Escalation Protection"
PRIV_CHECK=$(docker inspect clawdbot-gateway-secure 2>/dev/null | grep "no-new-privileges" || echo "")
if echo "$PRIV_CHECK" | grep -q "no-new-privileges:true"; then
    check_pass "No new privileges flag set"
else
    check_fail "No new privileges not set (SECURITY RISK)"
fi

# 5. Check seccomp profile
print_header "Seccomp Profile"
SECCOMP_CHECK=$(docker inspect clawdbot-gateway-secure 2>/dev/null | grep -i "seccomp" || echo "")
if echo "$SECCOMP_CHECK" | grep -q "seccomp"; then
    check_pass "Custom seccomp profile active"
else
    check_warn "Using default seccomp profile"
fi

# 6. Check network binding
print_header "Network Configuration"
PORT_CHECK=$(docker compose port clawdbot-gateway 3000 2>/dev/null || echo "")
if echo "$PORT_CHECK" | grep -q "127.0.0.1"; then
    check_pass "Localhost-only binding (127.0.0.1)"
elif echo "$PORT_CHECK" | grep -q "0.0.0.0"; then
    check_fail "Exposed to all interfaces (SECURITY RISK)"
else
    check_warn "Could not verify network binding"
fi

# 7. Check sandbox mode
print_header "Application Security Settings"
SANDBOX_CHECK=$(docker compose run --rm clawdbot-cli config get gateway.sandbox.enabled 2>/dev/null || echo "false")
if echo "$SANDBOX_CHECK" | grep -q "true"; then
    check_pass "Sandbox enabled"
    
    # Check sandbox mode
    SANDBOX_MODE=$(docker compose run --rm clawdbot-cli config get gateway.sandbox.mode 2>/dev/null || echo "")
    if echo "$SANDBOX_MODE" | grep -q "strict"; then
        check_pass "Sandbox mode: strict"
    else
        check_warn "Sandbox mode not set to strict"
    fi
else
    check_fail "Sandbox disabled (SECURITY RISK)"
fi

# 8. Check tool policy
TOOL_POLICY=$(docker compose run --rm clawdbot-cli config get gateway.tools.policy 2>/dev/null || echo "")
if echo "$TOOL_POLICY" | grep -q "restrictive"; then
    check_pass "Tool policy: restrictive"
else
    check_warn "Tool policy not set to restrictive"
fi

# 9. Check audit logging
AUDIT_CHECK=$(docker compose run --rm clawdbot-cli config get gateway.audit.enabled 2>/dev/null || echo "false")
if echo "$AUDIT_CHECK" | grep -q "true"; then
    check_pass "Audit logging enabled"
else
    check_warn "Audit logging disabled"
fi

# 10. Check prompt injection protection
INJECTION_CHECK=$(docker compose run --rm clawdbot-cli config get gateway.security.promptInjection.enabled 2>/dev/null || echo "false")
if echo "$INJECTION_CHECK" | grep -q "true"; then
    check_pass "Prompt injection protection enabled"
else
    check_warn "Prompt injection protection disabled"
fi

# 11. Check rate limiting
RATE_CHECK=$(docker compose run --rm clawdbot-cli config get gateway.security.rateLimit.enabled 2>/dev/null || echo "false")
if echo "$RATE_CHECK" | grep -q "true"; then
    check_pass "Rate limiting enabled"
else
    check_warn "Rate limiting disabled"
fi

# 12. Check resource limits
print_header "Resource Limits"
LIMITS_CHECK=$(docker inspect clawdbot-gateway-secure 2>/dev/null | grep -A 10 "NanoCpus\|Memory" || echo "")
if echo "$LIMITS_CHECK" | grep -q "NanoCpus"; then
    check_pass "CPU limits configured"
else
    check_warn "No CPU limits set"
fi

if echo "$LIMITS_CHECK" | grep -q "Memory"; then
    check_pass "Memory limits configured"
else
    check_warn "No memory limits set"
fi

# Summary
print_header "Security Verification Summary"

TOTAL_CHECKS=$((CHECKS_PASSED + CHECKS_FAILED + CHECKS_WARNING))

echo -e "${GREEN}Passed:   $CHECKS_PASSED${NC}"
echo -e "${YELLOW}Warnings: $CHECKS_WARNING${NC}"
echo -e "${RED}Failed:   $CHECKS_FAILED${NC}"
echo ""

# Security Score
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ $TOTAL_CHECKS -gt 0 ]; then
    SCORE_PERCENT=$((CHECKS_PASSED * 100 / TOTAL_CHECKS))
    echo -e "${BLUE}Security Score: $CHECKS_PASSED/$TOTAL_CHECKS checks passed ($SCORE_PERCENT%)${NC}"
    
    if [ $CHECKS_PASSED -eq $TOTAL_CHECKS ]; then
        echo -e "${GREEN}Status: ✅ SECURE (Perfect Score)${NC}"
    elif [ $CHECKS_PASSED -ge $((TOTAL_CHECKS * 3 / 4)) ]; then
        echo -e "${YELLOW}Status: ⚠️  NEEDS ATTENTION (Good, but improvable)${NC}"
    else
        echo -e "${RED}Status: ❌ INSECURE (Critical issues detected)${NC}"
    fi
else
    echo -e "${YELLOW}Status: ⚠️  Unable to calculate score${NC}"
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ Security verification passed!${NC}"
    echo -e "${GREEN}✅ Deployment meets security requirements${NC}\n"
    
    if [ $CHECKS_WARNING -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Some optional security features not enabled${NC}"
        echo -e "${YELLOW}⚠️  Review warnings above for recommendations${NC}\n"
    fi
    
    exit 0
else
    echo -e "${RED}❌ Security verification failed!${NC}"
    echo -e "${RED}❌ Critical security issues detected${NC}\n"
    
    echo -e "${BLUE}Recommended actions:${NC}"
    echo -e "1. Review failed checks above"
    echo -e "2. Apply security hardening from SECURE_DEPLOYMENT.md"
    echo -e "3. Re-run this verification script\n"
    
    exit 1
fi
