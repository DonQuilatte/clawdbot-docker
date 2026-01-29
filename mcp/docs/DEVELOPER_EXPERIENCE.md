# Developer Experience: Automated Project Engagement

## What It Is

**Single command to submit background jobs to remote Claude instances with automatic notification on completion.**

- Job-based architecture (not raw tmux sessions)
- Structured results written to disk
- Push notifications (not polling)
- Automatic failure recovery
- Clean session lifecycle

## What It Is Not

- Not a replacement for interactive development
- Not infinitely parallel (respects system resources)
- Not a deployment system
- Not persistent across TW Mac reboots (jobs require manual restart)

---

## Developer Workflow

### Submit a Job

```bash
# Clone new repo and analyze
agy-project git@github.com:acme/payment-service.git "Review architecture and identify tech debt"

# Output:
# 🔹 Job ID: payment-service-20260129-093015
# 🔹 Project: payment-service
# 📤 SUBMITTED: Job payment-service-20260129-093015 submitted successfully
# 
# 📋 Quick commands:
#   Status:   agy-project status
#   Logs:     agy-project logs payment-service-20260129-093015
#   Result:   agy-project result payment-service-20260129-093015
#   Attach:   agy-project attach payment-service-20260129-093015
#
# 💡 You'll be notified when complete
```

**What happens:**
1. Job ID generated: `{project}-{timestamp}`
2. Job submitted to TW Mac
3. Background process handles clone, setup, environment, Claude session
4. You get macOS notification when complete
5. Structured result written to `~/Development/.agy-jobs/{job-id}/result.md`

---

### Check Status Anytime

```bash
agy-project status
```

```
╔══════════════════════════════════════════════════════════════════════════════╗
║ JOB ID               PROJECT         STATUS               LAST UPDATE     ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ payment-service-...  payment-servi   🔄 running           2026-01-29T09:  ║
║ auth-service-...     auth-service    ✅ completed         2026-01-29T08:  ║
║ billing-api-...      billing-api     ❌ failed            2026-01-29T08:  ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

**Job States:**
- `📤 submitted` - Job accepted, starting
- `🔄 running` - Claude actively working
- `✅ completed` - Task finished, result available
- `❌ failed` - Error occurred (see logs)
- `⏱️ timeout` - Exceeded 30 min (session still alive, may still complete)

---

### Get Structured Results

```bash
agy-project result payment-service-20260129-093015
```

```
╔══════════════════════════════════════════════════════════════════════════════╗
║ JOB RESULT
╠══════════════════════════════════════════════════════════════════════════════╣
Job ID: payment-service-20260129-093015
Project: payment-service
Status: completed
Started: 2026-01-29T09:30:15Z

# Architecture Review: payment-service

## Accomplished
- Analyzed 47 source files across 3 modules
- Identified 12 tech debt items
- Generated dependency graph

## Issues Encountered
- None

## Next Recommended Actions
1. Address high-priority tech debt in auth module
2. Update outdated dependencies (see deps.md)
3. Add integration tests for payment flow

## Detailed Findings
[... full analysis ...]

╚══════════════════════════════════════════════════════════════════════════════╝
```

---

### View Full Logs (If Needed)

```bash
agy-project logs payment-service-20260129-093015
```

Shows complete execution log including:
- Clone/setup output
- Environment validation
- Claude's full interaction
- Timestamps and status changes

---

### Attach to Live Session (Advanced)

```bash
agy-project attach payment-service-20260129-093015
```

Drops you into the live tmux session. Use `Ctrl-b d` to detach without killing.

---

## Parallel Execution

```bash
# Submit multiple jobs simultaneously
agy-project auth-service "audit security vulnerabilities"
agy-project billing-api "optimize database queries"
agy-project admin-dashboard "refactor legacy components"

# Walk away. macOS notifications will alert you as each completes.
```

**Resource Management:**
- Jobs run in parallel on TW Mac
- Monitor CPU/RAM with `~/bin/tw run 'top -l 1'`
- Kill jobs if needed: `agy-project attach <job-id>` then `Ctrl-b` `:kill-session`

---

## Local Development

For local work with full MCP stack:

```bash
agy-local payment-service
```

Opens project in Antigravity on **this Mac** with:
- MCP servers auto-loaded
- direnv environment active
- All credentials available

---

## Reliability & Recovery

### Scenario: Clone Fails (Bad Credentials)

```bash
agy-project git@github.com:private/repo.git "analyze"
```

```
📤 SUBMITTED: Job repo-20260129-093015 submitted successfully
💡 You'll be notified when complete
```

Later:
```
[macOS Notification]
Job repo-20260129-093015 failed
repo: Session crashed
```

Check what happened:
```bash
agy-project logs repo-20260129-093015 | tail -20

