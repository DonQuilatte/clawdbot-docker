#!/bin/bash
# Weekly Clawdbot Health Check
# Runs every Monday at 9 AM

set -euo pipefail

LOG_DIR="$HOME/logs"
LOG_FILE="$LOG_DIR/clawdbot-weekly-tests.log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Run the test suite
echo "========================================" >> "$LOG_FILE"
echo "Weekly Health Check - $(date)" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

if ~/scripts/test-clawdbot-system-fast.sh >> "$LOG_FILE" 2>&1; then
    echo "✅ Tests PASSED" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    exit 0
else
    echo "⚠️ Tests FAILED - Review required" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # Optional: Send notification (uncomment if you want email alerts)
    # echo "Clawdbot weekly tests failed. Check $LOG_FILE for details." | mail -s "Clawdbot Test Failure" your@email.com
    
    exit 1
fi
