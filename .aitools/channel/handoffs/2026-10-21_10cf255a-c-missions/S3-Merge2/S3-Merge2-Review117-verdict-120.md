VERDICT: MERGEABLE

# PR #120 (FO-0b, `feature/fanout-size-warn`) -- pre-merge review v1.0

Reviewer: S3-Merge2-Review117 (independent, delegated by S3-Merge2 under Session Commander 10cf255a-c). Posted on the commander's 2026-10-28 order: "have the orchestrator launch a review first."

- **Head reviewed:** `1d37d935fcb51204048679000f83bfd3bbcf80d0` (origin, PR head)
- **Also reviewed:** local unpushed `d9bdfd045882487fbb3da0de06f4170ae4f02ab9` in worktree `.claude/worktrees/fo-size` (see "Merge mechanics")
- **Against:** origin/main `86a0ea88faec50e13b9d49067f3894bb4c771bea` (tree `0314ad90`). Rechecked against `2a505c46afd5e8d3b84a393334e23e41ecfe27d3` (it changes only `plans/build-package/design.md`): the merge result's tree is `bc5ed735`, which is main's tree.

## Bottom line

#120 adds **nothing** over current main. Its two code commits are already on main as equivalent patches: 978e72d = 1b5ab5d and cdad49f = 44a4845 (`git cherry -v origin/main origin/feature/fanout-size-warn d7f6855` marks both `-`). Merging it is an empty merge: the merge result's tree is exactly main's tree (`0314ad90`). Merge it only to close it with a merge commit, as the mission order requires.

**Blocking findings: 0.** There is one precondition, a mechanical one: GitHub cannot merge the current head (see below).

## Merge mechanics (the one thing to do before merging)

- GitHub reports `mergeable: CONFLICTING`, `mergeStateStatus: DIRTY` on 1d37d93. Git's local ort merge is clean. The difference comes from the criss-cross history: `git merge-base --all origin/main origin/feature/fanout-size-warn` returns **6** merge bases (c412377, 3de51d6, 2ae798a, 52821bd, 8caa79e, adcf4a7). Forcing the single base c412377 (`git merge-tree --merge-base=c412377 ...`) reproduces GitHub's conflicts in `.github/workflows/check.yml`, `scripts/aitools-install.{sh,ps1}`, `scripts/aitools-lib.sh`, `scripts/build-deploy.sh` and `tests/hookin/{test-hookin.sh,hookin-driver.ps1}`. These are phantom conflicts: the ort result equals main.
- **Fix:** give the branch a single merge base with main by merging main in, then push.
  - The worktree `fo-size` already has this commit: **d9bdfd0**, a no-ff merge of origin/main 727a3f7 into 1d37d93. It is **ahead** of origin by 57 commits (1 merge + 56 main commits) and **behind by 0**, so pushing it is a fast-forward. It is **not pushed**. I did not push it (review only).
  - With d9bdfd0, the merge base is the single commit 727a3f7, and `git merge-tree --merge-base=727a3f7 origin/main d9bdfd0` gives tree `0314ad90` = main, with no conflicts.
  - Option A (simplest): push d9bdfd0 as it is (fast-forward); main has moved to 86a0ea8 since, but the merge stays clean.
  - Option B: in `fo-size`, `git merge --no-ff origin/main` (now 2a505c4; clean, since #120 does not touch `plans/`), then push.
  - Either way, wait for CI on the new head. Then a reviewer re-checks the final SHA (the diff against main must still be empty), and only then the merge commit.
- The worktree `fo-size` is clean (`git status --short` is empty).

## Correctness against current main

- `git diff origin/main origin/feature/fanout-size-warn -- scripts/build-deploy.sh tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`: the test file is identical. In `build-deploy.sh` the only difference is main's newer incident #86 backup and swap code (611396c, PR #131), which the PR head does not have. The trial merge keeps main's version. Nothing of #120 is lost and nothing of main is reverted.
- `git diff origin/main d9bdfd0 -- <same files>`: empty.

## Non-blocking findings

1. **The PR body is stale.** "Why" says the FAIL "breaks `tests/claude-mdm` in CI on the integration base and on every FO branch". That is history now: the change reached main in 1b5ab5d/44a4845. Suggested merge-comment line: "Content already on main as 1b5ab5d/44a4845; this merge closes the PR with an empty merge."
2. **The "Review after" item is answered.** The deploy-harness FAIL-to-WARN change the body asks to confirm was confirmed by the commander on 2026-10-28: "7) accept the deploy-harness" (recorded in `plans/skills-and-rules-fanout.md` section 8 on main 86a0ea8). The merge comment can cite it.
3. **Follow-ups.** Audit 7 is done on main: `reference/script-standards-detail.md`:166 now lists `blog_warn`. Audit 1 is still open: `scripts/aitools`:2115-2116 on main still reports `log_ok "Rebuilt"` and does not count the build's `[warn]` lines. It is not in this PR's scope. Track it under FX/follow-ups.
4. **The GitHub file list is misleading** (45 files, +4777/-531). It is computed against the old c412377 base. The real effect on main is empty.

## Expected conflicts and how to resolve them

- A local `git merge --no-ff origin/main` into 1d37d93 or into d9bdfd0 has none (ort).
- The GitHub merge button on 1d37d93 fails (phantom conflicts, above). Do not resolve those hunks by hand. Push a branch head that has merged main in (d9bdfd0, or a fresh merge of 86a0ea8).

## CI

- On 1d37d93: macos, linux, windows, CodeQL and Analyze (actions, javascript-typescript, python, ruby) are all SUCCESS.
- On main: CI for 727a3f7 is SUCCESS; d9bdfd0's tree is identical to 727a3f7's (`git diff --stat 727a3f7 d9bdfd0` is empty). When I checked, CI for 86a0ea8 was queued and CI for 2a505c4 was in progress. Both results are unknown.
- No check failed.

## Prior reviews (read)

AuditA120 and AuditB120: 0 blocking. Review120 (head 978e72d): APPROVE WITH CHANGES. The fixes are in cdad49f (comment of 2026-10-27T02:58Z). None of them is invalidated by current main.

## What I ran

- `git fetch origin`; `gh pr view 120 --json headRefOid,baseRefName,mergeStateStatus,mergeable,statusCheckRollup,comments,reviews,files`
- `git log`, `git rev-list --left-right --count origin/feature/fanout-size-warn...d9bdfd0` (0 behind, 57 ahead), `git cherry -v`, `git merge-base --all`
- `git diff` (two-dot) on the PR's files, against main and against d9bdfd0
- Trial merge in the detached worktree `.claude/worktrees/m2-rv120`: `git merge --no-ff --no-commit origin/main` (then a2b05d5) was clean, `git diff --cached --stat origin/main` was empty, then `git merge --abort`. After main moved to 86a0ea8 I rechecked with `git merge-tree --write-tree` (tree = main's tree) for 1d37d93 and for d9bdfd0 (with base 727a3f7)
- `git merge-tree --merge-base=c412377` to reproduce GitHub's CONFLICTING

## Not run

- No test suites: the merge result is byte-identical to main's tree, so the suites would test main itself.
- Windows.
- No push and no merge (review only).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
