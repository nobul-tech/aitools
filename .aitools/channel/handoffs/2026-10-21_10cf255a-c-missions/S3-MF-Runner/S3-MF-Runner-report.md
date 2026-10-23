# S3-MF-Runner report: lib runner accepts "result" lines; user init uses it and passes --no-machine

**Intent**: **Purpose**: Record what mission S3-MF-Runner shipped (M3-FINISH items 2 and 3), how it was verified and reviewed, and what is left open. **Scope**: scripts/aitools-lib.sh/.ps1 (profile runner), scripts/aitools / aitools.ps1 (user init runner and writer call), tests/profile/test-lib.sh, test-user-init.sh, PR #113. NOT the resolver, setup-user-config, or audit findings A-12..A-18. **Audience**: S3-M3Finish, Jose.

## Summary

- PR: https://github.com/nobul-tech/aitools/pull/113, branch `fix/mf-lib-runner-result` (origin/main + `--no-ff` merges of #103 head 945deb5 and #98 head fae7d62). Merge after #103 and #98.
- Commits: e427e60 (lib runner + test-lib), 8967660 (user init + test-user-init), then review fix m2 (comments), the review file and this report.
- Files changed: scripts/aitools-lib.sh, scripts/aitools-lib.ps1, scripts/aitools, scripts/aitools.ps1, tests/profile/test-lib.sh, tests/profile/test-user-init.sh; plan, review and report in this folder.

## What changed

- Lib runner: exit 0/1 is trusted with a `via` or `result` line; `hostname`/`machine-id` with a non-empty bare value; otherwise rewritten to 2 + `error` line (as before). Missing resolver: RC 2 + `error` line naming it (runner still returns 1). Throw: RC 2 + `error` line `aitools-profile CMD threw: MSG` (PS in-process and the bash pwsh branch). Git Bash branch converts `--profile/--out/--config` as well as `--path`. Temp-file removal checked (`_aitlib_rm_tmp`, detail line; runner part of audit A-4).
- User init: `ui_profile_run` / `Invoke-UiProfile` call the lib runner and copy its results; call sites unchanged. `--no-machine` / `-NoMachine` set in the "not registered" block (scripts/aitools user_init, aitools.ps1 Invoke-UserInitCommand), never from an empty key at the writer call (owner "config" keeps no flag).
- Case-by-case comparison with the removed private runners: S3-MF-Runner-plan.md section 1.

## Verification (macOS arm64, isolated HOME under .scratch/session-mfrunner)

| test | before | after |
|---|---|---|
| test-lib.sh (bash 5 + pwsh) | 209/0 | 287/0 |
| test-lib.sh --bash-only, /bin/bash 3.2 | -- | 122/0 |
| test-user-init.sh (bash 5 + pwsh) | 200/0 | 229/0 |
| test-user-init.sh --bash-only, /bin/bash 3.2 | -- | 128/0 |
| test-config.sh | 269/0 | 269/0 |
| test-profile.sh | 689/0 | 689/0 |

- Regression proof: the new test-lib against the old lib fails exactly the 24 new-behaviour cases; the new test-user-init against the old entry points fails 20 assertions (2 machine-profile ERROR rows, the writer's `no machine match` row and ACTION, no flag).
- `bash -n` (bash 5, /bin/bash 3.2) and the pwsh parser on all six touched scripts: clean.
- check-pre-commit: 1 FAIL step 6 (known: harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh is 100644); step 11 WARN (live dotprofile has uncommitted changes, not touched). check-pre-push under an isolated HOME: 0 FAIL, 4 advisory WARNs.
- CI on 8967660: CodeQL, Analyze (actions, javascript-typescript, python), linux and windows pass; macos result in the final hand-back (`gh pr checks 113`).

## Not run

- Windows / Git Bash (cygpath conversion, MSYS translation UNVERIFIED; tested via the forced pwsh branch and a cygpath stub).
- claude-code-web environment.
- build-deploy.sh against the real dotprofile (the generated deploy/ picks up the lib change on the next build).

## Review

- Reviewer: S3-MF-Runner-Review (independent general-purpose agent, no isolation, its own detached worktree). Verdict: **approve with minors**, 0 B / 0 M / 2 m / 5 n. Comment: https://github.com/nobul-tech/aitools/pull/113#issuecomment-6356654462. File: S3-MF-Runner-Review-pr113.md (this folder).
- The reviewer reran all four suites (same counts; also test-config 174/0 and test-profile 498/0 under /bin/bash 3.2) and ran two regression probes: without the flag, 20 failures; with the flag keyed on an empty key at the writer call, 2 failures (via-config).
- m1 (a failed temp-file removal in user init is now a detail line, not a warning): deliberate; stated in the PR body.
- m2 (the AITOOLS_PROFILE_SH/PS1 overrides now reach user init): documented in both wrapper comments (commit 3, comments only).
- n1-n5: no change needed. n5 (Windows unverified) stays a follow-up for the first real Windows run.
- Spot-checked one reviewer claim: aitools-profile.sh:81-84 OS guard exits 1 with no result lines, so case 4 now reads it as an error.

## Observations for follow-up

- A registered machine whose refresh `register` fails also ends with an empty key and gets the flag; the writer then keeps machineId as it is. The run already exits 1 with an ERROR row. Suggest leaving it.
- FIX-1 keeps A-2, A-3 and A-4's `run_child_relayed` part; FIX-2 keeps A-12..A-15 (not made worse here).

## WRITE_BLOCKED

None. (One inline Perl edit was refused by the standing-order-guard hook as a long inline command; it was rerun as a scratch script, which is the hook's prescribed path, not a workaround of a denial.)

## INCIDENT markers (not filed)

None new.

## Delegates

- S3-MF-Runner-Review (general-purpose, no isolation, own detached worktree .claude/worktrees/mf-runner-review).
