#!/bin/bash
set -euo pipefail

# Clawdbot Secure Docker Deployment Script
# Version: 1.2.0

# shellcheck source=lib/common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    source "$SCRIPT_DIR/lib/common.sh"
else
    # Fallback if common.sh not found
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
fi

# Script-specific functions (extend common.sh)
print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

# Check prerequisites
check_prereqs() {
    print_header "Checking Prerequisites"
    
    # Check Docker
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running"
        echo "Please start Docker Desktop and try again"
        exit 1
    fi
    print_success "Docker is running"
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_error "Do not run this script as root"
        exit 1
    fi
    print_success "Not running as root"
    
    # Check for docker compose
    if ! docker compose version > /dev/null 2>&1; then
        print_error "Docker Compose not available"
        exit 1
    fi
    print_success "Docker Compose available"
    
    # Check for claude CLI (optional)
    if command -v claude &> /dev/null; then
        print_success "Claude CLI available"
        CLAUDE_CLI_AVAILABLE=true
    else
        print_warning "Claude CLI not found (API key auth will be used)"
        CLAUDE_CLI_AVAILABLE=false
    fi
}

# Set UID/GID for containers
setup_env() {
    print_header "Setting Up Environment"

    USER_UID=$(id -u)
    USER_GID=$(id -g)
    export USER_UID
    export USER_GID

    # Check for 1Password CLI
    if command -v op &> /dev/null && op account get &> /dev/null 2>&1; then
        print_info "1Password CLI detected, fetching secrets..."
        ANTHROPIC_API_KEY=$(op read "op://Developer/Anthropic Claude/API Key" 2>/dev/null || echo "")
        if [ -n "$ANTHROPIC_API_KEY" ]; then
            print_success "Anthropic API key loaded from 1Password"
        else
            print_warning "Could not fetch Anthropic API key from 1Password"
            print_info "Ensure item exists: op://Developer/Anthropic Claude/API Key"
        fi
    else
        print_warning "1Password CLI not available or not signed in"
        print_info "To use 1Password: eval \$(op signin)"
    fi

    # macOS-specific paths
    APPLE_NOTES_PATH="$HOME/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite"
    CODEX_PATH="$HOME/.codex"

    # SECURITY: Generate a strong random gateway token if not already set
    if [ -f .env ] && grep -q "^CLAWDBOT_GATEWAY_TOKEN=" .env; then
        GATEWAY_TOKEN=$(grep "^CLAWDBOT_GATEWAY_TOKEN=" .env | cut -d= -f2)
        print_info "Using existing gateway token from .env"
    else
        # Generate 32-byte random token (base64 encoded, URL-safe)
        GATEWAY_TOKEN=$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '=')
        print_success "Generated strong gateway token"
    fi

    # SECURITY: Use pinned version (check for updates at npm view clawdbot versions)
    CLAWDBOT_VERSION="${CLAWDBOT_VERSION:-2026.1.23-1}"

    # Create .env file
    cat > .env << EOF
USER_UID=${USER_UID}
USER_GID=${USER_GID}
CLAWDBOT_VERSION=${CLAWDBOT_VERSION}
NODE_ENV=production
CLAWDBOT_PORT=18789
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
CLAWDBOT_GATEWAY_TOKEN=${GATEWAY_TOKEN}
APPLE_NOTES_PATH=${APPLE_NOTES_PATH}
CODEX_PATH=${CODEX_PATH}
EOF

    # Secure the .env file
    chmod 600 .env

    print_success "Environment configured (UID:GID = ${USER_UID}:${USER_GID})"
}

# Build images
build_images() {
    print_header "Building Secure Clawdbot Images"

    # Use cache for faster iterative builds; pass --no-cache manually if needed
    print_info "Building with security hardening..."
    if docker compose --env-file .env -f config/docker-compose.secure.yml build; then
        print_success "Images built successfully"
    else
        print_error "Image build failed"
        exit 1
    fi
}

