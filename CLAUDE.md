# AI Tooling Hub

Jose's cross-machine scaffolding for Claude Code, Cursor, and MCP across Windows and macOS.

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
├── deploy/              # Self-contained scripts for MDM (generated)
├── plans/               # Detailed plans for roadmap items
├── reference/           # Setup notes and how-tos
├── rfcs/                # Design proposals
├── RELEASE_NOTES.md
└── ROADMAP.md
```

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

# Verification checklists (replaces ad-hoc commands)
# macOS/Linux:
bash scripts/check-pre-commit.sh       # or --fix (auto-fix line endings, exec bits, build)
bash scripts/check-pre-push.sh         # read-only
bash scripts/check-post-push.sh        # or --extensive (all 20 steps)
# Windows (PowerShell):
.\scripts\check-pre-commit.ps1         # or -Fix
.\scripts\check-pre-push.ps1           # read-only
.\scripts\check-post-push.ps1          # or -Extensive (all 20 steps)

# Clipboard to Markdown (requires pandoc; optional: claude CLI for auto-naming)
clip2md                        # Auto-name via AI: 250324-garcia-budget.md
clip2md meeting-notes          # Explicit name: meeting-notes.md
```

### Deploy using MDM

`build-deploy.sh` generates self-contained scripts in `deploy/` (`.sh` + `.ps1` pairs) -- config scripts (`setup-user-claude`, `-mcp`, `-hooks`, `setup-cursor-mcp`, `setup-user-cursor`) and tool scripts (`setup-vercelcli`, `-pandoc`, `-rust`, `-typst`). No repo needed -- run directly on any endpoint.

## Cross-Platform Paths

| Resource | Windows | macOS |
|----------|---------|-------|
| This repo | `%USERPROFILE%\repos\aitools` | `~/repos/aitools` |
| User CLAUDE.md | `%USERPROFILE%\.claude\CLAUDE.md` | `~/.claude/CLAUDE.md` |
| Shared config | `shared\claude-shared.md` (in repo) | `shared/claude-shared.md` (in repo) |
| User repo | `%USERPROFILE%\repos\aitools-<username>` | `~/repos/aitools-<username>` |

## Key Decisions

- This directory is the **"home base"** for general/cross-project AI conversations
- Shared preferences live in `shared/claude-shared.md` (template). User's personal copy lives in `<userRepoPath>/claude/CLAUDE.md` (syncs across machines). `scripts/setup-user-claude.sh/.ps1` reads from user repo first (fallback: shared template), interpolates `{{PLACEHOLDER}}` tokens from `profile.json`, and writes to `~/.claude/CLAUDE.md`. `deploy/` scripts use build-time embedded content (self-contained).
- `reference/tool-install-sources.md` is the source of truth for install commands -- always check before modifying installer scripts
- **`claude mcp add` and nested sessions**: `claude mcp add` fails inside nested Claude Code sessions (`CLAUDECODE` env var blocks it). `--addmcp` avoids this by writing `.claude/settings.local.json` directly via Node.js. `setup-user-mcp.sh/.ps1` unsets the var as a workaround.

## Code Conventions

- Python 3.10+, type hints, `argparse` for CLI, `pathlib.Path` over `os.path`
- Scripts (this repo): provide both `.ps1` and `.sh` variants since this repo is cross-platform
- Script logging: all setup scripts use structured logging -- `log`/`log_ok`/`log_error`/`log_warn` (bash) and `Log`/`LogOk`/`LogError`/`LogWarn` (PS1)
- Keep this file under 200 lines

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
- **PSO: Equal platform visibility** -- When showing usage examples, commands, or invocations in docs, always show both macOS/bash and Windows/PowerShell. Never abbreviate one platform as "same but .ps1" or similar.
