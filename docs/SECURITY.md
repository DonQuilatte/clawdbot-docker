# Security Guide

This document outlines security best practices for running Clawdbot in production.

## Table of Contents

- [Security Principles](#security-principles)
- [Sandbox Configuration](#sandbox-configuration)
- [Network Security](#network-security)
- [Authentication](#authentication)
- [Audit Logging](#audit-logging)
- [Tool Restrictions](#tool-restrictions)
- [Security Checklist](#security-checklist)

## Security Principles

Clawdbot follows these core security principles:

1. **Least Privilege**: Run with minimal permissions required
2. **Defense in Depth**: Multiple layers of security controls
3. **Fail Secure**: Default to secure settings
4. **Audit Everything**: Comprehensive logging of all actions
5. **Zero Trust**: Verify all requests and actions

## Sandbox Configuration

### Strict Mode (Recommended for Production)

```bash
# Enable strict sandboxing
docker compose run --rm clawdbot-cli config set gateway.sandbox.enabled true
docker compose run --rm clawdbot-cli config set gateway.sandbox.mode strict

# No system commands allowed
docker compose run --rm clawdbot-cli config set gateway.sandbox.allowedCommands "[]"
```

**Strict mode provides:**

- Complete isolation from host system
- No file system access outside container
- No network access to internal services
- No execution of system commands

### Moderate Mode (Development)

```bash
docker compose run --rm clawdbot-cli config set gateway.sandbox.mode moderate
docker compose run --rm clawdbot-cli config set gateway.sandbox.allowedCommands '["ls", "cat", "grep"]'
```

**Moderate mode provides:**

- Limited file system access
- Whitelist of allowed commands
- Restricted network access

### Permissive Mode (Not Recommended)

⚠️ **WARNING**: Only use for local development with trusted inputs.

```bash
docker compose run --rm clawdbot-cli config set gateway.sandbox.mode permissive
```

## Network Security

### Localhost Binding

Always bind to localhost in production:

```bash
docker compose run --rm clawdbot-cli config set gateway.bind localhost
```

This ensures the gateway is only accessible from the local machine.

### CORS Configuration

Disable CORS unless specifically needed:

```bash
docker compose run --rm clawdbot-cli config set gateway.cors.enabled false
```

If CORS is required, use a strict whitelist:

```bash
docker compose run --rm clawdbot-cli config set gateway.cors.enabled true
docker compose run --rm clawdbot-cli config set gateway.cors.allowedOrigins '["https://trusted-domain.com"]'
```

### Rate Limiting

Enable rate limiting to prevent abuse:

```bash
docker compose run --rm clawdbot-cli config set gateway.security.rateLimit.enabled true
docker compose run --rm clawdbot-cli config set gateway.security.rateLimit.maxRequests 100
docker compose run --rm clawdbot-cli config set gateway.security.rateLimit.windowMs 60000
```

This limits to 100 requests per minute per IP.

## Authentication

### Token Management

1. **Never commit tokens to version control**
2. **Rotate tokens regularly** (every 90 days recommended)
3. **Use separate tokens for development and production**
4. **Revoke unused tokens immediately**

### Setup Token Security

Setup tokens (`st-...`) have elevated privileges:

- Store securely (password manager recommended)
- Use only during initial setup
- Delete after authentication complete
- Never share or expose in logs

### Provider Authentication

```bash
# List authenticated providers
docker compose run --rm clawdbot-cli models auth list

# Remove unused providers
docker compose run --rm clawdbot-cli models auth reset --provider <provider-name>
```

## Audit Logging

### Enable Comprehensive Logging

```bash
# Enable audit logging
docker compose run --rm clawdbot-cli config set gateway.audit.enabled true
docker compose run --rm clawdbot-cli config set gateway.audit.logLevel info

# Log all API requests
docker compose run --rm clawdbot-cli config set gateway.audit.logRequests true

# Log all tool executions
docker compose run --rm clawdbot-cli config set gateway.audit.logTools true
```

### Log Retention

Configure log rotation to prevent disk space issues:

```bash
# Set maximum log file size (in MB)
docker compose run --rm clawdbot-cli config set gateway.audit.maxLogSize 100

# Set maximum number of log files
docker compose run --rm clawdbot-cli config set gateway.audit.maxLogFiles 10
```

### Monitoring Logs

```bash
# View recent logs
docker compose logs --tail=100 clawdbot-gateway

# Follow logs in real-time
docker compose logs -f clawdbot-gateway

# Search logs for security events
docker compose logs clawdbot-gateway | grep -i "security\|auth\|error"
```

## Tool Restrictions

### Restrictive Policy (Recommended)

```bash
# Enable restrictive tool policy
docker compose run --rm clawdbot-cli config set gateway.tools.policy restrictive

# Empty allow list (no tools allowed by default)
docker compose run --rm clawdbot-cli config set gateway.tools.allowList "[]"
```

### Selective Tool Access

If specific tools are required:

```bash
# Allow only specific tools
docker compose run --rm clawdbot-cli config set gateway.tools.policy whitelist
docker compose run --rm clawdbot-cli config set gateway.tools.allowList '["read_file", "search_web"]'
```

### Tool Audit

```bash
# List all available tools
docker compose run --rm clawdbot-cli tools list

# Check tool permissions
docker compose run --rm clawdbot-cli tools check <tool-name>
```

## Prompt Injection Protection

Enable protection against prompt injection attacks:

```bash
docker compose run --rm clawdbot-cli config set gateway.security.promptInjection.enabled true
docker compose run --rm clawdbot-cli config set gateway.security.promptInjection.strictMode true
```

This filters potentially malicious prompts before processing.

## Security Checklist

### Initial Setup

- [ ] Sandbox enabled and set to strict mode
- [ ] Gateway bound to localhost only
- [ ] CORS disabled or strictly configured
- [ ] Rate limiting enabled
- [ ] Audit logging enabled
- [ ] Prompt injection protection enabled
- [ ] Tool policy set to restrictive
- [ ] Setup tokens stored securely

### Regular Maintenance

- [ ] Review audit logs weekly
- [ ] Rotate authentication tokens quarterly
- [ ] Update Docker images monthly
- [ ] Review and update tool allowlist
- [ ] Check for security updates
- [ ] Verify security configuration hasn't changed

### Incident Response

If you suspect a security incident:

1. **Immediately stop the gateway**:

   ```bash
   docker compose down
   ```

2. **Preserve logs**:

   ```bash
   cp -r ~/Development/clawdbot-workspace/data/logs ~/security-incident-$(date +%Y%m%d)
   ```

3. **Review audit logs** for suspicious activity

4. **Rotate all authentication tokens**:

   ```bash
   docker compose run --rm clawdbot-cli models auth reset --all
   ```

5. **Review and update security configuration**

6. **Restart with enhanced monitoring**:
   ```bash
   docker compose run --rm clawdbot-cli config set gateway.audit.logLevel debug
   docker compose up -d clawdbot-gateway
   ```

## Security Updates

Stay informed about security updates:

- Monitor the [Clawdbot GitHub repository](https://github.com/clawdbot/clawdbot)
- Subscribe to security announcements
- Enable GitHub security alerts
- Regularly run `docker compose pull` to get latest images

## Reporting Security Issues

If you discover a security vulnerability:

1. **Do not** open a public GitHub issue
2. Email security@clawd.bot with details
3. Include steps to reproduce if possible
4. Allow reasonable time for response before disclosure

## Additional Resources

- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
