# S3-FanPlan report: plan for the setup-user-claude `~/.aitools/rules` fan-out

Author: S3-FanPlan (orchestrator, level 1, under Session Commander 10cf255a-c), 2026-10-26. Nothing implemented, committed or pushed.

## Summary (5 lines)

1. The draft plan is ready: `S3-FanPlan-drafts/plans/rules-fanout-claude.md`. It has 4 batches (A lib; B setup-user-claude.sh/.ps1; C build-deploy MDM + tests/claude-mdm + README; D tests/rules-fanout + CI) with verbatim old/new edits, an error-handling audit, and one fresh sub-agent per batch.
2. Survey finding: on main, setup-user-claude deploys only `<dotprofile>/claude/rules`. Nothing runs deploy-harness, and `~/.aitools/rules` does not exist live. So the fan-out depends on #106 (deploy-harness runs first) and #100 (manifest, for retired/adopt) landing first.
3. Merge order: #103 -> #112 -> (#113/#115/#116 any time) -> Batch A PR -> #100 -> #106 -> Batch B+C+D PR. #111 first means C11b instead of C11. #116 before #112 means re-pin D1/D2.
4. Independent review: APPROVE WITH CHANGES. RC-1 and RC-2 were fixed in place (plan section 12). The suite then passed 110/0/1 (bash 5 + pwsh) and 42/0/21 (/bin/bash 3.2) on an isolated-HOME prototype; nobody re-reviewed after the amendments.
5. One commander decision gates Batch B, Q1/R1: fanning out the 26 aitools `.claude/rules` puts about 79 KB (about 20k tokens) of unscoped "(this repo)" rules into every session in every repo, and loads them twice inside aitools. The plan implements the decision as given and costs out a "skip source aitools" variant.

## Paths

- Report: this file. Directory: `/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-FanPlan/` (main checkout, untracked, not committed).
- Draft plan: `S3-FanPlan-drafts/plans/rules-fanout-claude.md`. Its sections: 3 contract, 4 behaviour by case, 5 merge order, 6 batches, 8 risks, 9 open questions, 12 review amendments.
- Draft test (not protected; Batch D copies it verbatim): `S3-FanPlan-drafts/tests/rules-fanout/test-rules-fanout.sh`.
- Survey: `S3-FanPlan-{Claude,Lib,Harness,Install,Checks,Ref,Misc}-findings.md`, plus the shared brief `S3-FanPlan-explorer-brief.md`.
- Planner notes: `S3-FanPlan-Planner-notes.md`. Review: `S3-FanPlan-Review-verdict.md`.

## What the survey found (current behaviour)

**setup-user-claude today**
- Rules come only from `$USER_REPO_PATH/claude/rules/*.md`, between build-deploy markers. The deploy is additive through `deploy_managed_file` / `Deploy-ManagedFile`.
- The adopt target is the dotprofile file. A private commit+push block follows merge & adopt.
- Sources: `scripts/setup-user-claude.sh:288-429`, `.ps1:306-461` (verified by S3-FanPlan with grep). #103 and #112 delete that commit+push block (Claude findings).
- The filter is a `*.md` glob in .sh and `-Filter` in .ps1, so it is case-sensitive in .sh and not in .ps1 (Lib findings, confirmed with a pwsh/bash probe).
- The .ps1 has CRLF line endings.

**deploy-harness**
- It fills `~/.aitools/rules` from `shared/rules`, then `.claude/rules`, then the dotprofile `claude/rules`, and the first source wins (`deploy-harness.sh:260-264`, verified).
- It takes the dotprofile only from config.json `userRepoPath` (`:117-129`, verified). The resolver takes it from `AITOOLS_USER_REPO_PATH` first, so the two can name different dotprofiles (risk R6, Misc R-1).
- #100 adds the manifest `~/.aitools/rules/.aitools-rules-manifest` (`name<TAB>shared|aitools|dotprofile|retired`) and itself removes retired rules from `~/.aitools/rules`.

**Run order**
- On main, no installer or `aitools` path runs deploy-harness (Install and Harness findings).
- With #106 it runs at installer Step 8b and first in `deploy_configs`.
- MDM enforces no order, and the live dotprofile `deploy/` (825aed4) has no `deploy-harness.*` (Claude findings).

**Lib**
- `deploy_tracker_record` has no `removed` outcome and no default branch, so unknown outcomes are dropped without a trace (`aitools-lib.sh:2281-2297`, verified).
- `tty_interactive` tests `[ -t 0 ]` (`aitools-lib.sh:1357-1358`, verified). A here-string-fed loop therefore never prompts, as in `setup-user-cursor.sh:534-582` (verified). The plan uses fd 3 instead.

