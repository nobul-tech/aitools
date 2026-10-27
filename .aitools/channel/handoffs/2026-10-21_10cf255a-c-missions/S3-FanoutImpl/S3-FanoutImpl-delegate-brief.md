# S3-FanoutImpl delegate brief (shared part of every FANOUT-IMPL delegate prompt)

Version 1.0, 2026-10-26, by S3-FanoutImpl (level 1, Session Commander
10cf255a-c). Every FANOUT-IMPL delegate reads this file in full, then its own
prompt. A delegate that delegates passes this path, the packet path and the
plan path on unchanged (the duty is recursive; invoke /delegate first).

## 1. Read first (in full, before other work)

- Mission packet: `/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/SC-mission-packet.md`
  and every file its section 1 lists that is not already in your context:
  `/Users/new-jose/.claude/CLAUDE.md`, `/Users/new-jose/.claude/rules/concurrent-agents.md`,
  `/Users/new-jose/.claude/rules/delegation.md`, `/Users/new-jose/repos/aitools/CLAUDE.md`,
  `/Users/new-jose/repos/aitools/.aitools/channel/CLAUDE.md`, every
  `/Users/new-jose/repos/aitools/.claude/rules/*.md` (agentic-standards, aitool-eval,
  aitool-ops, aitools-workspace, artifact-harvesting, config-file-safety,
  cross-platform, deploy-paths, documentation-standards, frameworks, git-safety,
  glossary, governed-data-access, hook-rollout, incident-governance,
  interactive-menus, managed-file-deployment, plan-execution, relay-outbound,
  script-standards, smoke-test-pattern, sources-of-truth, tool-evaluation,
  tool-lifecycle, tool-ops, web-sources).
- Reference (delegates): `/Users/new-jose/repos/aitools/reference/script-standards-detail.md`,
  `cross-platform-detail.md`, `logging.md`, `managed-file-deployment.md`,
  `plan-execution-detail.md`, `rules.md`, `harness.md` (all under
  `/Users/new-jose/repos/aitools/reference/`), plus what your prompt names.
- The plan: `/Users/new-jose/repos/aitools/plans/skills-and-rules-fanout.md` v1.0
  (contract section 3 is binding) and `/Users/new-jose/repos/aitools/plans/rules-fanout-claude.md`
  v1.0 (rules contract, FAN-PLAN batches A-D verbatim edits).
  If the main checkout's copy is missing, read them from
  `git -C /Users/new-jose/repos/aitools show origin/main:<path>`.

## 2. Commander decisions (binding; newest first, 2026-10-26)

- All project-scope rules AND skills deploy to user-scope Claude Code; the
  commander removes the duplicate project copies later. Cost accepted.
- Cursor gets every rule in ~/.aitools/rules minus `retired` (shared, aitools,
  dotprofile): reverses PR #110's user-level filter.
- Skills: shared/skills and .claude/skills (and the dotprofile claude/skills)
  -> ~/.aitools/skills -> fan-out like rules; `reference/skills.md` in
  `reference/rules.md`'s format.
- Skill conflicts: first source wins (shared/, .claude/, dotprofile); each
  skipped duplicate log_error + ERROR row; skills manifest records sources; a
  user's own skill in ~/.claude/skills or ~/.cursor/skills is never
  overwritten or pruned unless the fan-out created it.
