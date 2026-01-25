# Secure Container Deployment Guide

**Production-grade, security-hardened Clawdbot deployment for enterprise and untrusted environments**

## 🔒 Security Features

This secure deployment includes:

✅ **Read-only root filesystem** - Prevents runtime modifications  
✅ **Non-root user** - Runs as UID 1000 (not root)  
✅ **Dropped capabilities** - All Linux capabilities dropped  
✅ **Seccomp profile** - Custom syscall filtering  
✅ **No new privileges** - Prevents privilege escalation  
✅ **Resource limits** - CPU, memory, and PID limits enforced  
✅ **Localhost-only binding** - No external network exposure  
✅ **Tmpfs mounts** - Temporary directories in memory  
✅ **Log rotation** - Prevents disk space exhaustion

## 🎯 When to Use Secure Deployment

Use this deployment if you:

- ✅ Are deploying in production or enterprise environments
- ✅ Process untrusted or sensitive data
- ✅ Require compliance with security standards (SOC 2, ISO 27001, etc.)
- ✅ Need defense-in-depth security posture
- ✅ Want to minimize attack surface

Use standard deployment if you:

- ❌ Are testing locally on your personal Mac
- ❌ Only process trusted data
- ❌ Need maximum flexibility for development

## 📋 Prerequisites

Same as standard deployment, plus:

- **Docker Desktop** with seccomp support
- **Sufficient permissions** to create user namespaces
- **Understanding** of container security concepts

## 🚀 Deployment Steps

### Step 1: Clone Official Clawdbot

```bash
git clone https://github.com/clawdbot/clawdbot.git ~/Development/Projects/clawdbot-official
cd ~/Development/Projects/clawdbot-official
```

### Step 2: Copy Secure Configuration Files

```bash
# Copy secure Docker Compose configuration
cp ~/Development/Projects/clawdbot/config/docker-compose.secure.yml ./docker-compose.yml

# Copy secure Dockerfile
cp ~/Development/Projects/clawdbot/config/Dockerfile.secure ./Dockerfile

# Copy seccomp profile
cp ~/Development/Projects/clawdbot/config/seccomp-profile.json ./

# Copy deployment script
cp ~/Development/Projects/clawdbot/scripts/deploy-secure.sh ./
chmod +x deploy-secure.sh
```

### Step 3: Configure Environment

```bash
# Create .env file
cat > .env << 'EOF'
# Clawdbot Secure Deployment Configuration
CLAWDBOT_HOME_VOLUME=$HOME/Development/clawdbot-workspace/data-secure
CLAWDBOT_GATEWAY_PORT=3000
CLAWDBOT_LOG_LEVEL=info
EOF

# Create data directory with proper permissions
mkdir -p ~/Development/clawdbot-workspace/data-secure/{config,logs,cache}
sudo chown -R 1000:1000 ~/Development/clawdbot-workspace/data-secure
chmod -R 755 ~/Development/clawdbot-workspace/data-secure
```

### Step 4: Build Secure Images

```bash
# Build with security-hardened Dockerfile
docker compose build --no-cache

# Verify images were created
docker images | grep clawdbot
```

### Step 5: Authenticate with Claude

```bash
# Login via browser
claude auth login

# Generate setup token
claude setup-token
# Copy the entire output (starts with "st-...")
```

### Step 6: Start Secure Gateway

```bash
# Start with secure configuration
docker compose up -d clawdbot-gateway

# Wait for startup
sleep 10

# Check status
docker compose ps
```

### Step 7: Configure Clawdbot

```bash
# Inject Claude token
docker compose run --rm clawdbot-cli models auth paste-token --provider anthropic
# Paste the setup-token when prompted
```

### Step 8: Apply Additional Security Hardening

```bash
# Enable strict sandboxing
docker compose run --rm clawdbot-cli config set gateway.sandbox.enabled true
docker compose run --rm clawdbot-cli config set gateway.sandbox.mode strict

# Localhost binding (already enforced in docker-compose.secure.yml)
docker compose run --rm clawdbot-cli config set gateway.bind localhost

# Restrictive tool policy
docker compose run --rm clawdbot-cli config set gateway.tools.policy restrictive
docker compose run --rm clawdbot-cli config set gateway.tools.allowList "[]"

# Enable audit logging
docker compose run --rm clawdbot-cli config set gateway.audit.enabled true
docker compose run --rm clawdbot-cli config set gateway.audit.logLevel info

# Enable prompt injection protection
docker compose run --rm clawdbot-cli config set gateway.security.promptInjection.enabled true
docker compose run --rm clawdbot-cli config set gateway.security.promptInjection.strictMode true

# Enable rate limiting
docker compose run --rm clawdbot-cli config set gateway.security.rateLimit.enabled true
docker compose run --rm clawdbot-cli config set gateway.security.rateLimit.maxRequests 100
docker compose run --rm clawdbot-cli config set gateway.security.rateLimit.windowMs 60000
```

### Step 9: Verify Security Configuration

```bash
# Copy and run security verification script
cp ~/Development/Projects/clawdbot/scripts/verify-security.sh ./
chmod +x verify-security.sh
./verify-security.sh
```

Expected output:

```
🔍 Security Configuration Verification
✅ Container running as non-root user (UID: 1000)
✅ Root filesystem is read-only
✅ All capabilities dropped
✅ No new privileges flag set
✅ Seccomp profile active
✅ Localhost-only binding
✅ Sandbox enabled (strict mode)
✅ Resource limits enforced
✅ Audit logging enabled
✅ Prompt injection protection enabled
```

### Step 10: Health Check

