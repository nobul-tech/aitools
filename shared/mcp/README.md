# MCP Server Configurations

MCP servers used across projects. Each AI tool has its own MCP config — they are **not shared**.

## Architecture (v3)

All three servers installed at user level. Chrome DevTools enabled globally; Vercel and Webflow disabled by default. Per-project, use `aitools --addmcp` to enable.

| Server | Transport | Default State | Enable per project |
|--------|-----------|---------------|-------------------|
| Chrome DevTools | stdio (local) | **Enabled** | N/A (always on) |
| Vercel | HTTP (remote) | Disabled | `aitools --addmcp vercel` |
| Webflow | HTTP (remote) | Disabled | `aitools --addmcp webflow` |

## Config Files

| Tool | User-level servers | User-level deny rules | Project enable |
|------|-------------------|----------------------|----------------|
| Claude Code | `~/.claude.json` | `~/.claude/settings.json` | `.claude/settings.local.json` |
| Cursor | `~/.cursor/mcp.json` | `agent mcp disable` | `agent mcp enable` or `.cursor/mcp.json` |

## Enable/Disable Mechanisms

### Claude Code

- **User-level deny** (`~/.claude/settings.json`):
  ```json
  { "permissions": { "deny": ["MCP(vercel)", "MCP(webflow)"] } }
  ```
- **Project-level allow** (`.claude/settings.local.json`):
  ```json
  { "permissions": { "allow": ["MCP(vercel)"] } }
  ```
- Project allow overrides user deny for that server in that project only.

### Cursor CLI

- **Disable**: `agent mcp disable vercel`
- **Enable**: `agent mcp enable vercel`
- **List**: `agent mcp list`
- Alternatively, add server to project `.cursor/mcp.json` (project config overrides user-level disabled state).

## Setup

### All Servers (user-level)

Configured automatically by `aitools install`, which runs:

```powershell
# Windows
.\scripts\setup-user-mcp.ps1    # Claude Code
.\scripts\setup-cursor-mcp.ps1  # Cursor

# macOS
bash scripts/setup-user-mcp.sh    # Claude Code
bash scripts/setup-cursor-mcp.sh  # Cursor
```

### Per-Project Enable

```bash
cd ~/repos/my-project
aitools --addmcp vercel            # Enable vercel
aitools --addmcp vercel webflow    # Enable both
aitools mcp                        # Check status
```

For Claude Code, this creates/merges `.claude/settings.local.json` with allow rules.
For Cursor, this runs `agent mcp enable` or falls back to project `.cursor/mcp.json`.

## Servers

| Server | Package/URL | Auth |
|--------|-------------|------|
| Chrome DevTools | `chrome-devtools-mcp@latest` (npx) | None |
| Vercel | `https://mcp.vercel.com` | OAuth (browser) |
| Webflow | `https://mcp.webflow.com/mcp` | OAuth (browser) |

## Post-setup

### Claude Code
1. Start a session and run `/mcp` to verify servers show green status
2. Chrome DevTools needs no auth
3. Vercel/Webflow only appear when enabled for the project (via `aitools --addmcp`)

### Cursor
1. Restart Cursor after running setup
2. Go to **Cursor Settings > Tools & MCP** to see servers
3. Vercel/Webflow can also be toggled in the IDE UI

## Platform Notes

- **Windows**: Chrome DevTools uses `cmd /c npx` wrapper in Cursor config. Claude Code uses `claude mcp add` directly.
- **macOS**: Chrome DevTools uses `npx` directly on both tools.
- Vercel and Webflow are remote HTTP servers — identical config on both platforms.
- OAuth tokens are cached locally per tool and refreshed automatically.

## Documentation Sources

See `reference/tool-install-sources.md` for official documentation links and verified install commands.
