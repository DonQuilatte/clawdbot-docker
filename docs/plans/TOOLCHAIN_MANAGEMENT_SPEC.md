# Toolchain Management System Specification

> Version: 1.0-draft
> Status: Review
> Date: 2026-01-30

## Overview

Automated toolchain management for dev-infra covering version tracking, auto-updates with rollback, documentation monitoring, dependency triage, and AI-powered PR review evaluation.

---

## 1. Tool Manifest

### Scope (Full Stack)

| Category | Examples | Source |
|----------|----------|--------|
| CLI Tools | claude, gh, direnv, bun, node | Homebrew, npm global |
| npm Packages | All dependencies | package.json |
| Docker Images | Base images, MCP containers | docker-compose.yml |
| MCP Servers | context7, filesystem, etc. | .mcp.json, .claude/mcp.json |
| GitHub Actions | checkout, setup-node, etc. | .github/workflows/*.yml |

### Manifest Format

```json
// config/toolchain-manifest.json
{
  "version": "1.0",
  "lastChecked": "2026-01-30T10:00:00Z",
  "tools": {
    "cli": {
      "claude": { "current": "1.0.17", "latest": null, "source": "npm", "autoUpdate": true },
      "gh": { "current": "2.45.0", "latest": null, "source": "homebrew", "autoUpdate": true }
    },
    "npm": {
      "dependencies": { /* extracted from package.json */ },
      "devDependencies": { /* extracted from package.json */ }
    },
    "docker": {
      "node:22-alpine": { "current": "22.1.0", "latest": null, "autoUpdate": true }
    },
    "mcp": {
      "@upstash/context7-mcp": { "current": "latest", "autoUpdate": true }
    },
    "actions": {
      "actions/checkout": { "current": "v4", "latest": null, "autoUpdate": true }
    }
  }
}
```

### Commands

```bash
# Check manifest status
agy manifest              # Show all tools with update status

# Update manifest from sources
agy manifest sync         # Scan sources, update current versions

# Check for available updates
agy manifest check        # Compare current vs latest
```

---

## 2. Auto-Update System

### Update Policy: Full Auto with Rollback

| Version Type | Action | Rollback |
|--------------|--------|----------|
| Patch (x.x.X) | Auto-update | Auto-revert on CI fail |
| Minor (x.X.0) | Auto-update | Auto-revert on CI fail |
| Major (X.0.0) | Notify only | N/A (manual) |

### Daily Check Flow

```
┌─────────────────────────────────────────────────────────────┐
│  Daily (6 AM)                                               │
├─────────────────────────────────────────────────────────────┤
│  1. Run `agy manifest check`                                │
│  2. For each update:                                        │
│     - Patch/Minor → Create update branch, run CI            │
│     - Major → Skip, add to triage queue                     │
│  3. If CI passes → Auto-merge to main                       │
│  4. If CI fails → Revert, create GitHub issue               │
└─────────────────────────────────────────────────────────────┘
```

### Rollback Mechanism

```yaml
# .github/workflows/auto-rollback.yml
on:
  workflow_run:
    workflows: ["CI"]
    types: [completed]
    branches: [main]

jobs:
  rollback:
    if: ${{ github.event.workflow_run.conclusion == 'failure' }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 2
      - name: Revert last commit
        run: |
          git revert HEAD --no-edit
          git push
      - name: Create issue
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: 'Auto-update failed - reverted',
              body: 'CI failed after auto-merge. Commit reverted automatically.',
              labels: ['auto-update', 'needs-review']
            })
```

---

## 3. Context7 Documentation Monitoring

### Current Libraries (from .mcp.json)

- clawdbot, clawdbot-repo
- docker, docker-compose, docker-mcp-toolkit, docker-desktop-mac
- claude-code
- gemini
- openai-codex
- 1password-cli
- antigravity-ide

### Monitoring Flow

```
┌─────────────────────────────────────────────────────────────┐
│  Weekly Check                                               │
├─────────────────────────────────────────────────────────────┤
│  1. Query Context7 API for each library                     │
│  2. Compare snippet counts / last_updated timestamps        │
│  3. If changed:                                             │
│     - Fetch diff summary                                    │
│     - Assess impact (breaking changes, new features)        │
│     - Add to docs/context7-changelog.md                     │
│  4. Flag high-impact changes for review                     │
└─────────────────────────────────────────────────────────────┘
```

### Commands

```bash
# Check for doc updates
agy docs check            # Compare cached vs current Context7

# Show recent changes
agy docs changelog        # Display recent doc updates

# Assess specific library
agy docs assess claude-code   # Detailed analysis of changes
```

### Assessment Criteria

| Signal | Weight | Description |
|--------|--------|-------------|
| Breaking changes | High | API/CLI changes that affect our code |
| New features | Medium | Capabilities we might adopt |
| Bug fixes | Low | Informational only |
| New topics | Medium | Expanding library coverage |

---

## 4. Dependabot Integration

### Configuration

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "daily"
    groups:
      patches:
        patterns: ["*"]
        update-types: ["patch"]
      minors:
        patterns: ["*"]
        update-types: ["minor"]
    ignore:
      - dependency-name: "*"
        update-types: ["version-update:semver-major"]

  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

### Auto-Merge Workflow

```yaml
# .github/workflows/dependabot-auto-merge.yml
name: Dependabot Auto-merge
on: pull_request

permissions:
  contents: write
  pull-requests: write

