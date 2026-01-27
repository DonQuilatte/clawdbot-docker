# Remote Mac Access Guide

## Overview

This guide covers all methods to access your remote Mac (192.168.1.245) from different locations and networks.

## Current Network Setup

```
Your Home Network (192.168.1.x)
├─ Main Mac: 192.168.1.230 (jederlichman@Mac)
├─ Remote Mac: 192.168.1.245 (tywhitaker@TW)
└─ Router: 192.168.1.1
```

## Access Methods Comparison

| Method | Home WiFi | Internet | Encryption | Setup Time | Cost |
|--------|-----------|----------|------------|------------|------|
| **LAN (Current)** | ✅ | ❌ | ⚠️ None | Done | Free |
| **Tailscale** | ✅ | ✅ | ✅ WireGuard | 10 min | Free |
| **CloudFlare** | ✅ | ✅ | ✅ TLS | 20 min | Free |
| **WireGuard VPN** | ✅ | ✅ | ✅ Strong | 60 min | Free |
| **Port Forward** | ✅ | ✅ | ❌ None | 30 min | Free |
| **Bluetooth** | ❌ | ❌ | N/A | N/A | N/A |

---

## Method 1: LAN Access (Current - Working ✅)

**Status:** Already configured and working

**When to use:**
- At home on WiFi
- Connected to same router
- Local network only

**Access commands:**
```bash
# SSH to remote Mac
ssh tywhitaker@192.168.1.245

# View Clawdbot dashboard (shows remote node)
open http://localhost:18789

# Screen Sharing (if enabled)
open vnc://192.168.1.245
```

**Pros:**
- ✅ Fast (local network speed)
- ✅ Simple
- ✅ No configuration needed
- ✅ Secure (not exposed to internet)

**Cons:**
- ❌ Only works at home
- ❌ Can't access when traveling

---

## Method 2: Tailscale (Recommended for Internet Access) ⭐

**Status:** Not installed (ready to add when needed)

**When to use:**
- Working from coffee shop
- Traveling
- Away from home
- Need secure remote access

### Setup Instructions

**Step 1: Install Tailscale on Both Macs**

```bash
# On Main Mac (192.168.1.230)
brew install tailscale
sudo tailscale up

# On Remote Mac (192.168.1.245)
ssh tywhitaker@192.168.1.245
brew install tailscale
sudo tailscale up
```

**Step 2: Get Tailscale IPs**

```bash
# On Main Mac
tailscale ip -4
# Example: 100.101.102.103

# On Remote Mac
ssh tywhitaker@192.168.1.245 "tailscale ip -4"
# Example: 100.101.102.104
```

**Step 3: Update Clawdbot Configuration**

```bash
# On Remote Mac
ssh tywhitaker@192.168.1.245

# Update config with Tailscale IP of main Mac
cat > ~/.clawdbot/clawdbot.json << 'EOF'
{
  "meta": {
    "lastTouchedVersion": "2026.1.24-3"
  },
  "gateway": {
    "mode": "remote",
    "remote": {
      "url": "ws://100.101.102.103:18789",
      "token": "clawdbot-local-dev"
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/Users/tywhitaker",
      "maxConcurrent": 2
    }
  }
}
EOF

# Restart Clawdbot node
clawdbot node restart
```

**Step 4: Update Gateway Binding**

```bash
# On Main Mac - allow connections from Tailscale network
clawdbot gateway config set bind 0.0.0.0

# Restart gateway
clawdbot gateway restart
```

**Step 5: Test Access**

```bash
# From anywhere with internet, SSH using Tailscale IP
ssh tywhitaker@100.101.102.104

# Verify Clawdbot connection
clawdbot node status
```

### Tailscale Features

**What you get:**
- ✅ Access from anywhere
- ✅ Automatic encryption (WireGuard)
- ✅ No port forwarding needed
- ✅ Works behind NAT/firewalls
- ✅ Free for personal use
- ✅ Works on iOS/Android too

**Management:**
```bash
# Check Tailscale status
tailscale status

# See all devices
tailscale status --json | jq '.Peer[].HostName'

# Disable (when not needed)
sudo tailscale down

# Re-enable
sudo tailscale up
```

---

## Method 3: CloudFlare Tunnel

**Status:** Not installed (advanced option)

**When to use:**
- Need to expose web services
- Want custom domain
- Need DDoS protection
- Sharing services with others

### Setup Instructions

```bash
# On Remote Mac
brew install cloudflare-warp cloudflared

# Create tunnel
cloudflared tunnel create clawdbot-remote

# Configure tunnel (create config.yml)
cat > ~/.cloudflared/config.yml << 'EOF'
tunnel: <TUNNEL_ID>
credentials-file: /Users/tywhitaker/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: remote.yourdomain.com
    service: http://localhost:22
  - service: http_status:404
EOF

# Run tunnel
cloudflared tunnel run clawdbot-remote

# Install as service
cloudflared service install
```

**Pros:**
- ✅ Custom domain
- ✅ No port forwarding
- ✅ DDoS protection
- ✅ Free tier available

