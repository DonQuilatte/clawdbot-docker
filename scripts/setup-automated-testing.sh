#!/bin/bash
# Setup Automated Weekly Testing for Clawdbot

set -euo pipefail

echo "Setting up automated weekly health checks..."

# Create logs directory
mkdir -p ~/logs

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "weekly-health-check.sh"; then
    echo "⚠️  Cron job already exists. Skipping..."
else
    # Add cron job
    (crontab -l 2>/dev/null; cat ~/scripts/clawdbot-cron.txt) | crontab -
    echo "✅ Cron job added successfully!"
fi

# Display current crontab
echo ""
echo "Current cron jobs:"
crontab -l | grep -A1 "Clawdbot" || echo "No Clawdbot cron jobs found"

echo ""
echo "=========================================="
echo "Automated Testing Setup Complete!"
echo "=========================================="
echo ""
echo "Weekly health checks will run:"
echo "  📅 Every Monday at 9:00 AM"
echo "  📝 Logs saved to: ~/logs/clawdbot-weekly-tests.log"
echo "  ⚡ Test script: ~/scripts/test-clawdbot-system-fast.sh"
echo ""
echo "To view logs:"
echo "  tail -f ~/logs/clawdbot-weekly-tests.log"
echo ""
echo "To remove cron job:"
echo "  crontab -e  # then delete the Clawdbot line"
echo ""