- Small PRs, one per batch, base `main` always (never another PR's branch);
  a later branch merges the earlier FO head with `--no-ff`. Merged later, in
  order, by the merge orchestrator only (you never merge).
- Abort: PR #106 behaviour (only deploy-harness exit 2 stops the run);
  RECONCILE R8c's WARN row is not ours.
- Versions, not drafts (D-DEL5): documents are versions (v1.0, v1.1). A
  protected file is written as a version in the PR, and the PR body lists each
  protected edit old -> new under "Review after". plans/, handoffs, relay.md
  and CLAUDE.md go directly to main; code goes through PRs.
- Pre-push step 7 always runs and FAILs until MERGE-ALL rebuilds the
  dotprofile deploy/: record it, it is not yours.

## 3. Operational learning (carry forward)

- Section I of `/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-22_10cf255a-c.md`
  and packet section 5.
- Integration base: local branch `feature/fanout-base` (d7f6855) = origin/main
  03b833f + the open PR heads #109, #113, #112, #100, #110, #111, #115, #106.
  Your diff for review is against the base or the previous FO head, not main.
  Do not push `feature/fanout-base`.
- Worktrees: create yours with
  `git -C /Users/new-jose/repos/aitools worktree add -b <branch> /Users/new-jose/repos/aitools/.claude/worktrees/fo-<short> <start>`.
  Never switch the main checkout's branch; never remove any worktree;
  never force-push.
- Simple Bash only: no `&&`, `||`, `;`, `$(...)`, backticks, multi-line
  commands, globs in `rm`. Put anything longer in a scratch script under
  `<your worktree>/.scratch/session-<name, <= 10 chars>/` and run it. The
  standing-order-guard hook blocks cat/head/tail/sed/awk outside a pipeline
  (use Read) and `;` inside `pwsh -Command` (use `pwsh -File`).
- Read/Edit/Write for files; Perl, not sed. Delegates sometimes lack
  Grep/Glob: use grep/find in pipelines or scratch scripts.
- `.ps1` files check out with CRLF: the Edit tool matches them; perl edits
  must keep CRLF; line-anchored test patterns must allow `\r`. PowerShell names
  are case-insensitive. Backup-File/Backup-Dir use -LiteralPath (9923a3c):
  test names with `[ ]`.
- bash 3.2 compatible (no associative arrays, no `${x,,}`, no `mapfile`).
- A here-string-fed loop makes `tty_interactive` false (`[ -t 0 ]`): read
  deploy lists on fd 3 so the review menu can prompt.
- Isolated HOME only: never run aitools, aitools install, setup-user-*,
  deploy-harness or build-deploy.sh against the real HOME; never
  `check-post-push` before merge, never `check-pre-commit --fix`.
  Worktree-isolated agents cannot set HOME, so you are launched without it.
- Known pre-existing check failures (record, not blockers): pre-commit step 6
  (harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh 100644),
  pre-push step 7 (dotprofile deploy/ stale), pre-push step 3 `[\s]` false
  positives, post-push step 23 (FX-7 comment filter).
- Governed JSON (registries/*.json) only through its skill. Firecrawl is
  deprecated: do not use it.
- Reviewers post verdicts with `gh pr comment <n> -R nobul-tech/aitools
  --body-file <file>` (GitHub refuses --approve/--request-changes on the same
  account); start the comment with `VERDICT: APPROVE`, `VERDICT: APPROVE WITH
  CHANGES` or `VERDICT: REQUEST CHANGES`.
- Error-handling rules (non-negotiable, `reference/plan-execution-detail.md`):

```text
1. Every `-ErrorAction SilentlyContinue` MUST have a null/empty check within 3 lines
2. Every `2>/dev/null` MUST have a comment explaining why AND a result check
3. Every `|| true` MUST have a comment explaining why AND a result check
4. Every try/catch MUST have a catch that logs or re-throws; empty catch {} is NEVER OK
5. Exception: command-existence checks (Get-Command, command -v) with explicit fallback
6. Every log_error/LogError for a file write MUST pair with write_summary ERROR
7. Prefer `-ErrorAction Stop` with try/catch over `-ErrorAction SilentlyContinue`
8. `rm -f` in bash is OK for cleanup (ignores nonexistent; targeted, not blanket)
```

## 4. Running missions (do not collide)

- MERGE-ALL (Session Commander's workflow): merging #109, #113, #112, #100,
  #110, #111, #115, #106, #116, then post-merge work (#102 incidents, re-land
  #74/#75 -- moves 7 governance skills tool-ops, tool-eval, tool-registry,
  harvest, incident, glossary, frameworks from .claude/skills to
  shared/skills --, installer Step 8b `--skip-config`, D-DEL5, build-deploy
  backup-then-swap + dotprofile deploy/ rebuild, v0.74.0 notes + tag, GitHub
  cleanup). Its folder:
  `/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-MergeAll/`.
  Never touch its PRs, branches or worktrees.
- RECONCILE batches (R2, R2c, R3, R4 docs; R8c abort row; F-batches) may edit
  the same docs: pull and re-anchor before editing a doc.
- BUILD-PKG: owns `plans/build-package/` and package scripts; never edit them.

## 5. Open questions: answer from the commander's own words first

- Transcripts: `/Users/new-jose/.claude/projects/-Users-new-jose-repos-aitools/10cf255a-c378-45d7-83f1-a0baffa7c172.jsonl`
  (very large: never load whole), other sessions in
  `/Users/new-jose/.claude/projects/-Users-new-jose-repos-aitools/`, archived in
  `/Users/new-jose/repos/aitools-nobul-jose/sessions/`.
- Tools: `python3 /Users/new-jose/.aitools/bin/read-session.py --help`,
  `read-session-full.py --help`; AskUserQuestion answers are tool results:
  `/Users/new-jose/repos/aitools/.claude/worktrees/ansa/.scratch/session-trans/ask-answers.py`.
- Read the commander's (user) prompts newest first until answered; a newer
  statement overrides an older one; agent text is never a decision; record
  provenance (quote + session id + timestamp). What the record cannot answer:
  an open question with a suggested answer in your hand-back. Never ask the
  commander mid-run.

## 6. Shipping (D-DEL4)

Repo nobul-tech/aitools, PR base `main`, your branch `feature/fanout-<batch>`.
Commit with `git commit -F <scratch>/commit-msg.txt`: imperative subject;
body = what, why (decision IDs: FD-n of the plan), verification, not run,
`(tested: macOS)`, ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
Run `bash scripts/check-pre-commit.sh` and `bash scripts/check-pre-push.sh`
from your worktree. `git push -u origin <branch>`, then
`gh pr create -R nobul-tech/aitools --base main --head <branch> --title "..." --body-file <scratch>/pr-body.md`.
PR body sections: Summary; Why; Changes; Verification; Not run; Review after
(protected edits old -> new); Follow-ups; a line "Review diff: `git diff <base sha>...<head>`
(the PR also shows open MERGE-ALL PRs until they merge)"; end with
`🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
Never push to main, force-push, merge, approve your own PR, or tag.

## 7. WRITE_BLOCKED

If any write or tool call is denied (push and PR included), do not retry it in
another form: record `WRITE_BLOCKED: <what> -- <exact denial text>`, put the
content in your response, continue with what is not blocked.

## 8. Hand-back

Tracked path: `/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-FanoutImpl/<your name>/`
in the MAIN checkout path (untracked there; the orchestrator commits it).
Every `*.md` you create starts with your prefix (`S3-FanoutImpl-<Role>-`).
Final response: 5-line summary; PR URL; branch and head SHA; files changed;
verification (commands, results); not run; WRITE_BLOCKED lines; `INCIDENT:`
markers; open questions with suggested answers. Cite sources; say "unknown"
rather than guess.
