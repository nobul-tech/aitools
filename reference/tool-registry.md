# Tool Registry

Registry of managed tools — install commands, lifecycle, and per-platform version tracking.
**Always check this before modifying install steps.**

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

- **Platform Status:** macOS: supported | Windows: supported | Linux: supported
- **Concurrency:** Yes -- independent sessions per directory
- **Post-Install Config:** `~/.claude/CLAUDE.md` (via setup script), git identity
- **Dependencies:** Git, Git Bash (Windows)
- **Invocation:** `claude` (direct)
- **Last verified version:** See tool-ops-claude-code.md

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

- **Platform Status:** macOS: supported | Windows: supported | Linux: supported
- **Concurrency:** Yes -- stateless CLI
- **Post-Install Config:** **`vercel login` required** -- not automated by setup scripts. Tool appears installed but is non-functional until login completes.
- **Dependencies:** Node.js (npm method only)
- **Invocation:** `vercel` (direct; never `npx vercel`)
- **Last verified version:** macOS: 50.23.2 (2026-03-02) | Windows: pending | Linux: pending

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

- **Platform Status:** macOS: supported | Windows: supported | Linux: supported
- **Concurrency:** Yes -- independent sessions
- **Post-Install Config:** `~/.cursor/cli-config.json` (merged from profile by setup script; preferences in `profile.json` under `cursor.cli`)
- **Dependencies:** ripgrep (`rg`)
- **Invocation:** `agent` (direct)
- **Last verified version:** macOS: 2026.02.27-e7d2ef6 (2026-03-02) | Windows: 2026.03.11-6dfa30c (2026-03-13) | Linux: pending

### Config Behavior

**Config files managed by aitools:**

| File | Script | Managed fields |
|------|--------|----------------|
| `~/.cursor/cli-config.json` | `setup-user-cursor` | `version`, `editor.vimMode`, `permissions`, `model`, `hasChangedDefaultModel` |
| `~/.cursor/mcp.json` | `setup-cursor-ide-mcp` | `mcpServers.chrome-devtools`, `mcpServers.vercel`, `mcpServers.webflow` |

All other fields (e.g., `authInfo`, `privacyCache`, `network`, `sandbox`,
`attribution`) are preserved via read-then-merge. See
`@.claude/rules/config-file-safety.md`.

**MCP server disable scope (KNOWN ISSUE):**

`agent mcp disable <name>` is **project-scoped**, not user-scoped. The
disable state is stored in Cursor's internal per-project config, not in
`~/.cursor/mcp.json` or `cli-config.json`.

Impact: `setup-cursor-ide-mcp` runs `agent mcp disable vercel/webflow`
from the directory where `aitools install` executes (typically the
aitools repo). Other projects see these servers as enabled, causing
authentication errors on launch.

Current workaround: Users must run `agent mcp disable vercel` and
`agent mcp disable webflow` manually in each new project directory.

Planned fix: Stop deploying vercel/webflow to user-level `mcp.json`.
Add them per-project only via `aitools --addmcp`.

**Platform-specific MCP commands:**

| Platform | chrome-devtools stdio command |
|----------|------------------------------|
| Windows | `cmd /c npx -y chrome-devtools-mcp@latest --isolated` |
| macOS | `npx -y chrome-devtools-mcp@latest --isolated` |

The `cmd /c` wrapper is required on Windows for npx PATH resolution.
OS guards in setup scripts ensure the correct variant is deployed. See
`@reference/managed-file-deployment.md` "Platform-Specific Config Values".

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
- **Platform Status:** macOS: supported | Windows: supported | Linux: evaluating
- **Concurrency:** **Yes with `--isolated`**; No without (Chrome profile lock prevents concurrent sessions)
- **Post-Install Config:** Skills deployed automatically by `setup-user-mcp`. No auth required.
- **Dependencies:** Node.js (npx)
- **Invocation:** N/A (MCP server; launched via npx in server config)
- **Last reviewed:** 2026-03-02

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
- **Platform Status:** macOS: supported | Windows: supported | Linux: supported
- **Concurrency:** Yes -- HTTP remote server
- **Post-Install Config:** **OAuth required** -- authenticate in Claude Code (`/mcp`) or Cursor (Settings > Tools & MCP) on first use. Tool appears configured but is non-functional until OAuth completes.
- **Dependencies:** None
- **Invocation:** N/A (MCP server; HTTP remote)
- **Last reviewed:** 2026-03-02

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
- **Platform Status:** macOS: supported | Windows: supported | Linux: supported
- **Concurrency:** Yes -- HTTP remote server
- **Post-Install Config:** **OAuth required** -- authenticate in Claude Code (`/mcp`) or Cursor (Settings > Tools & MCP) on first use. Tool appears configured but is non-functional until OAuth completes.
- **Dependencies:** None
- **Invocation:** N/A (MCP server; HTTP remote)
- **Last reviewed:** 2026-03-02

