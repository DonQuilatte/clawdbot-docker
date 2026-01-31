#!/bin/bash
#
# MCP Setup Script for Clawdbot
# Configures Docker MCP Toolkit with 1Password integration
#
# Usage: ./scripts/setup-mcp.sh [--all|--dockerhub|--exa|--validate]
#
# Prerequisites:
#   - Docker Desktop running
#   - 1Password CLI installed and signed in
#   - Docker MCP Toolkit enabled in Docker Desktop
#

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

# Symbols
CHECK="✓"
CROSS="✗"
WARN="⚠"
ARROW="→"

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------

# 1Password vault restriction
# SECURITY: Only allow access to the Developer vault
OP_ALLOWED_VAULT_ID="rtbdzfkcstpqfcot4gl66xbeky"
OP_ALLOWED_VAULT_NAME="Developer"

# 1Password item references (all items MUST be in Developer vault)
OP_DOCKER_ITEM="Docker"
OP_DOCKER_VAULT="$OP_ALLOWED_VAULT_NAME"
OP_EXA_ITEM="exa.ai"
OP_EXA_VAULT="$OP_ALLOWED_VAULT_NAME"

# DockerHub settings
DOCKERHUB_USERNAME="juniperdocent"

# Exa MCP URL
EXA_MCP_URL="https://mcp.exa.ai/mcp"

#------------------------------------------------------------------------------
# Utility Functions
#------------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}${ARROW}${NC} $1"
}

log_success() {
    echo -e "${GREEN}${CHECK}${NC} $1"
}

log_error() {
    echo -e "${RED}${CROSS}${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}${WARN}${NC} $1"
}

log_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

#------------------------------------------------------------------------------
# Pre-flight Checks
#------------------------------------------------------------------------------

# Detect and cache Docker command path (handles 1Password shell integration)
# This is called once at startup to avoid repeated detection overhead
_DOCKER_CMD=""
detect_docker_cmd() {
    # Return cached value if already detected
    [[ -n "$_DOCKER_CMD" ]] && return 0

    # 1Password shell integration can wrap docker; use direct path to avoid issues
    if [[ -x "/opt/homebrew/bin/docker" ]]; then
        _DOCKER_CMD="/opt/homebrew/bin/docker"
    elif [[ -x "/usr/local/bin/docker" ]]; then
        _DOCKER_CMD="/usr/local/bin/docker"
    else
        _DOCKER_CMD="docker"
    fi
    export _DOCKER_CMD
}

# Run docker mcp commands (uses cached docker path)
docker_mcp() {
    "$_DOCKER_CMD" mcp "$@" 2>&1
}

# Initialize docker command detection at script startup
detect_docker_cmd

check_dependencies() {
    log_header "Pre-flight Checks"
    local failed=0

    # Check 1Password CLI
    if command -v op &>/dev/null; then
        log_success "1Password CLI installed ($(op --version 2>/dev/null || echo 'unknown version'))"
    else
        log_error "1Password CLI not found. Install: brew install 1password-cli"
        failed=1
    fi

    # Check 1Password signin
    if op account get &>/dev/null 2>&1; then
        log_success "1Password signed in"
    else
        log_error "1Password not signed in. Run: eval \$(op signin)"
        failed=1
    fi

    # Check Docker (uses cached _DOCKER_CMD)
    if command -v "$_DOCKER_CMD" &>/dev/null; then
        log_success "Docker installed ($($_DOCKER_CMD --version 2>/dev/null | head -1))"
    else
        log_error "Docker not found"
        failed=1
    fi

    # Check Docker Desktop running
    if $_DOCKER_CMD info &>/dev/null 2>&1; then
        log_success "Docker Desktop running"
    else
        log_error "Docker Desktop not running. Please start Docker Desktop"
        failed=1
    fi

    # Check Docker MCP Toolkit
    if docker_mcp server ls &>/dev/null; then
        log_success "Docker MCP Toolkit available"
    else
        log_error "Docker MCP Toolkit not available. Enable in Docker Desktop settings"
        failed=1
    fi

    if [[ $failed -eq 1 ]]; then
        echo ""
        log_error "Pre-flight checks failed. Fix the issues above and retry."
        exit 1
    fi

    log_success "All pre-flight checks passed"
}

