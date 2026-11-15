# 08de-03 review of PR #166 (v1.2)

**Intent**: **Purpose**: the independent review verdict on PR #166 (nobul-tech/aitools, "Windows CI runs .ps1 test suites only"), with blocking and non-blocking findings, each with file:line and evidence. **Scope**: the PR diff against origin/main at head `cc60a59dcad5915a793eef1fd8a18fac04020f15`: check.yml, check-ci-suites.pl, tests/ci-suites, tests/os-guards, cross-platform.md/.mdc, RELEASE_NOTES, the five check-suite ports, and a sample of the other ports. NOT fixes (the reviewer edited no repo file). NOT an approval or a request for changes through `gh pr review`. **Audience**: 38dc-27 (the author's orchestrator), then the commander.

Version 1.2, 2026-11-14 (v1.0 at cc60a59; v1.1 adds "Re-check at 87f0d31"; v1.2 adds "Re-check at 3fb6b02"). **Current verdict (v1.2): APPROVE-equivalent (no blocking findings).** The verdict below is the v1.0 verdict at cc60a59. Reviewer: 08de-03-review-pr166, delegated by 38dc-27-windows-ci-finish (M6b-Finish, Session Commander 87795dc3). PR comment: https://github.com/nobul-tech/aitools/pull/166#issuecomment-6887485252

## Verdict

**CHANGES NEEDED (2 blocking).** Both blocking findings are fixes to the rule text in `.claude/rules/cross-platform.md` and `.cursor/rules/cross-platform.mdc`. The brief defines "a rule text that contradicts the code" as blocking, so they are listed as blocking.

I found no wrong behaviour, and no case was lost in a port apart from the replaced "twins" comparison (N1). No `.ps1` suite runs outside the windows job, and no guarded `.sh` suite runs inside it. Each check harness I mutated failed.

## Blocking

### B1. The rule says the guard is the first thing after `param`. In every `.ps1` suite the `-Help` handler comes first.

