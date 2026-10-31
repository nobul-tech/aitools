# S3-FanPlan explorer brief (shared by every S3-FanPlan explorer)

Written by S3-FanPlan (orchestrator, level 1, delegated by Session Commander
10cf255a-c), 2026-10-26. Read this in full after the mission packet. Your
launch prompt names your slice; this file carries everything shared.

## Mission context

Mission FAN-PLAN plans (does NOT implement) the refactor of
`scripts/setup-user-claude.sh/.ps1` so Claude Code gets its user-level rules
from the `~/.aitools/rules` fan-out, with the build-deploy MDM counterpart
and tests. You are an explorer: you read your slice in full and write a
findings file that the planner delegate will use to write verbatim
old/new edits. You change no code, open no PR, write no protected file.

## Rules (read before other work)

1. The mission packet, in full, and every file in its section 1:
   `/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/SC-mission-packet.md`
   Pass this path, unchanged, to any delegate you launch (you should not need to).
   For the packet's "Reference" subset you must read:
   reference/script-standards-detail.md, cross-platform-detail.md, logging.md,
   managed-file-deployment.md, plan-execution-detail.md (under
   /Users/new-jose/repos/aitools/.claude/worktrees/fanplan/reference/).
   For `plans/tool-support-and-machine-profile.md` and the prior handoff
   `.aitools/channel/handoffs/2026-10-21_360aa8f3-8.md`: read them in full
   (main checkout paths under /Users/new-jose/repos/aitools/).
2. Project rules: /Users/new-jose/repos/aitools/CLAUDE.md and every file in
   /Users/new-jose/repos/aitools/.claude/rules/ (agentic-standards.md,
   aitool-eval.md, aitool-ops.md, aitools-workspace.md, artifact-harvesting.md,
   config-file-safety.md, cross-platform.md, deploy-paths.md,
   documentation-standards.md, frameworks.md, git-safety.md, glossary.md,
   governed-data-access.md, hook-rollout.md, incident-governance.md,
   interactive-menus.md, managed-file-deployment.md, plan-execution.md,
   relay-outbound.md, script-standards.md, smoke-test-pattern.md,
   sources-of-truth.md, tool-evaluation.md, tool-lifecycle.md, tool-ops.md,
   web-sources.md). The main checkout may be behind origin/main: read the
   worktree copies under /Users/new-jose/repos/aitools/.claude/worktrees/fanplan/.claude/rules/
   when they differ, and say which you used.
3. User rules: /Users/new-jose/.claude/CLAUDE.md,
   /Users/new-jose/.claude/rules/concurrent-agents.md,
   /Users/new-jose/.claude/rules/delegation.md.

Critical rules restated:
- Read only. Do not edit any repo file, switch any branch, or remove any
  worktree. Never run `aitools`, `aitools install`, `setup-user-*`,
  `deploy-harness` or `scripts/build-deploy.sh` at all (you do not need to;
  if you must probe behaviour, do it only under an isolated HOME inside your
  scratch dir, and say so).
- Simple Bash only: no `$(...)`, backticks, `&&`, `||`, `;`, multi-line
  commands, globs in `rm`. cat/head/tail/sed/awk outside a pipeline are
  blocked: use Read (offset/limit for long files). grep in a pipeline or
  plain `grep -n` is fine.
- Read every file in your slice IN FULL (Read with offset/limit, 2,000
  lines per call). Say in your findings which files you read fully, with
  line counts.

## Skills

Invoke `/scratch` (scratch rules) and `/tool-ops` (Claude Code behaviour)
if relevant to your slice. If a skill will not load, read its SKILL.md at
/Users/new-jose/repos/aitools/.claude/worktrees/fanplan/shared/skills/<name>/SKILL.md
or /Users/new-jose/repos/aitools/.claude/worktrees/fanplan/.claude/skills/<name>/SKILL.md
and follow it by hand.

## Operational learning (carry forward)

