# Rollback Procedure

## If Migration Issues Occur

### Quick Rollback (Full Restore)

```bash
cd /Users/jederlichman/Development/Projects

# Remove migrated repo
rm -rf dev-infrastructure

# Restore from backup
mv ClawdBot-backup-20260129-1946 ClawdBot

# Restore mcp-deployment
mv /Users/jederlichman/Development/mcp-deployment-backup-20260129-1946 /Users/jederlichman/Development/mcp-deployment

# Remove redirect symlink
rm -f /Users/jederlichman/Development/mcp-deployment-redirect
```

### Partial Rollback (Keep Changes, Fix Issues)

```bash
# Reset to pre-migration state
cd /Users/jederlichman/Development/Projects/dev-infrastructure
git checkout main
git reset --hard aa4e923  # Pre-migration checkpoint
```

## Backup Locations

| Backup | Path | Created |
|--------|------|---------|
| ClawdBot | `~/Development/Projects/ClawdBot-backup-20260129-1946` | 2026-01-29 |
| mcp-deployment | `~/Development/mcp-deployment-backup-20260129-1946` | 2026-01-29 |

## Backup Retention

- Keep backups for **30 days** minimum
- Delete after confirming Phase B is stable
- Scheduled cleanup: **2026-02-28**

## Verification After Rollback

```bash
# Verify ClawdBot restored
ls -la ~/Development/Projects/ClawdBot/package.json

# Verify mcp-deployment restored
ls -la ~/Development/mcp-deployment/scripts/project-setup.sh

# Test deployment
cd ~/Development/Projects/iphone-tco-planner
bash scripts/validate-mcp.sh
```
