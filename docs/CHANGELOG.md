# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial project setup
- Docker Compose configuration
- Automated setup script
- Comprehensive documentation suite
- Security configuration guide
- Troubleshooting guide
- Quick reference guide
- Docker configuration guide

## [1.0.0] - 2026-01-25

### Added

- Initial release of Clawdbot Docker setup
- Docker Compose configuration with gateway and CLI services
- Automated `docker-setup.sh` script with prerequisite checks
- Environment variable configuration via `.env` file
- Persistent data volume management
- Health check configuration
- Resource limits (CPU and memory)
- Network isolation with bridge networking
- Comprehensive documentation:
  - Main README with quick start guide
  - QUICK_REFERENCE.md with essential commands
  - SECURITY.md with security best practices
  - TROUBLESHOOTING.md with common issues and solutions
  - DOCKER_GUIDE.md with detailed configuration reference
  - FILE_STRUCTURE.md with repository overview
- Security features:
  - Strict sandbox mode
  - Localhost-only binding
  - Restrictive tool policies
  - Audit logging
  - Prompt injection protection
  - Rate limiting
- Support for multiple AI providers:
  - Anthropic (Claude) via setup-token
  - Google Antigravity via OAuth
- CLI commands for:
  - Configuration management
  - Provider authentication
  - Health diagnostics
  - Plugin management

### Security

- Default configuration uses strict sandbox mode
- Gateway binds to localhost only by default
- Docker socket mounted read-only
- Comprehensive security documentation
- Audit logging capabilities

### Documentation

- Complete setup guide for macOS
- Step-by-step authentication instructions
- Security best practices
- Troubleshooting for common issues
- Docker configuration reference
- Quick reference for daily operations

## Version History

### [1.0.0] - 2026-01-25

- Initial release

---

## Release Notes Template

Use this template for future releases:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added

- New features

### Changed

- Changes in existing functionality

### Deprecated

- Soon-to-be removed features

### Removed

- Removed features

### Fixed

- Bug fixes

### Security

- Security improvements
```

## Upgrade Guide

### From 0.x to 1.0.0

This is the initial release. No upgrade path needed.

### Future Upgrades

Upgrade instructions will be added here for future versions.

---

## Contributing

When making changes:

1. Update this CHANGELOG.md
2. Update relevant documentation
3. Update version numbers in:
   - docker-compose.yml (image tags)
   - README.md (if applicable)
4. Tag releases in git:
   ```bash
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin v1.0.0
   ```

## Links

- [Repository](https://github.com/clawdbot/clawdbot)
- [Documentation](https://docs.clawd.bot)
- [Issues](https://github.com/clawdbot/clawdbot/issues)
- [Releases](https://github.com/clawdbot/clawdbot/releases)
