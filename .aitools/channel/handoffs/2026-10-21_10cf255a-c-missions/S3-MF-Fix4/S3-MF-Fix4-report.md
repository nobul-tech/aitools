# S3-MF-Fix4 report: audit findings A-22, A-23, A-24, A-26 (cursor part)

**Intent**: **Purpose**: Record what S3-MF-Fix4 changed for S3-MF-Audit findings A-22, A-23, A-24 and the cursor part of A-26, how it was verified, and what is left, so that S3-M3Finish and Jose can review PR #109. **Scope**: The B8 consumer fixes in setup-user-skills, setup-user-cursor and check-lib, and their test. NOT other audit findings. NOT the I-4 decision. **Audience**: S3-M3Finish, Jose.

## Summary
- PR: https://github.com/nobul-tech/aitools/pull/109
- Branch: `fix/mf-audit-consumers`, from origin/main 8a9dcb5.
- All four findings were confirmed in the code and fixed. None was rejected.
- The independent reviewer (S3-MF-Fix4-Review) found no blocking items. Its review: `S3-MF-Fix4-Review-pr109.md`; the same text is posted on the PR at https://github.com/nobul-tech/aitools/pull/109#issuecomment-6356131306.

## Per finding
| id | status | evidence (origin/main → fix) |
|---|---|---|
| A-22 | fixed | Before: setup-user-skills.ps1:44-52 wrote `ERROR\|skills\|skipped (dotprofile error)`, while the .sh (:52-60) wrote two rows. Now the .ps1 writes the same two rows (`claude skills`, `cursor skills`: "not deployed: dotprofile error") with the same LogError text, and skips discovery as the .sh does. |
| A-23 | fixed | Before: setup-user-cursor.sh:353-358 and .ps1:273-278 wrote an info line and "skipped (dotprofile error)". Now both log an error (`log_error` / `LogError`) and write `ERROR\|cursor cli\|not merged: dotprofile error`. This assumes I-4 = count the error, as setup-user-settings does. |
| A-24 | fixed | check-lib keeps the resolver's return code (`USER_REPO_RC` / `$script:UserRepoRc`). On a resolver error, print_summary / PrintSummary add the counted WARN step "0. Dotprofile resolution" to the console, checks.log and checks.jsonl. The check-*.sh/.ps1 callers are unchanged, because they are outside this mission's file ownership (see follow-ups). |
| A-26 (cursor) | fixed | The cli-config dry run now writes `OK\|cursor cli\|dry-run: would update`, or `OK\|cursor cli\|verified` when the file is up to date, in both languages. Before, the .sh wrote no row for would-merge, and the .ps1 wrote no dry-run row at all. |

## Verification (macOS)
- Syntax: `bash -n` (bash 5 and /bin/bash 3.2) and the pwsh parser on every touched file: clean. Re-run after the review tweaks: clean.
- tests/b8-consumers/test-b8-consumers.sh (new): 60/0 under bash 5 and 60/0 under /bin/bash 3.2. Run against the unfixed scripts, 24 of its checks fail.
- Existing suites, run under an isolated HOME, with bash 5 and 3.2:

  | suite | result (both bash versions) |
  |---|---|
  | profile | 689/0 |
  | lib | 209/0 |
  | config | 190/0 |
  | user-init | 200/0 |
  | rules-fanout-cursor | 78/0, 1 skip |
  | logging | 24/0 |
  | deploy-harness | 45/0 |
  | deploy-harness-mdm | 30/0 |

- check-pre-commit: 1 FAIL, which is the known step 6. check-pre-push: 1 FAIL, which is the known step 7 (stale dotprofile deploy/).
- After review: helper renamed from `Write-DotprofileResolutionStep` to `StepDotprofileResolution` (n-2); comment wording corrected (n-4). The new suite is green again.

## Not run
- Windows / Git Bash. The .ps1 files ran only as guard-stripped copies under pwsh 7.
- build-deploy against the live dotprofile, which stayed read-only.

## Follow-ups
- Regenerate the dotprofile deploy/ after merge. The cursor body is extracted whole, so no build-deploy.sh logic port is needed (the reviewer confirmed this against build-deploy.sh:835-907).
- A-24 caller skip texts: when the rc is 3, say "dotprofile unresolved" in pre-commit 11, pre-push 7 and 10, and post-push 5.
- The new suite and rules-fanout-cursor are not in CI (review n-5).
- INCIDENT: setup-user-cursor.sh:186 "node not found" log_warn has no summary row (summary coverage rule). Not filed.

## WRITE_BLOCKED
None.

## Open questions
- I-4: should a consumer re-count a resolver error that the lib already counted? Suggested answer: yes. That is the current behaviour in settings, skills and cursor; the step really did fail.
