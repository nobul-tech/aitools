# AI Tooling Hub

Jose's cross-machine scaffolding for Claude Code, Cursor, and MCP across Windows and macOS.

## Project Structure

```
aitools/
├── .claude/rules/       # Claude Code project rules (modular)
├── .cursor/rules/       # Cursor rules (.mdc format)
│   ├── general.mdc      #   Identity, code style
│   ├── sources-of-truth.mdc  # Protected files review gate
│   ├── tool-lifecycle.mdc     # Phase 2 gate for new tools
│   ├── cross-platform.mdc    # Dual-script, OS guards, PS 7
│   └── concurrent-agents.mdc # Multi-agent coordination
├── shared/              # Source of truth for configs
│   ├── claude-shared.md #   → embedded into deploy scripts by build
│   ├── cursor-rules/    # Template rules + User Rules source of truth
│   ├── shell/           # Shell aliases (bash/zsh + PowerShell)
│   ├── hooks/           # Claude Code hooks (session archive)
│   └── mcp/             # MCP server configuration docs
├── scripts/             # Dev/source scripts (read from shared/)
│   ├── aitools          # CLI entry point (bash, macOS/Linux)
│   ├── aitools.ps1      # CLI entry point (PowerShell, Windows)
│   └── build-deploy.sh  # Generates deploy/ from scripts/ + shared/
├── deploy/              # Self-contained scripts for MDM (generated)
├── plans/               # Detailed plans for roadmap items
└── reference/           # Setup notes and how-tos
```

## Build & Run

```bash
# Generate self-contained deploy/ scripts from scripts/ + shared/
bash scripts/build-deploy.sh

# CLI usage (after install -- same commands on both platforms)
aitools                        # Sync configs: quiet pull + rebuild + deploy all
aitools gitpull                # Update source: pull + deploy + changelog + version tag
aitools install                # Full setup: pull + install tools + deploy configs
aitools --addmcp vercel        # Add MCP server to current project
aitools --addmcp vercel webflow  # Add multiple MCP servers
aitools user init              # Set up user repo + session archive hook
aitools sessions list [proj]   # List archived sessions
aitools sessions archive ID    # Manually archive a session by ID
aitools sessions move F proj   # Refile an archived session under a different project

# Verification checklists (replaces ad-hoc commands)
# macOS/Linux:
bash scripts/check-pre-commit.sh       # or --fix (auto-fix line endings, exec bits, build)
bash scripts/check-pre-push.sh         # read-only
bash scripts/check-post-push.sh        # or --extensive (all 20 steps)
# Windows (PowerShell):
.\scripts\check-pre-commit.ps1         # or -Fix
.\scripts\check-pre-push.ps1           # read-only
.\scripts\check-post-push.ps1          # or -Extensive (all 20 steps)

# Deploy to an endpoint (no repo needed -- run from deploy/)
# macOS/Linux:
bash deploy/setup-user-claude.sh
# Windows (PowerShell):
.\deploy\setup-user-claude.ps1

# Clipboard to Markdown (requires pandoc; optional: claude CLI for auto-naming)
clip2md                        # Auto-name via AI: 250324-garcia-budget.md
clip2md meeting-notes          # Explicit name: meeting-notes.md
```

## Cross-Platform Paths

