# Docker Configuration Guide

Detailed explanation of the Clawdbot Docker setup and configuration options.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Docker Compose Configuration](#docker-compose-configuration)
- [Environment Variables](#environment-variables)
- [Volume Management](#volume-management)
- [Networking](#networking)
- [Resource Limits](#resource-limits)
- [Health Checks](#health-checks)
- [Customization](#customization)

## Architecture Overview

The Clawdbot Docker setup consists of two main services:

### 1. Gateway Service (`clawdbot-gateway`)

- **Purpose**: Main API server that handles requests and routes them to AI providers
- **Image**: `clawdbot/gateway:latest`
- **Port**: 3000 (configurable)
- **Restart Policy**: `unless-stopped` (auto-restart on failure)
- **Dependencies**: None (standalone service)

### 2. CLI Service (`clawdbot-cli`)

- **Purpose**: Command-line interface for configuration and management
- **Image**: `clawdbot/cli:latest`
- **Profile**: `cli` (only runs when explicitly called)
- **Dependencies**: Gateway service
- **Usage**: One-off commands via `docker compose run`

## Docker Compose Configuration

### Service Definitions

#### Gateway Service

```yaml
clawdbot-gateway:
  image: clawdbot/gateway:latest
  container_name: clawdbot-gateway
  restart: unless-stopped
  ports:
    - "${CLAWDBOT_GATEWAY_PORT:-3000}:3000"
  environment:
    - NODE_ENV=production
    - CLAWDBOT_HOME=/data
    - LOG_LEVEL=${CLAWDBOT_LOG_LEVEL:-info}
    - GATEWAY_BIND=${CLAWDBOT_GATEWAY_BIND:-localhost}
  volumes:
    - ${CLAWDBOT_HOME_VOLUME:-./data}:/data
    - /var/run/docker.sock:/var/run/docker.sock:ro
  networks:
    - clawdbot-network
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 40s
  deploy:
    resources:
      limits:
        cpus: "2"
        memory: 4G
      reservations:
        cpus: "0.5"
        memory: 1G
```

**Key Points:**

- Uses environment variable substitution with defaults
- Mounts Docker socket for container management (read-only)
- Includes health check for monitoring
- Resource limits prevent runaway processes

#### CLI Service

```yaml
clawdbot-cli:
  image: clawdbot/cli:latest
  container_name: clawdbot-cli
  profiles:
    - cli
  environment:
    - CLAWDBOT_HOME=/data
    - LOG_LEVEL=${CLAWDBOT_LOG_LEVEL:-info}
  volumes:
    - ${CLAWDBOT_HOME_VOLUME:-./data}:/data
  networks:
    - clawdbot-network
  depends_on:
    - clawdbot-gateway
```

**Key Points:**

- Uses `profiles` to prevent auto-start
- Shares same data volume as gateway
- Depends on gateway for certain operations

## Environment Variables

### Required Variables

#### `CLAWDBOT_HOME_VOLUME`

- **Description**: Path to persistent data storage on host
- **Default**: `./data` (relative to docker-compose.yml)
- **Recommended**: `$HOME/Development/clawdbot-workspace/data`
- **Example**:
  ```bash
  export CLAWDBOT_HOME_VOLUME="$HOME/Development/clawdbot-workspace/data"
  ```

### Optional Variables

#### `CLAWDBOT_GATEWAY_PORT`

- **Description**: External port for gateway API
- **Default**: `3000`
- **Range**: `1024-65535`
- **Example**:
  ```bash
  export CLAWDBOT_GATEWAY_PORT=8080
  ```

#### `CLAWDBOT_LOG_LEVEL`

- **Description**: Logging verbosity
- **Default**: `info`
- **Options**: `debug`, `info`, `warn`, `error`
- **Example**:
  ```bash
  export CLAWDBOT_LOG_LEVEL=debug
  ```

#### `CLAWDBOT_GATEWAY_BIND`

- **Description**: Network interface to bind to
- **Default**: `localhost`
- **Options**: `localhost`, `0.0.0.0`, specific IP
- **Security**: Use `localhost` for production
- **Example**:
  ```bash
  export CLAWDBOT_GATEWAY_BIND=localhost
  ```

### Setting Environment Variables

#### Method 1: .env File (Recommended)

```bash
# Copy example file
cp .env.example .env

# Edit .env file
nano .env

# Docker Compose automatically loads .env
docker compose up -d
```

#### Method 2: Shell Export

```bash
# Set in current shell
export CLAWDBOT_HOME_VOLUME="$HOME/Development/clawdbot-workspace/data"
export CLAWDBOT_GATEWAY_PORT=3000

# Make permanent (add to ~/.zshrc)
echo 'export CLAWDBOT_HOME_VOLUME="$HOME/Development/clawdbot-workspace/data"' >> ~/.zshrc
```

#### Method 3: Inline

```bash
CLAWDBOT_GATEWAY_PORT=8080 docker compose up -d
```

## Volume Management

### Data Volume

```yaml
volumes:
  - ${CLAWDBOT_HOME_VOLUME:-./data}:/data
```

**Host Path**: `~/Development/clawdbot-workspace/data`  
**Container Path**: `/data`  
**Purpose**: Persistent storage for configuration, logs, and cache

**Directory Structure**:

```
data/
├── config/          # Configuration files
│   └── gateway.json
├── logs/            # Application logs
│   ├── gateway.log
│   └── audit.log
└── cache/           # Temporary cache
    └── models/
```

### Docker Socket Volume

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:ro
```

**Purpose**: Allows gateway to manage Docker containers  
**Mode**: Read-only (`:ro`) for security  
**Security Note**: This grants container access to Docker daemon

### Volume Backup

```bash
# Backup entire data directory
tar -czf clawdbot-backup-$(date +%Y%m%d).tar.gz \
  ~/Development/clawdbot-workspace/data

# Restore from backup
tar -xzf clawdbot-backup-20260125.tar.gz -C ~/Development/clawdbot-workspace/
```

## Networking

### Network Configuration

```yaml
networks:
  clawdbot-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16
```

**Network Type**: Bridge (isolated network)  
**Subnet**: `172.28.0.0/16`  
**Purpose**: Isolate Clawdbot containers from other Docker networks

### Port Mapping

```yaml
ports:
  - "${CLAWDBOT_GATEWAY_PORT:-3000}:3000"
```

**Format**: `HOST_PORT:CONTAINER_PORT`  
**Default**: `3000:3000`  
**Customizable**: Via `CLAWDBOT_GATEWAY_PORT` environment variable

### Network Isolation

The bridge network provides:

- **Isolation**: Containers can't access other Docker networks
- **DNS**: Automatic service discovery (containers can reach each other by name)
- **Security**: No direct access to host network

### Accessing the Gateway

```bash
# From host machine
curl http://localhost:3000/health

# From another container in same network
curl http://clawdbot-gateway:3000/health

# From external machine (if bind is 0.0.0.0)
curl http://<host-ip>:3000/health
```

## Resource Limits

### CPU Limits

```yaml
deploy:
  resources:
    limits:
      cpus: "2"
    reservations:
      cpus: "0.5"
```

**Limits**: Maximum 2 CPU cores  
**Reservations**: Guaranteed 0.5 CPU cores  
**Purpose**: Prevent CPU starvation of other processes

### Memory Limits

```yaml
deploy:
  resources:
    limits:
      memory: 4G
    reservations:
      memory: 1G
```

**Limits**: Maximum 4GB RAM  
**Reservations**: Guaranteed 1GB RAM  
**Purpose**: Prevent out-of-memory errors on host

### Customizing Limits

Edit `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: "4" # Increase for heavy workloads
      memory: 8G # Increase for large models
    reservations:
      cpus: "1"
      memory: 2G
```

Then restart:

```bash
docker compose up -d clawdbot-gateway
```

### Monitoring Resource Usage

```bash
# Real-time stats
docker stats clawdbot-gateway

# Check current limits
docker inspect clawdbot-gateway | grep -A 10 Resources
```

## Health Checks

### Configuration

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

**Test**: HTTP GET to `/health` endpoint  
**Interval**: Check every 30 seconds  
**Timeout**: Fail if no response in 10 seconds  
**Retries**: Mark unhealthy after 3 consecutive failures  
**Start Period**: Grace period of 40 seconds on startup

### Health Check States

- **Starting**: During start_period (first 40 seconds)
- **Healthy**: Health check passing
- **Unhealthy**: Health check failing after retries

### Viewing Health Status

```bash
# Check health status
docker compose ps

# Detailed health info
docker inspect clawdbot-gateway | grep -A 20 Health

# Health check logs
docker compose logs clawdbot-gateway | grep health
```

### Custom Health Checks

Modify `docker-compose.yml` to add custom checks:

```yaml
healthcheck:
  test:
    [
      "CMD",
      "sh",
      "-c",
      "curl -f http://localhost:3000/health && curl -f http://localhost:3000/api/status",
    ]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

## Customization

### Adding Environment Variables

Edit `docker-compose.yml`:

```yaml
environment:
  - NODE_ENV=production
  - CLAWDBOT_HOME=/data
  - LOG_LEVEL=${CLAWDBOT_LOG_LEVEL:-info}
  - CUSTOM_VAR=${MY_CUSTOM_VAR:-default_value}
```

### Adding Volume Mounts

```yaml
volumes:
  - ${CLAWDBOT_HOME_VOLUME:-./data}:/data
  - ./custom-config:/app/config:ro # Read-only custom config
  - ./plugins:/app/plugins # Custom plugins
```

### Using Docker Compose Override

Create `docker-compose.override.yml` for local customizations:

```yaml
version: "3.8"

services:
  clawdbot-gateway:
    environment:
      - DEBUG=true
    ports:
      - "3001:3000" # Use different port
    deploy:
      resources:
        limits:
          cpus: "4"
          memory: 8G
```

This file is automatically merged with `docker-compose.yml` and is gitignored.

### Multiple Environments

```bash
# Development
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Production
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## Best Practices

### 1. Use Named Volumes for Production

```yaml
volumes:
  clawdbot-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /path/to/persistent/storage
```

### 2. Set Resource Limits

Always set CPU and memory limits to prevent resource exhaustion.

### 3. Use Health Checks

Health checks enable automatic recovery and monitoring.

### 4. Bind to Localhost

For security, always bind to `localhost` unless external access is required.

### 5. Regular Backups

Automate backups of the data volume:

```bash
# Add to crontab
0 2 * * * tar -czf ~/backups/clawdbot-$(date +\%Y\%m\%d).tar.gz ~/Development/clawdbot-workspace/data
```

### 6. Monitor Logs

Set up log rotation to prevent disk space issues:

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

### 7. Use .env for Secrets

Never commit `.env` file to version control. Use `.env.example` as template.

## Troubleshooting Docker Issues

### Container Won't Start

```bash
# Check logs
docker compose logs clawdbot-gateway

# Validate compose file
docker compose config

# Check for port conflicts
lsof -i :3000
```

### Volume Permission Issues

```bash
# Fix permissions
sudo chown -R $(whoami) ~/Development/clawdbot-workspace/data
chmod -R 755 ~/Development/clawdbot-workspace/data
```

### Network Issues

```bash
# Recreate network
docker compose down
docker network prune
docker compose up -d
```

### Resource Exhaustion

```bash
# Check Docker disk usage
docker system df

# Clean up
docker system prune -a
```

## Advanced Configuration

### Using External Database

```yaml
services:
  clawdbot-gateway:
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/clawdbot
    depends_on:
      - db

  db:
    image: postgres:15
    volumes:
      - postgres-data:/var/lib/postgresql/data
```

### Adding Reverse Proxy

```yaml
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - clawdbot-gateway
```

### Using Docker Secrets

```yaml
services:
  clawdbot-gateway:
    secrets:
      - api_key
      - db_password

secrets:
  api_key:
    file: ./secrets/api_key.txt
  db_password:
    file: ./secrets/db_password.txt
```

## References

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Docker Networking](https://docs.docker.com/network/)
- [Docker Volumes](https://docs.docker.com/storage/volumes/)
- [Health Checks](https://docs.docker.com/engine/reference/builder/#healthcheck)
