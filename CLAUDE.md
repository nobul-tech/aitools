# AI Tooling Hub

Jose's cross-machine scaffolding for Claude Code, Cursor, MCP across Windows and macOS. Automates lifecycle management of supported tools, context and configuration files.  Supports multiple users with dotprofile repos

## Project Structure

```
aitools/
├── .claude/
│   ├── commands/        # Claude Code slash commands
│   └── rules/           # Claude Code project rules (modular)
├── .cursor/rules/       # Cursor rules (.mdc format)
├── shared/              # Source of truth for configs
│   ├── claude-shared.md #   → embedded into deploy scripts by build
│   ├── cursor-rules/    # Template rules + User Rules source of truth
│   ├── hooks/           # Claude Code hooks
│   ├── mcp/             # MCP server configuration docs
│   ├── shell/           # Shell aliases (bash/zsh + PowerShell)
│   └── skills/          # Claude Code skill definitions
├── scripts/             # Dev/source scripts (read from shared/)
│   ├── aitools-lib.sh   #   Shared helpers (sourced; inlined into deploy/ by build)
│   ├── aitools-lib.ps1  #   PowerShell equivalent
│   ├── check-lib.sh     #   Check-script helpers (sources aitools-lib)
│   ├── check-lib.ps1    #   PowerShell equivalent
├── deploy/              # Self-contained scripts for MDM (generated)
├── plans/               # Detailed plans for roadmap items
├── reference/           # Setup notes and how-tos
├── rfcs/                # Design proposals
├── RELEASE_NOTES.md
└── ROADMAP.md
```

## Dotprofile Repos

Per-user companion repos store personal preferences, rules, and session archives. Named `aitools-<github-username>` (e.g., `aitools-nobul-jose`). Full spec: `reference/user-repo.md`.

```
aitools-<username>/
├── profile.json              # User identity, machine profiles, tool preferences
├── claude/
│   ├── CLAUDE.md             # Personal CLAUDE.md template ({{PLACEHOLDER}} tokens)
│   ├── effectiveness.md      # Claude Code effectiveness tracker
│   └── rules/                # User-level rules (deployed to ~/.claude/rules/)
│       └── concurrent-agents.md
├── sessions/                 # Archived Claude Code transcripts
│   └── <project>/            # One directory per project
│       └── YYYY-MM-DD_<id>.jsonl
└── README.md
```

- **Template priority**: `<userRepoPath>/claude/CLAUDE.md` wins over `shared/claude-shared.md`
- **Rules deployment**: additive -- managed files updated, unmanaged files preserved
- **Session archiving**: automatic via `SessionEnd` hook (reads `userRepoPath` from `~/.aitools/config.json`)
- **Setup**: `aitools user init` creates the repo and configures the hook

## Build & Run

```bash
# Generate self-contained deploy/ scripts from scripts/ + shared/
bash scripts/build-deploy.sh

# CLI usage (after install -- same commands on both platforms)
aitools                        # Sync configs: quiet pull + rebuild + deploy all
aitools gitpull [--patch]      # Update source: pull + deploy + changelog + version tag
aitools install                # Full setup: pull + install tools + deploy configs
aitools mcp                    # Show MCP server status for current project
aitools --addmcp vercel        # Add MCP server to current project
aitools --addmcp vercel webflow  # Add multiple MCP servers
aitools --dry-run              # Preview changes without writing files
aitools user init              # Set up user repo + session archive hook
aitools sessions list [proj]   # List archived sessions
aitools sessions archive ID    # Manually archive a session by ID
aitools sessions move <file> <project>  # Refile an archived session

# Verification checklists when working with git actions (replaces ad-hoc commands)
# macOS/Linux:
bash scripts/check*.sh       # or --fix (auto-fix line endings, exec bits, build)
# Windows (PowerShell):
.\scripts\check*.ps1         # or -Fix

# Clipboard to Markdown (requires pandoc; optional: claude CLI for auto-naming)
clip2md                        # Auto-name via AI: 250324-garcia-budget.md
clip2md meeting-notes          # Explicit name: meeting-notes.md
```

### Verification Details

- Pre-commit checklist: reference/pre-commit-checklist.md
- Pre-push checklist: reference/pre-push-checklist.md
- Post-push checklist: reference/post-push-checklist.md
- Script standards detail (exemptions, examples, check-script rules): reference/script-standards-detail.md

### Deploy using MDM

`build-deploy.sh` generates self-contained scripts in `deploy/` (`.sh` + `.ps1` pairs) -- config scripts (`setup-user-claude`, `-mcp`, `-hooks`, `setup-cursor-ide-mcp`, `setup-user-cursor`) and tool scripts (`setup-vercelcli`, `-pandoc`, `-rust`, `-typst`, `-gh-cli`, `-python`, `-uv`, `-modal`, `-go`, `-datadog`). Shared helpers from `scripts/aitools-lib.sh/.ps1` are inlined into deploy scripts at build time -- deploy scripts have no runtime dependency on the repo.

