VERDICT: MERGEABLE

# S3-Merge2-Review118 verdict v1.0 -- PR #118 (FO-1 fan-out lib helpers)

Independent pre-merge review by S3-Merge2-Review118 (delegated by S3-Merge2), on the commander's 2026-10-28 order: "launch a mission to serve as an orchestrator and merge open prs in the correct order ... have the orchestrator launch a review first."

- **Head reviewed**: `d29dc5f5d140847bd15ef0a2aba05dbea722f5b3` (feature/fanout-lib), base `main`.
- **Against**: origin/main `86a0ea8` (trial 1) and `2a505c4` (trial 2; it adds one line to `plans/build-package/design.md` and nothing else).
- **GitHub state**: `mergeStateStatus: DIRTY`, `mergeable: CONFLICTING`. The only conflict is `.github/workflows/check.yml`. It is mechanical and resolved below.
- **Blocking findings**: 0.
- **Condition**: the merger has to commit the conflict resolution on the branch (`git merge --no-ff origin/main`, never a rebase). That gives a new head SHA. Per MERGE-2's operational learning, that SHA then needs green CI and a re-verify before the merge.

## Blocking findings

None.

## Conflicts and how to resolve them

**Trial 1: origin/main + #118.** The only conflict is in `.github/workflows/check.yml`. `scripts/aitools-lib.sh` and `scripts/aitools-lib.ps1` merge cleanly: main's only lib change since the merge base 4ca476f is the jsonl warn-once code in `jsonl_record` / `Write-JsonlRecord`, which does not overlap with this PR. The conflict has two hunks, one in the macos job and one in the linux job:

1. macos job, after "User init tests (macOS /bin/bash 3.2)":
   - Keep #118's two "Fan-out lib helper tests" steps and main's two "Installer Step 3/5 relay tests" steps.
   - Keep #117's (FO-0) b8-consumers / deploy-harness / deploy-harness-mdm / hookin / rules-fanout-cursor / build-package steps and main's two "build-deploy backup + swap tests (incident #86)" steps.
2. linux job: the same union, with one step per suite.

Resolution: keep both sides of every hunk. Put a blank line between steps. Give main's new steps (`test-install`, `test-build-deploy-backup`) the `if: ${{ !cancelled() }}` that FO-0 adds to every step after the first suite, so they still run after an earlier failure. With that union:

- the "Every test suite is in CI" perl reports 17 suites, 0 missing;
- every suite below passes on the merged tree.

**Trial 2: origin/main + #117 (feature/fanout-ci) first, then #118.** This is the order the merger will meet. #118 already contains #117's head `dbe8f46`, so after #117 lands only #118's own fan-out-lib steps conflict:

- the same file and the same two places;
- HEAD side: main's "Installer Step 3/5 relay tests"; #118 side: "Fan-out lib helper tests";
- resolution: keep both.

The union-resolved check.yml from trial 2 has the same set of steps as trial 1. Only the step order differs. The lib files merge cleanly here too.

## `FAIL ps bd-special` on #121 / #124 / #125

#118 fixes it, in commit 32a1354: `Backup-Dir` now prunes with `Path.Combine` + `Directory.Delete` + a verify, not `Join-Path` + `Remove-Item -LiteralPath -Recurse`.

