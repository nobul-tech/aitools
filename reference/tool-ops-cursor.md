# Tool ops: Cursor (IDE and CLI)

**Intent**: **Purpose**: Hold operational knowledge about Cursor (desktop IDE
and the `agent` CLI) that the harness depends on: where Cursor reads
user-level rules, in what format, which files its agent's tools can reach,
and how to verify it. **Scope**: Rules location, format and loading
behaviour; ignore files and the agent's file access; agent modes; doc
access; verification. NOT install methods (`/tool-registry` skill). NOT the
ops metadata registry (`/tool-ops` skill). NOT project rule parity
(`reference/cursor-practices.md`). **Audience**: Agents that change
`setup-user-cursor`, the harness rules fan-out, anything Cursor loads from
`~/.cursor/`, or the aitools `.cursorignore`; every agent working in Cursor.

## User-level rules

| Item | Value | Source |
|------|-------|--------|
| Location | `~/.cursor/rules/` (Windows: `%USERPROFILE%\.cursor\rules\`) | cursor.com/help/customization/rules.md, "Where are rules stored?" (2026-10-22) |
| Format | `*.mdc` with a leading `---` frontmatter block | cursor.com/docs/rules.md "Rule file structure"; loader code |
| Plain `.md` | ignored | same |
| `.mdc` without frontmatter | skipped silently | loader code (frontmatter parser returns null) |
| Reach | workspaces under the home directory only | loader code (ancestor walk) |
| Sync | none (stays on the machine) | help page |

Verbatim (help page): "**User rule files** in `~/.cursor/rules` (Windows:
`%USERPROFILE%\.cursor\rules`) stay on the machine and do not sync."

"User Rules" set in **Customize → Rules** are a different thing. They are stored
on the Cursor account, not in files. cursor.com/docs/skills.md ("User rules are
also not migrated since they are not stored on the file system") refers to them.

### Loading behaviour

Cursor IDE 3.13.10 (`extensions/cursor-agent-exec/dist/main.js`) and CLI
2026.05.21-f84ab11 (`index.js`) share `LocalCursorRulesService`.
`loadRulesFromDirAndAncestors` starts at the workspace directory and walks up
to the filesystem root. At each directory it loads:

- `<dir>/.cursor/rules/**/*.mdc`
- `<dir>/AGENTS.md`
- `<dir>/CLAUDE.md` and `<dir>/CLAUDE.local.md`, only when third-party
  extensibility is enabled

There is no separate home lookup. `~/.cursor/rules` applies because `~` is an
ancestor of the workspace. A workspace outside `~` (`/tmp/x`, `C:\repos\x`)
does not see user rule files.

### Frontmatter to rule type

| Frontmatter | Type |
|-------------|------|
| `alwaysApply: true` | always included |
| `globs:` (comma string or YAML list) | auto-attached when a matching file is in context |
| `description:` only | agent decides when relevant |
| none of these | only when @-mentioned |

### Glob anchoring

Cursor IDE 3.13.10 (`rL` / `aL` in `cursor-agent-exec/dist/main.js`) matches a
relative glob against the file path relative to the directory that owns
`.cursor/rules`. For a user rule file, that directory is the home directory. An
absolute glob is matched against the full path. So a user rule with
`globs: scripts/**` attaches only to `~/scripts/...`. Use `**/scripts/**` to
match `scripts/` inside any repo under `~`. The CLI's anchoring is unknown,
because its bundle has no client-side matcher. `**/` is correct under either
anchor.

Inline `globs:` values are split on commas, so `*.{ts,tsx}` breaks. Use a block
list with indented `  - ` items; items at column 0 are not read.

### Harness deployment

`setup-user-cursor` step 4 fans `~/.aitools/rules` out here: every rule
except the ones the rules manifest retires (shared, aitools and dotprofile
sources alike; `@reference/rules.md` R-6). It converts each Claude Code
`<name>.md` to `<name>.mdc`:

- A rule without frontmatter gets `alwaysApply: true`.
- A Claude Code `paths:` key (any form) becomes an anchored `globs:` block
  list (`**/<pattern>`) with `alwaysApply: false`.
- A converted file that Cursor would misparse (a `---` inside a frontmatter
  value) is reported as a warning.

## Ignore files and agent file tools

Verified 2026-11-14 on Cursor IDE 3.30.14 (Windows 11, x64) in the aitools
workspace: each file tool was run on `.scratch/` before and after `.scratch/`,
`*.log` and `*.tmp` were removed from aitools `.cursorignore` (commander,
2026-11-14), and a delegate re-ran the after-test independently the same day.
`.gitignore` listed all three throughout.

| Behaviour | Observed | Source |
|-----------|----------|--------|
| `.cursorignore` blocks the agent's file tools, not only indexing | Write: `Read permission denied: <path>`. Read: `Error: Permission denied`. Grep: `Error running tool: Path '<path>' is filtered out by .cursorignore`. Glob: no error; the ignored files are left out of the result | test; ignore-file.md |
| `.gitignore` and Cursor's default ignore list do not block Read, Write or StrReplace | After the removal, all three work on `.scratch/` files ending `.md`, `.log`, `.tmp`, `.txt` and `.py`, although `.gitignore` lists `.scratch/`, `*.log` and `*.tmp` and the default list has `*.tmp` | test |
| Search honours `.gitignore` | Glob and Grep from the workspace root find nothing under a git-ignored directory. Pointed at that directory, they return its files except those matching a `.gitignore` file pattern (`*.log`, `*.tmp` here). In the workspace, Grep given a single file's path searches it, ignored or not | test; ignore-file.md |
| Outside the workspace (a git worktree under `~/.cursor/worktrees/`), only Grep applies that repo's `.cursorignore`, and it keeps the version it first saw | Read and Write worked in the worktree's `.scratch/` while the worktree's `.cursorignore` listed `.scratch/`. After that file was changed to drop `.scratch/`, Grep still refused `.scratch/` files there (`filtered out by .cursorignore`), while a file ignored only by `.gitignore` was searchable | test |
| The terminal and MCP tools are outside these controls | The Shell tool listed and read `.scratch/` while every file tool was blocked | test; ignore-file.md |
| Agents cannot change `.cursorignore` with the file tools | `Write permission denied: <path>: Blocked by permissions configuration`, for the workspace's file and for the copy in a git worktree outside the workspace, with an empty `permissions` block in `~/.cursor/cli-config.json` | test; security.md |

Verbatim, cursor.com/docs/reference/ignore-file.md (read 2026-11-14):
"Cursor blocks access to files listed in `.cursorignore` from: Code
accessible by Agent and Tab; Code accessible via @ mention references". "The
terminal and MCP server tools used by Agent cannot block access to code
governed by `.cursorignore`". "Cursor automatically ignores files in
`.gitignore` and the default ignore list below. Override with `!` prefix in
`.cursorignore`." (The `!` override is documented; not tested here.)

Verbatim, cursor.com/docs/agent/security.md (read 2026-11-14): "Agents can
modify workspace files without approval, except for configuration files."
"Configuration files (like workspace settings) need your approval first."

What the harness does with this:

- Do not add to `.cursorignore` a path an agent must read or write. The
  session scratch directory (`/scratch` skill) and its `*.log` and `*.tmp`
  files were removed from it for this reason (commander, 2026-11-14); the
  paths it still lists that agents need are under "Known gaps".
- Read and write scratch files by absolute path. To list a scratch directory,
  use the shell: from the workspace root, Glob and Grep skip git-ignored
  directories, and inside one they skip files that match another
  `.gitignore` pattern.
- A change to `.cursorignore` needs the user's approval. With the
  commander's order in the prompt, the agent makes the change with the shell
  and reports that it did.

## Agent modes

- **Ask mode** runs shell commands under a read-only sandbox. On a Windows
  machine without a sandbox backend, every Shell call fails with: `Terminal
  unavailable: this machine cannot enforce the 'workspace_readonly' sandbox
  policy this command requires, because no working sandbox backend is
  available (Windows sandbox helper only provides network proxy, not
  filesystem isolation).` (2026-11-13). Read-only commands such as `git log`
  fail too; switch to Agent mode for anything that needs a shell.

## Known gaps

- `~/.cursor/AGENTS.md` (the relay mirror written by `aitools` / install step
  22) is not read by the rules loader in either bundle. The loader reads
  `<ancestor>/AGENTS.md`, that is, `~/AGENTS.md`.
- Live canary not yet run (needs `agent login`).
- aitools `.cursorignore` still lists `harvesting/`, `.claude/worktrees/` and
  `.aitools/channel/*-full-session.md`. So a Cursor agent cannot read
  harvested artifacts (`/harvest` skill) or the full session transcripts that
  `.aitools/channel/CLAUDE.md` tells agents to load, and cannot edit files in
  a worktree under `.claude/worktrees/`, with the file tools. A worktree
  outside the workspace (for example under `~/.cursor/worktrees/`) is
  reachable by Read and Write; Grep there follows the worktree's own
  `.cursorignore` (see the table above). Open (2026-11-14).

## Doc access

Use the chrome-devtools skill. Every docs page has a `.md` variant listed in
https://cursor.com/llms.txt (`/docs/<page>.md`, `/help/<area>/<page>.md`).
Fetch it in-page for verbatim text. Do not use WebFetch for content that
feeds source-of-truth files (registries, rules, references).

## Verification (manual canary)

Requires `agent login`. Run from a workspace under `~`:

```bash
mkdir -p ~/.cursor/rules ~/hcursor-canary-ws
printf -- '---\nalwaysApply: true\n---\nThe secret token is AITOOLS-CANARY-MDC-7Q4.\n' > ~/.cursor/rules/aitools-canary.mdc
cd ~/hcursor-canary-ws
agent -p --trust --mode ask "Do not use any tools. Print every token in your rules that starts with AITOOLS-CANARY-, or NONE."
rm ~/.cursor/rules/aitools-canary.mdc
```

Expected result: `AITOOLS-CANARY-MDC-7Q4`.
