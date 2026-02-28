# Scripts

Setup and utility scripts for configuring AI tooling across machines.

## CLI Entry Points

| Script | Platform | Purpose |
|--------|----------|---------|
| `aitools` | macOS/Linux (bash) | CLI: sync configs, gitpull, install, --addmcp, mcp status |
| `aitools.ps1` | Windows (PowerShell) | CLI: same commands, native PowerShell implementation |
| `aitools-install.sh` | macOS/Linux | Full installer (tools + deploy configs) |
| `aitools-install.ps1` | Windows | Full installer (tools + deploy configs) |

## Setup Scripts

| Script | Platform | Purpose |
|--------|----------|---------|
| `setup-user-claude.ps1` | Windows | Creates `~/.claude/CLAUDE.md` with shared import |
| `setup-user-claude.sh` | macOS/Linux | Creates `~/.claude/CLAUDE.md` with shared import |
| `setup-user-mcp.ps1` | Windows | Installs/updates user-level MCP servers for Claude Code |
| `setup-user-mcp.sh` | macOS/Linux | Installs/updates user-level MCP servers for Claude Code |
| `setup-user-cursor.ps1` | Windows | Installs ripgrep + Cursor CLI, writes `cli-config.json` |
| `setup-user-cursor.sh` | macOS/Linux | Installs ripgrep + Cursor CLI, writes `cli-config.json` |
| `setup-cursor-mcp.ps1` | Windows | Writes `~/.cursor/mcp.json` with MCP servers for Cursor |
| `setup-cursor-mcp.sh` | macOS/Linux | Writes `~/.cursor/mcp.json` with MCP servers for Cursor |
| `setup-vercelcli.ps1` | Windows | Installs/updates Vercel CLI via npm |
| `setup-vercelcli.sh` | macOS/Linux | Installs/updates Vercel CLI via Homebrew (macOS) or npm (Linux) |
| `setup-pandoc.ps1` | Windows | Installs/updates Pandoc via winget |
| `setup-pandoc.sh` | macOS/Linux | Installs/updates Pandoc via Homebrew |
| `setup-user-hooks.ps1` | Windows | Deploys Claude Code SessionEnd hook to `~/.claude/settings.json` |
| `setup-user-hooks.sh` | macOS/Linux | Deploys Claude Code SessionEnd hook to `~/.claude/settings.json` |

## Verification Scripts

| Script | Platform | Purpose |
|--------|----------|---------|
| `check-lib.sh` | macOS/Linux | Shared library: colors, counters, step formatters (sourced) |
| `check-lib.ps1` | Windows | Shared library (dot-sourced) |
| `check-pre-commit.sh` | macOS/Linux | 12 pre-commit steps; `--fix` auto-repairs line endings, exec bits, build |
| `check-pre-commit.ps1` | Windows | 12 pre-commit steps; `-Fix` switch |
| `check-pre-push.sh` | macOS/Linux | 10 pre-push steps, read-only |
| `check-pre-push.ps1` | Windows | 10 pre-push steps, read-only |
| `check-post-push.sh` | macOS/Linux | 5 always-tier + 15 extensive steps; `--extensive` flag |
| `check-post-push.ps1` | Windows | 5 always-tier + 15 extensive steps; `-Extensive` switch |

## Build Pipeline

| Script | Platform | Purpose |
|--------|----------|---------|
| `build-deploy.sh` | macOS/Linux (bash only) | Generates `deploy/` from `scripts/` + `shared/` |

## OS Guards

All scripts include OS guards:
- **Setup scripts** (`.sh`/`.ps1`): Hard-block the wrong platform with an error and exit
- **CLI entry points** (`aitools`, `aitools-install.sh`): Detect Windows and forward to the `.ps1` variant via `pwsh -File` instead of hard-blocking

This prevents deploy scripts from accidentally running on the wrong platform, while the CLI entry points provide a seamless cross-platform experience.

## Usage

### User-level CLAUDE.md

```powershell
# Windows
.\scripts\setup-user-claude.ps1

# macOS
bash scripts/setup-user-claude.sh
```

Safe to re-run — backs up the existing file (up to 20 timestamped copies) then replaces with the latest version.

### Claude Code MCP Servers

```powershell
# Windows
.\scripts\setup-user-mcp.ps1

# macOS
bash scripts/setup-user-mcp.sh
```

Safe to re-run — removes and re-adds each MCP server to ensure latest config.

After running, start a Claude Code session and run `/mcp` to verify servers and authenticate Vercel + Webflow via OAuth.

### Cursor CLI + User Config

```powershell
# Windows
.\scripts\setup-user-cursor.ps1

# macOS
bash scripts/setup-user-cursor.sh
```

Safe to re-run — checks each step and skips what's already done. Installs ripgrep (required by Cursor CLI) and the CLI itself if missing, and writes `cli-config.json` if changed.

### Cursor MCP Servers

```powershell
# Windows
.\scripts\setup-cursor-mcp.ps1

# macOS
bash scripts/setup-cursor-mcp.sh
```

Safe to re-run — backs up the existing file then replaces with the latest config.

After running, restart Cursor and go to **Cursor Settings > Tools & MCP** to verify servers appear and authenticate Vercel + Webflow.

See `shared/mcp/README.md` for details on each server.

### Vercel CLI

```powershell
# Windows
.\scripts\setup-vercelcli.ps1

# macOS
bash scripts/setup-vercelcli.sh
```

Safe to re-run — detects existing install and upgrades or migrates as needed. On macOS, uses Homebrew for Claude Code PATH compatibility.
