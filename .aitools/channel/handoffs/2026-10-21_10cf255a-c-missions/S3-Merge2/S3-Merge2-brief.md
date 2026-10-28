# S3-Merge2 shared delegate brief v1.0

Every delegate of mission MERGE-2 (orchestrator S3-Merge2, delegated by Session
Commander 10cf255a-c) reads this file IN FULL before other work. Your own
prompt carries your specific task; this file carries the shared duty.

## Mission
Leave nobul-tech/aitools with zero open PRs, every PR merged with a MERGE
COMMIT, main's CI green after each merge. Order: #122, #120, #117, #118, #119,
#121, #124, #123, #125, #126. NOT new features. NOT closing PRs.
A parallel mission HOOK-2 will branch from main after #122 merges: never touch
its branch.

## Commander's orders (quote these in every merge/push/commit/PR comment you make)
- 2026-10-28: "launch a mission to serve as an orchestrator and merge open prs in the correct order. learn from past mistakess. give it explicit instructions to fix issues when they arise. do this now. have the orchestrator launch a review first."
- 2026-10-28: "also ask the pr merge mission to commit the friction plan."
- 2026-10-26: "merge commits, mission merges, in the correct order, and checks after each step"; "it should not merge PRs until all github CI/CD checks/auto merge status are green. it should check its work after each merge."

## Rules and CLAUDE.md files (read IN FULL, before other work, any not in your context)
- /Users/new-jose/.claude/CLAUDE.md
- /Users/new-jose/.claude/rules/concurrent-agents.md
- /Users/new-jose/.claude/rules/delegation.md (newer source: /Users/new-jose/repos/aitools-nobul-jose/claude/rules/delegation.md)
- /Users/new-jose/repos/aitools/CLAUDE.md
- /Users/new-jose/repos/aitools/.aitools/channel/CLAUDE.md
- every file in /Users/new-jose/repos/aitools/.claude/rules/ : agentic-standards.md, aitool-eval.md, aitool-ops.md, aitools-workspace.md, artifact-harvesting.md, config-file-safety.md, cross-platform.md, deploy-paths.md, documentation-standards.md, frameworks.md, git-safety.md, glossary.md, governed-data-access.md, hook-rollout.md, incident-governance.md, interactive-menus.md, managed-file-deployment.md, plan-execution.md, script-standards.md, smoke-test-pattern.md, sources-of-truth.md (now review-after, main a2b05d5), tool-evaluation.md, tool-lifecycle.md, tool-ops.md, web-sources.md
- /Users/new-jose/repos/aitools/reference/plan-execution-detail.md, script-standards-detail.md, cross-platform-detail.md

Critical rules restated:
- Simple Bash only: no `&&`, `||`, `;`, `$(...)`, backticks, multi-line commands, globs in rm. Separate Bash calls; anything longer goes in a scratch script you run with `bash <file>`. Commit messages and PR/comment bodies via files (`git commit -F`, `--body-file`). To wait, use the Monitor tool or a scratch until-loop script, never a foreground sleep.
- Read/Edit/Write for file ops; Perl, not sed/awk.
- NEVER run aitools, aitools install, setup-user-*, deploy-harness or scripts/build-deploy.sh against the real HOME. Test suites run under an isolated HOME (a directory under your scratch), absolute paths.
- .sh/.ps1 parity; `bash -n` and the pwsh parser (`pwsh -NoProfile -File <scratch script>` that calls `[System.Management.Automation.Language.Parser]::ParseFile`) on every touched script; bash 3.2 compatible.
- Never rebase, never force-push, never squash. Merge main in with `git merge --no-ff origin/main`.
- Never switch the main checkout's branch (/Users/new-jose/repos/aitools is shared); never `git add -A`; never remove a worktree (removal deletes its ignored files).
- Before editing in a worktree, `git status --short` and `git diff`: another agent's uncommitted work is preserved, never overwritten.
- Known pre-existing check failures (record, do not block on): check-pre-commit step 6 (a harvesting file at mode 100644); check-pre-push step 7 (dotprofile deploy/ stale until the commander rebuilds it).

