# MCP Environment Deployment & Adoption Plan

## **Overview**

This deployment plan covers rolling out production-ready MCP (Model Context Protocol) environment management across your organization. The solution provides:

- ✅ Workspace-scoped MCP configurations per project
- ✅ Secure credential management via 1Password CLI
- ✅ Automatic context switching with direnv
- ✅ Cross-IDE support (Cursor, VS Code, Antigravity)
- ✅ Zero-secrets-on-disk architecture

**Total deployment time:** 1-2 days for full organization rollout

---

## **PHASE 1: PREPARE (Day 1, Morning - 2 hours)**

### **1.1 Package Deployment Assets**

```bash
# Clone or create deployment repo
git clone <deployment-repo>
cd mcp-deployment

# Verify structure
tree -L 2
```

Expected structure:
```
mcp-deployment/
├── README.md
├── docs/
│   ├── DEPLOYMENT.md        # This file
│   ├── SETUP_GUIDE.md
│   └── TROUBLESHOOTING.md
├── scripts/
│   ├── global-setup.sh
│   ├── project-setup.sh
│   └── validate-setup.sh
└── examples/
    ├── clawdbot/
    └── data-science/
```

### **1.2 Create Organizational 1Password Vaults**

Set up vault structure in 1Password:

```
Development Vault (Team)
├── GitHub Token              # credential: ghp_xxx
├── GitKraken Token          # credential: gk_xxx
├── OpenAI API Key           # api_key: sk-xxx
└── Docker Registry Token    # api_key: dckr_xxx

Production Vault (Team)
├── Production API Keys
└── Service Account Tokens

Personal Vault (Individual)
└── Personal development tokens
```

**Action:** Create these vaults and populate with initial credentials.

### **1.3 Test on Pilot Machine**

Run full setup on your machine:

```bash
# Global setup
cd mcp-deployment
bash scripts/global-setup.sh

# Reload shell
exec zsh

# Test authentication
op whoami

# Project setup (test repo)
cd ~/Development/clawdbot
bash ~/mcp-deployment/scripts/project-setup.sh clawdbot

# Validate
bash ~/mcp-deployment/scripts/validate-setup.sh
```

**Success criteria:** All validation tests pass

---

## **PHASE 2: PILOT ROLLOUT (Day 1, Afternoon - 3 hours)**

### **2.1 Select Pilot Team**

Choose 2-3 team members for initial rollout:

- ✅ Mix of experience levels
- ✅ Different projects/repos
- ✅ At least one Cursor user, one VS Code user

### **2.2 Pilot Team Onboarding**

**Per pilot team member:**

1. Share deployment repo access
2. Schedule 30-min pairing session
3. Walk through global setup together
4. Walk through project setup on their primary repo
5. Validate setup works
6. Collect feedback

**Onboarding script:**
```bash
# Pilot member runs
git clone <deployment-repo>
cd mcp-deployment

# Global setup (10 min)
bash scripts/global-setup.sh
exec zsh

# Enable 1Password CLI integration
# Settings → Developer → CLI → Enable

# Test auth
op whoami

# Project setup (15 min)
cd ~/Development/<their-project>
bash ~/mcp-deployment/scripts/project-setup.sh

# Edit .envrc with their 1Password refs
# Update op:// references

# Validate
bash ~/mcp-deployment/scripts/validate-setup.sh

# Test in IDE
open -a Cursor .  # or VS Code
```

### **2.3 Collect Pilot Feedback**

Create feedback form:

- How long did setup take?
- Any errors encountered?
- Does environment switching work?
- Are MCP servers loading correctly?
- Documentation clarity (1-10)?
- Would you recommend to team? (Yes/No/Maybe)

**Action:** Iterate on scripts/docs based on feedback

---

## **PHASE 3: TEAM ROLLOUT (Day 2, Full Day)**

### **3.1 Create Internal Documentation**

Publish to company wiki/Notion:

**Quick Start Guide** (1-page):
```markdown
# MCP Environment Setup - Quick Start

## Prerequisites
- macOS with Homebrew
- 1Password app installed
- Access to Development vault

## Setup (20 minutes)

1. Clone deployment repo
2. Run global-setup.sh
3. Reload shell
4. Run project-setup.sh in each repo
5. Test with validate-setup.sh

## Support
- Slack: #dev-tools-support
- Documentation: <wiki-link>
- Issue tracker: <jira-link>
```

