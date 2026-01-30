---
description: fix-setup - Troubleshooting and repairing Antigravity Path 3 integration
---

If the user reports that their Antigravity IDE setup is failing, or if the auto-setup notification shows a warning/error, follow these steps to diagnose and repair the environment.

### 1. Run Health Check

Execute the health check script to identify specific failures:

```bash
./scripts/agy-health
```

### 2. Automatic Repair

If issues are found, the script can often fix them automatically:

```bash
./scripts/agy-health --fix
```

### 3. Manual Verification

If automatic repair fails, check the following manually:

- **1Password**: Ensure you are signed in (`op account list`).
- **direnv**: Ensure the environment is allowed (`direnv allow`).
- **MCP Config**: View the generated config to ensure absolute paths are correct:
  ```bash
  cat .antigravity/mcp_config.json
  ```

### 4. Reinitialization

In extreme cases, you can re-bootstrap the project (this will overwrite config files):

```bash
./scripts/agy-init --force
```

### 5. Log Analysis

If the silent setup failed without a clear error in the IDE, check the log file:

```bash
cat /tmp/agy-auto-setup-$(date +%Y%m%d).log
```
