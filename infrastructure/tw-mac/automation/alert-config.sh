#!/bin/bash
# Alert Configuration - Customize how you receive alerts
# Edit this file to configure alert preferences

# Save as ~/.claude/tw-mac/alert.sh and make executable
# The connection monitor will call this script with: $1=title $2=message $3=urgency

TITLE="$1"
MESSAGE="$2"
URGENCY="$3"  # normal, critical

# ═══════════════════════════════════════════
# NOTIFICATION METHODS - Uncomment to enable
# ═══════════════════════════════════════════

# --- macOS Notification Center (default) ---
osascript -e "display notification \"$MESSAGE\" with title \"Clawdbot\" subtitle \"$TITLE\"" 2>/dev/null

# --- Sound alert for critical ---
if [ "$URGENCY" = "critical" ]; then
    afplay /System/Library/Sounds/Sosumi.aiff 2>/dev/null &
fi

# --- Slack webhook (uncomment and add webhook URL) ---
# SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
# if [ -n "$SLACK_WEBHOOK" ]; then
#     curl -s -X POST -H 'Content-type: application/json' \
#         --data "{\"text\":\"*$TITLE*\n$MESSAGE\"}" \
#         "$SLACK_WEBHOOK" >/dev/null
# fi

# --- Email via mailx (uncomment and configure) ---
# EMAIL="your@email.com"
# if [ -n "$EMAIL" ] && [ "$URGENCY" = "critical" ]; then
#     echo "$MESSAGE" | mailx -s "Clawdbot Alert: $TITLE" "$EMAIL"
# fi

# --- Pushover (uncomment and add tokens) ---
# PUSHOVER_USER="your_user_key"
# PUSHOVER_TOKEN="your_app_token"
# if [ -n "$PUSHOVER_USER" ] && [ -n "$PUSHOVER_TOKEN" ]; then
#     PRIORITY=0
#     [ "$URGENCY" = "critical" ] && PRIORITY=1
#     curl -s -X POST https://api.pushover.net/1/messages.json \
#         -d "token=$PUSHOVER_TOKEN" \
#         -d "user=$PUSHOVER_USER" \
#         -d "title=$TITLE" \
#         -d "message=$MESSAGE" \
#         -d "priority=$PRIORITY" >/dev/null
# fi

# --- Discord webhook (uncomment and add webhook URL) ---
# DISCORD_WEBHOOK="https://discord.com/api/webhooks/YOUR/WEBHOOK"
# if [ -n "$DISCORD_WEBHOOK" ]; then
#     curl -s -X POST -H 'Content-type: application/json' \
#         --data "{\"content\":\"**$TITLE**\n$MESSAGE\"}" \
#         "$DISCORD_WEBHOOK" >/dev/null
# fi

# --- Log to file (always enabled) ---
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$URGENCY] $TITLE: $MESSAGE" >> "$HOME/.claude/tw-mac/alerts.log"
