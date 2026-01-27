# 🤖 TW Node: Pair Programmer Upgrade Plan

**Objective:** Transform the remote node `TW` (192.168.1.245) from a basic node into a fully capable Pair Programming collaborator.
**Target Status:** "Developer Ready"
**Architecture:** macOS (Intel/x86_64)

---

## 📊 Revised Current State (Verified)

| Component        | Status           | Missing Items                  |
| ---------------- | ---------------- | ------------------------------ |
| **Foundation**   | ✅ **Installed** | Homebrew (v5.0.1)              |
| **Runtime**      | ✅ **Installed** | Node.js (v24 via NVM)          |
| **AI Toolkit**   | ✅ **Installed** | Claude Code (v2.1)             |
| **Collab Tools** | ⚠️ Partial       | **Missing `gh` (GitHub CLI)**  |
| **Identity**     | ❌ Unconfigured  | Git `user.name` / `user.email` |
| **Containers**   | ❌ Missing       | Docker                         |

---

## 🛠️ Final Implementation Plan

### Phase 1: Containerization (OrbStack)

We will use **OrbStack** as the Docker provider. It is lightweight, fast, and drop-in compatible with Docker CLI.

- **Action:** `brew install orbstack`
- **Config:** `orbstack config set autostart true`

### Phase 2: AI & Dev Toolkit

We will install the standard collaborative toolset plus the requested specific AI CLIs.

- **Version Control:** `gh` (GitHub CLI)
- **AI CLIs:**
  - `codex-cli` (CodeX tools)
  - `gemini-cli` (Google Gemini tools)
  - `kilocode` (Kilocode tools)
  - _Note: These will be installed via Homebrew. If proprietary/private taps are needed, they must be added first._

### Phase 3: Identity & Ops

- **Git Identity:**
  - Name: `Don Quilatte`
  - Email: `roller-erasers.0b@icloud.com`

---

## 🚀 Execution Script: `scripts/install-orbstack-remote.sh`

A single unified script has been created to perform these actions over SSH.

**Usage:**

```bash
./scripts/install-orbstack-remote.sh
```

**Verification Steps:**
After running the script, verify the remote node:

1.  Git Config: `ssh tw "git config --global -l"`
2.  Docker/OrbStack: `ssh tw "docker ps"`
3.  CLIs: `ssh tw "which codex gemini kilocode"`

---

## 🔧 User Action Required

Run the installation script to upgrade the remote node:

```bash
~/Development/Projects/clawdbot/scripts/install-orbstack-remote.sh
```

### Step 2: Authentication Handover

- **GitHub:** We need to pass a `GH_TOKEN` to the remote machine so `gh` can authenticate non-interactively.
- **Claude:** We need to authenticate `claude` code, likely by passing session tokens or running `claude login` interactively once.

### Step 3: IDE Remote Access

- **VS Code Remote SSH:** You (on the Macbook) already have SSH access.
- **Recommendation:** Install the "Remote - SSH" extension in your local VS Code. You can then open folders on TW directly.
- **Cursor/Windsurf:** Similar "Remote SSH" capability is recommended over installing the GUI app on the headless/remote machine purely for editing.

---

## ✅ Success Criteria

1.  [ ] `node -v` returns v20+
2.  [ ] `gh auth status` returns "Logged in"
3.  [ ] `claude --version` returns version info
4.  [ ] Remote Git commits are correctly attributed

---

## 📝 Next Steps for User

1.  **Approve** this plan.
2.  **Provide Identity Details**:
    - What Name/Email should git use on TW?
    - Do you have a GitHub Personal Access Token availability for the `gh` login?
3.  **Execute**: I will write the installer script and run it via Clawdbot.
