# Claude Code Version Dependencies

Registry of version-dependent workarounds, behaviors, and assumptions in this repo.

- **Current version**: 2.1.59
- **Baseline version**: 2.1.51 (2026-02-16) -- version when most workarounds were written

## How to use

When Claude Code is upgraded:

1. Update "Current version" above
2. Walk CRITICAL items: check upstream issues (are they still open?)
3. Walk HIGH items if the version bump is major (e.g., 2.1 -> 2.2 or 3.0)
4. Update "Last verified" for any re-checked items
5. If a workaround is no longer needed, remove it from the codebase and this registry

Post-push checklist #20 triggers this review automatically.

---

## CRITICAL -- Would break core scripts if behavior changes

| # | Item | Baseline | Last verified | Files | Upstream |
|---|------|----------|---------------|-------|----------|
| 1 | Windows shell hardcoded to Git Bash (CLAUDE_CODE_SHELL broken) | 2.1.51 | 2.1.59 (2026-02-26) | `reference/claude-code-windows-shell.md`, `.claude/rules/cross-platform.md`, `CLAUDE.md` (Windows dispatch) | [#7490](https://github.com/anthropics/claude-code/issues/7490), [#25558](https://github.com/anthropics/claude-code/issues/25558), [#5049](https://github.com/anthropics/claude-code/issues/5049), [#16225](https://github.com/anthropics/claude-code/issues/16225), [#20453](https://github.com/anthropics/claude-code/issues/20453) |
| 2 | SessionEnd hook API contract (session_id, cwd, transcript_path on stdin) | 2.1.51 | 2.1.59 (2026-02-26) | `shared/hooks/session-archive.sh`, `reference/user-repo.md` | -- |

## NOTE -- Not a CC dependency

| # | Item | Note | Files |
|---|------|------|-------|
| 3 | Chrome DevTools MCP `--isolated` flag | Personal preference for concurrent sessions, not tied to CC versions | `scripts/setup-user-mcp.sh/.ps1`, `.claude/rules/post-push.md` |

## HIGH -- Would break workflows or produce wrong results

| # | Item | Baseline | Last verified | Files | Upstream |
|---|------|----------|---------------|-------|----------|
| 4 | Session path sanitization (CWD -> JSONL directory name uses `-` replacement) | 2.1.51 | 2.1.51 | `reference/claude-code-practices.md`, `shared/hooks/session-archive.sh` | -- |
| 5 | Subagent context gap (rules/CLAUDE.md not inherited by Task subagents) | 2.1.51 | 2.1.51 | `shared/claude-shared.md` (coaching items) | -- |
| 6 | CLAUDE.md hierarchy & merge behavior (5 levels, more-specific wins) | 2.1.51 | 2.1.51 | `reference/claude-code-practices.md`, `scripts/setup-user-claude.sh/.ps1` | -- |
| 7 | Session management commands (claude -c, --resume, /resume, /rename) | 2.1.51 | 2.1.51 | `reference/claude-code-practices.md` | -- |
| 8 | Hook execution context (hooks run in bash, not configurable) | 2.1.51 | 2.1.51 | `shared/hooks/session-archive.sh`, `scripts/setup-user-hooks.sh` | -- |
| 9 | Coaching items tied to CC capabilities (subagent gap, auto-memory locality) | 2.1.51 | 2.1.51 | `shared/claude-shared.md` | -- |

## MEDIUM -- Affects developer experience or specific features

| # | Item | Baseline | Last verified | Files | Upstream |
|---|------|----------|---------------|-------|----------|
| 10 | Write tool produces CRLF on macOS | 2.1.51 | 2.1.51 | `.claude/rules/pre-commit.md`, auto-memory `MEMORY.md` | -- |
| 11 | PATH limitations (npm global bin not always visible to CC) | 2.1.51 | 2.1.51 | `scripts/setup-user-mcp.sh` (node fallback for `claude mcp add`) | [#5202](https://github.com/anthropics/claude-code/issues/5202), [#3838](https://github.com/anthropics/claude-code/issues/3838) |
| 12 | PowerShell-from-Bash quoting patterns (single-quote outer, double-quote inner) | 2.1.51 | 2.1.51 | `reference/claude-code-windows-shell.md` | -- |
| 13 | Cursor Agent CLI rule sources (does NOT read ~/.claude/CLAUDE.md) | 2.1.51 | 2.1.51 | `reference/cursor-practices.md` | -- |

## LOW -- Architectural constraints unlikely to change soon

| # | Item | Baseline | Last verified | Files | Upstream |
|---|------|----------|---------------|-------|----------|
| 14 | Auto-memory locality (machine-specific, does not sync) | 2.1.51 | 2.1.51 | `shared/claude-shared.md`, auto-memory `MEMORY.md` | -- |
| 15 | Session sync not possible (CLI sessions are local per machine + directory) | 2.1.51 | 2.1.51 | `reference/claude-code-practices.md` | -- |
| 16 | Session storage internals (JSONL under ~/.claude/projects/) | 2.1.51 | 2.1.51 | `reference/claude-code-practices.md`, `shared/hooks/session-archive.sh` | -- |
| 17 | JSONL transcript fields (type, cwd, sessionId) | 2.1.51 | 2.1.51 | `reference/claude-code-practices.md`, `shared/hooks/session-archive.sh` | -- |
