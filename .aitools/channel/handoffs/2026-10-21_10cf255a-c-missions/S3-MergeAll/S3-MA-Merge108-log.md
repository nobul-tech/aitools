# S3-MA-Merge108 log: merge PR #108 (v1.0)

**Written:** 2026-10-27 (UTC) · **By:** S3-MA-Merge108, delegate of mission MERGE-ALL

## Result

PR #108 "Fix resolver and JSON engine audit findings A-6..A-9" (fix/mf-audit-profile-json) is merged.
- Merge commit: `5da9b5f03aa38bdee76d9d1c6894fad89cad3372`, mergedAt 2026-10-27T00:58:51Z. It was a merge commit (`--merge`) with `--match-head-commit dbcc61a004b4b584d59191e16b33926e58224771`. The branch was not deleted.
- Main CI run 40429786871: success (windows, macos and linux all success). CodeQL run 40429786882: success.

## Pre-merge checks

1. `gh pr view 108`: OPEN, base main, head dbcc61a, all 8 checks SUCCESS (CI macos/linux/windows run 39894588085; CodeQL). The state was UNKNOWN at first and CLEAN/MERGEABLE when re-queried.
2. Reviews: one review comment, S3-MF-Fix6-Review at b42f9e1. It reported 0 blocking and 4 non-blocking findings (n-1..n-4) and I-5. There were no PR comments. The head moved after the review: `git log b42f9e1..dbcc61a` shows b7d84ed (report), 4999394 (review file) and dbcc61a. dbcc61a is a 3-line test-only fix (it normalises NORM_TMP in bash-only runs, which fixed macOS CI run 39891714493). I read it, and it is CI-proven. Nothing blocking.
3. Conflict check: `git merge-tree --write-tree origin/main origin/fix/mf-audit-profile-json` gave tree 463151d with no conflicts. That is the same tree as the merge commit (`git rev-parse 5da9b5f^{tree}`).
4. Main had moved since the PR's CI ran (#103 and #98 merged). To be careful I ran the suites on the trial-merge tree (git archive of 463151d) before merging. All passed (table below).

## Local suites (isolated HOME and AITOOLS_LOG_DIR under .scratch/session-mg108/; script .scratch/session-mg108/run-suites.sh)

| suite | bash 5 (+pwsh parity) | /bin/bash 3.2 --bash-only |
|---|---|---|
| test-profile | 744/0 | 533/0 |
| test-config | 269/0 | 174/0 |
| test-lib | 209/0 | 92/0 |
| test-user-init | 200/0 | 107/0 |

The results were identical before the merge (trial tree) and after it (main checkout at 5da9b5f, after `pull --ff-only` 602d276..5da9b5f). `bash -n` and `/bin/bash -n` were clean on aitools-profile.sh and test-profile.sh. `perl -c aitools-json.pl` gave syntax OK. The pwsh parser was clean on aitools-profile.ps1 and aitools-json.ps1.

## Not run

- Windows locally (main CI's windows job passed).
- check-pre-commit / check-pre-push: no commits were made.

## Carried open items (from the review, non-blocking)

- n-1: no test reaches `die_internal`.
- n-2: setup-user-config's case-twin refusal shows no ACTION and no reason on the console.
- n-3: Get-WriteErrorText maps only two exception classes.
- n-4 / I-3: protected draft S3-MF-Fix6-drafts/reference/script-standards-detail.md.edit.txt, waiting for a decision (it is a post-merge follow-up under A3).
- INCIDENT (I-5, from the review): no spec covers how the JSON engines treat key case.
- PR #98 review m1 follow-up: split the resolver's "is not v2 or has no profiles" message.
