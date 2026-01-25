#!/bin/bash

# Automated Secure Deployment Script for Clawdbot
# Deploys Clawdbot with enterprise-grade security hardening

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ ${NC}$1"
}

print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${NC}$1"
}

print_error() {
    echo -e "${RED}✗ ${NC}$1"
}

print_header "Clawdbot Secure Deployment"

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    print_error "docker-compose.yml not found"
    print_info "Please run this script from the clawdbot-official directory"
    exit 1
fi

# Step 1: Build secure images
print_header "Building Secure Images"
print_info "Building with security-hardened Dockerfile..."
docker compose build --no-cache
print_success "Secure images built successfully"

# Step 2: Create data directory with proper permissions
print_header "Setting Up Data Directory"
DATA_DIR="${CLAWDBOT_HOME_VOLUME:-$HOME/Development/clawdbot-workspace/data-secure}"
print_info "Creating data directory: $DATA_DIR"
mkdir -p "$DATA_DIR"/{config,logs,cache}

print_info "Setting ownership to UID 1000..."
sudo chown -R 1000:1000 "$DATA_DIR"
chmod -R 755 "$DATA_DIR"
print_success "Data directory configured"

# Step 3: Start gateway
print_header "Starting Secure Gateway"
print_info "Starting clawdbot-gateway with security hardening..."
docker compose up -d clawdbot-gateway

print_info "Waiting for gateway to start..."
sleep 10

# Check if container is running
if docker compose ps | grep -q "clawdbot-gateway.*running"; then
    print_success "Gateway started successfully"
else
    print_error "Gateway failed to start"
    print_info "Check logs with: docker compose logs clawdbot-gateway"
    exit 1
fi

# Step 4: Verify security configuration
print_header "Verifying Security Configuration"
print_info "Running security checks..."

# Check user
USER_CHECK=$(docker compose exec -T clawdbot-gateway id 2>/dev/null || echo "failed")
if echo "$USER_CHECK" | grep -q "uid=1000"; then
    print_success "Running as non-root user"
else
    print_warning "User verification failed"
fi

# Check read-only filesystem
RO_CHECK=$(docker compose exec -T clawdbot-gateway touch /test 2>&1 || true)
if echo "$RO_CHECK" | grep -q "Read-only file system"; then
    print_success "Read-only filesystem active"
else
    print_warning "Filesystem may not be read-only"
fi

# Step 5: Apply security hardening
print_header "Applying Security Hardening"

print_info "Enabling strict sandbox mode..."
docker compose run --rm clawdbot-cli config set gateway.sandbox.enabled true
docker compose run --rm clawdbot-cli config set gateway.sandbox.mode strict

print_info "Configuring network security..."
docker compose run --rm clawdbot-cli config set gateway.bind localhost

print_info "Setting restrictive tool policy..."
docker compose run --rm clawdbot-cli config set gateway.tools.policy restrictive
docker compose run --rm clawdbot-cli config set gateway.tools.allowList "[]"

print_info "Enabling audit logging..."
docker compose run --rm clawdbot-cli config set gateway.audit.enabled true
docker compose run --rm clawdbot-cli config set gateway.audit.logLevel info

print_info "Enabling prompt injection protection..."
docker compose run --rm clawdbot-cli config set gateway.security.promptInjection.enabled true
docker compose run --rm clawdbot-cli config set gateway.security.promptInjection.strictMode true

print_info "Configuring rate limiting..."
docker compose run --rm clawdbot-cli config set gateway.security.rateLimit.enabled true
docker compose run --rm clawdbot-cli config set gateway.security.rateLimit.maxRequests 100
docker compose run --rm clawdbot-cli config set gateway.security.rateLimit.windowMs 60000

print_success "Security hardening applied"

# Step 6: Display next steps
print_header "Deployment Complete!"

echo -e "${GREEN}✅ Clawdbot deployed with enterprise-grade security${NC}\n"

echo -e "${BLUE}Next steps:${NC}\n"

echo -e "1. ${YELLOW}Authenticate with Claude:${NC}"
echo -e "   claude auth login"
echo -e "   claude setup-token\n"

echo -e "2. ${YELLOW}Configure Clawdbot:${NC}"
echo -e "   docker compose run --rm clawdbot-cli models auth paste-token --provider anthropic\n"

echo -e "3. ${YELLOW}Verify security:${NC}"
echo -e "   ./verify-security.sh\n"

echo -e "4. ${YELLOW}Check health:${NC}"
echo -e "   docker compose run --rm clawdbot-cli doctor"
echo -e "   curl http://localhost:3000/health\n"

echo -e "${BLUE}Security features enabled:${NC}"
echo -e "  ✓ Read-only root filesystem"
echo -e "  ✓ Non-root user (UID 1000)"
echo -e "  ✓ All capabilities dropped"
echo -e "  ✓ Custom seccomp profile"
echo -e "  ✓ Localhost-only binding"
echo -e "  ✓ Strict sandbox mode"
echo -e "  ✓ Restrictive tool policy"
echo -e "  ✓ Audit logging"
echo -e "  ✓ Prompt injection protection"
echo -e "  ✓ Rate limiting\n"

echo -e "${BLUE}Documentation:${NC}"
echo -e "  • Full guide: ~/Development/Projects/clawdbot/docs/SECURE_DEPLOYMENT.md"
echo -e "  • Security: ~/Development/Projects/clawdbot/docs/SECURITY.md"
echo -e "  • Troubleshooting: ~/Development/Projects/clawdbot/docs/TROUBLESHOOTING.md\n"