### Datadog MCP

**Official Docs**: https://docs.datadoghq.com/bits_ai/mcp_server/
**Blog**: https://www.datadoghq.com/blog/datadog-remote-mcp-server/
**Transport**: HTTP (remote) or stdio (local binary)
**Auth**: OAuth (browser flow) for remote; API key for local
**Scope**: User (disabled by default)
**Status**: Preview (may require allowlisting by Datadog)

**Install (Claude Code)**:
```bash
claude mcp add --transport http --scope user datadog https://mcp.datadoghq.com/mcp
```

**Toolsets**: core (logs, metrics, traces, dashboards, monitors, incidents, hosts, services, events, notebooks), alerting, apm, dbm, error-tracking, feature-flags, llmobs, product-analytics. Toolsets are selectable to save context window space.

**Lifecycle:**
- **Platform Status:** macOS: supported | Windows: supported | Linux: supported
- **Concurrency:** Yes -- HTTP remote server
- **Post-Install Config:** **OAuth required** for remote transport. Tool appears configured but is non-functional until OAuth completes. Preview access may require Datadog allowlisting.
- **Dependencies:** Active Datadog account (startup program or paid plan)
- **Invocation:** N/A (MCP server; HTTP remote)
- **Last reviewed:** 2026-03-06

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

- **Platform Status:** macOS: supported | Windows: supported | Linux: supported
- **Concurrency:** Yes -- runtime
- **Post-Install Config:** None
- **Dependencies:** --
- **Invocation:** N/A (runtime)
- **Last verified version:** macOS: 24.1.0 (2026-03-02) | Windows: pending | Linux: pending

---

## GitHub CLI (gh)

**Source**: https://cli.github.com

### Install

| Platform | Method | Command |
|----------|--------|---------|
| macOS | Homebrew (preferred) | `brew install gh` |
| Windows | winget (preferred) | `winget install GitHub.cli` |
| Linux | apt + GitHub keyring | `sudo apt-get install -y gh` (keyring added on first install) |

### Update

- Homebrew: `brew upgrade gh`
- winget: `winget upgrade GitHub.cli`
- apt: `sudo apt-get install -y gh`

### Check Version

```bash
gh --version
```

### Notes

- Required by aitools-install as a prerequisite (installed as Step 1)
- Auth step (`gh auth login`) is interactive — handled by aitools-install Step 2, not setup-gh-cli
- Linux first install adds the GitHub CLI apt keyring automatically (one-time)

### Lifecycle

- **Platform Status:** macOS: supported | Windows: supported | Linux: supported
- **Concurrency:** Yes — stateless CLI
- **Post-Install Config:** Auth via `gh auth login` (interactive, done in aitools-install Step 2)
- **Dependencies:** --
- **Invocation:** `gh` (direct)
- **Last verified version:** macOS: 2.87.3 (2026-03-02) | Windows: pending | Linux: pending

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

- **Platform Status:** macOS: supported | Windows: supported | Linux: supported
- **Concurrency:** Yes -- stateless CLI
- **Post-Install Config:** None
- **Dependencies:** --
- **Invocation:** `pandoc` (direct)
- **Last verified version:** macOS: 3.9 (2026-03-02) | Windows: pending | Linux: pending

---

## Perl

**Source**: https://strawberryperl.com (Windows) / system (macOS/Linux)

### Install

