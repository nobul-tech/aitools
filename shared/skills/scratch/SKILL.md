---
name: scratch
description: "Ephemeral session scratch files — session directories,
  naming conventions, commit message pattern. Use when writing temp
  files, staging commit messages, or running complex scripts that
  should not be inlined."
---

## Intent

**Purpose**: Manage ephemeral scratch files during a session —
session directory creation, naming conventions, cleanup, and the
commit message staging pattern. **Scope**: Ephemeral file lifecycle
only. NOT artifact harvesting (see `/harvest` skill in projects
that have `harvesting/`). NOT standing-order enforcement (that's
the standing-order-guard hook). **Audience**: Every agent in every
project.

## Session scratch directory

Each session gets a unique directory. The SessionStart hook
(`scratch-init.sh`) creates it automatically:

```
.scratch/session-XXXXXXXXXX/
```

All session temp files go INSIDE this directory. Never write
directly to `.scratch/` root — that causes filename collisions
across sessions.

### Finding the session dir

The session dir path is written to `.scratch/.current-session`
at session start. Read it to find your directory:

```bash
SESSION_DIR=$(cat .scratch/.current-session 2>/dev/null)
```

If `.current-session` doesn't exist (session started without the
hook), create the dir manually:

```bash
SESSION_DIR=$(mktemp -d .scratch/session-XXXXXXXXXX)
```

## Naming conventions

Use predictable names INSIDE the session dir. The directory
provides uniqueness; filenames provide readability.

| File | Name | Purpose |
|------|------|---------|
| Commit message | `commit-msg.txt` | Staging for `git commit -F` |
| Build log | `build.log` | Captured script output |
| Check log | `check.log` | Captured check script output |
| Temp script | `task.sh` or `task.ps1` | Complex commands that shouldn't be inlined |
| Smoke test log | `smoke-test.log` | Setup script output capture |

## Commit message pattern

Never inline commit messages with `$(...)`. Write to the session
dir and use `git commit -F`:

```bash
# Write message to session scratch dir
cat > "$SESSION_DIR/commit-msg.txt" << 'EOF'
Your commit message here.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF

# Commit using the file
git commit -F "$SESSION_DIR/commit-msg.txt"
```

## Complex script pattern

Per USO: never inline commands longer than ~5 lines. Write to the
session dir, execute, clean up:

```bash
# Write the script
cat > "$SESSION_DIR/task.sh" << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
# ... complex logic here ...
SCRIPT

# Execute
bash "$SESSION_DIR/task.sh"
```

## Scratch lifecycle warning

**Files in scratch are DELETED by the SessionEnd hook
(`harvest-session.sh`).** Non-ephemeral `.md` files are copied to
`harvesting/` with a date prefix (e.g.,
`harvesting/2026-03-19_filename.md`) before deletion. All other
files are deleted without backup.

**Never put carry-forward artifacts in scratch.** Handoff prompts,
planning briefs, running estimates, and any artifact that must
survive the session MUST be written to a permanent tracked location
(`plans/`, `reference/`, `.aitools/channel/`). A handoff written to
scratch will not survive the session that created it.

The scratch directory itself (`session-XXXXXXXXXX/`) is removed by
`rm -rf` after harvesting completes (lines 164-166 of
`harvest-session.sh`).

## What goes in .scratch/

**Ephemeral (deleted at session end):**
- Commit messages
- Build/check/smoke-test logs
- Temp scripts
- Output captures

**Artifacts (harvested at session end if project has `harvesting/`):**
- Python/bash/PowerShell utilities written to solve a problem
- Research documents, analysis outputs
- Prompt patterns that produced good results

The SessionEnd hook (`harvest-session.sh`) classifies contents
and handles both — deleting ephemeral files and harvesting
artifacts.

## .gitignore

`.scratch/` MUST be in `.gitignore` for every project. The
aitools repo already has this. For other projects, add it:

```
.scratch/
```

## Cross-References

- Standing-order enforcement: standing-order-guard hook
- Artifact harvesting: `/harvest` skill (project-level)
- SessionStart hook: `shared/hooks/scratch-init.sh`
- SessionEnd hook: `shared/hooks/harvest-session.sh`
