---
name: aitool-ops
description: "Read-only reference card for tool-ops operational knowledge —
  deny rules, hooks, CC version dependencies, doc access methods, governance
  modes. Available in ANY repo. Use when checking tool behavior, deny rules,
  hook behavior, CC version deps, or doc access methods."
---

## Intent

**Purpose**: Provide tool-ops operational knowledge to any agent in
any repo — deny rules, hooks, CC version dependencies, doc access
methods, governance modes, and known behavioral gaps. This is a
read-only reference card derived from the aitools repo's tool-ops
sources. **Scope**: Read-only lookups only. NOT writes to
tool-ops.json (use `/tool-ops` in the aitools repo for that). NOT
tool evaluation (use `/tool-eval`). NOT tool install/version
management (use `/tool-registry`). NOT incident filing (use
`/incident`). **Audience**: Any agent in any repo needing to check
tool operational behavior before making assumptions.

## When to use

Invoke `/aitool-ops` when ANY of these arise:

- Checking deny rules (what permission patterns are blocked and why)
- Checking hook behavior (what hooks fire, their events and matchers)
- Checking CC version dependencies (what breaks if CC upgrades)
- Checking doc access methods (chrome-devtools vs WebFetch)
- Checking governance modes (audit vs active per category)
- Checking subagent limitations (cross-repo access, SendMessage gap)
- Checking session management commands
- Checking hook portability rules (BSD vs GNU command divergences)
- User says `/aitool-ops` or asks about tool operations

## What this does NOT do

- Does NOT write to tool-ops.json — use `/tool-ops` in the aitools
  repo for registry writes
- Does NOT evaluate tools for adoption — use `/tool-eval`
- Does NOT manage the tool install registry — use `/tool-registry`
- Does NOT file incidents — use `/incident`

## Staleness warning

This skill was generated from `tool-ops.json` and
`tool-ops-claude-code.md` in the aitools repo. If the source has been
updated since the last `aitools install`, this content may be stale.
Run `aitools` to refresh.

Future enhancement: `build-deploy.sh` could auto-generate this skill's
content from the source files at build time, keeping it always current.
For now, the content is manually authored.

---

## Claude Code — Deny Rules

