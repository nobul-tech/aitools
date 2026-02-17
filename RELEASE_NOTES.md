# aitools Release Notes

## v3 — Config Sync, Version Tagging, Config Backups (2026-02-16)

### New command structure

| Command | What it does |
|---------|-------------|
| `aitools` (no args) | Quiet pull + rebuild + deploy all configs. Warns and continues if offline. |
| `aitools gitpull` | Pull + rebuild + deploy + date-formatted changelog + version tag. Clones repo if missing. |
| `aitools install` | Pull + rebuild + install all tools + deploy configs (unchanged). |

**Machine-switching workflow:**
- Arrive at machine → `aitools` (quick sync) or `aitools gitpull` (verbose changelog)
- Full setup → `aitools install`

### Version tagging

`aitools gitpull` creates and pushes a version tag: `v<date>.<session>.0` (e.g., `v2026-02-16.1.0`).
Commits after a tag are shown by `--version` as `2026-02-16.1.3` (3 commits since tag).
Falls back to `YYYY-MM-DD (hash)` when no tags exist.

### Config file backups

Setup scripts now back up files before overwriting. Keeps at most 20 timestamped copies per file.

| File | Backed up by |
|------|-------------|
| `~/.claude/CLAUDE.md` | `setup-user-claude` |
| `~/.cursor/mcp.json` | `setup-cursor-mcp` |

Backup format: `<file>.bak.<ISO-UTC-timestamp>` (e.g., `CLAUDE.md.bak.2026-02-17T023527Z`)

### Cross-platform fix

The bash `aitools` entry point now correctly dispatches to `.ps1` scripts via `powershell.exe` on Windows for all code paths (no-args, gitpull, install). Previously, only the `install` path had this forwarding — the new `deploy_configs()` function was missing it.

Added dispatch rule documentation to user-level CLAUDE.md, project CLAUDE.md, and `.claude/rules/cross-platform.md` to prevent recurrence.

---

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
