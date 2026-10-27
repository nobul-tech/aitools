# S3-Reconcile-Fix sub-delegate brief (2026-10-26)

Shared part of the three S3-Reconcile-Fix sub-delegate prompts (level 3, no
Agent tool). Read it in full, then the files it names.

## Who delegates to you
S3-Reconcile-Fix (level 2), delegated by S3-Reconcile (level 1) for Session
Commander 10cf255a-c; commander Jose. Mission: turn every in-scope INCIDENT
marker into an executable FIX item. You verify one area's markers against the
CURRENT origin/main and draft the fixes. You are READ-ONLY on the repo: you
write only your items file and your drafts folder (paths in your prompt).

## Rules (read before other work)
1. `/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Reconcile/S3-Reconcile-delegate-common.md`
   (the common brief) in full, and the mission packet
   `/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/SC-mission-packet.md`
   in full, plus every file in the packet's section 1 not already in your
   context: /Users/new-jose/.claude/CLAUDE.md,
   /Users/new-jose/.claude/rules/concurrent-agents.md,
   /Users/new-jose/.claude/rules/delegation.md,
   /Users/new-jose/repos/aitools/CLAUDE.md,
   /Users/new-jose/repos/aitools/.aitools/channel/CLAUDE.md, and every
   /Users/new-jose/repos/aitools/.claude/rules/*.md (agentic-standards,
   aitool-eval, aitool-ops, aitools-workspace, artifact-harvesting,
   config-file-safety, cross-platform, deploy-paths, documentation-standards,
   frameworks, git-safety, glossary, governed-data-access, hook-rollout,
   incident-governance, interactive-menus, managed-file-deployment,
   plan-execution, relay-outbound, script-standards, smoke-test-pattern,
   sources-of-truth, tool-evaluation, tool-lifecycle, tool-ops, web-sources).
2. Reference: /Users/new-jose/repos/aitools/reference/plan-execution-detail.md
   ("Error-handling rules (non-negotiable)": every code draft must pass it),
   reference/script-standards-detail.md, reference/cross-platform-detail.md,
   reference/logging.md, reference/managed-file-deployment.md.
3. Critical rules restated:
   - Read-only on the repo. No checkout/switch/add/commit/push; never remove a worktree.
   - Never run aitools, setup-user-*, deploy-harness, build-deploy.sh,
     check-pre-push.sh or check-post-push.sh against the real HOME. Tests only
     under an isolated HOME in a `mktemp -d` dir (outside the repo).
   - Simple Bash: no `&&` `||` `;` `$(...)` backticks or multi-line commands;
     cat/head/tail/awk outside a pipeline are blocked (use Read, or
     `git show origin/main:<path>` piped to `grep -n`); longer logic goes in a
     scratch script, then run it.
   - Do NOT export a full repo tree under the repo's `.scratch/` (Claude Code
     loads its CLAUDE.md; the harvester sees ~1000 files). Read code with
     `git -C /Users/new-jose/repos/aitools show origin/main:<path>`; to test,
     export only the needed files into a `mktemp -d` dir.
   - .sh/.ps1 parity, bash 3.2, `.ps1` files are CRLF. Every drafted code fix
     passes the error-handling rules; cite file:line on a named ref; "unknown"
     over guessing.
   - Protected files (sources-of-truth.md table, any intent statement): you
     draft text only; say "protected" on the item.

## Commander decisions (relayed 2026-10-26; facts, binding)
1. FAN-PLAN Q1/Q13: ALL project-scope rules and skills deploy to user-scope
   Claude Code (aitools' 26 rules and skills included). Do not plan the
   "skip aitools source" variant.
2. FAN-PLAN's plan is on main: `plans/rules-fanout-claude.md` (3a5f260), v1.0;
   its other questions take the report's suggested answers. Batches: A (lib:
   tracker `removed` + unknown-outcome default branch + `rule_name_kind`,
   `read_rules_manifest`, `lower_name`, `in_list`), B (setup-user-claude
   fan-out, fd 3 loop, case-insensitive filter), C (build-deploy MDM + tests/claude-mdm
   + README MDM run order), D (tests/rules-fanout + CI). Follow-ups NOT in its
   batches: F1 setup-user-cursor case filter + drop helper copies, F2
   deploy-harness add_source case parity, F3 deploy-harness via resolver, F4
   Windows CI, F5 adopt refresh / abort semantics, F6 un-CI'd suites
   (tests/rules-fanout-cursor, tests/deploy-harness, tests/deploy-harness-mdm).
   A follow-up is NOT "covered": make it an FX item and cite the F number.
3. Incidents are NOT filed. Every in-scope marker becomes a FIX item (code or
   docs). Exception: closing already-filed incidents that are fixed, and PR
   #102's approved batch #146-#170 (MERGE-ALL applies it).
4. The spec for aitools project rules reaching user scope is being written as
   `reference/rules.md` by the Session Commander's delegate: reference it, do
   not write it.
5. MERGE-ALL is merging every open PR now (merge commits, CI-gated). `git -C
   /Users/new-jose/repos/aitools fetch origin` first and again before you
   finish; for every item say whether a merged PR already fixed it (cite the
   commit), and whether an OPEN PR fixes it (`gh pr diff <n> -R
   nobul-tech/aitools`, or `git show origin/<branch>:<path>`). Open PRs and
   branches: #97 docs/m3-lead-plan, #98 feature/mf-config-no-machine, #100
   feature/harness-rules-manifest, #102 docs/mf-incidents, #103
   fix/mf-dotprofile-adopt-push, #104 docs/mf-audit, #106
   feature/harness-hookin, #108 fix/mf-audit-profile-json, #109
   fix/mf-audit-consumers, #110 feature/harness-cursor-user-rules, #111
   feature/harness-mdm-followups, #112 fix/mf-audit-claude-build, #113
   fix/mf-lib-runner-result, #114 fix/mf-audit-config, #115 fix/mf-lib-relay,
   #116 fix/mf-installer-relay (re-check with `gh pr list -R nobul-tech/aitools --state all --limit 25`).

## What is already covered (do not redo; name the batch)
The plan `/Users/new-jose/repos/aitools/plans/fan-plan-reconciliation.md`
v1.1 batches R1-R14 (read sections 4-6 and 8). In short: R1 decision 2
recorded; R2/R2c/R3 fan-out claims in managed-file-deployment.md/.mdc,
harness.md, aitools-workspace.md (rules/ and deploy-state rows, channel
pointer), reference/managed-file-deployment.md (incl. "first profile"),
hook-rollout.md/.mdc, scratch SKILL.md; R4 deploy-paths.md/.mdc (MDM drafts,
.claude/hooks, step-7 text, .mdc D-12/D-13); R5 user-repo.md AnsB edits +
glossary "profile"; R6 user-rules.md repos path + clipboard line; R7 parity
mandate (cursor-rule-parity.mdc, cursor-practices.md, documentation-standards.mdc,
config-file-safety.mdc); R8a menu "stop the run"; R8b #106 PS1 "harness
files" duplicate row; R8c exit-2 WARN `aborted by user` (Q6); R8d relay
intent; R9 `--alias` claim confirm; R10 aiToolingRepoPath into
setup-user-config; R11 pre-push step 7 WARN on input-changing pushes; R12a
agentic-framework.md deploy-state section, logging.md deploy-state,
pre-commit-checklist.md steps 3/10; R12b git-safety.md/.mdc "deploy/ is
frozen" + CLAUDE.md deploy/ line; R12c tool-lifecycle "deploy list" bullet,
README step counts + githook sentence, ROADMAP row; R12d sources-of-truth.mdc;
R13 ledger; R14 FAN-PLAN doc hand-off. Plan Q11 (pre-commit --fix staging
frozen deploy/) and Q12 (deploy-harness adopts not committed, N-Q2) are
handled by S3-Reconcile-Fix itself / the FX list: do not redo Q11.

## Output format
Items file (`<your prefix>items.md`), one block per marker you were given:

```
### <ledger id or source tag>: <one-line deficiency>
- Source marker(s): <file:line> (verbatim quote, short)
- Status on origin/main <short sha>: OPEN | FIXED (<commit/PR>) | COVERED (<R-batch / FAN-PLAN batch>) | FIXED ON OPEN PR #N (<branch:file:line>) | NOT A DEFICIENCY (<why>) | UNVERIFIABLE (<why>)
- Evidence: <file:line, function> on origin/main
- Severity: high | medium | low (incident-governance table)
- Fix: <direction>; then either a draft id in your drafts file (`@@@FILE` block title) or a precise spec (function, behaviour, rows/outcomes, the test that proves it)
- Files: <list> (code|docs; protected yes/no)
- Gate: none | PR #N merged | R-batch merged | FAN-PLAN batch merged
- Verification: <bash -n / pwsh parser / named test / grep with expected count>
- Decision needed: none | <question> -- suggested: <answer>
```

Code/doc drafts: `@@@FILE <repo-relative path> <title>` / `@@@OLD` / `@@@NEW`
/ `@@@END` blocks (format and applier:
`/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Reconcile/S3-Reconcile-Code-drafts/apply.pl`;
paths are repo-relative, e.g. `scripts/aitools-lib.sh`). Each OLD must occur
exactly once on origin/main: prove it by applying your drafts with
`perl apply.pl <edits> <export-dir> <out-dir>` to a `git archive` export of
only the touched files in a `mktemp -d` dir, then `bash -n` / pwsh parser on
the outputs. Draft verbatim OLD/NEW only when the fix is clear and under ~30
lines; otherwise a precise spec. Report the apply results.

End the items file with: "Not verified" list; `INCIDENT:` lines for new
deficiencies you find (they become FX items upstream); open questions with a
suggested answer each.

## Scratch
`/Users/new-jose/repos/aitools/.scratch/session-<your scratch name>/` (name
given in your prompt). Tests in `mktemp -d` dirs. Hand-back content goes in
your items file (tracked path), never only in scratch.

## WRITE_BLOCKED
If a write or tool call is denied, do not retry it in another form. Record
`WRITE_BLOCKED: <what> -- <exact denial text>`, put the content in your
response, and continue.

## Final response
Start with a 5-line summary, then the full items file content.