**Abort (per the Session Commander's 2026-10-26 correction)**
- #106 D3: only deploy-harness's exit 2 ends the run. Every other script, setup-user-claude included, gets `ERROR|<script>|script failed (exit 2)` and the run continues.
- Verified by S3-FanPlan in `gh pr diff 106`. Unchanged context: `aitools-install.sh:234-239`.

**build-deploy**
- The setup-user-claude generator is already a pure extract.
- The MDM rules code to remove: the build-time rules embed and the two "Rules fallback" blocks (`build-deploy.sh:692-702` verified, and `786-797`).
- The four `rules deploy*` markers must stay, and the span between the first two must stay non-empty.

**Checks and CI**
- Pre-commit 13 warns unless build-deploy.sh is staged with setup-user-claude.*. Pre-commit 6 needs mode 100755 on new tests. Pre-commit 20 needs paths that exist.
- Post-push 30 and 31 need the return-value and tracker parity.
- Pre-push 7 dry-runs the generated script with no `~/.aitools/rules`, so the plan's `OK|claude rules|n/a (no harness rules)` keeps it green.
- `check.yml` runs only tests/logging, managed-files and profile, so D1/D2 add the new suite.
- #112's `tests/claude-mdm` expects dotprofile `r1.md` in `~/.claude/rules`; C12 rewrites that check (Checks findings).

**Other scripts and hooks**
- No other setup-user-* script, misc script or shared hook reads or writes any rules directory (Install, Misc and Ref findings).

## Every place that must change (plan section 6)

- **Batch A:** `aitools-lib.sh/.ps1`. Adds the tracker outcome `removed` and a default branch that turns an unknown outcome into `failed`. Adds the helpers `rule_name_kind` / `Get-RuleNameKind`, `read_rules_manifest` / `Read-RulesManifest`, `lower_name` and `in_list`, byte-identical to #110's copies.
- **Batch B:** `setup-user-claude.sh/.ps1`. Sources rules from `~/.aitools/rules`, excludes retired names, filters case-insensitively, maps the adopt target from the manifest (only from a checkout that has `.git`), and runs the loop on fd 3. Retired copies are pruned only after a byte match and a verified backup. Also covers the no-harness and unreadable-manifest cases.
- **Batch C:** `build-deploy.sh` (C1-C11, or C11b), `tests/claude-mdm` (C12), `README.md` MDM run order (C13/C14).
- **Batch D:** `tests/rules-fanout/test-rules-fanout.sh`, plus `check.yml` steps for macOS (bash 5 and 3.2) and Linux.
- **Docs:** protected drafts only (next section).

## Protected-file drafts (text in `S3-FanPlan-drafts/`, old -> new; none written)

- `dot-claude/rules/deploy-paths.md` and `dot-cursor/rules/deploy-paths.mdc.md` (base: #99)
- `dot-claude/rules/managed-file-deployment.md` and the `.mdc` twin (base: #100's draft and #101). These also fix the "Primary (wins)" row.
- `dot-claude/rules/config-file-safety.md`
- `dot-claude/rules/hook-rollout.md` (`hook-lifecycle.md` now reaches `~/.claude/rules`)
- `reference/user-repo.md`, `reference/harness.md` and `reference/managed-file-deployment.md`. harness.md OLD 2 is based on #100's draft text, which is on no branch (review).
- `reference/tool-ops-claude-code.md`, new item #28. UNVERIFIED: the Claude Code memory docs were read with WebFetch and must be re-read with chrome-devtools (web-sources.md).
- The plan file itself (`plans/*.md` is protected).

## Risks (plan section 8)

- **R1:** aitools project rules load in every repo (see summary line 5).
- **R2:** merging B before #106 freezes `~/.claude/rules`. MDM endpoints keep their old embedded rules until the commander rebuilds `deploy/`.
- **R3:** the first run adds about 28 files without review.
- **R4:** one source change goes through two review menus.
- **R5:** the harness copy is stale after an adopt.
- **R6:** dotprofile mismatch (Misc R-1).
- **R7:** a user file with a retired name warns on every run.
- **R8:** the default branch surfaces latent caller bugs.
- **R9/R10:** the upper-case `.MD` case; how Claude Code treats it is unknown.

## Open questions (suggested answers)

- **Q1:** keep fanning out source `aitools` (decided) or take the variant? I suggest showing the commander the 20k-token evidence and recording his answer in the PR (merge gate Q13).
- **Q2:** adopt target? Map it from the manifest.
- **Q3:** no manifest? Fan out everything.
- **Q4:** should a resolver error still stop the rules? Yes.
- **Q5:** where do the helpers live? In the lib.
- **Q6:** should deploy-harness use the resolver? Yes, as follow-up F3.
- **Q7:** `removed` (and `retired`) as glossary terms? Yes, through `/glossary`.
- **Q8:** refresh the harness copy after an adopt? Yes, as a follow-up helper.
- **Q9 (#106 Q2):** should every script's exit 2 end the run? A follow-up, plus a WARN `aborted` row.
- **Q10:** keep the warning on a kept retired-name file? Yes, for now.
- **Q11:** warn on `.MD`? No.
- **Q12:** keep skipping hidden files? Yes.
- **Q13:** the commander's Q1 answer goes in the B+C+D PR body.
- **Coordination:** files are shared with mission BUILD-PKG (BP-6, BP-10, and lib/setup-user-*), so agree who owns what. Also, `scripts/build-package.sh` and `tests/build-package/test-cli.sh` are modified in the main checkout. That change is not from any S3-FanPlan delegate (`git status`).

## INCIDENT markers (not filed)

**Code and tests**
- The deploy tracker drops unknown outcomes without a trace and has no `removed` (Lib, Harness).
- The rules filter has case parity defects, but in deploy-harness `add_source` (sh vs ps1) and in setup-user-claude, not where the brief said. The Cursor fan-out is case-sensitive in both languages (Harness, Lib).
- The bash Cursor fan-out never prompts, because of the here-string loop; high (Lib; S3-FanPlan verified the mechanism).
- `check-post-push.sh:204` and pre-commit 3 `--fix` run build-deploy against the real dotprofile `deploy/` without checking the exit code; high (Checks I-1; line 204 verified).
- `tests/rules-fanout-cursor`, `tests/deploy-harness` and `tests/deploy-harness-mdm` are not in CI (Checks I-2).
- Pre-push 7's trigger misses deploy-harness and the embedded sources (Checks I-4).
- The live dotprofile `deploy/` is stale and has no `deploy-harness.*` (Claude).

**Docs and spec**
- `reference/harness.md:153-155` describes a fan-out that does not exist (Harness).
- deploy-paths.md/.mdc still call setup-user-claude "duplicated"; the .mdc twins have drifted (Claude, Checks).
- managed-file-deployment.md's "dotprofile Primary (wins)" row contradicts first-source-wins (Review).
- The `ADOPT_TRANSFORM` signature in the spec does not match the code's `ADOPT_FILTER` (Lib).
- tool-ops-claude-code.md is missing the facts on how user rules load, and its "2.1.81" is stale (Ref).
- No spec covers project-scoped "(this repo)" rules reaching user scope (Ref, high if shipped as is).
- user-repo.md "Scope guidance" contradicts D5 (Planner).
- `reference/tool-support-decision-tree.md:65, 472-483, 707-714` abort text. Now moot or under S3-AbortDocs after the correction: verify against #106.

**Outside the fan-out scope** (Install and Misc findings)
- setup-user-hooks writes `settings.json` without a backup.
- setup-user-shell ignores dry-run.
- `aitools-dashboard.ps1:379` assigns to `$pid`.
- The `AITOOLS_DEPLOY_IN_PROGRESS` guard is inactive.
- setup-cursor-ide-mcp sh/ps1 diverge.
- setup-skills has the same case-parity issue.
- TODO(glossary): "fan-out", "harness files", "removed", "retired".

## Delegates and how I verified them

- **Seven explorers:** S3-FanPlan-Claude, -Lib, -Harness, -Install, -Checks, -Ref and -Misc. Each read one slice: every file in reference/, scripts/, `.claude/rules`, `.cursor/rules`, shared/rules, shared/hooks, tests/ and CI.
  - Ref and Install first reported partial reads. I sent both back; each finished its full reads and added section 9.
  - Checks, Claude and Lib read their slices in full, but not every packet reference file. Each disclosed that.
- **My spot-checks against the code:** each claim below matched the code.
  - `deploy-harness.sh:117-129` and `:260-264`
  - `aitools-install.sh:234-239`
  - `check-post-push.sh:204`
  - `build-deploy.sh:686-705`
  - `aitools-lib.sh:2281-2297` and `:1357-1361`
  - `setup-user-cursor.sh:530-582`
  - `setup-user-claude` rules spans (grep)
  - #106's abort wiring (`gh pr diff 106`)
- **Planner:** S3-FanPlan-Planner. I read the plan's intent, summary, decisions, contract, behaviour and merge-order sections and confirmed sections 8-12 are present.
  - It prototyped the edits on scratch exports and a detached scratch worktree, under isolated HOMEs only.
  - That worktree is still registered: `.claude/worktrees/fanplan/.scratch/session-plan/wt112main`, detached, never pushed. Remove it with `git -C /Users/new-jose/repos/aitools worktree remove --force <path>` when no longer needed.
- **Independent reviewer:** S3-FanPlan-Review. It got the plan, the drafts and the code, and not the explorers' or the planner's notes.
  - Verdict APPROVE WITH CHANGES. All 29 old_strings occur exactly once on their named bases (10 PR heads and pairwise merges), and the suites pass on an edited export.
  - **RC-1** (Backup-File wildcard): main already has the `-LiteralPath` fix (`aitools-lib.ps1:781-793`). #112's branch lacks 9923a3c (`git merge-base --is-ancestor` exit 1), which explains the reviewer's probe. The plan now requires 9923a3c in B's base, adds a guarded remove, and adds a test.
  - **RC-2** (ERROR then OK row): fixed with the MANIFEST_FAILED flag, plus a test.
  - **RC-3:** became merge gate Q13.
  - The amendments were made by the planner and have not been re-reviewed independently. That is one review, not two.

## Not run

- No code changes, branches, PRs or commits by S3-FanPlan.
- Nothing ran against the real HOME.
- Not run: check-pre-commit, check-pre-push, check-post-push, CI, Windows or Linux runs, a real MDM endpoint, and the chrome-devtools read of the Claude Code docs.

WRITE_BLOCKED: none, from S3-FanPlan or any delegate.
