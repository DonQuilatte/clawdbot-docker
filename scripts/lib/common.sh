#!/bin/bash
# scripts/lib/common.sh
# Common infrastructure functions for Clawdbot.

# Get the gateway token, supporting .env and 1Password (op://)
get_gateway_token() {
    local token_ref
    
    # Identify repo root (assuming scripts/lib is 2 levels deep)
    local repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    if [ ! -f "$repo_root/.env" ]; then
        echo "❌ ERROR: .env file not found in $repo_root" >&2
        return 1
    fi

    token_ref=$(grep "^CLAWDBOT_GATEWAY_TOKEN=" "$repo_root/.env" | cut -d= -f2)

    if [ -z "$token_ref" ]; then
        echo "❌ ERROR: CLAWDBOT_GATEWAY_TOKEN not set in .env" >&2
        return 1
    fi

    # Check if it's a 1Password reference
    if [[ "$token_ref" == op://* ]]; then
        # Fetch from 1Password
        if ! command -v op &> /dev/null; then
            echo "❌ ERROR: 1Password CLI (op) not found but reference used" >&2
            return 1
        fi
        
        local token
        token=$(op read "$token_ref")
        if [ $? -ne 0 ]; then
             echo "❌ ERROR: Failed to read from 1Password" >&2
             return 1
        fi
        echo "$token"
    else
        # Return literal value
        echo "$token_ref"
    fi
}
