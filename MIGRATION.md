# Migration Guide

## ClawdBot → dev-infra

**Renamed:** 2026-01-30

### Path Changes

| Old Path | New Path |
|----------|----------|
| `~/Development/Projects/ClawdBot` | `~/Development/Projects/dev-infra` |
| `~/Development/Projects/dev-infrastructure` | `~/Development/Projects/dev-infra` |
| `~/Development/mcp-deployment` | `~/Development/Projects/dev-infra/mcp` |

### Naming Convention

- **dev-infra**: This infrastructure/deployment repo
- **ClawdBot**: The messaging gateway software (Docker containers, images, env vars)

### Rollback

Backups available:
- `ClawdBot-backup-20260129-1946`
- `mcp-deployment-backup-20260129-1946`
