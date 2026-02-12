# Scripts

Setup and utility scripts for configuring AI tooling across machines.

## Setup Scripts

| Script | Platform | Purpose |
|--------|----------|---------|
| `setup-user-claude.ps1` | Windows | Creates `~/.claude/CLAUDE.md` with shared import |
| `setup-user-claude.sh` | macOS/Linux | Creates `~/.claude/CLAUDE.md` with shared import |
| `setup-user-mcp.ps1` | Windows | Installs/updates user-level MCP servers for Claude Code |
| `setup-user-mcp.sh` | macOS/Linux | Installs/updates user-level MCP servers for Claude Code |

## Usage

### User-level CLAUDE.md

```powershell
# Windows
.\scripts\setup-user-claude.ps1

# macOS
bash scripts/setup-user-claude.sh
```

Safe to re-run — replaces the existing `~/.claude/CLAUDE.md` with the latest version.

### MCP Servers

```powershell
# Windows
.\scripts\setup-user-mcp.ps1

# macOS
bash scripts/setup-user-mcp.sh
```

Safe to re-run — removes and re-adds each MCP server to ensure latest config.

After running, start a Claude Code session and run `/mcp` to verify servers and authenticate Vercel + Webflow via OAuth.

See `shared/mcp/README.md` for details on each server.
