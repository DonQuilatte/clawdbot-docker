# Deployment Guide

Complete step-by-step deployment guide for Clawdbot on macOS.

## 🎯 Pre-Deployment Checklist

### Prerequisites Verification

Before starting deployment, ensure you have:

- [ ] macOS 10.15 or later
- [ ] Docker Desktop installed and **running**
- [ ] Node.js 18+ and npm installed
- [ ] Active Claude subscription
- [ ] Git installed
- [ ] Terminal access
- [ ] Internet connection

### Credentials Ready

- [ ] Claude account credentials (email/password)
- [ ] Google Cloud project for Antigravity (if using)
- [ ] Admin access to your Mac

### Review Documentation

- [ ] Read `README.md` for overview
- [ ] Review `SECURITY.md` for security implications
- [ ] Bookmark `QUICK_REFERENCE.md` for daily use

## 🚀 Deployment Steps

### Step 0: Pre-Flight Check

```bash
# Navigate to project directory
cd /Users/jederlichman/Development/Projects/clawdbot/

# Verify all files are present
ls -la

# Expected output should include:
# - docker-compose.yml
# - docker-setup.sh (executable)
# - .env.example
# - All documentation files

# Verify Docker is running
docker info

# If Docker is not running, start Docker Desktop:
open -a Docker
# Wait for Docker to start (check menu bar icon)
```

### Step 1: Run Automated Setup

```bash
# Make setup script executable (if not already)
chmod +x docker-setup.sh

# Run the setup script
./docker-setup.sh
```

**What this does:**

- ✅ Checks all prerequisites
- ✅ Creates data directory structure
- ✅ Generates default configuration
- ✅ Pulls Docker images
- ✅ Displays next steps

**Expected output:**

- Green checkmarks for all prerequisites
- Data directory created at `~/Development/clawdbot-workspace/data`
- `.env` file created
- Docker images pulled successfully

### Step 2: Authenticate Claude Code

```bash
# Login to Claude (opens browser)
claude auth login

# Follow browser prompts to authenticate
# You should see: "Successfully authenticated as <your-email>"

# Verify authentication
claude auth status

# Generate setup token for Clawdbot
claude setup-token
```

**Important:**

- Copy the **ENTIRE** token output (starts with `st-...`)
- Token is very long (200+ characters)
- Keep this token secure and ready for next step

### Step 3: Configure Security Settings

```bash
# Enable strict sandboxing
docker compose run --rm clawdbot-cli config set gateway.sandbox.enabled true
docker compose run --rm clawdbot-cli config set gateway.sandbox.mode strict

# Localhost binding only (security best practice)
docker compose run --rm clawdbot-cli config set gateway.bind localhost

# Restrictive tool policy
docker compose run --rm clawdbot-cli config set gateway.tools.policy restrictive

# Enable audit logging
docker compose run --rm clawdbot-cli config set gateway.audit.enabled true

# Enable prompt injection protection
docker compose run --rm clawdbot-cli config set gateway.security.promptInjection.enabled true

# Enable rate limiting
docker compose run --rm clawdbot-cli config set gateway.security.rateLimit.enabled true
docker compose run --rm clawdbot-cli config set gateway.security.rateLimit.maxRequests 100
```

**Verify security settings:**

```bash
docker compose run --rm clawdbot-cli config get gateway.sandbox.enabled
docker compose run --rm clawdbot-cli config get gateway.sandbox.mode
docker compose run --rm clawdbot-cli config get gateway.bind
```

### Step 4: Authenticate Clawdbot with Claude

```bash
# Inject your Claude subscription token
docker compose run --rm clawdbot-cli models auth paste-token --provider anthropic

# When prompted, paste the setup-token from Step 2
# Press Enter after pasting
```

**Expected output:**

- "Successfully authenticated with Anthropic"
- Token stored securely

**Verify authentication:**

```bash
docker compose run --rm clawdbot-cli models auth list
# Should show: anthropic (authenticated)
```

### Step 5: Configure Google Antigravity (Optional)