#------------------------------------------------------------------------------
# Credential Validation
#------------------------------------------------------------------------------

validate_dockerhub() {
    local username="$1"
    local pat="$2"

    log_info "Validating DockerHub credentials..."

    if echo "$pat" | $_DOCKER_CMD login -u "$username" --password-stdin &>/dev/null 2>&1; then
        log_success "DockerHub credentials valid"
        return 0
    else
        log_error "DockerHub credentials invalid"
        return 1
    fi
}

validate_exa() {
    local api_key="$1"

    log_info "Validating Exa API key..."

    local response
    # OPTIMIZATION: Add timeout to prevent indefinite hangs
    response=$(curl -s --connect-timeout 10 --max-time 30 -X POST "https://api.exa.ai/search" \
        -H "x-api-key: $api_key" \
        -H "Content-Type: application/json" \
        -d '{"query": "test", "numResults": 1}' 2>/dev/null)

    if echo "$response" | grep -q "results"; then
        log_success "Exa API key valid"
        return 0
    else
        log_error "Exa API key invalid"
        return 1
    fi
}

#------------------------------------------------------------------------------
# 1Password Operations
#------------------------------------------------------------------------------

# Secure wrapper functions - enforce Developer vault only
op_get_field() {
    local item="$1"
    local field="$2"
    # SECURITY: Always scope to Developer vault
    op item get "$item" --vault "$OP_ALLOWED_VAULT_ID" --fields label="$field" 2>/dev/null
}

op_update_field() {
    local item="$1"
    local field="$2"
    local value="$3"
    # SECURITY: Always scope to Developer vault
    op item edit "$item" --vault "$OP_ALLOWED_VAULT_ID" "$field=$value" &>/dev/null
}

# Validate that an item exists in the allowed vault
op_validate_vault_access() {
    local item="$1"
    local vault_id
    vault_id=$(op item get "$item" --vault "$OP_ALLOWED_VAULT_ID" --format json 2>/dev/null | grep -o '"vault":{"id":"[^"]*"' | head -1 | cut -d'"' -f6)

    if [[ "$vault_id" != "$OP_ALLOWED_VAULT_ID" ]]; then
        log_error "SECURITY: Item '$item' is not in the Developer vault"
        log_error "This project only allows access to vault: $OP_ALLOWED_VAULT_NAME ($OP_ALLOWED_VAULT_ID)"
        return 1
    fi
    return 0
}

#------------------------------------------------------------------------------
# DockerHub Setup
#------------------------------------------------------------------------------

setup_dockerhub() {
    log_header "DockerHub MCP Setup"

    # Get credentials from 1Password
    log_info "Fetching credentials from 1Password..."

    local username
    local pat

    username=$(op_get_field "$OP_DOCKER_ITEM" "username" || echo "")
    pat=$(op_get_field "$OP_DOCKER_ITEM" "text" || echo "")

    if [[ -z "$username" ]]; then
        username="$DOCKERHUB_USERNAME"
        log_warn "Username not in 1Password, using default: $username"
    else
        log_success "Username: $username"
    fi

    # Validate current PAT
    if [[ -n "$pat" ]] && validate_dockerhub "$username" "$pat"; then
        log_success "Existing PAT is valid"
    else
        log_warn "Current PAT is invalid or missing"
        echo ""
        echo -e "${YELLOW}Generate a new PAT at:${NC}"
        echo "  https://app.docker.com/settings/personal-access-tokens"
        echo ""
        echo "  - Click 'Generate new token'"
        echo "  - Name: clawdbot-mcp"
        echo "  - Permissions: Read & Write"
        echo ""

        # Try to open browser
        if command -v open &>/dev/null; then
            read -p "Open Docker Hub in browser? [Y/n] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                open "https://app.docker.com/settings/personal-access-tokens"
                sleep 2
            fi
        fi

        # Prompt for new PAT (hidden input for security)
        echo ""
        read -rsp "Paste new PAT (starts with dckr_pat_): " new_pat
        echo ""  # newline after hidden input

        if [[ -z "$new_pat" ]]; then
            log_error "No PAT provided. Aborting."
            return 1
        fi

        # Validate new PAT
        if ! validate_dockerhub "$username" "$new_pat"; then
            log_error "New PAT validation failed. Check the token and try again."
            return 1
        fi

        # Update 1Password
        log_info "Updating 1Password..."
        if op_update_field "$OP_DOCKER_ITEM" "text" "$new_pat"; then
            log_success "1Password updated"
        else
            log_warn "Could not update 1Password (item may not exist)"
        fi

        pat="$new_pat"
    fi

    # Configure Docker MCP
    log_info "Configuring Docker MCP..."

    # Set config (username)
    # IMPORTANT: Use correct secret name from catalog: dockerhub.pat_token
    if docker_mcp config write "{\"dockerhub\": {\"username\": \"$username\"}}"; then
        log_success "DockerHub config set"
    else
        log_error "Failed to set DockerHub config"
        return 1
    fi

    # Set secret (MUST use dockerhub.pat_token, not HUB_PAT_TOKEN)
    if docker_mcp secret set "dockerhub.pat_token=$pat"; then
        log_success "DockerHub secret set (dockerhub.pat_token)"
    else
        log_error "Failed to set DockerHub secret"
        return 1
    fi

    # Verify status
    local status
    status=$(docker_mcp server ls 2>/dev/null | grep dockerhub || echo "")

    if echo "$status" | grep -q "✓ done.*✓ done"; then
        log_success "DockerHub MCP fully configured"
    else
        log_warn "DockerHub status: $status"
    fi

    return 0
}

