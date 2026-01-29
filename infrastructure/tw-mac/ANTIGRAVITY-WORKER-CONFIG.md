# Antigravity Configuration for TW Mac Worker Node

**Date:** January 29, 2026
**Target:** TW Mac (tywhitaker@192.168.1.245)
**Purpose:** Optimize Antigravity settings for headless AI worker operations

---

## Instructions for Clawdbot Agent on TW Mac

✅ **COMPLETED: January 29, 2026**

These settings have been applied to TW Mac to optimize it as a dedicated worker/agent node for automated development workflows.

---

## Settings to Change

### TERMINAL COMMAND AUTO EXECUTION
| Setting | Target Value | Reason |
|---------|--------------|--------|
| Terminal Command Auto Execution | **Always Proceed** | Worker needs autonomous operation |
| Enable Terminal Sandbox | **OFF** | Worker needs full system access |

### AUTOMATION
| Setting | Target Value | Reason |
|---------|--------------|--------|
| Agent Auto-Fix Lints | **ON** | Auto-correct without prompts |
| Auto-Continue | **ON** | Keep long tasks running |

### HISTORY
| Setting | Target Value | Reason |
|---------|--------------|--------|
| Conversation History | **ON** | Context awareness |
| Knowledge | **ON** | Learn patterns over time |

### GENERAL
| Setting | Target Value | Reason |
|---------|--------------|--------|
| Explain and Fix in Current Conversation | **ON** | Maintain session continuity |
| Open Agent on Reload | **ON** | Ready for commands immediately |
| Enable Sounds for Agent | **OFF** | Headless worker, no audio needed |

### FILE ACCESS
| Setting | Target Value | Reason |
|---------|--------------|--------|
| Agent Gitignore Access | **ON** | Full repo access |
| Agent Non-Workspace File Access | **ON** | System operations access |

### SUGGESTIONS
| Setting | Target Value | Reason |
|---------|--------------|--------|
| Suggestions in Editor | **ON** | Faster coding |
| Tab Speed | **Fast** | Responsive completions |
| Highlight After Accept | **ON** | Visual feedback |
| Tab to Import | **ON** | Quick imports |

### NAVIGATION
| Setting | Target Value | Reason |
|---------|--------------|--------|
| Tab to Jump | **ON** | Efficient navigation |

### CONTEXT
| Setting | Target Value | Reason |
|---------|--------------|--------|
| Clipboard Context | **ON** | Use clipboard for context |
| Tab Gitignore Access | **ON** | Access all files |

---

## Allow List for Terminal Commands

✅ **Applied:**

```
ssh git npm docker tmux brew node python pip curl wget cat ls mkdir cp mv rm chmod tail head grep find ps kill launchctl
```

---

## Deny List for Terminal Commands

✅ **Applied:**

```
rm -rf /
rm -rf ~
sudo rm -rf
shutdown
reboot
```

---

## How to Apply

### Option 1: Via Antigravity UI
1. Open Antigravity on TW Mac
2. Go to Settings (⌘,)
3. Apply each setting as listed above
4. Add Allow/Deny list entries

### Option 2: Via Settings File (if supported)
Check if Antigravity stores settings in:
```
~/Library/Application Support/Antigravity/settings.json
```

If so, the agent can edit directly.

---

## Verification

After applying, verify with:
```bash
# Check Antigravity is running
pgrep -fl Antigravity

# Check settings file (if accessible)
cat ~/Library/Application\ Support/Antigravity/User/settings.json 2>/dev/null | head -50
```

---

## Security Notes

These settings are appropriate for TW Mac because:
- ✅ Behind Tailscale VPN (encrypted)
- ✅ Only accessed via SSH from Controller Mac
- ✅ No direct user interaction
- ✅ Deny list prevents destructive commands
- ✅ Dedicated worker node, not primary workstation

**Do NOT apply these settings to a primary user workstation.**

---

## Rollback

If needed, reset to safe defaults:
- Terminal Command Auto Execution → **Request Review**
- Enable Terminal Sandbox → **ON**
- Agent Non-Workspace File Access → **OFF**

---

*Configuration guide for TW Mac Antigravity worker node*
*Part of clawdbot distributed infrastructure*