| Resource | Windows | macOS |
|----------|---------|-------|
| This repo | `~\repos\aitools` | `~/repos/aitools` |
| User CLAUDE.md | `~/.claude/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| Shared config | `shared/claude-shared.md` (in repo) | `shared/claude-shared.md` (in repo) |
| User repo | `~\repos\aitools-<username>` | `~/repos/aitools-<username>` |

## Key Decisions

- **Marker** is the preferred PDF-to-markdown converter
- This directory is the **"home base"** for general/cross-project AI conversations
- Session notes are ephemeral; durable knowledge goes in CLAUDE.md or reference/ docs (auto-memory is local to each machine, not shared)
- Shared preferences live in `shared/claude-shared.md` (template). User's personal copy lives in `<userRepoPath>/claude/CLAUDE.md` (syncs across machines). `scripts/setup-user-claude.sh/.ps1` reads from user repo first (fallback: shared template), interpolates `{{PLACEHOLDER}}` tokens from `profile.json`, and writes to `~/.claude/CLAUDE.md`. `deploy/` scripts use build-time embedded content (self-contained).
- `deploy/` scripts are self-contained (zero dependencies beyond bash/PowerShell) -- MDM-ready
- **Dual deployment path equivalence**: Changes to `shared/` must flow through both the dev/repo path (runtime) and MDM path (build-time embed via `build-deploy.sh`). Template changes also require syncing the user repo copy. See `.claude/rules/deploy-paths.md`.
- Each script has `.sh` + `.ps1` pair; deploy scripts use hard OS guards, `aitools` bash forwards to PS1 on Windows
- Each managed tool gets dedicated `setup-<tool>.sh` + `.ps1` scripts in `scripts/`, copied to `deploy/` by build; `aitools-install` delegates to these
- `reference/tool-install-sources.md` is the source of truth for install commands -- always check before modifying installer scripts
- **Tool evaluation policy**: Never recommend unverified or abandoned tools — see `reference/tool-evaluation-criteria.md` for the full framework
- `claude mcp add` can't run inside nested Claude Code sessions -- `--addmcp` has a node fallback
- **Tool install cleanup**: When a setup script installs a tool via a preferred method (e.g., Homebrew), it should also detect and remove old installs from non-preferred sources (e.g., npm/bun global, manual binary). Prevents stale versions shadowing the preferred one due to PATH order. See `setup-vercelcli` for the pattern.
- **Cross-platform tool check**: When recommending tools in this project, verify availability on both macOS and Windows. Disclose if a tool is single-platform or has limited support on one OS.
- **Tool evaluation tracking**: Tools recommended but not yet approved go in the "Under Evaluation" section of `reference/tool-install-sources.md`. Promote or remove after testing.
- **Tool platform states**: `evaluating → approved → supported` per platform, plus `n/a`. Defined in `reference/tool-evaluation-criteria.md`. Release notes use `**Verified on:**` for release verification -- distinct from tool approval status.
- **Tool lifecycle**: Verified official sources must be recorded in `reference/tool-install-sources.md` before any setup code is written. See "Evaluation-to-Support Lifecycle" in `reference/tool-evaluation-criteria.md`.
- **Release versioning**: `major.minor.patch` scheme documented at the top of `RELEASE_NOTES.md`. Major = structural changes, minor = features/tools, patch = isolated bug fixes.
- **Roadmap tracking**: `ROADMAP.md` tracks active/planned work. Detailed plans in `plans/`. Completed items move to `RELEASE_NOTES.md`.
- **`--isolated` for stdio MCP servers**: Chrome DevTools MCP uses `--isolated` flag for throwaway temp Chrome profiles, enabling concurrent Claude Code + Cursor sessions without Chrome profile lock conflicts
- **Tool lifecycle entries require 5 fields**: Platform Status, Concurrency, Post-Install Config, Dependencies, Invocation -- see `reference/tool-evaluation-criteria.md`
- **Documentation standards**: RELEASE_NOTES format, version numbering, ROADMAP format, and reference doc threshold are codified in `.claude/rules/documentation-standards.md`
- **Claude Code version tracking**: Version-dependent workarounds tracked in `reference/claude-code-version-deps.md`. Review on CC version bumps via post-push checklist (#20).

## Code Conventions

- Python 3.10+, type hints, `argparse` for CLI, `pathlib.Path` over `os.path`
- Scripts (this repo): provide both `.ps1` and `.sh` variants since this repo is cross-platform
- Script logging: all setup scripts use structured logging — `log`/`log_ok`/`log_error`/`log_warn` (bash) and `Log`/`LogOk`/`LogError`/`LogWarn` (PS1). Full conventions in `.claude/rules/script-standards.md`.
- Keep this file under 200 lines; use `@reference/` imports for detail
- For Cursor rule correspondence, skills deployment, MCP setup, and CLI config, see `reference/cursor-practices.md`
- For tool evaluation framework and lifecycle phases, see `reference/tool-evaluation-criteria.md`
- For the workspace tool-requests convention, see `rfcs/RFC-0001-workspace-tool-requests.md`

### Script Execution Patterns

**Dual-script rule**: Every setup script gets both `.sh` and `.ps1` with OS guards. Shell-only scripts (no `.ps1` pair) are exceptions that must be documented in `.claude/rules/cross-platform.md` with rationale. Current exceptions: hooks (bash on all platforms by CC design) and `build-deploy.sh` (produces platform-independent output via sentinel markers).

**Windows dispatch**: Claude Code on Windows uses Git Bash. `CLAUDE_CODE_SHELL` is broken ([#25558](https://github.com/anthropics/claude-code/issues/25558)). Any code path calling setup scripts must dispatch by platform:
```bash
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) pwsh -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$ps1_path")" ;;
    *) bash "$sh_path" ;;
esac
```

**PowerShell from Bash**: Always single-quote the outer `-Command` string. Use double quotes inside for PS interpolation. For anything beyond a one-liner, use the write-then-execute pattern instead.

**Write-then-execute**: For complex bash or PowerShell, write to a temp file (Write tool), execute (`bash` or `pwsh -File`), clean up. Avoids quoting hell and keeps code readable/editable. This applies to both languages (see USO: Scratch files for complex scripting).

**String manipulation**: Use Perl for non-trivial transforms (see USO: Perl for string manipulation). sed is fine for trivial single substitutions only.

### Project Coaching Items

- **PCI: Audit broadly** -- When auditing error handling, check both suppressed errors (`SilentlyContinue`, `2>/dev/null`) AND missing error handling (no `try/catch`, no `-ErrorAction`, bare `Get-Content` on untrusted input). Pattern matching finds suppressions; "what happens if this fails?" finds gaps.

### Project Standing Orders

- **PSO: Checklist scripts, not ad-hoc** -- Use the project's check scripts (`check-pre-commit`, `check-pre-push`, `check-post-push`) instead of ad-hoc commands. Ad-hoc is OK for novel one-off checks only.
- **PSO: Platform-native dispatch** -- Run `.ps1` via `pwsh -File` on Windows, `.sh` via `bash` on macOS. Never run `.sh` setup scripts on Windows -- they skip PS1 validation and miss Windows-only issues. **Exceptions:** hooks (Claude Code runs hooks in bash on all platforms) and `build-deploy.sh` (approved single-language exception -- produces platform-independent output).

- For user repo pattern, profile schema, session archiving, and config schema, see `reference/user-repo.md`
