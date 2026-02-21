# Tool Installation Sources of Truth

Official documentation links and verified install commands for all tools managed by `aitools install`.
**Always check these before modifying install steps.**

Last verified: 2026-02-19

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

### Lifecycle

- **Platform Status:** macOS: supported; Windows: supported
- **Concurrency:** Yes -- independent sessions per directory
- **Post-Install Config:** `~/.claude/CLAUDE.md` (via setup script), git identity
- **Dependencies:** Git, Git Bash (Windows)

---

## Vercel CLI

**Source**: https://vercel.com/docs/cli

### Install

| Method | Command | Claude Code compatible? | Notes |
|--------|---------|------------------------|-------|
| Homebrew (macOS) | `brew install vercel-cli` | Yes | Preferred on macOS |
| npm | `npm i -g vercel` | Unreliable on macOS | Works on Windows |
| pnpm | `pnpm i -g vercel` | Unreliable on macOS | |
| yarn | `yarn global add vercel` | Unreliable on macOS | |
| bun | `bun i -g vercel` | Unreliable on macOS | |

### Update

- Homebrew: `brew upgrade vercel-cli`
- npm/pnpm/yarn/bun: Re-run the install command. The CLI notifies when updates are available.

### Check Version

```bash
vercel --version
```

### Claude Code PATH Issues

On macOS, `npm install -g` puts binaries in npm's global prefix bin (e.g. `~/.npm-global/bin/`), which Claude Code's Bash tool often doesn't include in its PATH. Homebrew installs to `/opt/homebrew/bin/` (Apple Silicon) or `/usr/local/bin/` (Intel), both reliably in PATH.

On Windows, npm is the only option (no winget package, no standalone binary). The install scripts verify PATH after install and warn if the directory isn't persistent.

