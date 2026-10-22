# Mission packet (Session Commander 10cf255a-c, 2026-10-21, rev 2)

Every mission commander reads this file in full before other work, and passes
it, unchanged and in full, to every delegate it launches (recursively). It is
the shared part of every mission prompt. The mission-specific part is in the
launch prompt.

## 1. Read before any other work (explicit; do not skip)

Read every file below in full that is not already in your context. Do not
assume you inherited them. Use the Read tool (offset/limit over 2,000 lines).

**User level**
- /Users/new-jose/.claude/CLAUDE.md
- /Users/new-jose/.claude/rules/concurrent-agents.md
- /Users/new-jose/.claude/rules/delegation.md  (D-DEL1..D-DEL4)

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

**Reference** (commanders: all of /Users/new-jose/repos/aitools/reference/*.md;
delegates: the subset the commander names, always including
script-standards-detail.md, cross-platform-detail.md, logging.md,
managed-file-deployment.md, plan-execution-detail.md)

**Decisions and state**
- /Users/new-jose/repos/aitools/plans/tool-support-and-machine-profile.md
  (all gate decisions, 95 items, with chat overrides) -- binding
- /Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_360aa8f3-8.md
  (prior handoff; SD-1..SD-8, exclusions in section F)

## 2. Skills (invoke; if one will not load, Read its SKILL.md and follow it by hand)

- **/delegate** -- shared/skills/delegate/SKILL.md, before every delegation.
  The duty is recursive: every delegate gets the same instructions,
  including this packet's path.
- **/scratch** -- shared/skills/scratch/SKILL.md. Every temp script, log,
  commit message and PR body goes in a session scratch directory. Delegates
  get no SessionStart hook: create `<your worktree>/.scratch/session-<NAME>`
  where <NAME> is 10 characters or fewer, never in the main checkout (a
  longer name makes the harvester hit a live session, S3-SR-8). Hand-backs
  live in tracked paths, never in scratch.
- Mission-specific skills are named in the launch prompt.

## 3. Delegation, recursion, "ultracode"

- Delegate with the Agent tool (general-purpose) when it helps. Every prompt
  carries the seven duty elements, this packet's path, your carried
  learning, and its own name prefix.
- "ultracode" only helps if your tool list has the Workflow tool; delegates
  launched with the Agent tool do not have it here (Claude Code 2.1.307), and
  level-3 delegates have no Agent tool. You are level 1.
- Name delegates `<your name>-<role>`, prefix `<that name>-` on every *.md
  they create (D-DEL1); never starting REPORT/SUMMARY/FINDINGS/ANALYSIS.
- Verify what every delegate returns before relying on it. An independent
  reviewer posts its verdict on the PR (`gh pr review`).

## 4. Shipping (D-DEL4) -- you ship directly

- Your own git worktree, never the main checkout:
  `git -C /Users/new-jose/repos/aitools fetch origin`, then
  `git -C /Users/new-jose/repos/aitools worktree add -b <branch> /Users/new-jose/repos/aitools/.claude/worktrees/<short-name> origin/main`.
  The main checkout stays on main: never switch its branch.
- Commit with `git commit -F <scratch>/commit-msg.txt`: imperative subject;
  body says what changed, why (decision/incident IDs), verification, what was
  not run; tested platform; end with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Run `bash scripts/check-pre-commit.sh` and `bash scripts/check-pre-push.sh`
  from your worktree. Known pre-existing failures (record, not blockers):
  pre-commit step 6 (harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh
  is 100644); pre-push step 7 (dotprofile deploy/ stale); pre-push step 3
  `[\s]` false positives.
- `git push -u origin <branch>`; `gh pr create -R nobul-tech/aitools --base main
  --head <branch> --title "..." --body-file <scratch>/pr-body.md`. Body
  sections: Summary; Why; Changes; Verification; Not run; Protected-file
  drafts awaiting approval; Follow-ups. End with
  `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- Commit and push after every batch (usage limits stop missions mid-work).
- Never push to main, force-push, merge or approve your own PR, or tag.
  Exception: dotprofile (aitools-nobul-jose) changes are committed and pushed
  to its main directly, as decided (N-Q2).
- Protected files are written only with content the commander approved
  (section 6 and your launch prompt); anything else ships as a draft in your
  mission folder (`dot-claude/`, `dot-cursor/` in draft paths).

## 5. Standing orders and operational learning

- USO Simple Bash: no `$(...)`, backticks, `&&`, `||`, `;`, multi-line
  commands, or globs in `rm`. Separate calls; scratch scripts for anything
  longer. standing-order-guard blocks cat/head/tail/sed/awk outside a
  pipeline (use Read) and `;` inside `pwsh -Command` (use `pwsh -File`).
- Dedicated tools for file ops; Perl, not sed/awk; no silent failures in
  reusable code (script-standards.md).
- Cross-platform pairs (.sh/.ps1), identical menus and outcomes; `bash -n`
  and the pwsh parser on every touched script; bash 3.2 compatible.
- Never run `aitools`, `aitools install`, `setup-user-*`, or
  `scripts/build-deploy.sh` against the real HOME; isolated HOME under your
  worktree scratch (#86). Harness worktree isolation blocks HOME overrides,
  so do not launch delegates with isolation when they need one.
- Verify the code, not an issue's state, before working on "open" items.
- registries/incidents.json is long: read it fully before choosing an id
  (next id is #146 on main after PR #65).
- Removing a git worktree deletes its ignored files: never remove another
  agent's worktree.
- Firecrawl is deprecated: do not use Firecrawl tools; chrome-devtools for
  web content that feeds protected files.
- Write outputs under `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/<YOUR-NAME>/`
  in your worktree.

## 6. Approved decisions (binding)

- SD-1..SD-8 (prior handoff D.3), SD-8 extended to 7 user-level skills.
- D-TS13 REVERSED: bare exit 2 = user abort; NO abort-marker file.
- Managed-file model (.claude/rules/agentic-standards.md once mission
  APPLY-DRAFTS lands; until then the drafts named in its prompt): SOURCE is
  the source of truth; no ancestor, no deploy state; one review menu
  [o]verwrite / [a]ccept & adopt / [m]erge & adopt (AI, text only) /
  [s]kip / [x]abort (exit 2); adopt and merge copy to the repo immediately;
  JSON reviewed field by field, SOURCE owns every field; backup, validate,
  restore on failure, ERROR row, continue.
- Registries stay in registries/; deploy-harness copies them to
  ~/.aitools/registries/. tool-versions.json deleted; tool-registry.md
  deprecated (use the /tool-registry skill).
- Dotprofile writes auto-commit and push (N-Q2).
- Profile resolver: native scripts/aitools-profile.sh/.ps1; raw machine ids;
  one scutil command (LocalHostName).
- deploy-harness: scripts/deploy-harness.sh/.ps1;
  ~/.aitools/{reference,registries,hooks,rules,skills,bin}; summary name
  "harness files"; conflicts: first source wins, each skipped duplicate
  log_error + ERROR row; shared/rules reach tools through
  setup-user-claude/setup-user-cursor fan-out.
- File ownership across parallel missions is stated in each launch prompt:
  never edit a file another running mission owns; rebase on origin/main after
  its PR merges before touching it.

## 7. WRITE_BLOCKED

If any write or tool call is denied, do not retry it in another form. Record
`WRITE_BLOCKED: <what> -- <exact denial text>`, put the content in your
response, and continue.

## 8. Final response shape

5-line summary; PR URL(s); branch; files changed; verification (commands,
results); not run; WRITE_BLOCKED lines; `INCIDENT:` markers (not filed);
open questions with suggested answers; delegates used. Cite sources; say
"unknown" rather than guess.
