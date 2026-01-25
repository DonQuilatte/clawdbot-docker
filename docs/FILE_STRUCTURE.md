# File Structure

Overview of all files in this repository and their purposes.

## 📄 Core Files

### `README.md`

Main entry point with quick start guide and links to detailed documentation.

### `docker-compose.yml`

Docker Compose configuration defining the gateway and CLI services, networking, volumes, and resource limits.

### `docker-setup.sh` (executable)

Automated setup script that:

- Checks prerequisites (Docker, Node.js, etc.)
- Creates data directory structure
- Generates default configuration
- Pulls Docker images
- Displays next steps

### `.env.example`

Template for environment variables. Copy to `.env` and customize:

- `CLAWDBOT_HOME_VOLUME` - Data storage path
- `CLAWDBOT_GATEWAY_PORT` - API port (default: 3000)
- `CLAWDBOT_LOG_LEVEL` - Logging verbosity
- `CLAWDBOT_GATEWAY_BIND` - Network binding

### `.gitignore`

Git ignore rules for:

- Environment files (`.env`)
- Data directories
- macOS system files
- Node modules
- Backup files

## 📚 Documentation

### `QUICK_REFERENCE.md`

Essential commands organized by category:

- Gateway control (start/stop/restart)
- Configuration management
- Authentication
- Health checks & diagnostics
- Security commands
- Maintenance & debugging

### `SECURITY.md`

Comprehensive security guide covering:

- Security principles
- Sandbox configuration (strict/moderate/permissive)
- Network security (localhost binding, CORS, rate limiting)
- Authentication & token management
- Audit logging
- Tool restrictions
- Prompt injection protection
- Security checklist
- Incident response procedures

### `TROUBLESHOOTING.md`

Solutions for common issues:

- Installation problems
- Authentication failures
- Gateway issues
- Network connectivity
- Performance problems
- Data & storage issues
- Diagnostic tools
- Full reset procedures

### `DOCKER_GUIDE.md`

Detailed Docker configuration reference:

- Architecture overview
- Docker Compose configuration
- Environment variables
- Volume management
- Networking
- Resource limits
- Health checks
- Customization options
- Best practices

### `FILE_STRUCTURE.md` (this file)

Overview of repository structure and file purposes.

## 📁 Directory Structure

```
clawdbot/
├── README.md                    # Main documentation
├── QUICK_REFERENCE.md          # Command cheat sheet
├── SECURITY.md                 # Security guide
├── TROUBLESHOOTING.md          # Problem solving
├── DOCKER_GUIDE.md             # Docker configuration
├── FILE_STRUCTURE.md           # This file
├── docker-compose.yml          # Docker Compose config
├── docker-setup.sh             # Setup script (executable)
├── .env.example                # Environment template
├── .gitignore                  # Git ignore rules
└── data/                       # Created by setup script
    ├── config/                 # Configuration files
    │   └── gateway.json
    ├── logs/                   # Application logs
    │   ├── gateway.log
    │   └── audit.log
    └── cache/                  # Temporary cache
        └── models/
```

## 🚀 Getting Started

1. **First Time Setup**:

   ```bash
   ./docker-setup.sh
   ```

2. **Read Documentation**:

   - Start with `README.md` for overview
   - Check `QUICK_REFERENCE.md` for commands
   - Review `SECURITY.md` for security setup
   - Consult `TROUBLESHOOTING.md` if issues arise

3. **Configure Environment**:

   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

4. **Follow Setup Steps** in `README.md`

## 📖 Documentation Flow

```
README.md (Start Here)
    ↓
QUICK_REFERENCE.md (Daily Commands)
    ↓
SECURITY.md (Security Setup)
    ↓
DOCKER_GUIDE.md (Advanced Config)
    ↓
TROUBLESHOOTING.md (When Issues Occur)
```

## 🔍 Finding Information

### "How do I start the gateway?"

→ `QUICK_REFERENCE.md` - Gateway Control section

### "How do I configure security?"

→ `SECURITY.md` - Security Configuration section

### "The gateway won't start"

→ `TROUBLESHOOTING.md` - Gateway Issues section

### "How do I change the port?"

→ `DOCKER_GUIDE.md` - Environment Variables section

### "What commands are available?"

→ `QUICK_REFERENCE.md` - All sections

### "How do I customize Docker setup?"

→ `DOCKER_GUIDE.md` - Customization section

## 🛠️ File Maintenance

### Regular Updates

- `README.md` - Update version numbers and links
- `QUICK_REFERENCE.md` - Add new commands as features are added
- `SECURITY.md` - Update security recommendations
- `TROUBLESHOOTING.md` - Add new issues and solutions
- `DOCKER_GUIDE.md` - Update configuration options

### Version Control

- Commit all documentation changes
- Tag releases with version numbers
- Keep `.env.example` updated with new variables
- Never commit `.env` file

### Backup Important Files

```bash
# Backup configuration
cp .env .env.backup

# Backup data directory
tar -czf clawdbot-backup-$(date +%Y%m%d).tar.gz data/
```

## 📝 Contributing

When adding new features:

1. Update relevant documentation files
2. Add commands to `QUICK_REFERENCE.md`
3. Document configuration in `DOCKER_GUIDE.md`
4. Add troubleshooting tips to `TROUBLESHOOTING.md`
5. Update security considerations in `SECURITY.md`
6. Update this file if structure changes

## 🔗 External Resources

- **Clawdbot Repository**: https://github.com/clawdbot/clawdbot
- **Documentation Site**: https://docs.clawd.bot
- **Discord Community**: https://discord.gg/clawdbot
- **Issue Tracker**: https://github.com/clawdbot/clawdbot/issues

## 📄 License

All documentation and configuration files in this repository are provided as-is for use with Clawdbot.
