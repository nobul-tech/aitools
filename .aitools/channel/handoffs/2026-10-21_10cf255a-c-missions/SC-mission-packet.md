# Mission packet (Session Commander 10cf255a-c, 2026-10-21)

Every mission commander reads this file in full before other work, and passes
it, unchanged and in full, to every delegate it launches (recursively). It is
the shared part of every mission prompt. The mission-specific part is in the
launch prompt.

## 1. Read before any other work (explicit; do not skip)

Read every file below in full that is not already in your context. Do not
assume you inherited them: what a delegate receives varies by environment and
version. Use the Read tool (offset/limit for files over 2,000 lines).

**User level**
- /Users/new-jose/.claude/CLAUDE.md
- /Users/new-jose/.claude/rules/concurrent-agents.md
- /Users/new-jose/.claude/rules/delegation.md  (D-DEL1..D-DEL4; the delegation duty)

**Project level (aitools)**
- /Users/new-jose/repos/aitools/CLAUDE.md
- /Users/new-jose/repos/aitools/.aitools/channel/CLAUDE.md
- every file in /Users/new-jose/repos/aitools/.claude/rules/ :
  agentic-standards.md, aitool-eval.md, aitool-ops.md, aitools-workspace.md,
  artifact-harvesting.md, config-file-safety.md, cross-platform.md,
  deploy-paths.md, documentation-standards.md, frameworks.md, git-safety.md,
  glossary.md, governed-data-access.md, hook-rollout.md,
  incident-governance.md, interactive-menus.md, managed-file-deployment.md,
  plan-execution.md, relay-outbound.md, script-standards.md,
  smoke-test-pattern.md, sources-of-truth.md, tool-evaluation.md,
  tool-lifecycle.md, tool-ops.md, web-sources.md

**Reference (commanders: read all of them; delegates: the commander names the
subset, which always includes the first five)**
/Users/new-jose/repos/aitools/reference/ :
script-standards-detail.md, cross-platform-detail.md, logging.md,
managed-file-deployment.md, plan-execution-detail.md,
smoke-test-pattern-detail.md, agentic-framework.md, agentic-prompt-patterns.md,
user-repo.md, harness.md, tool-ops-claude-code.md, tool-ops-google-chrome.md,
tool-registry.md, tool-evaluation-criteria.md, tool-evaluation-playbook.md,
pre-commit-checklist.md, pre-push-checklist.md, post-push-checklist.md,
README.md, and every framework-*.md (framework-adoption,
framework-artifact-harvesting, framework-governed-data-access,
framework-governed-vocabulary, framework-hook-rollout,
framework-incident-governance, framework-incident-investigation,
framework-intent-documentation, framework-managed-file-deployment,
framework-provenance, framework-source-of-truth,
framework-three-layer-governance, framework-tool-lifecycle,
framework-tool-ops). Others (ait-shellintegration, claude-code-effectiveness,
cursor-practices, do-what-feels-right, incident-020-process-discipline,
path-targeted-hooks-analysis) when relevant to your mission.

**Session handoff and state**
- /Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_360aa8f3-8.md
  (prior handoff; decisions SD-1..SD-8, exclusions in section F)

## 2. Skills (invoke them; if one will not load, Read its SKILL.md and follow it by hand)

- **/delegate** -- /Users/new-jose/repos/aitools/shared/skills/delegate/SKILL.md.
  Use it before every delegation. It and delegation.md define the seven duty
  elements and the D-DEL4 shipping terms. The duty is recursive: every
  delegate you launch gets the same instructions, including this packet.
- **/scratch** -- /Users/new-jose/repos/aitools/shared/skills/scratch/SKILL.md.
  Every temp script, captured log, commit message and PR body goes in your
  session scratch directory. Delegates get no SessionStart hook, so create it
  yourself with the skill's documented fallback, inside YOUR worktree:
  `mkdir -p <your worktree>/.scratch/session-<NAME>` (gitignored), where
  <NAME> is 10 characters or fewer (e.g. `S3SrcTruth`). A longer name makes
  the session-start catch-up harvest the wrong, live session directory
  (S3-ScratchRule finding S3-SR-8, 2026-10-21). Never create it in the main
  checkout.
  Never inline long commands; write a script there and run it.
  Known: the skill text is partly stale (mission SCRATCH-RULE is fixing it);
  the session-directory and commit-message patterns are correct.
