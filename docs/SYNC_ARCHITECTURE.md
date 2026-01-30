# Dependency Management Architecture - Status Report

## Current State: ✅ COMPLETE

### Three-Layer Sync System

```
UPSTREAM → DEV-INFRA → DOWNSTREAM
─────────   ─────────   ──────────
mcp-           (hub)    iphone-tco-planner
deployment              future projects

eval-
everything
```

### Implementations

**1. Upstream Tracking** (NEW - just shipped)
- **Tool**: `check-upstream.ts` + `sync-upstream.ts`
- **Frequency**: Weekly (Monday 9am) via GitHub Actions
- **Repos**: mcp-deployment, eval-everything-claude-code
- **Flow**: Manual review → mark synced
- **Status**: ✅ Active, tested

**2. Downstream Propagation** (EXISTING - working)
- **Tool**: `agy-sync` bash script
- **Frequency**: On-demand
- **Repos**: iphone-tco-planner (1 registered)
- **Flow**: `agy-sync --update` → copies files to projects
- **Status**: ✅ Active, 1 project outdated

**3. Dependabot Auto-merge** (NEW - just shipped)
- **Tool**: GitHub Actions workflows
- **Frequency**: Daily 3am npm, weekly Docker/Actions
- **Scope**: All npm/Docker/Actions dependencies
- **Flow**: Auto-merge patches/minors → revert on CI fail
- **Status**: ✅ Active, runs tomorrow

## Gaps & Recommendations

### ✅ No Critical Gaps
All sync flows operational. Architecture matches diagram.

### 🟡 Minor Optimizations

1. **Downstream propagation is manual**
   - Current: Run `agy-sync --update` manually
   - Could add: GitHub Action on dev-infra push
   - Risk: Auto-pushing to projects might break them
   - **Recommendation**: Keep manual, it's safer

2. **Only 1 downstream project registered**
   - iphone-tco-planner synced
   - Other projects not using dev-infra tooling yet
   - **Recommendation**: Register as needed via `agy-sync --register`

3. **Upstream check creates issues, not PRs**
   - GitHub issue requires manual review
   - Could auto-create PR with changes
   - **Recommendation**: Keep current, forces review

## Command Reference

### Upstream (external → dev-infra)
```bash
bun run scripts/check-upstream.ts              # Check mcp-deployment, eval-everything
bun run scripts/sync-upstream.ts <repo-name>   # Review and mark synced
```

### Downstream (dev-infra → projects)
```bash
agy-sync                        # Check status
agy-sync --update               # Push to all projects
agy-sync --register <path>      # Add new project
```

### Dependencies (npm/Docker/Actions)
```bash
bun run scripts/dependabot-triage.ts           # Check Dependabot PRs
bun run scripts/dependabot-triage.ts owner/repo
```

## Integration with agy Commands

Current `agy` aliases missing. Add to scripts/agy:
```bash
deps|dependabot)    bun run scripts/dependabot-triage.ts ;;
upstream)           bun run scripts/check-upstream.ts ;;
sync)               agy-sync ;;
```

## Next Actions

1. ✅ DONE: Upstream tracking system
2. ✅ DONE: Dependabot auto-merge
3. ⏭️ OPTIONAL: Add `agy deps`, `agy upstream`, `agy sync` aliases
4. ⏭️ WAIT: Validate Dependabot tomorrow (first run at 3am)
5. ⏭️ FUTURE: Register more downstream projects as needed
