# S3-MA-Merge115 log: PR #115 (fix/mf-lib-relay)

**Version:** v1.0 · 2026-10-27 (UTC) · S3-MA-Merge115, delegate of mission MERGE-ALL

## Result

- **Merged.** PR #115 was merged at 2026-10-27T05:30:56Z with a merge commit (`gh pr merge 115 --merge`). The merge commit is `167dcbec7d70438df232fe4ca9de67303ea655ef`. The branch is kept.
- **Main CI on 167dcbe:** CI run 40455753154 succeeded (macos, linux and windows all success). CodeQL run 40455752956 also succeeded.
- **Local suites on main at 167dcbe:** all pass (results below).

## Steps

1. **Before merging.**
   - The PR was OPEN with base main and head 2ae798a. Its checks were green but dated 2026-10-23, against an old base: the branch was 107 commits behind origin/main.
   - The order prerequisites had merged: #113 (its base) at 02:39:48Z and #111 at 04:24:17Z.
2. **Review state.**
   - One review comment: S3-MF-Relay-ReviewA, "approve with minors, 0 B / 0 M / 1 m / 4 n", on 4c55ec0.
   - Commit 2ae798a addresses m1 and n1-n4 (see its commit message).
   - No blocking finding is open.
3. **Merged origin/main into the branch** in worktree `.claude/worktrees/mf-relay-a`.
   - This was a merge commit, 9760c11: no rebase and no force-push. There were no conflicts; `scripts/aitools-lib.ps1` merged automatically.
   - I made this merge although GitHub said CLEAN, so that CI would test the tree that would actually land.
   - The local suites passed. I pushed and commented on the PR: issuecomment-6434154062.
4. **CI fix round 1.**
   - Run 40452798160 failed on linux and macos, in step "setup-user-claude dev + MDM tests".
   - Cause, from the log: `[build-deploy] [error] deploy/deploy-harness.ps1 is 202519 bytes, over the Intune script limit (200000)`. The #115 lib growth takes the inlined aitools-lib.ps1 over the size FAIL that #111 (fdb5109) added. build-deploy then exits non-zero, and every tests/claude-mdm build case fails after it.
   - Fix: I cherry-picked (`-x`) PR #120's two code commits as 1b5ab5d and 44a4845: 978e72d (the gate becomes a WARN) and cdad49f (the review fixes). This is FO-0b, RECONCILE FX-12, decision D3, which the commander accepted under Q16. #120 was reviewed "APPROVE WITH CHANGES" and the fixes are in cdad49f.
   - I pushed and commented on the PR: issuecomment-6434402689.
   - Run 40454466632 was green: linux, macos, windows, CodeQL and all Analyze jobs.
5. **Merge.** mergeStateStatus was CLEAN and main was still 613f0be. I merged with `--merge`.
6. **After the merge.**
   - `git pull --ff-only` on the main checkout: 613f0be..167dcbe.
   - Ran the suites under an isolated HOME (scratch `.claude/worktrees/mf-relay-a/.scratch/session-ma115/`).
   - The main checkout's scripts/ and tests/ are unchanged afterwards (`git status --short`).

## Local results (macOS arm64, isolated HOME), on main at 167dcbe

- `bash -n` (bash 5 and /bin/bash 3.2): clean on scripts/aitools, aitools-lib.sh, setup-user-claude.sh, setup-user-config.sh, build-deploy.sh and the touched tests.
- pwsh parser: clean on aitools.ps1, aitools-lib.ps1, setup-user-claude.ps1, setup-user-config.ps1 and test-adopt-push.ps1.

| Suite | Result |
|---|---|
| test-adopt-push.sh | 28/0 |
| test-adopt-push.ps1 | 23/0 |
| test-managed-files.sh | 57/0 |
| test-lib | 361/0 |
| test-lib, /bin/bash 3.2 | 160/0 |
| test-config | 319/0 |
| test-config, 3.2 | 208/0 |
| test-user-init | 229/0 |
| test-user-init, 3.2 | 128/0 |
| test-profile | 763/0 |
| test-logging | 24/0 |
| claude-mdm (bash 5) | 34/0 |
| claude-mdm (3.2) | 34/0 |
| deploy-harness-mdm | 65/0 |
| deploy-harness | 76/0 |

## Not run

- Windows locally. CI's windows job passed.
- check-pre-commit and check-pre-push. Pre-push step 7 is a known FAIL until the dotprofile is rebuilt.

## Notes for the orchestrator

- **#120 now overlaps main.** Its two code commits are on main (as 1b5ab5d and 44a4845). When #120 merges, the identical changes should resolve cleanly. Re-check its diff when its turn comes.
- **Size limit.** deploy-harness.ps1 is 202,519 B: still over the Intune 200,000 B limit, now reported as a WARN. FX-35 (dedupe the inlined lib) is still open. Until it lands, deploy-harness.ps1 cannot ship as an Intune platform script.
- INCIDENT: the stack's CI passed only because it ran against old bases. The #111 size FAIL plus the #113/#115 lib growth broke CI only when the two met. A CI gate that requires branches to be up to date with main (or a merge queue) would catch this before the merge. Candidate for plans/merge-friction-improvements.md.
