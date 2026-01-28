#!/usr/bin/env bash
# Pre-commit hook for gateway configuration validation
# Install: ln -sf ../../scripts/pre-commit-gateway-check.sh .git/hooks/pre-commit

set -euo pipefail

# Only run if docker-compose files are staged
if ! git diff --cached --name-only | grep -q 'docker-compose.*\.yml'; then
    exit 0
fi

echo "🔍 Validating gateway Docker configuration..."

COMPOSE_FILE="config/docker-compose.secure.yml"

# Check 1: Bind mode
BIND=$(grep -A1 '"--bind"' "$COMPOSE_FILE" 2>/dev/null | tail -1 | tr -d ' ",' || echo "")
if [[ "$BIND" == "localhost" ]]; then
    echo "❌ ERROR: Invalid bind mode 'localhost'"
    echo "   Use 'lan' for Docker compatibility (binds to 0.0.0.0 inside container)"
    exit 1
fi

# Check 2: tmpfs variables
if grep -E 'tmpfs:' -A10 "$COMPOSE_FILE" | grep -q '\${.*uid'; then
    echo "❌ ERROR: tmpfs uses variable interpolation"
    echo "   Docker Compose doesn't support variables in tmpfs options"
    exit 1
fi

# Check 3: Hardcoded tokens
if grep -qE 'token.*:.*[a-zA-Z0-9_-]{20,}' "$COMPOSE_FILE" 2>/dev/null; then
    if ! grep -q '\${' "$COMPOSE_FILE"; then
        echo "⚠️  WARNING: Possible hardcoded token detected"
    fi
fi

echo "✅ Gateway configuration validated"
exit 0