# Shows:
# ❌ FAILED: Git clone failed. Check credentials and repo URL.
```

**Resolution:** Fix SSH keys, retry with new job ID.

---

### Scenario: Dirty Working Tree

```bash
agy-project payment-service "refactor auth"
```

If project already exists with uncommitted changes:

```
❌ FAILED: Project exists with uncommitted changes. Commit or stash first.
```

**Resolution:** Go to TW Mac, commit/stash, resubmit.

---

### Scenario: Missing Environment Variables

Job completes but Claude couldn't push changes:

```bash
agy-project logs myapp-20260129-093015 | grep WARNING

# ⚠️  WARNING: Missing environment variables: GITHUB_TOKEN
```

**Resolution:** Update .envrc on TW Mac, direnv allow, retry.

---

### Scenario: Interactive Setup Script

project-setup.sh prompts for input (detected):

```
⚠️  WARNING: project-setup.sh appears interactive - may hang
```

Job times out after 60s:

```
⚠️  project-setup.sh failed or timed out after 60s
```

**Resolution:** Make project-setup.sh non-interactive or use flags for unattended mode.

---

### Scenario: 30-Minute Timeout

Large task exceeds 30 minutes:

```
[macOS Notification]
Job myapp-20260129-093015 timeout
myapp: Still running after 30min
```

Session is **still alive** - just wasn't marked complete. Options:

1. **Attach and check progress:**
   ```bash
   agy-project attach myapp-20260129-093015
   ```

2. **Let it continue** - may still complete and write result.md

3. **Kill if stuck:**
   ```bash
   agy-project attach myapp-20260129-093015
   # Ctrl-b :kill-session
   ```

---

## Security & Credentials

### What's Stored

**On TW Mac:**
- Git SSH keys (standard `~/.ssh/`)
- 1Password CLI integration
- direnv loads credentials from 1Password vaults
- No plaintext secrets in .envrc files

**Job Data:**
- Job logs: `~/Development/.agy-jobs/{job-id}/job.log`
- Results: `~/Development/.agy-jobs/{job-id}/result.md`
- Metadata: `~/Development/.agy-jobs/{job-id}/meta.json`

**What's Never Persisted:**
- 1Password master password (Touch ID only)
- API tokens in plaintext (vault references only)
- SSH private keys outside standard locations

### Shared Documents Safety

Jobs create files in the project directory. **Never commit:**
- API keys
- Tokens
- Credentials

Add to `.gitignore`:
```
.env
.envrc
**/secrets/
*.key
*.pem
```

Claude is instructed to write results to `$AGY_JOB_DIR`, not the project root.

---

## Limitations & Constraints

### Session Lifecycle

- Jobs survive SSH disconnects
- Jobs do **not** survive TW Mac restarts
- No automatic retry on failure (manual resubmit)

### Concurrency

- No hard limit on parallel jobs
- Monitor TW Mac resources manually
- Consider queueing if >5 concurrent jobs

### Rate Limits

- GitHub API: standard per-user limits
- Claude API: per-account limits
- No automatic backoff (handle manually)

### Result Retention

- Job data kept indefinitely in `~/Development/.agy-jobs/`
- Manual cleanup: `rm -rf ~/Development/.agy-jobs/{old-job-id}`
- Consider weekly cleanup cron job

---

## Notifications

### macOS

Automatic notification on completion/failure/timeout.

### Slack (Optional)

Set in .envrc:
```bash
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

Jobs will post to Slack channel on state changes.

---

## Comparison to Manual Workflow

| Aspect | Manual (Before) | Automated (After) |
|--------|----------------|-------------------|
| **Setup Time** | 2-3 min (multiple commands) | 5 sec (one command) |
| **Status Checking** | `tmux capture-pane` + tail | `agy-project status` |
| **Result Retrieval** | Parse tmux scrollback | `agy-project result` |
| **Notifications** | Manual polling | Push notifications |
| **Error Recovery** | Debug tmux session | Structured logs + state |
| **Session Management** | Manual tmux commands | Automatic lifecycle |
| **Parallel Jobs** | Manual tracking | Table view all jobs |
| **Completion Detection** | Guess from output | Explicit JOB_COMPLETE marker |

---

## Quick Reference

```bash
# Submit job
agy-project <repo-url-or-name> "<task>"

# Check all jobs
agy-project status

# Get result
agy-project result <job-id>

# View logs
agy-project logs <job-id>

# Attach to session
agy-project attach <job-id>

# Open locally
agy-local <project-name>
```

---

## Next Steps

1. Deploy scripts to TW Mac (see deployment guide)
2. Test with sample project
3. Configure Slack webhook (optional)
4. Set up weekly job cleanup cron
