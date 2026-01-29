#!/bin/bash
# infrastructure/tw-mac/lockdown-firewall.sh
# Locks down the TW Mac firewall to allow only Tailscale and necessary local traffic.

TS_INTERFACE="utun4"  # Tailscale interface found via ifconfig
TS_IP="100.81.110.81"
CONTROLLER_LAN_IP="192.168.1.244"
TW_LAN_IP="192.168.1.245"

echo "🛡️  Generating pf.conf for TW Mac..."

cat << EOF > /tmp/pf.conf
# TW Mac Firewall Rules
# interface for tailscale: $TS_INTERFACE

# Options
set skip on lo0

# Normalization
scrub in all

# Default policies
block in all
pass out all

# Allow Tailscale traffic (Full trust on tailscale net)
pass in on $TS_INTERFACE all
pass in from $TS_IP to any

# Allow SSH and SMB from Controller LAN IP (Fallback)
pass in proto tcp from $CONTROLLER_LAN_IP to $TW_LAN_IP port { 22, 445 }

# Allow Ping (ICMP) from Controller LAN
pass in proto icmp from $CONTROLLER_LAN_IP to $TW_LAN_IP

EOF

echo "✅ Generated /tmp/pf.conf"
echo "🚀 Applying rules (requires sudo)..."
echo "Command: sudo pfctl -f /tmp/pf.conf -e"

# We don't run it directly here because it's destructive/high-risk and requires sudo.
# I will provide this script to the user.
