# MCP Server Configurations

MCP servers used across projects. Each AI tool has its own MCP config — they are **not shared**.

## Two-Tier Architecture

| Tier | Scope | Servers | Setup |
|------|-------|---------|-------|
| **User-level** | All projects | chrome-devtools | `aitools install` (runs setup scripts) |
| **Project-level** | Per project | vercel, webflow | `aitools --addmcp <name>` |

User-level config reduces context bloat by only loading chrome-devtools globally.
Vercel and Webflow are added per-project where needed.

## Config Files

| Tool | User-level config | Project-level config |
|------|------------------|---------------------|
| Claude Code | `~/.claude.json` | `.mcp.json` (project root) |
| Cursor | `~/.cursor/mcp.json` | `.cursor/mcp.json` (project root) |

## Servers

| Server | Package/URL | Transport | Auth | Scope |
|--------|-------------|-----------|------|-------|
| Chrome DevTools | `chrome-devtools-mcp@latest` (npx) | stdio (local) | None | User |
| Vercel | `https://mcp.vercel.com` | HTTP (remote) | OAuth (browser) | Project |
| Webflow | `https://mcp.webflow.com/mcp` | HTTP (remote) | OAuth (browser) | Project |

## Setup

### User-Level (chrome-devtools)

Configured automatically by `aitools install`, which runs:

```powershell
# Windows
.\scripts\setup-user-mcp.ps1

# macOS
bash scripts/setup-user-mcp.sh
```

### Project-Level (vercel, webflow)

Add MCP servers to the current project for all AI tools:

```bash
cd ~/repos/my-project
aitools --addmcp vercel
aitools --addmcp vercel webflow
```

This creates/updates both `.mcp.json` (Claude Code) and `.cursor/mcp.json` (Cursor).
Safe to re-run — merges with existing config.

### Project-Level Config Format

**Claude Code (`.mcp.json`)**:
```json
{
  "mcpServers": {
    "vercel": {
      "type": "http",
      "url": "https://mcp.vercel.com"
    }
  }
}
```

**Cursor (`.cursor/mcp.json`)**:
```json
{
  "mcpServers": {
    "vercel": {
      "url": "https://mcp.vercel.com"
    }
  }
}
```

## Post-setup

### Claude Code
1. Start a session and run `/mcp` to verify servers show green status
2. Chrome DevTools needs no auth
3. Authenticate Vercel/Webflow via OAuth browser flow (if added to project)

### Cursor
1. Restart Cursor after running setup
2. Go to **Cursor Settings > Tools & MCP** to see servers
3. Authenticate Vercel/Webflow from the Tools & MCP settings page (if added to project)

## Platform Notes

- **Windows**: Chrome DevTools requires `cmd /c` wrapper before `npx`. In Claude Code, `claude mcp add` mangles `/c` as a path, so the setup script edits `~/.claude.json` directly.
- **macOS**: Chrome DevTools uses `npx` directly on both tools.
- Vercel and Webflow are remote HTTP servers — identical config on both platforms.
- OAuth tokens are cached locally per tool and refreshed automatically.

## Documentation Sources

See `reference/tool-install-sources.md` for official documentation links and verified install commands.
