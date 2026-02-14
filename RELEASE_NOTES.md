# aitools Release Notes

## v2 — CLI Subcommands, MCP Restructuring, Full Tool Chain (2026-02-14)

### CLI Subcommands

`aitools` now separates sync from install:

- `aitools` — Pull latest + rebuild deploy scripts + self-update. Does not install.
- `aitools install` — Install/update ALL dev tools and deploy configurations.
- `aitools --addmcp <name...>` — Add MCP servers to the current project.

### Full Tool Chain via `aitools install`

`aitools install` is now the single command that installs and updates everything:

| Tool | Install method |
|------|---------------|
| GitHub CLI (gh) | brew (macOS) / winget (Windows) |
| Node.js | brew (macOS) / winget (Windows) |
| Claude Code CLI | Native installer (auto-updates) / winget (Windows) |
| Vercel CLI | npm install -g vercel |
| Cursor CLI | Official installer |
| ripgrep | brew (macOS) / winget (Windows) |
| Chrome DevTools MCP | Configured at user level |

### MCP Architecture Change

User-level MCP now includes **only chrome-devtools**. Vercel and Webflow are now
added per-project to reduce context bloat (flagged by `claude doctor`).

- **Before**: chrome-devtools, vercel, webflow all at user level
- **After**: chrome-devtools at user level; vercel/webflow at project level via `--addmcp`

Legacy user-level vercel/webflow entries are cleaned up on next `aitools install`.

### New: `aitools --addmcp`

Add MCP servers to the current project for all AI tools (Claude Code + Cursor):

    cd ~/repos/my-project
    aitools --addmcp vercel
    aitools --addmcp vercel webflow

Creates/updates `.mcp.json` (Claude Code) and `.cursor/mcp.json` (Cursor).
Merges with existing config — safe to re-run.

Supported servers: `vercel`, `webflow`

### Logging Improvements

All MCP setup scripts now include structured logging:
- macOS: ~/Library/Logs/ai-tooling/deploy.log
- Windows: %LOCALAPPDATA%\ai-tooling\deploy.log

All paths in log output use native OS format.

### Documentation

- New `reference/tool-install-sources.md` — official docs and verified install commands for all managed tools
- Updated `shared/mcp/README.md` — two-tier MCP architecture docs
- Updated `CLAUDE.md` — new CLI usage examples
