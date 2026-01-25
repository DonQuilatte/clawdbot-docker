#!/bin/bash

# Clawdbot Shell Aliases Installer
# This script adds helpful Clawdbot aliases to your shell configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

print_success() {
    echo -e "${GREEN}✓ ${NC}$1"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${NC}$1"
}

print_error() {
    echo -e "${RED}✗ ${NC}$1"
}

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Detect shell
detect_shell() {
    print_header "Detecting Shell Configuration"
    
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_CONFIG="$HOME/.zshrc"
        SHELL_NAME="zsh"
    elif [ -n "$BASH_VERSION" ]; then
        SHELL_CONFIG="$HOME/.bashrc"
        SHELL_NAME="bash"
    else
        print_warning "Could not detect shell type"
        print_info "Defaulting to .zshrc"
        SHELL_CONFIG="$HOME/.zshrc"
        SHELL_NAME="zsh"
    fi
    
    print_success "Detected shell: $SHELL_NAME"
    print_info "Config file: $SHELL_CONFIG"
}

# Check if aliases already exist
check_existing() {
    print_header "Checking for Existing Aliases"
    
    if grep -q "# Clawdbot aliases" "$SHELL_CONFIG" 2>/dev/null; then
        print_warning "Clawdbot aliases already exist in $SHELL_CONFIG"
        echo -n "Do you want to update them? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_info "Installation cancelled"
            exit 0
        fi
        
        # Remove old aliases
        print_info "Removing old aliases..."
        sed -i.bak '/# Clawdbot aliases/,/^$/d' "$SHELL_CONFIG"
        print_success "Old aliases removed"
    else
        print_info "No existing aliases found"
    fi
}

# Install aliases
install_aliases() {
    print_header "Installing Clawdbot Aliases"
    
    cat >> "$SHELL_CONFIG" << 'EOF'

# Clawdbot aliases
alias clawd-up='cd ~/Development/Projects/clawdbot && docker compose up -d clawdbot-gateway'
alias clawd-down='cd ~/Development/Projects/clawdbot && docker compose down'
alias clawd-restart='cd ~/Development/Projects/clawdbot && docker compose restart clawdbot-gateway'
alias clawd-logs='cd ~/Development/Projects/clawdbot && docker compose logs -f clawdbot-gateway'
alias clawd-status='cd ~/Development/Projects/clawdbot && docker compose ps'
alias clawd-doctor='cd ~/Development/Projects/clawdbot && docker compose run --rm clawdbot-cli doctor'
alias clawd-config='cd ~/Development/Projects/clawdbot && docker compose run --rm clawdbot-cli config list'
alias clawd-health='curl -s http://localhost:3000/health | jq'
alias clawd-update='cd ~/Development/Projects/clawdbot && docker compose pull && docker compose up -d clawdbot-gateway'
alias clawd-backup='cd ~/Development/Projects/clawdbot && docker compose run --rm clawdbot-cli config export > ~/clawdbot-backup-$(date +%Y%m%d).json'
alias clawd-secure-check='docker inspect clawdbot-gateway-secure 2>/dev/null | jq ".[0].HostConfig | {ReadonlyRootfs, Privileged, User, CapDrop, SecurityOpt}" || docker inspect clawdbot-gateway 2>/dev/null | jq ".[0].HostConfig | {ReadonlyRootfs, Privileged, User, CapDrop, SecurityOpt}"'

EOF
    
    print_success "Aliases added to $SHELL_CONFIG"
}

# Display installed aliases
display_aliases() {
    print_header "Installed Aliases"
    
    echo -e "${GREEN}The following aliases have been installed:${NC}\n"
    
    cat << 'EOF'
clawd-up        - Start the Clawdbot gateway
clawd-down      - Stop the Clawdbot gateway
clawd-restart   - Restart the Clawdbot gateway
clawd-logs      - View and follow gateway logs
clawd-status    - Check gateway status
clawd-doctor    - Run health diagnostics
clawd-config    - View all configuration
clawd-health    - Check health endpoint (requires jq)
clawd-update    - Update and restart gateway
clawd-backup    - Backup configuration
clawd-secure-check - Inspect container security settings (requires jq)
EOF
    
    echo ""
}

# Reload shell
reload_shell() {
    print_header "Activating Aliases"
    
    print_info "Reloading shell configuration..."
    
    # Source the config file
    if [ "$SHELL_NAME" = "zsh" ]; then
        source "$HOME/.zshrc" 2>/dev/null || true
    else
        source "$HOME/.bashrc" 2>/dev/null || true
    fi
    
    print_success "Shell configuration reloaded"
    print_info "Aliases are now available in new terminal sessions"
}

# Test aliases
test_aliases() {
    print_header "Testing Aliases"
    
    print_info "Testing if aliases are available..."
    
    if alias clawd-status &>/dev/null; then
        print_success "Aliases are working!"
    else
        print_warning "Aliases not yet available in current session"
        print_info "Please run: source $SHELL_CONFIG"
        print_info "Or open a new terminal window"
    fi
}

# Display next steps
display_next_steps() {
    print_header "Installation Complete!"
    
    echo -e "${GREEN}✓ Clawdbot aliases have been installed${NC}\n"
    
    echo -e "${BLUE}Next Steps:${NC}\n"
    
    echo -e "1. ${YELLOW}Reload your shell:${NC}"
    echo -e "   source $SHELL_CONFIG\n"
    
    echo -e "2. ${YELLOW}Or open a new terminal window${NC}\n"
    
    echo -e "3. ${YELLOW}Try an alias:${NC}"
    echo -e "   clawd-status\n"
    
    echo -e "${BLUE}Quick Start:${NC}\n"
    echo -e "  clawd-up       # Start gateway"
    echo -e "  clawd-status   # Check status"
    echo -e "  clawd-logs     # View logs"
    echo -e "  clawd-doctor   # Run diagnostics\n"
    
    echo -e "${BLUE}For full list of aliases, run:${NC}"
    echo -e "  alias | grep clawd\n"
}

# Main execution
main() {
    print_header "Clawdbot Alias Installer"
    
    detect_shell
    check_existing
    install_aliases
    display_aliases
    reload_shell
    test_aliases
    display_next_steps
}

# Run main function
main
