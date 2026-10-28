# aitools

Cross-machine AI tooling hub — shared configs, rules, and scripts for Claude Code, Cursor, and MCP on macOS, Windows, Linux (Ubuntu), Claude Code web and Cursor cloud. Supported list: `reference/cross-platform-detail.md` "Supported platforms and environments".

## What's here

| Directory | Purpose |
|-----------|---------|
| `shared/` | Source of truth for user-level content: `claude-shared.md` (CLAUDE.md template), `skills/`, `hooks/`, `rules/`, `cursor-rules/`, `shell/` aliases, `mcp/` docs |
| `shared/hooks/` | Claude Code hooks; registration in `hooks-manifest.json` (SessionStart/SessionEnd harvest + archive + catch-up, PreToolUse guards, PostToolUse fixups, Stop hooks) |
| `scripts/` | `aitools` CLI, installers, setup scripts, `deploy-harness`, `build-deploy.sh` and `build-package.sh` pipelines |
| `deploy/` | Frozen historical shared baseline. `build-deploy.sh` now generates each user's MDM-ready scripts into their **dotprofile repo** (`aitools-<user>/deploy/`), not here |
| `registries/` | Governed JSON registries (tool registry, tool-ops, incidents, glossary, frameworks), accessed through their skills |
| `.claude/rules/` | Claude Code project rules |
| `.cursor/rules/` | Cursor project rules (.mdc format) |
| `reference/` | Setup notes, practices, specs |
| `scripts/check-*.sh/.ps1` | Automated pre-commit, pre-push, and post-push checklists |
| `tests/` | Test suites (CI runs logging, managed-files, profile, claude-mdm, build-deploy) |
| `packaging/` | Payload scripts for `build-package` (macOS PKG, Windows Intune, Linux .deb) |
| `plans/` | Detailed implementation plans for roadmap items |
| `harvesting/` | Harvested session artifacts + manifest |
| `rfcs/` | Design RFCs |
| `.github/workflows/check.yml` | CI: macOS, Linux, Windows jobs |
| `ROADMAP.md` | Active and planned work items |
| `RELEASE_NOTES.md` | Version history and changelog |

## How it works

`shared/` is the single source of truth for shared framework content. `scripts/build-deploy.sh` reads from `shared/` **and the user's dotprofile repo**, then embeds the content into self-contained, personalized deploy scripts written to **`<userRepoPath>/deploy/`** (the user's `aitools-<user>` repo) — not the shared `aitools/deploy/`, which is now frozen/historical. Deploy scripts need only bash or PowerShell on the target machine — no repo clone required. The workflow is: edit `shared/` (framework) or your dotprofile repo (personal config) → run `build-deploy.sh` → commit the generated `deploy/` **in your dotprofile repo** → deploy to endpoints.

