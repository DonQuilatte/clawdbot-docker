# Tailscale vs Proton VPN Evaluation for Clawdbot Infrastructure

**Date:** January 29, 2026
**Purpose:** Evaluate network security options for Controller ↔ TW Mac communication

---

## Current State

| Mac | Tailscale Installed | Status |
|-----|---------------------|--------|
| Controller (jederlichman) | ❌ No | - |
| TW Mac (tywhitaker) | ✅ Yes | Logged out |

**Current Security:** Local network only, SSH key-based auth, SMB with credentials

---

## Option 1: Tailscale (Recommended)

### What Tailscale Provides
- **WireGuard-based mesh VPN** - encrypted point-to-point tunnels
- **Zero-config networking** - devices find each other automatically
- **MagicDNS** - access TW Mac as `tw-mac.tailnet-name.ts.net`
- **ACLs** - fine-grained access control between devices
- **Works through NAT** - remote access from anywhere
- **Free tier** - up to 100 devices, 3 users

### Benefits for Clawdbot

| Benefit | Description |
|---------|-------------|
| **Encrypted tunnel** | All SSH/SMB traffic encrypted via WireGuard |
| **Remote access** | Control TW Mac from anywhere (coffee shop, travel) |
| **Stable IPs** | Each device gets a fixed 100.x.x.x IP |
| **No port forwarding** | Works behind any firewall/NAT |
| **SSH over Tailscale** | `ssh tw-mac` works from anywhere |
| **File sharing** | SMB mount works over Tailscale too |

### Free Tier Limitations
- 3 users max (fine for personal/small team)
- 100 devices (more than enough)
- No custom DERP relays
- Basic ACLs (sufficient for this use case)

### Implementation Complexity
**Low** - Install on both Macs, login, done.

```bash
# On Controller Mac
brew install tailscale
open /Applications/Tailscale.app  # or: sudo tailscaled & tailscale up

# On TW Mac
tailscale up  # Already installed, just login
```

### Updated SSH Config (with Tailscale)
```
Host tw-mac tw
  HostName tw-mac.tailnet-name.ts.net  # or 100.x.x.x
  User tywhitaker
  # ... rest same
```

---

## Option 2: Proton VPN (Paid)

### What Proton VPN Provides
- **Traditional VPN** - routes all traffic through Proton servers
- **Privacy-focused** - Swiss jurisdiction, no-logs policy
- **Server locations** - 60+ countries
- **Secure Core** - multi-hop routing

### Limitations for This Use Case

| Issue | Impact |
|-------|--------|
| **Not peer-to-peer** | Traffic goes: Controller → Proton → TW Mac (adds latency) |
| **Complex setup** | Need both Macs on same Proton server or split tunneling |
| **Not designed for LAN** | Proton VPN is for internet privacy, not device-to-device |
| **Overkill** | We don't need to hide from ISP, just encrypt local traffic |
| **Latency** | Every SSH command round-trips through Proton servers |

### When Proton VPN Makes Sense
- Browsing privately from untrusted networks
- Accessing geo-restricted content
- Hiding traffic from ISP
- **Not** for connecting two devices you own

---

## Comparison Matrix

| Feature | Tailscale (Free) | Proton VPN (Paid) | Current (None) |
|---------|------------------|-------------------|----------------|
| **Encryption** | ✅ WireGuard | ✅ OpenVPN/WG | ❌ Plaintext* |
| **Latency** | ✅ Direct P2P | ❌ Via servers | ✅ Direct |
| **Remote access** | ✅ Anywhere | ⚠️ Complex | ❌ LAN only |
| **Setup complexity** | ✅ Minimal | ❌ High | ✅ Done |
| **Cost** | ✅ Free | 💰 Paid | ✅ Free |
| **Designed for** | Device mesh | Internet privacy | - |
| **MagicDNS** | ✅ Yes | ❌ No | ❌ No |
| **ACLs** | ✅ Yes | ❌ No | ❌ No |

*SSH is encrypted, but SMB traffic and discovery are not.

---

## Recommendation: Tailscale

