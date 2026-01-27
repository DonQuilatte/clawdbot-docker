#!/bin/bash
# Post-restart setup for Clawdbot Docker container
# Run this after container recreation to restore authentication

set -e

COMPOSE_FILE="config/docker-compose.secure.yml"
CONTAINER_NAME="clawdbot-gateway-secure"

# SECURITY: Token must be set - no weak default
if [ -z "${CLAWDBOT_GATEWAY_TOKEN:-}" ]; then
    # Try to load from .env file
    if [ -f .env ]; then
        TOKEN=$(grep "^CLAWDBOT_GATEWAY_TOKEN=" .env 2>/dev/null | cut -d= -f2)
    fi
    if [ -z "$TOKEN" ]; then
        echo "❌ CLAWDBOT_GATEWAY_TOKEN not set"
        echo "   Set it in .env or export CLAWDBOT_GATEWAY_TOKEN=<token>"
        exit 1
    fi
else
    TOKEN="$CLAWDBOT_GATEWAY_TOKEN"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Clawdbot Post-Restart Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if container is running
if ! docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
    echo "❌ Container $CONTAINER_NAME is not running"
    echo "   Start it with: docker compose -f $COMPOSE_FILE up -d clawdbot-gateway"
    exit 1
fi

echo "✅ Container is running"

# Set remote token to match auth token
echo ""
echo "🔐 Configuring gateway token..."
docker exec "$CONTAINER_NAME" clawdbot config set gateway.remote.token "$TOKEN" >/dev/null 2>&1
echo "✅ Token configured (hidden for security)"

# Restart to apply config
echo ""
echo "🔄 Restarting gateway to apply config..."
docker compose -f "$COMPOSE_FILE" restart clawdbot-gateway
sleep 5

# Check for pending device pairings
echo ""
echo "📱 Checking device pairings..."
PENDING=$(docker exec "$CONTAINER_NAME" clawdbot devices list 2>&1)
echo "$PENDING"

# Extract pending request IDs
PENDING_IDS=$(echo "$PENDING" | grep -E "^│ [a-f0-9-]{36}" | awk '{print $2}' | head -5)

if [ -n "$PENDING_IDS" ]; then
    echo ""
    echo "🔔 Found pending device requests. Approve them?"
    read -p "   Auto-approve all pending devices? (y/N): " APPROVE

    if [[ "$APPROVE" =~ ^[Yy]$ ]]; then
        for ID in $PENDING_IDS; do
            echo "   Approving $ID..."
            if ! docker exec "$CONTAINER_NAME" clawdbot devices approve "$ID" 2>&1; then
                echo "   ⚠️  Warning: Failed to approve device $ID (may already be approved)"
            fi
        done
        echo "✅ Device approval complete"
    else
        echo "ℹ️  To approve manually:"
        echo "   docker exec $CONTAINER_NAME clawdbot devices approve <request-id>"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Setup Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Gateway URL:  http://127.0.0.1:18789/"
echo "Token:        (set in .env - not displayed for security)"
echo ""
echo "Useful commands:"
echo "  docker logs -f $CONTAINER_NAME          # View logs"
echo "  docker exec $CONTAINER_NAME clawdbot devices list  # List devices"
echo "  docker compose -f $COMPOSE_FILE down    # Stop gateway"