#------------------------------------------------------------------------------
# Exa Setup
#------------------------------------------------------------------------------

setup_exa() {
    log_header "Exa MCP Setup"

    # Get API key from 1Password
    log_info "Fetching API key from 1Password..."

    local api_key
    api_key=$(op_get_field "$OP_EXA_ITEM" "API Key" || echo "")

    if [[ -z "$api_key" ]]; then
        log_warn "Exa API key not found in 1Password"
        echo ""
        echo -e "${YELLOW}Get your API key at:${NC}"
        echo "  https://exa.ai"
        echo ""

        read -rsp "Paste Exa API key: " api_key
        echo ""  # newline after hidden input

        if [[ -z "$api_key" ]]; then
            log_error "No API key provided. Aborting."
            return 1
        fi
    fi

    # Validate API key
    if ! validate_exa "$api_key"; then
        log_error "Exa API key validation failed"
        return 1
    fi

    # Add to shell profile
    log_info "Adding EXA_API_KEY to shell profile..."

    local shell_profile
    if [[ "${SHELL:-}" == *"zsh"* ]]; then
        shell_profile="$HOME/.zshrc"
    else
        shell_profile="$HOME/.bashrc"
    fi

    # Check if already exists
    if grep -q "EXA_API_KEY" "$shell_profile" 2>/dev/null; then
        log_warn "EXA_API_KEY already in $shell_profile (updating)"
        # Remove old entry (macOS-compatible sed)
        sed -i '' '/export EXA_API_KEY/d' "$shell_profile" 2>/dev/null || \
            sed -i '/export EXA_API_KEY/d' "$shell_profile"
    fi

    # SECURITY: Use 1Password reference instead of plaintext API key
    # This ensures the key is fetched at runtime, not stored in plaintext
    echo '# Exa API key - fetched from 1Password at runtime' >> "$shell_profile"
    echo 'export EXA_API_KEY="$(op read "op://Developer/exa.ai/API Key" 2>/dev/null || echo "")"' >> "$shell_profile"
    log_success "Added 1Password reference to $shell_profile (key fetched at runtime)"
    log_warn "Note: Requires 1Password CLI signin for EXA_API_KEY to work"

    # Update project .mcp.json
    log_info "Updating project .mcp.json..."

    local project_dir
    project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local mcp_json="$project_dir/.mcp.json"

    if [[ -f "$mcp_json" ]]; then
        # Check if exa already configured
        if grep -q '"exa"' "$mcp_json"; then
            log_success "Exa already in .mcp.json"
        else
            log_warn "Add Exa to .mcp.json manually or run setup again"
        fi
    else
        log_warn ".mcp.json not found at $mcp_json"
    fi

    # Create skill file
    local skill_dir="$project_dir/.claude/skills"
    mkdir -p "$skill_dir"

    if [[ ! -f "$skill_dir/exa-search.md" ]]; then
        log_info "Creating Exa skill file..."
        cat > "$skill_dir/exa-search.md" << 'SKILL_EOF'
---
name: exa-search
description: AI-powered web search using Exa API. Use for documentation, research, and code context.
---

# Exa Search Skill

## Tools Available
- `web_search_exa` - Web search
- `get_code_context_exa` - Code examples
- `crawling_exa` - Full page content
- `company_research_exa` - Company research

## Example Usage
```
web_search_exa(query="Docker security best practices", numResults=10)
```
SKILL_EOF
        log_success "Created $skill_dir/exa-search.md"
    else
        log_success "Exa skill file already exists"
    fi

    return 0
}

