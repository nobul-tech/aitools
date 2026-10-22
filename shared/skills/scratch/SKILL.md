---
name: scratch
description: "Ephemeral session scratch files — the session directory,
  how to find it (main agent, delegate, git worktree), naming conventions
  and how the harvester classifies them, the commit-message and PR-body
  patterns. Use when writing temp scripts, captured logs, commit messages
  or PR bodies, or running complex commands that should not be inlined."
---

## Intent

**Purpose**: Equip every agent to find or create its session scratch
directory and use it for temp scripts, captured logs, commit messages
and PR bodies — directory location for the main agent, a delegate and
a git worktree, naming conventions and their harvest outcome, the
commit-message and PR-body patterns, and the scratch lifecycle.
**Scope**: Ephemeral file lifecycle only. NOT artifact harvesting (see
`/harvest` skill in projects that have `harvesting/`). NOT
standing-order enforcement (that's the standing-order-guard hook). NOT
the governing principle and delegation duty (user rule `scratch.md`).
**Audience**: Every agent in every project.

## Session scratch directory

Every temp script, captured log, commit message and PR body goes in
your session scratch directory. Never write to the `.scratch/` root
(file names collide across sessions), and never inline what belongs
in a file.

The directory is `<root>/.scratch/session-<id>/`, where `<root>` is
the git toplevel of the session's working directory (`git rev-parse
--show-toplevel`; the working directory itself outside a repo) and
`<id>` is the first 10 characters of the Claude Code session id.
The SessionStart hook `scratch-init.sh` creates it and prints it into
your context:

```
Session scratch directory: /Users/me/repos/proj/.scratch/session-10cf255a-c
```

`.scratch/` is gitignored. The workspace rule mentions
`.aitools/scratch/`; no hook or harvester uses that path today.

### Finding your directory

1. **Main agent**: use the path from the `Session scratch directory:`
   line in your context. Write it into later commands literally.
2. **No such line** (hooks not deployed, or context compacted): Read
   `<root>/.scratch/.current-session`. Treat it as a hint, not a fact:
   it is one file per checkout, shared by every session there, and any
   session's start overwrites it and any harvest deletes it. Use it only
   if it names `session-<your id>`; otherwise create your own directory
   as a delegate does (step 3), named after yourself.
3. **Delegate** (sub-agent, background session, cloud agent): no
   SessionStart hook runs for you, so you have no directory until you
   make one. Use the path the delegation prompt gives you; if it gives
   none, create one named after yourself in the repo or worktree you
   work in:

   ```bash
   mkdir -p /abs/path/to/worktree/.scratch/session-S3-Build
   ```

   Keep the part after `session-` to 10 characters or fewer
   (`session-S3-Build`, not `session-S3-ScratchRule`). The catch-up
   harvester truncates it to 10 characters; a longer name is never
   harvested, and the miss makes it harvest the directory named in
   `.current-session` (a live session's) instead.

   A delegating agent states this path in every delegation prompt.

### Git worktrees

Each worktree is its own git toplevel, so each has its own
`.scratch/`. A delegate working in a worktree uses that worktree's
`.scratch/session-<NAME>/`, not the main checkout's (a worktree-isolated
delegate cannot write there at all).

The harvester only sweeps the `.scratch/` of the root a session started
in. A worktree's `.scratch/` is never harvested unless a session starts
in that worktree, and `git worktree remove` deletes it without warning.
Anything a delegate must hand back goes to a tracked path committed on
its branch (for example its mission folder), never to scratch.

## Naming conventions

The directory gives uniqueness; the file name gives readability and
decides what the SessionEnd harvester does with the file.

| File | Name | At session end |
|------|------|----------------|
| Commit message | `commit-msg.txt` (or `commit-msg-<topic>.txt`) | left in place, not harvested |
| PR or issue body | `pr-body.md` | harvested (no ephemeral pattern yet) |
| Captured output | `build.log`, `check.log`, `smoke-test.log` | left in place, not harvested |
| Throwaway data | `<name>.tmp` | left in place, not harvested |
| Temp script | `task.sh`, `task.ps1`, `probe-<topic>.py` | harvested |
| Notes, research | `<NAME>-<topic>.md` | harvested |

Only names that start with `commit-msg`, end in `.log` or `.tmp`, or are
`.md` files whose name contains `log`, `output` or `dump` count as
ephemeral. A commit message named `msg-fix.txt` is harvested as an
artifact. Avoid `log`, `output` and `dump` in the name of a `.md` you
want kept (`S2-Catalog.md` is treated as ephemeral). Files in
subdirectories of the session dir are never harvested.

## Commit message pattern

Never inline a commit message, and never build one with `$(...)` or a
heredoc in Bash (the standing-order-guard blocks both). Write the file
with the Write tool, then commit with it:

1. Write `<session dir>/commit-msg.txt`:

   ```
   Imperative subject line

   Body: what changed, why, how it was verified.

   <attribution line from your current instructions>
   ```

   Copy the attribution line (`Co-Authored-By: ...`) from the
   instructions in your context at the time; do not reuse one from an
   old example, model names change.

2. Commit:

   ```bash
   git commit -F /abs/path/.scratch/session-10cf255a-c/commit-msg.txt
   ```

## PR body pattern

Write `<session dir>/pr-body.md` with the Write tool, then:

```bash
gh pr create --base main --head feature/x --title "Title" --body-file /abs/path/.scratch/session-10cf255a-c/pr-body.md
```

The same works for `gh issue create --body-file` and
`gh pr comment --body-file`.

## Complex script pattern

Any command longer than about three lines, or one that needs `&&`,
`||`, `;`, `$(...)` or backticks, goes in a script file (the
standing-order-guard blocks those inline). Write the script with the
Write tool, then run it with one Bash call.

macOS / Linux / Git Bash:

```bash
bash /abs/path/.scratch/session-10cf255a-c/task.sh
```

Windows / PowerShell (from Claude Code's Git Bash):

```bash
pwsh -NoProfile -File /abs/path/.scratch/session-10cf255a-c/task.ps1
```

Do not delete scratch files when you are done. The harvester decides
what to keep, and `rm` with globs is blocked.

## Lifecycle

Nothing in `.scratch/` is deleted by the harness.

- **SessionEnd** (`harvest-session.sh`, a shim for
  `ait-harvest.py harvest`): copies every non-ephemeral top-level file
  of your session dir to `harvesting/<UTC date>_session-<id>_<name>`
  (files starting with `handoff` go to `.aitools/channel/handoffs/`),
  records it in the harvest manifest, writes a `.harvested` marker in
  the session dir, and deletes `.scratch/.current-session`. The session
  dir and every file in it stay on disk.
- **SessionStart** (`session-catchup.sh`): harvests the same way any
  other `session-*` dir in this root that has no `.harvested` marker
  (for example a delegate's dir, or a session whose SessionEnd never
  ran). `scratch-init.sh` prints a count of dirs older than 24 hours
  and leaves them.
- Old session dirs accumulate until someone removes them by hand (with
  a cleanup script, not an inline `rm` glob).

**Never put carry-forward artifacts in scratch.** Handoffs, plans,
running estimates, mission reports and anything another session or
machine needs go to a tracked location (`plans/`, `reference/`,
`.aitools/channel/`) and are committed. A harvested copy is renamed
and only reaches other machines once someone commits `harvesting/`;
scratch itself never leaves the machine.

## .gitignore

`.scratch/` MUST be in `.gitignore` for every project. The aitools
repo has it. For other projects, add:

```
.scratch/
```

## Cross-References

- Governing rule: user rule `scratch.md` (source `shared/rules/scratch.md`
  in the aitools repo; deployed to `~/.claude/rules/` once
  deploy-harness ships a path for `shared/rules/`)
- Standing orders: USO "Scratch files for complex scripting" and USO
  "Simple Bash commands only" (user CLAUDE.md); enforcement in the
  standing-order-guard hook
- Delegation prompts (where to tell a delegate its dir): `/delegate`
  skill
- Artifact harvesting: `/harvest` skill
- SessionStart hooks: `shared/hooks/scratch-init.sh`,
  `shared/hooks/session-catchup.sh`
- SessionEnd hook: `shared/hooks/harvest-session.sh` (logic in
  `scripts/ait-harvest.py`)
