# Alignment Plan: Current Scripts → New Architecture

## Current State (Committed)

**3 scripts in clawdbot/scripts/:**
- `agy` - Router (local by default, -r for remote)
- `agy-local` - Local execution (starts `claude` CLI)
- `agy-project` - Remote execution (tmux + claude on TW Mac)

**Strengths:**
- ✅ Security hardened (sanitization, escaping, polling)
- ✅ Simple interface
- ✅ Works today

**Gaps:**
- ❌ No job tracking
- ❌ No notifications
- ❌ No structured results
- ❌ Manual log scraping (tmux capture-pane)
- ❌ No completion detection

---

## New Architecture (Proposed)

**Job-based system with:**
- Job IDs + metadata
- Structured results (result.md)
- Push notifications
- Status tracking
- Auto-completion detection

---

## Migration Path

### Phase 1: Backward Compatible Enhancement (THIS WEEK)

**Keep existing interface, add features internally:**

```bash
# Existing usage still works
agy-project myapp "do something"

# But now you can also:
agy-project status          # New: view all jobs
agy-project logs <job-id>   # New: structured logs
agy-project result <job-id> # New: get result.md
```

**Files to update:**

1. **`scripts/agy`** - No changes needed (router works as-is)

2. **`scripts/agy-project`** - Enhanced version:
   - Add subcommand handling (status/logs/result/attach)
   - Wrap execution in job infrastructure
   - Generate job IDs
   - Create metadata files
   - Send notifications
   - Keep all existing security (sanitization, escaping, polling)

3. **`scripts/agy-local`** - No changes needed for now

4. **NEW: `scripts/agy-jobs`** - Job management utility (runs on TW Mac):
   - `agy-jobs status` - List all jobs
   - `agy-jobs logs <id>` - Show job.log
   - `agy-jobs result <id>` - Show result.md

5. **NEW: `scripts/agy-notify`** - Notification helper:
   - macOS notifications
   - Optional Slack webhooks

### Phase 2: Zero-Command Integration (NEXT WEEK)

Add Antigravity IDE integration:

1. **NEW: `scripts/agy-auto-setup`** - Auto-runs on project open
2. **NEW: `.antigravity/config.json`** - Project config template
3. **UPDATE: `scripts/project-setup.sh`** - Add Antigravity hooks

### Phase 3: Full Adoption (ONGOING)

Roll out to team with documentation and training.

---

## Implementation Steps (Today)

### Step 1: Deploy Support Scripts to TW Mac

```bash
# Copy notification script
scp ~/bin/agy-notify tw-mac:~/bin/

# Copy job management script  
scp ~/bin/agy-jobs tw-mac:~/bin/

# Make executable
ssh tw-mac "chmod +x ~/bin/agy-{notify,jobs}"
```

### Step 2: Update agy-project in clawdbot

Replace `clawdbot/scripts/agy-project` with enhanced version that:
- Preserves all existing functionality
- Adds job tracking
- Adds subcommands (status/logs/result)
- Generates job IDs
- Creates metadata
- Sends notifications

### Step 3: Test Migration

```bash
cd ~/Development/Projects/clawdbot

# Test old interface (should work as before)
./scripts/agy-project clawdbot "analyze the codebase"

# Test new features
./scripts/agy-project status
./scripts/agy-project logs clawdbot-20260129-xxx
```

### Step 4: Commit Enhanced Version

```bash
cd ~/Development/Projects/clawdbot
git add scripts/agy-project scripts/agy-jobs scripts/agy-notify
git commit -m "feat(scripts): enhance agy-project with job tracking and notifications"
git push
```

---

## Comparison: Before vs After

### Before (Current)
```bash
$ agy-project myapp "analyze"
=== AntiGravity Project Setup ===
✓ Project found
✓ Session created
=== Session Ready ===
Quick commands:
  View output: ~/bin/tw run 'tmux capture-pane -t myapp -p | tail -50'
  Attach: ~/bin/tw tmux
```

You manually check output, manually determine if complete.

### After (Enhanced)
```bash
$ agy-project myapp "analyze"
=== Submitting Job ===
Job ID: myapp-20260129-153045
Project: myapp
✓ Job submitted

Quick commands:
  Status:   agy-project status
  Logs:     agy-project logs myapp-20260129-153045
  Result:   agy-project result myapp-20260129-153045
  Attach:   agy-project attach myapp-20260129-153045

[15 minutes later, macOS notification]
"Job myapp-20260129-153045 completed"

$ agy-project result myapp-20260129-153045
╔══════════════════════════════════════╗
║ JOB RESULT
╠══════════════════════════════════════╣
Job ID: myapp-20260129-153045
Status: completed

[structured result.md content]
╚══════════════════════════════════════╝
```

---

## Developer Experience: What Changes?

### Old Way
```bash
agy myapp                # Opens local claude CLI
agy -r myapp "task"      # Starts remote tmux session
# Then manually monitor tmux
```

### New Way (Same Commands + More)
```bash
agy myapp                # Still opens local claude CLI (unchanged)
agy -r myapp "task"      # Still starts remote (but now tracked as job)
agy -r status            # NEW: See all jobs
agy -r result <job-id>   # NEW: Get structured results
```

**Key point:** All existing usage patterns still work. New features are additive.

---

## Recommendation

**Implement Phase 1 today:**

1. Copy my `agy-project-secure` logic into `clawdbot/scripts/agy-project`
2. Keep all existing security hardening
3. Add job tracking features
4. Deploy support scripts to TW Mac
5. Test and commit

**Benefits:**
- ✅ Backward compatible
- ✅ Immediate value (notifications, status tracking)
- ✅ No workflow disruption
- ✅ Foundation for Phase 2 (zero-command)

**Risk:** Low - existing interface unchanged, new features opt-in.
