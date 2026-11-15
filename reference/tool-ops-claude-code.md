# Claude Code Operations

**Intent**: **Purpose**: Consolidated operational knowledge for
Claude Code as a managed tool — version dependencies, session
behavior, platform workarounds, and setup notes that affect harness
scripts and hooks. **Scope**: Operational knowledge only. NOT
install/upgrade (`/tool-registry` skill). NOT governance modes or deny
rules (`/tool-ops` skill). NOT incidents (`/incident` skill). NOT
configuration deployment (setup scripts). **Audience**: Agents
modifying CC-related scripts or hooks, agents troubleshooting CC
behavior, check scripts validating version deps.

## Version Dependencies

Registry of version-dependent workarounds, behaviors, and assumptions in this repo.

- **Current version**: 2.1.325 (observed `claude --version`, Windows 11, 2026-11-14). Re-verified at this version: #1 (Windows shell), #25, #27 (level-3 tool set), #31, #32 (#31 and #32 again by mission 38dc-25, the same day). Every other item keeps its own "Last verified" (items #1-#24 at or before 2.1.81: open item 2 of `reference/evaluations/claude-code-macos-2026-10-21.md`). Previous observation: 2.1.309, macOS, 2026-10-27. Observed at 2.1.325 on macOS (2026-11-15): #36 (`/compact`).
- **Baseline version**: 2.1.51 (2026-02-16) -- version when most workarounds were written

### How to use

When Claude Code is upgraded:

1. Update "Current version" above
2. Walk CRITICAL items: check upstream issues (are they still open?)
3. Walk HIGH items if the version bump is major (e.g., 2.1 -> 2.2 or 3.0)
4. Update "Last verified" for any re-checked items
5. If a workaround is no longer needed, remove it from the codebase and this registry

Post-push checklist #20 triggers this review automatically.

### Item numbers

Each item keeps its number for life; a new item takes the next free number
(after #36) whatever its severity, so a table is not in numeric order. Before
adding one, check every severity table for the number.

**Renumbered 2026-11-14** (mission 38dc-25): #28 and #29 had each been given
to two items. The MEDIUM items numbered first keep them (commit 261b9d9,
2026-10-26): #28 user-level rules, #29 skills. The HIGH items moved: auto
mode and allow rules for PR merges #28 -> #33 (commit 7ff4e74, 2026-10-28),
hook output channel #29 -> #34. Records written before 2026-11-14 (handoffs,
commit messages, release notes) that cite #28 for auto mode or #29 for the
hook output channel mean #33 and #34. Records of 2026-10-28 from the
workflow-guard work (commit da43dc5) also number the hook output channel #28
and the Workflow event shape #29: those are #34 and #30 (the merge f88fb7d
moved them to #29 and #30 the same day).

---

### CRITICAL -- Would break core scripts if behavior changes