- The failure on #121 matches the bug that commit fixes. In run 40447927627 (job 122003524584, linux), `ps bd-special` deleted the decoy `r[1]*?.bak.2020-01-01T000000Z.bak.2020-01-02T000000Z` and kept `r[1]*?.bak.2020-01-01T000000Z`. The run ended 356 passed, 2 failed.
- #118's own linux CI (run 40460911036 at d29dc5f) passes. So does my local run on the merged tree.
- Which branches contain 32a1354 (`git merge-base --is-ancestor`):

  | Branch | Contains 32a1354 |
  |---|---|
  | fanout-claude-rules (#121) | no |
  | fanout-claude-skills (#124) | no |
  | fanout-skills-legacy (#125) | no |
  | fanout-harness-skills (#119) | no |
  | fanout-cursor (#123) | yes |
  | fanout-docs (#126) | yes |

- Those four branches clear once #118 is on main and they merge main in.

## Non-blocking findings

- **N1 -- `!cancelled()` on main's new CI steps.** `.github/workflows/check.yml` (merge resolution): main's `test-install` and `test-build-deploy-backup` steps have no `if: ${{ !cancelled() }}`. Without it, an earlier failing suite hides their results, which is the gap FO-0 closed. Add it in the conflict resolution (see above).
- **N2 -- `n/a (nothing to deploy)` is a new summary text in the governed-looking `n/a (...)` form.** It comes from `deploy_tracker_summary` / `Write-DeployTrackerSummary`. `reference/script-standards-detail.md` "Governed summary outcomes" reserves `n/a (<environment>)` for an environment skip, and the glossary does not define this text. This belongs with the `removed` vocabulary work already assigned to FO-7 (audit B N4). `TODO(glossary)`.
- **N3 -- newer .NET and PowerShell APIs in the .ps1.** `aitools-lib.ps1` `Copy-DirectoryTree` and `Deploy-ManagedFile` use `ResolveLinkTarget` / `LinkTarget` (.NET 6, so pwsh 7.2+), and `Get-FanoutEntryType` uses `UnixStat` (I believe pwsh 7.4+; unverified). Older pwsh versions fail in two different ways:
  - On pwsh 7.0/7.1, `LinkTarget` is `$null` with no error, so the dangling-symlink guard is skipped silently.
  - `ResolveLinkTarget` throws, so a backup of a tree that holds a link gives `copy failed`.

  This is harmless at the pwsh 7 baseline on current runners. A follow-up could state the minimum pwsh version in the header.
- **N4 -- perl stderr can corrupt the `*.md` count.** In `aitools-lib.sh` `backup_dir`, the count is captured with `2>&1`. If perl wrote a warning while still exiting 0, the count would not be a number: `[ "$file_count" -eq 0 ]` would print a test error and the backup would go ahead. Unlikely (`perl -e` with no `-w`). A fix is to capture stderr separately, as the prune block's error path does.
- **N5 -- Windows native not run.** The fan-out suite is not in the windows CI job, and its `[ ] * ?` and FIFO cases skip there (as the PR body says). This was disclosed and carried by the earlier reviews.
- **N6 -- head d29dc5f had no independent re-verify.** The last independent re-verify (issuecomment-6434142305) was at f69e2db. ec6c4ac (R1 and R2 fixes) and d29dc5f (main merge, no file change) were not re-verified. This review covers them: bd-partial, bd-mdcase and bd-link-sh/ps are in the 374/0 run below, and I read the ec6c4ac code in `backup_dir` / `_backup_dir_discard` / `Remove-IncompleteBackup`.

Checked and clean:

- Every `deploy_tracker_record` / `Record-DeployOutcome` caller on the merged tree (setup-user-claude, -cursor, -hooks, -skills, build-deploy) passes either a known lower-case outcome or a `MANAGED_FILE_RESULT` value (created / updated / verified / accept & adopt / skipped / failed). The new `default` branch, which counts an unknown outcome as failed, does not fire for any caller.
- Existing `backup_dir` callers (setup-user-claude, setup-user-cursor) do not read the new result variables, so nothing changes for them except the documented log lines.
- No `Set-StrictMode` anywhere in `scripts/` or `tests/`, so an absent property returns `$null` with no error.
- No new `2>/dev/null`, `|| true` or `SilentlyContinue` in the lib diff. Every `catch` logs. bash 3.2 constructs only: here-strings, no associative arrays.

## What I ran

On macOS arm64. Detached worktree `.claude/worktrees/m2-rv118`, `git merge --no-ff --no-commit origin/main` onto d29dc5f, check.yml union-resolved. Every suite ran with `HOME=<scratch>/home-<suite>`, and `AITOOLS_USER_REPO_PATH` and `AITOOLS_ENVIRONMENT` unset.

| Suite | Result |
|---|---|
| tests/fanout-lib (bash 5 + pwsh) | 374 / 0 / 0 |
| tests/fanout-lib (/bin/bash 3.2 `--bash-only`) | 134 / 0 / 1 |
| managed-files sh (bash 5, 3.2) / ps1 | 57/0, 57/0 / 39/0 |
| adopt-push sh / ps1 | 28/0 / 23/0 |
| logging sh / ps1 | 24/0 / 15/0/5 |
| profile test-lib (bash 5, 3.2) | 361/0, 160/0 |
| profile test-install (main's new suite; bash 5, 3.2) | 41/0, 22/0 |
| rules-fanout-cursor | 164/0/1 |
| deploy-harness | 76/0 |
| hookin | 46/0 |
| b8-consumers | 60/0 |
| claude-mdm | 34/0 |
| deploy-harness-mdm | 65/0 |
| build-deploy backup (main's #131 suite; bash 5, 3.2) | 24/0, 24/0 |

Static checks:

- `bash -n` and `/bin/bash -n` on `scripts/aitools-lib.sh` and `tests/fanout-lib/test-fanout-lib.sh`: OK.
- pwsh `Parser::ParseFile` on `scripts/aitools-lib.ps1`: OK. It has 0 LF-only lines (CRLF kept).
- Modes: lib.sh 100755, lib.ps1 100644, test 100755.
- The "Every test suite is in CI" perl from check.yml, run on the merged tree: 17 suites, 0 missing.

Trial 2 (main + #117 union, then #118): conflict in check.yml only; the resolved step set is the same as trial 1. Both trial merges were aborted and the worktree is back at d29dc5f. Nothing was committed to a branch or pushed.

PR CI at d29dc5f (run 40460911036): macos, linux and windows passed; CodeQL passed.

**Not run**: Windows native, check-pre-commit / check-pre-push / check-post-push, and anything against the real HOME. I did not run CI on the resolved merge; it does not exist on GitHub yet.