### **3.2 Schedule Rollout Sessions**

**Option A: Office Hours** (Recommended)
- 2-hour blocks over 2 days
- Team members drop in for assistance
- Run 4 sessions to cover 20-30 people

**Option B: Team Presentations**
- 1-hour group demo + Q&A
- Record session for async viewers
- Follow-up 1:1 support as needed

### **3.3 Phased Rollout Schedule**

**Day 2, Morning (9am-12pm):**
- Office hours: 9-11am
- Team A (10 people) onboards
- Immediate support available

**Day 2, Afternoon (1pm-5pm):**
- Office hours: 2-4pm
- Team B (10 people) onboards
- Document common issues

**Day 3+ (Optional):**
- Async onboarding for remaining team
- Recorded video available
- Slack support channel active

---

## **PHASE 4: PROJECT MIGRATION (Ongoing)**

### **4.1 Prioritize Projects**

Rank repositories by:
1. Active development frequency
2. Number of contributors
3. Existing MCP usage
4. Security sensitivity

**Example priority:**
```
High Priority:
- clawdbot (active, 5 contributors)
- data-platform (active, 8 contributors)

Medium Priority:
- internal-tools (2 contributors)
- automation-scripts (1 contributor)

Low Priority:
- archived-projects (no active dev)
```

### **4.2 Per-Project Migration**

For each project:

```bash
# 1. Create feature branch
cd ~/Development/<project>
git checkout -b feat/mcp-environment-setup

# 2. Run project setup
bash ~/mcp-deployment/scripts/project-setup.sh

# 3. Customize .envrc for project needs
vim .envrc
# Update op:// references
# Add project-specific env vars

# 4. Customize MCP configs
vim .cursor/mcp.json
# Add/remove MCP servers as needed

# 5. Test locally
direnv allow
bash ~/mcp-deployment/scripts/validate-setup.sh
open -a Cursor .  # Verify MCP servers load

# 6. Commit and PR
git add .envrc scripts/ .cursor/ .vscode/ .gitignore
git commit -m "Add production-ready MCP environment config"
git push origin feat/mcp-environment-setup

# Create PR with checklist:
# - [ ] .envrc configured
# - [ ] Wrapper scripts present
# - [ ] MCP configs for Cursor/VS Code
# - [ ] .gitignore updated
# - [ ] Local testing passed
# - [ ] Documentation updated
```

### **4.3 Project Checklist**

Track migration status:

| Project | Priority | Owner | Status | PR Link | Notes |
|---------|----------|-------|--------|---------|-------|
| clawdbot | High | You | ✅ Complete | #123 | - |
| data-platform | High | Alice | 🔄 In Progress | #124 | - |
| internal-tools | Medium | Bob | 📋 Planned | - | Waiting on vault access |

---

## **PHASE 5: MONITOR & SUPPORT (Week 1-2)**

### **5.1 Support Channels**

**Slack Channel:** `#mcp-environment-support`

Auto-responder template:
```
Common issues:

1. "1Password CLI not authenticated"
   → Enable CLI integration in 1Password app settings

2. "direnv: permission denied"
   → Run: direnv allow

3. "MCP servers not loading"
   → Check: ./scripts/mcp-* are executable
   → Run: chmod +x scripts/mcp-*

4. "Environment not switching between projects"
   → Reload: direnv reload
   → Check: direnv status

For other issues, ping @your-name or create ticket: <link>
```

### **5.2 Monitoring Metrics**

Track adoption:

```bash
# Create adoption dashboard
Metrics to track:
- Team members onboarded: X / Y
- Projects migrated: X / Y  
- Support tickets opened: X
- Setup time (avg): X minutes
- Satisfaction score: X / 10
```

### **5.3 Common Issues Resolution**

Document solutions as they arise:

| Issue | Solution | Frequency |
|-------|----------|-----------|
| 1Password Touch ID not working | Restart 1Password app | High |
| direnv not loading automatically | Add hook to ~/.zshrc | Medium |
| MCP servers showing as "disconnected" | Restart IDE after direnv changes | High |
| Secrets not resolving | Check vault access permissions | Low |