**Cons:**
- ⚠️ More complex setup
- ⚠️ Requires domain name
- ⚠️ Overkill for personal use

---

## Method 4: WireGuard VPN (Advanced)

**Status:** Not installed (advanced option)

**When to use:**
- Want full control
- Need to access entire home network
- Have technical expertise

### Setup Overview

```bash
# Install WireGuard
brew install wireguard-tools

# Generate keys
wg genkey | tee privatekey | wg pubkey > publickey

# Configure WireGuard
# (Complex - see WireGuard documentation)
```

**Pros:**
- ✅ Full network access
- ✅ Strong encryption
- ✅ Fast performance

**Cons:**
- ⚠️ Complex configuration
- ⚠️ Requires static IP or DDNS
- ⚠️ Need to configure router

---

## Method 5: Port Forwarding (NOT RECOMMENDED ❌)

**Status:** Not configured (security risk)

**Why NOT to use:**
- ❌ Exposes services to internet
- ❌ Subject to attacks
- ❌ No encryption by default
- ❌ Requires static IP or DDNS
- ❌ Most ISPs block common ports
- ❌ Violates security best practices

**If you must:**
1. Setup DDNS (no-ip.com or duckdns.org)
2. Configure router port forwarding
3. Forward external port to 192.168.1.245:22
4. Use SSH tunneling for all connections

---

## Bluetooth: Not Possible ❌

Bluetooth **cannot** be used for:
- ❌ SSH connections
- ❌ Network communication
- ❌ Computer-to-computer remote access
- ❌ Clawdbot communication

Bluetooth is only for:
- Short-range devices (keyboards, mice, headphones)
- Low bandwidth connections
- Maximum 10-30 feet range

---

## Recommended Setup

### For Home Use Only
```
Current LAN setup ✅
- No additional setup needed
- Fast and secure
- Works perfectly
```

### For Internet Access (When Needed)
```
Add Tailscale ✅
- 10 minute setup
- Works from anywhere
- Secure by default
- Free for personal use
```

### For Advanced Users
```
Consider CloudFlare Tunnel or WireGuard
- More control
- Custom domains
- Complex setup
```

---

## Quick Start: Add Tailscale Now

```bash
# Run automated setup script
~/Development/Projects/clawdbot/scripts/setup-tailscale.sh

# Or manual setup:
# 1. Install on both Macs
brew install tailscale && sudo tailscale up

# 2. Get IPs and update Clawdbot config
# 3. Restart services
# 4. Test connection
```

---

## Security Best Practices

**Do:**
- ✅ Use Tailscale or VPN for internet access
- ✅ Keep SSH keys with passphrases
- ✅ Enable firewall on both Macs
- ✅ Use encrypted connections
- ✅ Keep software updated

**Don't:**
- ❌ Port forward without VPN
- ❌ Expose services directly to internet
- ❌ Use weak passwords
- ❌ Disable firewall
- ❌ Share credentials

---

## Firewall Configuration

### Enabling Firewall on Remote Mac

The macOS firewall can be enabled without breaking Clawdbot connectivity. The Clawdbot node makes **outbound** WebSocket connections to the gateway, which are allowed by default. However, Node.js must be explicitly added to the firewall's allowed applications.

**Step 1: Enable Firewall**
```bash
# On TW (via System Settings or command line)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
```

**Step 2: Add Node.js to Allowed Apps**
```bash
# On TW - add your Node.js binary (adjust path for your nvm version)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add ~/.nvm/versions/node/v24.13.0/bin/node
```

**Step 3: Restart Clawdbot Node**
```bash
clawdbot node restart
```

**Step 4: Verify Connection**
```bash
# Check node status
clawdbot node status

# Or from main Mac
ssh tywhitaker@192.168.1.245 'clawdbot node status'
```

### Firewall Verification Commands

```bash
# Check firewall state
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# List allowed apps
/usr/libexec/ApplicationFirewall/socketfilterfw --listapps

# Check if specific app is blocked
/usr/libexec/ApplicationFirewall/socketfilterfw --getappblocked /path/to/app
```

### After Node.js Updates

When you update Node.js via nvm, you may need to re-add the new version to the firewall:

```bash
# Get current node path
which node

# Add to firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add $(which node)

# Restart Clawdbot
clawdbot node restart
```

---

## Troubleshooting

### Can't connect from internet
- Verify Tailscale is running: `tailscale status`
- Check firewall allows Tailscale
- Confirm Clawdbot gateway binding: `clawdbot gateway config get bind`

### Tailscale not connecting
- Restart Tailscale: `sudo tailscale down && sudo tailscale up`
- Check network connectivity
- Verify both devices authenticated to same Tailscale account

### Clawdbot node offline
- Check node status: `ssh tywhitaker@192.168.1.245 "clawdbot node status"`
- Verify gateway reachable from remote
- Check WebSocket connection in logs

---

## See Also

- [Tailscale Setup Guide](TAILSCALE_SETUP.md)
- [System Status](SYSTEM_STATUS.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Quick Reference](QUICK_REFERENCE.md)

---

**Last Updated:** 2026-01-27
**Status:** LAN working ✅ | Tailscale ready to add ⏸️
