#!/bin/bash
# Token Configuration Validator
# Checks all token locations for consistency and reports mismatches

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

# Results
ERRORS=0
WARNINGS=0
LOCATIONS=()
TOKENS=()

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Token Configuration Validator${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

check_location() {
    local location="$1"
    local token="$2"
    local status="$3"
    
    LOCATIONS+=("$location")
    TOKENS+=("$token")
    
    if [ "$status" = "ok" ]; then
        echo -e "  ${GREEN}✅${NC} $location"
        echo -e "     Token: ${token:0:12}..."
    elif [ "$status" = "warn" ]; then
        echo -e "  ${YELLOW}⚠️${NC}  $location"
        echo -e "     Token: ${token:0:12}..."
        ((WARNINGS++))
    else
        echo -e "  ${RED}❌${NC} $location"
        echo -e "     Error: $token"
        ((ERRORS++))
    fi
}

echo ""
print_header

echo -e "${BLUE}➤ Checking Token Locations${NC}\n"

# 1. Check .env file
if [ -f "$ENV_FILE" ]; then
    TOKEN=$(grep "^CLAWDBOT_GATEWAY_TOKEN=" "$ENV_FILE" 2>/dev/null | cut -d= -f2 || true)
    if [ -n "$TOKEN" ]; then
        check_location ".env file" "$TOKEN" "ok"
    else
        check_location ".env file" "Token not set or empty" "error"
    fi
else
    check_location ".env file" "File not found" "error"
fi

# 2. Check environment variable
if [ -n "${CLAWDBOT_GATEWAY_TOKEN:-}" ]; then
    check_location "Environment variable (CLAWDBOT_GATEWAY_TOKEN)" "$CLAWDBOT_GATEWAY_TOKEN" "ok"
else
    check_location "Environment variable" "Not set" "warn"
fi

# 3. Check main gateway config
GATEWAY_CONFIG="$HOME/.clawdbot/clawdbot.json"
if [ -f "$GATEWAY_CONFIG" ]; then
    # Try to extract token if it exists in config
    TOKEN=$(python3 -c "import json; f=open('$GATEWAY_CONFIG'); d=json.load(f); print(d.get('gateway',{}).get('token',''))" 2>/dev/null || echo "")
    if [ -n "$TOKEN" ]; then
        check_location "Gateway config (~/.clawdbot/clawdbot.json)" "$TOKEN" "ok"
    else
        check_location "Gateway config (~/.clawdbot/clawdbot.json)" "Token not in config (may be in env)" "warn"
    fi
else
    check_location "Gateway config" "File not found" "warn"
fi

# 4. Check LaunchAgent (if exists)
GATEWAY_PLIST="$HOME/Library/LaunchAgents/com.clawdbot.gateway.plist"
if [ -f "$GATEWAY_PLIST" ]; then
    TOKEN=$(plutil -extract EnvironmentVariables.CLAWDBOT_GATEWAY_TOKEN raw "$GATEWAY_PLIST" 2>/dev/null || echo "")
    if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
        check_location "Gateway LaunchAgent (com.clawdbot.gateway.plist)" "$TOKEN" "warn"
        echo -e "     ${YELLOW}NOTE: Hardcoded token in LaunchAgent can override config${NC}"
    else
        check_location "Gateway LaunchAgent" "No hardcoded token (good)" "ok"
    fi
else
    check_location "Gateway LaunchAgent" "Not installed" "warn"
fi

# 5. Check Docker Compose files
COMPOSE_SECURE="$PROJECT_ROOT/config/docker-compose.secure.yml"
if [ -f "$COMPOSE_SECURE" ]; then
    if grep -q "CLAWDBOT_GATEWAY_TOKEN" "$COMPOSE_SECURE"; then
        TOKEN_REF=$(grep "CLAWDBOT_GATEWAY_TOKEN" "$COMPOSE_SECURE" | head -1)
        check_location "Docker Compose (config/docker-compose.secure.yml)" "Uses env var reference" "ok"
    else
        check_location "Docker Compose" "Token reference not found" "warn"
    fi
fi

# 6. Check for running Docker containers with old tokens
if command -v docker &> /dev/null; then
    RUNNING_CONTAINERS=$(docker ps --filter "name=clawdbot" --format "{{.Names}}" 2>/dev/null || true)
    if [ -n "$RUNNING_CONTAINERS" ]; then
        for container in $RUNNING_CONTAINERS; do
            TOKEN=$(docker inspect "$container" -f '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep "^CLAWDBOT_GATEWAY_TOKEN=" | cut -d= -f2 || echo "")
            if [ -n "$TOKEN" ]; then
                check_location "Docker container ($container)" "$TOKEN" "warn"
            fi
        done
    fi
fi

echo ""
echo -e "${BLUE}➤ Token Consistency Check${NC}\n"

# Extract unique tokens (excluding empty/error messages)
UNIQUE_TOKENS=$(printf '%s\n' "${TOKENS[@]}" | grep -v "^$\|not found\|Not set\|Error\|null\|Uses env" | sort -u || true)
TOKEN_COUNT=$(echo "$UNIQUE_TOKENS" | grep -v "^$" | wc -l | tr -d ' ')

if [ "$TOKEN_COUNT" -eq 0 ]; then
    echo -e "  ${RED}❌ No valid tokens found${NC}"
    ((ERRORS++))
elif [ "$TOKEN_COUNT" -eq 1 ]; then
    echo -e "  ${GREEN}✅ All tokens are consistent${NC}"
    echo -e "     Token prefix: ${UNIQUE_TOKENS:0:12}..."
else
    echo -e "  ${RED}❌ Multiple different tokens found!${NC}"
    echo -e "     Found $TOKEN_COUNT different tokens:"
    while IFS= read -r token; do
        if [ -n "$token" ]; then
            echo -e "       - ${token:0:12}..."
            # Show which locations use this token
            for i in "${!TOKENS[@]}"; do
                if [[ "${TOKENS[$i]}" == "$token" ]]; then
                    echo -e "         └─ ${LOCATIONS[$i]}"
                fi
            done
        fi
    done <<< "$UNIQUE_TOKENS"
    ((ERRORS++))
fi

echo ""
echo -e "${BLUE}➤ Security Checks${NC}\n"

# Check for weak default tokens
for token in "${TOKENS[@]}"; do
    if [[ "$token" == "clawdbot-local-dev" ]]; then
        echo -e "  ${RED}❌ Insecure default token detected: 'clawdbot-local-dev'${NC}"
        echo -e "     ${YELLOW}This should only be used in local development${NC}"
        echo -e "     Generate a secure token: openssl rand -hex 32"
        ((ERRORS++))
        break
    fi
done

# Check token strength
for token in "${TOKENS[@]}"; do
    if [ -n "$token" ] && [ "$token" != "Not set" ] && [ "$token" != "null" ]; then
        if [ ${#token} -lt 32 ]; then
            echo -e "  ${YELLOW}⚠️${NC}  Token length is short (${#token} chars)"
            echo -e "     Recommended: At least 32 characters"
            ((WARNINGS++))
        else
            echo -e "  ${GREEN}✅${NC} Token length is adequate (${#token} chars)"
        fi
        break
    fi
done

# Check if tokens are in version control
if [ -f "$ENV_FILE" ] && [ -d "$PROJECT_ROOT/.git" ]; then
    if git ls-files --error-unmatch "$ENV_FILE" &>/dev/null; then
        echo -e "  ${RED}❌ .env file is tracked in git!${NC}"
        echo -e "     Run: git rm --cached .env"
        ((ERRORS++))
    else
        echo -e "  ${GREEN}✅${NC} .env file is not in version control"
    fi
fi

# Summary
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "  ${GREEN}✅ All checks passed!${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "  ${YELLOW}⚠️  $WARNINGS warning(s) found${NC}"
    echo -e "     The system will work, but could be improved"
    exit 0
else
    echo -e "  ${RED}❌ $ERRORS error(s) and $WARNINGS warning(s) found${NC}"
    echo -e "     Configuration issues detected that may cause failures"
    echo ""
    echo -e "${YELLOW}Recommended Actions:${NC}"
    echo -e "  1. Ensure all tokens match (use the one in .env as source of truth)"
    echo -e "  2. Remove hardcoded tokens from LaunchAgent plists"
    echo -e "  3. Stop any Docker containers with old tokens"
    echo -e "  4. Generate a strong token if using 'clawdbot-local-dev'"
    echo ""
    echo -e "To generate a secure token:"
    echo -e "  ${BLUE}openssl rand -hex 32${NC}"
    echo ""
    exit 1
fi
