# S3-MA-FrictionReview verdict on plans/merge-friction-improvements.md

**Version:** v1.0 · **Written:** 2026-10-26 (UTC) · **By:** S3-MA-FrictionReview (independent reviewer, mission MERGE-ALL, Session Commander 10cf255a-c, commander Jose)
**Reviewed:** `plans/merge-friction-improvements.md` v1.0 (untracked in the main checkout, 68,138 bytes, mtime 16:26). I edited it to **v1.1**.
**Against:** `origin/main` adb61ec (`git show origin/main:<path>`, `git grep ... origin/main`), the live GitHub API, and a syntax probe. I did not read the writers' findings files.

## VERDICT: PASS with fixes applied in v1.1

v1.0 is a sound plan. The friction list is backed by evidence, the batches are small and ordered, and most proposed tests and CI steps are concrete. The pinned interfaces are a real improvement.

Ten defects meant that a test or step would not catch what v1.0 claimed, or would conflict with a rule. All ten are fixed in v1.1. Two of them (B1, B3) are in the merge gate, which is the plan's top item.

## Blocking defects (fixed in v1.1)

| # | Where | Defect | Evidence | v1.1 fix |
|---|---|---|---|---|
| B1 | X2, 7.1, section 3 gate test | The gate cannot see stale green. `mergeStateStatus` is CLEAN for a PR far behind main unless strict required checks are on. v1.0's "checks from an older head SHA" condition cannot be computed, because `statusCheckRollup` has no SHA field. The plan's own P1 ("green goes stale") therefore passed the gate | `gh pr view 108 --json statusCheckRollup,mergeStateStatus`: CLEAN, every check from 2026-10-23. `gh api repos/nobul-tech/aitools/compare/main...dbcc61a`: `behind_by: 33`. Rollup fields: `name,status,conclusion,startedAt,completedAt,detailsUrl,workflowName` | A `behind_by` > 0 refusal through the compare API. `--update` re-runs and re-checks. The unobservable condition is dropped. A test fixture for the #108 case |
| B2 | X2 | The check is vacuous on missing checks: "any check is not SUCCESS" passes an empty or partial rollup (#74/#75 had an empty rollup, as the plan itself notes) | P2 row | `REQUIRED_CHECKS` (default `macos,linux,windows`) must all be present. Test case added |
| B3 | X2, X12, 5.5 | Verdicts can be spoofed. The repo is public, so anyone can comment `VERDICT: PASS @ <sha>` and turn the gate or `review/verdict` green | `gh api repos/nobul-tech/aitools` gives `visibility: public` | `VERDICT_AUTHORS` (default `nobul-jose`) in both. Test cases added |
| B4 | X2, X12, 5.5 | "Later commits are channel-only or a merge of origin/main" was undefined. A per-commit or compare file list either counts every file a merge of main brings in, or misses a merge resolution that edits code | design | One definition: `T = git merge-tree --write-tree <verdict> <merge-base(head, origin/main)>`, then `git diff --name-only T <head>` must list only channel paths. A conflict refuses. git 2.54 here (needs 2.38 or later) |
| B5 | D-DEL6 (5.4) with `paths-ignore` (X3) | After a merge whose diff is entirely paths-ignored, main starts no CI run, so "wait for main's CI on the merge SHA" waits forever or misreads "no run" | check.yml design | "No CI expected" when every changed file is ignored. Otherwise poll `gh run list --commit` (bounded) and treat a missing run as an error |
| B6 | X10a / X10b | Ordering bug. X10a's script passed `--require-dotprofile`, which only X10b adds. `build-deploy.sh` parses no arguments and exits 0 on every skip | `build-deploy.sh:86-88, 203-216` | X10a uses the existing "built nothing" guard (`check-pre-push.sh:151-157`). X10b adds the flag |
| B7 | X10a test | "A fixture with a renamed deploy-harness section heading fails" tests the wrong tree. The headings are in `scripts/deploy-harness.sh`, not in the dotprofile fixture | deploy-paths.md ("extract_span, each heading must match one line") | The test renames a heading in a `git archive HEAD` copy of the aitools tree |
| B8 | X4, step 22 | Contradiction. `--check` had to fail on un-ticketed SKIP lines, which means running every suite, yet pre-commit step 22 runs `--check` on every commit | 4.2 step 22, X4 | `--check` is static. The SKIP and XPASS rules are enforced in the `ci` and `local` run modes |
| B9 | Step 23, 5.1 | The versions-not-drafts steering misses Cursor. `.cursor/rules/sources-of-truth.mdc:33-34` carries the same "Draft the change / Present for review" gate, and step 23 did not scan `.cursor/rules`, `CLAUDE.md` or `shared/claude-shared.md` (where R2's line goes). "Ships as a draft" (packet section 4, the source of the R1 template) was not matched | `git grep -i -E "draft the change\|present for review\|ships as a draft" origin/main` | Governed list and patterns widened. "Present for review" is a WARN (glossary.md:144 uses it legitimately). A 5.1 row for the `.mdc`, `tool-lifecycle` and `tool-adopt` sites |
| B10 | X17 | Targets `fedora:latest`, which is not a supported platform | cross-platform.md "Supported platforms and environments" (Ubuntu 24.04, 22.04) | `ubuntu-24.04` and `ubuntu-22.04` matrix, plus one `claude-code-web` environment case |

## Non-blocking (fixed or recorded in v1.1)

- **X9b scope.** A user-level MAINSWITCH in every repo fights the commander's "less worktree overhead": elsewhere, branching in the primary checkout is the normal flow. Changed to opt-in (`git config aitools.pinMainCheckout true`). The comparison now uses absolute paths (`--absolute-git-dir` against `--path-format=absolute --git-common-dir`); plain `--git-dir` can print a relative `.git`. Open question 10 is revised.
- **X6 key.** The known-failures key adds the label: step 2 has two rows, so a step-only key hides both. 7.5 is updated.
- **X7a.** Step 1 hard-codes `Jose <jose@nobul.tech>` and must SKIP in `--ci`. The script parses only `$1 == --fix`, so `--ci` needs argument parsing.
- **X14 / P21.** `check-pre-commit.sh --fix` step 3 runs `build-deploy.sh` against the real HOME, the same hazard as `scripts/githooks/pre-commit`. Added to X14.
- **X3 syntax loop.** `/bin/bash -n` cannot catch bash-4-only run-time constructs (`declare -A`, `mapfile`, `${v,,}`). A lint rule is noted. Probe: 89 tracked `.sh` files pass both shells; `.py` and `.pl` pass.
- **X1.** The `DRAFT` text in `aitools-json.pl:4` and `.ps1:3` is inside protected intent statements. It needs a `Protected-file:` trailer. Whether the commander approved that intent is unknown (new question 11).
- **X2 `--update`.** That `gh pr update-branch` needs `allow_update_branch` (G1) is unverified. Marked; the batch tests it on one PR.
- **X12.** Added the `if: github.event.issue.pull_request` guard and the PR-number source.
- **7.9 (new).** One channel-path file, taken from CLAUDE.md "Channel exception". v1.0 used `.aitools/channel/**` in places, which is wider than the exception.
- **P22 (new).** The main checkout diverged during this review: first ahead 1 and behind 11, then ahead 3. The channel exception's `pull --ff-only` fails for everyone, and nothing warns. X21 (`commit-direct` stops and never merges) and X22 (an ahead/diverged warning) are extended.
- **Section 0** is re-stated against adb61ec. 99740cc was a local, unpushed commit, and 17 PRs are open now (#101 merged).
- **New question 12.** One account means `VERDICT_AUTHORS` blocks outsiders but cannot tell reviewer from author. A separate reviewer identity is the real fix.

## Verified correct (spot checks)

- check.yml: triggers `push`/`pull_request` `branches: [main]` (lines 12-16), no `concurrency`, no `paths-ignore`, jobs `macos`/`linux`/`windows`, 8 test entry files, windows lacks the 4 profile suites, linux runs `check-hook-parity.py`, and the macOS pwsh syntax step uses `2>/dev/null`. All confirmed.
- 12 `tests/**/test-*` files; the 4 not in CI are as listed.
- `check-pre-push.sh:70` `[\s]` (bash) and `.ps1:71` `\s*` are as stated. The X1 test cases match the corrected `[[:space:]]` behaviour (`tokens:` is not flagged; `token = abc` is flagged).
- Step numbers: pre-commit 1-20 (.sh), `.ps1` has no 17-19, pre-push 1-10, post-push 1-7 and 9-32. Reserved numbers 21-27, 11-13 and 33-34 are free.
- `harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh` is 100644, and 2 `shared/hooks/*.bak.2026-06-21T*` files are tracked (both 100755).
- Repo settings: squash and rebase allowed; `allow_auto_merge`, `allow_update_branch` and `delete_branch_on_merge` false; public.
- CodeQL is default setup: three `Analyze (*)` checks plus the aggregate `CodeQL` check (`workflowName` empty). `ALLOW_NEUTRAL=CodeQL` is reasonable.
- `standing-order-guard.sh` has `violation()` and per-check `MODE_*` variables, as X9b assumes.
- `check-lib.sh` `step_fail` receives the step number and label, so X6 is feasible without changing the signature.
- CLAUDE.md "Channel exception" exists on `origin/main`.

## Commit status

I did not commit or push the plan v1.1 or this verdict. CLAUDE.md "Channel exception" says to commit from the main checkout after `git pull --ff-only`, and "if the pull is not a fast-forward, leave the files uncommitted and tell the commander."

- At the start of the review, the pull failed (ahead 1, behind 11).
- At the end, local main was **ahead 3** with unpushed commits from another agent: 99740cc, 57e5b54 and the merge 4cb6379.
- 57e5b54 touches code and rule paths (`scripts/build-package.sh`, `packaging/*`, `tests/build-package/test-cli.sh`, `.claude/rules/deploy-paths.md`). Pushing main would ship them to main without a PR.

The orchestrator or commander must decide what happens to those commits before these two files are committed.

## INCIDENT markers (not filed)

- INCIDENT: local main in the shared checkout holds 57e5b54 (BUILD-PKG review fixes to `scripts/`, `packaging/`, `tests/` and `.claude/rules/deploy-paths.md`) and merge 4cb6379, unpushed. Those are not channel-exception paths. Unless the commander authorised it, this deviates from CLAUDE.md "Channel exception" ("Everything else uses a worktree and a PR"). Any agent that pushes main ships them.
- INCIDENT: `.cursor/rules/sources-of-truth.mdc:33-34` keeps the pre-write draft gate that deliverable 3 retires in `.claude/rules/sources-of-truth.md`, so the Cursor and Claude rules will disagree.
- INCIDENT: `check-pre-commit.sh --fix` step 3 runs `build-deploy.sh` against the real HOME (packet section 5 forbids that).