```bash
# Verify provider availability
docker compose run --rm clawdbot-cli models list-providers

# Enable Antigravity plugin
docker compose run --rm clawdbot-cli plugins enable google-antigravity-auth

# Authenticate Google Antigravity (opens browser for OAuth)
docker compose run --rm clawdbot-cli models auth login --provider google-antigravity

# Follow browser OAuth flow
# Grant necessary permissions

# Set as default provider (optional)
docker compose run --rm clawdbot-cli models auth set-default --provider google-antigravity
```

**Verify Antigravity setup:**

```bash
docker compose run --rm clawdbot-cli models list
# Should show both Anthropic and Google providers
```

### Step 6: Launch Gateway

```bash
# Start the gateway service
docker compose up -d clawdbot-gateway

# Wait a few seconds for startup
sleep 5

# Check container status
docker compose ps
# Should show: clawdbot-gateway running (healthy)
```

**Expected output:**

```
NAME                 STATUS              PORTS
clawdbot-gateway    Up X seconds (healthy)   0.0.0.0:3000->3000/tcp
```

### Step 7: Verify Installation

```bash
# Run comprehensive health check
docker compose run --rm clawdbot-cli doctor

# Test health endpoint
curl http://localhost:3000/health
# Should return: {"status":"ok","timestamp":"..."}

# Check gateway logs
docker compose logs --tail=50 clawdbot-gateway

# Verify all providers
docker compose run --rm clawdbot-cli models list
```

**Success indicators:**

- ✅ `docker compose ps` shows gateway as "running (healthy)"
- ✅ `curl http://localhost:3000/health` returns 200 OK
- ✅ `doctor` command shows no errors
- ✅ Logs show no errors or warnings

## ✅ Post-Deployment Verification

### Complete Verification Checklist

```bash
# 1. Container is running
docker compose ps | grep clawdbot-gateway
# Expected: "Up X seconds (healthy)"

# 2. Health endpoint responds
curl -f http://localhost:3000/health
# Expected: HTTP 200 with JSON response

# 3. Authentication is valid
docker compose run --rm clawdbot-cli models auth list
# Expected: Shows authenticated providers

# 4. Configuration is correct
docker compose run --rm clawdbot-cli config get gateway.sandbox.enabled
# Expected: true

# 5. Logs are clean
docker compose logs --tail=100 clawdbot-gateway | grep -i error
# Expected: No critical errors

# 6. Resources are healthy
docker stats --no-stream clawdbot-gateway
# Expected: Reasonable CPU and memory usage
```

### Test Basic Functionality

```bash
# Test a simple API request (if API is available)
curl -X POST http://localhost:3000/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello, Clawdbot!"}'

# Check response in logs
docker compose logs --tail=20 clawdbot-gateway
```

## 🎁 Shell Aliases (Optional but Recommended)

Add these to your `~/.zshrc` or `~/.bashrc`:

```bash
# Clawdbot aliases
alias clawd-up='cd ~/Development/Projects/clawdbot && docker compose up -d clawdbot-gateway'
alias clawd-down='cd ~/Development/Projects/clawdbot && docker compose down'
alias clawd-restart='cd ~/Development/Projects/clawdbot && docker compose restart clawdbot-gateway'
alias clawd-logs='cd ~/Development/Projects/clawdbot && docker compose logs -f clawdbot-gateway'
alias clawd-status='cd ~/Development/Projects/clawdbot && docker compose ps'
alias clawd-doctor='cd ~/Development/Projects/clawdbot && docker compose run --rm clawdbot-cli doctor'
alias clawd-config='cd ~/Development/Projects/clawdbot && docker compose run --rm clawdbot-cli config list'
alias clawd-health='curl -s http://localhost:3000/health | jq'
```

**To install aliases:**

```bash
# Append to your shell config
cat >> ~/.zshrc << 'EOF'

# Clawdbot aliases
alias clawd-up='cd ~/Development/Projects/clawdbot && docker compose up -d clawdbot-gateway'
alias clawd-down='cd ~/Development/Projects/clawdbot && docker compose down'
alias clawd-restart='cd ~/Development/Projects/clawdbot && docker compose restart clawdbot-gateway'
alias clawd-logs='cd ~/Development/Projects/clawdbot && docker compose logs -f clawdbot-gateway'
alias clawd-status='cd ~/Development/Projects/clawdbot && docker compose ps'
alias clawd-doctor='cd ~/Development/Projects/clawdbot && docker compose run --rm clawdbot-cli doctor'
alias clawd-config='cd ~/Development/Projects/clawdbot && docker compose run --rm clawdbot-cli config list'
alias clawd-health='curl -s http://localhost:3000/health | jq'
EOF

# Reload shell configuration
source ~/.zshrc

# Test aliases
clawd-status
clawd-health
```

