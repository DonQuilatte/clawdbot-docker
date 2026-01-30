# Dependabot Auto-Merge System

Maximum automation for dependency updates with safe rollback.

## What it does

- **Auto-merges**: patches, minors, and GitHub Actions updates when CI passes
- **Blocks**: major version updates (manual review required)
- **Rolls back**: failed merges automatically with issue creation
- **Reports**: CLI triage tool shows what needs attention

## Setup

1. Deploy to a repo:
```bash
./scripts/deploy-dependabot.sh /path/to/repo
```

2. Update rollback workflow:
   - Edit `.github/workflows/dependabot-rollback.yml`
   - Change `workflows: ["CI"]` to your actual CI workflow name

3. Commit and push

## Usage

Check status anytime:
```bash
bun run scripts/dependabot-triage.ts
```

Shows:
- 🚨 Major versions needing manual review
- ❌ Failed CI requiring fixes
- ⏳ Auto-merging queue

## Files

- `templates/dependabot/dependabot.yml` - Dependabot config
- `templates/dependabot/auto-merge.yml` - Auto-merge workflow
- `templates/dependabot/rollback-failed.yml` - Rollback workflow
- `scripts/dependabot-triage.ts` - Status dashboard
- `scripts/deploy-dependabot.sh` - Deployment script

## Safety

Auto-merge only when:
- Update type is patch or minor
- All CI checks pass
- Not a major version

If merged update breaks CI:
- Commit auto-reverts
- Issue created with details
- You're notified next triage run

## Maintenance

Zero daily maintenance unless:
- Major version released → manual review
- CI fails → investigate and fix

Everything else merges automatically.
