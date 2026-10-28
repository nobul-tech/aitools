VERDICT: MERGEABLE

# PR #121 pre-merge review v1.0 (FO-3: Claude rules fan-out)

Reviewer: S3-Merge2-Review121, an independent reviewer under S3-Merge2 (MERGE-2 orchestrator, delegated by Session Commander 10cf255a-c), 2026-10-28.
I ran this review on the commander's 2026-10-28 order: "launch a mission to serve as an orchestrator and merge open prs in the correct order. learn from past mistakess. give it explicit instructions to fix issues when they arise. do this now. have the orchestrator launch a review first."

- **Head reviewed:** `4339c08437c6dfe08cfb75f102e48589a4681d9f` (`feature/fanout-claude-rules`)
- **Base:** origin/main `2a505c4` (trial 1 merged `86a0ea8`; the only change after it is a plan doc)
- **GitHub state:** DIRTY (conflicts with main)

**This verdict comes with conditions.** The code is correct and needs no fix. The branch itself cannot merge as it stands:
1. #117, #118 and #119 merge first, in that order.
2. Then origin/main is merged into this branch (`git merge --no-ff origin/main`), and the conflicts below are resolved.
3. CI must be green on the new head, and the new head SHA gets a re-verify comment before `gh pr merge`.

## Blocking findings

None.

## CI failure on 4339c08 (run 40447927627): clears once #118 is merged in

