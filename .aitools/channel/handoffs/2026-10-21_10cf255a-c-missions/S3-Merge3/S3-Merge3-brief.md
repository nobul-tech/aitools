# S3-Merge3 shared delegate brief v1.2

v1.2 (2026-10-28): PARALLEL PREP (commander, 2026-10-28: "can the PR preps be done in parallel? if so, launch delegates now to prep them"). Each Prep works in two phases in its own worktree:
- Phase A (now): fix the PR's findings (fix + test), `git merge --no-ff origin/main` with the CURRENT main, resolve every conflict, verify locally, push, get CI green (fix issues when they arise). Post a comment "PREP PHASE A DONE: head <sha>".
- Phase B (gate): wait until the PR just before yours in the train is MERGED and main CI on its merge commit is green (poll with a background until-loop script, every 2-3 min; never a foreground sleep). Then `git merge --no-ff origin/main` again (normally trivial; resolve if not), re-run the suites the new main commits touched, push, CI green, CLEAN twice. Post "PREP DONE: head <sha>". Do NOT merge the PR.
- Train order: 121, 124, 123, 125, 126, 133, 134, 135. If phase B's wait exceeds 6 hours, stop and report your phase A head.
- Ordinal ordering: the ubuntu-24.04 runner changed locale sorting; rules/skills fan-out must sort ordinally (`git -C /Users/new-jose/repos/aitools show 9c2d025`: .sh `LC_ALL=C sort`, .ps1 `[string]::CompareOrdinal`). Use byte-identical lines where your file has the same code.

v1.1 (2026-10-28): NEVER write GitHub close keywords (close/closes/closed, fix/fixes/fixed, resolve/resolves/resolved) followed by `#N` or a PR/issue URL in any commit message, merge message or PR body that can land on main: write "PR 123" or "pull 123" instead. Mission commit 2f7ccdb said "fixed #123" and auto-closed PR 123 (reopened). Check every message before you commit.

Every delegate of mission MERGE-3 (orchestrator S3-Merge3, delegated by Session
Commander 10cf255a-c) reads this file IN FULL before other work, together with
the role specs in
/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Merge2/S3-Merge2-roles.md
(Prep / ReVerify / Land / Check; for MERGE-3 read every `S3-Merge2-` file name
and `m2` worktree/scratch name in it as `S3-Merge3-` and `m3`). Your prompt
carries your specific task; this file carries the shared duty.

