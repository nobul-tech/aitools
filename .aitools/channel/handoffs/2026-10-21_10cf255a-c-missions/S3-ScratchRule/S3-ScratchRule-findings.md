# S3-ScratchRule findings

Each /scratch inconsistency, with file:line evidence and its resolution.
Line numbers refer to origin/main db4b3c5 unless the path is the main
checkout (`/Users/new-jose/repos/aitools/`), which is noted. Observations of
live state were made 2026-10-21/22 UTC.

## Probe

`.scratch/session-S3-ScratchRule/probe-worktree-remove.sh` (gitignored, in
the mission worktree) built a throwaway repo and ran the real
`scripts/ait-harvest.py harvest` against it with an isolated `HOME`.
Output (verbatim, abridged to the result lines):

```
remove exit=0
wt dir gone (ignored .scratch deleted with it)
-- harvesting/:
2026-10-22_session-abcdefghij_.harvested-like
2026-10-22_session-abcdefghij_events.jsonl
2026-10-22_session-abcdefghij_msg-topic.txt
2026-10-22_session-abcdefghij_pr-body.md
2026-10-22_session-abcdefghij_task.sh
harvest-manifest.json
-- session dir after:
.harvested .harvested-like build.log commit-msg.txt events.jsonl msg-topic.txt pr-body.md subdir task.sh
-- .current-session after:
removed
```

So: `git worktree remove` (no `--force`) exits 0 and deletes an ignored
`.scratch/`; the harvester copies, never deletes; it skips `commit-msg.txt`
and `build.log`; it harvests `msg-*.txt`, `pr-body.md`, `events.jsonl` and
dotfiles; it ignores subdirectories; it deletes `.scratch/.current-session`.

## 1. Location: `.scratch/`, not `.aitools/scratch/`

- Code: `shared/hooks/scratch-init.sh:34-40` resolves
  `git rev-parse --show-toplevel` (fallback `pwd`) and uses
  `$PROJECT_ROOT/.scratch`; `:60-64` names the dir
  `session-<first 10 chars of session_id>` (mktemp only when session_id is
  empty, `:65-67`); `:70` writes `.scratch/.current-session`; `:119` prints
  `Session scratch directory: <path>` into the session context.
  `scripts/ait-harvest.py:759` (`project_root / ".scratch"`) and `:92-94`
  (`SCRATCH_PREFIX_LEN = 10`) match. Every hook that logs events reads
  `<git root>/.scratch/.current-session` (standing-order-guard.sh:68,
  delegation-duty-guard.sh:56, sh-file-fixup.sh:21,
  intelligence-stop.py:367).
- Spec that disagrees: `.claude/rules/aitools-workspace.md:37` lists
  `scratch/` under `<repo>/.aitools/`, and `:64-68` says the namespace
  consolidation `.scratch/` -> `.aitools/scratch/` and `harvesting/` ->
  `.aitools/harvesting/` is the governing decision. Only
  `scripts/aitools-dashboard.sh:180-184` (and `.ps1:128`) look in
  `.aitools/scratch/`. The harvester writes `<root>/harvesting/`
  (`ait-harvest.py:779`), not `.aitools/harvesting/`. `.gitignore:32` and
  `:52` ignore both `.scratch/` and `.aitools/scratch/`.
- Resolution: the skill documents `.scratch/session-<10-char session id>/`
  (what runs) and says `.aitools/scratch/` is documented but not
  implemented. The rule text in aitools-workspace.md is protected:
  INCIDENT (see incidents file, S3-SR-1).

## 2. Lifecycle: nothing is deleted

- Skill (old) `shared/skills/scratch/SKILL.md:97-111`: "Files in scratch are
  DELETED by the SessionEnd hook", "removed by `rm -rf` ... (lines 164-166
  of `harvest-session.sh`)"; `:115` "Ephemeral (deleted at session end)".
- Code: `shared/hooks/harvest-session.sh` is 65 lines (no line 164); it is a
  shim that pipes stdin to `ait-harvest.py harvest` (`:60`), header `:15-16`
  "never deletes scratch dirs". `ait-harvest.py:752-754` docstring "Never
  deletes scratch dirs"; `:796-798` ephemeral files are counted
  (`deleted += 1`) and skipped, not unlinked; `:812-833` non-ephemeral files
  are copied (`shutil.copy2`) to `harvesting/<UTC date>_session-<prefix>_<name>`;
  `:863-867` unlinks only `.scratch/.current-session`; `:873-875` writes a
  `.harvested` marker in the session dir. `scratch-init.sh:45-54` only
  counts and prints stale dirs. The probe confirms.
