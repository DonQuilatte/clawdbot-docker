# Task: Apply Antigravity Worker Node Settings

**Priority:** High
**Target:** This Mac (TW Mac)
**Purpose:** Configure Antigravity for headless AI worker operations

---

## Instructions

Please apply the following settings changes in Antigravity. Open Settings (⌘,) and configure:

### 1. Terminal Command Auto Execution
- Set to: **Always Proceed**
- Location: Settings → Terminal Command Auto Execution dropdown

### 2. Enable Terminal Sandbox
- Set to: **OFF** (toggle off)
- This allows full system access needed for worker operations

### 3. Agent Auto-Fix Lints
- Set to: **ON** (toggle on)
- Location: Settings → Automation section

### 4. Auto-Continue
- Set to: **ON** (toggle on)
- Keeps long-running tasks going without prompts

### 5. Explain and Fix in Current Conversation
- Set to: **ON** (toggle on)
- Location: Settings → General section

### 6. Enable Sounds for Agent
- Set to: **OFF** (toggle off)
- No audio needed for headless worker

### 7. Allow List Terminal Commands
Add these commands to the Allow List:
```
ssh
git
npm
node
docker
tmux
brew
python
pip
curl
wget
```

### 8. Deny List Terminal Commands
Add these commands to the Deny List for safety:
```
rm -rf /
rm -rf ~
sudo rm -rf
shutdown
reboot
```

---

## Verification

After applying settings, confirm by:
1. Check Terminal Auto Execution shows "Always Proceed"
2. Verify Terminal Sandbox is OFF
3. Confirm Agent Auto-Fix Lints is ON
4. Verify Auto-Continue is ON

---

## Context

This TW Mac is configured as a **dedicated worker node** in the clawdbot distributed infrastructure:
- Behind Tailscale VPN (encrypted)
- Controlled from jeds-macbook-pro via SSH
- No direct user interaction expected
- These settings enable autonomous operation

---

## After Completion

Reply with confirmation that settings have been applied, or list any settings that could not be changed.