### Why Tailscale Wins
1. **Purpose-built** for connecting your own devices securely
2. **Zero cost** for our use case
3. **Minimal setup** - 5 minutes total
4. **Remote access bonus** - work from anywhere
5. **Better security** - all traffic encrypted, including SMB
6. **Stable addressing** - no more IP changes or mDNS issues

### Why Not Proton VPN
1. **Wrong tool** - designed for internet privacy, not device mesh
2. **Added latency** - every command goes through Switzerland
3. **Complex config** - split tunneling, same-server coordination
4. **Paying for unused features** - we don't need 60 countries

---

## Implementation Plan

### Phase 1: Install & Connect (15 min)

**On Controller Mac:**
```bash
brew install tailscale
open /Applications/Tailscale.app
# Login with your account (Google, Microsoft, or email)
```

**On TW Mac (already installed):**
```bash
tailscale up
# Login with SAME account
```

### Phase 2: Verify Connection
```bash
# From Controller
tailscale status
ping tw-mac  # Should resolve via MagicDNS
```

### Phase 3: Update Infrastructure

**Update SSH config:**
```
Host tw-mac tw
  HostName tw-mac.your-tailnet.ts.net
  # ... rest unchanged
```

**Update tw-control.sh:**
```bash
TW_HOST="tywhitaker@tw-mac.your-tailnet.ts.net"
```

**Update health monitor:**
```bash
# Ping Tailscale IP instead of LAN IP
ping -c 1 100.x.x.x
```

### Phase 4: Optional Hardening

**Tailscale ACLs (admin console):**
```json
{
  "acls": [
    {"action": "accept", "src": ["jederlichman-mac"], "dst": ["tw-mac:*"]},
    {"action": "accept", "src": ["tw-mac"], "dst": ["jederlichman-mac:*"]}
  ]
}
```

**Disable LAN access (if desired):**
- Firewall TW Mac to only accept Tailscale traffic
- Removes local network attack surface

---

## Security Improvements

| Before (Current) | After (Tailscale) |
|------------------|-------------------|
| SSH encrypted, SMB not fully | All traffic encrypted |
| LAN only | Access from anywhere |
| IP can change (DHCP) | Fixed 100.x.x.x |
| mDNS discovery | Tailscale DNS |
| No access control | ACLs available |
| No audit log | Tailscale logs connections |

---

## Decision Required

- [x] **Proceed with Tailscale** - Install on both Macs, update configs ✅ IMPLEMENTED
- [ ] ~~Keep current setup~~ - Local network only is acceptable
- [ ] ~~Further evaluation~~ - Need more information

---

## Implementation Complete (January 29, 2026)

### Tailscale IPs
| Device | Tailscale IP | MagicDNS |
|--------|--------------|----------|
| Controller (jeds-macbook-pro) | 100.73.138.46 | jeds-macbook-pro.tail270069.ts.net |
| TW Mac | 100.81.110.81 | tw.tail270069.ts.net |

### Updated Configs
- `~/.ssh/config` - Primary host now uses Tailscale IP (100.81.110.81)
- `tw-control.sh` - Tailscale-first with LAN fallback
- `tw-health-monitor.sh` - Monitors Tailscale connectivity
- Known hosts updated for Tailscale IP

### Verification
```bash
$ ~/bin/tw status
✓ Tailscale: Connected (100.81.110.81)
✓ SSH: Connected
✓ Persistent Socket: Active
✓ SMB Mount: Active
```

All traffic between Controller and TW Mac now encrypted via WireGuard tunnel.

---

## Appendix: Tailscale Free vs Paid

| Feature | Free | Personal ($48/yr) | Business |
|---------|------|-------------------|----------|
| Devices | 100 | 100 | Unlimited |
| Users | 3 | 1 admin | Team |
| ACLs | Basic | Basic | Advanced |
| Custom DERP | ❌ | ❌ | ✅ |
| SSO | ❌ | ❌ | ✅ |
| Audit logs | ❌ | ❌ | ✅ |

**Verdict:** Free tier is sufficient for clawdbot infrastructure.

---

*Evaluation completed: January 29, 2026*
