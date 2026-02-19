# AI Tooling Hub

Jose's cross-machine scaffolding for Claude Code, Cursor, and MCP across Windows and macOS.

## Project Structure

```
ai-tooling/
├── .claude/rules/       # Claude Code project rules (modular)
├── .cursor/rules/       # Cursor rules (.mdc format)
│   ├── general.mdc      #   Identity, code style
│   ├── sources-of-truth.mdc  # Protected files review gate
│   ├── tool-lifecycle.mdc     # Phase 2 gate for new tools
│   ├── cross-platform.mdc    # Dual-script, OS guards, PS 5.1
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

## Git Identity

- Name: `Jose`
- Email: `jose@nobul.tech`

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

# Deploy to an endpoint (no repo needed -- run from deploy/)
# macOS/Linux:
bash deploy/setup-user-claude.sh
# Windows (PowerShell):
# .\deploy\setup-user-claude.ps1

# Clipboard to Markdown (requires pandoc; optional: claude CLI for auto-naming)
clip2md                        # Auto-name via AI: 250324-garcia-budget.md
clip2md meeting-notes          # Explicit name: meeting-notes.md
```

## Cross-Platform Paths

| Resource | Windows | macOS |
|----------|---------|-------|
| This repo | `C:\repos\ai-tooling` | `~/repos/ai-tooling` |
| User CLAUDE.md | `~/.claude/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| Shared config | `shared/claude-shared.md` (in repo) | `shared/claude-shared.md` (in repo) |

## Key Decisions

- **Marker** is the preferred PDF-to-markdown converter
- This directory is the **"home base"** for general/cross-project AI conversations
- Session notes are ephemeral; durable knowledge goes in CLAUDE.md or reference/ docs (auto-memory is local to each machine, not shared)
- Shared preferences live in `shared/claude-shared.md`, embedded into deploy scripts by `build-deploy.sh`
- `deploy/` scripts are self-contained (zero dependencies beyond bash/PowerShell) -- MDM-ready
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
- **Tool lifecycle entries require 4 fields**: Platform Status, Concurrency, Post-Install Config, Dependencies -- see `reference/tool-evaluation-criteria.md`
- **Documentation standards**: RELEASE_NOTES format, version numbering, ROADMAP format, and reference doc threshold are codified in `.claude/rules/documentation-standards.md`

## Code Conventions

- Python 3.10+, type hints, `argparse` for CLI, `pathlib.Path` over `os.path`
- Scripts (this repo): provide both `.ps1` and `.sh` variants since this repo is cross-platform
- Script logging: all setup scripts use structured logging — `log`/`log_ok`/`log_error`/`log_warn` (bash) and `Log`/`LogOk`/`LogError`/`LogWarn` (PS1). Full conventions in `.claude/rules/script-standards.md`. Gold standard: `scripts/setup-user-mcp.sh/.ps1`
- Keep this file under 200 lines; use `@reference/` imports for detail

### Windows dispatch in `aitools` (bash)

Every setup script has an OS guard that rejects the wrong platform. The bash `aitools` runs in Git Bash on Windows, so **any code path that calls `.sh` setup scripts must also handle Windows by calling `.ps1` via `powershell.exe`**. This pattern exists in `deploy_configs()` and the `install` command — check both when adding new flows.

Pattern: `case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) powershell.exe -File ... ;; *) bash ... ;; esac`

The PS1 `aitools.ps1` mirrors each bash command. When adding a command to one, add it to both.

@reference/claude-code-practices.md
@reference/claude-code-windows-shell.md
@reference/cursor-practices.md
@reference/tool-evaluation-criteria.md
