# MCP Server Configurations

MCP servers used across projects. Each AI tool has its own MCP config — they are **not shared**.

| Tool | Config file | Setup script |
|------|------------|--------------|
| Claude Code | `~/.claude.json` | `scripts/setup-user-mcp.ps1` / `.sh` |
| Cursor | `~/.cursor/mcp.json` | `scripts/setup-cursor-mcp.ps1` / `.sh` |

## Servers

| Server | Package/URL | Transport | Auth |
|--------|-------------|-----------|------|
| Chrome DevTools | `chrome-devtools-mcp@latest` (npx) | stdio (local) | None |
| Vercel | `https://mcp.vercel.com` | HTTP (remote) | OAuth (browser) |
| Webflow | `https://mcp.webflow.com/mcp` | HTTP (remote) | OAuth (browser) |

All three servers are configured in both Claude Code and Cursor.

## Setup

### Claude Code

```powershell
# Windows
.\scripts\setup-user-mcp.ps1

# macOS
bash scripts/setup-user-mcp.sh
```

The scripts remove and re-add each server via `claude mcp` commands.

### Cursor

```powershell
# Windows
.\scripts\setup-cursor-mcp.ps1

# macOS
bash scripts/setup-cursor-mcp.sh
```

The scripts write `~/.cursor/mcp.json` directly (Cursor has no CLI for MCP management).

## Manual commands (Claude Code only)

### Windows

> **Known issue**: `claude mcp add` mangles `cmd /c` on Windows (interprets `/c` as a path).
> Use the setup script instead, which edits `~/.claude.json` directly for Chrome DevTools.

```
# Chrome DevTools — use setup script (see above) or edit ~/.claude.json directly
claude mcp add --transport http --scope user vercel https://mcp.vercel.com
claude mcp add --transport http --scope user webflow https://mcp.webflow.com/mcp
```

### macOS

```
claude mcp add chrome-devtools --scope user -- npx -y chrome-devtools-mcp@latest
claude mcp add --transport http --scope user vercel https://mcp.vercel.com
claude mcp add --transport http --scope user webflow https://mcp.webflow.com/mcp
```

## Post-setup

### Claude Code
1. Start a session and run `/mcp` to verify all three show green status
2. Authenticate Vercel and Webflow via OAuth browser flow
3. Chrome DevTools needs no auth

### Cursor
1. Restart Cursor after running the setup script
2. Go to **Cursor Settings > Tools & MCP** to see the servers
3. Authenticate Vercel and Webflow from the Tools & MCP settings page

## Platform notes

- **Windows**: Chrome DevTools requires `cmd /c` wrapper before `npx` — without it you get "Connection closed" errors. In Claude Code, `claude mcp add` mangles `/c` as a path, so the setup script edits `~/.claude.json` directly. In Cursor, we write the JSON directly so this isn't an issue
- **macOS**: Chrome DevTools uses `npx` directly on both tools
- Vercel and Webflow are remote HTTP servers — identical config on both platforms
- OAuth tokens are cached locally per tool and refreshed automatically
