# S3-MA-Merge110 log: PR #110 merge

**Version:** v1.0 · **Written:** 2026-10-27 (UTC) · **By:** S3-MA-Merge110 (delegate of mission MERGE-ALL)

## Result
- PR #110 "Cursor: fan out user-level rules only and prune against the rules manifest" (branch `feature/harness-cursor-user-rules`) was **MERGED** at 2026-10-27T04:04:19Z with `gh pr merge 110 --merge --match-head-commit 8d935f9`. The branch is kept.
- Merge commit on main: `672c1f987b94f70ed0bbaea755e3c285711ec5ef`.
- Main CI run 40447690603 (push, 672c1f9): **success**. windows took 1m17s, linux 10m20s, macos 14m21s. CodeQL run 40447689077: **success**.

## Steps
1. Pre-check: OPEN, base main, MERGEABLE, CLEAN, head adcf4a7. Every check was green, but the CI dated from 2026-10-23.
2. Reviews: two COMMENTED reviews from S3-H2-Cursor-Review. Both say "NO BLOCKING FINDINGS": the first review, and a re-verification at 7f7fc5c that marks findings 1-4 resolved. The PR had no other comments.
3. Stale-CI check: the merge base with main was 699eba8. Since then, main had changed `scripts/setup-user-cursor.sh/.ps1`, `scripts/aitools-lib.sh/.ps1` and `.github/workflows/check.yml`. The green CI therefore did not cover the merged state, so I merged origin/main into the branch in the existing worktree `.claude/worktrees/h2-cursor`. That worktree was clean before the merge. The result is merge commit 8d935f9, a clean ort auto-merge of setup-user-cursor.*, with no rebase and no force-push. I pushed it (adcf4a7..8d935f9) and posted a PR comment: https://github.com/nobul-tech/aitools/pull/110#issuecomment-6433284805
4. Fresh PR CI on 8d935f9 (run 40446391239): windows, linux and macos passed. The CodeQL Analyze jobs (actions, js-ts, python, ruby) passed, and the CodeQL aggregate was skipping. The PR state was then CLEAN, so I merged it.
5. After the merge: `git pull --ff-only` on the main checkout (1e34284..672c1f9), then the local suites.

## Local tests (macOS, isolated temp HOME inside each suite)
Runner: `.claude/worktrees/h2-cursor/.scratch/session-mg110/run-tests.sh`. I ran it twice: on the branch after the main-merge, and on main at 672c1f9. Both runs gave the same results:
- `bash -n` OK: scripts/deploy-harness.sh, scripts/setup-user-cursor.sh, scripts/aitools-lib.sh, and both test scripts.
- pwsh parser OK: scripts/deploy-harness.ps1, scripts/setup-user-cursor.ps1, scripts/aitools-lib.ps1, tests/rules-fanout-cursor/convert-rule.ps1, tests/rules-fanout-cursor/step4-driver.ps1.
- tests/deploy-harness/test-deploy-harness.sh: 76 passed, 0 failed, 0 skipped.
- tests/rules-fanout-cursor/test-rules-fanout-cursor.sh: 164 passed, 0 failed, 1 skipped.
- `git status --short -- scripts tests deploy` on the main checkout showed no changes afterwards.

## Findings
- INCIDENT: `.github/workflows/check.yml` runs neither `tests/rules-fanout-cursor/` nor `tests/deploy-harness/`. A grep for `rules-fanout` and `deploy-harness` in check.yml returns nothing. The suites for this PR run only locally. This is input for plans/merge-friction-improvements.md.
- INCIDENT (process): GitHub reported CLEAN plus green checks from 3 days earlier, although main had since changed files this PR touches. "CLEAN" does not mean the merged state was tested. Possible fixes: require branches to be up to date before merging, or have the merge step refresh any PR whose CI is older than main's last change to the files it touches.
- Follow-up: the PR ships protected-doc versions that have not been applied yet: `S3-H2-Cursor-drafts/reference/tool-ops-cursor.md.edit.txt`, `.../registries/tool-ops.json.edit.txt`, and the S3-H2-Manifest drafts (harness.md, managed-file-deployment.md, the rules managed-file-deployment.md). They belong in the post-merge follow-ups.

## Not run
- Windows and Linux local runs; CI covered them.
- Pre-push checks; I created no new code commits, only the main-merge.