## 🔧 Post-Deployment Configuration

### Optional: Customize Port

If port 3000 is already in use:

```bash
# Edit .env file
echo "CLAWDBOT_GATEWAY_PORT=8080" >> .env

# Restart gateway
docker compose down
docker compose up -d clawdbot-gateway

# Verify new port
curl http://localhost:8080/health
```

### Optional: Enable Debug Logging

For troubleshooting:

```bash
# Enable debug logging
docker compose run --rm clawdbot-cli config set gateway.logLevel debug

# Restart gateway
docker compose restart clawdbot-gateway

# View debug logs
docker compose logs -f clawdbot-gateway
```

### Optional: Configure Log Rotation

```bash
# Set maximum log file size (in MB)
docker compose run --rm clawdbot-cli config set gateway.audit.maxLogSize 100

# Set maximum number of log files
docker compose run --rm clawdbot-cli config set gateway.audit.maxLogFiles 10

# Restart to apply
docker compose restart clawdbot-gateway
```

## 📊 Monitoring

### Daily Health Checks

```bash
# Quick health check
clawd-health

# Detailed diagnostics
clawd-doctor

# Check resource usage
docker stats --no-stream clawdbot-gateway

# View recent logs
clawd-logs --tail=50
```

### Weekly Maintenance

```bash
# Check for updates
cd ~/Development/Projects/clawdbot
docker compose pull

# Restart with new images
docker compose up -d clawdbot-gateway

# Clean up old images
docker image prune -f

# Verify everything still works
clawd-doctor
```

### Monthly Tasks

```bash
# Backup configuration
docker compose run --rm clawdbot-cli config export > ~/backups/clawdbot-config-$(date +%Y%m%d).json

# Backup data directory
tar -czf ~/backups/clawdbot-data-$(date +%Y%m%d).tar.gz ~/Development/clawdbot-workspace/data

# Review logs for issues
docker compose logs --since 30d clawdbot-gateway | grep -i error

# Check disk usage
docker system df
du -sh ~/Development/clawdbot-workspace/data/*
```

## 🚨 Rollback Procedure

If something goes wrong during deployment:

```bash
# Stop gateway
docker compose down

# Restore from backup (if you have one)
tar -xzf ~/backups/clawdbot-data-YYYYMMDD.tar.gz -C ~/Development/clawdbot-workspace/

# Or start fresh
rm -rf ~/Development/clawdbot-workspace/data
./docker-setup.sh

# Re-authenticate
claude auth login
claude setup-token
docker compose run --rm clawdbot-cli models auth paste-token --provider anthropic

# Restart
docker compose up -d clawdbot-gateway
```

## 📞 Getting Help

If deployment fails:

1. **Check logs**: `docker compose logs clawdbot-gateway`
2. **Run diagnostics**: `docker compose run --rm clawdbot-cli doctor`
3. **Review troubleshooting**: See `TROUBLESHOOTING.md`
4. **Check GitHub issues**: https://github.com/clawdbot/clawdbot/issues
5. **Join Discord**: https://discord.gg/clawdbot

## 🎉 Deployment Complete!

Once all verification steps pass, your Clawdbot installation is:

✅ **Deployed** - Gateway is running  
✅ **Secured** - Strict sandbox and security settings enabled  
✅ **Authenticated** - Connected to Claude and Antigravity  
✅ **Monitored** - Health checks and logging enabled  
✅ **Ready** - Ready for production use

**Next Steps:**

- Start using Clawdbot via the API
- Monitor logs regularly
- Keep documentation handy
- Join the community

---

**Deployment Date**: ********\_********  
**Deployed By**: ********\_********  
**Version**: 1.0.0  
**Status**: ✅ Production Ready
