#!/bin/bash

# Clawdbot Pre-Flight Check Script
# Run this before deployment to verify all prerequisites

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

print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

print_success() {
    echo -e "${GREEN}✓ ${NC}$1"
    ((CHECKS_PASSED++))
}

print_warning() {
    echo -e "${YELLOW}⚠ ${NC}$1"
    ((CHECKS_WARNING++))
}

print_error() {
    echo -e "${RED}✗ ${NC}$1"
    ((CHECKS_FAILED++))
}

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Check macOS version
check_macos() {
    print_header "Checking macOS Version"
    
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "Not running on macOS"
        return 1
    fi
    
    local version=$(sw_vers -productVersion)
    local major=$(echo "$version" | cut -d. -f1)
    
    if [ "$major" -ge 10 ]; then
        print_success "macOS version: $version"
    else
        print_error "macOS version too old: $version (requires 10.15+)"
    fi
}

# Check Docker Desktop
check_docker() {
    print_header "Checking Docker"
    
    # Check if Docker command exists
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        print_info "Install from: https://www.docker.com/products/docker-desktop"
        return 1
    fi
    
    print_success "Docker is installed: $(docker --version)"
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        print_info "Start Docker Desktop from Applications"
        return 1
    fi
    
    print_success "Docker daemon is running"
    
    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not available"
        return 1
    fi
    
    print_success "Docker Compose is available: $(docker compose version --short)"
    
    # Check Docker resources
    local cpus=$(docker info --format '{{.NCPU}}')
    local memory=$(docker info --format '{{.MemTotal}}')
    local memory_gb=$((memory / 1024 / 1024 / 1024))
    
    print_info "Docker resources: ${cpus} CPUs, ${memory_gb}GB RAM"
    
    if [ "$cpus" -lt 2 ]; then
        print_warning "Docker has less than 2 CPUs allocated"
    fi
    
    if [ "$memory_gb" -lt 4 ]; then
        print_warning "Docker has less than 4GB RAM allocated"
    fi
}

# Check Node.js and npm
check_node() {
    print_header "Checking Node.js and npm"
    
    if ! command -v node &> /dev/null; then
        print_warning "Node.js is not installed (optional for CLI)"
        print_info "Install from: https://nodejs.org/"
        return 0
    fi
    
    local node_version=$(node --version)
    local node_major=$(echo "$node_version" | cut -d. -f1 | tr -d 'v')
    
    if [ "$node_major" -ge 18 ]; then
        print_success "Node.js version: $node_version"
    else
        print_warning "Node.js version is old: $node_version (recommended: 18+)"
    fi
    
    if ! command -v npm &> /dev/null; then
        print_warning "npm is not installed"
        return 0
    fi
    
    print_success "npm version: $(npm --version)"
}

# Check Claude CLI
check_claude() {
    print_header "Checking Claude CLI"
    
    if ! command -v claude &> /dev/null; then
        print_warning "Claude CLI is not installed"
        print_info "Install with: curl -fsSL https://claude.ai/install.sh | bash"
        return 0
    fi
    
    print_success "Claude CLI is installed: $(claude --version)"
    
    # Check Claude authentication
    if claude auth status &> /dev/null; then
        print_success "Claude is authenticated"
    else
        print_warning "Claude is not authenticated"
        print_info "Run: claude auth login"
    fi
}

# Check Clawdbot CLI
check_clawdbot_cli() {
    print_header "Checking Clawdbot CLI"
    
    if ! command -v clawd &> /dev/null; then
        print_warning "Clawdbot CLI is not installed"
        print_info "Install with: npm install -g clawdbot@latest"
        return 0
    fi
    
    print_success "Clawdbot CLI is installed: $(clawd --version)"
}

# Check port availability
check_port() {
    print_header "Checking Port Availability"
    
    local port=${CLAWDBOT_GATEWAY_PORT:-3000}
    
    if lsof -i ":$port" &> /dev/null; then
        print_error "Port $port is already in use"
        print_info "Process using port $port:"
        lsof -i ":$port" | grep LISTEN
        print_info "Either stop the process or change CLAWDBOT_GATEWAY_PORT in .env"
    else
        print_success "Port $port is available"
    fi
}