jobs:
  auto-merge:
    runs-on: ubuntu-latest
    if: github.actor == 'dependabot[bot]'
    steps:
      - name: Fetch metadata
        id: metadata
        uses: dependabot/fetch-metadata@v2
        with:
          github-token: "${{ secrets.GITHUB_TOKEN }}"

      - name: Auto-merge patches and minors
        if: steps.metadata.outputs.update-type != 'version-update:semver-major'
        run: gh pr merge --auto --squash "$PR_URL"
        env:
          PR_URL: ${{ github.event.pull_request.html_url }}
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Comment on majors
        if: steps.metadata.outputs.update-type == 'version-update:semver-major'
        run: |
          gh pr comment "$PR_URL" --body "⚠️ Major version update - manual review required"
        env:
          PR_URL: ${{ github.event.pull_request.html_url }}
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Triage Command

```bash
# Check Dependabot status
agy dependabot            # Show PRs needing attention

# Output:
# Major Updates (manual review):
#   - PR #42: bump typescript from 4.x to 5.x
#   - PR #45: bump node from 20 to 22
#
# Auto-merging (3 PRs):
#   - lodash 4.17.20 → 4.17.21
#   - ...
#
# Failed CI (fix required):
#   - PR #43: bump eslint...
```

---

## 5. Greptile Evaluation

### What is Greptile?

AI-powered PR reviewer focused on codebase-context feedback:
- Understands broader codebase, not just the diff
- Posts PR comments/summaries via GitHub App
- Focuses on bugs, edge cases, architectural issues

### Evaluation Criteria

| Criteria | Weight | Notes |
|----------|--------|-------|
| Context awareness | High | Must understand our bash/node/docker stack |
| False positive rate | High | Noisy tools get ignored |
| Integration effort | Medium | GitHub App install vs custom setup |
| Cost | Medium | Per-repo or per-seat pricing |
| Privacy | High | What code is sent where? |

### Trial Plan

1. **Week 1**: Install on dev-infra only
2. **Week 2**: Enable on 3-5 PRs, collect feedback
3. **Week 3**: Compare against manual review quality
4. **Decision**: Adopt, reject, or trial on more repos

### Alternatives to Compare

| Tool | Model | Pricing | Notes |
|------|-------|---------|-------|
| Greptile | Custom | $19/seat/mo | Context-aware, codebase indexing |
| CodeRabbit | GPT-4 | $12/seat/mo | Popular, good summaries |
| Qodo (Codium) | Multiple | Free tier | Focus on test generation |
| GitHub Copilot PR | GPT-4 | Included | Native, but less context |

### Recommendation

Start with Greptile trial (matches your stated preference for "deeper, codebase-context critique"). If too noisy or expensive, fall back to CodeRabbit.

---

## 6. Implementation Phases

### Phase 1: Foundation (Week 1)
- [ ] Create `config/toolchain-manifest.json` schema
- [ ] Implement `scripts/manifest-sync.ts` - scan sources
- [ ] Implement `scripts/manifest-check.ts` - compare versions
- [ ] Add `agy manifest` command

### Phase 2: Dependabot (Week 1-2)
- [ ] Deploy `.github/dependabot.yml`
- [ ] Deploy `.github/workflows/dependabot-auto-merge.yml`
- [ ] Deploy `.github/workflows/auto-rollback.yml`
- [ ] Implement `scripts/dependabot-triage.ts`
- [ ] Add `agy dependabot` command

### Phase 3: Context7 Monitoring (Week 2)
- [ ] Implement `scripts/context7-check.ts` - query library status
- [ ] Create `docs/context7-changelog.md` - track changes
- [ ] Implement assessment logic for impact scoring
- [ ] Add `agy docs` commands

### Phase 4: Greptile Evaluation (Week 3)
- [ ] Install Greptile GitHub App on dev-infra
- [ ] Document baseline PR review quality
- [ ] Collect feedback on 5 PRs
- [ ] Make adopt/reject decision

### Phase 5: Polish (Week 4)
- [ ] Unified `agy toolchain` command for all operations
- [ ] Documentation updates
- [ ] Runbook for common scenarios

---

## 7. File Structure

```
dev-infra/
├── config/
│   └── toolchain-manifest.json     # Version tracking
├── scripts/
│   ├── manifest-sync.ts            # Scan and update manifest
│   ├── manifest-check.ts           # Check for updates
│   ├── dependabot-triage.ts        # Triage Dependabot PRs
│   ├── context7-check.ts           # Monitor doc updates
│   └── deploy-dependabot.sh        # Setup script
├── templates/
│   └── dependabot/
│       ├── dependabot.yml          # Dependabot config
│       ├── auto-merge.yml          # Auto-merge workflow
│       └── auto-rollback.yml       # Rollback workflow
├── docs/
│   └── context7-changelog.md       # Doc update history
└── .github/
    ├── dependabot.yml              # (deployed)
    └── workflows/
        ├── dependabot-auto-merge.yml
        └── auto-rollback.yml
```

---

## 8. Resolved Questions

1. **CLI tool updates**: **Notify only**. Homebrew breaks things.
   - Add `brew outdated` to triage script
   - Human decides when to update

2. **Context7 tracking**: **No custom tracking**. Weekly re-index only.
   - Let Context7 handle diffs internally
   - Don't build change detection

3. **Greptile scope**: **dev-infra only** for trial.
   - Expand if useful, don't waste credits on junk repos

---

## Appendix: Commands Summary

```bash
# Manifest operations
agy manifest              # Show all tools with status
agy manifest sync         # Update from sources
agy manifest check        # Check for updates

# Dependabot triage
agy dependabot            # Show PRs needing attention

# Context7 docs
agy docs check            # Check for doc updates
agy docs changelog        # Show recent changes
agy docs assess <lib>     # Analyze specific library

# Combined
agy toolchain             # Full status overview
```
