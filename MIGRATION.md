# Migration Guide

## ClawdBot → dev-infrastructure

**Renamed:** 2026-01-29

### Path Changes

| Old Path | New Path |
|----------|----------|
| `~/Development/Projects/ClawdBot` | `~/Development/Projects/dev-infrastructure` |
| `~/Development/mcp-deployment` | `~/Development/Projects/dev-infrastructure/mcp` |

### Transition Symlink

A symlink exists at `~/Development/mcp-deployment-redirect` pointing to the new location.

### Rollback

Backups available:
- `ClawdBot-backup-20260129-1946`
- `mcp-deployment-backup-20260129-1946`
