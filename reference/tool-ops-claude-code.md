# Claude Code Operations

**Intent**: **Purpose**: Consolidated operational knowledge for
Claude Code as a managed tool — version dependencies, session
behavior, platform workarounds, and setup notes that affect harness
scripts and hooks. **Scope**: Operational knowledge only. NOT
install/upgrade (tool-registry.md). NOT governance modes or deny
rules (`/tool-ops` skill). NOT incidents (`/incident` skill). NOT
configuration deployment (setup scripts). **Audience**: Agents
modifying CC-related scripts or hooks, agents troubleshooting CC
behavior, check scripts validating version deps.

## Version Dependencies

Registry of version-dependent workarounds, behaviors, and assumptions in this repo.

- **Current version**: 2.1.81
- **Baseline version**: 2.1.51 (2026-02-16) -- version when most workarounds were written

### How to use

When Claude Code is upgraded:

1. Update "Current version" above
2. Walk CRITICAL items: check upstream issues (are they still open?)
3. Walk HIGH items if the version bump is major (e.g., 2.1 -> 2.2 or 3.0)
4. Update "Last verified" for any re-checked items
5. If a workaround is no longer needed, remove it from the codebase and this registry

Post-push checklist #20 triggers this review automatically.

---

### CRITICAL -- Would break core scripts if behavior changes