# Create volumes and fix permissions
create_volumes() {
    print_header "Creating Docker Volumes"
    
    docker volume create config_clawdbot-config 2>/dev/null || true
    docker volume create config_clawdbot-logs 2>/dev/null || true
    
    print_info "Fixing volume permissions and clearing stale locks..."
    # We use a temporary container to fix permissions from the outside
    # This avoids EACCES errors when the container starts
    docker run --rm \
        -v config_clawdbot-config:/data \
        alpine sh -c "chown -R 1000:1000 /data && chmod -R 755 /data && rm -f /data/*.lock"
    
    print_success "Volumes ready and permissions fixed"
}

# Configure authentication
setup_auth() {
    print_header "Setting Up Authentication"
    
    echo "Choose authentication method:"
    echo "  1) Claude Code setup-token (requires Claude subscription)"
    echo "  2) Anthropic API key (pay-per-use)"
    echo ""
    read -rp "Enter choice (1 or 2): " AUTH_CHOICE
    echo ""
    
    if [ "$AUTH_CHOICE" = "1" ]; then
        if [ "$CLAUDE_CLI_AVAILABLE" = true ]; then
            print_info "Generating setup-token..."
            echo "Run this command to get your token:"
            echo -e "${YELLOW}  claude setup-token${NC}"
            echo ""
            read -rp "Press Enter when ready to paste token..."
            echo ""
            read -rsp "Paste setup-token: " SETUP_TOKEN
            echo ""

            # SECURITY: Pass token via environment variable instead of temp file
            # This avoids writing secrets to disk
            print_info "Running onboarding with setup-token..."
            if ! docker compose --env-file .env -f config/docker-compose.secure.yml run --rm \
                -e CLAWDBOT_SETUP_TOKEN="$SETUP_TOKEN" \
                clawdbot-cli sh -c 'clawdbot onboard --non-interactive || clawdbot setup'; then
                print_warning "Onboarding returned non-zero exit code (may be normal for first run)"
            fi

            # Clear the variable from memory
            unset SETUP_TOKEN
        else
            print_error "Claude CLI not available for setup-token method"
            print_info "Please install Claude CLI or use API key (option 2)"
            exit 1
        fi
            
    elif [ "$AUTH_CHOICE" = "2" ]; then
        # Try to get API key from 1Password first
        API_KEY=""
        if command -v op &> /dev/null && op account get &> /dev/null 2>&1; then
            print_info "Checking 1Password for Anthropic API key..."
            API_KEY=$(op read "op://Developer/Anthropic Claude/API Key" 2>/dev/null || echo "")
            if [ -n "$API_KEY" ]; then
                print_success "API key loaded from 1Password"
            fi
        fi

        # If not found in 1Password, prompt user
        if [ -z "$API_KEY" ]; then
            print_info "Get your API key from: https://console.anthropic.com/settings/keys"
            echo ""
            read -rsp "Paste Anthropic API key: " API_KEY
            echo ""
        fi

        # SECURITY: Update .env file with API key using temp file swap (no .bak exposure)
        if grep -q "^ANTHROPIC_API_KEY=" .env 2>/dev/null; then
            # Use awk to avoid sed backup file that could expose secrets
            awk -v key="$API_KEY" '/^ANTHROPIC_API_KEY=/{$0="ANTHROPIC_API_KEY="key}1' .env > .env.tmp
            chmod 600 .env.tmp
            mv .env.tmp .env
        else
            echo "ANTHROPIC_API_KEY=${API_KEY}" >> .env
        fi

        # SECURITY: Pass API key via --env-file to avoid exposure in process list
        print_info "Running onboarding with API key..."
        if ! docker compose --env-file .env -f config/docker-compose.secure.yml run --rm \
            --env-file .env \
            clawdbot-cli sh -c 'clawdbot onboard --non-interactive || clawdbot setup'; then
            print_warning "Onboarding returned non-zero exit code (may be normal for first run)"
        fi

        # Clear the variable from memory
        unset API_KEY
    else
        print_error "Invalid choice"
        exit 1
    fi
    
    print_success "Authentication configured"
}

# Start gateway
start_gateway() {
    print_header "Starting Clawdbot Gateway"
    
    print_info "Starting gateway with security hardening..."
    if docker compose --env-file .env -f config/docker-compose.secure.yml up -d clawdbot-gateway; then
        print_success "Gateway started"
    else
        print_error "Gateway failed to start"
        print_info "Check logs with: docker compose --env-file .env -f config/docker-compose.secure.yml logs"
        exit 1
    fi
}