---

## **PHASE 6: OPTIMIZATION (Week 2-4)**

### **6.1 Team-Specific Customizations**

Create templates for common patterns:

**Backend Team:**
```bash
# .envrc additions
op_export DATABASE_URL "op://Development/Postgres/connection_string"
op_export REDIS_URL "op://Development/Redis/url"
```

**Frontend Team:**
```bash
# .envrc additions
op_export VITE_API_URL "op://Development/API/url"
op_export SENTRY_DSN "op://Development/Sentry/dsn"
```

### **6.2 Advanced Features**

**Multi-environment support:**
```bash
# .envrc
if [ -f .envrc.local ]; then
  source_env .envrc.local
fi

case "${ENV:-dev}" in
  dev)
    op_export API_KEY "op://Development/API/key"
    ;;
  staging)
    op_export API_KEY "op://Staging/API/key"
    ;;
  prod)
    op_export API_KEY "op://Production/API/key"
    ;;
esac
```

### **6.3 CI/CD Integration**

**GitHub Actions example:**
```yaml
name: CI
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Load secrets
        uses: 1password/load-secrets-action@v1
        with:
          export-env: true
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
          GITHUB_TOKEN: op://Development/GitHub Token/credential
          
      - name: Run tests
        run: npm test
```

---

## **SUCCESS CRITERIA**

### **Week 1:**
- ✅ 80% of active developers onboarded
- ✅ Top 5 priority projects migrated
- ✅ <5 support tickets per day
- ✅ Avg setup time <25 minutes

### **Week 2:**
- ✅ 100% of active developers onboarded
- ✅ All active projects migrated
- ✅ <2 support tickets per day
- ✅ Team satisfaction >8/10

### **Month 1:**
- ✅ Zero plaintext secrets in repos
- ✅ Standardized MCP config across projects
- ✅ CI/CD integration complete
- ✅ Documentation finalized

---

## **ROLLBACK PLAN**

If critical issues arise:

### **Individual Rollback:**
```bash
# Remove direnv hook
vim ~/.zshrc  # Delete direnv hook line

# Restore old workflow
export GITHUB_TOKEN="<your-token>"  # In shell rc

# Remove project config
rm -rf .envrc scripts/.mcp-*
git restore .
```

### **Project Rollback:**
```bash
# Revert PR
git revert <commit-hash>

# Or restore from backup
git checkout main -- .envrc scripts/ .cursor/ .vscode/
```

### **Team Rollback:**
- Keep old workflow documented as fallback
- Maintain both systems during transition period
- Set rollback deadline (e.g., Week 4)

---

## **TIMELINE SUMMARY**

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| **Prepare** | 2 hours | Tested deployment package |
| **Pilot** | 3 hours | 2-3 users validated |
| **Rollout** | 1 day | 20-30 users onboarded |
| **Migration** | 1-2 weeks | Projects migrated |
| **Support** | 2 weeks | Documentation refined |
| **Optimize** | 2-4 weeks | Advanced patterns adopted |

**Total:** 4-6 weeks for complete organizational adoption

---

## **QUICK REFERENCE**

### **Setup Commands:**
```bash
# Global (once per machine)
bash scripts/global-setup.sh && exec zsh

# Project (once per repo)
bash scripts/project-setup.sh <project-name>

# Validate
bash scripts/validate-setup.sh
```

### **Daily Usage:**
```bash
# Switch projects (automatic)
cd ~/Development/project-a  # Loads project-a env
cd ~/Development/project-b  # Loads project-b env

# Reload environment
direnv reload

# Check status
direnv status
echo $PROJECT_NAME
```

### **Troubleshooting:**
```bash
# Auth issues
op whoami
op signin

# Permission issues
direnv allow

# Script issues
chmod +x scripts/mcp-*
```

---

## **CONTACT & SUPPORT**

- **Deployment Lead:** [Your Name]
- **Slack Channel:** #mcp-environment-support
- **Documentation:** [Wiki Link]
- **Issue Tracker:** [Jira Link]

---

**Last Updated:** 2026-01-28
**Version:** 1.0.0
