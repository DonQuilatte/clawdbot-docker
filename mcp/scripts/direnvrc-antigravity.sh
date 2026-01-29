#!/usr/bin/env bash

# Add to ~/.config/direnv/direnvrc for automatic Antigravity engagement

# layout_antigravity: Auto-configure project for Antigravity
layout_antigravity() {
    local project_root="$PWD"
    local project_name=$(basename "$project_root")
    
    # Run auto-setup in background
    if [ -x "${HOME}/bin/agy-auto-setup" ]; then
        "${HOME}/bin/agy-auto-setup" "$project_root" &
    fi
    
    # Export MCP server configuration path if exists
    if [ -f "${project_root}/.mcp-servers.json" ]; then
        export AGY_MCP_SERVERS="${project_root}/.mcp-servers.json"
    fi
    
    # Export job directory for remote execution results
    export AGY_JOBS_DIR="${HOME}/Development/.agy-jobs"
    
    # Mark that we're in an Antigravity-managed project
    export AGY_PROJECT_NAME="$project_name"
    export AGY_PROJECT_ROOT="$project_root"
}
