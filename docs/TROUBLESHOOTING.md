# Troubleshooting Guide

Common issues and solutions for Clawdbot Docker setup.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Authentication Issues](#authentication-issues)
- [Gateway Issues](#gateway-issues)
- [Network Issues](#network-issues)
- [Performance Issues](#performance-issues)
- [Data & Storage Issues](#data--storage-issues)
- [Diagnostic Tools](#diagnostic-tools)

## Installation Issues

### Docker Desktop Not Running

**Symptoms:**

- `Cannot connect to the Docker daemon`
- `docker: command not found`

**Solution:**

```bash
# Check if Docker Desktop is running
docker info

# If not running, start Docker Desktop from Applications
open -a Docker

# Wait for Docker to start, then verify
docker info
```

### Permission Denied Errors

**Symptoms:**

- `permission denied while trying to connect to the Docker daemon socket`

**Solution:**

```bash
# Add your user to docker group (may require restart)
sudo dkutil group add docker $USER

# Or run Docker Desktop and ensure it has proper permissions
# System Preferences > Security & Privacy > Full Disk Access > Docker
```

### Port Already in Use

**Symptoms:**

- `Bind for 0.0.0.0:3000 failed: port is already allocated`

**Solution:**

```bash
# Find what's using port 3000
lsof -i :3000

# Kill the process (replace PID with actual process ID)
kill -9 <PID>

# Or use a different port
export CLAWDBOT_GATEWAY_PORT=3001
docker compose up -d clawdbot-gateway
```

## Authentication Issues

### Claude Auth Login Fails

**Symptoms:**

- Browser doesn't open
- "Authentication failed" error

**Solution:**

```bash
# Ensure Claude CLI is properly installed
claude --version

# If not found, reinstall
curl -fsSL https://claude.ai/install.sh | bash

# Try manual browser authentication
claude auth login --manual

# Clear auth cache and retry
rm -rf ~/.claude/auth
claude auth login
```

### Setup Token Not Working

**Symptoms:**

- "Invalid token" error
- "Token expired" error

**Solution:**

```bash
# Generate a fresh setup token
claude setup-token

# Ensure you copy the ENTIRE token (starts with "st-")
# Token should be very long (200+ characters)

# Verify Claude authentication first
claude auth status

# If status shows not authenticated, re-login
claude auth login
claude setup-token
```

### Provider Authentication Fails

**Symptoms:**

- "Provider not found" error
- "Authentication failed for provider" error

**Solution:**

```bash
# List available providers
docker compose run --rm clawdbot-cli models list-providers

# Reset provider authentication
docker compose run --rm clawdbot-cli models auth reset --provider anthropic

# Try authentication again with fresh token
claude setup-token
docker compose run --rm clawdbot-cli models auth paste-token --provider anthropic
```

### Google Antigravity OAuth Fails

**Symptoms:**

- Browser doesn't open for OAuth
- "OAuth callback failed" error

**Solution:**

```bash
# Ensure plugin is enabled
docker compose run --rm clawdbot-cli plugins list
docker compose run --rm clawdbot-cli plugins enable google-antigravity-auth

# Try manual OAuth flow
docker compose run --rm clawdbot-cli models auth login --provider google-antigravity --manual

# Check if port 8080 is available (used for OAuth callback)
lsof -i :8080
```

## Gateway Issues

### Gateway Won't Start

**Symptoms:**

- Container exits immediately
- `docker compose ps` shows "Exited (1)"

**Solution:**

```bash
# Check container logs
docker compose logs clawdbot-gateway

# Common issues and fixes:

# 1. Configuration error
docker compose run --rm clawdbot-cli config list
docker compose run --rm clawdbot-cli config reset

# 2. Missing data directory
mkdir -p ~/Development/clawdbot-workspace/data/{config,logs,cache}

# 3. Corrupted image
docker compose pull clawdbot/gateway:latest
docker compose up -d clawdbot-gateway

# 4. Resource constraints
docker system df
docker system prune
```

### Health Check Fails

**Symptoms:**

- `curl http://localhost:3000/health` returns error
- Container shows "unhealthy" status

**Solution:**

```bash
# Check if gateway is actually running
docker compose ps

# Check detailed health status
docker inspect clawdbot-gateway | grep -A 10 Health

# View health check logs
docker compose logs clawdbot-gateway | grep health

# Try accessing health endpoint from inside container
docker compose exec clawdbot-gateway curl -f http://localhost:3000/health

# If internal health check works, check network binding
docker compose run --rm clawdbot-cli config get gateway.bind
```

### Gateway Crashes Repeatedly

**Symptoms:**

- Container restarts constantly
- High CPU or memory usage

**Solution:**

```bash
# Check resource usage
docker stats clawdbot-gateway

# View crash logs
docker compose logs --tail=200 clawdbot-gateway

# Increase resource limits in docker-compose.yml
# Edit the deploy.resources section

# Check for memory leaks
docker compose run --rm clawdbot-cli doctor --verbose

# Enable debug logging
docker compose run --rm clawdbot-cli config set gateway.logLevel debug
docker compose restart clawdbot-gateway
```

## Network Issues

### Cannot Access Gateway from Browser

**Symptoms:**

- `curl http://localhost:3000` times out
- "Connection refused" error

**Solution:**

```bash
# Verify gateway is running
docker compose ps

# Check port binding
docker compose port clawdbot-gateway 3000

# Verify bind address
docker compose run --rm clawdbot-cli config get gateway.bind

# If bound to localhost, try from local machine only
curl http://localhost:3000/health

# Check firewall settings
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
```

### DNS Resolution Fails

**Symptoms:**

- "Could not resolve host" errors
- External API calls fail

**Solution:**

```bash
# Test DNS from container
docker compose exec clawdbot-gateway nslookup google.com

# If DNS fails, check Docker DNS settings
docker compose exec clawdbot-gateway cat /etc/resolv.conf

# Restart Docker Desktop to reset DNS
# Or configure custom DNS in Docker Desktop settings
```

### Proxy Issues

**Symptoms:**

- "Connection timeout" to external services
- "Proxy authentication required" errors

**Solution:**

```bash
# Set proxy environment variables in docker-compose.yml
# Add under environment:
#   - HTTP_PROXY=http://proxy.example.com:8080
#   - HTTPS_PROXY=http://proxy.example.com:8080
#   - NO_PROXY=localhost,127.0.0.1

# Restart gateway
docker compose up -d clawdbot-gateway
```

## Performance Issues

### Slow Response Times

**Symptoms:**

- API requests take >5 seconds
- Gateway feels sluggish

**Solution:**

```bash
# Check resource usage
docker stats clawdbot-gateway

# Increase resource limits
# Edit docker-compose.yml deploy.resources section

# Check disk I/O
docker system df

# Clear cache
rm -rf ~/Development/clawdbot-workspace/data/cache/*

# Optimize Docker Desktop resources
# Docker Desktop > Preferences > Resources
# Increase CPU and Memory allocation
```

### High Memory Usage

**Symptoms:**

- Container using >4GB RAM
- System becomes slow

**Solution:**

```bash
# Check memory usage
docker stats clawdbot-gateway

# Restart gateway to clear memory
docker compose restart clawdbot-gateway

# Set memory limits in docker-compose.yml
# deploy.resources.limits.memory: 2G

# Check for memory leaks in logs
docker compose logs clawdbot-gateway | grep -i "memory\|leak\|oom"
```

## Data & Storage Issues

### Disk Space Full

**Symptoms:**

- "No space left on device" errors
- Cannot write logs

**Solution:**

```bash
# Check Docker disk usage
docker system df

# Clean up unused resources
docker system prune -a

# Check data directory size
du -sh ~/Development/clawdbot-workspace/data/*

# Clean old logs
find ~/Development/clawdbot-workspace/data/logs -name "*.log" -mtime +30 -delete

# Configure log rotation
docker compose run --rm clawdbot-cli config set gateway.audit.maxLogSize 100
docker compose run --rm clawdbot-cli config set gateway.audit.maxLogFiles 5
```

### Configuration Lost After Restart

**Symptoms:**

- Settings reset to defaults
- Authentication lost

**Solution:**

```bash
# Verify volume mount
docker compose config | grep -A 5 volumes

# Check data directory permissions
ls -la ~/Development/clawdbot-workspace/data

# Fix permissions
sudo chown -R $(whoami) ~/Development/clawdbot-workspace/data

# Verify configuration persistence
docker compose run --rm clawdbot-cli config set test.value "hello"
docker compose restart clawdbot-gateway
docker compose run --rm clawdbot-cli config get test.value
```

### Cannot Write to Logs

**Symptoms:**

- "Permission denied" when writing logs
- Empty log files

**Solution:**

```bash
# Check log directory permissions
ls -la ~/Development/clawdbot-workspace/data/logs

# Fix permissions
sudo chown -R $(whoami) ~/Development/clawdbot-workspace/data/logs
chmod -R 755 ~/Development/clawdbot-workspace/data/logs

# Verify container can write
docker compose exec clawdbot-gateway touch /data/logs/test.log
```

## Diagnostic Tools

### Doctor Command

Comprehensive health check:

```bash
docker compose run --rm clawdbot-cli doctor

# Verbose output
docker compose run --rm clawdbot-cli doctor --verbose

# Check specific component
docker compose run --rm clawdbot-cli doctor --component gateway
```

### Troubleshoot Command

Interactive troubleshooting:

```bash
docker compose run --rm clawdbot-cli troubleshoot

# This will:
# - Check all prerequisites
# - Verify configuration
# - Test network connectivity
# - Validate authentication
# - Generate diagnostic report
```

### Log Analysis

```bash
# View all logs
docker compose logs

# View specific service
docker compose logs clawdbot-gateway

# Follow logs in real-time
docker compose logs -f clawdbot-gateway

# Search for errors
docker compose logs clawdbot-gateway | grep -i error

# Export logs for analysis
docker compose logs > clawdbot-logs-$(date +%Y%m%d).txt
```

### Configuration Dump

```bash
# Export all configuration
docker compose run --rm clawdbot-cli config export > config-dump.json

# View specific settings
docker compose run --rm clawdbot-cli config list | grep -i security

# Compare with defaults
docker compose run --rm clawdbot-cli config diff
```

## Full Reset (Nuclear Option)

⚠️ **WARNING**: This will delete ALL data and configuration.

```bash
# Stop all containers
docker compose down -v

# Remove all Clawdbot data
rm -rf ~/Development/clawdbot-workspace/data

# Remove Docker images
docker rmi clawdbot/gateway:latest clawdbot/cli:latest

# Clean Docker system
docker system prune -a

# Start fresh
cd ~/Development/clawdbot-workspace/clawdbot
./docker-setup.sh

# Re-authenticate
claude auth login
claude setup-token
docker compose run --rm clawdbot-cli models auth paste-token --provider anthropic

# Restart gateway
docker compose up -d clawdbot-gateway
```

## Getting Help

If none of these solutions work:

1. **Collect diagnostic information**:

   ```bash
   docker compose run --rm clawdbot-cli doctor --verbose > diagnostics.txt
   docker compose logs > logs.txt
   docker compose config > config.txt
   ```

2. **Check GitHub Issues**: https://github.com/clawdbot/clawdbot/issues

3. **Join Discord**: https://discord.gg/clawdbot

4. **Contact Support**: support@clawd.bot

Include the diagnostic files when reporting issues.