# Wait for health check with exponential backoff
wait_for_health() {
    print_header "Waiting for Gateway Health Check"

    print_info "Waiting for gateway to become healthy (exponential backoff)..."

    local delay=2
    local max_delay=15
    local total_wait=0
    local max_wait=90
    local attempt=1

    while [ $total_wait -lt $max_wait ]; do
        sleep "$delay"
        total_wait=$((total_wait + delay))

        STATUS=$(docker inspect clawdbot-gateway-secure --format='{{.State.Health.Status}}' 2>/dev/null || echo "starting")
        echo "  Attempt $attempt (${total_wait}s): $STATUS"

        if [ "$STATUS" = "healthy" ]; then
            print_success "Gateway is healthy"
            return 0
        fi

        # Exponential backoff: 2s -> 4s -> 8s -> 15s (capped)
        delay=$((delay * 2))
        [ $delay -gt $max_delay ] && delay=$max_delay
        attempt=$((attempt + 1))
    done

    print_warning "Health check timeout (gateway may still be starting)"
    print_info "Check status with: docker compose --env-file .env -f config/docker-compose.secure.yml ps"
}

# Final verification
verify_deployment() {
    print_header "Verifying Deployment"

    # Check container is running
    if docker compose --env-file .env -f config/docker-compose.secure.yml ps | grep -q "clawdbot-gateway.*Up"; then
        print_success "Gateway container running"
    else
        print_error "Gateway container not running"
        return 1
    fi

    # Cross-platform port check (works on macOS and Linux)
    if command -v lsof &>/dev/null && lsof -i :18789 -sTCP:LISTEN &>/dev/null; then
        print_success "Gateway listening on localhost:18789"
    elif command -v ss &>/dev/null && ss -tln | grep -q ":18789 "; then
        print_success "Gateway listening on localhost:18789"
    else
        print_warning "Port check inconclusive (install lsof or ss for verification)"
    fi

    # Check security settings in single docker inspect call for performance
    print_info "Verifying security settings..."

    INSPECT_DATA=$(docker inspect clawdbot-gateway-secure 2>/dev/null)
    if [ -z "$INSPECT_DATA" ]; then
        print_warning "Could not inspect container"
        return 1
    fi

    # Use here-strings to avoid subshell overhead from echo | jq
    RO_FS=$(jq -r '.[0].HostConfig.ReadonlyRootfs' <<< "$INSPECT_DATA")
    USER_ID=$(jq -r '.[0].Config.User' <<< "$INSPECT_DATA")

    if [ "$RO_FS" = "true" ]; then
        print_success "Read-only filesystem active"
    else
        print_warning "Read-only filesystem not active"
    fi

    if [ "$USER_ID" != "0:0" ] && [ "$USER_ID" != "" ]; then
        print_success "Running as non-root user ($USER_ID)"
    else
        print_warning "User check inconclusive"
    fi
}

# Main deployment flow
main() {
    clear
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║     Clawdbot Secure Docker Deployment v1.1.0              ║"
    echo "║     Enterprise-Grade Security Hardening                   ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    check_prereqs
    setup_env
    build_images
    create_volumes
    setup_auth
    start_gateway
    wait_for_health
    verify_deployment
    
    print_header "Deployment Complete!"
    
    echo -e "${GREEN}✅ Clawdbot is now running with enterprise security!${NC}"
    echo ""
    echo "📊 Deployment Information:"
    echo "  Gateway URL: http://localhost:18789"
    echo "  Container: clawdbot-gateway-secure"
    echo "  Config: Docker volume 'clawdbot-config'"
    echo ""
    echo "🔧 Management Commands:"
    echo "  View logs:    docker compose --env-file .env -f config/docker-compose.secure.yml logs -f"
    echo "  Stop:         docker compose --env-file .env -f config/docker-compose.secure.yml down"
    echo "  Restart:      docker compose --env-file .env -f config/docker-compose.secure.yml restart"
    echo "  CLI:          docker compose --env-file .env -f config/docker-compose.secure.yml run --rm clawdbot-cli"
    echo "  Verify:       ./scripts/verify-security.sh"
    echo ""
    echo "📚 Documentation: docs/SECURE_DEPLOYMENT.md"
    echo ""
}

# Run main function
main