- Live state: the main checkout `.scratch/` holds 46 `session-*` dirs, the
  oldest from 2026-06-21 (`ls -la /Users/new-jose/repos/aitools/.scratch`).
- `.claude/rules/artifact-harvesting.md:65-67` ("no longer deletes --
  v0.64.1") is correct.
- Same stale claim elsewhere: `shared/skills/handoff/SKILL.md:318-319`
  (cites "harvest-session.sh lines 164-166"), `:367`, `:545`, `:598`;
  `shared/claude-shared.md:124` and dotprofile `claude/CLAUDE.md:167`
  ("The SessionEnd hook handles cleanup"); prior handoff
  `2026-10-21_360aa8f3-8.md:7` (provenance, left as is).
- Resolution: skill rewritten to the copy-not-delete lifecycle with the
  classifier's real rules. Other files: INCIDENT S3-SR-2.

## 3. Attribution in the commit example

- Skill (old) `:71`: `Co-Authored-By: Claude Opus 4.6 (1M context) ...`.
  Current attribution: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
  (mission packet section 4).
- Resolution: the example uses a placeholder line and says to copy the
  attribution line from the session's current instructions.

## 4. Finding your own session dir; delegates

- Delegates get no SessionStart hook (mission packet section 2;
  `shared/hooks/hooks-manifest.json:13-16` registers scratch-init only for
  SessionStart, and has no SubagentStart entry).
- `.current-session` is one pointer per repo root, shared by every session
  in that checkout: each SessionStart overwrites it (`scratch-init.sh:70`)
  and every harvest deletes it (`ait-harvest.py:863-867`), including
  catch-up harvests of other sessions' orphaned dirs (`:1131`). Observed:
  `/Users/new-jose/repos/aitools/.scratch/.current-session` absent while
  session 10cf255a-c was live; its dir
  `.scratch/session-10cf255a-c/.harvested` contains `2026-10-21T05:05:52Z`
  although the session kept running and writing to the dir afterwards
  (files dated through 2026-10-21 17:40 local). Reading `.current-session`
  can therefore return nothing or another session's dir.
  `intelligence-stop.py:366-376` falls back to `session-<session_id[:10]>`;
  the bash hooks do not.
- Old skill `:37-46` told agents to `cat` the pointer and fall back to
  `mktemp -d`.
- Resolution: the skill tells the main agent to take its dir from the
  `Session scratch directory:` line in its context (scratch-init.sh:119),
  to use `.current-session` only as a checked fallback, and tells a
  delegate to create `<its repo or worktree root>/.scratch/session-<DELEGATE-NAME>/`
  with `mkdir -p`, the path given in the delegation prompt. INCIDENT S3-SR-3
  for the shared pointer.

## 5. Git worktrees

- `git rev-parse --show-toplevel` returns the worktree's own root, so each
  worktree has its own `.scratch/` (scratch-init.sh:35;
  ait-harvest.py:221-234, :1104-1110). A session's SessionEnd and catch-up
  sweep only that session's root (`ait-harvest.py:759`, `:1108`).
- Consequence: a delegate's dir in a worktree is never harvested unless a
  session starts in that worktree, and `git worktree remove` deletes it
  without warning (probe). Worktree-isolated delegates cannot write to the
  main checkout's `.scratch/` (incident #83; /delegate SKILL.md:193-197).
- Resolution: the skill says a delegate in a worktree uses that worktree's
  `.scratch/`, and anything that must outlive it goes to a tracked path
  committed on the branch (the mission folder). INCIDENT S3-SR-4 (worktree
  scratch is lost silently).

## 6. shared/rules is not deployed

- `shared/rules/` does not exist on origin/main (`ls` in the worktree:
  "No such file or directory"); in the main checkout it exists, empty and
  untracked (`ls -la /Users/new-jose/repos/aitools/shared`). Git does not
  track empty directories.
- User rules deploy only from the dotprofile:
  `scripts/setup-user-claude.sh:265-266` (`$USER_REPO_PATH/claude/rules`),
  `scripts/build-deploy.sh:164-165`; `reference/user-repo.md:181-195`.
  The dotprofile `claude/rules/` holds `concurrent-agents.md` and
  `delegation.md` (precedent for a user rule placed there, D-DEL2).
- Resolution: the rule ships as a draft in the mission folder; options in
  `S3-ScratchRule-deploy-gap.md`.

## 7. The skill's examples were blocked by the guard

- Old skill `:38` `SESSION_DIR=$(cat .scratch/.current-session 2>/dev/null)`
  and `:45` `$(mktemp -d ...)`: `$(...)` is blocked (standing-order-guard,
  `MODE_SUBSHELL="enforce"`, `:50`). `:66-76` and `:84-93` are multi-line
  heredoc Bash commands: blocked by the 4-line check (`:161-165`,
  `MODE_SCRATCH="enforce"`) and against USO "Dedicated tools for file ops"
  (incident #46 is the same pattern).
- Resolution: the skill's examples use the Write tool for file content and
  one-line Bash calls with literal paths.

## 8. The classifier keeps staging files and harness bookkeeping

- `ait-harvest.py:703-723`: ephemeral = name starts `commit-msg`, ends
  `.log`/`.tmp`, a few `.json` names, `.md` containing log/output/dump.
  Everything else, including unknown extensions and dotfiles, is harvested
  and labelled `"type": "code"` (`:844-853`).
- Evidence in `/Users/new-jose/repos/aitools/harvesting/`: commit messages
  not named `commit-msg*` (`2026-10-21_session-360aa8f3-8_msg-incidents.txt`
  and four more `msg-*.txt`, `2026-10-21_session-10cf255a-c_msg-leftovers.txt`,
  `2026-06-21_8_session-eafcf161-5_dotprofile-commit-v71.txt`), PR and issue
  bodies (`..._pr-issue9-body.md`, `..._issue7-body.md`), and harness files
  (`..._.harvested`, 20+ `..._.intelligence-last-check`, 20+
  `..._events.jsonl`). The probe reproduces each case.
- Resolution: the skill states the naming that the classifier treats as
  ephemeral today (`commit-msg*`, `*.log`, `*.tmp`) and that a PR body has
  no ephemeral pattern yet. INCIDENT S3-SR-5 (overlaps #73, which covers the
  log/output/dump substring rule and subdirectories).

## 8b. A session-dir suffix longer than 10 characters makes catch-up harvest the wrong dir

- `ait-harvest.py:1126` takes the dir suffix (`S3-ScratchRule`) and
  `:1131` passes it as `session_id`; `:760` truncates it to 10 characters
  (`S3-Scratch`); `:763` finds no `session-S3-Scratch`; `:765-773` falls
  back to `.scratch/.current-session` and harvests the dir it names.
- Probe `.scratch/session-S3-ScratchRule/probe-long-name.sh` (isolated
  `HOME`, throwaway repo, live dir `session-LIVE012345` named in the
  pointer, orphan `session-S3-ScratchRule`), `ait-harvest.py catchup`:

  ```
  -- harvesting/:
  2026-10-22_session-S3-Scratch_live-work.sh
  -- live dir:
  .harvested
  live-work.sh
  -- delegate dir:
  delegate-work.sh
  -- .current-session:
  removed
  ```

  The live session's file was harvested under the delegate's truncated
  name, the live dir was marked `.harvested`, the pointer was deleted,
  and the delegate's dir was left unmarked (so the next SessionStart
  repeats the miss).
- The mission packet (section 2) tells delegates to use
  `.scratch/session-<YOUR-NAME>`; names such as `S3-ScratchRule` and
  `S3-SourceTruth` are longer than 10. In a worktree nobody sweeps it, so
  the bug fires only if a session later starts in that worktree, or if a
  delegate uses the main checkout.
- Resolution: the skill says to keep the suffix at 10 characters or fewer.
  INCIDENT S3-SR-8 (high).

## 9. Smaller items

- standing-order-guard scratch message (`:164`) says "Write it to a temp
  .sh or .ps1 file ... then clean up": it names no session dir, and
  "clean up" conflicts with harvesting and with the rm-glob ban. File owned
  by parallel mission S3-HooksFix: reported only (INCIDENT S3-SR-6).
- `.claude/rules/incident-governance.md` "Hook specifications" says a
  SubagentStart hook serves "skill content + governance duty + scratch
  namespace"; `hooks-manifest.json` registers no SubagentStart hook.
  INCIDENT S3-SR-7.
- The skill intent says it covers "cleanup"; there is none. Intent is
  protected: drafted, not written (see report).