```bash
# Run diagnostics
docker compose run --rm clawdbot-cli doctor

# Test health endpoint
curl http://localhost:3000/health

# Check logs
docker compose logs --tail=50 clawdbot-gateway
```

## 🔍 Security Verification

### Verify Non-Root User

```bash
docker compose exec clawdbot-gateway whoami
# Expected: clawdbot (not root)

docker compose exec clawdbot-gateway id
# Expected: uid=1000(clawdbot) gid=1000(clawdbot)
```

### Verify Read-Only Filesystem

```bash
docker compose exec clawdbot-gateway touch /test
# Expected: touch: /test: Read-only file system
```

### Verify Capabilities

```bash
docker inspect clawdbot-gateway-secure | grep -A 20 CapAdd
# Expected: Only NET_BIND_SERVICE (if needed) or empty
```

### Verify Network Binding

```bash
# Should only be accessible from localhost
curl http://localhost:3000/health  # ✅ Works
curl http://$(hostname -I | awk '{print $1}'):3000/health  # ❌ Fails
```

### Verify Resource Limits

```bash
docker stats --no-stream clawdbot-gateway-secure
# Verify CPU and memory limits are enforced
```

## 🛡️ Security Hardening Comparison

| Feature         | Standard        | Secure Container              |
| --------------- | --------------- | ----------------------------- |
| Root Filesystem | Read-write      | **Read-only**                 |
| User            | Configurable    | **Non-root (UID 1000)**       |
| Capabilities    | Default (~14)   | **All dropped**               |
| Seccomp         | Default profile | **Custom restrictive**        |
| Network Binding | Configurable    | **Localhost-only enforced**   |
| Resource Limits | Optional        | **Enforced (CPU, RAM, PIDs)** |
| New Privileges  | Allowed         | **Blocked**                   |
| Tmpfs Mounts    | None            | **/tmp, /var/tmp, /run**      |
| Log Rotation    | Manual          | **Automatic (10MB x 3)**      |
| Docker Socket   | Read-write      | **Removed/Read-only**         |

## 🔧 Troubleshooting Secure Deployment

### Issue: Permission Denied Errors

```bash
# Check data directory ownership
ls -la ~/Development/clawdbot-workspace/data-secure

# Fix permissions
sudo chown -R 1000:1000 ~/Development/clawdbot-workspace/data-secure
chmod -R 755 ~/Development/clawdbot-workspace/data-secure
```

### Issue: Cannot Write to Filesystem

This is **expected** with read-only root filesystem. Use tmpfs mounts:

```bash
# Temporary files should go to /tmp (tmpfs)
# Persistent data should go to /data (mounted volume)
```

### Issue: Container Won't Start

```bash
# Check logs
docker compose logs clawdbot-gateway

# Common issues:
# 1. Seccomp profile not found
cp ~/Development/Projects/clawdbot/config/seccomp-profile.json ./

# 2. Data directory permissions
sudo chown -R 1000:1000 ~/Development/clawdbot-workspace/data-secure

# 3. Port already in use
lsof -i :3000
```

### Issue: Health Check Failing

```bash
# Check if curl is available in container
docker compose exec clawdbot-gateway which curl

# If missing, rebuild with curl included
docker compose build --no-cache
```

## 📊 Performance Impact

Secure deployment has minimal performance impact:

- **CPU**: < 2% overhead from seccomp filtering
- **Memory**: ~10MB for tmpfs mounts
- **I/O**: Slightly faster (tmpfs for temp files)
- **Startup**: +2-3 seconds (security checks)

## 🔄 Updates and Maintenance

### Updating Secure Deployment

```bash
# Pull latest code
cd ~/Development/Projects/clawdbot-official
git pull

# Rebuild with security hardening
docker compose build --no-cache

# Stop old container
docker compose down

# Start new container
docker compose up -d clawdbot-gateway

# Verify security settings
./verify-security.sh
```

### Backup Secure Configuration

```bash
# Backup configuration
docker compose run --rm clawdbot-cli config export > ~/backups/clawdbot-secure-$(date +%Y%m%d).json

# Backup data directory
tar -czf ~/backups/clawdbot-secure-data-$(date +%Y%m%d).tar.gz \
  ~/Development/clawdbot-workspace/data-secure
```

## 🎯 Production Deployment Checklist

Before deploying to production:

- [ ] All security features verified with `verify-security.sh`
- [ ] Sandbox mode enabled and set to strict
- [ ] Localhost-only binding confirmed
- [ ] Resource limits appropriate for workload
- [ ] Audit logging enabled and tested
- [ ] Backup procedures in place
- [ ] Monitoring configured
- [ ] Incident response plan documented
- [ ] Security team review completed
- [ ] Compliance requirements verified

## 📞 Support

For security-related questions:

- **Security Guide**: `~/Development/Projects/clawdbot/docs/SECURITY.md`
- **Troubleshooting**: `~/Development/Projects/clawdbot/docs/TROUBLESHOOTING.md`
- **GitHub Issues**: https://github.com/clawdbot/clawdbot/issues
- **Security Contact**: security@clawd.bot (for vulnerabilities)

## 🎊 Deployment Complete!

Your Clawdbot instance is now running with:

✅ **Enterprise-grade security**  
✅ **Defense-in-depth protection**  
✅ **Minimal attack surface**  
✅ **Production-ready configuration**

**Next steps**:

- Monitor logs regularly
- Run `verify-security.sh` after any changes
- Keep security configurations up to date
- Review audit logs weekly

---

**Version**: 1.1.0  
**Security Level**: 🔒 **Enterprise**  
**Status**: ✅ **Production Ready**
