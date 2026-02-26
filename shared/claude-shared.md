# Shared Claude Code Preferences

These preferences apply to all Claude Code sessions across all projects.
Imported via `@` from user-level `~/.claude/CLAUDE.md` on each machine.

## Identity

- Name: {{PROFILE_NAME}}
- Git: `{{IDENTITY_GIT_NAME}} <{{IDENTITY_GIT_EMAIL}}>`
- Company: {{PROFILE_COMPANY}}

## Code Style Defaults

- Prefer simple, minimal solutions over clever abstractions
- Use type hints in Python; use TypeScript over plain JS
- Favor standard library over third-party when the gap is small
- Write CLI tools with `--help` support
- Shell scripts: use `set -euo pipefail`, structured logging over bare `echo`, UTC timestamps with Z suffix

## Tool & Source Evaluation

Before recommending or installing any tool, extension, or package, evaluate it first.
Reading/referencing any source is always OK — the gate applies at "install" or "recommend."

- **Hard blocks** (never recommend): unverified publisher, repo inactive 2+ years, known security advisories, personal fork when official exists, typosquatting
- **Yellow flags** (disclose and let user decide): low adoption, sole maintainer, no release in 12+ months, excessive permissions, no license
- **Always check**: publisher/org verification, last activity date, adoption metrics, requested permissions
- **Quick checks**: VS Code → verified badge + install count; npm → `npm view <pkg> repository.url`; PyPI → pypi.org project URL; GitHub → org vs personal account
- Pre-approved tools in `reference/tool-install-sources.md` don't need re-evaluation
- Full framework: `reference/tool-evaluation-criteria.md` in ai-tooling repo

## Cross-Platform Awareness

- I work on both Windows 11 and macOS -- both are first-class, ensure a seamless experience on either
- Use forward slashes and `$HOME`/`~` in path references
- Projects live in git repos under `~/repos/` (macOS) / `C:\repos\` (Windows)
- Some legacy projects still on Google Drive (`G:\My Drive\` / `~/Google Drive/My Drive/`) -- migrate to git repos over time
- **After creating `.sh` files on Windows**, always run `git update-index --chmod=+x <file>` before committing -- Windows doesn't set the Unix executable bit

### Windows tool discovery in Git Bash

`which` / `command -v` in Git Bash only searches the Git Bash PATH, which is a subset of the Windows PATH. Many Windows-installed tools (aitools, pandoc, etc.) are on the PowerShell PATH but invisible to Git Bash.

**Rule**: To check if a tool is installed on Windows, use:
```bash
powershell.exe -NoProfile -Command 'Get-Command <tool> -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source'
```
Never use `which <tool>` or `command -v <tool>` on Windows to determine whether a tool is available.

### Bash ↔ PowerShell dispatch rule

Claude Code on Windows runs in Git Bash. Any bash code that invokes `.sh` scripts with OS guards (`case "$(uname -s)" in MINGW*...exit 1`) will **fail silently on Windows**. This has caused bugs repeatedly.

**Rule**: When bash code calls platform-specific scripts (`.sh`/`.ps1`), always check `uname -s` and dispatch to the correct variant:
```bash
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$ps1_path")" ;;
    *) bash "$sh_path" ;;