- Mission-specific skills are named in your launch prompt.

## 3. Delegation, recursion, and "ultracode"

- You are a mission commander. Delegate when it helps: parallel research, an
  independent reviewer, a batch of code. Use the Agent tool
  (subagent_type general-purpose). Every delegate prompt carries the seven
  duty elements (/delegate), this packet's path with the instruction to read
  it in full, your mission's carried learning, and its own name prefix.
- You may put the keyword "ultracode" in a prompt you write, for work that
  benefits from orchestration. Be aware: in this environment (Claude Code
  2.1.307, probe 2026-10-21, reference/tool-ops-claude-code.md "Sub-agent
  Nesting Depth") delegates launched with the Agent tool do NOT have the
  Workflow tool, and the third level of delegates has no Agent tool. If a
  Workflow tool appears in your tool list, you may use it; otherwise delegate
  with the Agent tool. You are level 1; your delegates are level 2 and can
  delegate once more; level 3 cannot delegate.
- Name delegates `<your name>-<role>` (e.g. S3-SourceTruth-Plan), prefix
  `<that name>-` on every *.md file they create (D-DEL1). Names never start
  with REPORT, SUMMARY, FINDINGS or ANALYSIS.
- Verify what every delegate returns before relying on it (/delegate
  "Verifying what comes back"): files exist, claims spot-checked, scope kept.

## 4. Shipping (D-DEL4) -- you ship directly

- Work in your own git worktree, never in the main checkout:
  `git -C /Users/new-jose/repos/aitools worktree add -b <branch> /Users/new-jose/repos/aitools/.claude/worktrees/<short-name> origin/main`
  (run `git -C /Users/new-jose/repos/aitools fetch origin` first; origin/main
  is db4b3c5 or later). The main checkout is on a stale branch with the
  commander's own uncommitted CLAUDE.md edit: do not touch it.
- Commit with `git commit -F <scratch>/commit-msg.txt`. Every commit message
  has a short imperative subject and a detailed body: what changed, why, the
  decision or incident it implements (cite IDs), how it was verified, and
  what was not run. End with:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
  Note the tested platform, e.g. `(tested: macOS)`.
- Run the checks that apply: `bash scripts/check-pre-commit.sh` and
  `bash scripts/check-pre-push.sh` from your worktree. Known failures that
  pre-date your branch (record them in the PR, they are not blockers):
  pre-commit step 6 (harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh
  is tracked 100644); pre-push step 7 (dotprofile deploy/ stale on main);
  pre-push step 3 false positives (the `[\s]` secret pattern matches words
  like "tokens:").
- Push: `git push -u origin <branch>`. Open the PR:
  `gh pr create -R nobul-tech/aitools --base main --head <branch> --title "<title>" --body-file <scratch>/pr-body.md`.
  The PR body has these sections: Summary; Why (decisions/incidents);
  Changes (file by file); Verification (exact commands and results);
  Not run (and why); Protected-file drafts awaiting approval; Follow-ups.
  End the body with: `🤖 Generated with [Claude Code](https://claude.com/claude-code)`
- Return the PR URL in your final response.
- Limits: never push to main, never force-push, never merge or approve your
  own PR, never tag. A denied push or PR is WRITE_BLOCKED.
- Protected files (.claude/rules/sources-of-truth.md table; intent statements
  anywhere; .claude/rules/*.md; registries/*.json; the listed reference/*.md;
  plans/*.md; ROADMAP.md; CLAUDE.md) are written ONLY with content the
  commander approved. Content approved so far is listed in section 6.
  Anything else protected ships as a draft inside your mission folder
  (use `dot-claude/`, `dot-cursor/` instead of `.claude/`, `.cursor/` in
  draft paths so Claude Code does not load drafts as live rules or skills).

## 5. Standing orders and operational learning (carried forward; sources in parentheses)

- USO Simple Bash: no `$(...)`, backticks, `&&`, `||`, `;`, multi-line
  commands, or globs in `rm` inside Bash tool calls. Separate calls; scratch
  scripts for anything longer. Pipelines are fine. The standing-order-guard
  hook blocks `cat/head/tail/sed/awk` outside a pipeline (use Read), and a
  `;` inside `pwsh -Command` unless the command starts with the bare word
  `pwsh` (use `pwsh -NoProfile -File <scratch>.ps1`). (hook-rollout.md;
  incident #82; this session)
- USO Dedicated tools for file ops; Perl, not sed/awk, for string work.
- USO No silent failures in reusable code (script-standards.md table).
- Cross-platform: every .sh change has its .ps1 pair; identical menus and
  outcomes; `bash -n` and the pwsh parser on every touched script
  (pwsh is /opt/homebrew/bin/pwsh; parse via a scratch .ps1 file). bash 3.2
  compatibility (/bin/bash on macOS): no `${x,,}`, no empty `"${a[@]}"`
  under `set -u`. (S3-Gate-B probes, PR #58)
- Never run `aitools`, `aitools install`, `setup-user-*`, or
  `scripts/build-deploy.sh` against the real HOME. Test under an isolated
  HOME: `HOME=<worktree>/.scratch/session-<NAME>/home` with a fake config
  and a fake dotprofile when needed. build-deploy rm -rf's the real dotprofile
  deploy/ otherwise (#86). You are NOT harness-worktree-isolated, so HOME
  overrides work for you; a delegate launched with worktree isolation cannot
  set HOME, so do not use isolation for delegates that must. (#83; this session)
- Nobody runs `aitools` on this machine until mission HOOKS-FIX merges: main
  currently deploys a standing-order-guard whose sed check is in observe mode.
- Verify the code, not an issue's state, before working on "open" items
  (issue #32 was already fixed by 7aacdef; #29 may be). (this session)
- registries/incidents.json is ~2,027 lines: read it fully (offset/limit)
  before choosing an id. The /incident skill still points at the dead path
  reference/incidents.json (#84).
- Firecrawl is deprecated (commander, 2026-10-21): do not use Firecrawl tools.
  Use chrome-devtools for web content that feeds protected files
  (web-sources.md), WebFetch for low-stakes reads.
- Session restarts kill running delegates: commit and push early.
- Mission drafts from earlier sessions are read-only provenance:
  /Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_360aa8f3-8-missions/
  and the merged mission folders under
  /Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/
  (S3-Gate, S3-Ledger, S3-Hooks, S3-Path32). Write your outputs under
  `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/<YOUR-NAME>/`
  in your worktree.

## 6. Approved decisions (commander, binding)

- SD-1..SD-8 (prior handoff section D.3). SD-2: one hook version, in
  shared/hooks. SD-5: [r]eplace/[k]eep/[x]abort tool menu.
- D-TS13 approved (2026-10-21): an [x]abort exits 2 AND writes an abort
  marker; runners treat exit 2 as a user abort only when the marker exists.
- Managed-file model approved (2026-10-21), text now on branch
  docs/managed-file-choices (not yet merged; read it at
  /Users/new-jose/repos/aitools/.claude/worktrees/mfchoices/.claude/rules/agentic-standards.md
  section "Managed-file review choices and merge", and the State Machine in
  /Users/new-jose/repos/aitools/.claude/worktrees/mfchoices/reference/managed-file-deployment.md):
  SOURCE is the source of truth; no ancestor, no deploy state; one review
  menu [o]verwrite / [a]ccept & adopt / [m]erge & adopt (AI merge, text only)
  / [s]kip / [x]abort (unchanged, exit 2); adopt and merge are copied to the
  repo immediately by the library; JSON is reviewed field by field, SOURCE
  owns every field; backup, validate, and on failure restore, log, ERROR row,
  continue.
- deploy-harness (mission HARNESS, later): scripts/deploy-harness.sh/.ps1;
  ~/.aitools/{reference,registries,hooks,rules,skills,bin}; summary name
  "harness files"; on a name conflict the first source found wins and each
  skipped duplicate is a log_error + ERROR row; assumptions documented in
  reference/harness.md.
- Firecrawl deprecated.

## 7. WRITE_BLOCKED

If any write or tool call is denied by a permission check or hook, do not
retry it in another form. Record `WRITE_BLOCKED: <what> -- <exact denial
text>`, put the content in your response, and continue.

## 8. Final response shape

Start with a 5-line summary. Then: PR URL(s), branch, files changed,
verification (commands and results), not run, WRITE_BLOCKED lines,
`INCIDENT:` markers (do not file them; the session commander triages),
open questions for the commander (each with a suggested answer), delegates
used. Cite a source for every factual claim (file:line, command output);
say "unknown" rather than guess.
