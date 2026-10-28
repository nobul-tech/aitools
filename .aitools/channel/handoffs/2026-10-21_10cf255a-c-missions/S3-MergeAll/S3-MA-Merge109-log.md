# S3-MA-Merge109 log: PR #109 merge

**Version:** v1.0 · **Date:** 2026-10-27 (UTC) · **By:** S3-MA-Merge109 (delegate of mission MERGE-ALL)

## Result

PR #109 (fix/mf-audit-consumers, "Fix B8 consumer rows on a dotprofile resolver error") is MERGED.
Merge commit: 91d06b70b36b30d8aeffa134731a71f3b0162be5 (`gh pr merge 109 --merge --match-head-commit 34f5d40`), at 2026-10-27T02:07:37Z. The branch was kept.

## Steps

1. Pre-check: OPEN, base main, MERGEABLE/CLEAN. The checks were green but ran 2026-10-23 on 1692959. `gh api compare main...fix/mf-audit-consumers` showed the branch 77 commits behind main.
2. Reviews: one comment, S3-MF-Fix4-Review at e9fd2ae: "APPROVE-equivalent. No blocking findings." The only commit after it, 1692959, applies review notes n-2 and n-4 (a check-lib.ps1 helper rename and a comment fix) and adds the reports. No unresolved BLOCKING findings.
3. Brought the branch up to date so CI would test the merged tree. In worktree .claude/worktrees/mf-fix4 (status clean), I ran `git merge --no-edit origin/main` at 42ed67e. The merge was clean: main's 77 commits touch none of the PR's scripts (only other tests/ files). Pushed 1692959..34f5d40 with no rebase and no force-push. Explained on the PR in issuecomment-6431790980.
4. Local tests before the push: `/bin/bash tests/b8-consumers/test-b8-consumers.sh` gave 60 passed, 0 failed. Each case runs under its own temp HOME (test header line 11, env HOME= lines 79/86/191/194). `bash -n` (/bin/bash 3.2) and the pwsh parser are clean on all 7 touched scripts.
5. PR CI at 34f5d40 passed: CI run 40435281015 (linux, macos, windows) and CodeQL run 40435278077 (actions, js-ts, python, ruby) plus the CodeQL check. The state was MERGEABLE/CLEAN, then I merged.
6. Post-merge: main CI run 40436615831 for 91d06b7 passed (windows, macos, linux) and CodeQL run 40436615123 passed. In the main checkout, `pull --ff-only` (42ed67e..91d06b7) was followed by the same test (60/0) and the same syntax checks (all OK). `git status -- scripts tests` was clean afterwards.

## Not run

Windows local, which is covered only by CI's windows job. pre-commit and pre-push were not run: the push was a merge of main with no new content.

## Follow-ups

- INCIDENT: tests/b8-consumers/test-b8-consumers.sh is not in .github/workflows/check.yml. A grep for "tests/" in check.yml lists logging, managed-files and profile only, so CI does not run PR #109's 60-assertion regression test. Candidate for plans/merge-friction-improvements.md: a CI step that runs every tests/**/test-*.sh, or an audit that fails when a test file is not wired into check.yml.
- Friction: the PR's green checks were 3 days and 77 commits stale while GitHub still reported CLEAN. Branch protection does not require branches to be up to date, so CLEAN alone does not prove that the merged tree was tested.