- Approved behaviour for the fan-out (HARNESS-2 hand-back; commander answers
  2026-10-22): setup-user-claude fans out everything in `~/.aitools/rules`
  into `~/.claude/rules`, minus `retired`, case-insensitive, `*.md` only,
  skipping `*.bak.*`; it stops deploying dotprofile rules directly; it needs
  a build-deploy MDM counterpart and a regression test in
  `tests/rules-fanout/`. "Put aitools rules in the user space of claude
  code"; Cursor gets user level only. deploy-harness: first source wins on
  conflict, each skipped duplicate log_error + ERROR row; summary name
  "harness files". (Source: launch prompt from Session Commander 10cf255a-c;
  HARNESS-2 hand-back.) "minus `retired`" = the rules that the rules
  manifest (PR #100) marks retired; confirm what #100 actually implements.
- Commander decision 2026-10-26: an `[x]abort` (exit 2) ends only that setup
  script; the installer continues with the next script
  (interactive-menus.md). PR #106 currently ends the whole run; treat it as
  under change.
- Known defects: the rules filter is case-sensitive in .sh vs
  case-insensitive in .ps1; the deploy tracker has no `removed` outcome;
  the Backup-File literal-path bug is fixed on main (9923a3c).
- Open PRs touching the same files (read with `gh pr view <n> -R
  nobul-tech/aitools` and `gh pr diff <n> -R nobul-tech/aitools`):
  #103 and #112 (setup-user-claude.*, build-deploy.sh), #100 (deploy-harness
  manifest), #110 (Cursor fan-out), #111 (MDM payload data file,
  build-deploy.sh), #106/#116 (installers), #113/#115 (lib runner/relay).
  Other open PRs: #97-#99, #101, #102, #104, #105, #108, #109, #114.
- Live state observed by S3-FanPlan 2026-10-26: `/Users/new-jose/.aitools/rules`
  does NOT exist (deploy-harness has never run live). `~/.claude/rules/`
  holds concurrent-agents.md, delegation.md, delegation.md.bak.2026-10-22T045154Z.
  Dotprofile `claude/rules/` holds concurrent-agents.md and delegation.md.
- `.ps1` files may check out with CRLF: line-anchored grep patterns miss.
- deploy-harness section headings are cut points for build-deploy's MDM
  generator: rewording one breaks the build (S3-H-MDM hand-back).
- Delegates sometimes lack Grep/Glob: use Bash grep/find in pipelines.
- Verify the code, not an issue or PR title, before stating behaviour.

## Access (all absolute)

- Reading copy (origin/main 480b901): /Users/new-jose/repos/aitools/.claude/worktrees/fanplan/ (read only)
- Main checkout: /Users/new-jose/repos/aitools (read only, except your output file below)
- Dotprofile (read only): /Users/new-jose/repos/aitools-nobul-jose (claude/rules/, claude/CLAUDE.md, profile.json, deploy/)
- Live user dirs (read only): /Users/new-jose/.claude/rules/, /Users/new-jose/.aitools/
- Prior mission hand-backs (read only, for context): /Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/ (S3-Harness/, S3-H-Core/, S3-H-Cursor/, S3-H-MDM/ etc.)
- Your scratch: /Users/new-jose/repos/aitools/.claude/worktrees/fanplan/.scratch/session-<yourdir>/ (dir name <=10 chars, given in your prompt)
- Your output dir (writable): /Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-FanPlan/

## Name prefix (D-DEL1)

Every *.md you create starts with `S3-FanPlan-<Role>-` (your role is in your
launch prompt), e.g. `S3-FanPlan-Lib-findings.md`.

## WRITE_BLOCKED

If any write or tool call is denied, do not retry it in another form.
Record `WRITE_BLOCKED: <what> -- <exact denial text>`, put the content in
your response, and continue.

## Findings file shape

`S3-FanPlan-<Role>-findings.md` in the output dir:
1. 5-line summary.
2. Files read in full (path, lines).
3. Current behaviour relevant to the rules fan-out / setup-user-claude /
   deploy-harness / MDM, with `file:line` and function names. Quote the
   exact code blocks (verbatim, with line numbers) that the refactor would
   change or must stay consistent with: the planner needs exact old_string
   text.
4. Every place in your slice that must change (or be checked) for the
   refactor, and why.
5. Interactions with the open PRs in your slice (which hunks overlap).
6. Error-handling / parity / script-standards issues spotted in the code
   that the refactor would touch.
7. Risks, unknowns ("unknown" rather than guess), open questions with
   suggested answers.
8. `INCIDENT:` markers for deficiencies found (not filed).

Cite file:line, command output, or URL for every factual claim. Your final
response: the 5-line summary plus the findings path.
