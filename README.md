# aitools

Cross-machine AI tooling hub — shared configs, rules, and scripts for Claude Code, Cursor, and MCP across Windows 11 and macOS.

## What's here

| Directory | Purpose |
|-----------|---------|
| `shared/` | Source of truth: Claude prefs, Cursor rules, shell aliases, MCP docs |
| `scripts/` | `aitools` CLI, installers, setup scripts, `build-deploy.sh` pipeline |
| `deploy/` | Generated self-contained scripts (MDM-ready, no repo needed) |
| `.claude/rules/` | Claude Code project rules |
| `.cursor/rules/` | Cursor project rules (.mdc format) |
| `reference/` | Setup notes, practices, session showcase |
| `scripts/check-*.sh/.ps1` | Automated pre-commit, pre-push, and post-push checklists |
| `plans/` | Detailed implementation plans for roadmap items |
| `shared/hooks/` | Claude Code hooks (session archive) |
| `ROADMAP.md` | Active and planned work items |
| `RELEASE_NOTES.md` | Version history and changelog |

## How it works

`shared/` is the single source of truth for all configuration. `scripts/build-deploy.sh` reads from `shared/` and embeds the content into self-contained deploy scripts in `deploy/`. There is no separate `build/` output directory—MDM and CI use `deploy/` only. The workflow is: edit `shared/` → run `build-deploy.sh` → commit `deploy/` → deploy to endpoints. Deploy scripts need only bash or PowerShell on the target machine — no repo clone required.

## Quick start

### Install on a new machine

**One-liner (recommended)** — installs prerequisites (package manager + git), clones the repo, runs the full installer, then (interactive only) `aitools user init` to load your dotprofile. Idempotent; re-run anytime.

macOS/Linux:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/nobul-tech/aitools/main/scripts/bootstrap.sh)"
```

Windows (PowerShell):
```powershell
irm https://raw.githubusercontent.com/nobul-tech/aitools/main/scripts/bootstrap.ps1 | iex
```

**Manual** — clone the repo and run the installer yourself:

macOS/Linux:
```bash
git clone https://github.com/nobul-tech/aitools.git ~/repos/aitools
bash ~/repos/aitools/scripts/aitools-install.sh
```

Windows (PowerShell):
```powershell
git clone https://github.com/nobul-tech/aitools.git ~\repos\aitools
~\repos\aitools\scripts\aitools-install.ps1
```

After install, the `aitools` command is available:

```bash
aitools                          # Sync configs: pull + rebuild + deploy all
aitools gitpull                  # Update source + deploy + changelog + version tag
aitools install                  # Full setup: install tools + deploy configs
aitools mcp                      # Show MCP server status
aitools --addmcp vercel          # Enable MCP server for current project
aitools --version                # Show installed and repo version
aitools user init                # Set up user repo + session archive hook
aitools sessions list [project]  # List archived sessions
aitools sessions archive <id>    # Manually archive a session by ID
```

### Deploy to a machine (no repo needed)

Run these from the `deploy/` directory -- self-contained, MDM-ready:

macOS/Linux:
```bash
bash deploy/setup-user-claude.sh        # Claude Code user preferences
bash deploy/setup-user-cursor.sh        # Cursor CLI + config
bash deploy/setup-user-mcp.sh           # Claude Code MCP servers
bash deploy/setup-cursor-ide-mcp.sh         # Cursor MCP servers
bash deploy/setup-vercelcli.sh          # Vercel CLI
bash deploy/setup-pandoc.sh             # Pandoc
bash deploy/setup-rust.sh               # Rust (cargo)
```

Windows (PowerShell):
```powershell
.\deploy\setup-user-claude.ps1          # Claude Code user preferences
.\deploy\setup-user-cursor.ps1          # Cursor CLI + config
.\deploy\setup-user-mcp.ps1             # Claude Code MCP servers
.\deploy\setup-cursor-ide-mcp.ps1           # Cursor MCP servers
.\deploy\setup-vercelcli.ps1            # Vercel CLI
.\deploy\setup-pandoc.ps1               # Pandoc
.\deploy\setup-rust.ps1                 # Rust (cargo)
```

### Honest harness (`hh`)

`hh` runs **`git pull --ff-only`** first (skip with **`--no-pull`** or **`HH_NO_PULL=1`** if offline), then **git status** for harness paths (relay, `shared/`, `deploy/`, `build-deploy.sh`, `.cursorignore`), then **`aitools`** (unless `-n` / `--status-only`). Use it when you want one habit instead of remembering pull vs relay vs shared vs deploy.

- **`[RELAY]` prompt:** After **`aitools`** (or **`hh -n`**), if `.aitools/channel/relay.md` is uncommitted or **`main`** is ahead of **`origin/main`**, the harness may prompt (`scripts/relay-outbound-prompt.sh` / `.ps1`). Set **`AITOOLS_SKIP_RELAY_PROMPT=1`** to skip. Inbound pull is automatic; outbound commit/push is not.
- **Install:** `aitools install` copies `hh` to `~/.local/bin` (macOS/Linux) and `hh.ps1` + a `hh` function in PowerShell (Windows). Requires `~/.local/bin` on `PATH` (installer usually wires this).
- **Optional pre-commit** (regenerates `deploy/` when `shared/` or `scripts/build-deploy.sh` is staged): from repo root run `bash scripts/init-hh-hooks.sh` once, or `git config core.hooksPath scripts/githooks`.

### Develop / maintain configs

Work inside the repo to update shared configuration:

macOS/Linux:
```bash
vim shared/claude-shared.md
bash scripts/build-deploy.sh
git add shared/ deploy/ && git commit -m "Update shared config"
```

Windows (PowerShell):
```powershell
# Edit shared source files in your editor, then rebuild deploy scripts:
bash scripts/build-deploy.sh             # bash-only build step (uses Git Bash on Windows)
git add shared/ deploy/; git commit -m "Update shared config"
```

### Verification checklists

Run before commit, push, and after push -- replaces ad-hoc commands:

macOS/Linux:
```bash
bash scripts/check-pre-commit.sh         # 12 steps; or --fix to auto-repair
bash scripts/check-pre-push.sh           # 10 steps, read-only
bash scripts/check-post-push.sh          # 5 always-tier steps
bash scripts/check-post-push.sh --extensive  # all 20 steps
```

Windows (PowerShell):
```powershell
.\scripts\check-pre-commit.ps1           # 12 steps; or -Fix to auto-repair
.\scripts\check-pre-push.ps1             # 10 steps, read-only
.\scripts\check-post-push.ps1            # 5 always-tier steps
.\scripts\check-post-push.ps1 -Extensive # all 20 steps
```

See `reference/` for deeper setup notes and practices.

**Add shell aliases** (optional):

```bash
# bash/zsh — add to ~/.bashrc or ~/.zshrc
source ~/repos/aitools/shared/shell/aliases.sh
```

```powershell
# PowerShell — add to $PROFILE
. "$HOME\repos\aitools\shared\shell\aliases.ps1"
```

Key aliases: `cc` (Claude Code with CLAUDE.md check), `ccr`/`ccs` (resume/pick sessions), `clip2md` (clipboard to markdown).

**Clipboard to Markdown** (requires pandoc; optional: claude CLI for auto-naming):

```bash
clip2md                          # Auto-name via AI: 250324-garcia-budget.md
clip2md meeting-notes            # Explicit name: meeting-notes.md
```

## Version history

See [RELEASE_NOTES.md](RELEASE_NOTES.md) for the full changelog.

## License

MIT