A third, parallel path, `scripts/build-package.sh` (v1.0 scaffolding: `--dry-run` works; package builds are stubs until plan batches B2/B8–B10), builds installable packages for a fleet of users: a Windows Intune Win32 app (`.intunewin`), an unsigned macOS PKG (Intune, Jamf) and a Linux `.deb` for Ubuntu 24.04 and 22.04 (VMs and containers, including Claude Code web and Cursor cloud). The dev and MDM paths stay as they are. Design: `plans/build-package/design.md`.

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
aitools gitpull --patch          # Same as gitpull, bump the patch version
aitools install                  # Full setup: install tools + deploy configs
aitools install --skip-gh-auth --repos-path PATH --skip-drive-detection
aitools mcp                      # Show MCP server status
aitools --addmcp vercel          # Enable MCP server for current project
aitools --version                # Show installed and repo version
aitools --dry-run                # Preview without writing files
aitools --force                  # No prompts: managed files take the source version (backups kept)
aitools user init                # Set up user repo, register this machine, session archive hook
aitools user init --alias A      # Register this machine as profile A without a prompt
aitools sessions list [project]  # List archived sessions
aitools sessions archive <id>    # Manually archive a session by ID
aitools sessions move F proj     # Refile an archived session under another project
aitools dashboard [--stop|--status|--snapshot|--background]  # Mission control dashboard server
```

### Deploy to a machine (no repo clone needed)

`build-deploy.sh` generates self-contained, MDM-ready scripts in your dotprofile repo's `deploy/` (`aitools-<user>/deploy/`). Copy that directory to the endpoint and run `deploy-harness` **first**: it fills `~/.aitools` (rules, reference, registries, hooks, skills, bin, config.json). The other scripts read from it: the rules fan-outs in `setup-user-claude` and `setup-user-cursor` read `~/.aitools/rules` (run before it, they report `n/a (no harness rules)` and deploy no rules).

macOS/Linux:
```bash
bash deploy/deploy-harness.sh          # ~/.aitools harness files (run first)
bash deploy/setup-user-claude.sh       # Claude Code CLAUDE.md + rules
bash deploy/setup-user-settings.sh     # settings.json <-> profile.json
bash deploy/setup-user-hooks.sh        # Claude Code hooks
bash deploy/setup-user-skills.sh       # skills
bash deploy/setup-user-mcp.sh          # Claude Code MCP servers
bash deploy/setup-user-cursor.sh       # Cursor CLI config + rules fan-out
bash deploy/setup-cursor-ide-mcp.sh    # Cursor MCP servers
bash deploy/setup-<tool>.sh            # one per managed tool (gh-cli, pandoc, rust, typst, uv, python, go, modal, datadog, perl, bash, google-chrome, vercelcli)
```

Windows (PowerShell):
```powershell
.\deploy\deploy-harness.ps1            # ~/.aitools harness files (run first)
.\deploy\setup-user-claude.ps1
.\deploy\setup-user-settings.ps1
.\deploy\setup-user-hooks.ps1
.\deploy\setup-user-skills.ps1
.\deploy\setup-user-mcp.ps1
.\deploy\setup-user-cursor.ps1
.\deploy\setup-cursor-ide-mcp.ps1
.\deploy\setup-<tool>.ps1              # one per managed tool
```

On an endpoint where `aitools-install` never ran, `deploy-harness` deploys the harness files but reports `ERROR config.json not generated` (it needs the bootstrap keys `reposPath`/`repoPath`).

### Honest harness (`hh`)

`hh` runs **`git pull --ff-only`** first (skip with **`--no-pull`** or **`HH_NO_PULL=1`** if offline), then **git status** for harness paths (relay, `shared/`, `deploy/`, `build-deploy.sh`, `.cursorignore`), then **`aitools`** (unless `-n` / `--status-only`). Use it when you want one habit instead of remembering pull vs relay vs shared vs deploy.

- **`[RELAY]` prompt:** After **`aitools`** (or **`hh -n`**), if `.aitools/channel/relay.md` is uncommitted or **`main`** is ahead of **`origin/main`**, the harness may prompt (`scripts/relay-outbound-prompt.sh` / `.ps1`). Set **`AITOOLS_SKIP_RELAY_PROMPT=1`** to skip. Inbound pull is automatic; outbound commit/push is not.
- **Install:** `aitools install` copies `hh` to `~/.local/bin` (macOS/Linux) and `hh.ps1` + a `hh` function in PowerShell (Windows). Requires `~/.local/bin` on `PATH` (installer usually wires this).
- **Optional pre-commit** (`scripts/githooks/pre-commit`; enable with `bash scripts/init-hh-hooks.sh` or `git config core.hooksPath scripts/githooks`): when `shared/` or `scripts/build-deploy.sh` is staged, it runs `build-deploy.sh`, which rebuilds your **dotprofile** `deploy/` (backup + swap). Commit that change in the dotprofile repo. Do not enable it in agent worktrees: it runs against the real `HOME`.

### Develop / maintain configs

Work inside the repo to update shared configuration:

macOS/Linux:
```bash
vim shared/claude-shared.md
bash scripts/build-deploy.sh        # rebuilds the dotprofile deploy/ (backs up to deploy.bak.<UTC>/, swaps in only on success)
git add shared/ && git commit -m "Update shared config"
# then commit the regenerated deploy/ in your dotprofile repo (aitools-<user>/)
```

Windows (PowerShell):
```powershell
# Edit shared source files in your editor, then rebuild deploy scripts:
bash scripts/build-deploy.sh             # bash-only build step (uses Git Bash on Windows); rebuilds the dotprofile deploy/ (backup + swap)
git add shared/; git commit -m "Update shared config"   # commit deploy/ in your dotprofile repo
```

### Verification checklists

Run before commit, push, and after push -- replaces ad-hoc commands:

macOS/Linux:
```bash
bash scripts/check-pre-commit.sh         # 21 steps; --fix auto-repairs line endings, exec bits, build freshness
bash scripts/check-pre-push.sh           # 10 steps, read-only (step 7 rebuilds into a temp copy of the dotprofile)
bash scripts/check-post-push.sh          # all post-push steps (1-32; 15 and 28 are retired SKIPs)
```

Windows (PowerShell):
```powershell
.\scripts\check-pre-commit.ps1           # 21 steps; -Fix auto-repairs
.\scripts\check-pre-push.ps1             # 10 steps, read-only
.\scripts\check-post-push.ps1            # all post-push steps (1-32; 15 and 28 are retired SKIPs)
```

`--fix` / `-Fix` runs `build-deploy.sh` against the real `HOME` (it rebuilds the dotprofile `deploy/`): agents never pass it.

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
