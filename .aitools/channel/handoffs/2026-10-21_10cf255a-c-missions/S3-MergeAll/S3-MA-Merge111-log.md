# S3-MA-Merge111 log: PR #111 merge

**Version:** v1.0 · **Written:** 2026-10-27 (UTC) · **By:** S3-MA-Merge111 (delegate of mission MERGE-ALL)

## Result

PR #111 (`feature/harness-mdm-followups`, head 8caa79e) was merged into main with a merge commit: **613f0be816a67af9feff0b7a9265de455d37d0fe** (mergedAt 2026-10-27T04:24:17Z). The branch was kept. Main's CI run 40449546435 and CodeQL run 40449545797 for 613f0be both finished with `success`.

## Steps

1. **Pre-merge state.** `gh pr view 111`: OPEN, base main, MERGEABLE, mergeStateStatus CLEAN. 8 checks were all SUCCESS: CI linux/macos/windows, CodeQL x4.
2. **Reviews.**
   - The first S3-H2-MDM-Review verdict (at 633d1d7) had BLOCKING B1.
   - The re-verify at fdb5109 found NO BLOCKING FINDINGS: B1 and N1-N4 fixed, N6-N8 open and non-blocking.
   - 8caa79e (the N6 fix) was never re-reviewed, so I reviewed it and posted the verdict: https://github.com/nobul-tech/aitools/pull/111#issuecomment-6433708744 (NO BLOCKING FINDINGS).
   - The diff is one line, build-deploy.sh:2331: the sha check stays on the Latin-1 bytes, and record lines are parsed from a UTF-8 decode of those bytes. Content is base64, so the decode does not touch it.
   - No test was added for a non-ASCII file name (follow-up).
3. **Conflict/BEHIND.** None. `git merge-tree --write-tree origin/main origin/feature/harness-mdm-followups` merged cleanly (tree a7cb52a). The worktree `.claude/worktrees/h2-mdm` was clean, and I did not change it.
4. **Pre-merge local tests** (worktree at 8caa79e):
   - tests/deploy-harness-mdm: 64/0/0
   - tests/deploy-harness: 76/0/0
5. **Merge.** I re-checked the state just before merging: CLEAN, head unchanged. Then `gh pr merge 111 -R nobul-tech/aitools --merge`.
6. **Post-merge.**
   - `git pull --ff-only`: 672c1f9..613f0be.
   - CI 40449546435: success (windows, linux, macos). CodeQL 40449545797: success.
   - Local suites on main:

| Command | Result |
|---|---|
| `bash tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` | 64 passed, 0 failed, 0 skipped |
| `/bin/bash tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` (bash 3.2) | 64 passed, 0 failed, 0 skipped |
| `bash tests/deploy-harness/test-deploy-harness.sh` | 76 passed, 0 failed, 0 skipped |
| `bash -n` on scripts/build-deploy.sh, scripts/deploy-harness.sh, the MDM test | OK |
| pwsh parser on scripts/deploy-harness.ps1 | parse OK |
| `git status --short scripts tests deploy` after the tests | clean |

7. **Fix PR.** Not needed. Main is green.

## Not run

- Windows: covered by CI only.
- The real dotprofile build: never against the real HOME.

## Follow-ups (from the reviews, still open)

- **N5.2:** the corrupt config.json outcome differs between .sh and .ps1, and there is no test for it.
- **N6:** no test record with a non-ASCII file name.
- **N7:** the .ps1 has about 9 KB of headroom under the 200,000 B Intune limit.
- **N8:** the first-line truncation guard is skipped when perl is missing.
- **Brief note:** Step 8b gets `--skip-config` now that #111 has merged.

## INCIDENT markers (not filed)

- INCIDENT: CI (`.github/workflows/check.yml`) does not run `tests/deploy-harness/` or `tests/deploy-harness-mdm/`. The run log for 40449546435 lists no deploy-harness step, so #100/#111 regressions in those suites are caught only by local runs. This is a candidate for the friction plan's CI steps.
- INCIDENT (carried from the review, unknown scope): in the generated deploy-harness.ps1, an uncaught terminating error inside `try { } finally { }` returned rc 0 (review N1).