| Platform | Method | Command |
|----------|--------|---------|
| Windows | WinGet (preferred) | `winget install StrawberryPerl.StrawberryPerl` |
| macOS | System | Pre-installed (`/usr/bin/perl`) |
| macOS | Homebrew | `brew install perl` |
| Linux | System | Pre-installed (`/usr/bin/perl`) |

### Check Version

`perl --version`

### Use Cases

Simple one-liner text processing (USO mandate):
- `perl -ne 'print "$1\n" if /pattern/'` — regex extraction
- `perl -pe 's/foo/bar/'` — substitution
- `perl -0777 -pe 's/[\r\n]+$/\n/'` — trailing whitespace normalization

No CPAN modules required. Minimum version: 5.10+.

### Lifecycle

- **Platform Status:** macOS: supported | Windows: supported | Linux: supported
- **Concurrency:** Yes — stateless CLI
- **Post-Install Config:** None
- **Dependencies:** None (Windows: standalone; macOS/Linux: system)
- **Invocation:** `perl` (direct). Anti-pattern: `sed`/`awk` for non-trivial string manipulation
- **Last verified version:** Windows: 5.42.0.1 (2026-03-12) | macOS: pending | Linux: pending

### Platform Gotchas

**Windows (Strawberry Perl):** Defaults to `:unix:crlf` PerlIO layers (text
mode). Perl one-liners that write explicit `\r\n` produce double-CR
(`\r\r\n`). Fix: `export PERLIO=:perlio` or per-invocation prefix. See
`reference/cross-platform-detail.md` "Strawberry Perl text mode".

### PERLIO Deployment

Strawberry Perl's `:crlf` text mode requires `PERLIO=:perlio` to prevent
double-CR on explicit `\r\n` writes. This is a deployment concern, not
just a usage note.

| Context | How PERLIO is set | Scope |
|---------|-------------------|-------|
| `build-deploy.sh` | `export PERLIO=:perlio` | Build-time |
| Setup scripts | Not needed (no explicit CRLF writes) | N/A |
| Interactive shell | User sets manually if needed | Manual |

