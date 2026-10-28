VERDICT: BLOCKING

# PR #117 (FO-0, `feature/fanout-ci`) -- pre-merge review v1.0

Reviewer: S3-Merge2-Review117 (independent, delegated by S3-Merge2 under Session Commander 10cf255a-c). Posted on the commander's 2026-10-28 order: "have the orchestrator launch a review first."

- **Head reviewed:** `dbe8f463b4e53e6a12acd95a61cf2ed68b12401d` (origin; the local worktree `fo-ci` is at the same SHA, clean, nothing unpushed)
- **Against:** origin/main `86a0ea88faec50e13b9d49067f3894bb4c771bea` (trial merge). Main has since moved to `2a505c4`, which changes only `plans/build-package/design.md` and does not affect this PR.

## Bottom line

The change is correct, and on the merged tree it works: the coverage step passes, and every suite it adds passes locally. It is **blocking only because the branch has a real content conflict with main** in `.github/workflows/check.yml`. Main gained the `tests/build-deploy/test-build-deploy-backup.sh` steps (#131) at the same places where #117 adds its steps. The fix is a single merge commit on the branch, and no code change is needed. After that fix and green CI on the new head, the PR is mergeable. Re-verify the final SHA before the merge.

## Blocking findings (1)

**B1. Conflict in `.github/workflows/check.yml` with main (#131).** `git merge --no-ff --no-commit origin/main` has two conflict hunks:

- **macos job** (after the `setup-user-claude dev + MDM tests (macOS /bin/bash 3.2)` step, around line 168 of the merge): HEAD has the 8 FO-0 steps (b8-consumers bash 5 and 3.2, deploy-harness, deploy-harness-mdm, hookin, rules-fanout-cursor, build-package bash 5 and 3.2). Main has `build-deploy backup + swap tests (incident #86)` and its `macOS /bin/bash 3.2` twin.
- **linux job** (after `setup-user-claude dev + MDM tests (bash + pwsh)`, around line 428): HEAD has the 6 FO-0 steps. Main has `build-deploy backup + swap tests (incident #86)`.

**Fix (exact):** in the worktree `fo-ci`, run `git merge --no-ff origin/main`. Resolve both hunks by **keeping both sides**, HEAD's FO-0 steps first and then main's build-deploy-backup step(s), with a blank line between the two blocks. Leave the `%exempt` list empty. Then `ruby -e 'require "yaml"; YAML.load_file(ARGV[0])' .github/workflows/check.yml`, commit, and push. Optional, for consistency with FO-0 (non-blocking): add `if: ${{ !cancelled() }}` to main's three build-deploy-backup steps.

**Why "keep both" is required, not taking either side alone:**
- With both sides kept, the coverage step passes: "All 16 test suites are in CI or exempt", rc 0.
- With HEAD only ("ours"), it fails, rc 1: `::error::tests/build-deploy/test-build-deploy-backup.sh is not run by any step` and `::error::tests/profile/test-install.sh is not run by any step`. The second one is because ours-only also loses main's test-install steps, which sit outside the conflict hunks.
- With main only ("theirs"), FO-0 is dropped.

This is the "#131 suite flagged" case the orchestrator expected. Main already runs the new suite, so the check flags it only if the conflict is resolved wrongly.

## Non-blocking findings

1. **The PR body is stale.**
   - "This PR contains PR #120 ... Merge #120 first" is moot: #120's code is already on main (1b5ab5d/44a4845), and the #120 merge is empty (see my #120 verdict).
   - The CI evidence names head dbe8f46 against base c412377, not current main.
   - "14 suites" is now 16: main added `tests/build-deploy/test-build-deploy-backup.sh` and `tests/profile/test-install.sh`.
   - Suggested: a one-line addendum in the merge comment.
2. **GitHub shows CONFLICTING/DIRTY.** Part of that is real (B1). Part of it is phantom, from the criss-cross history (several merge bases, as in #120). Once the branch merges main in, the merge base is a single commit and GitHub sees the true state.
3. **Later PRs and the coverage check.** Once #117 is on main, every later PR that adds a `tests/*/test-*.sh` suite must add a single-line `run: bash <path>` step, or the check fails. I checked the open branches. Each one already runs its new suites in its own check.yml:
   - #122: `tests/hooks/test-delegation-duty-guard.sh`
   - #118, #121, #123-#126: `tests/fanout-lib`, `rules-fanout`, `skills-fanout`, `skills-legacy`
   - #119: no new suites

   Their merges will hit the same kind of check.yml hunk as B1. Resolve each by keeping both sides, and check that the coverage step passes after each merge.
4. **Carried over from Review117 (2026-10-27); still valid, follow-ups:**
   - The detector sees single-line `run:` only and counts a suite run in any job.
   - It ignores `if:`.
   - It does not cover `test-*.ps1`.
   - There is no 3.2 step for deploy-harness, hookin or rules-fanout-cursor.
   - There is no Windows fan-out coverage.
   - The `tests/rules-fanout-cursor` header still claims Git Bash.

   The PR body's own comment documents the blind spots.

## Expected conflicts and how to resolve them

Only B1 (`.github/workflows/check.yml`, 2 hunks), resolved by keeping both sides as above. `scripts/build-deploy.sh` auto-merges, taking main's #131 backup and swap code. After resolution, the merge's only difference from main is `.github/workflows/check.yml` (+112 lines).

## CI

On dbe8f46, all checks are SUCCESS: macos, linux, windows, CodeQL, Analyze x4. That run was against the old base. CI must re-run on the new merge head.

## What I ran (macOS, trial merge of dbe8f46 + 86a0ea8 in the detached worktree `.claude/worktrees/m2-rv117`, both conflict hunks resolved by keeping both sides, uncommitted; then `git merge --abort`)

- Every suite ran with `HOME=<scratch>/suites/home-<suite>` and `env -u AITOOLS_USER_REPO_PATH`.
- YAML parse (ruby): OK.
- Coverage step, extracted from the parsed YAML: exactly 1 copy (linux job); "All 16 test suites are in CI or exempt", rc 0.
- Negative case (branch-only check.yml against the merged tree's suites): rc 1, with the two suites named above.

| Suite | Result |
|---|---|
| b8-consumers (bash 5) | 60/0 |
| b8-consumers (`/bin/bash` 3.2) | 60/0 |
| deploy-harness | 76/0 |
| deploy-harness-mdm | 65/0 |
| hookin | 46/0 |
| rules-fanout-cursor | 164/0, 1 skip |
| build-package test-cli (bash 5) | 36/0 |
| build-package test-cli (3.2) | 36/0 |
| build-deploy-backup (bash 5) | 24/0 |
| build-deploy-backup (3.2) | 24/0 |
| claude-mdm | 34/0 |

All exit 0.

## Not run

- Linux and Windows jobs (CI only).
- `check-pre-commit` / `check-pre-push` (the change is CI YAML only).
- No push or merge (review only).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