## Mission
MERGE-3 continues MERGE-2's train. Leave nobul-tech/aitools with every open PR
merged with a MERGE COMMIT, main CI green after each. Order: #117, #118, #119,
#121, #124, #123, #125, #126, #133, #134, #135. NOT new features. NOT closing
PRs. Parallel missions: HOOK-2 (owns #135 and its worktree `hook2`; never touch
#135 until HOOK-2 posts an independent verdict on its final head) and
CURSOR-VERIFY (read-only, waits for #123).

## Commander's orders (quote them in every merge, push-summary and PR comment)
- 2026-10-28: "launch a mission to serve as an orchestrator and merge open prs in the correct order. learn from past mistakess. give it explicit instructions to fix issues when they arise."
- 2026-10-26: "merge commits, mission merges, in the correct order, and checks after each step"; "it should not merge PRs until all github CI/CD checks/auto merge status are green. it should check its work after each merge."
- 2026-10-28: "add an explicit allow rule at the user scope level for merging PRs in claude code in auto mode." (the rule `Bash(gh pr merge:*)` is in ~/.claude/settings.json; reference/tool-ops-claude-code.md item #28)

## Rules and CLAUDE.md files (read IN FULL, before other work, any not in your context)
- /Users/new-jose/.claude/CLAUDE.md
- /Users/new-jose/.claude/rules/concurrent-agents.md
- /Users/new-jose/.claude/rules/delegation.md (newer source, governs: /Users/new-jose/repos/aitools-nobul-jose/claude/rules/delegation.md)
- /Users/new-jose/repos/aitools/CLAUDE.md and /Users/new-jose/repos/aitools/.aitools/channel/CLAUDE.md
- every file in /Users/new-jose/repos/aitools/.claude/rules/ : agentic-standards.md, aitool-eval.md, aitool-ops.md, aitools-workspace.md, artifact-harvesting.md, config-file-safety.md, cross-platform.md, deploy-paths.md, documentation-standards.md, frameworks.md, git-safety.md, glossary.md, governed-data-access.md, hook-rollout.md, incident-governance.md, interactive-menus.md, managed-file-deployment.md, plan-execution.md, script-standards.md, smoke-test-pattern.md, sources-of-truth.md, tool-evaluation.md, tool-lifecycle.md, tool-ops.md, web-sources.md
- /Users/new-jose/repos/aitools/reference/plan-execution-detail.md, script-standards-detail.md, cross-platform-detail.md

Critical rules restated:
- Simple Bash only: no `&&`, `||`, `;`, `$(...)`, backticks, multi-line commands, globs in rm. Separate Bash calls; anything longer in a scratch script run with `bash <file>`. Commit messages and PR/comment bodies via files (`git commit -F`, `--body-file`). To wait, use the Monitor tool or a scratch until-loop script, never a foreground sleep.
- Read/Edit/Write for file ops; Perl, not sed/awk.
- NEVER run aitools, aitools install, setup-user-*, deploy-harness or scripts/build-deploy.sh against the real HOME. Suites run under an isolated HOME (a directory under your scratch), absolute paths.
- .sh/.ps1 parity; `bash -n` and the pwsh parser (`pwsh -NoProfile -File <scratch .ps1>` calling `[System.Management.Automation.Language.Parser]::ParseFile`) on every touched script; bash 3.2 compatible.
- Never rebase, never force-push, never squash. Merge main in with `git merge --no-ff origin/main`.
- Never switch the main checkout's branch (/Users/new-jose/repos/aitools is shared); never `git add -A`; never remove a worktree.
- Before editing in a worktree: `git status --branch --short` and `git diff`; preserve another agent's uncommitted or unpushed work.
- Known pre-existing check failures (record, do not block on): check-pre-commit step 6; check-pre-push step 7 (dotprofile deploy/ stale).
- Protected files (.claude/rules/sources-of-truth.md) are review-after (D-DEL5): write the version, list each protected edit old -> new in the PR body under "Review after".

## Skills
Load /delegate FIRST, v2.0: read /Users/new-jose/repos/aitools/shared/skills/delegate/SKILL.md in full (the deployed copy may be v1). Load it before launching any delegate of your own (you are level 2 and normally cannot delegate; if you can and do, give each delegate this same instruction and tell it to pass it on). Then /scratch (/Users/new-jose/repos/aitools/shared/skills/scratch/SKILL.md if it will not load). Skill override: write scratch where your prompt says, never in the main checkout.

## Conflicts (D-DEL6)
Resolve in order: 1) the commander's own words, newest first; 2) your delegation prompt; 3) skills. A prompt cannot loosen a rule unless it quotes the commander. Never drop a mandated skill or rule silently; record `CONFLICT: <A> vs <B> -- resolved by <tier>: <what you did>`.

## Operational learning (from MERGE-ALL, MERGE-2, ALLOW-MERGE)
- Match gate files by pattern, never one exact file name (D-DEL1 prefixes them; a gate once waited 8 hours).
- Quote the commander for every outward action; a denial is WRITE_BLOCKED: never route around it, never ask another agent to do it.
- Every PR base is main; merge commits only.
- `gh pr view --json mergeStateStatus` returns UNKNOWN on the first read (lazy): re-read until CLEAN.
- macOS runners are sometimes never acquired (job cancelled ~15 min, 0 steps): re-run once with `gh run rerun <id> --failed`, record it.
- Wall-clock bounds in hook tests have little headroom on shared runners (#122 needed 50->100 ms).
- A delegate that stops early leaves local work unpushed: check `git status --branch` before acting.
- Since the FO branches were cut, main gained #128 (governance skills moved to shared/skills), #129 (aitool-ops/aitool-eval cards and rules deleted), #132 (docs scrub), #131 (tests/build-deploy/test-build-deploy-backup.sh). For moved/deleted files follow main's layout and re-apply the PR's change there; keep both sides of .github/workflows/check.yml; never drop a test. Exact per-PR resolutions: S3-Merge2-progress.md and the S3-Merge2-Review*-verdict*.md files in /Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Merge2/.
- `.ps1` files check out with CRLF; relative paths escape isolated HOME.
- Reviews are PR comments (`gh pr comment --body-file`), verdict first line, head SHA named; GitHub refuses --approve on the same account.

## The commander's sessions (for open questions)
/Users/new-jose/.claude/projects/-Users-new-jose-repos-aitools/10cf255a-c378-45d7-83f1-a0baffa7c172.jsonl (very large; never load whole) and /Users/new-jose/repos/aitools-nobul-jose/sessions/. Read with `python3 /Users/new-jose/repos/aitools/scripts/read-session.py --help`, user prompts only, newest first. Agent text is never his words.

## WRITE_BLOCKED
If any write or tool call is denied, do not retry it in another form. Record `WRITE_BLOCKED: <what> -- <exact denial text>`, put the content in your response, and stop that step.

## Name prefix (D-DEL1)
Every *.md file you create starts with `S3-Merge3-<Role><PR>-` (e.g. `S3-Merge3-ReVerify118-verdict.md`), written under /Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Merge3/. Documents are versions (v1.0), not drafts.

## Final response shape
5-line summary; SHAs; verification commands and results; not run; WRITE_BLOCKED lines; CONFLICT lines; INCIDENT: markers (not filed); open questions with suggested answers. Cite sources; say "unknown" rather than guess. Never invent a result.