## Cross-Platform Paths

| Resource | Windows | macOS |
|----------|---------|-------|
| This repo | `%USERPROFILE%\repos\aitools` | `~/repos/aitools` |
| User CLAUDE.md | `%USERPROFILE%\.claude\CLAUDE.md` | `~/.claude/CLAUDE.md` |
| Shared config | `shared\claude-shared.md` (in repo) | `shared/claude-shared.md` (in repo) |
| User repo | `%USERPROFILE%\repos\aitools-<username>` | `~/repos/aitools-<username>` |

## Key Decisions

- This directory is the **"home base"** for general/cross-project AI conversations
- Shared preferences live in `shared/claude-shared.md` (template). User's personal copy lives in `<userRepoPath>/claude/CLAUDE.md` (syncs across machines). `scripts/setup-user-claude.sh/.ps1` reads from user repo first (dotprofile wins if present; fallback: shared template). Both files must be kept in sync — shared template is the fallback and the MDM deploy source. Interpolates `{{PLACEHOLDER}}` tokens from `profile.json`, and writes to `~/.claude/CLAUDE.md`. `deploy/` scripts use build-time embedded content (self-contained).
- `reference/tool-registry.md` is the source of truth for install commands -- always check before modifying installer scripts
- Install methods in `tool-registry.md` and `BuildPrereqs` must be derived from official tool documentation via the discovery process in `.claude/rules/tool-lifecycle.md` -- never chosen from assumption or memory
- **`claude mcp add` and nested sessions**: `claude mcp add` fails inside nested Claude Code sessions (`CLAUDECODE` env var blocks it). `--addmcp` avoids this by writing `.claude/settings.local.json` directly via Node.js. `setup-user-mcp.sh/.ps1` unsets the var as a workaround.

## Code Conventions

- Python 3.10+, type hints, `argparse` for CLI with `--help`, `pathlib.Path` over `os.path`, `if __name__ == "__main__":` guard
- Keep this file under 200 lines

### Script Execution Patterns


**Windows dispatch**: Claude Code on Windows uses Git Bash. `CLAUDE_CODE_SHELL` is broken ([#25558](https://github.com/anthropics/claude-code/issues/25558)). Any code path calling setup scripts must dispatch by platform:
```bash
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) pwsh -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$ps1_path")" ;;
    *) bash "$sh_path" ;;
esac
```

**PowerShell from Bash**: Always single-quote the outer `-Command` string. Use double quotes inside for PS interpolation. For anything beyond a one-liner, use the write-then-execute pattern instead.

### Project git conventions
When performing commit and push actions with git, before and after, you must look for any pre or post reference files, load those instructions into context, and follow them exactly

### Project Standing Orders

- **PSO: Checklist scripts, not ad-hoc** -- Use the project's check scripts (`check-pre-commit`, `check-pre-push`, `check-post-push`) instead of ad-hoc commands. Ad-hoc is OK for novel one-off checks only.
- **PSO: Platform-native dispatch** -- Run `.ps1` via `pwsh -File` on Windows, `.sh` via `bash` on macOS. Never run `.sh` setup scripts on Windows -- they skip PS1 validation and miss Windows-only issues. **Exceptions:** hooks (Claude Code runs hooks in bash on all platforms) and `build-deploy.sh` (approved single-language exception -- produces platform-independent output).
- **PSO: Equal platform visibility** -- When showing usage examples, commands, or invocations in docs, always show both macOS/bash and Windows/PowerShell. Never abbreviate one platform as "same but .ps1" or similar.
- **PSO: Audit broadly** -- When auditing error handling, check both suppressed errors (`SilentlyContinue`, `2>/dev/null`) AND missing error handling (no `try/catch`, no `-ErrorAction`, bare `Get-Content` on untrusted input). Pattern matching finds suppressions; "what happens if this fails?" finds gaps.
- **PSO: Dual-script rule** -- Every setup script gets both `.sh` and `.ps1` with OS guards. Shell-only scripts (no `.ps1` pair) are exceptions that must be documented in `.claude/rules/cross-platform.md` with rationale. Current exceptions: hooks (bash on all platforms by CC design) and `build-deploy.sh` (produces platform-independent output via sentinel markers).
- **PSO: Script logging** -- all deploy, setup, check and all other reusable scripts use structured logging -- `log`/`log_ok`/`log_error`/`log_warn` (bash) and `Log`/`LogOk`/`LogError`/`LogWarn` (PS1). Never suggest, plan nor implement re-usable scripts without structured logging
- **PSO: Sub-agent execution for large plans** -- Plans modifying 3+ code files (or any shared library) must use the sub-agent execution pattern: verbatim code in plan, error-handling audit per block, fresh sub-agent per batch with rules injected, main agent verification between batches. See `.claude/rules/plan-execution.md`.
