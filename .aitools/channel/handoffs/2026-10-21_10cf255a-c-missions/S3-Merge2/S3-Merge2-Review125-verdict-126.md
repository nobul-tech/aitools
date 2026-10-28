VERDICT: BLOCKING

# S3-Merge2-Review125: pre-merge review of PR #126 (FO-7 docs), v1.0

Independent pre-merge review by S3-Merge2-Review125 (delegated by S3-Merge2, mission MERGE-2, Session Commander 10cf255a-c), on the commander's 2026-10-28 order: "launch a mission to serve as an orchestrator and merge open prs in the correct order. learn from past mistakess. give it explicit instructions to fix issues when they arise. do this now. have the orchestrator launch a review first."

- **Head reviewed:** `725b03a647ada3a0eb613357d80df17c6ca54b11` (`feature/fanout-docs`)
- **Against:** `origin/main` `86a0ea88faec50e13b9d49067f3894bb4c771bea` (2026-10-28), and the open train heads #122 d3e0249, #120 1d37d93, #117 dbe8f46, #118 d29dc5f, #119 fd660a9, #121 4339c08, #124 282c28b, #123 096a8bf, #125 7754c15
- **GitHub:** `mergeStateStatus` DIRTY / CONFLICTING. CI on 725b03a: all green (macos, linux, windows, CodeQL).
- **Blocking findings:** 4 (B1-B4). Non-blocking: 5.

The earlier verdict (S3-FanoutImpl-Review126, issuecomment-6434702662) was correct for main at 672c1f9, and its findings were fixed in 6cfe41b. Since then main gained #128 (seven governance skills moved to `shared/skills`), #129 (the `/aitool-ops` and `/aitool-eval` cards and their rules deleted), #131 and #132 (the v0.74.0 docs scrub). Main has moved under this PR's docs. On current main, 21 files conflict, and several statements the PR adds are now false. The fix is a re-anchor round on main plus the train, not a rewrite.

## Blocking

