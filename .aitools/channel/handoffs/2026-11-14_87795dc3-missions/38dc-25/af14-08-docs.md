# af14-08-docs v1.0 — Claude Code docs, eight questions, verbatim

**Intent**: **Purpose**: verbatim, dated, URL-cited quotes from the official Claude Code docs
(code.claude.com) that settle eight open questions for 38dc-25. **Scope**: the eight questions
of mission af14-08-cc-docs-read. NOT repo edits, NOT interpretation beyond the page ("not
stated" where the page is silent), NOT incident filing. **Audience**: 38dc-25.

- Author: af14-08 (delegated by 38dc-25). Version 1.0, 2026-11-14.
- Method: Chrome DevTools MCP (own page, pageId 9, closed at the end), Markdown pages
  `https://code.claude.com/docs/en/<page>.md`, text searched with `evaluate_script` over
  `document.body.innerText`. No WebFetch, no Firecrawl. Quotes are copied from the script
  output, unedited (Markdown link syntax kept).
- Read times (UTC, 2026-11-14): changelog read just before 23:33:47Z; every other page
  between 23:33:47Z and 23:35:09Z (clock read with `date -u` at both points).
- Installed Claude Code here: 2.1.325. The changelog's newest entry is **2.1.325**,
  November 13, 2026, so the docs match the installed version.

Pages read: `changelog.md`, `memory.md`, `hooks.md`, `permissions.md`, `settings.md`,
`sub-agents.md`, `tools-reference.md`, `env-vars.md`, `setup.md`. None failed.

---

## Q1. Changelog: 2.1.59, 2.1.63, 2.1.68; first effort-level setting

URL: https://code.claude.com/docs/en/changelog.md (read ~23:32Z). The page says it "is
generated from the [CHANGELOG.md on GitHub](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)".

**2.1.59** — "February 26, 2026"
> * Claude automatically saves useful context to auto-memory. Manage with /memory
> * Added `/copy` command to show an interactive picker when code blocks are present, allowing selection of individual code blocks or the full response.
> * Improved "always allow" prefix suggestions for compound bash commands (e.g. `cd /tmp && git fetch && git push`) to compute smarter per-subcommand prefixes instead of treating the whole command as one
> * Improved ordering of short task lists
> * Improved memory usage in multi-agent sessions by releasing completed subagent task state
> * Fixed MCP OAuth token refresh race condition when running multiple Claude Code instances simultaneously
> * Fixed shell commands not showing a clear error message when the working directory has been deleted
> * Fixed config file corruption that could wipe authentication when multiple Claude Code instances ran simultaneously

Nothing on effort, HTTP hooks, `InstructionsLoaded` or `agent_id`.

**2.1.63** — "February 28, 2026". Relevant lines:
> * Added HTTP hooks, which can POST JSON to a URL and receive JSON instead of running a shell command
> * Added `ENABLE_CLAUDEAI_MCP_SERVERS=false` env var to opt out from making claude.ai MCP servers available
> * Project configs & auto memory now shared across git worktrees of the same repository

(Also: `/simplify` and `/batch` bundled commands, MCP OAuth URL paste fallback, `/copy`
"Always copy full response", "17 bug fixes" — mostly memory/listener leaks, and
"Fixed `/clear` not resetting cached skills".) Nothing on effort, `InstructionsLoaded`, `agent_id`.

**2.1.68** — "March 4, 2026" (whole entry):
> * Opus 4.6 now defaults to medium effort for Max and Team subscribers. Medium effort works well for most tasks — it's the sweet spot between speed and thoroughness. You can change this anytime with `/model`
> * Re-introduced the "ultrathink" keyword to enable high effort for the next turn
> * Removed Opus 4 and 4.1 from Claude Code on the first-party API — users with these models pinned are automatically moved to Opus 4.6

Nothing on `effortLevel`, HTTP hooks, `InstructionsLoaded`, `agent_id`.

**`InstructionsLoaded` and `agent_id` are in 2.1.69 ("March 5, 2026")**, not 2.1.68:
> * Added `InstructionsLoaded` hook event that fires when CLAUDE.md or `.claude/rules/*.md` files are loaded into context
> * Added `agent_id` (for subagents) and `agent_type` (for subagents and `--agent`) to hook events

Earlier `agent_id`: 2.0.42 (November 15, 2025): "Added `agent_id` and `agent_transcript_path` fields to `SubagentStop` hooks."

**Effort, oldest mentions first** (every changelog line containing "effort", up to 2.1.120):
- 2.1.42 (February 13, 2026): "Added one-time Opus 4.6 effort callout for eligible users" (oldest "effort" line in the whole changelog)
- 2.1.49: "SDK model info now includes `supportsEffort`, `supportedEffortLevels`, and `supportsAdaptiveThinking` fields so consumers can discover model capabilities."
- 2.1.68 (March 4, 2026): the medium-effort default and "ultrathink" lines above
- 2.1.69 (March 5, 2026): "Added effort level display (e.g., "with low effort") to the logo and spinner, making it easier to see which effort setting is active"
- 2.1.72 (March 10, 2026): "Fixed `--effort` CLI flag being reset by unrelated settings writes on startup"; "Simplified effort levels to low/medium/high (removed max) ... Use `/effort auto` to reset to default"
- 2.1.73: "Improved `/effort` to work while Claude is responding, matching `/model` behavior"
- 2.1.76 (March 14, 2026): "Added `/effort` slash command to set model effort level"
- 2.1.80: "Added `effort` frontmatter support for skills and slash commands to override the model effort level when invoked"
- The literal key `effortLevel` first appears in 2.1.203 (July 7, 2026): "Fixed background sessions ignoring `effortLevel` changes in settings.json when forked through the daemon" (later: 2.1.280, 2.1.317).

**Plain answer**: stated: HTTP hooks were added in 2.1.63; `InstructionsLoaded` and hook
`agent_id` were added in 2.1.69, not 2.1.68; 2.1.68 only changed the Opus 4.6 default to medium
effort and brought back "ultrathink". **No changelog entry announces an `effortLevel` settings
key.** The first line that calls effort a *setting* is 2.1.69 ("which effort setting is
active"). The first line that ties effort to settings is 2.1.72 (`--effort` flag being reset by
"settings writes"). The key `effortLevel` first appears by name in 2.1.203, in a fix that
assumes it already exists.

---

## Q2. Memory: how CLAUDE.md levels combine; "200 lines"

URL: https://code.claude.com/docs/en/memory.md (read 23:33:47Z–23:35:09Z).

Combination (all load, concatenated, no override):
> All discovered files are concatenated into context rather than overriding each other. Across the directory tree, content is ordered from the filesystem root down to your working directory. For the `foo/bar/` example, `foo/CLAUDE.md` appears in context before `foo/bar/CLAUDE.md`, so instructions closer to where you launched Claude are read last. Within each directory, `CLAUDE.local.md` is appended after `CLAUDE.md`, so your personal notes are the last thing Claude reads at that level.

> CLAUDE.md files can live in several locations, each with a different scope. The table below lists them in load order, from broadest scope to most specific, so a project instruction appears in context after a user instruction.

(Table: Managed policy, User `~/.claude/CLAUDE.md`, Project `./CLAUDE.md` or `./.claude/CLAUDE.md`, Local `./CLAUDE.local.md`.)

Conflicts:
> Claude Code loads user-level rules before project rules, so a project rule appears later in Claude's context than a user rule. Neither set overrides the other: if a user rule and a project rule conflict, Claude may follow either one, so keep the two consistent.

> * **Consistency**: if two instructions contradict each other, Claude may pick one arbitrarily. Review your CLAUDE.md files, nested CLAUDE.md files in subdirectories, and [`.claude/rules/`](#organize-rules-with-claude/rules/) periodically to remove outdated or conflicting instructions.

> Rules without [`paths` frontmatter](#path-specific-rules) are loaded at launch with the same priority as `.claude/CLAUDE.md`.

> CLAUDE.md content is delivered as a user message after the system prompt, not as part of the system prompt itself. Claude reads it and tries to follow it, but there's no guarantee of strict compliance, especially for vague or conflicting instructions.

200 lines: applies to two different things.
- CLAUDE.md, a size *target* (not a limit): "* **Size**: target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence." and "Files over 200 lines consume more context and may reduce adherence. Claude Code skips a file over 4 MiB."
- Auto memory `MEMORY.md`, a *load limit*: "The first 200 lines of `MEMORY.md`, or the first 25KB, whichever comes first, are loaded at the start of every conversation. Content beyond that threshold is not loaded at session start." Comparison table row: "**Loaded into** | Every session | Every session (first 200 lines or 25KB)" (CLAUDE.md column vs Auto memory column).
- Separate character limit for files that load on demand (subdirectory CLAUDE.md, subdirectory rules, path-scoped rules): "**200K context window**: 40,000 characters"; "**1M context window**: 200,000 characters on Claude Opus 4.6 and Claude Sonnet 4.6, and 150,000 characters on later models".

**Plain answer**: stated: every level loads and they are concatenated (broadest first,
most specific last); none overrides another. **"More specific wins" is not stated**: the page
says the opposite, that on a conflict "Claude may follow either one" / "may pick one
arbitrarily". The "200 lines" figure is a *target* for each CLAUDE.md file and a hard *load
limit* (200 lines or 25KB) only for auto memory `MEMORY.md`.

---

## Q3. Hooks: Windows shell for `type: "command"`; Stop exit 2; stderr on exit 0

URL: https://code.claude.com/docs/en/hooks.md (read 23:33:47Z–23:35:09Z).

Windows shell:
> **Shell form** runs when `args` is absent. The `command` string is passed to a shell: `sh -c` on macOS and Linux, Git Bash on Windows, or PowerShell when Git Bash isn't installed. Set the `shell` field to choose explicitly.

> | `shell` | no | Shell to use for this hook. Accepts `"bash"` or `"powershell"`. Defaults to `"bash"`, or to `"powershell"` on Windows when Git Bash isn't installed. Setting `"powershell"` runs the command via PowerShell on Windows. Does not require `CLAUDE_CODE_USE_POWERSHELL_TOOL` since hooks spawn PowerShell directly. Ignored when `args` is set |

> | `args` | no | Argument list. When present, `command` is resolved as an executable and spawned directly with `args` as the argument vector, with no shell involved. ... |

> On Windows, you can run individual hooks in PowerShell by setting `"shell": "powershell"` on a command hook. Claude Code auto-detects `pwsh.exe`, the PowerShell 7 and later executable, and falls back to `powershell.exe` for Windows PowerShell 5.1.

Git Bash location: "set [`CLAUDE_CODE_GIT_BASH_PATH`](https://code.claude.com/docs/en/env-vars) if Git Bash is installed where Claude Code doesn't find it." cmd.exe is not named as a hook shell. (Changelog 2.1.47: "Fixed hooks (PreToolUse, PostToolUse) silently failing to execute on Windows by using Git Bash instead of cmd.exe (anthropics/claude-code#25981)".)

Stop exit 2:
> | `Stop` | Yes | Prevents Claude from stopping, continues the conversation |

> A hook that blocks by exiting 2 routes the same way as `reason`: Claude receives the stderr message as the explanation for why it should continue.

General: "The message that comes with the block is your hook's stderr. If your hook also printed JSON that makes a blocking decision, Claude Code uses that decision's reason instead."

stderr on exit 0:
> Claude never sees stderr from a hook that exits 0. To read it yourself on events such as `PreToolUse`, enable [debug logging](#debug-hooks). To surface a warning to Claude from a `PostToolUse` or `PostToolUseFailure` hook, exit 2 instead so [Claude sees the stderr](#exit-code-2-behavior-per-event) even though the tool already ran.

Exit-code table row for plain text: "| [Plain text](#exit-code-0), or nothing | Success | Blocking error. Your stderr is the reason | Non-blocking error. The notice carries the first line of your stderr |"

**Plain answer**: stated: on Windows a shell-form command hook runs in Git Bash, or in
PowerShell when Git Bash isn't installed (cmd is not used). The per-hook `"shell": "bash" |
"powershell"` field chooses the shell. `args` (exec form) uses no shell, and
`CLAUDE_CODE_GIT_BASH_PATH` points to Git Bash. When a Stop hook exits 2, Claude keeps going
and gets the stderr as the reason. On exit 0, Claude never sees stderr; it shows only in the
debug log.

---

## Q4. Hooks: SessionEnd timeout; cancellation at exit

URL: https://code.claude.com/docs/en/hooks.md (read 23:33:47Z–23:35:09Z); env-vars.md (same window).

> SessionEnd hooks have a default timeout of 1.5 seconds. It applies when you exit, run `/clear`, or switch sessions with interactive `/resume`. You can give a hook more time in two ways:
>
> * **Per-hook `timeout`**: set `timeout` in that hook's configuration. The overall budget rises automatically to match the highest per-hook `timeout` in your settings files, up to 60 seconds. If you raise the budget this way, a hook without its own `timeout` still keeps the default. Timeouts set on plugin-provided hooks don't raise the budget.
> * **`CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS`**: set this environment variable in milliseconds to override the budget explicitly. The value you set also becomes the timeout for each hook without its own `timeout`.
>
> Before v2.1.268, `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` raised only the overall budget, and a hook without its own `timeout` was still canceled after 1.5 seconds.

Common `timeout` field: "[`SessionEnd`](#sessionend) hooks share a 1.5-second budget; if your settings set a longer per-hook `timeout`, Claude Code raises the budget to match, up to 60 seconds".

Cancellation: "Apart from a command hook you run with [`async: true`](#run-hooks-in-the-background), Claude Code cancels a `command`, `http`, or `mcp_tool` hook that reaches its [`timeout`](#common-fields), discarding the hook's output".

Async hooks at exit: "Claude Code delivers an async hook's results only while the session runs: * In [non-interactive mode](https://code.claude.com/docs/en/headless.md) with the `-p` flag, Claude Code kills any async hook still running at teardown and finalizes it with outcome `cancelled` * If your hook's work must outlive a `claude -p` session, start a fully detached process from it"

SessionEnd decision: "SessionEnd hooks have no decision control. They can't block session termination but can perform cleanup tasks. Claude Code discards their [JSON output fields](#json-output), such as `systemMessage`." Exit 2: "| `SessionEnd` | No | Shows stderr to user only |".

env-vars.md `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS`: "Override the time budget in milliseconds for [SessionEnd](https://code.claude.com/docs/en/hooks.md#sessionend) hooks. ... By default the budget is 1.5 seconds, automatically raised to the highest per-hook `timeout` configured in settings files, up to 60 seconds. Timeouts on plugin-provided hooks do not raise the budget".

Changelog: 2.1.74 "Fixed `SessionEnd` hooks being killed after 1.5 s on exit regardless of `hook.timeout` — now configurable via `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS`"; 2.1.268 "Fixed `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` not extending SessionEnd hooks that have no per-hook `timeout` (they were still cancelled after 1.5 seconds)"; 2.1.300 "Fixed SessionEnd hooks sometimes not running when you exit while a background command is still running".

**Plain answer**: stated: SessionEnd hooks share a 1.5-second budget on exit, `/clear` and
`/resume`. A per-hook `timeout` raises the budget up to 60 seconds, and
`CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` sets it directly. A hook that hits its timeout is
cancelled and its output is thrown away. Async hooks still running at teardown are killed, but
the page states this only for `-p` (non-interactive) mode.

---

## Q5. Permissions: scope precedence for allow vs deny; MCP rule syntax

URLs: https://code.claude.com/docs/en/permissions.md and https://code.claude.com/docs/en/settings.md (read 23:33:47Z–23:35:09Z).

permissions.md:
> Rules are evaluated in order: deny, then ask, then allow. The first match in that order determines the outcome, and rule specificity doesn't change the order.

> If a tool is denied at any level, no other level can allow it. For example, a managed settings deny can't be overridden by `--allowedTools`, and `--disallowedTools` can add restrictions beyond what managed settings define.

> The same holds across settings scopes: if user settings allow a permission and project settings deny it, the deny rule blocks it. The reverse is also true: a user-level deny blocks a project-level allow, because deny rules from any scope are evaluated before allow rules.

> A broad deny rule like `Bash(aws *)` blocks every matching call, including calls that also match a narrower allow rule like `Bash(aws s3 ls)`. An allow rule can't carve an exception out of a deny rule.

> PreToolUse hook decisions don't bypass permission rules. ... a matching deny rule blocks the call, and a matching ask rule still prompts even when the hook returned `"allow"` or `"ask"`.

settings.md:
> ### Lists merge instead of overriding
>
> When you set the same list key, such as `permissions.allow`, in more than one file, Claude Code combines the lists instead of picking one, so each file can add entries without removing another file's.

> Settings precedence, highest first: managed settings, command line, project local, shared project, user. A key set at a higher level overrides the same key set lower down.

> * **You chose "Yes, and don't ask again" on a permission prompt but still get prompted for the same tool.** That choice saved an `allow` rule to your local file, and an `allow` rule there doesn't outrank an `ask` rule from a project or managed file

MCP syntax (permissions.md):
> To match every tool from an MCP server, write `mcp__<server>__*`. To match one tool, write its full name, `mcp__<server>__<tool>`.

> * `mcp__puppeteer` matches any tool provided by the `puppeteer` server
> * `mcp__puppeteer__*` uses wildcard syntax and also matches all tools from the `puppeteer` server
> * `mcp__puppeteer__puppeteer_navigate` matches the `puppeteer_navigate` tool provided by the `puppeteer` server

> Allow rules accept tool-name globs only after a literal `mcp__<server>__` prefix. The server segment must be glob-free so the rule names a specific server you configured. ... An unanchored allow glob such as `"*"`, `"B*"`, or `"mcp__*"` is skipped and doesn't auto-approve anything.

> Deny and ask rules also accept glob patterns in the tool-name position. The pattern must match the full tool name: `"*"` matches every tool, and `"mcp__*"` matches every MCP tool across all servers.

> * **Names with characters such as `.` or spaces**: those characters become `_`, so for a server you configured as `my.server`, write `mcp__my_server__*`

> When Claude Code loads a settings file, it skips any `mcp__` rule that has parentheses.

> Tools from connectors Claude Code fetches itself appear as `mcp__claude_ai_<server>__<tool>`.

**Plain answer**: stated: deny wins across every scope. A user-scope deny blocks a
project-scope allow, and a project-scope deny blocks a user-scope allow. Permission lists are
merged across files, not overridden, and checked in the order deny, then ask, then allow. MCP
rules: `mcp__<server>` or `mcp__<server>__*` cover the whole server, and
`mcp__<server>__<tool>` covers one tool. `mcp__*` works only as a deny or ask rule; an allow
rule with it is skipped. Rules with parentheses are skipped.

---

## Q6. Sub-agents: what context a sub-agent receives at start

URL: https://code.claude.com/docs/en/sub-agents.md, section "What loads at startup" (read 23:33:47Z–23:35:09Z).

> Each subagent starts with a fresh, isolated context window. It doesn't see your conversation history, the skills you've already invoked, or the files Claude has already read. Claude composes a delegation message that summarizes the task, and the subagent works from there. The exception is a [fork](#fork-the-current-conversation), which inherits the parent conversation instead of starting fresh.

> A non-fork subagent's initial context contains:
>
> * **System prompt**: the agent's own prompt plus environment details that Claude Code appends, not the Claude Code system prompt. ...
> * **Task message**: the delegation prompt Claude writes when it hands off the work.
> * **CLAUDE.md files**: every level of the [CLAUDE.md hierarchy](https://code.claude.com/docs/en/memory.md#how-claude-md-files-load) the main conversation loads, including `~/.claude/CLAUDE.md`, project rules, `CLAUDE.local.md`, managed policy files, and any [`AGENTS.md` files](https://code.claude.com/docs/en/memory#agents-md) loaded as project instructions. The built-in Explore and Plan agents skip this. A subagent whose definition sets [`omitClaudeMd`](#supported-frontmatter-fields) loads only the managed policy files, or none at all when the definition comes from [managed settings](#choose-the-subagent-scope).
> * **Git status**: a snapshot ... Explore and Plan skip it regardless.
> * **Preloaded skills**: full content of any skill named in the agent's [`skills` field](#preload-skills-into-subagents). Built-in agents don't preload skills.
> * **Sibling roster**: a [system reminder](https://code.claude.com/docs/en/glossary.md#system-reminder) listing `main` and every other named agent in the session, each a valid `to` value for [`SendMessage`](#resume-subagents). ...

> For Explore, Plan, and subagents with `omitClaudeMd`, a subdirectory's `CLAUDE.md` and matching [path-scoped rules](https://code.claude.com/docs/en/memory.md#path-specific-rules) still [load](https://code.claude.com/docs/en/memory.md#how-claude-md-files-load) when the subagent works with files there.

> The main conversation still has your full CLAUDE.md when it reads these subagents' results, so most rules don't need to reach the subagent itself. If a rule must, such as "ignore the `vendor/` directory," restate it in the prompt you give Claude when delegating.

> Some main-conversation state never reaches a non-fork subagent: * **Output style** ... * **Auto memory**: the main conversation's [auto memory](https://code.claude.com/docs/en/memory.md#auto-memory) isn't loaded. ... * **Context window size**: a subagent's context window is sized by its own model, not the parent's.

Skills (Preload skills section):
> This field controls which skills are preloaded, not which skills the subagent can access: without it, the subagent can still discover and invoke project, user, and plugin skills through the Skill tool during execution. To prevent a subagent from invoking skills entirely, omit `Skill` from the [`tools`](#available-tools) list or add it to `disallowedTools`.

**Plain answer**: stated: a non-fork sub-agent gets its own system prompt, the delegation
message, every CLAUDE.md level the main session loads (including project rules), a git status
snapshot, the skills preloaded through its `skills` field, and a list of the other named
agents. It does **not** get the parent's conversation, the skills the parent already invoked,
the files it read, or auto memory. Explore and Plan skip CLAUDE.md and git status. Any skill
can still be loaded during the run through the Skill tool. A fork inherits the parent's
conversation.

---

## Q7. PowerShell tool on Windows; "primary shell"; `CLAUDE_CODE_SHELL`

URLs: https://code.claude.com/docs/en/tools-reference.md, https://code.claude.com/docs/en/env-vars.md, https://code.claude.com/docs/en/setup.md (read 23:33:47Z–23:35:09Z); changelog.md (~23:32Z).

tools-reference.md "PowerShell tool":
> The PowerShell tool lets Claude run PowerShell commands natively. On Windows, this means commands run in PowerShell instead of routing through Git Bash. How the tool becomes available depends on your platform:
>
> * **Windows without Git Bash**: the tool is enabled automatically.
> * **Windows with Git Bash installed**: the tool is on by default for claude.ai and Console accounts; set `CLAUDE_CODE_USE_POWERSHELL_TOOL=1` to enable it in Amazon Bedrock, Google Cloud's Agent Platform, and Microsoft Foundry sessions, or `0` to turn it off.
> * **Linux, macOS, and WSL**: the tool is opt-in.

> On Windows, Claude Code auto-detects `pwsh.exe` for PowerShell 7+ with a fallback to `powershell.exe` for PowerShell 5.1. When the tool is enabled, Claude treats PowerShell as the primary shell. The Bash tool remains available for POSIX scripts when Git Bash is installed.

> On Windows with Git Bash installed, denying Bash also turns the PowerShell tool off for the session. This applies to scoped rules such as `Bash(git push *)` as well as a bare `Bash` ...

> * `"defaultShell": "powershell"` in [`settings.json`](https://code.claude.com/docs/en/settings-reference#all-settings): routes interactive `!` commands through PowerShell. Requires the PowerShell tool to be enabled.

hooks.md (PowerShell input section):
> * On Windows, wherever the PowerShell tool is enabled, Claude treats PowerShell as the primary shell and routes shell commands through it.
> * On Windows without Git Bash, the tool is enabled automatically and Claude Code doesn't register the Bash tool at all.
> * A hook that matches only `Bash` never fires there.

env-vars.md:
> | `CLAUDE_CODE_USE_POWERSHELL_TOOL` | Controls the PowerShell tool. On Windows without Git Bash, the tool is enabled automatically; set to `0` to disable it. On Windows with Git Bash installed, the tool is on by default for claude.ai and Console accounts; set to `1` to enable it in Amazon Bedrock, Google Cloud's Agent Platform, and Microsoft Foundry sessions, or `0` to turn it off. ... |

> | `CLAUDE_CODE_SHELL` | Set the shell Claude Code uses to run Bash tool commands. Accepts a path to a `bash` or `zsh` binary, for example `/opt/homebrew/bin/bash`. Other shells such as `fish` are not supported. If the value is not a working `bash` or `zsh` path, Claude Code ignores it and falls back to auto-detection. Auto-detection uses your `$SHELL` when it points to `bash` or `zsh`, otherwise it picks the first working `zsh` then `bash` found on your `PATH` and standard install locations |

env-vars.md (under "Features that need feature-flag fetching", "With fetching off, you can't:"):
> * Get the [PowerShell tool](https://code.claude.com/docs/en/tools-reference.md#powershell-tool) by default for claude.ai and Console accounts on Windows with Git Bash installed; Claude Code routes shell commands through Git Bash unless you set `CLAUDE_CODE_USE_POWERSHELL_TOOL=1`. On Windows without Git Bash, the tool stays on

setup.md:
> * **Without Git for Windows**, Claude Code runs shell commands via the [PowerShell tool](https://code.claude.com/docs/en/tools-reference.md#powershell-tool).
> * **With Git for Windows**, Claude Code uses Git Bash for the [Bash tool](https://code.claude.com/docs/en/tools-reference.md#bash-tool-behavior). If Claude Code can't find Git Bash, set the path in your [settings.json file](https://code.claude.com/docs/en/settings.md):

> When Git for Windows is installed, the PowerShell tool is available alongside Bash: on by default for claude.ai and Console accounts, and enabled with `CLAUDE_CODE_USE_POWERSHELL_TOOL=1` in Amazon Bedrock, Google Cloud's Agent Platform, and Microsoft Foundry sessions. Set it to `0` to turn the tool off.

Changelog history:
- 2.1.84 (March 26, 2026): "Added PowerShell tool for Windows as an opt-in preview."
- 2.1.111 (April 16, 2026): "Windows: PowerShell tool is progressively rolling out. Opt in or out with `CLAUDE_CODE_USE_POWERSHELL_TOOL`. On Linux and macOS, enable with `CLAUDE_CODE_USE_POWERSHELL_TOOL=1` (requires `pwsh` on PATH)"
- 2.1.126 (May 1, 2026): "Windows: when the PowerShell tool is enabled, Claude now treats PowerShell as the primary shell instead of defaulting to Bash"
- 2.1.143 (May 15, 2026): "The PowerShell tool is now enabled by default on Windows for Bedrock, Vertex, and Foundry users. Opt out with `CLAUDE_CODE_USE_POWERSHELL_TOOL=0`." and "PowerShell tool now passes `-ExecutionPolicy Bypass`. Opt out with `CLAUDE_CODE_POWERSHELL_RESPECT_EXECUTION_POLICY=1`"
- 2.0.65 (December 11, 2025): "Added `CLAUDE_CODE_SHELL` environment variable to override automatic shell detection (useful when login shell differs from actual working shell)"

Note: the 2.1.143 changelog line (default on for Bedrock/Vertex/Foundry) and today's docs
(on by default for claude.ai and Console; `=1` needed for Bedrock/Agent Platform/Foundry)
describe different defaults. The docs are the current statement; the changelog line is
history. Not reconciled on any page I read.

**Plain answer**: stated: on Windows with Git Bash installed, the PowerShell tool is on by
default for claude.ai and Console accounts, needs `CLAUDE_CODE_USE_POWERSHELL_TOOL=1` on
Bedrock, Agent Platform and Foundry, and `=0` turns it off. Without Git Bash it is always on and
there is no Bash tool. "Primary shell" means Claude sends shell commands through PowerShell,
while Bash stays available for POSIX scripts. `CLAUDE_CODE_SHELL` sets the binary the **Bash
tool** uses (a bash or zsh path only). **Whether it applies on Windows is not stated**; for
Windows the docs point to `CLAUDE_CODE_GIT_BASH_PATH` instead.

---

## Q8. `TaskStop`, stopping background agents, `SendMessage`, `SubagentHandback`

URLs: https://code.claude.com/docs/en/tools-reference.md, https://code.claude.com/docs/en/sub-agents.md (read 23:33:47Z–23:35:09Z); changelog.md (~23:32Z).

tools-reference.md tool table:
> | `TaskStop` | Stops a running background task by ID. It also accepts an [agent-team teammate](https://code.claude.com/docs/en/agent-teams.md) or a named background agent by agent ID or name. When no task matches the ID, the error lists the running background agents by ID and description, including agents that another agent spawned | No |

> | `SendMessage` | Sends a message to another agent: an [agent team](https://code.claude.com/docs/en/agent-teams.md) teammate, a [subagent it resumes](https://code.claude.com/docs/en/sub-agents.md#resume-subagents) by agent ID or name, or one of your other Claude Code sessions, on this machine or beyond it. Messaging other sessions requires Claude Code v2.1.224 or later. ... | No |

> | `SubagentHandback` | Delivers a subagent's final report to whichever conversation receives that subagent's result. Provided only in [auto mode](https://code.claude.com/docs/en/permission-modes.md#eliminate-prompts-with-auto-mode), to subagents that the Agent tool runs locally other than [forks](https://code.claude.com/docs/en/sub-agents.md#fork-the-current-conversation), and available in the terminal CLI, IDE extensions, cloud sessions, and the Agent SDK; the classifier reviews the report before it's delivered. Requires Claude Code v2.1.271 or later | No |

> Where the conditions in the `SubagentHandback` tools-table entry hold, Claude Code also gives the subagent that tool, even if you leave it out of `tools` or list it in `disallowedTools`.

> The Agent tool spawns a subagent in a separate context window. The subagent works through its task autonomously, then returns its result to the parent conversation. The parent doesn't see the subagent's intermediate tool calls or outputs, only that final result.

sub-agents.md:
> When Claude sends a completed subagent a message with the `SendMessage` tool, the subagent resumes in the background without a new `Agent` invocation. The same applies to a subagent that Claude stopped with the `TaskStop` tool, once its stopped run has exited.

> ... a background subagent keeps every MCP tool but only these built-in tools: `Read`, `Grep`, `Glob`, `LSP`, `Bash`, `PowerShell`, `Edit`, `Write`, `NotebookEdit`, `WebFetch`, `WebSearch`, `TodoWrite`, `Skill`, `ToolSearch`, `EnterWorktree`, `ExitWorktree`, `Monitor`, `TaskStop`, `SendMessage`, and `Artifact`, plus [`SubagentHandback`](https://code.claude.com/docs/en/tools-reference) for a subagent that reports through it.

> * When a subagent fails or you stop it, Claude Code keeps its row for 30 seconds. To clear the row sooner, select it and press `x`.

> A background subagent's results reach Claude as a completion notification in a later turn.

> By default, a subagent can spawn subagents of its own, up to three layers below the main conversation. At the depth limit, Claude Code withholds the `Agent` tool from every subagent except a [fork](#fork-the-current-conversation), so a subagent at the limit does its delegated work itself and returns one summary.

> Claude Code scans each subagent's final report before Claude reads it. ... The scan never removes or rewords anything

Changelog: 2.1.203 "Fixed `TaskStop` and `TaskOutput` failing to find background agents spawned by another agent — errors now list running agents by id and description"; 2.1.317 "Changed SendMessage so a message to a running background agent arrives earlier: its running command moves to the background, without being stopped". `SubagentHandback` does not appear in the changelog (no line contains it).

**Plain answer**: stated: `TaskStop` stops a background task, teammate or named background
agent by ID or name. A stopped or finished subagent picks up again (resumes) when it gets a
`SendMessage`. `SubagentHandback` delivers a subagent's *final report* to whoever receives its
result. It exists only in auto mode, for local non-fork subagents, from v2.1.271, and the
auto-mode classifier reviews the report before delivery. "One report per result" in those
words is not stated; the docs say "the final report" and "only that final result".
`SubagentHandback` is not in the changelog.

---

## Findings for 38dc-25 (facts that differ from the harness docs as briefed)

These are comparisons, not incidents (not filed):
- The user CLAUDE.md says "Claude Code on Windows always uses Git Bash (not configurable).
  `CLAUDE_CODE_SHELL` is broken on Windows". The docs now state the PowerShell tool is on by
  default on Windows with Git Bash for claude.ai/Console accounts and becomes the "primary
  shell" (Q7). `CLAUDE_CODE_SHELL` sets only the Bash tool's bash/zsh binary; nothing about
  Windows is stated.
- The user CLAUDE.md says "CC 2.1.68+ defaults to medium for Opus 4.6". The changelog says
  medium for "Max and Team subscribers" in 2.1.68, and 2.1.94/2.1.117 later raised defaults to
  `high` (Q1 list; 2.1.117: "Default effort for Pro/Max subscribers on Opus 4.6 and Sonnet 4.6
  is now `high` (was `medium`)").
- `InstructionsLoaded` and hook `agent_id` arrived in 2.1.69, not 2.1.68 (Q1).
- The "200 lines" figure is a *target* for CLAUDE.md and a hard *load limit* only for auto
  memory `MEMORY.md` (Q2). The aitools documentation-standards rule's "Keep `CLAUDE.md` under
  200 lines" matches the target.
- "More specific wins" between CLAUDE.md levels or rules is not stated; the docs say all
  are concatenated and a conflict may be resolved either way (Q2).