| # | Item | Baseline | Last verified | Files | Upstream |
|---|------|----------|---------------|-------|----------|
| 1 | Windows shell hardcoded to Git Bash (CLAUDE_CODE_SHELL broken) | 2.1.51 | 2.1.74 (2026-03-13) | "Windows Shell Limitations" section below, `.claude/rules/cross-platform.md`, `CLAUDE.md` (Windows dispatch) | [#7490](https://github.com/anthropics/claude-code/issues/7490), [#25558](https://github.com/anthropics/claude-code/issues/25558), [#5049](https://github.com/anthropics/claude-code/issues/5049), [#16225](https://github.com/anthropics/claude-code/issues/16225), [#20453](https://github.com/anthropics/claude-code/issues/20453) |
| 2 | SessionEnd hook API contract (session_id, cwd, transcript_path on stdin) | 2.1.51 | 2.1.74 (2026-03-13) | `shared/hooks/session-archive.sh`, `reference/user-repo.md` | -- |

### NOTE -- Not a CC dependency

| # | Item | Note | Files |
|---|------|------|-------|
| 3 | Chrome DevTools MCP `--isolated` flag | Personal preference for concurrent sessions, not tied to CC versions | `scripts/setup-user-mcp.sh/.ps1`, `.claude/rules/post-push.md` |

### HIGH -- Would break workflows or produce wrong results

| # | Item | Baseline | Last verified | Files | Upstream |
|---|------|----------|---------------|-------|----------|
| 4 | Session path sanitization (CWD -> JSONL directory name uses `-` replacement) | 2.1.51 | 2.1.51 | "Session Storage Internals" section below, `shared/hooks/session-archive.sh` | -- |
| 5 | Subagent context gap (rules/CLAUDE.md not inherited by Task subagents) | 2.1.51 | 2.1.74 (2026-03-13) | `shared/claude-shared.md` (coaching items) | [#29423](https://github.com/anthropics/claude-code/issues/29423) |
| 6 | CLAUDE.md hierarchy & merge behavior (5 levels, more-specific wins) | 2.1.51 | 2.1.51 | "CLAUDE.md Hierarchy" section below, `scripts/setup-user-claude.sh/.ps1` | -- |
| 7 | Session management commands (claude -c, --resume, /resume, /rename) | 2.1.51 | 2.1.51 | "Session Management Commands" section below | -- |
| 8 | Hook execution context (hooks run in bash or HTTP, not configurable shell) | 2.1.51 | 2.1.74 (2026-03-13) | `shared/hooks/session-archive.sh`, `scripts/setup-user-hooks.sh` | -- (2.1.63 adds HTTP hooks as alternative to shell) |
| 9 | Coaching items tied to CC capabilities (subagent gap, auto-memory locality) | 2.1.51 | 2.1.51 | `shared/claude-shared.md` | -- |
| 23 | `claude update` triggers SessionEnd hooks then cancels them | 2.1.81 | 2.1.81 (2026-03-22) | `scripts/aitools-install.sh/.ps1` (runs `claude update`) | -- |
| 24 | Subagent cross-repo file access restriction (Glob/Grep denied outside CWD repo, Read with explicit paths works) | 2.1.74 | 2.1.74 (2026-03-24) | `shared/claude-shared.md` (delegation duty), delegation prompts | -- |
| 19 | `effortLevel` setting (`settings.json` key controlling reasoning effort) | 2.1.68 | 2.1.74 (2026-03-13) | `scripts/setup-user-hooks.sh/.ps1`, `reference/user-repo.md`, `shared/claude-shared.md` | -- |
| 25 | SendMessage for agent continuation unavailable (gated behind Agent Teams flag; old `resume` param removed in 2.1.77) | 2.1.77 | 2.1.81 (2026-03-24) | Agent tool documentation, delegation prompts | [#35240](https://github.com/anthropics/claude-code/issues/35240), [#37051](https://github.com/anthropics/claude-code/issues/37051), [#38183](https://github.com/anthropics/claude-code/issues/38183) |

### MEDIUM -- Affects developer experience or specific features

| # | Item | Baseline | Last verified | Files | Upstream |
|---|------|----------|---------------|-------|----------|
| 10 | Write tool produces CRLF on macOS | 2.1.51 | 2.1.51 | `.claude/rules/pre-commit.md`, auto-memory `MEMORY.md` | -- |
| 11 | PATH limitations (npm global bin not always visible to CC) | 2.1.51 | 2.1.51 | `scripts/setup-user-mcp.sh` (node fallback for `claude mcp add`) | [#5202](https://github.com/anthropics/claude-code/issues/5202), [#3838](https://github.com/anthropics/claude-code/issues/3838) |
| 12 | PowerShell-from-Bash quoting patterns (single-quote outer, double-quote inner) | 2.1.51 | 2.1.51 | "Windows Shell Limitations" section below | -- |
| 13 | Cursor Agent CLI rule sources (does NOT read ~/.claude/CLAUDE.md) | 2.1.51 | 2.1.51 | `reference/cursor-practices.md` | -- |
| 18 | `@file` references resolved in CLAUDE.md but NOT in `.claude/rules/*.md` | 2.1.63 | 2.1.63 (2026-03-01) | `shared/claude-shared.md` (Knowledge Management), dotprofile `claude/CLAUDE.md` | -- |
| 20 | `InstructionsLoaded` hook event (fires after CLAUDE.md and rules load) | 2.1.68 | 2.1.74 (2026-03-13) | -- (not yet used) | -- |
| 21 | `agent_id`/`agent_type` in hook events (distinguishes main vs subagent) | 2.1.68 | 2.1.74 (2026-03-13) | -- (not yet used) | -- |

### LOW -- Architectural constraints unlikely to change soon

| # | Item | Baseline | Last verified | Files | Upstream |
|---|------|----------|---------------|-------|----------|
| 14 | Auto-memory locality (machine-specific, does not sync) | 2.1.51 | 2.1.51 | `shared/claude-shared.md`, auto-memory `MEMORY.md` | -- |
| 15 | Session sync not possible (CLI sessions are local per machine + directory) | 2.1.51 | 2.1.51 | "Session Sync" section below | -- |
| 16 | Session storage internals (JSONL under ~/.claude/projects/) | 2.1.51 | 2.1.51 | "Session Storage Internals" section below, `shared/hooks/session-archive.sh` | -- |
| 17 | JSONL transcript fields (type, cwd, sessionId) | 2.1.51 | 2.1.51 | "Session Storage Internals" section below, `shared/hooks/session-archive.sh` | -- |
| 22 | `includeGitInstructions` setting (controls whether git context is injected into system prompt) | 2.1.68 | 2.1.74 (2026-03-13) | -- (not yet used) | -- |

### Filed issues -- Tracking our upstream reports

| # | Issue | Title | Filed | Status | Related items |
|---|-------|-------|-------|--------|---------------|
| F1 | [#29423](https://github.com/anthropics/claude-code/issues/29423) | Task subagents do not load project CLAUDE.md or .claude/rules/ | 2026-02-27 | Open (duplicate bot challenged, differentiation posted 2026-02-28) | Item #5 |

### Release notes watch

Notable changes in CC releases that may affect this registry.

#### 2.1.63 (2026-02-28)

- **HTTP hooks added**: Hooks can now POST JSON to a URL instead of running a shell command. May affect item #8 (hook execution context) -- hooks are no longer bash-only.
- **Project configs shared across git worktrees**: `CLAUDE.md` and auto-memory now shared across worktrees of the same repo. Affects item #6 (hierarchy behavior).
- **`/simplify` and `/batch` bundled slash commands**: New built-in commands.
- No changes to Windows shell configuration (#1) or subagent context loading (#5).

#### 2.1.59 (2026-03-01)

- **Reasoning effort modes**: New `effortLevel` setting in `settings.json` (`"low"`, `"medium"`, `"high"`). Controls reasoning depth per session. "ultrathink" keyword forces high for one turn.
- No changes to Windows shell configuration (#1) or subagent context loading (#5).

#### 2.1.68 (2026-03-04)

- **`effortLevel` defaults to medium for Opus 4.6**: Previously unset (implicit high). Scripts that manage `settings.json` should handle this key. See item #19.
- **`InstructionsLoaded` hook event**: New hook event fires after CLAUDE.md and rules are loaded. See item #20.
- **`agent_id`/`agent_type` in hook events**: Hook stdin JSON now includes agent context. See item #21.
- **`includeGitInstructions` setting**: Controls git context injection into system prompt. See item #22.
- No changes to Windows shell configuration (#1) or subagent context loading (#5).

#### 2.1.74 (2026-03-13)

- Patch release. No new features affecting this registry.

#### 2.1.70 (2026-03-06)

- **VS Code integration enhancements**: Spark icon session listing, markdown plan view with comments, native MCP dialog (`/mcp`).
- **Performance**: ~74% fewer prompt input re-renders, ~426KB less startup memory, Remote Control poll reduced from 1-2s to 10min.
- **Windows/WSL clipboard fix**: Non-ASCII text (CJK, emoji) no longer corrupted; uses PowerShell `Set-Clipboard`.
- **Effort parameter fix**: Fixed "model does not support effort parameter" with custom Bedrock profiles.
- **Model notification fix**: No more repeated "Model updated to Opus 4.6" with legacy Opus strings.
- **23 bug fixes total** including API gateway compatibility, SSH newline insertion, `/color` enhancements, prompt cache busting on MCP connect.
- No changes to Windows shell configuration (#1) or subagent context loading (#5).

#### 2.1.69 (2026-03-05)

- Patch release. No new features affecting this registry.

---

## Session Behavior

Baseline: Claude Code 2.1.51 (2026-02-16)

### Session Sync Across Devices

- Claude Code CLI sessions are **local to each machine** and do **not sync** across devices.
- Claude Code web (claude.ai) sessions are separate from CLI sessions entirely.
- Sessions are also **tied to the directory** they were started in — you can only resume from the same directory.
- Syncing raw session files (JSONL) via git is **not recommended** — they contain absolute paths, aren't portable across OS, and there's no `--resume <file>` mechanism.
- **Best practice:** Use `CLAUDE.md` and auto-memory as the cross-device "session transfer" layer. Put valuable decisions and context there, let sessions be ephemeral.

### CLAUDE.md Hierarchy (5 levels)

| Level | Path | Scope |
|-------|------|-------|
| Managed (org/IT) | `C:\Program Files\ClaudeCode\CLAUDE.md` | All users on machine |
| **User (personal global)** | `~/.claude/CLAUDE.md` | You, all projects, this machine |
| **Project (team)** | `./CLAUDE.md` in repo root | All team members via git |
| Project (personal) | `./CLAUDE.local.md` | You only, auto-gitignored |
| Subdirectory | `./some-dir/CLAUDE.md` | Loaded on-demand when working in that dir |

All levels merge together. More specific wins on conflict.

### User-Level CLAUDE.md Setup

- Applies to **every** Claude Code session on that machine, regardless of project.
- Locations:
  - Windows: `C:\Users\jdpal\.claude\CLAUDE.md`
  - Mac: `~/.claude/CLAUDE.md`
- **Template source** (priority order):
  1. `<userRepoPath>/claude/CLAUDE.md` -- personal copy in the user's dotfile repo (syncs across machines via git). Contains `{{PLACEHOLDER}}` tokens.
  2. `shared/claude-shared.md` -- fallback template in the aitools repo.
- **Deploy flow** (`scripts/setup-user-claude.sh/.ps1`):
  1. Read template from user repo (fallback: shared template)
  2. Read `profile.json` from user repo to get identity values for current machine
  3. Interpolate `{{PLACEHOLDER}}` tokens (`PROFILE_NAME`, `PROFILE_COMPANY`, `IDENTITY_GIT_NAME`, `IDENTITY_GIT_EMAIL`)
  4. Append `## Machine-Specific` footer (OS, hostname, shell)
  5. Write to `~/.claude/CLAUDE.md`
- **MDM deploy** (`deploy/setup-user-claude.sh/.ps1`): Self-contained with build-time embedded content. No repo or profile needed.
- **Scaffolding**: `aitools user init` copies `shared/claude-shared.md` to `<userRepoPath>/claude/CLAUDE.md` if missing.

### Session Management Commands

| Command | What it does |
|---------|--------------|
| `claude -c` | Resume most recent session in current directory |
| `claude --resume` | Interactive session picker (current directory only) |
| `claude --resume "name"` | Resume a named session |
| `/resume` | Switch sessions from inside a running session |
| `/rename <name>` | Name the current session for easy recall |
| `claude --continue --fork-session` | Fork current session into a new one |

### claude update Hook Cancellation

`claude update` (called by `aitools-install` step 9) internally starts a
transient session to check for updates. When it completes, SessionEnd hooks
fire — but CC immediately cancels them with `Hook cancelled`. This is CC
behavior, not a hook bug.

Observed output:
```
SessionEnd hook [bash ".../harvest-session.sh"] failed: Hook cancelled
```

**Impact:** None. The hooks exit before doing real work (no session dir exists
for the transient update session). The `[info]` log level in aitools-install
correctly treats this as informational, not an error.

**No action needed.** This is benign noise from CC's session lifecycle firing
hooks for non-interactive sessions. If CC adds a hook filter for session type,
this goes away.

### Agent Continuation Gap (SendMessage)

Since v2.1.77, there is no working mechanism to send messages to a
previously spawned subagent:

- **Old mechanism** (`resume` parameter on Agent tool): Removed in v2.1.77.
  Had longstanding issues (#11712, #13619, #10856) and was effectively
  non-functional before removal.
- **New mechanism** (`SendMessage` tool): Part of the Agent Teams feature set,
  gated behind `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` (disabled by default).
  The Agent tool description references SendMessage as if universally available,
  but it is not. Even with the flag enabled, reports of unavailability (#34750).

**Impact on delegation patterns:**

- Subagents must be fully self-contained at launch. No follow-up messages possible.
- The Agent tool's own return value includes `agentId` with instructions to use
  SendMessage -- the model will attempt to use it and fail.
- Sequential delegation (launch new agent with prior agent's output) is the
  only working pattern for iterative subagent work.

**Workaround:** Include all context in the initial Agent launch prompt. Use
TaskOutput to read completed agent results. Launch new agents for follow-up
work, passing prior output as context.

Upstream: [#35240](https://github.com/anthropics/claude-code/issues/35240),
[#37051](https://github.com/anthropics/claude-code/issues/37051),
[#38183](https://github.com/anthropics/claude-code/issues/38183)

### Session Storage Internals

Claude Code stores session transcripts as JSONL files under `~/.claude/projects/`:

```
~/.claude/projects/
├── -Users-pepe-repos-ai-tooling/     # sanitized CWD path
│   ├── <session-uuid>.jsonl
│   └── <session-uuid>/subagents/     # subagent transcripts
└── -Users-pepe-repos-mbx-ext/
    └── ...
```

#### Path Sanitization

The project directory name is the CWD with `/` replaced by `-`. This is **lossy** for project names containing hyphens — you cannot split on `-` to recover the project name.

Example: `/Users/pepe/repos/ai-tooling` becomes `-Users-pepe-repos-ai-tooling`. Naive split yields `tooling`, not `ai-tooling`.

**Correct approach:** Read the `cwd` field from the JSONL transcript, then derive the project name from the real path.

#### JSONL Transcript Structure

Each line is a JSON object. Fields available in most entries:

- `type` — message type (`human`, `assistant`)
- `cwd` — original working directory (absolute path)
- `sessionId` — full session UUID

### Best Practices for CLAUDE.md Content

**Include:** build/test/lint commands, code style rules, project architecture, gotchas, tool preferences.
**Exclude:** things Claude can infer from code, standard conventions, long tutorials, frequently-changing info.
**Size:** Keep under 200 lines (auto-load limit). Use `@path` imports for more detail.

### Auto-Creating CLAUDE.md in New Projects

- No built-in auto-create. Use `claude /init` to scaffold per project.
- Use the `cc` shell alias (see `shared/shell/`) that checks for CLAUDE.md before launching.

### Machines

| Machine | OS | IDE | Claude Code |
|---------|-----|-----|-------------|
| Workstation | Windows 11 Pro for Workstations | Cursor | CLI (in Cursor terminal) |
| Laptop | macOS | Cursor | CLI (in Cursor terminal) |
| Web | Any browser | — | claude.ai (separate sessions) |

### Setup Checklist

- [x] Create `~/.claude/CLAUDE.md` on Windows workstation (via `scripts/setup-user-claude.ps1`)
- [x] Create `~/.claude/CLAUDE.md` on Mac laptop (via `scripts/setup-user-claude.sh`)
- [x] Shared rules in repo (`shared/claude-shared.md`), embedded into deploy scripts by `build-deploy.sh`
- [x] Shell alias (`cc`) for auto-CLAUDE.md check (see `shared/shell/`)
- [x] "Home base" directory for general conversations: this repo (`aitools/`)
- [x] Self-contained deploy scripts in `deploy/` — MDM-ready, no repo or Drive dependency

---

## Windows Shell Limitations

Claude Code's Bash tool is **hardcoded to Git Bash on Windows**. The `CLAUDE_CODE_SHELL` environment variable exists but is **broken on Windows** -- it is silently ignored regardless of how it's set.

Baseline: Claude Code 2.1.51 | Last verified: 2.1.62 (2026-02-27)

### Upstream Issues

| Issue | Title | Status |
|-------|-------|--------|
| [#7490](https://github.com/anthropics/claude-code/issues/7490) | Allow users to configure which shell the Bash tool uses | Open |
| [#25558](https://github.com/anthropics/claude-code/issues/25558) | CLAUDE_CODE_SHELL environment variable ignored on Windows | Open |
| [#5049](https://github.com/anthropics/claude-code/issues/5049) | CC native on Windows: not really shell aware | Open |
| [#16225](https://github.com/anthropics/claude-code/issues/16225) | Improve PowerShell shell configuration support for Windows | Open |
| [#20453](https://github.com/anthropics/claude-code/issues/20453) | CLAUDE_CODE_SHELL not respected on Windows | Closed (no fix) |

### What Does NOT Work

- `CLAUDE_CODE_SHELL=pwsh` as an environment variable -- ignored
- `env.CLAUDE_CODE_SHELL` in `settings.json` -- ignored
- No setting, extension, or MCP server can change the Bash tool's shell on Windows

### Working Workarounds

#### Run a PowerShell command from the Bash tool

```bash
pwsh -NoProfile -Command 'Your-Command Here'
```

Single-quote the `-Command` argument so bash doesn't expand `$` variables meant for PowerShell.

#### Run a .ps1 script from the Bash tool

```bash
pwsh -NoProfile -ExecutionPolicy Bypass -File "path/to/script.ps1"
```

This is the pattern used by `aitools install` (see the `install` command in `scripts/aitools`).

#### Multi-line PowerShell from the Bash tool

```bash
pwsh -NoProfile -Command '
  $items = Get-ChildItem -Path .
  foreach ($item in $items) {
    Write-Host $item.Name
  }
'
```

### Quoting Gotchas

| Pattern | Works? | Why |
|---------|--------|-----|
| `pwsh -Command 'Write-Host $env:PATH'` | Yes | Single quotes prevent bash expansion |
| `pwsh -Command "Write-Host $env:PATH"` | No | Bash expands `$env` (empty), PowerShell gets broken command |
| `pwsh -Command 'Write-Host "hello world"'` | Yes | Inner double quotes are fine inside outer single quotes |
| `pwsh -Command "Write-Host 'hello world'"` | Risky | Bash may expand special chars in the outer double quotes |

**Rule of thumb:** Always single-quote the outer `-Command` string. Use double quotes inside for PowerShell string interpolation.

### Recommended Pattern: Write-then-Execute

For anything beyond a trivial one-liner, **do not use inline `-Command`**. The quoting rules above become unmanageable for multi-statement scripts with variables, loops, or string interpolation.

**Default pattern**: Write the PowerShell code to a temp `.ps1` file using the Write tool, then execute with `-File`:

```bash
# Step 1: Use the Write tool to create a temp .ps1 file with full PS syntax
# Step 2: Execute it cleanly — no quoting issues
pwsh -NoProfile -ExecutionPolicy Bypass -File "path/to/temp.ps1"
# Step 3: Delete the temp file when done
```

Benefits:
- No escaping between bash and PowerShell
- Full PowerShell syntax — readable, editable with the Edit tool
- Same pattern works for validation scripts
- Tools like pandoc, git, etc. resolve correctly in the script's PATH context

**Only use inline `-Command`** for trivial one-liners where a temp file would be overkill (e.g., `pwsh -Command '$PSVersionTable.PSVersion'`).

### Impact on This Repo

This repo provides both `.ps1` and `.sh` variants of all scripts. On Windows, Claude Code can run `.sh` scripts natively (Git Bash) but must use the `pwsh -File` workaround for `.ps1` scripts. PS 7 (`pwsh`) is the project baseline -- all dispatch uses `pwsh`, not `powershell.exe`.

Once Anthropic fixes the upstream issues, we can simplify by setting `CLAUDE_CODE_SHELL=pwsh` and running `.ps1` scripts directly.

---

## Cross-References

- Tool-ops registry: `/tool-ops` skill
- Tool registry: `reference/tool-registry.md`
- Incident registry: `/incident` skill
- User repo spec: `reference/user-repo.md`
- Cross-platform rules: `.claude/rules/cross-platform.md`
- Upstream shell issue comment: `reference/gh-issue-7490-comment.md`