| ID | Permission Pattern | Hook | Reason |
|----|-------------------|------|--------|
| cc-deny-guide-subagent | `Agent(claude-code-guide)` | `block-claude-code-guide.sh` | Haiku model returns inaccurate schema — caused incident where all hooks were disabled (#34730) |

The deny rule blocks the built-in guide subagent and injects corrective
harness context instead.

## Claude Code — Hooks

| Event | Matcher | Script | Purpose |
|-------|---------|--------|---------|
| PreToolUse | Agent | `block-claude-code-guide.sh` | Deny built-in guide subagent, inject corrective harness context |

Additional hooks deployed by the harness (not in tool-ops.json but
part of the operational landscape):

| Event | Script | Purpose |
|-------|--------|---------|
| SessionStart | `scratch-init.sh` | Create session scratch directory |
| SessionEnd | `session-archive.sh` | Archive session transcript to user repo |
| SessionEnd | `harvest-session.sh` | Classify and harvest scratch artifacts |
| PostToolUse (Write/Edit) | `sh-file-fixup.sh` | Fix CRLF line endings and chmod +x on .sh files |
| PreToolUse (Bash git) | `standing-order-guard.sh` | Checklist reminder for git operations |
| Stop | `surfacing-duty-stop.sh` | Periodic surfacing duty reminder |
| Stop | `estimate-refresh-stop.sh` | Running estimate refresh reminder |
| PreToolUse (Read glossary.json) | `glossary-skill-guard.sh` | Redirect direct JSON access to /glossary skill |
| PreToolUse (Agent) | `block-claude-code-guide.sh` | Block guide subagent + context injection |
| SessionStart | `tool-ops-session-audit.sh` | Audit tool-ops coverage at session start |
| SessionStart | `dashboard-serve.sh` | Start dashboard server if running estimate exists |
| SessionStart | `harness-db-sessionstart.sh` | Record session start in harness DB |
| SessionEnd | `harness-db-sessionend.sh` | Record session end in harness DB |

## Claude Code — Governance Modes

All categories are currently in **audit** mode (observe and log, do
not enforce):

| Category | Mode | What it covers |
|----------|------|----------------|
| denyRules | audit | Permission pattern blocking |
| hooks | audit | Hook fire/fail tracking |
| contextInjection | audit | Doc URL injection into subagents |
| kpis | audit | Operational metrics collection |
| versionDeps | audit | Version dependency drift detection |
| verifications | audit | Hook and deny rule testing |

Promotion from audit to active requires zero-drift telemetry evidence
via the `/tool-ops` skill in the aitools repo.

## Claude Code — Doc Access

**Method**: chrome-devtools skill navigates to
`https://code.claude.com/docs/en/*.md`

**Key pages**: hooks.md, permissions.md, sub-agents.md, settings.md,
mcp.md

**Quick reference for hook types**:
- `command` requires `command` field
- `prompt` requires `prompt` field (static string only)
- `http` requires `url` field
- `agent` requires `prompt` field

**Rule**: When reading web content that will be recorded verbatim
(install commands, config steps, API references), use the
chrome-devtools skill instead of WebFetch. WebFetch summarizes via a
smaller model and misses JS-rendered content. WebFetch is fine for
general research, blog posts, and quick fact-checks.

## Claude Code — Version Dependencies (CRITICAL)

Items that would break core scripts if CC behavior changes.

| # | Item | Baseline | Last Verified |
|---|------|----------|---------------|
| 1 | Windows shell hardcoded to Git Bash (`CLAUDE_CODE_SHELL` broken) | 2.1.51 | 2.1.74 |
| 2 | SessionEnd hook API contract (session_id, cwd, transcript_path on stdin) | 2.1.51 | 2.1.74 |

**Impact of #1**: CC on Windows always uses Git Bash. `CLAUDE_CODE_SHELL`
is silently ignored. All Windows dispatch must use `pwsh -File` for PS1
scripts. Upstream: #7490, #25558, #5049, #16225, #20453.

**Impact of #2**: Session archive hook parses stdin JSON. If the contract
changes, session archiving breaks silently.

## Claude Code — Version Dependencies (HIGH)

Items that would break workflows or produce wrong results.

| # | Item | Baseline | Last Verified |
|---|------|----------|---------------|
| 4 | Session path sanitization (CWD uses `-` replacement, lossy for hyphenated names) | 2.1.51 | 2.1.51 |
| 5 | Subagent context gap (rules/CLAUDE.md not inherited by Task subagents) | 2.1.51 | 2.1.74 |
| 6 | CLAUDE.md hierarchy and merge behavior (5 levels, more-specific wins) | 2.1.51 | 2.1.51 |
| 7 | Session management commands (claude -c, --resume, /resume, /rename) | 2.1.51 | 2.1.51 |
| 8 | Hook execution context (hooks run in bash or HTTP, not configurable shell) | 2.1.51 | 2.1.74 |
| 9 | Coaching items tied to CC capabilities (subagent gap, auto-memory locality) | 2.1.51 | 2.1.51 |
| 19 | `effortLevel` setting (settings.json key, defaults to medium for Opus 4.6 since 2.1.68) | 2.1.68 | 2.1.74 |
| 23 | `claude update` triggers SessionEnd hooks then cancels them (benign noise) | 2.1.81 | 2.1.81 |
| 24 | Subagent cross-repo file access restriction | 2.1.74 | 2.1.74 |
| 25 | SendMessage for agent continuation unavailable (gated behind Agent Teams flag) | 2.1.77 | 2.1.81 |

## Claude Code — Version Dependencies (MEDIUM)

| # | Item | Baseline | Last Verified |
|---|------|----------|---------------|
| 10 | Write tool produces CRLF on macOS | 2.1.51 | 2.1.51 |
| 11 | PATH limitations (npm global bin not always visible to CC) | 2.1.51 | 2.1.51 |
| 12 | PowerShell-from-Bash quoting patterns (single-quote outer, double-quote inner) | 2.1.51 | 2.1.51 |
| 13 | Cursor Agent CLI rule sources (does NOT read ~/.claude/CLAUDE.md) | 2.1.51 | 2.1.51 |
| 18 | `@file` references resolved in CLAUDE.md but NOT in `.claude/rules/*.md` | 2.1.63 | 2.1.63 |
| 20 | `InstructionsLoaded` hook event (fires after CLAUDE.md and rules load) | 2.1.68 | 2.1.74 |
| 21 | `agent_id`/`agent_type` in hook events (distinguishes main vs subagent) | 2.1.68 | 2.1.74 |

## Claude Code — Version Dependencies (LOW)

| # | Item | Baseline | Last Verified |
|---|------|----------|---------------|
| 14 | Auto-memory locality (machine-specific, does not sync) | 2.1.51 | 2.1.51 |
| 15 | Session sync not possible (CLI sessions are local per machine + directory) | 2.1.51 | 2.1.51 |
| 16 | Session storage internals (JSONL under ~/.claude/projects/) | 2.1.51 | 2.1.51 |
| 17 | JSONL transcript fields (type, cwd, sessionId) | 2.1.51 | 2.1.51 |
| 22 | `includeGitInstructions` setting (controls git context injection into system prompt) | 2.1.68 | 2.1.74 |

## Subagent Cross-Repo Access Restriction (#24)

Subagents launched via the Agent tool have restricted file access
outside the CWD repo:

- **Glob/Grep**: Denied outside CWD repo boundaries
- **Read**: Works with explicit absolute paths (even outside CWD repo)
- **Write/Edit**: Denied outside CWD repo

**Impact on delegation**: When delegating work that needs files from
another repo, include the file content in the delegation prompt
(inline via XML delimiters) rather than expecting the subagent to
read it. Alternatively, use Read with explicit paths for known
file locations.

## Agent Continuation Gap — SendMessage (#25)

Since v2.1.77, there is no working mechanism to send messages to a
previously spawned subagent:

- **Old mechanism** (`resume` parameter on Agent tool): Removed in
  v2.1.77. Had longstanding issues and was effectively non-functional
  before removal.
- **New mechanism** (`SendMessage` tool): Part of the Agent Teams
  feature set, gated behind `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`
  (disabled by default). Even with the flag enabled, reports of
  unavailability.

**Impact on delegation patterns**:

- Subagents must be fully self-contained at launch. No follow-up
  messages possible.
- The Agent tool's own return value includes `agentId` with
  instructions to use SendMessage — the model will attempt to use
  it and fail.
- Sequential delegation (launch new agent with prior agent's output)
  is the only working pattern for iterative subagent work.

**Workaround**: Include all context in the initial Agent launch
prompt. Use TaskOutput to read completed agent results. Launch new
agents for follow-up work, passing prior output as context.

Upstream: #35240, #37051, #38183

## Session Management Commands

| Command | What it does |
|---------|--------------|
| `claude -c` | Resume most recent session in current directory |
| `claude --resume` | Interactive session picker (current directory only) |
| `claude --resume "name"` | Resume a named session |
| `/resume` | Switch sessions from inside a running session |
| `/rename <name>` | Name the current session for easy recall |
| `claude --continue --fork-session` | Fork current session into a new one |

Sessions are local to each machine and tied to the directory they were
started in. They do not sync across devices.

## CLAUDE.md Hierarchy (5 levels)

| Level | Path | Scope |
|-------|------|-------|
| Managed (org/IT) | `C:\Program Files\ClaudeCode\CLAUDE.md` | All users on machine |
| User (personal global) | `~/.claude/CLAUDE.md` | You, all projects, this machine |
| Project (team) | `./CLAUDE.md` in repo root | All team members via git |
| Project (personal) | `./CLAUDE.local.md` | You only, auto-gitignored |
| Subdirectory | `./some-dir/CLAUDE.md` | Loaded on-demand when working in that dir |

All levels merge together. More specific wins on conflict.

## Hook Portability Rules

Hooks (`shared/hooks/*.sh`) run in bash on ALL platforms — macOS,
Linux, and Windows Git Bash. They must be portable across all bash
environments. Hooks cannot source `aitools-lib.sh` or `check-lib.sh`
— they are standalone deployed files.

### Known command divergences

| Command | macOS (BSD) | Linux/Git Bash (GNU) | Correct Pattern |
|---------|-------------|---------------------|-----------------|
| `stat` modification time | `stat -f %m file` | `stat -c %Y file` | `uname -s` dispatch |
| `stat` birth time | `stat -f %B file` | `stat -c %W file` (0 if unsupported) | `uname -s` dispatch |
| `stat` formatted date | `stat -f "%SB" -t "%Y-%m-%d"` | `date -d "@$(stat -c %Y)"` | `uname -s` dispatch |
| `find` formatted output | `find -printf` not available | `find -printf '%T@'` | Use `find -print0` + `stat` loop |
| `grep` Perl regex | Not available | `grep -P` | Use `perl -ne` or `grep -E` |
| `date` parsing | `date -j -f fmt` | `date -d string` | `uname -s` dispatch |

**Never use the fallback chain pattern** `stat -f %m "$file" || stat -c %Y "$file"`.
On Git Bash, GNU `stat -f` means `--file-system` (not format). It
partially succeeds with wrong multiline output, contaminating the
variable.

## Claude Code — Verification

Hook and deny rule testing uses mock-json-pipe:

```bash
echo '{"tool_name":"Agent","tool_input":{"subagent_type":"claude-code-guide"}}' | bash block-claude-code-guide.sh
# Expected: exit 0, stdout contains "permissionDecision.*deny"

echo '{"tool_name":"Agent","tool_input":{"subagent_type":"Explore"}}' | bash block-claude-code-guide.sh
# Expected: exit 0, no stdout (not blocked)
```

## Windows Shell Limitations

CC on Windows is hardcoded to Git Bash. The `CLAUDE_CODE_SHELL`
environment variable is broken (silently ignored).

**Working workarounds**:

- Run PS1 commands: `pwsh -NoProfile -Command 'Your-Command Here'`
- Run PS1 scripts: `pwsh -NoProfile -ExecutionPolicy Bypass -File "path/to/script.ps1"`
- Quoting rule: Always single-quote the outer `-Command` string.
  Use double quotes inside for PS interpolation.
- For complex PS1: Write to a temp `.ps1` file, execute with `-File`.

## `claude update` Hook Cancellation (#23)

`claude update` starts a transient session. When it completes,
SessionEnd hooks fire but CC immediately cancels them. Observed
output: `SessionEnd hook [...] failed: Hook cancelled`.

**Impact**: None. The hooks exit before doing real work (no session
dir exists for the transient update session). This is benign noise.

## Cross-references

- Full tool-ops registry (CRUD): `/tool-ops` skill (aitools repo only)
- Tool-ops governance rule: `.claude/rules/tool-ops.md` (aitools repo)
- CC operational reference: `reference/tool-ops-claude-code.md` (aitools repo)
- Framework documentation: `reference/framework-tool-ops.md` (aitools repo)
- Tool evaluation: `/tool-eval` skill
- Tool install registry: `/tool-registry` skill
