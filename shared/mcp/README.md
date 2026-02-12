# MCP Server Configurations

MCP servers used across projects, configured at the user level (`--scope user`).

## Servers

| Server | Package/URL | Transport | Auth | Scope |
|--------|-------------|-----------|------|-------|
| Chrome DevTools | `chrome-devtools-mcp@latest` (npx) | stdio (local) | None | All projects |
| Vercel | `https://mcp.vercel.com` | HTTP (remote) | OAuth (browser) | All projects |
| Webflow | `https://mcp.webflow.com/mcp` | HTTP (remote) | OAuth (browser) | All projects |

## Setup

Run the setup script to install/update all MCP servers:

**Windows (PowerShell):**
```powershell
.\scripts\setup-user-mcp.ps1
```

**macOS:**
```bash
bash scripts/setup-user-mcp.sh
```

The scripts are safe to re-run — they remove and re-add each server to ensure the latest config.

## Manual commands

### Windows

```
claude mcp add chrome-devtools --scope user -- cmd /c npx -y chrome-devtools-mcp@latest
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

After adding servers, start a Claude Code session and run `/mcp` to:
1. Verify all three show green status
2. Authenticate Vercel (OAuth browser flow)
3. Authenticate Webflow (OAuth browser flow)
4. Chrome DevTools needs no auth

## Platform notes

- **Windows**: Chrome DevTools requires `cmd /c` wrapper before `npx` — without it you get "Connection closed" errors
- **macOS**: Chrome DevTools uses `npx` directly
- Vercel and Webflow are remote HTTP servers — identical config on both platforms
- OAuth tokens are cached locally and refreshed automatically
