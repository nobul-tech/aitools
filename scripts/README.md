# Scripts

Setup and utility scripts for configuring AI tooling across machines.

## Setup Scripts

| Script | Platform | Purpose |
|--------|----------|---------|
| `setup-user-claude.ps1` | Windows | Creates `~/.claude/CLAUDE.md` with shared import |
| `setup-user-claude.sh` | macOS/Linux | Creates `~/.claude/CLAUDE.md` with shared import |
| `setup-user-mcp.ps1` | Windows | Installs/updates user-level MCP servers for Claude Code |
| `setup-user-mcp.sh` | macOS/Linux | Installs/updates user-level MCP servers for Claude Code |
| `setup-user-cursor.ps1` | Windows | Installs ripgrep + Cursor CLI, writes `cli-config.json`, copies User Rules to clipboard |
| `setup-user-cursor.sh` | macOS/Linux | Installs ripgrep + Cursor CLI, writes `cli-config.json`, copies User Rules to clipboard |
| `setup-cursor-mcp.ps1` | Windows | Writes `~/.cursor/mcp.json` with MCP servers for Cursor |
| `setup-cursor-mcp.sh` | macOS/Linux | Writes `~/.cursor/mcp.json` with MCP servers for Cursor |

## Usage

### User-level CLAUDE.md

```powershell
# Windows
.\scripts\setup-user-claude.ps1

# macOS
bash scripts/setup-user-claude.sh
```

Safe to re-run — replaces the existing `~/.claude/CLAUDE.md` with the latest version.

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

Safe to re-run — checks each step and skips what's already done. Installs ripgrep (required by Cursor CLI) and the CLI itself if missing, writes `cli-config.json` if changed, and copies User Rules to clipboard.

After running, paste clipboard contents into **Cursor Settings > Rules**. Source of truth for User Rules: `shared/cursor-rules/user-rules.md`.

### Cursor MCP Servers

```powershell
# Windows
.\scripts\setup-cursor-mcp.ps1

# macOS
bash scripts/setup-cursor-mcp.sh
```

Safe to re-run — replaces `~/.cursor/mcp.json` with the latest config.

After running, restart Cursor and go to **Cursor Settings > Tools & MCP** to verify servers appear and authenticate Vercel + Webflow.

See `shared/mcp/README.md` for details on each server.
