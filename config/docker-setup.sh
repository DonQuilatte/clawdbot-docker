#!/bin/bash

# Clawdbot Docker Setup Script
# This script initializes the Clawdbot environment with Docker

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
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

# Check if running on macOS
check_os() {
    print_header "Checking Operating System"
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This script is designed for macOS only"
        exit 1
    fi
    print_success "Running on macOS"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_deps=()
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        missing_deps+=("Docker Desktop for Mac")
    else
        print_success "Docker is installed ($(docker --version))"
    fi
    
    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not available"
        missing_deps+=("Docker Compose")
    else
        print_success "Docker Compose is available ($(docker compose version))"
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        print_info "Please start Docker Desktop"
        exit 1
    else
        print_success "Docker daemon is running"
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_warning "Node.js is not installed (optional for CLI)"
    else
        print_success "Node.js is installed ($(node --version))"
    fi
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        print_warning "npm is not installed (optional for CLI)"
    else
        print_success "npm is installed ($(npm --version))"
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
}

# Setup environment variables
setup_environment() {
    print_header "Setting Up Environment"
    
    # Set default data directory if not set
    if [ -z "$CLAWDBOT_HOME_VOLUME" ]; then
        export CLAWDBOT_HOME_VOLUME="$HOME/Development/clawdbot-workspace/data"
        print_info "Using default data directory: $CLAWDBOT_HOME_VOLUME"
    else
        print_info "Using custom data directory: $CLAWDBOT_HOME_VOLUME"
    fi
    
    # Create data directory structure
    print_info "Creating data directory structure..."
    mkdir -p "$CLAWDBOT_HOME_VOLUME"/{config,logs,cache}
    
    # Set permissions
    chmod -R 755 "$CLAWDBOT_HOME_VOLUME"
    
    print_success "Data directory created: $CLAWDBOT_HOME_VOLUME"
    
    # Create .env file if it doesn't exist
    if [ ! -f .env ]; then
        print_info "Creating .env file..."
        cat > .env << EOF
# Clawdbot Environment Configuration
CLAWDBOT_HOME_VOLUME=$CLAWDBOT_HOME_VOLUME
CLAWDBOT_GATEWAY_PORT=3000
CLAWDBOT_LOG_LEVEL=info
CLAWDBOT_GATEWAY_BIND=localhost
EOF
        print_success ".env file created"
    else
        print_info ".env file already exists"
    fi
}

# Pull Docker images
pull_images() {
    print_header "Pulling Docker Images"
    
    print_info "Pulling clawdbot/gateway:latest..."
    if docker pull clawdbot/gateway:latest; then
        print_success "Gateway image pulled successfully"
    else
        print_error "Failed to pull gateway image"
        print_warning "This might be expected if the image doesn't exist yet"
    fi
    
    print_info "Pulling clawdbot/cli:latest..."
    if docker pull clawdbot/cli:latest; then
        print_success "CLI image pulled successfully"
    else
        print_error "Failed to pull CLI image"
        print_warning "This might be expected if the image doesn't exist yet"
    fi
}

# Initialize configuration
initialize_config() {
    print_header "Initializing Configuration"
    
    # Create default config file if it doesn't exist
    local config_file="$CLAWDBOT_HOME_VOLUME/config/gateway.json"
    
    if [ ! -f "$config_file" ]; then
        print_info "Creating default configuration..."
        cat > "$config_file" << 'EOF'
{
  "gateway": {
    "bind": "localhost",
    "port": 3000,
    "sandbox": {
      "enabled": false,
      "mode": "moderate",
      "allowedCommands": []
    },
    "tools": {
      "policy": "moderate",
      "allowList": []
    },
    "audit": {
      "enabled": false,
      "logLevel": "info"
    },
    "security": {
      "promptInjection": {
        "enabled": false
      },
      "rateLimit": {
        "enabled": false,
        "maxRequests": 100,
        "windowMs": 60000
      },
      "cors": {
        "enabled": false
      }
    }
  }
}
EOF
        print_success "Default configuration created"
    else
        print_info "Configuration file already exists"
    fi
}

# Display next steps
display_next_steps() {
    print_header "Setup Complete!"
    
    echo -e "${GREEN}✓ Clawdbot Docker environment is ready${NC}\n"
    
    echo -e "${BLUE}Next Steps:${NC}\n"
    
    echo -e "1. ${YELLOW}Authenticate Claude Code:${NC}"
    echo -e "   claude auth login"
    echo -e "   claude setup-token\n"
    
    echo -e "2. ${YELLOW}Configure Security Settings:${NC}"
    echo -e "   docker compose run --rm clawdbot-cli config set gateway.sandbox.enabled true"
    echo -e "   docker compose run --rm clawdbot-cli config set gateway.sandbox.mode strict\n"
    
    echo -e "3. ${YELLOW}Authenticate Clawdbot:${NC}"
    echo -e "   docker compose run --rm clawdbot-cli models auth paste-token --provider anthropic\n"
    
    echo -e "4. ${YELLOW}Configure Google Antigravity:${NC}"
    echo -e "   docker compose run --rm clawdbot-cli plugins enable google-antigravity-auth"
    echo -e "   docker compose run --rm clawdbot-cli models auth login --provider google-antigravity\n"
    
    echo -e "5. ${YELLOW}Start the Gateway:${NC}"
    echo -e "   docker compose up -d clawdbot-gateway\n"
    
    echo -e "6. ${YELLOW}Verify Installation:${NC}"
    echo -e "   docker compose run --rm clawdbot-cli doctor"
    echo -e "   curl http://localhost:3000/health\n"
    
    echo -e "${BLUE}For detailed instructions, see README.md${NC}\n"
}

# Main execution
main() {
    print_header "Clawdbot Docker Setup"
    
    check_os
    check_prerequisites
    setup_environment
    pull_images
    initialize_config
    display_next_steps
}

# Run main function
main
