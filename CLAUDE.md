# AI Tooling Hub

**Mission**: Cross-platform tool lifecycle management, configuration, and AI
context orchestration for developers who work across Windows, macOS, and Linux.

One CLI that installs, configures, and maintains all managed tools with native
platform support (PowerShell on Windows, bash on macOS/Linux), structured
logging, interactive deployment review, and drift detection. Multi-user via
dotprofile repos. MDM-ready via self-contained deploy scripts. Tools and
dependencies are managed using platform-native best practices — evaluation
criteria prioritize delivering the best developer experience on each platform,
not artificial 1:1 parity.

## Design Principles

- **Three-layer governance**: Prevention (rules in context stop issues from being created), Detection (hooks fire in real-time during sessions), Audit (skills/subagents provide deep review on demand). Each layer catches what the previous missed. Applies to both governance and USO/PSO compliance.
- **Ambiguity is a defect**: If a rule, reference, or plan can be read two ways, that's a bug. Surface it immediately — file via `/gap` skill per `.claude/rules/gap-governance.md`. Every session has this duty.
- **Full context, not token budgeting**: Use the full context window. Launch subagents with complete rules. Load reference files generously. Keep CLAUDE.md and rules succinct for *clarity*, not to save tokens. Use skills, reference files, and hooks for depth.
- **Specs vs state**: Rules and references define what SHOULD be. The `/gap` skill tracks what ISN'T yet. Never describe a feature as "working" if it hasn't fired in production. See `.claude/rules/gap-governance.md`.
- **Separate tool harnesses**: Claude Code (`.claude/rules/`, CLAUDE.md) and Cursor (`.cursor/rules/`, agents.md) serve different purposes and are managed independently. No parity requirement.
- **End users are developers**: Every aitools user benefits from understanding internals. No "dumb user" persona. Skills, docs, and menus assume developer familiarity. Users may work on one, two, or all three platforms — aitools supports all combinations. Cross-platform coverage in skills and docs is factual (all platforms documented), not prescriptive (don't assume every user cares about every platform).
- **Skills as enablement**: Every managed tool, dependency, and repeatable process gets a skill. User-level skills (`shared/skills/` → `~/.claude/skills/`) cover managed tools and project-agnostic patterns. Project-level skills (`.claude/skills/`) cover repo-specific frameworks. Skills are process implementations governed by rules. Every skill with auto-trigger behavior requires three artifacts: the skill itself, a trigger directive in its governing rule (states WHEN to invoke), and a detection hook spec (catches when the process is bypassed). The rule governs; the skill implements; the hook enforces. See `plans/governance-and-compliance-framework.md` for placement criteria and `.claude/rules/governed-data-access.md` for the access pattern.
- **Document intent**: Every markdown file, every major section that could be misread in isolation, and every code file must state its intent: purpose (what it exists to deliver), scope (what's covered and explicitly excluded), and audience (who consumes it). A file or section without intent is ambiguous by definition. In markdown, intent appears as an `**Intent**:` block or opening paragraph. In code, intent appears as a header comment block. New files must include intent; existing files are backfilled incrementally. Intent statements are a protected activity — draft and present for user approval before writing. See `@.claude/rules/sources-of-truth.md`.
## Project Structure

```
aitools/
├── .claude/
│   ├── commands/        # Claude Code slash commands
│   └── rules/           # Claude Code project rules (modular)
│   └── skills/          # Project-level skill definitions (auto-discovered)
├── .cursor/rules/       # Cursor rules (.mdc format)
├── shared/              # Source of truth for configs
│   ├── claude-shared.md #   → embedded into deploy scripts by build
│   ├── cursor-rules/    # Template rules + User Rules source of truth
│   ├── hooks/           # Claude Code hooks
│   ├── mcp/             # MCP server configuration docs
│   ├── shell/           # Shell aliases (bash/zsh + PowerShell)
│   └── skills/          # User-level skill definitions (deployed to ~/.claude/skills/)
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

`build-deploy.sh` generates self-contained scripts in `deploy/` (`.sh` + `.ps1` pairs) -- config scripts (`setup-user-claude`, `-mcp`, `-skills`, `-hooks`, `setup-cursor-ide-mcp`, `setup-user-cursor`) and tool scripts (`setup-vercelcli`, `-pandoc`, `-rust`, `-typst`, `-gh-cli`, `-python`, `-uv`, `-modal`, `-go`, `-datadog`, `-perl`). Shared helpers from `scripts/aitools-lib.sh/.ps1` are inlined into deploy scripts at build time -- deploy scripts have no runtime dependency on the repo.

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
- The `/tool-registry` skill is the access point for tool install commands -- always check via the skill before modifying installer scripts
- Install methods and `BuildPrereqs` must be derived from official tool documentation via the `/tool-eval` skill -- never chosen from assumption or memory
- **`claude mcp add` and nested sessions**: `claude mcp add` fails inside nested Claude Code sessions (`CLAUDECODE` env var blocks it). `--addmcp` avoids this by writing `.claude/settings.local.json` directly via Node.js. `setup-user-mcp.sh/.ps1` unsets the var as a workaround.
- AI CLI invocations in scripts use `invoke_ai`/`Invoke-AI` (aitools-lib) with explicit speed/permission tiers. Prompts follow the structured pattern and are evaluated per `.claude/rules/agentic-standards.md`
- **deploy/ lifecycle**: `deploy/` is fully generated by `build-deploy.sh` and
  reset to HEAD before every `aitools` pull. Uncommitted deploy/ changes are
  ephemeral. See `.claude/rules/git-safety.md`
- **Governed data changes**: When a governed file's schema changes, update the governing skill first (so it documents the new schema), then invoke the skill to make the data change. Never change governed data without the skill reflecting the current schema. See `@.claude/rules/governed-data-access.md`

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
- **PSO: Fail, don't mask** -- Never mask broken states with fallbacks. If a managed dependency (tool, config, path) is missing or misconfigured, that is a failure -- surface it via `log_error` / `LogError` and exit. Do not silently fall back to bundled, unmanaged, or degraded alternatives that allow the script to continue in a broken state. Remediate the root cause (e.g., run `aitools install`) before continuing.
