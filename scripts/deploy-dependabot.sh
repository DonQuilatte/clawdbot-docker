#!/bin/bash
# Deploy Dependabot configuration to a target repository
# Usage: ./scripts/deploy-dependabot.sh <target-repo-path>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../templates/dependabot"

if [ -z "$1" ]; then
    echo "Usage: $0 <target-repo-path>"
    echo ""
    echo "Example: $0 ~/Development/Projects/myapp"
    exit 1
fi

TARGET_REPO="$1"

if [ ! -d "$TARGET_REPO" ]; then
    echo "❌ Target directory does not exist: $TARGET_REPO"
    exit 1
fi

if [ ! -d "$TARGET_REPO/.git" ]; then
    echo "❌ Target is not a git repository: $TARGET_REPO"
    exit 1
fi

echo "📦 Deploying Dependabot configuration to: $TARGET_REPO"
echo ""

# Create directories
mkdir -p "$TARGET_REPO/.github/workflows"

# Deploy files
echo "📄 Deploying dependabot.yml..."
cp "$TEMPLATE_DIR/dependabot.yml" "$TARGET_REPO/.github/dependabot.yml"

echo "📄 Deploying auto-merge workflow..."
cp "$TEMPLATE_DIR/auto-merge.yml" "$TARGET_REPO/.github/workflows/dependabot-auto-merge.yml"

echo "📄 Deploying auto-rollback workflow..."
cp "$TEMPLATE_DIR/auto-rollback.yml" "$TARGET_REPO/.github/workflows/auto-rollback.yml"

# Check for CI workflow
if ! ls "$TARGET_REPO/.github/workflows/"*.yml 2>/dev/null | xargs grep -l "name: CI" >/dev/null 2>&1; then
    echo ""
    echo "⚠️  Warning: No 'CI' workflow found."
    echo "   Edit auto-rollback.yml and update the 'workflows:' trigger to match your CI workflow name."
fi

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Next steps:"
echo "  1. cd $TARGET_REPO"
echo "  2. Review .github/dependabot.yml"
echo "  3. Update auto-rollback.yml workflow trigger if needed"
echo "  4. git add .github && git commit -m 'deps: add Dependabot automation'"
echo "  5. git push"
echo ""
echo "Run triage anytime:"
echo "  bun run $SCRIPT_DIR/dependabot-triage.ts"
