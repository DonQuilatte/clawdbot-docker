#!/bin/bash
# Install OrbStack on Remote Mac
# Optional: Enables Docker containers on the remote Mac

set -e

# shellcheck source=lib/common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

echo "🐳 OrbStack Installation for Remote Mac"
echo "========================================"
echo ""

# Load configuration
load_env

# Configuration from environment (no hardcoded values)
: "${REMOTE_HOST:?Set REMOTE_HOST in .env or environment}"
: "${REMOTE_USER:?Set REMOTE_USER in .env or environment}"

# Check prerequisites
check_prereqs() {
    print_step "Checking prerequisites..."

    # Test SSH connection
    if ! ssh_check "${REMOTE_USER}@${REMOTE_HOST}"; then
        print_error "Cannot SSH to ${REMOTE_USER}@${REMOTE_HOST}"
        exit 1
    fi
    print_success "SSH connection verified"

    # Check if Homebrew is installed on remote
    if ! ssh_cmd "${REMOTE_USER}@${REMOTE_HOST}" 'command -v brew' &>/dev/null; then
        print_error "Homebrew not installed on remote Mac"
        echo "    Install Homebrew first:"
        echo "    ssh ${REMOTE_USER}@${REMOTE_HOST}"
        echo "    /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    print_success "Homebrew available"

    # Check if OrbStack is already installed
    if ssh_cmd "${REMOTE_USER}@${REMOTE_HOST}" 'command -v orb' &>/dev/null; then
        print_warning "OrbStack is already installed"
        echo ""
        echo "Current OrbStack status:"
        ssh_cmd "${REMOTE_USER}@${REMOTE_HOST}" 'orb status 2>/dev/null || echo "  (not running)"'
        echo ""
        read -rp "Reinstall/update OrbStack? (y/N) " -n 1 REPLY
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Exiting."
            exit 0
        fi
    fi

    echo ""
}

# Install OrbStack
install_orbstack() {
    print_step "Installing OrbStack on remote Mac..."
    echo ""

    ssh_cmd "${REMOTE_USER}@${REMOTE_HOST}" << 'ENDSSH'
echo "Installing OrbStack via Homebrew..."
brew install --cask orbstack

echo ""
echo "Waiting for installation to complete..."
sleep 5

# Check if installed
if command -v orb &> /dev/null; then
    echo "✓ OrbStack CLI installed"
else
    echo "✓ OrbStack installed (CLI may require app launch)"
fi

# Check for docker command
if command -v docker &> /dev/null; then
    echo "✓ Docker command available"
else
    echo "Note: Docker command will be available after OrbStack first launch"
fi
ENDSSH

    print_success "OrbStack installed"
}

# Start OrbStack
start_orbstack() {
    print_step "Starting OrbStack..."

    ssh_cmd "${REMOTE_USER}@${REMOTE_HOST}" << 'ENDSSH'
# Open OrbStack app
open -a OrbStack 2>/dev/null || echo "Note: OrbStack may need manual first launch"

# Wait for startup
echo "Waiting for OrbStack to start..."
sleep 10

# Check status
if command -v orb &> /dev/null; then
    orb status 2>/dev/null || echo "OrbStack starting..."
fi

# Verify docker is working
if docker info > /dev/null 2>&1; then
    echo "✓ Docker daemon running"
    docker version --format 'Docker version: {{.Server.Version}}'
else
    echo "Note: Docker may need OrbStack to complete startup"
fi
ENDSSH
}

# Verify installation
verify_installation() {
    print_step "Verifying installation..."
    echo ""

    # Batch verification in single SSH call
    local verify_result
    verify_result=$(ssh_cmd "${REMOTE_USER}@${REMOTE_HOST}" 'bash -s' 2>/dev/null <<'ENDSSH' || echo "SSH_FAILED"
echo "=== OrbStack Status ==="
orb status 2>/dev/null || echo "Not running (may need manual start)"
echo ""

echo "=== Docker Version ==="
DOCKER_VERSION=$(docker version --format "{{.Server.Version}}" 2>/dev/null || echo "not running")
echo "VERSION=$DOCKER_VERSION"

if [ "$DOCKER_VERSION" != "not running" ]; then
    echo ""
    echo "=== Docker Test ==="
    docker run --rm hello-world 2>&1 | grep -c "Hello from Docker" || echo "0"
fi
ENDSSH
)

    echo "$verify_result"

    # Extract docker version for status
    local docker_version
    docker_version=$(echo "$verify_result" | grep "^VERSION=" | cut -d= -f2)

    echo ""
    if [ "$docker_version" != "not running" ] && [ -n "$docker_version" ]; then
        print_success "Docker version: $docker_version"
    else
        print_warning "Docker not responding (start OrbStack first)"
    fi
}

# Show summary
show_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_success "OrbStack Installation Complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📦 What's installed:"
    echo "   - OrbStack (Docker/Linux VM manager)"
    echo "   - Docker CLI"
    echo "   - Docker Compose"
    echo ""
    echo "🔧 Commands available on remote Mac:"
    echo "   docker ps              - List containers"
    echo "   docker images          - List images"
    echo "   docker-compose up -d   - Start compose services"
    echo "   orb status             - OrbStack status"
    echo ""
    echo "🚀 First-time setup (if needed):"
    echo "   1. SSH to remote: ssh ${REMOTE_USER}@${REMOTE_HOST}"
    echo "   2. Open OrbStack: open -a OrbStack"
    echo "   3. Complete setup wizard in GUI"
    echo ""
    echo "💡 Tips:"
    echo "   - OrbStack uses less resources than Docker Desktop"
    echo "   - Supports both Docker and Linux VMs"
    echo "   - Integrates with macOS keychain for auth"
    echo ""
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Installs OrbStack (Docker manager) on remote Mac."
    echo ""
    echo "Options:"
    echo "  --check-only    Only check current status, don't install"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Required environment variables (set in .env):"
    echo "  REMOTE_HOST     IP address of remote Mac"
    echo "  REMOTE_USER     Username on remote Mac"
    echo ""
    echo "Note: OrbStack is OPTIONAL. The remote node works"
    echo "without Docker for basic Clawdbot functionality."
    exit 0
}

# Main execution
main() {
    echo "This script will install OrbStack on the remote Mac."
    echo "OrbStack provides Docker and Linux VM support."
    echo ""
    echo "Target: ${REMOTE_USER}@${REMOTE_HOST}"
    echo ""

    read -rp "Continue with installation? (y/N) " -n 1 REPLY
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    echo ""

    check_prereqs
    install_orbstack
    start_orbstack
    verify_installation
    show_summary
}

# Handle arguments
case "${1:-}" in
    --help|-h)
        show_help
        ;;
    --check-only)
        check_prereqs
        verify_installation
        exit 0
        ;;
    *)
        main
        ;;
esac