- **The failure:** the linux job fails in one step, `tests/fanout-lib`, at 356 passed / 2 failed: `FAIL ps bd-special` and `FAIL parity bd-special`. In the pwsh `Backup-Dir` prune, the decoy `r[1]*?.bak.2020-01-01T000000Z.bak.2020-01-02T000000Z` was deleted and `r[1]*?.bak.2020-01-02T000000Z` was kept.
- **The fix:** #118 commit `32a1354`, "Prune old directory backups with .NET calls in Backup-Dir". It replaces the wildcard-sensitive `Join-Path` + `Remove-Item` with `Path.Combine` + `Directory.Delete` and verifies the removal. That commit is on #118's head `d29dc5f` and not in #121. `git log origin/feature/fanout-claude-rules..origin/feature/fanout-lib` lists 15 commits, including `32a1354`, `ec6c4ac` and the #106/#115 main merges.
- **Evidence that it clears:**
  - #118's own linux CI at `d29dc5f` (run 40460911036, job 122045018305) reports `ok ps bd-special` and `ok parity bd-special`, and fanout-lib 374/0.
  - In my trial 2 (with #118 merged in), fanout-lib passes 374/0/0 on macOS.

## Non-blocking findings

1. **The PR body is stale.**
   - "Merge gates" lists #100 and #106 as pending. Both are on main now: #100 is `89e2953`, and #106 is `4ca476f`. #120's size-gate commit `44a4845` is also on main already (`git branch -r --contains 44a4845` lists origin/main).
   - Of the gates, #117 and #118 are still open. #120 is still open as a PR, but its code is effectively on main.
   - The "CI on 4339c08" paragraph is correct, but it should say the failure clears once #118 is merged in (see above).
   - Suggest one comment, or a body edit, at the final head.
2. **The branch is behind #118 by 15 commits.**
   - These include `f69e2db` ("n/a (nothing to deploy)" when every tracker count is 0) and `ec6c4ac` (half-made directory backups).
   - Both trial merges ran this PR's suites against those lib changes: everything is green (table below). None of this PR's assertions depends on the old `verified`-when-empty text.
3. **Tracker rows longer than 30 characters** (earlier audits A N5 and B N4) are settled by the commander's 2026-10-28 answer to hand-back Q4, "10) yes": the spec gets amended for tracker rows. Main `86a0ea8`, `plans/skills-and-rules-fanout.md` section 8. This stays a follow-up and is not a blocker.
4. **Docs drift until FO-7 (#126)** (earlier review finding 4). These still say rules come from `<userRepoPath>/claude/rules` and that dotprofile rules are embedded as a fallback:
   - `.claude/rules/deploy-paths.md`
   - `.claude/rules/managed-file-deployment.md`
   - `reference/user-repo.md`

   #126 is last in the train. Merge it promptly after #121.
5. **Not this PR's issue, but on the train path:** #119 conflicts with main in the header comment of `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` (two hunks: the comment text and the `--help` line range `$. <= 29` vs `28`). I resolved it in my trial by combining both comments and using `<= 30`. The #119 reviewer and merger own it.

## Code review (current head against current main)

- **Rules span** (`scripts/setup-user-claude.sh` 289-687, `.ps1` twin): unchanged from the version the earlier reviewer and auditors passed, plus the fix commit `ffcc5f1`.
- **Rows:** every `write_summary` / `Write-Summary` row and text matches between sh and ps1. That covers the 12 rule rows: n/a, cannot read harness rules, cannot read rules manifest, the bad-header ACTION, cannot create rules dir (twice, including the dry run), the retired ACTION, both dry-run rows and validation failed.
- **interactive-menus return-value contract:** the deploy loop handles `created|updated|verified|"accept & adopt"|skipped|failed`, plus a default branch that logs an error and records `failed`.
- **script-standards error handling:**
  - No new `2>/dev/null`, `|| true` or empty catch.
  - `mkdir`, `cat` and `rm` stderr is captured into the `log_error` reason.
  - `rm` is re-checked with `-e` / `-L`.
- **bash 3.2:** here-strings, `${x:+...}` and `${line#*"$TAB"}`. `/bin/bash -n` passes, and the suite passes under `/bin/bash` 3.2.
- **deploy-paths:** the rules source is `~/.aitools/rules` only. `build-deploy.sh` no longer embeds dotprofile rules: no `USER_RULE_*` and no "Rules fallback" are left, and the claude-mdm check asserts the absence. The size-gate test now pads the still-embedded `claude/CLAUDE.md` template.
- **Hot spots #128 and #129** (skills and rules moved or deleted): this PR does not touch `shared/skills`, `.claude/skills`, or the deleted aitool-ops/aitool-eval files.
  - After merging main, the PR's net diff against main is 11 files: `check.yml`, `README.md`, `aitools-lib.sh/.ps1`, `build-deploy.sh`, `setup-user-claude.sh/.ps1`, and the tests claude-mdm, deploy-harness-mdm, fanout-lib and rules-fanout.
  - The `.claude/rules/interactive-menus.md` and `reference/managed-file-deployment.md` entries in the GitHub file list are already on main, so the net diff is 0.

## Expected conflicts and how to resolve them

**Trial 1** (head `4339c08` + origin/main `86a0ea8`) conflicts in 3 files:
- `.github/workflows/check.yml`, 4 hunks. Take the union: keep main's "Installer Step 3/5 relay" and "build-deploy backup + swap (incident #86)" steps and the PR's fanout-lib, rules-fanout, b8-consumers, deploy-harness, hookin, rules-fanout-cursor and build-package steps. The result parses (ruby YAML), and "Every test suite is in CI" passes: "All 18 test suites are in CI or exempt".
- `README.md`, 2 hunks. Take main's "Deploy to a machine" layout (it is newer, from #132). Append the FO-3 run-order note after "The other scripts read from it.": "The rules fan-outs in `setup-user-claude` and `setup-user-cursor` read `~/.aitools/rules`: run before `deploy-harness`, they report `n/a (no harness rules)` and deploy no rules."
- `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`, 1 hunk. Take the PR's side, which pads `claude/CLAUDE.md`. Main's side pads a dotprofile rule, which this PR no longer embeds, so with main's side the forced size-gate check would fail.

**Trial 2** (origin/main + #117 `dbe8f46` + #118 `d29dc5f` + #119 `fd660a9`, in that order, then #121) conflicts in 2 files:
- `.github/workflows/check.yml`, 2 hunks (build-deploy backup vs rules-fanout steps). Take the union, as above.
- `README.md`. Same resolution as above.
- The deploy-harness-mdm test auto-merges to the PR's `CLAUDE.md` padding.

The steps before #121 had their own conflicts: #117 and #118 in `check.yml` (union), and #119 in the deploy-harness-mdm header (finding 5).

## What I ran (macOS 27 arm64)

- **Isolation:** suites ran under an isolated HOME and USERPROFILE (`.scratch/session-rv121/runs-<label>/home`), with `AITOOLS_*` overrides unset. The suites also isolate themselves.
- **Commits:** nothing was pushed. Trial 2's intermediate steps were local commits on a detached HEAD in my worktree only (`839e469`, `fda6cb7`, `ef94ea4`), never pushed. Both merges were aborted afterwards.

| Check | Trial 1 (main) | Trial 2 (train) |
|---|---|---|
| tests/rules-fanout (bash 5 + pwsh) | 118 / 0 / 1 | 118 / 0 / 1 |
| tests/rules-fanout `/bin/bash` 3.2 `--bash-only` | 44 / 0 / 23 | 44 / 0 / 23 |
| tests/claude-mdm bash 5; `/bin/bash` 3.2 | 35 / 0 / 0 each | 35 / 0 / 0 each |
| tests/fanout-lib | 358 / 0 / 0 | 374 / 0 / 0 |
| tests/deploy-harness-mdm | 65 / 0 / 0 | 67 / 0 / 0 |
| tests/build-deploy/test-build-deploy-backup.sh (#131) | 24 / 0 | 24 / 0 |
| tests/managed-files (sh) | 57 / 0 / 0 | 57 / 0 / 0 |
| tests/hookin | 46 / 0 / 0 | 46 / 0 / 0 |
| tests/deploy-harness | 76 / 0 / 0 | 131 / 0 / 0 |
| `bash -n` and `/bin/bash -n` setup-user-claude.sh; `bash -n` build-deploy.sh | pass | pass |
| pwsh parser: setup-user-claude.ps1, aitools-lib.ps1 | pass | pass |
| check.yml YAML + "Every test suite is in CI" body | parses; 18 suites OK | parses; 18 suites OK |

I also read:
- the failed log of run 40447927627;
- #118's linux job log, run 40460911036;
- the existing review (S3-FanoutImpl-Review121), audits A and B, and the author's fix comment;
- `git merge-tree` train simulation.

## Not run

- Native Windows and Linux. The linux bd-special evidence is #118's CI.
- `check-pre-commit`, `check-pre-push`, `check-post-push`.
- Anything against the real HOME. A real MDM endpoint.
- tests/managed-files ps1 and adopt-push.
