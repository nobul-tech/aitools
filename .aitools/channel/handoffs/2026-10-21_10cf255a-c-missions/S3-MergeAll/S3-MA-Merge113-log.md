# S3-MA-Merge113 log: PR #113 merge

**Version:** v1.0 · **Date:** 2026-10-27 (UTC) · **By:** S3-MA-Merge113 (delegate of mission MERGE-ALL)

## Result

PR #113 (fix/mf-lib-runner-result, "Lib profile runner accepts result lines; user init uses it and passes --no-machine") is MERGED.
- Merge commit: c14d6f095ccd81094e6bda9faba78e0df0cc9e98, made with `gh pr merge 113 --merge --match-head-commit dc64dbb5`, at 2026-10-27T02:39:48Z.
- The branch was kept.

## Steps

1. **Pre-check.** The PR was OPEN with base main. Mergeable and the merge state were UNKNOWN. The checks were green but had run on 2026-10-23 at 2419d23. `git rev-list --left-right --count origin/main...origin/fix/mf-lib-runner-result` gave 76 behind and 5 ahead. The stacked predecessors #103 and #98 had already merged (`gh pr list --state all`).
2. **Reviews.** There is one comment: S3-MF-Runner-Review at 8967660, "approve with minors", 0 B, 0 M, 2 m, 5 n. The only commit after it is 2419d23, which documents the resolver override (m2) and adds the review and report. There are no unresolved BLOCKING findings.
3. **Bringing the branch up to date.** This followed the #109 precedent, so that CI would test the merged tree.
   - The worktree `.claude/worktrees/mf-runner` was clean.
   - I ran `git merge --no-edit origin/main` there at 91d06b7. The merge was clean: only `scripts/aitools-lib.ps1` needed an auto-merge.
   - I pushed 2419d23..dc64dbb with no rebase and no force-push, and explained it on the PR in issuecomment-6432216425.
4. **Local tests at dc64dbb, before the push.** Each suite ran under its own temp HOME in `.claude/worktrees/mf-runner/.scratch/session-ma113/` (script `run-suites.sh`).

   | Suite | bash 5 + pwsh | /bin/bash 3.2 `--bash-only` |
   |---|---|---|
   | tests/profile/test-lib | 287/0 | 122/0 |
   | tests/profile/test-user-init | 229/0 | 128/0 |
   | tests/profile/test-config | 319/0 | 208/0 |
   | tests/profile/test-profile | 763/0 | 546/0 |

   - tests/managed-files/test-adopt-push: .sh 28/0, .ps1 23/0.
   - `bash -n` (bash 5 and 3.2) is OK on all 8 touched bash files, and the pwsh parser is OK on all 5 touched .ps1 files.
5. **PR CI at dc64dbb.** All checks passed:
   - CI run 40438422265: linux, macos and windows.
   - CodeQL run 40438419493: actions, javascript-typescript, python and ruby, plus the CodeQL check.

   The state was then MERGEABLE/CLEAN, and I merged.
6. **Post-merge.**
   - Main CI run 40439732782 for c14d6f0 passed: linux 9m59s, macos 9m58s, windows 1m18s. CodeQL run 40439731696 also passed.
   - In the main checkout I ran `pull --ff-only` (91d06b7..c14d6f0), then the same suites with identical counts (all 0 failed) and the same syntax checks (all OK).
   - Afterwards, `git status --short -- scripts tests` was clean.

## Not run

- Windows local runs. The windows CI job covers Windows, but it runs no profile, user-init or lib-wrapper suites (see the job step list in run 40439732782). The review's n5 still stands: the Git Bash cygpath/pwsh branch is unverified.
- pre-commit and pre-push. The push was a merge of main with no new content.

## Follow-ups

- Friction (same as #109): the PR's checks were 4 days and 76 commits stale. Branch protection does not require branches to be up to date, so CLEAN alone does not prove that the merged tree was tested. Candidate for plans/merge-friction-improvements.md: require up-to-date branches, or a merge-queue equivalent.
- INCIDENT: the windows CI job does not run tests/profile/test-lib.sh or test-user-init.sh, so the Windows path-conversion branch that PR #113 changed is never exercised in CI.
