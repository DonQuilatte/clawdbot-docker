# MCP Deployment Package - Changelog

## [1.1.0] - 2026-01-29

### Fixed
- **CRITICAL:** MCP wrappers now include Homebrew in PATH (`/opt/homebrew/bin:/usr/local/bin`)
  - Fixes `npx: command not found` errors in IDEs
  - Required for Antigravity, Cursor, VS Code MCP server execution

- **MCP Server Names:** Changed from `@gitkraken/mcp-server` (non-existent) to `@modelcontextprotocol/server-github`
  - gitkraken package doesn't exist in npm registry
  - All configs now reference "github" server instead of "gitkraken"

### Added
- **Antigravity IDE support:** 
  - Creates `.antigravity/config.json` with MCP server configuration
  - Auto-loads MCP servers when project opens
  - Uses `${workspaceFolder}` variable for path resolution

- **Better PATH handling:**
  - Wrappers explicitly export PATH with Homebrew locations
  - Works across different shell environments (sh, bash, zsh)

### Changed
- Updated `project-setup.sh` to generate correct wrapper scripts
- Updated all MCP JSON configs to use "github" instead of "gitkraken"
- Added Antigravity to AI CLI support matrix

## [1.0.0] - 2026-01-28

Initial release with:
- Workspace-scoped MCP configurations
- 1Password credential management
- direnv environment switching
- Cursor and VS Code support
- Claude Code and Gemini CLI support
