# S3-Reconcile delegate common brief (2026-10-26)

Shared part of every S3-Reconcile delegate prompt. Read it in full, then the
mission packet and its section 1. Pass this file's path AND the packet path to
any delegate you launch (the delegation duty is recursive).

## Who delegates to you
S3-Reconcile (orchestrator, level 1) for Session Commander 10cf255a-c. Mission
RECONCILE: write `plans/fan-plan-reconciliation.md` v1.0, an executable plan that
reconciles code, docs and the commander's decisions for every pending item in the
deployment area. You are a READ-ONLY research delegate: you change no repo file.
You write only your findings file(s) in
`/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Reconcile/`
and scratch scripts in your own scratch dir.

## Rules (read before other work)
1. Mission packet, in full, and every file in its section 1:
   `/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/SC-mission-packet.md`
   - User: /Users/new-jose/.claude/CLAUDE.md, /Users/new-jose/.claude/rules/concurrent-agents.md, /Users/new-jose/.claude/rules/delegation.md
   - Project: /Users/new-jose/repos/aitools/CLAUDE.md (updated 2026-10-26: "Channel exception (direct to main)"), /Users/new-jose/repos/aitools/.aitools/channel/CLAUDE.md, every /Users/new-jose/repos/aitools/.claude/rules/*.md (list: `ls /Users/new-jose/repos/aitools/.claude/rules/`), and /Users/new-jose/repos/aitools/.cursor/rules/*.mdc where your task touches them.
   - Reference (delegates): /Users/new-jose/repos/aitools/reference/script-standards-detail.md, cross-platform-detail.md, logging.md, managed-file-deployment.md, plan-execution-detail.md, harness.md, plus the ones your task names.
2. Critical rules restated:
   - Read-only on the repo. Never `git checkout`/`switch` in the main checkout; never `git worktree remove`; never `git add`/commit/push (only S3-Reconcile commits).
   - Never run `aitools`, `aitools install`, `setup-user-*`, `deploy-harness`, `build-deploy.sh`, or `check-pre-push.sh` against the real HOME (they rebuild/delete the real dotprofile deploy/).
   - Simple Bash only: no `&&`, `||`, `;`, `$(...)`, backticks, multi-line commands; cat/head/tail/sed/awk outside a pipeline are blocked (use Read; `sed -n 'N,Mp' file` read-only is allowed). Longer logic: a scratch script, then run it.
   - Read/Edit/Write for files; Perl not sed/awk for transformations.
   - Governed JSON (registries/*.json) is read through its skill's process; reading it for research is allowed, writing it is not.
   - Firecrawl is deprecated: do not use it.
   - Cite a source for every claim (file:line on a named ref such as origin/main, command output, PR number, transcript session+uuid+timestamp). Say "unknown" rather than guess.
   - Agent text is never a commander decision. Only Jose's own words (user prompts, AskUserQuestion answers, his PR comments, commits he authored by hand) are decisions. A newer statement overrides an older one.

## Skills
/scratch, /delegate (only if you delegate), /investigate where useful, /incident and /glossary read-only. If a skill will not load, read its SKILL.md under /Users/new-jose/.claude/skills/<name>/ or /Users/new-jose/repos/aitools/{shared/skills,.claude/skills}/<name>/ and follow it by hand.

## Operational learning (carry forward)
- Handoff /Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-22_10cf255a-c.md section I (read it) and packet section 5.
- Subagents may lack Grep/Glob: use `grep -rn`/`find` in pipelines or scratch scripts.
- `.ps1` files check out with CRLF: line-anchored patterns miss them.
- Use absolute paths everywhere. Read code at a named ref: `git -C /Users/new-jose/repos/aitools show origin/main:<path>` (origin was fetched 2026-10-26; main HEAD 8e490d7) or PR branches `origin/<branch>:<path>`. The main checkout working tree is at 8e490d7 too.
- AskUserQuestion answers are not in plain user-prompt text: they arrive as tool_result. Reuse the filters:
  - /Users/new-jose/repos/aitools/.claude/worktrees/ansa/.scratch/session-trans/ask-answers.py
  - /Users/new-jose/repos/aitools/.claude/worktrees/ansb/.scratch/session-ansb/user-prompts.py and window.py
  - /Users/new-jose/repos/aitools/scripts/read-session.py --help, read-session-full.py --help (copies in /Users/new-jose/.aitools/bin/)
- Prior answers already established (do not redo; verify only if your task depends on them):
  - S3-AnsA report: /Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-AnsA/S3-AnsA-report.md
  - S3-AnsB report: /Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-AnsB/S3-AnsB-report.md
  - S3-MdmPkg report: /Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-MdmPkg/S3-MdmPkg-report.md
  - S3-FanPlan findings (plan still in progress): /Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-FanPlan/
  - S3-AbortDocs hand-back: `git -C /Users/new-jose/repos/aitools show origin/feature/harness-hookin:.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-AbortDocs/S3-AbortDocs-handback.md`

## Commander decisions given to S3-Reconcile (binding; newest first; verify wording where you rely on it)
- 2026-10-26: plans/, handoffs, relay.md and CLAUDE.md are committed directly to main from the main checkout (CLAUDE.md "Channel exception", main 1af8851). Pre-push step 7 always runs (8e490d7). Abort: keep #106's behaviour (only deploy-harness exit 2 stops a run); docs updated on #106 (3de51d6). Dotprofile pushes from a non-main branch are an ERROR. Backup-File literal path fix on main (9923a3c). M3-FINISH protected drafts approved; logging I-1 (not yet for the sync loop), I-2, I-4 approved. HARNESS-2: deploy-paths.mdc twin approved ("1d) approved"); Manifest/Cursor/MDM doc drafts approved; row 6 wording "... or --no-machine when they leave this machine unregistered"; row 8 relay intent to be redrafted after #103 and #106 merge. build-package: parallel package distribution (BUILD-PKG mission; do not touch plans/build-package/).
- 2026-10-23T01:58:29Z uuid e073aea3: "3) put aitools rules in the user space of claude code" (fan-out ordered; Cursor user-level only per the assistant's reading).
- 2026-10-26T21:58:13Z uuid cb1f0201: "6) re-factoring setup-user-claude and the fan-out requires a mission to create a plan" (FAN-PLAN, running; do not redo it).
- Earlier: the 95 gate decisions in /Users/new-jose/repos/aitools/plans/tool-support-and-machine-profile.md and handoff D.3.

## Parallel missions (do not overlap or edit)
FAN-PLAN (S3-FanPlan, setup-user-claude ~/.aitools/rules fan-out plan), BUILD-PKG (S3-BuildPkg, plans/build-package/). Do not touch any worktree under /Users/new-jose/repos/aitools/.claude/worktrees/ (read-only reads are fine).

## Name prefix (D-DEL1)
Every *.md you create starts with your own prefix, `S3-Reconcile-<Role>-` (for example `S3-Reconcile-Git-findings.md`). Never start a name with REPORT/SUMMARY/FINDINGS/ANALYSIS; avoid "log", "output", "dump" in names.

## Scratch
Your own dir: `/Users/new-jose/repos/aitools/.scratch/session-<name>/` with <name> 10 characters or fewer, as your prompt states. Hand-back content goes in your findings file (tracked path), never only in scratch.

## WRITE_BLOCKED
If any write or tool call is denied, do not retry it in another form. Record `WRITE_BLOCKED: <what> -- <exact denial text>`, put the content in your response, and continue.

## Final response
Start with a 5-line summary, then the full content of your findings file. Mark deficiencies `INCIDENT:` (do not file them). List open questions with a suggested answer each.
