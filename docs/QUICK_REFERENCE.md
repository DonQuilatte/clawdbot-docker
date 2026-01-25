# Quick Reference

Essential commands for daily Clawdbot operations.

## 🚀 Quick Start

```bash
# One-time setup
./docker-setup.sh

# Start gateway
docker compose up -d clawdbot-gateway

# Check status
docker compose ps

# View logs
docker compose logs -f clawdbot-gateway
```

## 🔧 Common Commands

### Gateway Control

```bash
# Start
docker compose up -d clawdbot-gateway

# Stop
docker compose down

# Restart
docker compose restart clawdbot-gateway

# Status
docker compose ps

# Logs (last 50 lines)
docker compose logs --tail=50 clawdbot-gateway

# Follow logs
docker compose logs -f clawdbot-gateway
```

### Configuration

```bash
# List all settings
docker compose run --rm clawdbot-cli config list

# Get specific setting
docker compose run --rm clawdbot-cli config get gateway.sandbox.enabled

# Set setting
docker compose run --rm clawdbot-cli config set gateway.bind localhost

# Reset to defaults
docker compose run --rm clawdbot-cli config reset

# Export config
docker compose run --rm clawdbot-cli config export > backup.json

# Import config
docker compose run --rm clawdbot-cli config import < backup.json
```

### Authentication

```bash
# List providers
docker compose run --rm clawdbot-cli models list-providers

# List authenticated providers
docker compose run --rm clawdbot-cli models auth list

# Authenticate provider
docker compose run --rm clawdbot-cli models auth paste-token --provider anthropic

# Set default provider
docker compose run --rm clawdbot-cli models auth set-default --provider google-antigravity

# Reset provider auth
docker compose run --rm clawdbot-cli models auth reset --provider anthropic
```

### Health & Diagnostics

```bash
# Health check
curl http://localhost:3000/health

# Comprehensive diagnostics
docker compose run --rm clawdbot-cli doctor

# Verbose diagnostics
docker compose run --rm clawdbot-cli doctor --verbose

# Troubleshoot
docker compose run --rm clawdbot-cli troubleshoot
```

### Plugins

```bash
# List plugins
docker compose run --rm clawdbot-cli plugins list

# Enable plugin
docker compose run --rm clawdbot-cli plugins enable google-antigravity-auth

# Disable plugin
docker compose run --rm clawdbot-cli plugins disable <plugin-name>
```

## 🔒 Security Commands

```bash
# Enable strict sandbox
docker compose run --rm clawdbot-cli config set gateway.sandbox.enabled true
docker compose run --rm clawdbot-cli config set gateway.sandbox.mode strict

# Localhost only
docker compose run --rm clawdbot-cli config set gateway.bind localhost

# Restrictive tools
docker compose run --rm clawdbot-cli config set gateway.tools.policy restrictive

# Enable audit logging
docker compose run --rm clawdbot-cli config set gateway.audit.enabled true

# Enable prompt injection protection
docker compose run --rm clawdbot-cli config set gateway.security.promptInjection.enabled true

# Enable rate limiting
docker compose run --rm clawdbot-cli config set gateway.security.rateLimit.enabled true
```

## 🧹 Maintenance

```bash
# Update images
docker compose pull
docker compose up -d clawdbot-gateway

# Clean Docker system
docker system prune

# Clean old logs (older than 30 days)
find ~/Development/clawdbot-workspace/data/logs -name "*.log" -mtime +30 -delete

# Check disk usage
docker system df
du -sh ~/Development/clawdbot-workspace/data/*

# Backup configuration
docker compose run --rm clawdbot-cli config export > config-backup-$(date +%Y%m%d).json
```

## 🐛 Debugging

```bash
# Enable debug logging
docker compose run --rm clawdbot-cli config set gateway.logLevel debug
docker compose restart clawdbot-gateway

# View errors only
docker compose logs clawdbot-gateway | grep -i error

# Check container stats
docker stats clawdbot-gateway

# Inspect container
docker inspect clawdbot-gateway

# Execute command in container
docker compose exec clawdbot-gateway sh
```

## 📊 Monitoring

```bash
# Container status
docker compose ps

# Resource usage
docker stats clawdbot-gateway

# Health status
docker inspect clawdbot-gateway | grep -A 10 Health

# Recent logs
docker compose logs --tail=100 clawdbot-gateway

# Search logs
docker compose logs clawdbot-gateway | grep "search-term"
```

## 🔄 Reset & Recovery

```bash
# Soft reset (restart)
docker compose restart clawdbot-gateway

# Medium reset (rebuild)
docker compose down
docker compose pull
docker compose up -d clawdbot-gateway

# Hard reset (delete data - WARNING!)
docker compose down -v
rm -rf ~/Development/clawdbot-workspace/data
./docker-setup.sh
```

## 📁 File Locations

```bash
# Configuration
~/Development/clawdbot-workspace/data/config/

# Logs
~/Development/clawdbot-workspace/data/logs/

# Cache
~/Development/clawdbot-workspace/data/cache/

# Docker files
~/Development/clawdbot-workspace/clawdbot/
```

## 🆘 Emergency Commands

```bash
# Stop everything immediately
docker compose down

# Kill all Clawdbot containers
docker ps -a | grep clawdbot | awk '{print $1}' | xargs docker rm -f

# View crash logs
docker compose logs --tail=200 clawdbot-gateway

# Generate diagnostic report
docker compose run --rm clawdbot-cli doctor --verbose > diagnostics-$(date +%Y%m%d).txt
```

## 📚 Documentation

- Full Setup: `README.md`
- Security Guide: `SECURITY.md`
- Troubleshooting: `TROUBLESHOOTING.md`
- Online Docs: https://docs.clawd.bot

## 💡 Tips

- Use `docker compose` (not `docker-compose`) on newer Docker versions
- Always check logs first when troubleshooting: `docker compose logs clawdbot-gateway`
- Run `doctor` command regularly: `docker compose run --rm clawdbot-cli doctor`
- Backup config before major changes: `docker compose run --rm clawdbot-cli config export > backup.json`
- Keep Docker Desktop updated for best performance