# Check disk space
check_disk_space() {
    print_header "Checking Disk Space"
    
    local available=$(df -h . | awk 'NR==2 {print $4}')
    local available_gb=$(df -g . | awk 'NR==2 {print $4}')
    
    print_info "Available disk space: $available"
    
    if [ "$available_gb" -lt 10 ]; then
        print_warning "Less than 10GB free disk space"
        print_info "Clawdbot requires at least 5GB for images and data"
    else
        print_success "Sufficient disk space available"
    fi
}

# Check network connectivity
check_network() {
    print_header "Checking Network Connectivity"
    
    if ping -c 1 google.com &> /dev/null; then
        print_success "Internet connection is working"
    else
        print_error "No internet connection"
        print_info "Internet is required to pull Docker images"
        return 1
    fi
    
    # Check Docker Hub connectivity
    if curl -s https://hub.docker.com &> /dev/null; then
        print_success "Docker Hub is accessible"
    else
        print_warning "Cannot reach Docker Hub"
    fi
}

# Check project files
check_project_files() {
    print_header "Checking Project Files"
    
    local required_files=(
        "docker-compose.yml"
        "docker-setup.sh"
        ".env.example"
        "README.md"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            print_success "Found: $file"
        else
            print_error "Missing: $file"
        fi
    done
    
    # Check if docker-setup.sh is executable
    if [ -x "docker-setup.sh" ]; then
        print_success "docker-setup.sh is executable"
    else
        print_warning "docker-setup.sh is not executable"
        print_info "Run: chmod +x docker-setup.sh"
    fi
}

# Check environment variables
check_environment() {
    print_header "Checking Environment Variables"
    
    if [ -f ".env" ]; then
        print_success "Found .env file"
        
        # Check key variables
        if grep -q "CLAWDBOT_HOME_VOLUME" .env; then
            local home_volume=$(grep "CLAWDBOT_HOME_VOLUME" .env | cut -d= -f2)
            print_info "CLAWDBOT_HOME_VOLUME: $home_volume"
        fi
    else
        print_warning ".env file not found"
        print_info "Copy from .env.example: cp .env.example .env"
    fi
}

# Display summary
display_summary() {
    print_header "Pre-Flight Check Summary"
    
    echo -e "${GREEN}Passed:  $CHECKS_PASSED${NC}"
    echo -e "${YELLOW}Warnings: $CHECKS_WARNING${NC}"
    echo -e "${RED}Failed:   $CHECKS_FAILED${NC}"
    echo ""
    
    if [ $CHECKS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ All critical checks passed!${NC}"
        echo -e "${GREEN}✓ You are ready to deploy Clawdbot${NC}\n"
        
        echo -e "${BLUE}Next steps:${NC}"
        echo -e "1. Run: ${YELLOW}./docker-setup.sh${NC}"
        echo -e "2. Follow the deployment guide in ${YELLOW}DEPLOYMENT.md${NC}\n"
        
        return 0
    else
        echo -e "${RED}✗ Some critical checks failed${NC}"
        echo -e "${RED}✗ Please fix the errors above before deploying${NC}\n"
        
        echo -e "${BLUE}Common fixes:${NC}"
        echo -e "- Start Docker Desktop if not running"
        echo -e "- Install missing dependencies"
        echo -e "- Free up disk space if needed"
        echo -e "- Check network connectivity\n"
        
        return 1
    fi
}

# Main execution
main() {
    print_header "Clawdbot Pre-Flight Check"
    
    print_info "This script will verify all prerequisites for Clawdbot deployment"
    echo ""
    
    check_macos
    check_docker
    check_node
    check_claude
    check_clawdbot_cli
    check_port
    check_disk_space
    check_network
    check_project_files
    check_environment
    
    display_summary
}

# Run main function
main