- Rule: `.claude/rules/cross-platform.md:122-123`: "the guard prints to stderr, first thing after `set` / `param`".
- Code: all 34 tracked `tests/*/test-*.ps1` run `if ($Help) { ...; exit 0 }` before the guard. Example: `tests/check-pre-push/test-pre-push-step7.ps1`: `param` at :31, help at :32, guard at :34-37. `tests/bootstrap/test-bootstrap.ps1` defines functions and runs `Resolve-Path` (:46-63) before its guard at :65.
- All 28 `.sh` suites that carry the guard put it first after `set`.
- Evidence: `.scratch/session-08de-03/guard-order.pl` over `git ls-files tests` found 34 `.ps1` suites with the help handler first and 0 `.sh` suites.
- Impact: low. On macOS/Linux, `-Help` prints the help and exits 0 instead of refusing. Still, the rule is false for every `.ps1` suite.
- Fix, either one:
  - Reword the rule: "first thing after `set` / `param` and the help handler".
  - Or move the help line below the guard in the 34 `.ps1` harnesses (and move `test-bootstrap.ps1`'s setup below its guard).

### B2. The rule says every `.sh`/`.ps1` suite pair has "the same cases and golden files". The older twins do not.

- Rule: `.claude/rules/cross-platform.md:118-121` and `.cursor/rules/cross-platform.mdc:68-69`.
- Code: the twins from before this PR share no golden files: `git grep -l -i golden -- tests/managed-files tests/logging tests/menus tests/setup-user-shell tests/relay-outbound` returns nothing. Their case counts also differ (check-call lines, `.sh` / `.ps1`, from `.scratch/session-08de-03/twin-count.pl`):

  | Suite | `.sh` | `.ps1` |
  |---|---|---|
  | test-managed-files | 88 | 56 |
  | test-adopt-push | 28 | 22 |
  | test-setup-user-shell | 23 | 37 |
  | test-menu-choice | 85 | 97 |
  | test-logging | 34 | 36 |

- The PR body's Follow-ups already list "16 + 6 parity gaps between the managed-files twins".
- Fix: limit the sentence to the suites that meet it and name the older twins as known gaps (follow-up). Make the same change in the `.mdc`.

## Non-blocking

1. **N1. The deploy-steps "twins" case is gone.** The pre-port `tests/check-post-push/test-post-push-deploy-steps.sh` (at 8bf15d9) compared the `.sh` and `.ps1` results directly. It is replaced by the same expectations written by hand in both harnesses (`.ps1`:188-199 and the `.sh` `expect` calls). The guarantee holds only while the two copies stay in sync. The PR's golden-file follow-up fixes it.
2. **N2. Two "sh static" cases are skipped silently when the `.sh` path is missing.** In `test-post-push-deploy-steps.ps1:225` and `test-pre-commit-steps3-10.ps1:414`, a missing `.sh` path (an override pointing nowhere) skips the case with no FAIL. The pre-port harness failed "sh: <path> exists", and `test-post-push-step7.ps1:125-126` still does.
3. **N3. `check-ci-suites.pl` does not check that a guarded `.sh` suite has a `.ps1` twin.** The commander asked for it: "windows ci tests should have the equivalent mac/linux .sh script in ps1". Today only `tests/ci-suites/test-check-ci-suites.sh` lacks one, deliberately (linux-only by `%only`).
4. **N4. The `BASH_VERSINFO[5]` guard case is only checked statically** (`tests/os-guards/classify-guards.pl:92`). No run proves it refuses: on Git Bash the `uname` case fires first, and spoofing is forbidden.
5. **N5. Harnesses go green when a tool is missing.** `test-pre-push-step7.ps1:70-81` SKIPs and exits 0 without node or Git Bash, so a runner missing either passes with nothing tested. The pattern is inherited from the `.sh`. `test-os-guards.sh:141-142` FAILs under `CI=true` instead, which is the better pattern.
6. **N6. One count in the PR body is stale.** It reports rules-fanout `.ps1` as 65/0/2. At cc60a59 I get 69/0/2.
7. **N7. I did not verify the commander quotes for two exemptions.** The build-package.sh approval and the helper-module exemption are quoted as relayed by M6-Polish (commit 2331302). I did not check them against the transcript.

## What I ran

All commands ran from the worktree W, with scripts in `W/.scratch/session-08de-03/`.

- **Head.** `git -C W rev-parse HEAD` returned cc60a59dcad5915a793eef1fd8a18fac04020f15. The merge base with origin/main is 8bf15d9. Between 5f962b1 and 8bf15d9 only `test-post-push-deploy-steps.sh` changed, so 8bf15d9 is the pre-port base.
- **Suite placement.** `run-ci-suites.sh` (`git ls-files ... | perl scripts/check-ci-suites.pl --root . .github/workflows/check.yml`) gave "All 71 test suites are in CI on their platforms", exit 0. `bash -n tests/ci-suites/test-check-ci-suites.sh` gave exit 0.
- **Guard scan.** `classify-suites.pl` uses the check's guard regex. It found:
  - 9 unguarded `.sh` suites, all in the exemption table.
  - 28 guarded `.sh` suites, each with a `.ps1` twin except `test-check-ci-suites.sh`.
  - 6 `.ps1`-only suites.
- **Steps per job.** `count-steps.sh`:
  - Windows: 60 steps (34 `bash tests/`, 12 `pwsh tests/`) became 57 steps (9 `bash tests/`, 34 `pwsh tests/`).
  - macOS: 75 steps became 80.
  - Linux: unchanged at 48.
  - These match the PR body.
- **Compliance step.** It is the last step of the linux job (check.yml:711-713) and the windows job (:1136-1139).
- **Windows `.ps1` runs** (pwsh 7.6.10, `run-suite.ps1` / `run-batch.ps1`, `AITOOLS_LOG_DIR` in scratch). All exited 0:

  | Suite | Result (pass/fail/skip) |
  |---|---|
  | os-guards | 68/0/0 |
  | check-pre-push step 7 | 3/0/0 |
  | check-post-push step 7 | 7/0/0 |
  | check-post-push steps 2/6/14 | 10/0/0 |
  | menu parity | 22/0/0 |
  | check-pre-commit 3/10 | 40/0/0 |
  | tests/lib/test-platform-lib | 31/0/0 |
  | b8-consumers | 31/0/0 |
  | skills-legacy | 40/0/0 |
  | rules-fanout | 69/0/2 |
  | deploy-harness | 120/0/0 |

- **Real dotprofile.** The real dotprofile `deploy/` and `deploy.bak.*` directories were not touched: the newest is from 2026-11-14T00:53Z, before this review.
- **Mutation runs** (`mutants.ps1`). Copies in scratch, run through PRE_COMMIT_PS1/SH and POST_PUSH_PS1/SH; no repo file was edited. Every run exited 1:

  | Script under test | Harness | FAILs |
  |---|---|---|
  | pre-fix `check-pre-commit` (846ab24) | steps3-10 | 22 |
  | current `check-pre-commit.ps1`, step 3 changed to run `$gitBash build-deploy.sh` under `-Fix` | steps3-10 | 2 |
  | `check-post-push` before 1536e6b | deploy-steps | 4 |
  | `check-post-push` at 0c667a8 (before step 7 was retired) | step 7 | 4 |
  | current `check-post-push.ps1`, step 7 changed to run `& $bashExe build-deploy.sh` | step 7 | 2 |

- **Case parity** (`case-parity.pl`). I compared check names in the pre-port `.sh` at 8bf15d9 against the new `.sh` plus the new `.ps1` for the 20 ported suites. Only the deploy-steps "twins" case is gone (N1). The other "missing" names are artifacts of my name normalization (`$fx:` became `${fx}:`, and "force: overwrite" was split into `--force` and `-Force`).
- **Guard order:** `guard-order.pl` (B1).
- **RELEASE_NOTES.** `git diff --numstat origin/main -- RELEASE_NOTES.md` gave `22 0`. v0.77.16 sits above v0.77.13, so versions stay in descending order.
- **PR body.** Read with `gh pr view 166`. I checked its claims on step counts, suite count, os-guards and the check-suite results. All match except N6.
- **CI.** `gh pr checks 166` showed linux, macos and windows pending, and CodeQL Analyze (actions) passed with the others pending. I did not wait.

## Not run

- Any `.sh` suite past its guard (Windows; `bash -n` only on test-check-ci-suites.sh).
- macOS/Linux runs.
- These `.ps1` ports: claude-mdm, hookin, profile ×5, fanout-lib, rules-fanout-cursor, skills-fanout, deploy-harness-mdm.
- A mutation test of menu parity (its harness has no override variable for check-post-push.ps1; its planted-mismatch cases already show that the check can fail).
- Checking the commander quotes against the transcript.
- Reading the author's mission reports: not needed to check the claims in the PR body.

## Re-check at 87f0d31 (v1.1)

At 38dc-27's request (PR comment 6887511088), I re-checked B1 and B2 only, on `git diff cc60a59 87f0d31`. Head verified with `gh pr view 166 --json headRefOid` = 87f0d3121c2f756ca8cbe97d6103ced5e341530a. Follow-up PR comment: https://github.com/nobul-tech/aitools/pull/166#issuecomment-6887526163

**Updated verdict: CHANGES NEEDED (1 blocking).** B1 is resolved and B2 is partly resolved.

### B1: resolved

- The rule now reads "first thing after `set` / `param` and, in a `.ps1`, its `-Help` handler" (`.claude/rules/cross-platform.md:126`, `.cursor/rules/cross-platform.mdc:68`).
- `tests/bootstrap/test-bootstrap.ps1` now refuses before its setup: the guard is at :46-49, directly after the help handler at :41-44.
- `.scratch/session-08de-03/pre-guard.pl` scanned all 34 tracked `tests/*/test-*.ps1` for statements between `param(` and the guard, outside the `if ($Help) {...}` block. It found none.
- On Windows (pwsh 7.6.10): `test-bootstrap.ps1` 26/0/0 and `test-os-guards.ps1` 68/0/0. The exemption table still classifies after the rule edit.

### B2: partly resolved, still blocking

- The older twins are now named correctly ("do not yet").
- The new sentence overclaims for the five check-suite ports:
  - `.claude/rules/cross-platform.md:121-123`: "The harnesses ported in 2026-11 (PR #166) have the same cases and compare against the same golden files".
  - `.cursor/rules/cross-platform.mdc:69-70`: "the 2026-11 ports share cases and golden files".
- Evidence: `git grep -l -i golden -- tests/check-pre-push tests/check-post-push tests/check-pre-commit` finds nothing. Golden files exist only in the 15 script-suite ports: b8-consumers, claude-mdm, hookin, profile ×5, fanout-lib, rules-fanout, rules-fanout-cursor, skills-fanout, skills-legacy, deploy-harness, deploy-harness-mdm.
- The check-suite ports hold their expectations in each harness instead (N1).
- Fix: limit the golden-file claim to the script-suite ports, and say the check-suite ports have the same cases with expectations written in each harness (golden files as a follow-up). Make the same change in the `.mdc`.

Non-blocking N1-N7 are unchanged; I did not re-check them.

Note: 87f0d31 also committed this report at v1.0. This v1.1 is a working-tree change only, not committed (as briefed).

## Re-check at 3fb6b02 (v1.2)

At 38dc-27's request, I re-checked B2 only, on `git diff 87f0d31 3fb6b02`. Head verified as 3fb6b02d5e7f5a1158ff60f7f0a615483eba6bc7 (`gh pr view 166 --json headRefOid` and `git rev-parse HEAD`). Follow-up PR comment: https://github.com/nobul-tech/aitools/pull/166#issuecomment-6887545043

**Updated verdict: APPROVE-equivalent (no blocking findings).**

### B2: resolved

- `.claude/rules/cross-platform.md:121-127` and `.cursor/rules/cross-platform.mdc:69-72` now say:
  - the script-suite ports compare against golden files;
  - the check-suite ports (check-pre-push, check-post-push, check-pre-commit) write the same expectations in each harness, with golden files as a follow-up;
  - the older twins do not yet share cases.
- This matches the code: `git grep -l -i golden` finds golden files in all 15 script-suite ports and none under `tests/check-pre-push`, `tests/check-post-push` or `tests/check-pre-commit`.
- `test-os-guards.ps1` still passes 68/0/0 on Windows after the edit; it parses the exemption table of the same file.

### New non-blocking finding N8

I should have raised this at the first re-check.

- "The harnesses ported in 2026-11 have the same cases" is approximate. Each side also has cases for its own platform only. Distinct case names, from my first-pass `case-parity.pl` output:

  | Suite | `.sh` | `.ps1` |
  |---|---|---|
  | deploy-harness | 110 | 120 (Windows-only locked-file and ACL cases) |
  | skills-fanout | 86 | 74 |
  | rules-fanout-cursor | 135 | 122 |
  | fanout-lib | 12 | 9 |

- No pre-port case is lost. I did not classify every per-platform difference.
- Suggested wording: "the same shared cases, plus platform-only cases on each side". Not blocking.

N1-N7 are unchanged and were not re-checked.

This v1.2 is a working-tree change only, not committed (as briefed). 3fb6b02 committed v1.1.

## Signals

- WRITE_BLOCKED: one Write of `C:\Users\jdpal\repos\aitools\.aitools-placeholder-not-used.txt` was a mistaken tool call by me, outside my access and not needed. It was denied: "Permission for this action was denied by the Claude Code auto mode classifier. Reason: [Destructive or Unwanted Actions]." I did not retry it, and nothing depends on it.
- CONFLICT: none.
- INCIDENT: none beyond the findings above (B2 matches the managed-files twin parity gaps the PR already lists as a follow-up).
