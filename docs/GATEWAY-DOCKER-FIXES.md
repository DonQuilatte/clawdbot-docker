# Gateway Docker Configuration Fixes

## Issue Summary

The Clawdbot gateway Docker deployment had several configuration issues preventing proper browser connections:

1. **Invalid `--bind` option**: `--bind localhost` is not valid; must use `loopback`, `lan`, `tailnet`, `auto`, or `custom`
2. **tmpfs UID/GID mismatch**: tmpfs mounts used `uid=1000,gid=1000` but macOS runs as `uid=501,gid=20`
3. **Volume permission mismatch**: Named Docker volumes created with `1000:1000` ownership but container runs as `501:20`
4. **Token/pairing confusion**: Multiple authentication layers (gateway token + device pairing) caused connection failures

## Root Causes

### 1. Bind Address Issue
```yaml
# WRONG - "localhost" is not a valid bind mode
"--bind", "localhost"

# CORRECT - use "lan" for Docker (binds to 0.0.0.0 inside container)
"--bind", "lan"
```

The gateway needs to bind to `0.0.0.0` inside the container for Docker port mapping to work. Using `loopback` binds to `127.0.0.1` inside the container, which Docker cannot forward to.

### 2. tmpfs Permission Issue
Docker Compose does NOT support variable interpolation in tmpfs options:
```yaml
# WRONG - variables not expanded
- /tmp:mode=1770,uid=${USER_UID:-501}

# CORRECT - hardcode macOS values
- /tmp:mode=1770,size=512M,noexec,nosuid,nodev,uid=501,gid=20
```

### 3. Volume Ownership Issue
Named Docker volumes are created with ownership from the Docker image's default user (1000:1000), not the runtime user (501:20).

**Solution**: Use host directory mounts instead of named volumes:
```yaml
volumes:
  - ${HOME}/.dev-infra:/home/node/.clawdbot:rw
  - ${HOME}/.dev-infra/logs:/home/node/logs:rw
```

### 4. Token Configuration Hierarchy
The gateway reads tokens from multiple sources with this precedence:
1. `--token` CLI argument (highest)
2. `CLAWDBOT_GATEWAY_TOKEN` environment variable
3. `gateway.auth.token` in `~/.clawdbot/clawdbot.json` config file

If these don't match what browsers have stored in localStorage, connections fail with "token_mismatch".

## Device Pairing
New browser sessions require device pairing approval:
```bash
# List pending devices
docker exec clawdbot-gateway-secure clawdbot devices list

# Approve a device
docker exec clawdbot-gateway-secure clawdbot devices approve <request-id>
```

## Verification Steps
```bash
# 1. Check container is healthy
docker ps | grep clawdbot

# 2. Verify HTTP endpoint
curl -s http://localhost:18789/ | head -3

# 3. Check for successful WebSocket connections
docker logs clawdbot-gateway-secure | grep "webchat connected"

# 4. Verify no pending device pairings
docker exec clawdbot-gateway-secure clawdbot devices list
```

## Files Modified
- `config/docker-compose.secure.yml`: Fixed bind mode, tmpfs permissions, volume mounts
- `.env`: Added `CLAWDBOT_GATEWAY_TOKEN`

## Prevention
See `tests/gateway-docker-test.sh` for automated validation of these configuration requirements.
