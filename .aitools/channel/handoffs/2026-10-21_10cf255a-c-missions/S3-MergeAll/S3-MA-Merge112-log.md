# S3-MA-Merge112 log: PR #112 merge

**Version:** v1.0 · **Date:** 2026-10-27 (UTC) · **By:** S3-MA-Merge112 (delegate of mission MERGE-ALL)

## Result

PR #112 (fix/mf-audit-claude-build, "Fix setup-user-claude hostname/dry-run rows and build-deploy embed cleanup, plain build output (A-19, A-20, A-25, A-26 claude)") is MERGED.
- Merge commit: da574182675202a3d7a05659edda102828ab3685, made with `gh pr merge 112 --merge --match-head-commit 9886930c`, at 2026-10-27T03:11:58Z.
- The branch was kept.

## Steps

1. **Pre-check.** The PR was OPEN with base main, MERGEABLE/CLEAN, head 52821bd. Its checks were green but had run on 2026-10-23. `git rev-list --left-right --count origin/main...HEAD` in the worktree gave 86 behind and 5 ahead. The stacked predecessor #103 had already merged (2026-10-27T00:24:59Z, `gh pr list --state all`).
2. **Reviews.** There are two comments from S3-MF-Fix5-Review. The first, at db9ddf8, was CHANGES-REQUESTED (B-1). The re-verification at 18d6646 reads "Updated verdict: APPROVE-equivalent. B-1 is fixed, and so is N-1." The only later commit is 52821bd, which records the re-verification and the report (markdown only). There are no unresolved BLOCKING findings.
3. **Bringing the branch up to date.** This followed the #109/#113 precedent, so that CI would test the merged tree.
   - The worktree `.claude/worktrees/mf-fix5` was clean and tracked origin.
   - I ran `git merge --no-edit origin/main` there. The merge was clean.
   - I pushed 52821bd..9886930 with no rebase and no force-push, and explained it on the PR in issuecomment-6432619800.
4. **Local tests at 9886930, before the push.** Each suite ran under its own temp HOME (script `.claude/worktrees/mf-fix5/.scratch/session-ma112/run-suites.sh`).

   | Suite | Result |
   |---|---|
   | tests/claude-mdm/test-claude-mdm.sh (bash 5) | 34/0 |
   | tests/claude-mdm/test-claude-mdm.sh (/bin/bash 3.2, AITOOLS_TEST_BASH=/bin/bash) | 34/0 |
   | tests/managed-files/test-adopt-push .sh / .ps1 | 28/0, 23/0 |
   | tests/managed-files/test-managed-files .sh / .ps1 | 57/0, 39/0 |

   - `bash -n` (bash 5 and 3.2) is OK on build-deploy.sh, setup-user-claude.sh and test-claude-mdm.sh, and the pwsh parser is OK on setup-user-claude.ps1.
5. **PR CI at 9886930.** All checks passed:
   - CI run 40441431307: linux 10m37s, macos 14m0s, windows 1m21s.
   - CodeQL run 40441426433: actions, javascript-typescript, python and ruby, plus the CodeQL check.

   The state was then MERGEABLE/CLEAN, and I merged.
6. **Post-merge.**
   - Main CI run 40442824033 for da57418 passed: linux 10m31s, macos 14m33s, windows 1m16s. It includes "setup-user-claude dev + MDM tests" (bash 5 and 3.2), "Build deploy scripts" and "Check deploy drift". CodeQL run 40442823861 also passed.
   - In the main checkout I ran `pull --ff-only` (6686c16..da57418), then the same suites with identical counts (all 0 failed) and the same syntax checks (all OK).
   - Afterwards, `git status --short -- scripts tests deploy` was clean.

## Not run

- `scripts/build-deploy.sh` locally. It is not run against the real HOME (packet section 5). CI ran it on all three platforms, along with the deploy drift check.
- Windows local runs. The windows CI job does not run test-claude-mdm.sh. Only the linux and macos jobs do (check.yml).
- pre-commit and pre-push. The push was a merge of main with no new content.

## Follow-ups

- Friction (same as #109 and #113): the PR's checks were 4 days and 86 commits stale while the state was CLEAN. Candidate for plans/merge-friction-improvements.md: require up-to-date branches, or a merge-queue equivalent.
- INCIDENT: the windows CI job does not run tests/claude-mdm/test-claude-mdm.sh. The PowerShell side of setup-user-claude, which this PR changed, is only exercised through pwsh on linux and macos, never on native Windows.