**Git Bash bundled perl** (`/usr/bin/perl`, v5.38.2) already uses
`:perlio` — the fix is a no-op for it. Only Strawberry Perl at
`C:\Strawberry\perl\bin\` is affected.

**PATH priority**: `check-lib.ps1` prepends `C:\Strawberry\perl\bin` to
PATH to ensure the managed Strawberry Perl is used instead of Git Bash's
bundled version. This is required because Git's `usr/bin/` can shadow
managed tools due to PATH order.

See also `@reference/managed-file-deployment.md` "Environment Variable
Deployment" and `@reference/cross-platform-detail.md` "Strawberry Perl
text mode".

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

- **Platform Status:** macOS: supported | Windows: supported | Linux: supported
- **Concurrency:** Yes -- independent sessions
- **Post-Install Config:** None
- **Dependencies:** Homebrew (macOS), winget (Windows)
- **Invocation:** `pwsh` (direct; never `powershell.exe` except bootstrap)
- **Last verified version:** macOS: 7.5.4 (2026-03-02) | Windows: pending | Linux: pending

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

- **MSVC Build Tools**: Required for linking. `setup-rust.ps1` checks and warns if missing.
  Manual: `winget install Microsoft.VisualStudio.2022.BuildTools` (add "Desktop Development
  with C++" workload).
- **NASM**: Required by `aws-lc-sys` (crypto library used by rustls, reqwest, and many crates).
  `setup-rust.ps1` auto-installs via `winget install NASM.NASM`. Without NASM, `cargo install`
  for any crate using `aws-lc-rs` panics: `NASM command not found! Build cannot continue.`
- **CMake**: Required by some crates. Official: cmake.org/download lists pip, ZIP, MSI
  (not winget). Windows: `uv tool install cmake` (user-level, installs to `~/.local/bin`,
  PyPI package maintained by Kitware). macOS: `brew install cmake`.
  See `reference/tool-evaluation-playbook.md`.

All known build prerequisites are tracked in `aitools-lib.ps1` (`$script:BuildPrereqs`)
and `aitools-lib.sh` (`check_build_prereqs`). When a new prerequisite is discovered,
add it to both files — see "Adding a new build prerequisite" in
`reference/script-standards-detail.md`.

### Known Install Paths

Used by `Ensure-ToolOnPath` / `ensure_tool_on_path` and `Check-BuildPrereqs` /
`check_build_prereqs` fallback when `Get-Command` / `command -v` fails (tool
installed but not on PATH in current session).

**Windows:**

| Tool | Install method | Standard path | Verified | Notes |
|------|---------------|--------------|----------|-------|
| NASM | winget (NASM.NASM) | `%LOCALAPPDATA%\bin\NASM\nasm.exe` | 2026-03-11 (v3.01) | Per-user Nullsoft installer; `Program Files` as secondary |
| CMake | uv tool install cmake | `%USERPROFILE%\.local\bin\cmake.exe` | 2026-03-12 (v4.2.3) | PyPI package via uv tool; `~/.local/bin` on user PATH |

**macOS/Linux:**

| Tool | Known paths |
|------|------------|
| NASM | `/usr/local/bin/nasm`, `/opt/homebrew/bin/nasm`, `/usr/bin/nasm` |
| CMake | `/usr/local/bin/cmake`, `/opt/homebrew/bin/cmake`, `/usr/bin/cmake`, `/Applications/CMake.app/Contents/bin/cmake` |

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

- **Platform Status:** macOS: supported | Windows: supported | Linux: supported
- **Concurrency:** Yes — independent cargo invocations
- **Post-Install Config:** None (rustup configures toolchain automatically). Windows: MSVC Build Tools must be present.
- **Dependencies:** C linker (Xcode CLT on macOS, MSVC Build Tools on Windows)
- **Invocation:** `cargo` (direct; `rustc` and `rustup` also available)
- **Last verified version:** macOS: 1.93.1 (2026-03-02) | Windows: pending | Linux: pending

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

- **Platform Status:** macOS: supported | Windows: supported | Linux: supported
- **Concurrency:** Yes -- stateless CLI
- **Post-Install Config:** None
- **Dependencies:** Pandoc (when used as `--pdf-engine`)
- **Invocation:** `typst` (direct; never `npx typst`)
- **Last verified version:** macOS: 0.14.2 (2026-03-02) | Windows: pending | Linux: pending

---

## Python

**Source**: https://www.python.org/downloads/
**Purpose**: Python runtime. Required by: Modal CLI, uv, pip-installed tools.

### Install

| Platform | Method | Command |
|----------|--------|---------|
| macOS | Homebrew (preferred) | `brew install python` |
| Windows | pymanager (preferred) | `winget install Python.PythonInstallManager` then `py install 3.14` |

**Note (Windows)**: Python Install Manager (pymanager, PEP 773) is the official PSF tool
for managing Python runtimes on Windows. The winget ID `Python.PythonInstallManager` is
version-agnostic and auto-updates. Runtimes are managed via `py install <version>`.

### Update

- Homebrew: `brew upgrade python`
- pymanager: `winget upgrade Python.PythonInstallManager` (manager) + `py install --update 3.14` (runtime)

### Check Version

```bash
python3 --version   # macOS
python --version    # Windows
py list             # Windows: list installed runtimes (pymanager)
```

### Non-Preferred Install Methods (cleanup targets)

| Method | Detection | Why not preferred |
|--------|-----------|-------------------|
| Microsoft Store (MSIX) | `Get-AppxPackage *PythonSoftwareFoundation*` | PATH conflicts with pymanager, can't be managed by winget upgrade |
| winget `Python.Python.3.x` | `winget list --id Python.Python` | Version-specific ID requires manual bumps; replaced by pymanager |
| Old py.exe launcher | `py --help` (no `install` subcommand) | Superseded by pymanager; conflicts if both present |
| Conda | `conda list python` | Environment isolation issues, conflicts with system Python |
| pyenv | `pyenv versions` | Extra layer of indirection, not needed for our use case |

### Notes

- On macOS, `python3` and `pip3` are the correct commands (Homebrew convention)
- On Windows, `python` and `python -m pip` are the correct commands (PEP 773 deprecates standalone `pip`)
- On Windows, pymanager provides `py` for runtime management (`py install`, `py list`, `py install --update`)

### Lifecycle

- **Platform Status:** macOS: supported | Windows: supported | Linux: supported
- **Concurrency:** Yes -- runtime
- **Post-Install Config:** None
- **Dependencies:** --
- **Invocation:** `python3` (macOS) / `python` (Windows); `pip3` (macOS) / `python -m pip` (Windows); `py` (Windows: runtime management)
- **Last verified version:** macOS: pending | Windows: pending | Linux: pending

---

## uv

**Source**: https://docs.astral.sh/uv/getting-started/installation/
**Purpose**: Fast Python package installer and resolver. Preferred over pip for package installs.

### Install

| Platform | Method | Command |
|----------|--------|---------|
| macOS | Homebrew (preferred) | `brew install uv` |
| Windows | winget (preferred) | `winget install --id=astral-sh.uv -e` |

### Update

- Homebrew: `brew upgrade uv`
- winget: `winget upgrade --id=astral-sh.uv`

### Check Version

```bash
uv --version
```

### Notes

- 50x-100x faster than pip for package resolution and installation
- Drop-in replacement for `pip install`: use `uv pip install`
- 50K+ GitHub stars, Astral (official org), MIT license, very active releases

### Lifecycle

- **Platform Status:** macOS: supported | Windows: supported | Linux: supported
- **Concurrency:** Yes -- stateless CLI
- **Post-Install Config:** None
- **Dependencies:** --
- **Invocation:** `uv` (direct)
- **Last verified version:** macOS: pending | Windows: pending | Linux: pending

---

## Go

**Source**: https://go.dev
**Purpose**: Go programming language toolchain. Required by `go install` for tools like Datadog Pup CLI.

### Install

| Platform | Method | Command |
|----------|--------|---------|
| macOS | Homebrew (preferred) | `brew install go` |
| Windows | winget (preferred) | `winget install GoLang.Go` |

### Update

- Homebrew: `brew upgrade go`
- winget: `winget upgrade GoLang.Go`

### Check Version

```bash
go version
```

### Non-Preferred Install Methods

| Method | Platform | Notes |
|--------|----------|-------|
| macOS .pkg installer | macOS | Installs to /usr/local/go; setup-go.sh removes and replaces with Homebrew |
| MSI installer | Windows | setup-go.ps1 detects and proceeds with winget |
| Chocolatey | Windows | setup-go.ps1 attempts `choco uninstall golang` then installs via winget |
| goenv | macOS/Linux | Warn-only; user-managed, not removed |
| Scoop | Windows | Warn-only; user-managed, not removed |
| Manual tarball | macOS/Linux | setup-go.sh removes /usr/local/go/ and replaces with Homebrew |

### Notes

- GOPATH/bin must be on PATH for `go install` binaries to be accessible
- Default GOPATH: `~/go` (macOS) / `%USERPROFILE%\go` (Windows)
- `go install` used by Datadog Pup as alternative install method

### Lifecycle

- **Platform Status:** macOS: supported | Windows: supported | Linux: supported
- **Concurrency:** Yes -- stateless CLI
- **Post-Install Config:** GOPATH/bin on PATH (automated by setup script)
- **Dependencies:** --
- **Invocation:** `go` (direct)
- **Last verified version:** macOS: pending | Windows: pending | Linux: pending

---

## Modal CLI

**Source**: https://modal.com/docs/guide
**Purpose**: Serverless Python compute platform (Debian Linux containers). GPU workloads,
  batch jobs, scheduled functions. Planned compute backend for aitools.nobul.tech (Layer 3).

### Install

| Platform | Method | Command |
|----------|--------|---------|
| All | uv tool (preferred) | `uv tool install modal` |
| All | pip (fallback) | `pip install --user modal` |

### Update

```bash
uv tool upgrade modal
```

### Check Version

```bash
modal --version
```

### Prerequisites

- Python 3.10+
- `modal setup` (one-time auth, browser flow) required after install

### Lifecycle

- **Platform Status:** macOS: supported | Windows: supported | Linux: supported
- **Concurrency:** Yes -- stateless CLI
- **Post-Install Config:** `modal setup` required (not automated)
- **Dependencies:** Python 3.10+, uv (preferred) or pip
- **Invocation:** `modal` (direct)
- **Last verified version:** macOS: pending | Windows: pending | Linux: pending

---

## Datadog CLI (Pup)

**Source**: https://github.com/datadog-labs/pup
**Purpose**: Datadog CLI -- query logs, manage monitors, dashboards, incidents, metrics across 33+ products. 200+ commands.

### Install

| Platform | Method | Command |
|----------|--------|---------|
| macOS/Linux | Homebrew (preferred) | `brew install datadog-labs/pack/pup` |
| Windows | cargo install (source) | `cargo install --git https://github.com/datadog-labs/pup` |
| macOS/Linux | Manual download | Pre-built binaries from [latest release](https://github.com/datadog-labs/pup/releases/latest) |

### Update

- Homebrew: `brew upgrade datadog-labs/pack/pup`
- cargo: re-run `cargo install --git https://github.com/datadog-labs/pup`

### Check Version

```bash
pup version
```

### Prerequisites

- `pup auth login` (one-time OAuth, browser flow) required after install
- **Windows build prerequisites**: Rust toolchain + build tools (MSVC, NASM) are checked
  automatically by `setup-datadog.ps1` via `Check-BuildPrereqs`. If any are missing, the
  script fails early with remediation instructions (no wasted compilation time).
- **macOS cargo fallback**: If Homebrew install fails, the cargo fallback path checks
  prerequisites via `check_build_prereqs` and diagnoses failures via `diagnose_build_failure`.

### Authentication

| Command | Purpose |
|---------|---------|
| `pup auth login` | OAuth2 + PKCE browser flow (one-time) |
| `pup auth status` | Check auth (always exits 0; check output for `"authenticated": false`) |
| `pup auth refresh` | Refresh access token |
| `pup auth logout` | Clear stored tokens |

- **Token storage**: System keychain (macOS Keychain, Windows Credential Manager, Linux Secret Service). Set `DD_TOKEN_STORAGE=file` for file-based fallback.
- **Auth priority**: `DD_ACCESS_TOKEN` (bearer) > OAuth2 tokens (from `pup auth login`) > API keys (`DD_API_KEY` + `DD_APP_KEY`)
- **Auth check for setup scripts**: `pup auth status` output content (exits 0 regardless — check for `Not authenticated` or `"authenticated": false`)
- **Agent mode**: Auto-detected when `CLAUDECODE` env var is set — structured JSON output, auto-approves confirmations

### Notes

- Rewritten from Go to Rust (circa v0.24+). No pre-built Windows binaries as of v0.26.0.
- Published under `datadog-labs` (not main `DataDog` org) -- yellow flag per tool evaluation criteria. Officially maintained by Datadog employees.
- OAuth2 auth model -- no API key management needed for interactive use
- Useful for querying logs and managing monitors from the command line
- Install verified via chrome-devtools: 2026-03-06 (GitHub README + releases page)

### Lifecycle

- **Platform Status:** macOS: supported | Windows: supported (source build) | Linux: supported
- **Concurrency:** Yes -- stateless CLI
- **Post-Install Config:** `pup auth login` required (not automated); check with `pup auth status`
- **Dependencies:** None (Homebrew) or Rust toolchain (cargo install)
- **Invocation:** `pup` (direct)
- **Last verified version:** macOS: Pup 0.26.0 (2026-03-06) | Windows: Pup 0.26.0 (2026-03-06) | Linux: pending

---

## Overrides

Intentional deviations from upstream defaults. When comparing our install
commands against official docs, these are expected discrepancies — not bugs.

| Tool | Override | Upstream Default | Our Value | Reason | Added | Last verified |
|------|----------|-----------------|-----------|--------|-------|---------------|
| Chrome DevTools MCP | `--isolated` flag | Not included | Added to all install commands | Enables concurrent Claude Code + Cursor sessions by using throwaway temp Chrome profiles | 2026-02-19 | 2026-02-27 |