**B1. 21 files conflict with origin/main, three of them modify/delete.**
- Trial merge: `git merge --no-ff --no-commit origin/main` on 725b03a.
- Conflicted files:
  - **modify/delete** (main deleted these in #129, this PR edits them): `.claude/rules/aitool-eval.md`, `.claude/rules/aitool-ops.md`, `shared/skills/aitool-ops/SKILL.md`.
  - **content**, with hunk counts:
    - rules: `.claude/rules/aitools-workspace.md` (1), `deploy-paths.md` (1), `documentation-standards.md` (1), `hook-rollout.md` (1), `managed-file-deployment.md` (1)
    - Cursor twins: `.cursor/rules/deploy-paths.mdc` (1), `hook-rollout.mdc` (1), `managed-file-deployment.mdc` (2)
    - `.github/workflows/check.yml` (4), `README.md` (2)
    - references: `reference/cursor-practices.md` (2), `framework-governed-vocabulary.md` (1), `harness.md` (1), `managed-file-deployment.md` (7), `rules.md` (3), `script-standards-detail.md` (2), `user-repo.md` (3)
    - `shared/skills/scratch/SKILL.md` (1)
- How to resolve: see "Expected conflicts" below.
- **The hazard:** taking this PR's side wholesale would silently drop facts the #132 scrub added to main. Examples:
  - the `dotprofile_commit_push` result table in `reference/managed-file-deployment.md`;
  - the `Claude settings` content-source row;
  - the `claude settings` / `claude template` tool names and the `aitools-profile` logging override in `reference/script-standards-detail.md`;
  - the `rules/` row and the SD-2 `hooks/` comment in `reference/user-repo.md`;
  - the fuller MDM script list in `README.md`;
  - `--skip-config` and "Dotprofile resolution" in `reference/managed-file-deployment.md`.

**B2. After the merge, pre-commit step 20 (path references) fails: 7 dead references in `reference/skills.md`.**
- Evidence: I resolved the trial merge naively (this PR's side for content conflicts, main's deletion for modify/delete; index only, not committed) and ran `python3 scripts/check-path-refs.py --root <worktree>`.
- Result: `dead path references: 7`, exit 1. The dead references:
  - `reference/skills.md:170` and `:174`: `.claude/rules/aitool-ops.md`, `.claude/rules/aitool-eval.md`
  - `:469`, `:470`: the same two files
  - `:506`: the same two files
- Fix: drop the reference-card paragraph (skills.md section 4, lines 169-175) and the cross-reference at :506. At :469-470, cite #129 (cards retired; `/tool-ops`, `/tool-eval` now in `shared/skills`) instead of the deleted rules.

**B3. `reference/skills.md` describes the skill inventory from before #128 and #129. On main it is false.**
Main has 20 skills in `shared/skills/` and 2 in `.claude/skills/` (`audit`, `governed-data`). The source is `git ls-tree origin/main`, and `scripts/check-skill-levels.py` on the trial merge prints "20 in shared/skills (user), 2 in .claude/skills (project)".
- `reference/skills.md:37`, S-6: "not on main at 672c1f9: all 9 project skills are still in `.claude/skills/`". They moved: #128, main 72c94c3.
- `:85-86`: "Built from the 24 skills on `origin/main` (15 in `shared/skills/`, 9 in `.claude/skills/`)". Main now has 22 (20 + 2).
- `:93`: "7 of 24 have it today". Recount against main.
- `:353-361`, section 7: "The 9 aitools `.claude/skills` (`audit`, `frameworks`, `glossary`, ...)" and "Inside aitools each of them exists twice ... until the commander removes the project copies". Only `audit` and `governed-data` are project skills now, and #128 moved the other seven rather than duplicating them. The measured cost in section 7 must be redone for 2 skills.
- `:407-408`: `tool-eval` / `tool-ops` listed as `.claude` with "does not work (use `/aitool-eval`)" / "(use `/aitool-ops`)". Both are in `shared/skills` now, and the cards no longer exist.
- `:414`: the `aitool-eval, aitool-ops | shared` row describes deleted skills.
- The same staleness sits outside skills.md:
  - `reference/rules.md:120` (merged tree): "aitools (`/aitool-ops`, `/aitool-eval`), each with a project trigger rule";
  - `reference/rules.md:102-103` on the PR head;
  - `shared/skills/aitool-continue/SKILL.md:560-561` ("use `/aitool-eval`" / "use `/aitool-ops`"), which this PR edits.
- Fix: re-anchor skills.md sections 4, 7 and the table on main 86a0ea8 plus the train. Re-measure section 7. Point every `/aitool-*` mention at `/tool-ops` / `/tool-eval` (#129).

**B4. `reference/managed-file-deployment.md:288-291` misstates what the fallback does after an adopt.**
- The PR says: "In the fallback (`setup-user-skills`, no `~/.aitools/skills`) the old rule holds: after an adopt into the first LOCAL the caller reads SOURCE again for the next, which then verifies. Callers do not copy one LOCAL to another."
- The code at #125 7754c15 does the opposite. In `scripts/setup-user-skills.sh` `deploy_skill()`, case `"accept & adopt"`, the adopted LOCAL is copied to the other targets (`backup_file "$_other"`, `cp "$dest" "$_other"`, "Synced adopted skill to ..."), and a failure writes ERROR `sync failed: <skill>`. `scripts/setup-user-skills.ps1` `Deploy-Skill` (`Write-Summary "ERROR" $ToolName "sync failed: $SkillName"`, :181) does the same.
- Main's scrubbed text, the `=======` side of this hunk, describes this correctly.
- Fix: keep main's sentence for the fallback, and keep this PR's fan-out sentences ("each LOCAL goes through `deploy_managed_file` in its own fan-out ... the Cursor copy follows one run later").

## Non-blocking

- **N1. The open questions in the PR body are answered.** The commander answered Q1-Q4 on 2026-10-28, recorded in main 86a0ea8 (`plans/skills-and-rules-fanout.md` section 8):
  - "7) accept the deploy-harness"
  - "8) shared/ wins"
  - "9) setup-cursor-cli should do the fan-out for cursor skills/rules" (clarified: setup-user-cursor)
  - "10) yes"

  Move them from "Open questions" to answered, in the PR body and wherever skills.md section 10 lists them as open (Q2 and Q3 are cited there).
- **N2. The #123 head moved after this PR was anchored.** The PR anchors on 880749e; #123 is now 096a8bf (cb4d986 plus merges). cb4d986 adds Cursor behaviour the docs do not describe:
  - step 4 writes `n/a (nothing to deploy)` when only retired names exist;
  - a retired `.mdc` is found case-insensitively and reported under its on-disk name;
  - a bad header or an invalid manifest line writes one ACTION;
  - a dry-run row is ERROR when errors were logged.

  Nothing the docs say contradicts it. Optional additions to rules.md 6.1 / skills.md 6.2.
- **N3. `documentation-standards.md` "Skill placement".** The two sides conflict on substance.
  - Main (#128) says "`.claude/skills/` = project level (aitools sessions only, never deployed)" and "Pre-commit step 21 fails on a collision".
  - This PR says every source is deployed to user scope.
  - The commander's newer words win (FD-1 / R-4, 2026-10-26: "ALL project-scope rules AND skills are deployed to user-scope Claude Code", newer than SD-8 of 2026-10-21). With #119/#124 landed, `.claude/skills` does reach `~/.claude/skills`, so main's "never deployed" becomes false. Keep this PR's deployment statement.
  - Keep main's "Pre-commit step 21" sentence (`scripts/check-skill-levels.py` still enforces it) and main's "Governed data" bullet.
  - Change "Inside aitools each project skill exists at both levels until the commander removes the project copies" to name the 2 that remain.
- **N4. README run order.** This PR's side drops `setup-user-settings`, `setup-user-hooks` and `setup-user-skills` from the MDM list, which main's scrub added. Keep main's list and add this PR's run-order note ("rules and skills fan-outs ... `setup-user-skills` deploys skills as the fallback") and the "+ rules + skills" comments.
- **N5. CLAUDE.md inventory row 52** (the `shared/` bullet, FD-8 direct to main) is still pending, as the earlier review's N4 said. Main's CLAUDE.md still says "`aitools install` deploys to `~/.claude/` and `~/.cursor/`". Land it with or right after this PR.

## Expected conflicts and how to resolve them

**On main alone** (all 21 files): as above.
- modify/delete (3 files): take main's deletion.
- `check.yml`: keep both sides. This PR's train steps and main's `test-install` / `test-build-deploy-backup` steps are independent additions; the union parses (ruby YAML) in my #125 trial.
- Docs hunks: per-hunk union. This PR's fan-out statements (true once the train lands) plus main's scrub facts (B1 list, B4, N3, N4).

**On main plus the train** (stopped at the first conflict, as ordered):
- Train heads merged in order onto 86a0ea8 with `--no-ff` (local only):
  - #122 `feature/ddg-agent-workflow` conflicts at once: `check.yml`, plus modify/delete of `shared/skills/aitool-ops/SKILL.md`.
  - Skipping #122: #120 is clean, then #117 `feature/fanout-ci` conflicts in `check.yml`.
- The train heads are not yet updated for current main, so the chain cannot be run to #126 today. The orchestrator's per-PR main merges will change these files again.
- Pairwise virtual merges (`git merge-tree`) of 725b03a with each train head:
  - #122: `check.yml`
  - #121: `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` (#121's newer 4339c08 comment rewording; take #121's side)
  - every other head: clean
- Expect the same file set again once those land, plus whatever their main merges resolve differently.

## What I ran

| What | Result |
|---|---|
| `gh pr view 126` | DIRTY / CONFLICTING; CI on 725b03a all SUCCESS |
| Trial merge `origin/main` into 725b03a (`--no-ff --no-commit`, aborted after) | 21 conflicted files (3 modify/delete) |
| Naive resolve + `scripts/check-path-refs.py` | 7 dead refs, exit 1 (B2) |
| Naive resolve + `scripts/check-skill-levels.py` | 0 collisions; 20 shared + 2 project skills |
| Train chain from 86a0ea8 | stops at #122 (check.yml + aitool-ops modify/delete); without #122, stops at #117 (check.yml) |
| `git merge-tree` 725b03a x each train head | conflicts only with #122 (check.yml) and #121 (deploy-harness-mdm test) |
| Fact checks | `git grep` on 725b03a, #125 7754c15 (setup-user-skills `deploy_skill` / `Deploy-Skill`), #123 096a8bf (`git log` 725b03a..096a8bf, cb4d986), origin/main 86a0ea8 (`git ls-tree`, `git show 86a0ea8`) |

Worktree: `/Users/new-jose/repos/aitools/.claude/worktrees/m2-rv126` (detached; merge aborted, clean).

**Not run:** test suites (this PR's own commits are docs only; the code is reviewed in #117-#125), `check-pre-commit` as a whole (only its step 20 and step 21 helpers, on the trial merge), `check-pre-push`, Windows.

-- S3-Merge2-Review125 (level 3: S3-Merge2 -> Session Commander 10cf255a-c)
