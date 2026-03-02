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
- Tool governance lives in [`nobul-jose/aitools`](https://github.com/nobul-jose/aitools) -- pre-approved tools, evaluation framework, and lifecycle phases documented there
- When working outside aitools: open an issue on `nobul-jose/aitools` via `gh` (see [RFC 0001](https://github.com/nobul-jose/aitools/blob/main/rfcs/RFC-0001-workspace-tool-requests.md))

## Cross-Platform Awareness

- I work on both Windows 11 and macOS -- both are first-class, ensure a seamless experience on either
- Use `~/` with forward slashes on macOS, `%USERPROFILE%\` with backslashes on Windows
- Projects live in git repos under `~/repos/` (macOS) / `%USERPROFILE%\repos\` (Windows)
- Google Drive paths are auto-discovered by `aitools install` and stored in `~/.aitools/config.json` (`googleDrives` array) -- do not hardcode them
- **After creating `.sh` files on Windows**, always run `git update-index --chmod=+x <file>` before committing -- Windows doesn't set the Unix executable bit

### Windows tool discovery in Git Bash

`which` / `command -v` in Git Bash only searches the Git Bash PATH, which is a subset of the Windows PATH. Many Windows-installed tools (aitools, pandoc, etc.) are on the PowerShell PATH but invisible to Git Bash.

**Rule**: To check if a tool is installed on Windows, use:
```bash
pwsh -NoProfile -Command 'Get-Command <tool> -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source'
```
Never use `which <tool>` or `command -v <tool>` on Windows to determine whether a tool is available.

## Tools & Workflow

**aitools** (`~/repos/aitools/`) is the central CLI for managing tool installs, configs, and MCP servers. Long-term goal: single workflow management tool across all machines. Not there yet -- current tooling still includes Cursor, Claude Code, and others as the stack evolves.

### Managed CLI Tools

All CLI tools below are globally installed. Invoke directly by name -- never
use `npx`, `bunx`, or other package runners.

| Tool | Command |
|------|---------|
| Claude Code | `claude` |
| Cursor CLI | `agent` |
| GitHub CLI | `gh` |
| Vercel CLI | `vercel` |
| Pandoc | `pandoc` |
| Rust (cargo) | `cargo` |
| Typst | `typst` |
| pwsh | `pwsh` |

### Per-Platform Tools

- **macOS**: Terminal.app, zsh, bash, Cursor, Claude Code, pwsh (when PowerShell needed)
- **Windows**: pwsh, Cursor, Claude Code, Command Prompt, WSL/bash (when Linux/Unix environment needed)
- **Note**: Claude Code on Windows always uses Git Bash (not configurable). `CLAUDE_CODE_SHELL` is broken on Windows ([#25558](https://github.com/anthropics/claude-code/issues/25558)). Use Unix shell syntax in all Claude Code sessions. To run PowerShell: `pwsh -NoProfile -Command '...'`

## MCP Servers

Three servers at user level. Chrome DevTools enabled globally; Vercel/Webflow disabled by default.

- **Enable for project**: `aitools --addmcp vercel` (or `vercel webflow`)
- **Check status**: `aitools mcp`
- **Manual enable** (Claude Code): add `MCP(vercel)` to `.claude/settings.local.json` `permissions.allow`
- **Manual enable** (Cursor CLI): `agent mcp enable vercel`
- **Prefer chrome-devtools skill for official docs**: When reading web content that will be recorded verbatim (install commands, config steps, API references), use the chrome-devtools skill instead of WebFetch. WebFetch summarizes via a smaller model and misses JS-rendered content. WebFetch is fine for general research, blog posts, and quick fact-checks.

## Knowledge Management

- **Auto memory is disabled** via `profile.json` (`autoMemory: false`), deployed by `setup-user-hooks`. Durable knowledge belongs in git-tracked files: `CLAUDE.md`, `.claude/rules/`, or project docs.
- **Planning workflow:** When starting a major plan, check for stale auto memory files (`~/.claude/projects/.../memory/`) from before the disable and migrate any useful content into the repo.

## Coaching

Active improvement areas. UCI (User) apply everywhere; PCI (Project) apply to a specific repo.
Full evaluation and progress log: `claude/effectiveness.md` in your user repo.

- **UCI: Smaller batches** -- Break large plans into 2-3 file chunks with verification between each, rather than 20+ file batches. Large batches cause rules to be ignored even when they're in context. After each chunk, re-scan the rules that apply before moving on.
- **UCI: Test mid-session** -- Paste small test runs after each change group, don't wait until the end.
- **UCI: Err on the side of caution** -- When uncertain (safe tool or not? reversible action or not? compact or not?), default to the cautious path. The cost of being too careful is low, the cost of being wrong is high.
- **UCI: Hooks** -- Leverage Claude Code hooks beyond guardrails -- subagent context injection (PreToolUse on Agent to close the context gap), auto-format on Write/Edit, auto-test after code changes, completion notifications.
- **UCI: Ask for help when stuck** -- When the environment is fundamentally broken (e.g., deleted CWD, corrupted shell state), ask the user to restart the session instead of burning tool calls on workarounds.
- **UCI: Clean up before deleting** -- Always `cd` back to a stable directory before `rm -rf`'ing temp dirs used during testing.
- **UCI: Subagent context gap** -- Subagents launched via Task do NOT inherit project rules or CLAUDE.md files. Prefer subagents for research; for code-writing in projects with cross-cutting rules, consider including critical rules in the subagent prompt.
- **UCI: Clarify before complying** -- If a user response seems to contradict or reverse a prior recommendation, ask a clarifying question before proceeding. A quick "Just to confirm -- did you mean X or Y?" avoids wasted work from miscommunication.
- **UCI: Preserve subagent work product** -- When a subagent performs a substantial exploration (multi-file audit, multi-component analysis), write the full findings to a scratch file -- do not condense them into a stub summary that discards the detail. Trivial lookups can stay inline.
- **UCI: Verify subagent audit results** -- When subagents perform audits (code review, pattern scanning, compliance checks), spot-check their results. Read at least one file reported "clean" and verify. Treat subagent results as leads, not conclusions.
### Standing Orders

Standing orders are non-negotiable rules. USO (User) apply everywhere; PSO (Project) apply to a specific repo.
Repeated violations will end the working relationship.

- **USO: Dedicated tools for file ops** -- Use Read/Edit/Write/Grep/Glob for file operations. Bash is for shell execution only (git, scripts, build commands).
- **USO: Investigate user-reported problems** -- When the user reports unexpected behavior, it is real. Investigate first; do not deflect or speculate.
- **USO: Scratch files for complex scripting** -- Never inline long commands in the Bash tool. Write a temp file (bash/pwsh/perl/other), execute, clean up. Inline only for simple one-liners.
- **USO: Perl for string manipulation** -- Use Perl (not sed/awk) for non-trivial string manipulation. sed is fine for trivial single substitutions only.
- **USO: No silent failures in reusable code** -- In any code meant to run more than once (scripts, services, hooks, CLI tools), never suppress errors without checking the result and logging/failing. `-ErrorAction SilentlyContinue`, `2>/dev/null`, `|| true`, `try/catch` are fine IF the result is immediately checked. Command-existence checks with explicit fallback are exempt. Applies when the project has a logging framework, is production code, or has reliability expectations. Does NOT apply to scratch/temp/throwaway work.
- **USO: Simple Bash commands only** -- Never use `$(...)`, backticks, `&&`, `||`, `;`, or glob patterns (`*`, `?`) in destructive commands (`rm`) in Bash tool calls -- these trigger permission prompts that block the user. For commit messages, write to a temp file with Write and use `git commit -F`. For sequential commands, make separate Bash calls. For cleanup, write a cleanup script and execute it. Pipelines (`|`) are OK.

**In plan mode**: Always review these areas and proactively suggest relevant improvements (e.g., "consider breaking this into smaller batches" or "this would be a good candidate for a hook").

## Git Conventions

- Commit messages: imperative mood, concise
- Branch naming: `feature/`, `fix/`, `docs/` prefixes
- Always set local git identity before first commit in a new repo
- **Issue tracking**: When I reference bugs or issues in context where documentation is expected (e.g., "fix bugs #1 and #2", "the bugs are filed"), check the project's GitHub repo via `gh issue list` / `gh issue view <number>`. Issues have full repro steps and context -- don't ask me to re-describe them.