| # | Item | Baseline | Last verified | Files | Upstream |
|---|------|----------|---------------|-------|----------|
| 1 | Windows shell hardcoded to Git Bash (CLAUDE_CODE_SHELL broken) | 2.1.51 | 2.1.325 (2026-11-14, Windows 11): **partly obsolete**. The Bash tool still runs Git Bash (its tool description: "This tool runs Git Bash (POSIX sh), not cmd.exe or PowerShell"), but every session (main and delegates) also has a PowerShell tool ("PowerShell edition: PowerShell 7+ (pwsh)"), with no shell key in `~/.claude/settings.json`, and the session environment reads "Shell: PowerShell (primary); Bash tool also available for POSIX scripts". `CLAUDE_CODE_SHELL`: not tested. Docs (tools-reference, read 2026-11-14 by af14-08): "**Windows with Git Bash installed**: the tool is on by default for claude.ai and Console accounts; set `CLAUDE_CODE_USE_POWERSHELL_TOOL=1` to enable it in Amazon Bedrock, Google Cloud's Agent Platform, and Microsoft Foundry sessions, or `0` to turn it off." and "When the tool is enabled, Claude treats PowerShell as the primary shell. The Bash tool remains available for POSIX scripts when Git Bash is installed." `CLAUDE_CODE_SHELL` (env-vars): "Set the shell Claude Code uses to run Bash tool commands. Accepts a path to a `bash` or `zsh` binary"; whether it works on Windows: not stated. Upstream history: PowerShell tool preview (2.1.84), "Git for Windows no longer required" (2.1.120), per `reference/evaluations/claude-code-macos-2026-10-21.md` | "Windows Shell Limitations" section below, `.claude/rules/cross-platform.md`, `CLAUDE.md` (Windows dispatch) | [#7490](https://github.com/anthropics/claude-code/issues/7490), [#25558](https://github.com/anthropics/claude-code/issues/25558), [#5049](https://github.com/anthropics/claude-code/issues/5049), [#16225](https://github.com/anthropics/claude-code/issues/16225), [#20453](https://github.com/anthropics/claude-code/issues/20453) |
| 2 | SessionEnd hook API contract (session_id, cwd, transcript_path on stdin) | 2.1.51 | 2.1.74 (2026-03-13) | `shared/hooks/session-archive.sh`, `reference/user-repo.md` | -- |

### NOTE -- Not a CC dependency

| # | Item | Note | Files |
|---|------|------|-------|
| 3 | Chrome DevTools MCP `--isolated` flag | Personal preference for concurrent sessions, not tied to CC versions | `scripts/setup-user-mcp.sh/.ps1`, `reference/post-push-checklist.md` (steps 3 and 15) |

### HIGH -- Would break workflows or produce wrong results

| # | Item | Baseline | Last verified | Files | Upstream |
|---|------|----------|---------------|-------|----------|
| 4 | Session path sanitization (CWD -> JSONL directory name uses `-` replacement) | 2.1.51 | 2.1.51 | "Session Storage Internals" section below, `shared/hooks/session-archive.sh` | -- |
| 5 | Subagent context gap (rules/CLAUDE.md not inherited by Task subagents) | 2.1.51 | 2.1.325 (2026-11-14, Windows): **partly superseded** for general-purpose delegates launched with the Agent tool (observed at levels 2 and 3 by 38dc-25, af14-04, af14-05): at launch they receive the user and project CLAUDE.md and every user and project rule without `paths:` frontmatter; a `paths:` rule arrives later, after the delegate reads files (38dc-25 got them on reading files in its worktree, whose paths relative to the session's directory start `.claude/worktrees/38dc-25/`; how such paths are matched: not checked); a nested CLAUDE.md (`.aitools/channel/CLAUDE.md`) arrives when it reads a file under it. Project files come from the session's working directory, not the delegate's worktree (observed for a session started in the main checkout): rules and CLAUDE.md from the main checkout `C:\Users\jdpal\repos\aitools`, and the project skill `frameworks` loaded with "Base directory for this skill: C:\Users\jdpal\repos\aitools\.claude\skills\frameworks" for a delegate working in `.claude/worktrees/38dc-25`. So a delegate's rules can differ from its branch's; the delegation duty (element 2: read the worktree's files) still applies. Explore, Plan and workflow agents not re-checked. Docs (sub-agents.md "What loads at startup", read 2026-11-14 by af14-08): a subagent gets "every level of the CLAUDE.md hierarchy the main conversation loads, including `~/.claude/CLAUDE.md`, project rules, `CLAUDE.local.md`, managed policy files" (Explore and Plan skip this), and "doesn't see your conversation history, the skills you've already invoked, or the files Claude has already read" | `shared/claude-shared.md` (coaching items) | [#29423](https://github.com/anthropics/claude-code/issues/29423) |
| 6 | CLAUDE.md hierarchy & merge behavior (5 levels; all loaded and concatenated, none overrides another) | 2.1.51 | 2.1.51; docs re-read 2026-11-14 (memory.md, af14-08): "All discovered files are concatenated into context rather than overriding each other"; "if two instructions contradict each other, Claude may pick one arbitrarily". The earlier "more-specific wins" was wrong | "CLAUDE.md Hierarchy" section below, `scripts/setup-user-claude.sh/.ps1` | -- |
| 7 | Session management commands (claude -c, --resume, /resume, /rename) | 2.1.51 | 2.1.51 | "Session Management Commands" section below | -- |
| 8 | Hook execution context (hooks run in bash or HTTP, not configurable shell) | 2.1.51 | 2.1.74 (2026-03-13); 2.1.325 (2026-11-14, Windows): the harness registers every hook command as `bash "<path>"` and those hooks run (the standing-order-guard blocked a `cat` call and the delegation-guard added context on every Agent call in session 87795dc3-e); which shell parses the command string: hooks docs (read 2026-11-14 by af14-08, spot-checked by 38dc-25): "The `command` string is passed to a shell: `sh -c` on macOS and Linux, Git Bash on Windows, or PowerShell when Git Bash isn't installed. Set the `shell` field to choose explicitly." So the harness's bash hooks need Git for Windows | `shared/hooks/session-archive.sh`, `scripts/setup-user-hooks.sh` | -- (2.1.63 adds HTTP hooks as alternative to shell) |
| 9 | Coaching items tied to CC capabilities (subagent gap, auto-memory locality) | 2.1.51 | 2.1.51 | `shared/claude-shared.md` | -- |
| 23 | `claude update` triggers SessionEnd hooks then cancels them | 2.1.81 | 2.1.81 (2026-03-22) | `scripts/aitools-install.sh/.ps1` (runs `claude update`) | -- |
| 24 | Subagent cross-repo file access restriction (Glob/Grep denied outside CWD repo, Read with explicit paths works) | 2.1.74 | 2.1.74 (2026-03-24) | `shared/claude-shared.md` (delegation duty), delegation prompts | -- |
| 19 | `effortLevel` setting (`settings.json` key controlling reasoning effort) | unknown: no changelog entry announces the key (2.1.68 changed the Opus 4.6 default effort; the key is first named in 2.1.203; 2.1.59 entry corrected 2026-11-14) | 2.1.74 (2026-03-13) | `scripts/setup-user-settings.sh/.ps1` (`profile.json` `claude.settings.effortLevel`), `shared/claude-shared.md` | -- |
| 25 | **Closed at 2.1.325.** SendMessage for agent continuation unavailable (gated behind Agent Teams flag; old `resume` param removed in 2.1.77) | 2.1.77 | 2.1.81 (2026-03-24); **superseded**: in 2.1.309 (macOS, 2026-10-27) `SendMessage` and `ListAgents` are offered to the main session for in-process subagents; **tested end to end 2.1.325 (Windows, 2026-11-14)**: delegates at levels 1-3 have SendMessage (deferred); a message to a running delegate is queued to its next tool round, one to a finished delegate resumes it, `to: "main"` reaches the main conversation; delegates at levels 2-3 have no ListAgents. See item #32 | "Delegate Identity, Transcripts and Control" section below, "Agent Continuation Gap" (history), delegation prompts | [#35240](https://github.com/anthropics/claude-code/issues/35240), [#37051](https://github.com/anthropics/claude-code/issues/37051), [#38183](https://github.com/anthropics/claude-code/issues/38183) |
| 26 | Sub-agent Markdown file-name block: Write refuses a sub-agent write whose basename matches `^(REPORT\|SUMMARY\|FINDINGS\|ANALYSIS).*\.md$` (case-insensitive) | 2.1.289 | 2.1.289 (2026-10-05) | "Sub-agent Markdown File-Name Block" section below, dotprofile `claude/rules/delegation.md` (D-DEL1), `shared/skills/delegate/SKILL.md`, `shared/hooks/delegation-duty-guard.sh`, `shared/claude-shared.md` + dotprofile `claude/CLAUDE.md` (Delegation Duty) | -- (not in the official docs) |
| 27 | `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` caps sub-agent nesting (documented default 3; the Claude Code web environment sets 1); the launch path decides whether a delegate gets the Agent tool (Workflow agents never do) | 2.1.219 | 2.1.307 (2026-10-21); level-3 tool set re-verified 2.1.325 (Windows, 2026-11-14): no Agent, no Workflow | "Sub-agent Nesting Depth" section below, `shared/skills/delegate/SKILL.md`, `shared/skills/aitool-continue/SKILL.md` | -- |
| 33 | Auto mode (numbered #28 until 2026-11-14): an explicit user-scope allow rule (`Bash(gh pr merge:*)`) resolves a matching command before the classifier, so `gh pr merge` no longer gets the "[Merge Without Review]" denial; applies to sub-agents; picked up mid-session | 2.1.309 | 2.1.309 (2026-10-28) | "Auto Mode and Allow Rules for PR Merges" section below, dotprofile `profile.json` `claude.settings.permissions.allow`, merge-mission prompts | -- (documented: permission-modes, permissions, settings) |
| 34 | Hook output channel (numbered #29 until 2026-11-14): stderr of a hook that exits 0 never reaches Claude; observe-mode hooks reach Claude through stdout JSON `hookSpecificOutput.additionalContext`. Hooks docs (https://code.claude.com/docs/en/hooks, read 2026-10-28): "Claude never sees stderr from a hook that exits 0."; PreToolUse decision control, `additionalContext`: "String added to Claude’s context alongside the tool result."; "A hook’s additionalContext, systemMessage, and initialUserMessage strings, and its plain stdout, are capped at 10,000 characters" | 2.1.309 | 2.1.309 (2026-10-28) | `shared/hooks/delegation-duty-guard.sh`, `shared/hooks/workflow-delegation-guard.sh` (`finish()`: 4,000-character cap), `.claude/rules/hook-rollout.md` | -- |
| 30 | Workflow event shape: Claude Code fires ONE PreToolUse(Workflow) per Workflow tool call, whose `tool_input` carries the whole `script` (the 5 real payloads of session 10cf255a-c carry only `script`); no hook event fires per `agent()` call (a workflow-runtime function, not a tool call); tool calls made inside workflow agents fire the configured hooks with `agent_id`. Hooks docs (read 2026-10-28): PreToolUse "Matches on any tool name except EndConversation: built-in tools such as Bash, PowerShell, Edit, Write, Read, Glob, Grep, Agent, Workflow, WebFetch, WebSearch, AskUserQuestion, and ExitPlanMode, and any MCP tool names."; "When a subagent calls a tool, tool events such as PreToolUse and PostToolUse fire the same configured hooks as in the main conversation, and the input carries the agent_id and agent_type common input fields that identify the subagent." Live record: workflow wf_11a87d20-2c7's agent transcripts hold 34 `PreToolUse:Bash`, 1 `PreToolUse:Read` and 68 `PostToolUse:Write` hook records. Not seen by the workflow guard: a saved workflow launched by `tool_input.name` (no `script` / `scriptPath`: reported "not checked"), and child workflows a script starts with `workflow(...)` (their `agent()` prompts reach no hook). Parser limits (hook header LIMITS): a `/` after `)` is read as division; in `const A = '...', B = '...'` only `A` is captured; a method named `agent(p) { }` counts as an unresolved call site | 2.1.309 | 2.1.309 (2026-10-28) | `shared/hooks/workflow-delegation-guard.sh` (parses the script at that one event), `shared/hooks/hooks-manifest.json`, `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Hook2/S3-Hook2-spec.md` section 1 | -- |
| 31 | Delegate identity and files: every delegate's transcript is `~/.claude/projects/<project-dir>/<main-session-id>/subagents/agent-<agentId>.jsonl` (flat for all depths) with `agent-<agentId>.meta.json`, whose `description` (the Agent call's `description`) is the only link from a mission name to an agentId; the Agent tool returns the agentId and an `output_file` but no session id; the `output_file` is created empty and was observed to become a hard link to the transcript when the delegate was woken again after it stopped (by a SendMessage or by its own background task), and not otherwise (v1.1 probes); no environment variable holds a delegate's own id (`CLAUDE_CODE_SESSION_ID` is the main session's) | 2.1.325 | 2.1.325 (2026-11-14, Windows) | "Delegate Identity, Transcripts and Control" section below, `shared/skills/delegate/SKILL.md` ("Environment limits"), delegation prompts | -- (not in the official docs as observed) |
| 32 | Delegate control: an orchestrator cannot TaskStop its own delegate (the error names the caller's id), but the main session stopped a level-1 delegate it launched (v1.1); TaskStop with an unknown id lists the session's running background agents; SendMessage queues to a running delegate and resumes a finished one; a second SubagentHandback is delivered in a run woken by a Monitor event or started by a SendMessage to a finished delegate, and refused ("one report per result") in a run woken while a background shell from before the first report still runs, or by that shell's completion (v1.1 probes); a delegate's background tasks outlive its hand-back and their completion can bring it back | 2.1.325 | 2.1.325 (2026-11-14, Windows; v1.1 probes af14-01 to af14-07 the same day) | "Delegate Identity, Transcripts and Control" section below, `shared/skills/delegate/SKILL.md`, delegation prompts | -- |
| 35 | SessionEnd hook time budget: hooks docs (read 2026-11-14 by af14-08, spot-checked by 38dc-25): "SessionEnd hooks have a default timeout of 1.5 seconds. It applies when you exit, run `/clear`, or switch sessions with interactive `/resume`."; a per-hook `timeout` raises the shared budget up to 60 s, `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` overrides it; a hook that overruns is cancelled ("Hook cancelled"). The harness archive hook overran it on every exit and runs detached since 2026-06-21 (`reference/artifact-harvesting.md` "Detached archive"); item #23 is the same message from `claude update` | 2.1.74 (changelog: SessionEnd hooks were killed after 1.5 s "regardless of `hook.timeout`" before) | docs 2026-11-14 (2.1.325); not re-measured | `shared/hooks/session-archive.sh`, `scripts/ait-harvest.py`, `reference/artifact-harvesting.md` | -- |
| 36 | `/compact` keeps the last reply word for word: after `/compact` the context holds a summary of the conversation, then "the most recent messages from before compaction, kept verbatim". Observed once: the part kept word for word was the last assistant reply (a handoff printed in the terminal); the prompt that asked for it came back only in the summary. The summary names the session transcript and says it "was written without seeing" the kept messages. How many messages are kept, and whether that varies: unknown. The `/handoff` skill (v2.0) depends on it: the handoff is the last reply before `/compact`. **Claude Code only**: other harnesses aitools supports (Cursor CLI, IDE, cloud agents) are not tested and may behave differently | unknown (first version not checked) | 2.1.325 (2026-11-15, macOS, CLI, session a9074793-c) | "Compaction and the Terminal Handoff" section below, `shared/skills/handoff/SKILL.md` | -- (not checked against the docs) |

### MEDIUM -- Affects developer experience or specific features

| # | Item | Baseline | Last verified | Files | Upstream |
|---|------|----------|---------------|-------|----------|
| 10 | Write tool produces CRLF on macOS | 2.1.51 | 2.1.51 | `reference/pre-commit-checklist.md` (step 4), `scripts/check-pre-commit.sh` step 4 (CRLF check) | -- |
| 11 | PATH limitations (npm global bin not always visible to CC) | 2.1.51 | 2.1.51 | `scripts/setup-user-mcp.sh` (node fallback for `claude mcp add`) | [#5202](https://github.com/anthropics/claude-code/issues/5202), [#3838](https://github.com/anthropics/claude-code/issues/3838) |
| 12 | PowerShell-from-Bash quoting patterns (single-quote outer, double-quote inner) | 2.1.51 | 2.1.51 | "Windows Shell Limitations" section below | -- |
| 13 | Cursor Agent CLI rule sources (does NOT read ~/.claude/CLAUDE.md) | 2.1.51 | 2.1.51 | `reference/cursor-practices.md` | -- |
| 18 | `@file` references resolved in CLAUDE.md but NOT in `.claude/rules/*.md` | 2.1.63 | 2.1.63 (2026-03-01) | `shared/claude-shared.md` (Knowledge Management), dotprofile `claude/CLAUDE.md` | -- |
| 20 | `InstructionsLoaded` hook event (fires after CLAUDE.md and rules load) | 2.1.69 (changelog; was recorded as 2.1.68 until 2026-11-14) | 2.1.74 (2026-03-13) | -- (not yet used) | -- |
| 21 | `agent_id`/`agent_type` in hook events (distinguishes main vs subagent) | 2.1.69 (changelog; was recorded as 2.1.68 until 2026-11-14; `SubagentStop` had `agent_id` since 2.0.42) | 2.1.74 (2026-03-13) | -- (not yet used) | -- |
| 28 | User-level rules (`~/.claude/rules/`): apply to every project on the machine; loaded before project rules, and neither set overrides the other (on conflict Claude may follow either); a rule without `paths:` loads at launch; a user rule's `paths:` globs are relative to the session's primary working directory (a project rule's: the directory that holds its `.claude` folder); `paths` is the only frontmatter field read, others are ignored without an error; frontmatter that does not parse loads the rule as if it had no `paths`. Project rules are discovered recursively; whether user-level rules are, and the case of the `.md` extension: unknown (not stated) | unknown (first version not stated; read against 2.1.309) | 2.1.309 (2026-10-27, code.claude.com/docs/en/memory "User-level rules", "Path-specific rules", "Rule frontmatter reference", read with chrome-devtools) | `scripts/setup-user-claude.sh/.ps1` (rules fan-out), `scripts/deploy-harness.sh/.ps1`, `reference/rules.md` | -- |
| 29 | Skills: personal `~/.claude/skills/<name>/SKILL.md` ("All your projects on this machine, but not Cowork or cloud sessions") and project `.claude/skills/`; a same-named skill runs personal over project; only the description (with `when_to_use`, truncated at 1,536 characters in the listing) is in context per skill, the body loads when invoked; `disable-model-invocation: true` keeps the description out of context; a skill entry may be a symlink to a directory (loaded once); `synced` is reserved (`~/.claude/skills/synced/` holds claude.ai skills) and `anthropic-skills*` does not load; live change detection covers SKILL.md text only; in a linked worktree without `.claude/skills` at its root, the main checkout's project skills load (2.1.277+) | unknown (first version not stated; read against 2.1.309) | 2.1.309 (2026-10-27, code.claude.com/docs/en/skills "Choose where skills load", "Same name in", "Frontmatter reference", invocation table, read with chrome-devtools) | `scripts/aitools-lib.sh/.ps1` (`fanout_harness_skills` / `Invoke-HarnessSkillsFanout`), `scripts/setup-user-claude.sh/.ps1`, `scripts/deploy-harness.sh/.ps1`, `reference/skills.md` | -- |

### LOW -- Architectural constraints unlikely to change soon

| # | Item | Baseline | Last verified | Files | Upstream |
|---|------|----------|---------------|-------|----------|
| 14 | Auto-memory locality (machine-specific, does not sync) | 2.1.51 | 2.1.51 | `shared/claude-shared.md` | -- |
| 15 | Session sync not possible (CLI sessions are local per machine + directory) | 2.1.51 | 2.1.51 | "Session Sync" section below | -- |
| 16 | Session storage internals (JSONL under ~/.claude/projects/) | 2.1.51 | 2.1.51 | "Session Storage Internals" section below, `shared/hooks/session-archive.sh` | -- |
| 17 | JSONL transcript fields (type, cwd, sessionId) | 2.1.51 | 2.1.51 | "Session Storage Internals" section below, `shared/hooks/session-archive.sh` | -- |
| 22 | `includeGitInstructions` setting (controls whether git context is injected into system prompt) | 2.1.69 (changelog; was recorded as 2.1.68 until 2026-11-14) | 2.1.74 (2026-03-13) | -- (not yet used) | -- |

### Filed issues -- Tracking our upstream reports

| # | Issue | Title | Filed | Status | Related items |
|---|-------|-------|-------|--------|---------------|
| F1 | [#29423](https://github.com/anthropics/claude-code/issues/29423) | Task subagents do not load project CLAUDE.md or .claude/rules/ | 2026-02-27 | Open (duplicate bot challenged, differentiation posted 2026-02-28) | Item #5 |

### Release notes watch

Notable changes in CC releases that may affect this registry.

#### 2.1.325 (observed 2026-11-14, Windows)

- **SendMessage works for delegates** (item #25 closed): queued to a running
  delegate, resumes a finished one, `to: "main"` reaches the main
  conversation. See items #31 and #32.
- **SubagentHandback**: a second report is delivered in a run woken by a
  Monitor event or by a SendMessage to a finished delegate, and refused in
  a run woken while a background shell from before the first report still
  runs, or by its completion; a delegate's background tasks outlive its
  hand-back. See item #32.
- **Windows shell**: a PowerShell tool in every session, PowerShell the
  primary shell; the Bash tool is still Git Bash. See item #1.
- **TaskStop**: the main session can stop a level-1 delegate. See item #32.
- Changelog not read for this entry; the behaviour above was observed, not
  read from release notes.
- **`/compact`** (observed 2026-11-15, macOS): keeps the last reply word
  for word after its summary. See item #36.

#### 2.1.289 (observed 2026-10-05)

- **Sub-agent Markdown file-name block** in the Write tool. See item #26.
- **`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`** in effect (set to 1 by the Claude Code web environment). See item #27.
- Items #1-#25 were not re-verified against this version (see "Current version" above).

#### 2.1.219

- **Default sub-agent nesting depth raised from 1 to 3** (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`), per the changelog as reported on 2026-10-05. See item #27.

#### 2.1.63 (2026-02-28)

- **HTTP hooks added**: Hooks can now POST JSON to a URL instead of running a shell command. May affect item #8 (hook execution context) -- hooks are no longer bash-only.
- **Project configs shared across git worktrees**: `CLAUDE.md` and auto-memory now shared across worktrees of the same repo. Affects item #6 (hierarchy behavior).
- **`/simplify` and `/batch` bundled slash commands**: New built-in commands.
- No changes to Windows shell configuration (#1) or subagent context loading (#5).

#### 2.1.59 (2026-02-26)

- Corrected 2026-11-14 (38dc-25, from the changelog read by af14-08 with
  chrome-devtools): the entry is auto memory ("Claude automatically saves
  useful context to auto-memory"), `/copy` and fixes. It says nothing about
  effort. The earlier text here ("New `effortLevel` setting", date
  2026-03-01) was wrong. No changelog entry announces an `effortLevel` key:
  effort lines start at 2.1.42, 2.1.69 first calls it a "setting", 2.1.76
  adds `/effort`, and the key `effortLevel` is first named in 2.1.203. See
  item #19.

#### 2.1.68 (2026-03-04)

- Whole entry (verbatim): "Opus 4.6 now defaults to medium effort for Max
  and Team subscribers. ... You can change this anytime with `/model`";
  "Re-introduced the "ultrathink" keyword to enable high effort for the next
  turn"; "Removed Opus 4 and 4.1 from Claude Code on the first-party API".
  See item #19.
- Corrected 2026-11-14: `InstructionsLoaded`, `agent_id`/`agent_type` and
  `includeGitInstructions` are in 2.1.69, not here (items #20, #21, #22).

#### 2.1.74 (2026-03-13)

- "Fixed `SessionEnd` hooks being killed after 1.5 s on exit regardless of
  `hook.timeout` — now configurable via
  `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS`" (changelog, read 2026-11-14 by
  af14-08). See item #35. (Earlier text: "Patch release. No new features
  affecting this registry.")

#### 2.1.70 (2026-03-06)

- **VS Code integration enhancements**: Spark icon session listing, markdown plan view with comments, native MCP dialog (`/mcp`).
- **Performance**: ~74% fewer prompt input re-renders, ~426KB less startup memory, Remote Control poll reduced from 1-2s to 10min.
- **Windows/WSL clipboard fix**: Non-ASCII text (CJK, emoji) no longer corrupted; uses PowerShell `Set-Clipboard`.
- **Effort parameter fix**: Fixed "model does not support effort parameter" with custom Bedrock profiles.
- **Model notification fix**: No more repeated "Model updated to Opus 4.6" with legacy Opus strings.
- **23 bug fixes total** including API gateway compatibility, SSH newline insertion, `/color` enhancements, prompt cache busting on MCP connect.
- No changes to Windows shell configuration (#1) or subagent context loading (#5).

#### 2.1.69 (2026-03-05)

- "Added `InstructionsLoaded` hook event that fires when CLAUDE.md or
  `.claude/rules/*.md` files are loaded into context" (item #20) and "Added
  `agent_id` (for subagents) and `agent_type` (for subagents and `--agent`)
  to hook events" (item #21); "Added `includeGitInstructions` setting (and
  `CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS` env var) to remove built-in commit
  and PR workflow instructions from Claude's system prompt" (item #22, found
  by the reviewer af14-09 and re-read by 38dc-25); "Added effort level
  display ... which effort setting is active" (changelog, read 2026-11-14
  by af14-08). The earlier
  text here ("Patch release. No new features affecting this registry.") was
  wrong.

---

## Session Behavior

Baseline: Claude Code 2.1.51 (2026-02-16)

### Session Sync Across Devices

- Claude Code CLI sessions are **local to each machine** and do **not sync** across devices.
- Claude Code web (claude.ai) sessions are separate from CLI sessions entirely.
- Sessions are also **tied to the directory** they were started in — you can only resume from the same directory.
- Syncing raw session files (JSONL) via git is **not recommended** — they contain absolute paths, aren't portable across OS, and there's no `--resume <file>` mechanism.
- **Best practice:** Use `CLAUDE.md` and auto-memory as the cross-device "session transfer" layer. Put valuable decisions and context there, let sessions be ephemeral.

### Session Archive & Catch-up (harness)

While CC sessions don't sync, the harness archives them. SessionEnd
(`session-archive.sh`) and SessionStart (`session-catchup.sh`) hooks — thin
shims over `scripts/ait-harvest.py` — copy each session transcript **and its
subagent transcripts** to the user repo (`sessions/<project>/`), committing and
pushing best-effort. Catch-up on SessionStart recovers anything an abrupt,
offline, or slept SessionEnd missed. The helper logs to
`~/.aitools/logs/ait-harvest.log`. Full spec: `@reference/user-repo.md`
"Archiving Mechanism".

### CLAUDE.md Hierarchy (5 levels)

| Level | Path | Scope |
|-------|------|-------|
| Managed (org/IT) | `C:\Program Files\ClaudeCode\CLAUDE.md` | All users on machine |
| **User (personal global)** | `~/.claude/CLAUDE.md` | You, all projects, this machine |
| **Project (team)** | `./CLAUDE.md` in repo root | All team members via git |
| Project (personal) | `./CLAUDE.local.md` | You only, auto-gitignored |
| Subdirectory | `./some-dir/CLAUDE.md` | Loaded on-demand when working in that dir |

All levels load and are concatenated, broadest first; none overrides
another. Memory docs (read 2026-11-14 by af14-08): "All discovered files are
concatenated into context rather than overriding each other" and "if two
instructions contradict each other, Claude may pick one arbitrarily". Keep
the levels consistent (item #6; the earlier "more specific wins" was wrong).

### User-Level CLAUDE.md Setup

- Applies to **every** Claude Code session on that machine, regardless of project.
- Locations:
  - Windows: `%USERPROFILE%\.claude\CLAUDE.md`
  - Mac: `~/.claude/CLAUDE.md`
- **Template source** (priority order):
  1. `<userRepoPath>/claude/CLAUDE.md` -- personal copy in the user's dotfile repo (syncs across machines via git). Contains `{{PLACEHOLDER}}` tokens.
  2. `shared/claude-shared.md` -- fallback template in the aitools repo.
- **Deploy flow** (`scripts/setup-user-claude.sh/.ps1`):
  1. Read the template from the dotprofile (fallback: `shared/claude-shared.md`); a resolver error deploys nothing.
  2. Get this machine's values from the one resolver (`resolve_machine_profile` / `Resolve-MachineProfile`).
  3. Interpolate `{{PROFILE_NAME}}`, `{{PROFILE_COMPANY}}`, `{{IDENTITY_GIT_NAME}}`, `{{IDENTITY_GIT_EMAIL}}`, `{{USER_REPO_PATH}}` (one literal pass; empty values leave the token).
  4. Append `## Machine-Specific` (`- Machine: <OS> <arch> (<hostname>; profile <alias>)`, `- Shell: <shell>`; PS1: no arch yet).
  5. Deploy through `deploy_managed_file` with the dotprofile template as adopt target and `claude_md_adopt_filter`.
- **MDM deploy** (`<userRepoPath>/deploy/setup-user-claude.sh/.ps1`): embeds the resolver, the build-time template and a `profile.json` snapshot (no rules: `.claude/rules/deploy-paths.md`); uses the live dotprofile when the machine has it, the embedded copies otherwise.
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
| `/compact` | Summarise the conversation so far; the most recent messages are kept word for word after the summary (item #36) |

### Compaction and the Terminal Handoff (#36)

**Claude Code only.** This section records what the Claude Code harness
did. aitools supports other harnesses (Cursor CLI, Cursor IDE, Cursor cloud
agents); their compaction or summarisation has not been tested and may not
behave the same. Test it there before relying on it.

**Observed** (Claude Code 2.1.325, CLI, macOS, 2026-11-15, session
a9074793-c):

1. The commander asked for a handoff to read after compaction in the same
   session, printed in the terminal, with no file. The agent printed it as
   its last reply.
2. The commander ran `/compact`.
3. The context after compaction held, in order: a summary of the session
   (nine sections; the commander's prompts listed, the agent's replies and
   tool output condensed), with the transcript path ("If you need specific
   details from before compaction (like exact code snippets, error
   messages, or content you generated), read the full transcript at:
   <path>"); the note "The messages after this summary are the most recent
   messages from before compaction, kept verbatim. The summary was written
   without seeing them, so something it says has not happened yet may
   already have happened in them."; then the handoff reply, unchanged. The
   prompt that asked for the handoff was not among the kept messages.
4. The resumed agent extracted the handoff from the transcript
   (`read-session.py --search` with a phrase unique to the handoff) and
   compared it section by section with the copy in its context: identical.

**What follows:**

- Text that must survive word for word goes in the last reply before
  `/compact`, with nothing after it.
- Everything earlier comes back as summary: re-read it from the
  transcript when an action depends on its exact words.
- Where the summary and the kept messages disagree on what has happened,
  the kept messages are newer.

**Unknown:** how many recent messages are kept, and whether that depends
on their size; whether auto-compaction keeps the same; Claude Code on
Windows and Claude Code web (the same harness, not part of this test).

Process: `/handoff` skill (v2.0: written by the session agent itself,
printed in the terminal, not delegated).

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

The same `Hook cancelled` also appears in normal sessions when a SessionEnd
hook overruns the SessionEnd time budget (1.5 s by default): item #35. That
one is not benign: the harness moved its archive work to a detached process
for this reason (`reference/artifact-harvesting.md` "Detached archive").

**No action needed.** This is benign noise from CC's session lifecycle firing
hooks for non-interactive sessions. If CC adds a hook filter for session type,
this goes away.

### Agent Continuation Gap (SendMessage)

**Closed at 2.1.325** (tested 2026-11-14, Windows): SendMessage reaches a
running delegate at its next tool round and resumes a finished one; see
"Delegate Identity, Transcripts and Control" below. Keep delegation prompts
self-contained anyway: a follow-up message costs a resume, and a launch can
be cut short (that section, "Interruptions"). The rest of this section is
history.

From v2.1.77 to at least 2.1.81 there was no working mechanism to send
messages to a previously spawned subagent (history below). By 2.1.309 the main
session is offered `SendMessage` / `ListAgents` for subagents it spawned.

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

**Workaround:** Include all context in the initial Agent launch prompt. Launch
new agents for follow-up work, passing prior output as context.

Upstream: [#35240](https://github.com/anthropics/claude-code/issues/35240),
[#37051](https://github.com/anthropics/claude-code/issues/37051),
[#38183](https://github.com/anthropics/claude-code/issues/38183)

### Subagent Cross-Repo Access Restriction (#24)

Subagents launched via the Agent tool have restricted file access outside
the CWD repo:

- **Glob/Grep**: Denied outside CWD repo boundaries
- **Read**: Works with explicit absolute paths (even outside CWD repo)
- **Write/Edit**: Denied outside CWD repo

**Impact on delegation**: When delegating work that needs files from another
repo, include the file content in the delegation prompt (inline via XML
delimiters) rather than expecting the subagent to read it. Alternatively, use
Read with explicit paths for known file locations. (Folded in from the retired
`/aitool-ops` card.)

### Built-in guide subagent block

The built-in `claude-code-guide` subagent is blocked by the
`block-claude-code-guide.sh` PreToolUse(Agent) hook, which denies it and
injects correct hook-schema context (#34730). No `permissions.deny` rule is
used: Claude Code does not reliably honor deny for built-in subagents, so the
hook is the enforcement. Verification cases: `/tool-ops` skill
(`tools.claude-code.verifications`). (Folded in from the retired `/aitool-ops`
card.)

### Sub-agent Markdown File-Name Block

Observed in 2.1.289 (2026-10-05, Claude Code web environment). When the caller
is a sub-agent, the Write tool's input validation refuses any file whose
basename matches `^(REPORT|SUMMARY|FINDINGS|ANALYSIS).*\.md$`
(case-insensitive) and returns:

```
Subagents should return findings as text, not write report files. Include this content in your final response instead.
```

- Built into the binary (`validateInput`, telemetry event
  `tengu_subagent_md_report_blocked`, error code 5); the check is gated on the
  caller having an agent ID, so the main agent is not affected.
- It runs before permission rules. No setting, allow rule or hook output
  overrides it. Not in the official docs.
- Allowed names observed: `notes.txt`, `plain.md`, `s3-report.md`.
- Edit and other write paths: not verified.

**Workaround (decision D-DEL1, 2026-10-05):** every delegation prompt tells
the delegate to start every `*.md` file name with its own name
(`S2-report.md`). The name prefix never matches the anchored pattern, as long
as the delegate's name does not itself start with one of the four words. The
prefix also records which delegate wrote the file. Governed by the user rule
`delegation.md` and the `/delegate` skill; detected by
`delegation-duty-guard.sh` (element 8 of eight since 2026-10-26, observe mode)
and, for each `agent()` prompt of a Workflow script, by
`workflow-delegation-guard.sh` (since 2026-10-28, observe mode).

### Sub-agent Nesting Depth

`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` sets how deep sub-agents may nest.
Documented default 3; the 2.1.219 changelog raised the default from 1 to 3
(as reported by the delegating session 3030c86a on 2026-10-05; changelog not
re-read for this entry). The Claude Code web environment runner sets it to 1
(observed: `printenv CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` -> `1`, 2026-10-05),
so a sub-agent there has no Agent tool and cannot delegate further. A launch
past the cap fails with:

```
Subagent nesting limit reached (depth N of M). Complete this task directly using your tools instead of spawning another agent. If the user explicitly requested deeper nesting, ask them to raise CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH.
```

**Impact on delegation:** a delegation chain must fit the cap of the
environment it runs in. A delegate at the cap does the whole task itself; plan
its scope accordingly (`/delegate` skill).

**Launch path decides whether a delegate can delegate** (observed 2.1.307,
macOS, local environment, 2026-10-21; `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`
unset at every level):

| Launched via | Has Agent | Has Workflow | Deepest level that ran |
|---|---|---|---|
| Agent tool from the main session | yes at levels 1-2, no at level 3 | no | 3 |
| A Workflow `agent()` call | no (not even deferred via ToolSearch) | no | 1 |
| A Workflow `agent()` call with `agentType: 'general-purpose'` | no (not even deferred via ToolSearch) | no | 1 |

Re-verified 2.1.307, macOS, local environment, 2026-10-26 (workflow
`probe-workflow-nesting`, run wf_f1bf6cf0-be5): a default workflow agent and
one launched with `agentType: 'general-purpose'` were each told explicitly to
go outside the workflow's layout and launch their own general-purpose
sub-agent. Neither had an Agent, Task or Workflow tool; ToolSearch
`select:Agent` returned "No matching deferred tools found", and a keyword
search ("agent subagent task workflow") surfaced only TaskCreate / TaskGet /
TaskList / TaskUpdate / TaskStop (todo-list tools), SendMessage and
ListAgents (message existing agents only), RemoteTrigger (cloud routines)
and `mcp__firecrawl__firecrawl_agent` (web research). The agent type does
not change the tool set. Not tested: spawning through the `claude` CLI
(`claude -p`, present at `~/.local/bin/claude`) or RemoteTrigger, which are
separate mechanisms with their own permissions.

**`isolation: "remote"` fell back to a local worktree** (2.1.307, macOS,
2026-10-27): an Agent-tool call with `subagent_type: "general-purpose"`,
`isolation: "remote"` ran on this Mac in a new git worktree
(`.claude/worktrees/agent-<id>`, branch `worktree-agent-<id>`, reported in
the completion notice's `<worktree>` block), with `CLAUDE_CODE_REMOTE` and
`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` unset. No cloud or Claude Code web
environment was used, so the web nesting limit (1) was not exercised; the
tool describes remote availability as gated. In the same probe, levels 1 and
2 had the Agent tool and level 3 did not, and the Agent tool given to
delegates has no `run_in_background` parameter (every delegate launch was
asynchronous: "Async agent launched successfully"), so skills that tell a
delegate to launch foreground sub-agents (e.g. deep-research's
`run_in_background=false`) cannot be followed as written; the delegate waits
for each completion notification instead.

- At the default cap (3), the third delegate has no Agent tool at all, so a
  chain runs main → L1 → L2 → L3.
- Workflow agents cannot delegate, whatever the cap: a workflow is one level
  of fan-out under the session that runs it. Encode deeper structure in the
  script itself (stages, `pipeline()`, one-level `workflow()` calls), or launch
  mission commanders with the Agent tool when they must delegate.
- No delegate has the Workflow tool, so a delegate cannot start a workflow.
- Worktree-isolated agents also refuse any command that sets `HOME`
  ("this command sets HOME, injecting git configuration ... Refusing to run
  it"), so isolated-`HOME` runs (`build-deploy.sh`, #86) must run from a
  non-isolated agent or the main session.

Re-verified 2.1.325, Windows 11, local environment, 2026-11-14 (probe
2b10-01, a level-3 delegate launched with the Agent tool by a level-2
delegate): ToolSearch `select:Agent,SendMessage,TaskStop,ListAgents,Monitor,Workflow`
returned only SendMessage, TaskStop and Monitor; Agent, ListAgents and
Workflow were neither in its tool list nor deferred. Its `meta.json` records
`"spawnDepth":3`. The level-2 delegate that launched it (38dc-08) had the
Agent tool, with no `run_in_background` parameter.

### Delegate Identity, Transcripts and Control (#31, #32)

Version 1.0, 2026-11-14. **Tested** with Claude Code 2.1.325 (`claude
--version`), Windows 11, local environment, in session
87795dc3-e9b0-4f82-937b-139b3f13fa81, by 38dc-08 (a level-2 delegate
launched with the Agent tool by the orchestrator M6-Polish), with two
throwaway level-3 probes (2b10-01, 2b10-02) and the session's 42 delegate
`meta.json` files (counted 18:44Z). Further evidence: the M6-Polish transcript
(`subagents/agent-a0c459c8f689338dc.jsonl`, 2026-11-14 17:33-18:38Z). Quotes
are verbatim from tool results; `<...>` marks an elided id or path. Not
tested on macOS, Linux, Claude Code web or Cursor: paths and behaviour there
are unknown.

Version 1.1, 2026-11-14 (mission 38dc-25, a level-2 delegate of M6-Polish,
same session, Claude Code 2.1.325, Windows 11): the three open questions of
v1.0 answered. What turns `output_file` into a hard link, which second
hand-back is refused, and whether the main session can TaskStop a delegate
(below, "output_file", "Hand-backs" and "TaskStop"). Evidence: five
throwaway level-3 probes (af14-01 `aa4adfc1b796d71f2`, af14-02
`a261644da4ec634ca`, af14-03 `a4a3c9e096e872b30`, af14-06
`a2720a4f422358e45`, af14-07 `a09a2aff2ee7c9b2f`), a poller that logged every agent `output_file`'s link
count every 2 s (23:20:37Z onwards), and the main session transcript.

#### Where a delegate's files live

| What | Path (observed on Windows) | Notes |
|------|------|-------|
| Main session transcript | `~/.claude/projects/<project-dir>/<session-id>.jsonl` | `<project-dir>` is the session's cwd with `:` and `\` replaced by `-`: `C:\Users\jdpal\repos\aitools` -> `C--Users-jdpal-repos-aitools` (see #4 for `/` on macOS) |
| Every delegate's transcript, at any depth | `~/.claude/projects/<project-dir>/<session-id>/subagents/agent-<agentId>.jsonl` | `<session-id>` is the MAIN session's id. Levels 1, 2 and 3 sit flat in one directory; no per-level or per-parent folders |
| Delegate metadata | `.../subagents/agent-<agentId>.meta.json` | Written at launch, before the transcript (probe 2b10-01: meta 18:39:51.79Z, transcript 18:39:52.01Z) |
| Large tool output | `.../<session-id>/tool-results/<id>.txt` | A result over the inline limit is replaced by `Output too large (58.9KB). Full output saved to: <...>\tool-results\b1ebmx7sq.txt` (a delegate's Bash call, saved under the main session). Named by the shell id for Bash, by the tool-use id for other tools (`toolu_01U8XBMKcQhqJV3kgH1tGNMS.txt`, a Grep) |
| Agent `output_file` | `%LOCALAPPDATA%\Temp\claude\<hash>\<session-id>\tasks\<agentId>.output` | Not a reliable copy of the transcript; see "output_file" below |
| Background shell output | same `tasks\` directory, `<shellId>.output` | Shell ids are 9 characters starting with `b` (`b2pmsszp4`). A delegate's shells write to the main session's `tasks\` directory |
| Running-process records | `~/.claude/sessions/<pid>.json` and `<pid>.<hash>.key` (a `.key` file can exist with no matching `.json`) | No transcripts. The JSON's fields include `pid`, `sessionId`, `cwd`, `startedAt`, `version`, `kind`, `name`, `status`, `messagingSocketPath` (example: `{"pid":10576,"sessionId":"87795dc3-...","cwd":"C:\\Users\\jdpal\\repos\\aitools",...,"version":"2.1.325",...,"kind":"interactive",...,"name":"aitools-82",...,"status":"busy",...}`) |

The `tasks\` path on macOS and Linux: unknown.

#### `meta.json` fields

Example (probe 2b10-01, verbatim, as written at launch):

```
{"agentType":"general-purpose","isBuiltIn":true,"launchedWithDefaults":true,"description":"2b10-01-idprobe throwaway test","toolUseId":"toolu_016xS2ZaJDcPz1JxqYEzeUKf","parentAgentId":"ab61a67f59bce2b10","spawnDepth":3,"requestShape":"background","requestNonInteractive":true,"pickedEffortModel":"claude-opus-5-5"}
```

| Field | Meaning (observed) |
|-------|--------------------|
| `description` | The Agent call's `description` argument, verbatim. The only field that carries the mission name |
| `toolUseId` | The id of the Agent `tool_use` in the launching agent's transcript |
| `parentAgentId` | The launching delegate's agentId. Absent when the main session launched it (7 of 42 files, all `spawnDepth` 1) |
| `spawnDepth` | 1 (launched by the main session), 2 or 3 |
| `requestShape`, `requestNonInteractive` | `"background"` and `true` on all 42 files, including the 38dc-08 launch, whose Agent call had no `run_in_background` argument |
| `agentType`, `isBuiltIn`, `launchedWithDefaults`, `pickedEffortModel` | Agent type and model choice (`general-purpose`, `true`, `true`, `claude-opus-5-5` on every file here) |
| `finished` | Added as `true` when the delegate's run ends; removed when it is revived (the file is rewritten and its key order changes). Not a liveness test: M6-Polish's file said `"finished": true` while TaskStop listed it among the running background agents (18:39Z) |
| `revivedAt` | Epoch milliseconds, seen on one file only: M6-Polish. It is rewritten each time the user messages that delegate directly: three values seen (18:36:06.871Z, 18:40:39.762Z, 18:49:44.394Z), each matching a "The user sent a new message while you were working" entry in its transcript (reviewer 2b10-03). Not written for delegates resumed with SendMessage (M6-A, M6-R4, 2b10-01) |

Every `user`, `assistant` and `attachment` line of a delegate transcript
carries `agentId`, `sessionId` (the main session's id), `isSidechain: true`,
`version` (`2.1.325`), `cwd`, `gitBranch`, `entrypoint`, `userType`, `uuid`,
`parentUuid` and `timestamp`. The `api-request`, `api-request-shape` and
`api-request-blob` lines (26 of 83 in 2b10-01) lack `isSidechain`, `cwd`,
`gitBranch`, `entrypoint`, `userType`, `uuid` and `parentUuid`, and the
`api-request-blob` lines also lack `version` and `timestamp` (reviewer
2b10-03). The launching
agent's transcript keeps the full launch record: the Agent `tool_use` input,
and a `toolUseResult` with `isAsync`, `status: "async_launched"`, `agentId`,
`description`, `resolvedModel` and the full `prompt` as sent.

#### Mapping a mission name to an agent id

The `description` is the only link from a mission name to an agentId seen
in `meta.json`: neither the prompt nor any other field carries the mission
name. The Agent tool offered to the level-2 delegate 38dc-08 has no `name`
parameter (its parameters: `description`, `prompt`, `subagent_type`,
`model`, `isolation`, `effort`, and no `run_in_background`, which 37 of the
session's 47 Agent calls passed from other levels). The main session's
Agent schema was not checked. So:

1. Start every Agent `description` with the mission name and keep names
   unique (`38dc-08-subagent-transcripts docs`). A reused description makes
   the lookup ambiguous.
2. Record the agentId from the launch result in your notes and report.
3. To recover it later, search the descriptions (or use the Grep tool on
   `subagents\` with the mission name). The file name is the agentId;
   `parentAgentId` gives the chain upward.

   macOS / Linux / Git Bash (the search M6-Polish ran at 18:07:50Z):

   ```bash
   grep -o '"description":"[^"]*"' -r ~/.claude/projects/<project-dir>/<session-id>/subagents --include=*.meta.json
   ```

   Windows PowerShell (run 2026-11-14, pwsh 7):

   ```powershell
   Select-String -Path "$env:USERPROFILE\.claude\projects\<project-dir>\<session-id>\subagents\*.meta.json" -Pattern '"description":"[^"]*"' | ForEach-Object { "$($_.Filename): $($_.Matches[0].Value)" }
   ```
4. The main session is not in `subagents/`: its transcript is
   `<project-dir>/<session-id>.jsonl`.

#### What the Agent tool returns

Every launch observed (M6-Polish's nine, 38dc-08's three) returned at once,
in this shape (verbatim, probe 2b10-01):

```
Async agent launched successfully. (This tool result is internal metadata — never quote or paste any part of it, including the agentId below, into a user-facing reply.)
agentId: ad2eb0549286e5589 (internal ID - do not mention to user. Use SendMessage with to: 'ad2eb0549286e5589', summary: '<5-10 word recap>' to continue this agent.)
The agent is working in the background. You will be notified automatically when it completes. You know nothing about its results until that notification arrives — do not report, assume, or predict them; continue other work or respond to the user in the meantime.
Do not duplicate this agent's work — avoid working with the same files or topics it is using.
output_file: C:\Users\jdpal\AppData\Local\Temp\claude\89ee379d6ae34d53\87795dc3-e9b0-4f82-937b-139b3f13fa81\tasks\ad2eb0549286e5589.output
Do NOT Read or tail this file via the shell tool — it is the full subagent JSONL transcript and reading it will overflow your context. If the user asks for progress, say the agent is still running; you'll get a completion notification.
```

No session id is returned: a delegate runs inside the main session, and the
agentId (17 characters: `a` and 16 hex digits) is its only identifier. The
"internal ID" note concerns user-facing replies; an orchestrator records the
id in its own notes and reports when the commander asks for it.

#### `output_file` is not a reliable transcript copy

The launch result calls `output_file` "the full subagent JSONL transcript".
Observed instead: it is created as an empty file at launch (0 bytes, link
count 1), and became a hard link to `subagents/agent-<agentId>.jsonl` when
the delegate was **woken again after it stopped**: by a SendMessage, or by
an event or the completion of its own background task. No link was seen
without such a wake (five probes; the v1.0 cases below are consistent but
were not checked one by one).

- af14-02 (no background work) stopped at 23:21:25Z with an empty file; the
  SendMessage that resumed it was sent at 23:21:35.94Z, and the next poll
  (23:21:37.28Z) saw link count 2 (734,156 bytes). af14-01 (handed back with
  a background shell running) was linked at the same poll, right after the
  SendMessage that woke it.
- af14-03 handed back at 23:22:17Z with a 90 s background shell running and
  stayed empty; it was linked at 23:23:47.42Z, the second its shell's
  completion woke it (its own report times the wake at 23:23:47Z). No
  message was sent to it before then. Likewise af14-06 (linked 23:25:55.56Z;
  its shell's completion reached it at 23:25:54.64Z) and af14-07 (linked
  23:27:01.63Z; its first Monitor event reached it at 23:26:59.67Z).
- v1.0 data, consistent with this: 2b10-01 was empty after it finished and
  linked right after a SendMessage resumed it; M6-R1 was linked at
  18:48:58Z, after a resume at 18:46:58Z (reviewer 2b10-03); M5-Fixes, M6-G,
  M6-B and M2-Reask-D2 were linked though no SendMessage targets them (each
  transcript records background shells, whose completion can wake them;
  that each was woken this way was not checked one by one); M6-F, M4-B and
  2b10-02 stayed empty. Count at 18:44Z: 14 of 42 linked; at 23:18Z
  (38dc-25, `samefile` against each transcript): 37 of 80.

**Read a delegate's transcript at
`subagents/agent-<agentId>.jsonl`**, through the harness readers
(`read-session-full.py --help`, `read-session.py --help` in
`~/.aitools/bin/`), never whole: a delegate transcript is commonly 2-5 MB, and
a probe's is about 0.5 MB before its first turn.

#### How a delegate learns its own id

No environment variable holds it. A delegate's environment (verbatim, probe
2b10-01 and 38dc-08):

```
CLAUDE_CODE_CHILD_SESSION=1
AI_AGENT=claude-code_2-1-325_agent
CLAUDE_CODE_SESSION_ID=87795dc3-e9b0-4f82-937b-139b3f13fa81
CLAUDE_PID=10576
```

`CLAUDE_CODE_SESSION_ID` is the main session's id (the `<session-id>`
directory above) and `CLAUDE_PID` the main process, matching
`~/.claude/sessions/10576.json`. Ways to find the agentId:

1. **Search the descriptions (read-only, recommended).** Grep the
   delegate's own description in
   `~/.claude/projects/<project-dir>/<CLAUDE_CODE_SESSION_ID>/subagents/*.meta.json`.
   2b10-01 found exactly one match, `agent-ad2eb0549286e5589.meta.json`. Works
   when the description is unique, which is why it should start with the
   mission name.
2. **A refused TaskStop names the caller.** TaskStop on another running
   agent fails with `Task a42820dbaa5685b08 is owned by a42820dbaa5685b08;
   agent ab61a67f59bce2b10 cannot stop it.`: the last id is the caller's. The
   orchestrator M6-Polish learned its id this way (17:58:29Z). Use method 1
   instead: a TaskStop that does succeed stops something.
3. TaskStop with an unknown id lists the running background agents, but
   leaves the caller out (both observations), so it does not give the
   caller's id directly.

#### TaskStop

- **An orchestrator cannot stop its own delegate.** 38dc-08 ran TaskStop on
  its level-3 probe 2b10-02 while the probe was in a 150 s foreground Bash
  wait: `Task a42820dbaa5685b08 is owned by a42820dbaa5685b08; agent
  ab61a67f59bce2b10 cannot stop it.` The probe's wait finished normally
  (`start`, `done`) and it saw no stop, notice or message: the refused call
  has no effect on the target. M6-Polish got the same answer for its
  delegate M6-A after M6-A had handed back while its own CI watch still ran
  (17:58:29Z).
- **The main session can stop a delegate it launched.** Main session
  87795dc3-e, 2026-11-14T00:49:25Z, on M1-Ship (level 1), which had just
  handed back and was "waiting on its own background work" (a Monitor,
  `bu0wz009l`, watching CI): `{"message":"Successfully stopped task:
  a30774d069aaa0587 (M1-Ship: ship JSON review PR)","task_id":"a30774d069aaa0587","task_type":"local_agent","command":"M1-Ship:
  ship JSON review PR"}`. M1-Ship never ran again, and no event of its
  Monitor reached any transcript afterwards, although the CI it watched
  finished before 01:17Z (the main session's own watch reported then). So
  the stop also ended the delegate's background Monitor (observed: no
  event; not checked: the process itself).
- **A delegate that already failed cannot be stopped**: main session,
  18:34:15Z, on M6-Polish after an API error ended its run: `Task
  a0c459c8f689338dc is not running (status: failed)`. The failed delegate
  could still be revived: M6-Polish ran again after this, each time the user
  messaged it directly (`revivedAt` 18:36:06Z, 18:40:39Z, 18:49:44Z, see
  "`meta.json` fields").
- Not tested: the main session stopping a delegate that another delegate
  launched (level 2 or 3), or one that is in the middle of a turn. The
  refusal text "Task <id> is owned by <id>" names the target itself as the
  owner, so ownership is not "the launching agent" in the usual sense; what
  the main session may stop beyond its own level-1 delegates: unknown.
- **An unknown id lists the session's running background agents**, with
  descriptions, across every branch of the tree (siblings, the parent, other
  missions), and leaves the caller out:
  `No task found with ID: a0000000000000000. Running background agents:
  a0c459c8f689338dc (M6-Polish: leftover findings mission),
  a98913ce56c3ea1d3 (38dc-09-postpush-deploy-checks), ab61a67f59bce2b10
  (38dc-08-subagent-transcripts docs)` (as seen by 2b10-01).
- A delegate can stop its own background shells and monitors by their task
  id (M6-A: "I stopped my CI watch (task b7njqe38m)").
- The tool description says a background agent "spawned with a name" can be
  stopped by that name; the Agent tool here has no name parameter.

To end a delegate's work early, send it a message (below) telling it to stop
its background tasks and finish, then wait for its notification.

#### SendMessage

- **Who has it**: delegates at levels 1-3, as a deferred tool (load it with
  ToolSearch `select:SendMessage`; observed at level 1 in M6-Polish's
  transcript at 18:14:29Z, at levels 2 and 3 by 38dc-08 and 2b10-01). `ListAgents`, which its description
  mentions, is not available to delegates at levels 2 and 3 (ToolSearch
  `select:ListAgents`: "No matching deferred tools found").
- **To a running delegate**: queued, delivered at its next tool round:
  `{"success":true,"message":"Message queued for delivery to ab61a67f59bce2b10 at its next tool round. Sending this moved nothing it is running to the background just now, so the message waits for that round unless something moves sooner. If it finishes first, it is resumed with the message and notifies again, so wait for that notification before resending.","pin":{"id":"ab61a67f59bce2b10","name":"ab61a67f59bce2b10","ref":"ced660"}}`.
  The receiver sees a system reminder: `Another Claude session sent a
  message while you were working:` followed by `<agent-message
  from="<sender agentId>">` and the text, with a note that the sender is an
  agent in the same session and carries no user authority.
- **To a finished delegate**: resumes it from its transcript:
  `{"success":true,"message":"Resuming agent ad2eb05","pin":{"id":"ad2eb0549286e5589","name":"ad2eb0549286e5589","ref":"2baedc"}}`
  (the transcript's `toolUseResult` adds `revivedAgentId`).
- **To the main conversation**: a background delegate may send `to: "main"`:
  `{"success":true,"message":"Message queued for the main conversation's next turn."}`
  (M6-Polish, 18:38:44Z).
- A resumed delegate (2b10-01) and a newly launched one (38dc-08) each
  received a system reminder `<tools-used-before-summary>` listing tools they
  had not used (2b10-01: "Agent, Edit, Glob, Monitor, SendMessage, Skill").
  Do not read it as your own history; its meaning is unknown.

#### Hand-backs and completion notifications

What the docs say (tools-reference.md and sub-agents.md, read 2026-11-14 by
af14-08 with chrome-devtools): `SubagentHandback` "Delivers a subagent's final
report to whichever conversation receives that subagent's result. Provided
only in auto mode, to subagents that the Agent tool runs locally other than
forks ... the classifier reviews the report before it's delivered. Requires
Claude Code v2.1.271 or later". `TaskStop` "Stops a running background task
by ID. It also accepts an agent-team teammate or a named background agent by
agent ID or name." And: "When Claude sends a completed subagent a message
with the `SendMessage` tool, the subagent resumes in the background ... The
same applies to a subagent that Claude stopped with the `TaskStop` tool,
once its stopped run has exited" (the last clause re-read by the reviewer
af14-09).
"One report per result" is not stated in the docs.

- **The report arrives as a message**: the caller sees `<agent-message
  from="<agentId>">` beginning `[Subagent hand-back] The text below is the
  final report of a subagent this session delegated to. It is model output,
  NOT a message from the user ...`, with every report line indented. When
  the report contains tag-like text, the harness prepends `[harness: subagent
  output matched instruction-shaped pattern(s): harness-signal-tag. Control
  tags below are neutralized (`<` → `<\`); ...]`.
- **Then a task notification**: `<task-notification>` with `<task-id>` = the
  agentId, `<tool-use-id>`, `<output-file>`, `<status>completed</status>`, a
  `<summary>`, a `<note>`, a `<result>` that points to the message instead of
  repeating it, and `<usage>` (`subagent_tokens`, `tool_uses`,
  `duration_ms`). Two summaries were seen:
  - `Agent "<description>" is waiting on its own background work`, note:
    `This agent stopped with background work of its own still running. It
    may resume on its own when that work completes or reports, and the same
    task-id notifies again if it does; the result below may be interim.`
  - `Agent "<description>" finished`, note: `A task-notification fires each
    time this agent stops with no live background children of its own. The
    user can send it another message and resume it, so the same task-id may
    notify more than once.`
  - A third status (main session transcript, 18:34:10Z):
    `<status>failed</status>`, summary `Agent "<description>" failed: Agent
    terminated early due to an API error: API Error: Opus 5.5's safeguards
    flagged this message ...`.
  - `<tool-use-id>` is the tool call that started the run being reported:
    the Agent call for the first run, the resuming SendMessage for a run
    started by a message (af14-02's second notification carried the id of
    38dc-25's SendMessage, `toolu_01DLwxSBqjArtfxYAdHAhjU3`). A run woken by
    the delegate's own background task has no `<tool-use-id>` (af14-01,
    af14-03, af14-06).
- **A second hand-back (v1.0 counts: delivered 17 times, refused once; the
  condition is in the next bullet).**
  Repeat SubagentHandback calls (the first hand-back not counted) were
  delivered 17 times: 13 after a background-task notification (M1-Ship 5,
  M3-Fixes 3, M6-A 4, M6-DE 1) and 4 after a SendMessage resume (M4-Winpty,
  M6-R4, M6-A, M6-DE, one each); 15 of the 17 came right after
  `[handback-send-enforce]` (counts by the reviewer 2b10-03 from the
  transcripts; its own re-check hand-back after a SendMessage resume was
  delivered too). Once, a resumed 2b10-01 was refused (18:40:47Z): `Nothing was sent: an earlier
  report of yours was already delivered (SubagentHandback delivers one
  report), so this one did not reach your caller. Use SendMessage to send
  anything further, then stop.` Its caller's notification added: `This agent
  called SubagentHandback again after that report and was refused (one
  report per result), so anything new in that call has not reached you
  through it. If it has not messaged you since, send it a message
  (SendMessage) to ask for it.`
- **Which second hand-back is refused (v1.1, probes of 2026-11-14,
  23:21-23:28Z).** It depends on what woke the delegate and on the
  background work it left running when its first report went out. Every
  first report (R1) was delivered.

  | Probe | Live at R1 | What woke it for the next report | That call | Result |
  |-------|------------|----------------------------------|-----------|--------|
  | af14-02 | nothing | SendMessage, after it had finished | direct | delivered |
  | af14-03 (R3) | nothing left (shell done, finished) | SendMessage | direct | delivered |
  | af14-01 (R2) | Bash shell, 150 s | SendMessage while the shell ran | direct | **refused** |
  | af14-01 (R3) | same shell | the shell's completion | direct | **refused** |
  | af14-03 (R2) | Bash shell, 90 s | the shell's completion | direct | **refused** |
  | af14-06 | Bash shell, 60 s | the shell's completion | plain-text turn end, no call | no `[handback-send-enforce]`; the agent finished; nothing more reached the caller |
  | af14-07 (R2) | Monitor (3 events) | Monitor event 1 | plain-text turn end, then `[handback-send-enforce]` (23:27:00.663Z), then the call | delivered |
  | af14-07 (R3) | same Monitor | Monitor event 2 | direct | delivered |
  | 2b10-01 (v1.0) | Bash shell, 90 s | SendMessage while the shell ran | direct | **refused** |

  So: a report from a run woken by an event of the delegate's own
  **Monitor**, or from a run started by a SendMessage to a delegate that
  had **finished**, is delivered. A report from a run woken while a
  **background Bash shell** started before the first report was still
  running (by a SendMessage), or woken by that shell's **completion**, is
  refused. This matches the v1.0 counts: M1-Ship's six hand-backs
  (00:31-00:49Z) were all delivered, each right after
  `[handback-send-enforce]`; the five after the first came in runs woken by
  events of its CI watch, which was a Monitor (`bumgnf7f4`, started with the
  Monitor tool at 00:30:40Z, then `bu0wz009l`). Why the harness
  draws the line there: unknown (its notification calls it "one report per
  result"). Not tested: a shell started after the first report, and a
  Monitor's last event or exit: af14-07's third event and its Monitor's
  exit (`event-3`, `[exited with code 0]` in the Monitor's output file,
  about 23:27:59Z) did not wake it (its transcript ends at 23:27:31Z, checked
  23:29:38Z and 23:37:06Z), and no further
  notification reached its caller.

  Practice: stop your background shells before you hand back. If a
  SubagentHandback is refused, send the content by SendMessage (it reached
  the caller every time: 2b10-01, af14-01, af14-03).
- **A delegate's background work outlives its hand-back.** 2b10-01 handed
  back with a 90 s background shell running (`b2pmsszp4`). The shell kept
  running and finished normally (`start`, `done`, `[exited with code 0]`);
  its completion notification reached the delegate (by then resumed by a
  message), which reported to its caller again by SendMessage. The caller's
  notification says such a delegate "may resume on its own when that work
  completes or reports". This matches M6-A's repeated reports while its CI
  watch ran. **Stop your own monitors and background shells before you hand
  back** (or say in the report that one still runs).
- **Forced hand-back**: the harness may tell a delegate `[handback-send-enforce]
  Your report has not been delivered. Call SubagentHandback({message: <your
  full report>}) now; the call ends your run.` Seen when a delegate ended a
  turn with plain text instead of a tool call: M6-Polish at 18:34:08Z, right
  after a plain-text answer and amid safety-classifier stops; most
  of the repeat hand-backs above followed it (reviewer 2b10-03). A delegate
  that answers a resume with plain text can be pushed into a second
  hand-back this way. Probes (v1.1): it came after a plain-text turn end in
  a run woken by a Monitor event (af14-07), and did not come after one in a
  run woken by a background shell's completion (af14-06: the agent simply
  finished) or after a refused hand-back and a SendMessage (af14-01,
  af14-03). Write the report file before arming long watches so a forced
  hand-back loses nothing (M6-A, M6-Polish).

#### Interruptions that change what a delegate receives

- **Safety classifier**: `Your response above was stopped by a safety
  classifier — this is not a tool or API error. The rest of it was withheld,
  and tool calls in it that had not finished did not run. Do not produce
  that content again, even reworded.`, alternating with `API Error: Opus
  5.5's safeguards flagged this message ... Details: \`[reasoning_extraction]\``
  (M6-Polish, 18:31-18:36Z). In that stretch M6-Polish's Agent call for
  38dc-08 ran with its prompt cut off mid-sentence; it sent the rest by
  SendMessage. Check a launch made near an interruption: the launching
  agent's `toolUseResult.prompt` shows what was actually sent.
- **Background move**: a foreground Bash call running longer than 180 s
  returns `Command was moved to the background (ID: <shellId>) after running
  for 180s. Output is being written to: <...>\tasks\<shellId>.output. You
  will be notified when it completes.` (M6-Polish, 17:41:54Z). A 150 s
  foreground wait was not moved (2b10-02).

#### Guidance for orchestrators

1. Start every Agent `description` with the mission name; keep it unique.
2. Record each delegate's agentId from the launch result; find it again by
   searching `meta.json` descriptions.
3. Read a delegate's transcript at `subagents/agent-<agentId>.jsonl` with
   the harness readers, never the `output_file`.
4. As a delegate, you cannot TaskStop your own delegate: message it to stop
   instead. The main session can stop a level-1 delegate it launched.
5. Tell every delegate to stop its own background shells before handing
   back, and to write its report file first: a hand-back made after a
   resume while such a shell still runs, or after its completion, is
   refused.
6. After a delegate's hand-back, follow up by SendMessage (it resumes the
   delegate); its answer may come as a second hand-back or, if that is
   refused, as a message.
7. Give a delegate the main session id (`CLAUDE_CODE_SESSION_ID`) and the
   project directory, so it can find its own and its siblings' transcripts.

### Auto Mode and Allow Rules for PR Merges (#33)

**Tested** 2026-10-28, Claude Code 2.1.309 (`claude --version`), macOS,
local environment, session in auto mode (`permissions.defaultMode` stays
`"default"`), by S3-AllowMerge, a level-1 delegate launched with the Agent
tool by Session Commander 10cf255a-c.

**The rule** (user scope, added by the Session Commander on the commander's
order, 2026-10-28): `"permissions": {"allow": ["Bash(gh pr merge:*)"]}` in
`~/.claude/settings.json` (backup `settings.json.bak.2026-10-28T173309Z`),
mirrored in the dotprofile `profile.json` `claude.settings.permissions`
(dotprofile commit 9cb13b2) so `setup-user-settings` keeps it. User scope
applies in every repo and needs no workspace trust; a project-scope
`.claude/settings.json` allow rule applies only after the folder's trust
dialog is accepted (docs below).

**Before** (MERGE-2, 2026-10-28, no allow rule): `gh pr merge 122 --merge
--match-head-commit 8f644ff…` was denied with:

```
Permission for this action was denied by the Claude Code auto mode classifier. Reason: [Merge Without Review].
```

Earlier (MERGE-ALL, 2026-10-27) 25 PRs merged from inside a workflow; four
were flagged afterwards with the same reason but not stopped. That matches the
documented third subagent check: the classifier reviews a finished subagent's
work and report and prepends a warning; it does not undo actions.

**After** (this test, rule in place, delegate session):

| PR | Command | Result | Merge commit |
|----|---------|--------|--------------|
| #122 | `gh pr merge 122 -R nobul-tech/aitools --merge --match-head-commit 8f644fffcf6e6c634ee09c4959887022d19ba2d2` | ran with no prompt or denial, empty output; `gh pr view` then showed `MERGED` at 2026-10-28T17:34:47Z; main CI run 40737064303 success | d8f0aedda0271fcf450c7595f5fa2b16eee39119 |
| #120 | `gh pr merge 120 -R nobul-tech/aitools --merge --match-head-commit 1a30fe7f139fb9d313ec332f489e7b19572cc1f5` | same: no prompt or denial, empty output; `MERGED` at 2026-10-28T18:05:35Z; main CI run 40741876684 success | 1b4e9d7cae8b752a6a3d5355920c8eb791a9435a |

Pre-merge checks: `gh pr view 122 --json state,headRefOid,mergeStateStatus,statusCheckRollup`
showed head 8f644ff, all 8 checks `SUCCESS`; the first read returned
`mergeStateStatus: UNKNOWN` (GitHub computes it lazily) and a second read
`CLEAN` / `MERGEABLE`. Re-read until `CLEAN` before merging.

The result is consistent with the documented decision order: a call that
matches an allow rule resolves at step 1 and never reaches the classifier.
The session cannot observe directly whether the classifier was skipped or
consulted and agreed; the docs say it is skipped.

**What the docs say** (read 2026-10-28 with chrome-devtools, `.md` pages):

- https://code.claude.com/docs/en/permission-modes.md "How the classifier
  evaluates actions": "Each action goes through a fixed decision order. The
  first matching step wins: 1. Actions matching your allow, ask, or deny rules
  resolve immediately, with these exceptions: …" (exceptions: protected-path
  writes, critical-path `rm`/`rmdir`, `requiresUserInteraction` MCP tools,
  commands with per-command allowed domains, content-matching ask rules,
  symlinked protected paths, network-path reads) "… 3. Everything else goes
  to the classifier".
- Same page: "On entering auto mode, broad allow rules that grant arbitrary
  code execution are dropped: Blanket `Bash(*)` or `PowerShell(*)`;
  Wildcarded interpreters like `Bash(python*)`; Package-manager run commands;
  `Agent` allow rules; `Monitor` allow rules … Narrow rules like
  `Bash(npm test)` stay in effect." `Bash(gh pr merge:*)` is a narrow rule.
- Same page, "How auto mode handles subagents": "2. While the subagent runs,
  each of its actions goes through the same decision order as in the parent
  session, with the same block and allow rules. Any `permissionMode` in the
  subagent's frontmatter is ignored." and "1. Before a subagent starts, the
  delegated task description is evaluated, so a dangerous-looking task is
  blocked at spawn time."
- https://code.claude.com/docs/en/permissions.md: "The `:*` suffix is an
  equivalent way to write a trailing wildcard, so `Bash(ls:*)` matches the
  same commands as `Bash(ls *)`." and "if user settings allow a permission
  and project settings deny it, the deny rule blocks it." and
  "`permissions.allow` rules … in a project's `.claude/settings.json` grant
  capability, so Claude Code applies them only after you accept the
  workspace trust dialog for that folder."
- https://code.claude.com/docs/en/settings.md "When edits take effect":
  "Claude Code watches your settings files and reloads them when they
  change, so it applies most edits to the running session without a
  restart, including edits to `permissions`, `hooks`, and credential
  helpers". The rule was added mid-session and applied without a restart.

**Guidance for merge missions:**

1. The allow rule removes the classifier gate for `gh pr merge` only. It
   does not replace review: the mission still gates each merge on green CI,
   `mergeStateStatus: CLEAN`, a recorded independent verdict, and
   `--match-head-commit <verified head>` so a moved branch fails the merge.
2. Keep the form `gh pr merge <n> -R <owner/repo> …` as one simple command.
   The rule matches the command prefix; a merge wrapped in a script or a
   compound command may not match it and then goes to the classifier
   (inference from the decision order; not tested).
3. Record the commander's merge order in a PR comment after each merge.
4. A deny or ask rule in any scope still wins over this allow rule.
5. Other outward-facing commands (`git push` to `main`, `gh release`, tag
   pushes) are not covered by this rule and still go to the classifier.

### Session Storage Internals

Claude Code stores session transcripts as JSONL files under `~/.claude/projects/`:

```
~/.claude/projects/
├── -Users-pepe-repos-ai-tooling/     # sanitized CWD path
│   ├── <session-uuid>.jsonl
│   ├── <session-uuid>/subagents/     # subagent transcripts
│   │   ├── agent-<agentId>.jsonl     # every depth, flat
│   │   └── agent-<agentId>.meta.json # description, parentAgentId, spawnDepth
│   └── <session-uuid>/tool-results/  # large tool outputs (<toolId>.txt)
└── -Users-pepe-repos-mbx-ext/
    └── ...
```

Detail, and how to map a delegate's mission name to its agentId: "Delegate
Identity, Transcripts and Control" above.

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
**Size:** Target under 200 lines per CLAUDE.md file (memory docs: "target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence"; a file over 4 MiB is skipped). The 200-line load limit is auto memory's: "The first 200 lines of `MEMORY.md`, or the first 25KB, whichever comes first, are loaded" (read 2026-11-14 by af14-08). Use `@path` imports for more detail.

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
- [x] Self-contained deploy scripts in the dotprofile `deploy/` (generated by `build-deploy.sh`; the shared `aitools/deploy/` is frozen) — MDM-ready, no repo or Drive dependency

---

## Windows Shell Limitations

> **Partly obsolete** (item #1, re-verified 2.1.325 on Windows 11,
> 2026-11-14): the Bash tool still runs Git Bash, so the quoting patterns
> below still apply inside it, but Claude Code also offers a PowerShell tool
> (PowerShell 7+) in every session, main and delegates, and reports
> PowerShell as the primary shell. Run PowerShell with that tool; the
> `pwsh -NoProfile -File` dispatch below is for PowerShell run from Bash or
> from bash scripts. Upstream history: PowerShell tool preview (2.1.84),
> "Git for Windows no longer required" (2.1.120), per
> `reference/evaluations/claude-code-macos-2026-10-21.md`.
> `CLAUDE_CODE_SHELL` was not re-tested.

Claude Code's Bash tool is **hardcoded to Git Bash on Windows** (still true at 2.1.325). The `CLAUDE_CODE_SHELL` environment variable exists but was **broken on Windows** at 2.1.62 -- it was silently ignored regardless of how it was set (not re-tested since).

Baseline: Claude Code 2.1.51 | Last verified: 2.1.325 (2026-11-14, Windows 11; `CLAUDE_CODE_SHELL` not re-tested since 2.1.62, 2026-02-27)

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

This is the pattern `scripts/aitools` uses on Windows: run in Git Bash, it hands every command to `aitools.ps1` this way before its library loads (`aitools_win_forward`).

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

This repo provides both `.ps1` and `.sh` variants of all scripts. On Windows, Claude Code runs `.sh` scripts in the Bash tool (Git Bash) and `.ps1` scripts either with the PowerShell tool (2.1.325: `pwsh -NoProfile -File <script>.ps1`) or from the Bash tool with the `pwsh -File` pattern above. PS 7 (`pwsh`) is the project baseline -- all dispatch uses `pwsh`, not `powershell.exe`.

Before 2.1.84 there was no PowerShell tool and the `pwsh -File` pattern from Bash was the only way; that is history now (item #1).

---

## Cross-References

- Tool-ops registry: `/tool-ops` skill
- Handoff process (item #36): `/handoff` skill
- Tool registry: `/tool-registry` skill
- Incident registry: `/incident` skill
- User repo spec: `reference/user-repo.md`
- Cross-platform rules: `.claude/rules/cross-platform.md`