#------------------------------------------------------------------------------
# Validate All
#------------------------------------------------------------------------------

validate_all() {
    log_header "Validating All MCP Servers"

    local failed=0

    # DockerHub
    log_info "Checking DockerHub..."
    local dh_status
    dh_status=$(docker_mcp server ls 2>/dev/null | grep dockerhub || echo "not found")

    if echo "$dh_status" | grep -q "✓ done.*✓ done"; then
        log_success "DockerHub: SECRETS ✓ CONFIG ✓"
    else
        log_warn "DockerHub: $dh_status"
        failed=1
    fi

    # GitHub
    log_info "Checking GitHub..."
    local gh_status
    gh_status=$(docker_mcp server ls 2>/dev/null | grep github-official || echo "not found")

    if echo "$gh_status" | grep -q "✓ done"; then
        log_success "GitHub: configured"
    else
        log_warn "GitHub: $gh_status"
    fi

    # Exa
    log_info "Checking Exa..."
    if [[ -n "${EXA_API_KEY:-}" ]]; then
        if validate_exa "$EXA_API_KEY" 2>/dev/null; then
            log_success "Exa: API key valid"
        else
            log_warn "Exa: API key invalid"
            failed=1
        fi
    else
        log_warn "Exa: EXA_API_KEY not set in environment"
        failed=1
    fi

    # Context7
    log_info "Checking Context7..."
    local c7_status
    c7_status=$(docker_mcp server ls 2>/dev/null | grep context7 || echo "not found")

    if echo "$c7_status" | grep -v "required"; then
        log_success "Context7: ready"
    else
        log_warn "Context7: $c7_status"
    fi

    echo ""
    if [[ $failed -eq 0 ]]; then
        log_success "All validations passed"
    else
        log_warn "Some validations failed - check warnings above"
    fi

    return $failed
}

#------------------------------------------------------------------------------
# Final Instructions
#------------------------------------------------------------------------------

show_final_instructions() {
    log_header "Setup Complete"

    echo ""
    echo -e "${YELLOW}${WARN} IMPORTANT: Restart Required${NC}"
    echo ""
    echo "  The MCP gateway caches credentials. You MUST restart Claude Code:"
    echo ""
    echo "    Option 1: Cmd+Q (quit) → reopen Claude Code"
    echo "    Option 2: Type /exit in Claude Code"
    echo ""
    echo -e "${BLUE}After restart, test with:${NC}"
    echo ""
    echo "    'What are my DockerHub namespaces?'"
    echo "    'Search Exa for Docker security'"
    echo ""
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {
    local action="${1:-all}"

    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          MCP Setup Script for Clawdbot                   ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"

    case "$action" in
        --all|all)
            check_dependencies
            setup_dockerhub
            setup_exa
            validate_all
            show_final_instructions
            ;;
        --dockerhub|dockerhub)
            check_dependencies
            setup_dockerhub
            show_final_instructions
            ;;
        --exa|exa)
            check_dependencies
            setup_exa
            show_final_instructions
            ;;
        --validate|validate)
            check_dependencies
            validate_all
            ;;
        --help|-h|help)
            echo ""
            echo "Usage: $0 [OPTION]"
            echo ""
            echo "Options:"
            echo "  --all        Setup all MCP servers (default)"
            echo "  --dockerhub  Setup DockerHub only"
            echo "  --exa        Setup Exa only"
            echo "  --validate   Validate current configuration"
            echo "  --help       Show this help"
            echo ""
            ;;
        *)
            log_error "Unknown option: $action"
            echo "Run '$0 --help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
