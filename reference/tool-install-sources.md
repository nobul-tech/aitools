# Tool Installation Sources of Truth

Official documentation links and verified install commands for all tools managed by `aitools install`.
**Always check these before modifying install steps.**

Last verified: 2026-02-14

---

## Claude Code CLI

**Source**: https://code.claude.com/docs/en/setup

### Install

| Method | Command | Auto-updates? |
|--------|---------|---------------|
| Native (macOS/Linux/WSL) | `curl -fsSL https://claude.ai/install.sh \| bash` | Yes |
| Native (Windows PowerShell) | `irm https://claude.ai/install.ps1 \| iex` | Yes |
| Native (Windows CMD) | `curl -fsSL https://claude.ai/install.cmd -o install.cmd && install.cmd && del install.cmd` | Yes |
| Homebrew | `brew install --cask claude-code` | No (`brew upgrade claude-code`) |
| WinGet | `winget install Anthropic.ClaudeCode` | No (`winget upgrade Anthropic.ClaudeCode`) |
| npm (DEPRECATED) | `npm install -g @anthropic-ai/claude-code` | No |

### Update

- Native: auto-updates in background, or `claude update` for manual
- Homebrew: `brew upgrade claude-code`
- WinGet: `winget upgrade Anthropic.ClaudeCode`

### System Requirements

- macOS 13.0+, Windows 10 1809+, Ubuntu 20.04+, Debian 10+
- 4 GB+ RAM, internet connection
- Windows: requires Git Bash (Git for Windows)
- Node.js 18+ only needed for deprecated npm install

### Notes

- On Windows Git Bash (MSYS), the bash curl installer works. WinGet also works from Git Bash.
- `claude doctor` verifies installation type and version
- Release channels: `latest` (default) or `stable`

---

## Vercel CLI

**Source**: https://vercel.com/docs/cli

### Install

| Method | Command |
|--------|---------|
| npm | `npm i -g vercel` |
| pnpm | `pnpm i -g vercel` |
| yarn | `yarn global add vercel` |
| bun | `bun i -g vercel` |

### Update

Re-run the install command. The CLI notifies when updates are available.

### Check Version

```bash
vercel --version
```

### Notes

- Official docs show `npm i vercel` (local install). For global CLI usage, add `-g` flag.
- Permission errors on macOS: see npm's guide on resolving EACCES errors. Avoid `sudo npm install -g`.
- Has built-in `vercel mcp` command for MCP client configuration.

---

## Cursor Agent CLI

**Source**: https://cursor.com/docs/cli/installation

### Install

| Platform | Command |
|----------|---------|
| macOS/Linux/WSL | `curl https://cursor.com/install -fsS \| bash` |
| Windows (PowerShell) | `irm 'https://cursor.com/install?win32=true' \| iex` |

### Update

```bash
agent update
# or
agent upgrade
```

### Check Version

```bash
agent --version
```

### Prerequisites

- PATH: `~/.local/bin` must be in PATH (bash → `~/.bashrc`, zsh → `~/.zshrc`)
- **ripgrep (`rg`)**: Required at runtime (the CLI shells out to `rg` for code search). Not mentioned in official docs but confirmed via error: "Could not find ripgrep (rg) binary".
  - macOS: `brew install ripgrep`
  - Windows: `winget install BurntSushi.ripgrep.MSVC`

---

## MCP Servers

### Chrome DevTools MCP

**Package**: `chrome-devtools-mcp@latest` (npm/npx)
**Transport**: stdio (local)
**Auth**: None

| Platform | Claude Code config | Cursor config |
|----------|-------------------|---------------|
| macOS/Linux | `npx -y chrome-devtools-mcp@latest` | `"command": "npx", "args": ["-y", "chrome-devtools-mcp@latest"]` |
| Windows | `cmd /c npx -y chrome-devtools-mcp@latest` | `"command": "cmd", "args": ["/c", "npx", "-y", "chrome-devtools-mcp@latest"]` |

**Note**: On Windows, `claude mcp add` mangles `/c` flag — edit `~/.claude.json` directly.

### Vercel MCP

**URL**: `https://mcp.vercel.com`
**Transport**: HTTP (remote)
**Auth**: OAuth (browser flow)
**Scope**: Project-level (via `aitools --addmcp vercel`)

### Webflow MCP

**URL**: `https://mcp.webflow.com/mcp`
**Transport**: HTTP (remote)
**Auth**: OAuth (browser flow)
**Scope**: Project-level (via `aitools --addmcp webflow`)

---

## Node.js

**Source**: https://nodejs.org

### Install

| Platform | Command |
|----------|---------|
| macOS (Homebrew) | `brew install node@22` |
| Windows (winget) | `winget install OpenJS.NodeJS.LTS` |
| Ubuntu/Debian | See NodeSource or nvm |

Required for: Chrome DevTools MCP (npx), Vercel CLI (npm), Cursor CLI JSON merge fallback.
