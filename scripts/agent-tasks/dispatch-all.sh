#!/bin/bash
# Agent Task Dispatcher for ClawdBot
# Uses native Antigravity CLI to spawn parallel agents

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common library for colors and utilities
if [[ -f "$SCRIPT_DIR/../lib/common.sh" ]]; then
    source "$SCRIPT_DIR/../lib/common.sh"
else
    # Fallback colors if common.sh not available
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
fi

ANTIGRAVITY_CLI="/Applications/Antigravity.app/Contents/Resources/app/bin/antigravity"
PROJECT_DIR="$HOME/Development/Projects/dev-infrastructure"

dispatch_agent() {
    local task_name="$1"
    local task_prompt="$2"

    echo -e "${BLUE}Dispatching:${NC} $task_name"

    cd "$PROJECT_DIR"
    "$ANTIGRAVITY_CLI" chat \
        --mode agent \
        --new-window \
        "$task_prompt" &

    sleep 1  # Stagger launches slightly
}

show_usage() {
    echo "Usage: $0 <wave>"
    echo ""
    echo "Waves:"
    echo "  wave1  - Core improvements (6 parallel agents)"
    echo "  wave2  - Integration & testing (4 parallel agents)"
    echo "  wave3  - Documentation & polish (3 parallel agents)"
    echo ""
    echo "Example: $0 wave1"
}

# ═══════════════════════════════════════════════════════════════
# WAVE 1: Core Improvements (6 agents)
# ═══════════════════════════════════════════════════════════════
wave1() {
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  WAVE 1: Core Improvements - 6 Parallel Agents${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    dispatch_agent "docker-healthcheck" \
"Task: Improve Docker Health Checks

Branch: feature/docker-healthcheck-improvements

1. Review config/docker-compose.secure.yml
2. Add comprehensive healthcheck for each service
3. Include startup_period, interval, timeout, retries
4. Add healthcheck endpoint to the application if needed
5. Test with: docker compose -f config/docker-compose.secure.yml up
6. Commit and push when tests pass"

    dispatch_agent "security-audit" \
"Task: Security Audit Script Enhancement

Branch: feature/security-audit-enhancement

1. Review scripts/verify-security.sh
2. Add checks for:
   - Container user is non-root
   - Read-only filesystem is enabled
   - Capabilities are dropped
   - Seccomp profile is applied
   - Network policies are correct
3. Output results in structured format (JSON optional)
4. Commit and push when complete"

    dispatch_agent "env-validation" \
"Task: Environment Validation

Branch: feature/env-validation

1. Create scripts/validate-env.sh
2. Check all required environment variables
3. Validate 1Password references (op://) are resolvable
4. Check Docker/OrbStack is running
5. Verify network connectivity to required services
6. Exit with clear error messages if validation fails
7. Commit and push when complete"

    dispatch_agent "logging-setup" \
"Task: Structured Logging Configuration

Branch: feature/structured-logging

1. Review current logging in the Docker setup
2. Configure JSON structured logging
3. Add log rotation configuration
4. Ensure logs don't contain sensitive data
5. Update docker-compose with logging driver config
6. Commit and push when complete"

    dispatch_agent "backup-restore" \
"Task: Backup and Restore Scripts

Branch: feature/backup-restore

1. Create scripts/backup.sh for container data
2. Create scripts/restore.sh for recovery
3. Include configuration backup
4. Add timestamp-based backup naming
5. Document usage in script headers
6. Commit and push when complete"

    dispatch_agent "monitoring-integration" \
"Task: Health Monitoring Integration

Branch: feature/health-monitoring

1. Review existing health check infrastructure
2. Create scripts/health-monitor.sh
3. Add endpoint health polling
4. Include container status checks
5. Output status in machine-readable format
6. Commit and push when complete"

    echo ""
    echo -e "${YELLOW}Wave 1 dispatched! Monitor agents with CMD+E in Antigravity${NC}"
    echo -e "${YELLOW}After all PRs merged, run: npm run agents:wave2${NC}"
}

# ═══════════════════════════════════════════════════════════════
# WAVE 2: Integration & Testing (4 agents)
# ═══════════════════════════════════════════════════════════════
wave2() {
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  WAVE 2: Integration & Testing - 4 Parallel Agents${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    dispatch_agent "integration-tests" \
"Task: Integration Test Suite

Branch: feature/integration-tests

1. Create tests/integration/ directory
2. Add Docker compose up/down tests
3. Add health endpoint tests
4. Add security verification tests
5. Integrate with npm test command
6. Commit and push when tests pass"

    dispatch_agent "ci-pipeline" \
"Task: CI/CD Pipeline Setup

Branch: feature/ci-pipeline

1. Create .github/workflows/ci.yml
2. Add linting step (shellcheck)
3. Add unit tests step
4. Add Docker build verification
5. Add security scan step
6. Commit and push when complete"

    dispatch_agent "tw-mac-integration" \
"Task: TW Mac Worker Integration

Branch: feature/tw-mac-integration

1. Review existing TW Mac setup in CLAUDE.md
2. Create scripts/tw-dispatch.sh for task delegation
3. Add handoff template for ClawdBot tasks
4. Integrate with existing tw-* commands
5. Document usage in script header
6. Commit and push when complete"

    dispatch_agent "mcp-tool-tests" \
"Task: MCP Server Tool Verification

Branch: feature/mcp-tool-tests

1. Create tests/mcp/ directory
2. Add tests for github MCP tools
3. Add tests for filesystem MCP tools
4. Add tests for context7 MCP tools
5. Verify tool responses are correct
6. Commit and push when tests pass"

    echo ""
    echo -e "${YELLOW}Wave 2 dispatched! Monitor agents with CMD+E in Antigravity${NC}"
    echo -e "${YELLOW}After all PRs merged, run: npm run agents:wave3${NC}"
}

# ═══════════════════════════════════════════════════════════════
# WAVE 3: Documentation & Polish (3 agents)
# ═══════════════════════════════════════════════════════════════
wave3() {
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  WAVE 3: Documentation & Polish - 3 Parallel Agents${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    dispatch_agent "runbook" \
"Task: Operations Runbook

Branch: feature/runbook

1. Create docs/RUNBOOK.md
2. Document deployment procedures
3. Document troubleshooting steps
4. Document recovery procedures
5. Include common commands reference
6. Commit and push when complete"

    dispatch_agent "architecture-diagram" \
"Task: Architecture Documentation

Branch: feature/architecture-docs

1. Create docs/ARCHITECTURE.md
2. Document system components
3. Document network topology
4. Document security boundaries
5. Include Mermaid diagrams where helpful
6. Commit and push when complete"

    dispatch_agent "cleanup-polish" \
"Task: Codebase Cleanup

Branch: feature/cleanup

1. Remove any unused files
2. Ensure consistent formatting
3. Verify all scripts have proper headers
4. Check .gitignore is complete
5. Verify no secrets in codebase
6. Commit and push when complete"

    echo ""
    echo -e "${YELLOW}Wave 3 dispatched! Monitor agents with CMD+E in Antigravity${NC}"
    echo -e "${GREEN}All waves complete after this!${NC}"
}

# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════
case "${1:-}" in
    wave1) wave1 ;;
    wave2) wave2 ;;
    wave3) wave3 ;;
    *)
        show_usage
        exit 1
        ;;
esac