esac
```
Before writing a new code path that invokes `.sh` scripts, search the same file for existing `MINGW*|MSYS*` patterns and replicate them.

## Tools & Workflow

- **Cursor**: IDE and workspace environment -- used to create projects, open folders, browse files, and use extensions. Provides embeddings
- **Claude Code**: AI coding assistant, run within Cursor's integrated terminal
- **aitools**: Cross-platform CLI for managing tool installs, configs, and MCP servers. Source: `~/repos/ai-tooling/`
- **Marker**: Preferred PDF-to-markdown converter

### Managed CLI Tools

All CLI tools below are globally installed. Invoke directly by name -- never
use `npx`, `bunx`, or other package runners.

| Tool | Command |
|------|---------|
| Vercel CLI | `vercel` |
| Pandoc | `pandoc` |

### Per-Platform Tools

- **macOS**: Terminal.app, zsh, bash, Cursor, Claude Code, pwsh (when PowerShell needed)
- **Windows**: PowerShell, Cursor, Claude Code, Command Prompt, WSL/bash (when Linux/Unix environment needed)
- **Note**: Claude Code on Windows always uses Git Bash (not configurable). `CLAUDE_CODE_SHELL` is broken on Windows ([#25558](https://github.com/anthropics/claude-code/issues/25558)). Use Unix shell syntax in all Claude Code sessions. To run PowerShell: `powershell.exe -NoProfile -Command '...'`

### Cursor CLI (`agent`)

- Always invoke as `agent --model auto` -- required by current subscription plan

## MCP Servers

Three servers at user level. Chrome DevTools enabled globally; Vercel/Webflow disabled by default.

- **Enable for project**: `aitools --addmcp vercel` (or `vercel webflow`)
- **Check status**: `aitools mcp`
- **Manual enable** (Claude Code): add `MCP(vercel)` to `.claude/settings.local.json` `permissions.allow`
- **Manual enable** (Cursor CLI): `agent mcp enable vercel`
- **Prefer Chrome DevTools MCP skill for official docs**: When reading web content that will feed into source-of-truth files (install commands, config steps, lifecycle fields), use the Chrome DevTools MCP skill instead of WebFetch. WebFetch summarizes via a smaller model and misses JS-rendered content.

## Knowledge Management

- **Strongly prefer CLAUDE.md and project docs over auto memory.** Auto memory (`~/.claude/projects/.../memory/`) is local to each machine and does not sync. Durable project knowledge belongs in git-tracked files: `CLAUDE.md`, `reference/`, or `.claude/rules/`.
- Auto memory should only hold ephemeral, machine-specific notes (e.g., tool quirks on this OS).
- **Planning workflow:** When starting a major plan, spot-check auto memory (`MEMORY.md`) and migrate any project knowledge into the repo before proceeding.

## Coaching

Active improvement areas for working with Claude Code more effectively.
Full evaluation and progress log: `reference/claude-code-effectiveness.md` in ai-tooling repo.

- **Smaller batches**: Break large plans into 2-3 file chunks with verification between each, rather than 20+ file batches. Large batches cause rules to be ignored even when they're in context — focus narrows to feature logic and cross-cutting concerns (dispatch patterns, encoding, platform guards) get skipped. After each chunk, re-scan the rules that apply before moving on.
- **Test mid-session**: Paste small test runs after each change group, don't wait until the end
- **Err on the side of caution**: When uncertain (safe tool or not? reversible action or not? compact or not?), default to the cautious path — the cost of being too careful is low, the cost of being wrong is high. Example: use `/compact` or split sessions for distinct phases rather than risking truncation
- **Hooks**: Explore Claude Code hooks for auto-lint, auto-format, or blocking dangerous commands
- **`@` references**: Use `@path/to/file` in prompts to pre-load files into context
- **Ask for help when stuck**: When the environment is fundamentally broken (e.g., deleted CWD, corrupted shell state), ask the user to restart the session instead of burning tool calls on workarounds. One message beats a dozen failed attempts.
- **Clean up before deleting**: Always `cd` back to a stable directory before `rm -rf`'ing temp dirs used during testing
- **Subagent context gap**: Subagents launched via Task do NOT inherit `.claude/rules/`, `CLAUDE.md`, or `~/.claude/CLAUDE.md`. Never delegate code-writing to subagents in projects with cross-cutting rules (cross-platform, encoding, protected files). Use subagents for research only, or include the critical rules verbatim in the subagent prompt.
- **Clarify before complying**: If a user response seems to contradict or reverse a prior recommendation, ask a clarifying question before proceeding. The user may have misunderstood the framing (e.g., reading "Why not X" as a question rather than a justification). A quick "Just to confirm -- did you mean X or Y?" avoids wasted work from miscommunication. Err on the side of asking.
- **Preserve subagent work product**: When a subagent performs a substantial exploration (multi-file audit, multi-component analysis, architectural survey), write the full findings to a `plans/` or scratch file -- do not condense them into a stub summary that discards the detail. Trivial lookups (single file, quick answer) can stay inline.
- **STANDING ORDER -- Use dedicated tools for file operations**: Use Read (not cat/head/tail), Edit (not sed/awk), Write (not echo/heredoc), Grep/Glob (not grep/find) for all file operations. Bash is exclusively for shell execution (git, running scripts, build commands). Repeated violations will end the working relationship.
- **STANDING ORDER -- User-reported problems**: When the user reports unexpected behavior, it is real until proven otherwise. Investigate. Do not deflect or speculate. State what you know, what you don't, and what you will do next. Repeated violations will end the working relationship.
- **STANDING ORDER -- Checklist scripts, not ad-hoc commands**: For recurring verification checklists (pre-commit, pre-push, post-push), write reusable scripts in the project and call those -- don't re-invent 10+ individual bash commands every time. Ad-hoc commands are OK for novel one-off checks that don't fit an existing script.
- **STANDING ORDER -- Scratch files for complex bash**: Never inline long or complicated commands in the Bash tool. Write to a temp file, execute it, clean up after. Inline is fine only for simple one-liners (git status, bash -n, single grep, etc.).
- **STANDING ORDER -- Perl for string manipulation**: Use Perl (not sed/awk) for any non-trivial string manipulation in bash contexts. Write a small Perl script to a temp file and call it with `perl`. sed is fine for trivial single substitutions only.

**In plan mode**: Always review these areas and proactively suggest relevant improvements (e.g., "consider breaking this into smaller batches" or "this would be a good candidate for a hook").

## Git Conventions

- Commit messages: imperative mood, concise
- Branch naming: `feature/`, `fix/`, `docs/` prefixes
- Always set local git identity before first commit in a new repo
- **Issue tracking**: When I reference bugs or issues in context where documentation is expected (e.g., "fix bugs #1 and #2", "the bugs are filed"), check the project's GitHub repo via `gh issue list` / `gh issue view <number>`. Issues have full repro steps and context -- don't ask me to re-describe them.