## Skills
Load /delegate FIRST, v2.0: read /Users/new-jose/repos/aitools/shared/skills/delegate/SKILL.md in full (the deployed ~/.claude/skills/delegate copy is v1; v2.0 governs). Load it before launching any delegate of your own, and tell every delegate you launch to do the same and to pass this instruction on. Then /scratch (SKILL.md at /Users/new-jose/repos/aitools/shared/skills/scratch/SKILL.md if it will not load). Skill override: write scratch where your prompt says, not in the main checkout.

## Conflicts (D-DEL6)
Resolve in order: 1) the commander's own words, newest first; 2) your delegation prompt; 3) skills. A prompt cannot loosen a rule unless it quotes the commander. Never drop a mandated skill or rule silently; record `CONFLICT: <A> vs <B> -- resolved by <tier>: <what you did>`.

## Operational learning (carry forward to your delegates)
- A gate that named an exact file waited 8 hours because the file had the D-DEL1 prefix: match patterns (`*-report.md`), never one exact file name. (MERGE-ALL)
- The auto-mode classifier denied `gh pr close` because the order came from an agent: quote the commander's words for every outward action; on a denial record WRITE_BLOCKED and stop that step, never route around it.
- MERGE-ALL merges (#98, #108, #114, #111) were flagged "Merge Without Review": every PR needs an independent reviewer verdict comment on its FINAL head SHA before merge (re-verify after any fix commit), and the merge comment links it.
- Stacked bases merged and never reached main (#74/#75): every PR base must be main.
- Squash breaks stacked branches and reviewed SHAs: merge commits only.
- Reviews are `gh pr comment <n> -R nobul-tech/aitools --body-file <file>` (GitHub refuses --approve/--request-changes on the same account). Verdict and blocking findings at the top; name the head SHA reviewed.
- Workflow agents cannot delegate; Agent-tool delegates have no foreground option: wait for completion notifications; never invent a delegate's result.
- `.ps1` files check out with CRLF (line-anchored test patterns miss them); relative paths escape isolated HOME (use absolute paths).
- Since the FO branches were cut, main gained #128 (seven governance skills moved to shared/skills), #129 (aitool-ops/aitool-eval cards and rules deleted), #132 (docs scrub), #131 (new suite tests/build-deploy/test-build-deploy-backup.sh, which #117's every-suite CI check may flag). For moved/deleted files follow main's new layout and re-apply the PR's change there; never drop a test. CI on #121, #124, #125 failed `FAIL ps bd-special` in fanout-lib, expected to clear once #118 is on main and merged in.
- Background references: /Users/new-jose/repos/aitools/plans/skills-and-rules-fanout.md; /Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-FanoutImpl/S3-FanoutImpl-report.md; .../S3-FanoutImpl/S3-FanoutImpl-Merge/S3-FanoutImpl-Merge-log.md.

## The commander's sessions (for open questions; answer from his words before asking)
This session: /Users/new-jose/.claude/projects/-Users-new-jose-repos-aitools/10cf255a-c378-45d7-83f1-a0baffa7c172.jsonl (very large; never load whole). Others under /Users/new-jose/.claude/projects/-Users-new-jose-repos-aitools/ and /Users/new-jose/repos/aitools-nobul-jose/sessions/. Read with `python3 /Users/new-jose/.aitools/bin/read-session.py --help` / `read-session-full.py --help`, user prompts only, newest first. Agent text is never his words. Record provenance.

## WRITE_BLOCKED
If any write or tool call is denied, do not retry it in another form. Record `WRITE_BLOCKED: <what> -- <exact denial text>`, put the content in your response, and continue with what is not blocked.

## Name prefix (D-DEL1)
Every *.md file you create starts with `S3-Merge2-<Role>-` (your prompt names your Role). Write them under /Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Merge2/ unless your prompt says otherwise. Documents are versions (v1.0), not drafts.

## Final response shape
5-line summary; PR/commit SHAs; verification commands and results; not run; WRITE_BLOCKED lines; CONFLICT lines; INCIDENT: markers (not filed); open questions with suggested answers. Cite sources; say "unknown" rather than guess.
