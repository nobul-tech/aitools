# Tool Installation Sources of Truth

Official documentation links and verified install commands for all tools managed by `aitools install`.
**Always check these before modifying install steps.**

Last verified: 2026-02-27 (Claude Code 2.1.62)

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
- **Invocation:** `claude` (direct)

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
- **Invocation:** `vercel` (direct; never `npx vercel`)

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
- **Post-Install Config:** `~/.cursor/cli-config.json` (merged from profile by setup script; preferences in `profile.json` under `cursor.cli`)
- **Dependencies:** ripgrep (`rg`)
- **Invocation:** `agent` (direct)

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

**Skills** (deployed by `setup-user-mcp`):

Vendored in `shared/skills/` from the upstream repo. Deployed to `~/.claude/skills/` (Claude Code)
and `~/.cursor/skills/` (Cursor Agent CLI) by `setup-user-mcp.sh/.ps1`.
Deploy scripts embed content inline (self-contained).
When updating vendored skills, re-fetch from the GitHub repo URLs below.

- `chrome-devtools` -- browser automation & debugging
- `a11y-debugging` -- accessibility auditing

**Skills source:**
- https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/skills/chrome-devtools/SKILL.md
- https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/skills/a11y-debugging/SKILL.md

**Note:** The Claude Code plugin (`/plugin install chrome-devtools-mcp`) is NOT used.
It bundles its own MCP server config without `--isolated`, causing config conflicts.
Standalone skills + our user-scope MCP config provide the same functionality without conflicts.

**Lifecycle:**
- **Platform Status:** macOS: supported; Windows: supported
- **Concurrency:** **Yes with `--isolated`**; No without (Chrome profile lock prevents concurrent sessions)
- **Post-Install Config:** Skills deployed automatically by `setup-user-mcp`. No auth required.
- **Dependencies:** Node.js (npx)
- **Invocation:** N/A (MCP server; launched via npx in server config)

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
- **Invocation:** N/A (MCP server; HTTP remote)

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
- **Invocation:** N/A (MCP server; HTTP remote)

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
- **Invocation:** N/A (runtime)

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
- **Invocation:** `pandoc` (direct)

---

## PowerShell (pwsh)

**Source**: https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell

### Install

| Platform | Method | Command |
|----------|--------|---------|
| macOS | Homebrew -- Microsoft tap (preferred) | `brew install powershell/tap/powershell` |
| Windows | winget (preferred) | `winget install --id Microsoft.PowerShell --source winget` |

### Update

- Homebrew: `brew upgrade powershell/tap/powershell`

### Check Version

```bash
pwsh --version
```

### Non-Preferred Install Methods (cleanup targets)

| Method | Detection | Why not preferred |
|--------|-----------|-------------------|
| Homebrew cask (deprecated) | `brew list --cask powershell` | Deprecated by Microsoft 2026-09-01, Gatekeeper signing issues |

### Notes

- Binary is `pwsh` on both platforms (not `powershell` or `powershell.exe`)
- Windows also ships `powershell.exe` (PS 5.1) -- not used by this project except as bootstrap fallback in `aitools-install.sh`
- Used by: PS1 syntax validation in check scripts and build-deploy.sh, all Windows dispatch from bash scripts

### Lifecycle

- **Platform Status:** macOS: supported; Windows: supported
- **Concurrency:** Yes -- independent sessions
- **Post-Install Config:** None
- **Dependencies:** Homebrew (macOS), winget (Windows)
- **Invocation:** `pwsh` (direct; never `powershell.exe` except bootstrap)

---

## Rust (cargo)

**Source**: https://www.rust-lang.org/tools/install
**Purpose**: Rust toolchain — compiler (`rustc`), package manager/build tool (`cargo`), toolchain manager (`rustup`).

### Install

| Platform | Method | Command |
|----------|--------|---------|
| macOS/Linux | rustup (preferred) | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` |
| Windows | winget (preferred) | `winget install -e --id Rustlang.Rustup` |
| Windows | rustup-init.exe (alt) | Download from https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe |
| macOS | Homebrew (alt) | `brew install rustup` then `rustup default stable` |

### Update

```
rustup update
```

### Check Version

```bash
cargo --version
rustc --version
rustup --version
```

### Prerequisites (Windows)

MSVC Build Tools required for linking. `rustup-init` offers to install automatically. Manual: install **Visual Studio Build Tools** with the **"Desktop Development with C++"** workload.

### Non-Preferred Install Methods (cleanup targets)

| Method | Detection | Why not preferred |
|--------|-----------|-------------------|
| `brew install rust` | `brew list rust` | Brew-managed toolchain, not rustup-managed — can't use `rustup update` |
| System package manager | `apt list --installed rustc` | Usually outdated versions |

### Notes

- All tools install to `~/.cargo/bin` (added to PATH by rustup automatically)
- Homebrew `rustup` requires manual PATH setup: add `$(brew --prefix rustup)/bin` to PATH
- winget package (`Rustlang.Rustup`) installs rustup, which then manages the toolchain

### Lifecycle

- **Platform Status:** macOS: supported; Windows: supported
- **Concurrency:** Yes — independent cargo invocations
- **Post-Install Config:** None (rustup configures toolchain automatically). Windows: MSVC Build Tools must be present.
- **Dependencies:** C linker (Xcode CLT on macOS, MSVC Build Tools on Windows)
- **Invocation:** `cargo` (direct; `rustc` and `rustup` also available)

---

## Typst

**Source**: https://typst.app / https://github.com/typst/typst
**Purpose**: PDF engine for pandoc (`--pdf-engine=typst`). Converts markdown-to-PDF via pandoc without a LaTeX distribution.

### Install

| Platform | Method | Command |
|----------|--------|---------|
| macOS | Homebrew (preferred) | `brew install typst` |
| Windows | winget (preferred) | `winget install --id Typst.Typst` |

### Update

- Homebrew: `brew upgrade typst`
- winget: `winget upgrade --id Typst.Typst`

### Check Version

```bash
typst --version
```

### Non-Preferred Install Methods (cleanup targets)

| Method | Detection | Why not preferred |
|--------|-----------|-------------------|
| cargo (`cargo install typst-cli`) | `cargo install --list \| grep typst` | Different binary path, may shadow package manager install |
| npm (`npm install -g typst`) | `npm list -g typst` | Third-party wrapper, not official |

### Notes

- Single ~30-50 MB binary, no runtime dependencies
- Used by: `pandoc --pdf-engine=typst` for markdown-to-PDF
- 45K+ GitHub stars, 350+ contributors, Apache 2.0, active releases
- 27x faster than XeLaTeX

### Lifecycle

- **Platform Status:** macOS: supported; Windows: supported
- **Concurrency:** Yes -- stateless CLI
- **Post-Install Config:** None
- **Dependencies:** Pandoc (when used as `--pdf-engine`)
- **Invocation:** `typst` (direct; never `npx typst`)

---

## Overrides

Intentional deviations from upstream defaults. When comparing our install
commands against official docs, these are expected discrepancies — not bugs.

| Tool | Override | Upstream Default | Our Value | Reason | Added |
|------|----------|-----------------|-----------|--------|-------|
| Chrome DevTools MCP | `--isolated` flag | Not included | Added to all install commands | Enables concurrent Claude Code + Cursor sessions by using throwaway temp Chrome profiles | 2026-02-19 |