Related issues:
- [#5202](https://github.com/anthropics/claude-code/issues/5202) — Claude Code PATH doesn't include npm global bin
- [#3838](https://github.com/anthropics/claude-code/issues/3838) — Bash tool PATH limitations

### Notes

- Official docs show `npm i vercel` (local install). For global CLI usage, add `-g` flag.
- Permission errors on macOS: see npm's guide on resolving EACCES errors. Avoid `sudo npm install -g`.
- Has built-in `vercel mcp` command for MCP client configuration.
- No winget package or standalone binary available for Windows.

### Lifecycle

- **Platform Status:** macOS: supported; Windows: supported
- **Concurrency:** Yes -- stateless CLI
- **Post-Install Config:** **`vercel login` required** -- not automated by setup scripts. Tool appears installed but is non-functional until login completes.
- **Dependencies:** Node.js (npm method only)

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

### Lifecycle

- **Platform Status:** macOS: supported; Windows: supported
- **Concurrency:** Yes -- independent sessions
- **Post-Install Config:** `~/.cursor/cli-config.json` (via setup script)
- **Dependencies:** ripgrep (`rg`)

---

## MCP Servers

### Chrome DevTools MCP

**Official Docs**: https://github.com/ChromeDevTools/chrome-devtools-mcp
**Package**: `chrome-devtools-mcp@latest` (npm/npx)
**Transport**: stdio (local)
**Auth**: None
**Scope**: User (enabled by default)

**Install (Claude Code)**:
```bash
claude mcp add chrome-devtools --scope user -- npx chrome-devtools-mcp@latest --isolated
```

**Install (Cursor)**: Write to `~/.cursor/mcp.json`:
```json
{ "command": "npx", "args": ["-y", "chrome-devtools-mcp@latest", "--isolated"] }
```
Windows variant uses `"command": "cmd", "args": ["/c", "npx", "-y", "chrome-devtools-mcp@latest", "--isolated"]`.

**Install (Claude Code Plugin -- adds skills)**:
```
/plugin marketplace add ChromeDevTools/chrome-devtools-mcp
/plugin install chrome-devtools-mcp
```
Skills added: `chrome-devtools` (browser automation/debugging), `a11y-debugging` (accessibility auditing).
Plugin is additive -- requires the MCP server config above to already be in place.

**Note:** The plugin's bundled server config omits `--isolated`. Our user-scope
MCP config includes it and takes precedence. See Overrides section below.

**Lifecycle:**
- **Platform Status:** macOS: supported; Windows: supported
- **Concurrency:** **Yes with `--isolated`**; No without (Chrome profile lock prevents concurrent sessions)
- **Post-Install Config:** Plugin install optional (adds skills for structured workflows). No auth required.
- **Dependencies:** Node.js (npx)

### Vercel MCP

**Official Docs**: https://vercel.com/docs/agent-resources/vercel-mcp
**URL**: `https://mcp.vercel.com`
**Transport**: HTTP (remote)
**Auth**: OAuth (browser flow)
**Scope**: User (disabled by default)

**Install (Claude Code)**:
```bash
claude mcp add --transport http --scope user vercel https://mcp.vercel.com
```

**Lifecycle:**
- **Platform Status:** macOS: supported; Windows: supported
- **Concurrency:** Yes -- HTTP remote server
- **Post-Install Config:** **OAuth required** -- authenticate in Claude Code (`/mcp`) or Cursor (Settings > Tools & MCP) on first use. Tool appears configured but is non-functional until OAuth completes.
- **Dependencies:** None

### Webflow MCP

**Official Docs**: https://developers.webflow.com/mcp/reference/getting-started
**GitHub**: https://github.com/webflow/mcp-server
**URL**: `https://mcp.webflow.com/mcp`
**Transport**: HTTP (remote)
**Auth**: OAuth (browser flow)
**Scope**: User (disabled by default)

**Install (Claude Code)**:
```bash
claude mcp add --transport http --scope user webflow https://mcp.webflow.com/mcp
```

**Lifecycle:**
- **Platform Status:** macOS: supported; Windows: supported
- **Concurrency:** Yes -- HTTP remote server
- **Post-Install Config:** **OAuth required** -- authenticate in Claude Code (`/mcp`) or Cursor (Settings > Tools & MCP) on first use. Tool appears configured but is non-functional until OAuth completes.
- **Dependencies:** None

---

## MCP Management & Configuration

### Claude Code MCP

**Docs**: https://code.claude.com/docs/en/mcp

| Command | What it does |
|---------|--------------|
| `claude mcp add <name> --scope user ...` | Add server at user level |
| `claude mcp remove <name> --scope user` | Remove server from user level |
| `claude mcp list` | List configured servers |
| `/mcp` (in session) | Show server status with connection health |

**Scopes**: `user` (all projects), `project` (current repo in `.mcp.json`).

**Disable/Enable via settings** (https://code.claude.com/docs/en/settings):
- Deny at user level: `~/.claude/settings.json` → `permissions.deny: ["MCP(serverName)"]`
- Allow per project: `.claude/settings.local.json` → `permissions.allow: ["MCP(serverName)"]`
- Project allow overrides user deny for that specific server.

### Cursor CLI MCP

**Docs**: https://cursor.com/docs/cli/mcp

| Command | What it does |
|---------|--------------|
| `agent mcp list` | List MCP servers and their status |
| `agent mcp enable <name>` | Enable an MCP server |
| `agent mcp disable <name>` | Disable an MCP server |

**Config**: `~/.cursor/mcp.json` (user-level), `.cursor/mcp.json` (project-level).

### Cursor IDE MCP

**Docs**: https://cursor.com/docs/context/mcp

- **Settings UI**: Cursor Settings > Features > MCP — toggle servers on/off
- **Tools & MCP**: Cursor Settings > Tools & MCP — see available tools, authenticate OAuth
- Not automatable (UI-only toggles); managed manually

---

## Node.js

**Source**: https://nodejs.org

### Install

| Platform | Command |
|----------|---------|
| macOS (Homebrew) | `brew install node@22` |
| Windows (winget) | `winget install OpenJS.NodeJS.LTS` |
| Ubuntu/Debian | See NodeSource or nvm |

Required for: Chrome DevTools MCP (npx), Vercel CLI (npm), settings JSON merge in setup scripts.

### Lifecycle

- **Platform Status:** macOS: supported; Windows: supported
- **Concurrency:** Yes -- runtime
- **Post-Install Config:** None
- **Dependencies:** --

---

## Pandoc

**Source**: https://pandoc.org/installing.html

### Install

| Platform | Method | Command |
|----------|--------|---------|
| macOS | Homebrew (preferred) | `brew install pandoc` |
| Windows | winget (preferred) | `winget install --source winget --exact --id JohnMacFarlane.Pandoc` |
| Windows | Chocolatey (alt) | `choco install pandoc` |
| Linux | apt | `sudo apt install pandoc` |

### Update

- Homebrew: `brew upgrade pandoc`
- winget: `winget upgrade JohnMacFarlane.Pandoc`

### Check Version

```bash
pandoc --version
```

### Non-Preferred Install Methods (cleanup targets)

| Method | Detection | Why not preferred |
|--------|-----------|-------------------|
| Conda | `conda list pandoc` | Environment isolation issues, stale versions |
| MacPorts | `port installed pandoc` | Less common than Homebrew on macOS |
| pip (`pip install pandoc`) | pip wrapper, not pandoc itself | Confusing, incomplete |
| Cabal | `~/.cabal/bin/pandoc` | Haskell toolchain dependency |
| Manual binary/installer | `/usr/local/bin/pandoc` not from Homebrew | No auto-update path |

### Notes

- Cross-platform — native packages on macOS, Windows, Linux
- Single static binary, no runtime dependencies
- Used by: `clip2md` shell alias (clipboard HTML → Markdown)

### Lifecycle

- **Platform Status:** macOS: supported; Windows: supported
- **Concurrency:** Yes -- stateless CLI
- **Post-Install Config:** None
- **Dependencies:** --

---

## Overrides

Intentional deviations from upstream defaults. When comparing our install
commands against official docs, these are expected discrepancies — not bugs.

| Tool | Override | Upstream Default | Our Value | Reason | Added |
|------|----------|-----------------|-----------|--------|-------|
| Chrome DevTools MCP | `--isolated` flag | Not included | Added to all install commands | Enables concurrent Claude Code + Cursor sessions by using throwaway temp Chrome profiles | 2026-02-19 |

---

## Under Evaluation

Tools recommended during sessions but not yet approved for managed install. Try them out, then either promote to a managed tool above or remove.

### Typst

**Source**: https://typst.app / https://github.com/typst/typst
**Purpose**: PDF engine for pandoc (`--pdf-engine=typst`). Converts markdown-to-PDF via pandoc without a LaTeX distribution.

| Platform | Method | Command |
|----------|--------|---------|
| macOS | Homebrew (preferred) | `brew install typst` |
| Windows | winget (preferred) | `winget install --id Typst.Typst` |

**Version check**: `typst --version`

**Usage with pandoc**:
```bash
pandoc input.md --pdf-engine=typst -o output.pdf
```

**Why this over alternatives**: Single ~30-50 MB binary (vs ~100 MB+ for TinyTeX, ~4 GB for full TeX Live, ~200-400 MB for Chromium-based tools). Native cross-platform binaries. 45K+ GitHub stars, 350+ contributors, Apache 2.0, active releases (Feb 2026). 27x faster than XeLaTeX.

**Non-preferred alternatives** (cleanup targets if Typst is approved):
| Alternative | Why not preferred |
|-------------|-------------------|
| TinyTeX / TeX Live / MacTeX | 100 MB - 4 GB, complex package management (`tlmgr`) |
| Tectonic | No winget package, on-demand network downloads |
| WeasyPrint | Painful Windows install (GTK dependencies) |
| wkhtmltopdf | Archived/abandoned |
| md-to-pdf (npm) | Downloads entire Chromium (~200-400 MB) |
