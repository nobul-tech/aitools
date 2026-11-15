# e9d6-22 report: split the pre-commit steps 3-10 and post-push deploy-steps suites by platform (v1.0)

Mission e9d6-22-port-check-deploy, delegated by 38dc-13 (e9d6), finished under
38dc-27 (08de) after 38dc-13 ended. Worktree `W` =
`C:\Users\jdpal\repos\aitools\.claude\worktrees\38dc-13`. Nothing committed or pushed
(38dc-27 commits; it holds check.yml).

## Summary

- Each `.sh` harness now runs on macOS and Linux only. It carries the POSIX test-suite guard and tests only the `.sh` check twin.
- The two new `.ps1` harnesses run on Windows with native pwsh. They test only the `.ps1` twin, and no case runs bash.
- Both harnesses of a suite run the same platform-neutral static (perl) cases.
- `.ps1` results: pre-commit 40/0/0 and deploy-steps 10/0/0. Both equal the PR #154 Windows CI lines classified (p) and (n), in the same order (`diff` rc 0).
- `.sh` results: each passes `bash -n`, refuses Git Bash (exit 1, guard message, nothing written), and classifies `posix`. Both `.ps1` classify `win`.
- Mutation proof: 8 mutations (4 per suite). Every one turned PASS lines into FAILs with exit 1, and the real files are byte-identical afterwards.

## Files

| File | Change | SHA-256 (final) |
|---|---|---|
| `tests/check-pre-commit/test-pre-commit-steps3-10.sh` | edited: POSIX guard, .ps1-twin and Windows branches removed, header | `7d4622dd31dc140a4d8a4a1c338a0553372cebab03e995505d55edd9c2a79216` |
| `tests/check-pre-commit/test-pre-commit-steps3-10.ps1` | new (restored after the 08de-01 overwrite, see below) | `5aa8d7c68fe01f6b3a57401b9edf882ec082e94c9b2f18905838cebe230ec29a` |
| `tests/check-post-push/test-post-push-deploy-steps.sh` | edited: same | `e4747db9ecb339ef1022831e717327e8844a4e84f13b54b4ade728a0f5ce6076` |
| `tests/check-post-push/test-post-push-deploy-steps.ps1` | new | `3ef6a3d875f8f90ad4300e4c95227181de0d17ea7526a5674365a605464923c1` |

All four are LF, with 0 CR bytes. The two `.ps1` files are pure ASCII. The `.sh` index modes are unchanged (100755). The new `.ps1` files are untracked, and the committer adds them.

## Baselines

The baselines are the PR #154 run 43655061089 logs, `W\.scratch\session-38dc-13\ci-{windows,linux}-154.log`, extracted with `ci-section.py` to `W\.scratch\session-e9d6-22\ci-{windows,linux}-{precommit,deploysteps}.log`. Windows CI shows 62/0/0 and 19/0/0, and Linux shows 62/0/0 and 19/0/0.

## Classification of every CI line

Key: (s) exercises the `.sh` twin; (p) exercises the `.ps1` twin; (n) platform-neutral (perl text checks, or the fixture HOME check); (x) needs both twins on one host.

### Pre-commit steps 3-10 (62 lines on each OS)

| CI lines (names) | Count | Class | Goes to |
|---|---|---|---|
| `sh: the step 3 and step 10 sections were found`; `sh section --fix: {exit 0, build-deploy.sh was not run (no marker, HOME untouched), nothing staged under deploy/, exactly SKIP 3 and SKIP 10, pointing to check-pre-push step 7, no result advises --fix}`; the same 5 for `sh section (no --fix)` | 11 | s | .sh |
| `sh: the step 6 section was found`; `sh step 6 --fix: {exit 0, deploy/x.sh still 100644 in the index, nothing staged under deploy/, scripts/y.sh repaired to 100755, exactly PASS 6 (fixed)}`; `sh step 6 (no --fix): {exit 0, deploy/x.sh still 100644 ..., nothing staged ..., scripts/y.sh unchanged (100644), exactly FAIL 6, scripts/y.sh only (1 file)}` | 11 | s | .sh |
| the same 22 with `ps1` / `-Fix` | 22 | p | .ps1 |
| `sh static: {no line runs build-deploy, no line stages deploy/, the tracked *.sh listing (step 6) excludes deploy/, no step result advises --fix, the --fix usage line exists and does not say it builds}` | 5 | n | both |
| `ps1 static: {...same 5, -Fix}` | 5 | n | both |
| `run (sh, fix flag): {8 checks}` (Linux, macOS) | 8 | s | .sh |
| `run (ps1, fix flag): {8 checks}` (Windows) | 8 | p | .ps1 |

On Windows, CI ran the 22 (s) section lines in Git Bash. They are gone from Windows now.

- `.ps1` result: 22 p + 10 n + 8 p = **40**. The run log `W\.scratch\session-e9d6-22\precommit-run2.log` is identical, line for line, to the Windows CI lines minus the (s) lines (`diff` rc 0).
- Expected `.sh` result on macOS/Linux: 22 s + 10 n + 8 s = **40**, listed in full in `W\.scratch\session-e9d6-22\exp-sh-precommit.txt`. That is the Linux CI lines 5-26, 49-58 and 76-83 of `ci-linux-precommit.log`, unchanged, then `40 passed, 0 failed, 0 skipped`.

### Post-push deploy steps (19 lines on each OS)

| CI lines | Count | Class | Goes to |
|---|---|---|---|
| `sh: the step 2, 6 and 14 sections were found`; `sh frozen: {exit 0, build-deploy.sh was not run, results are exactly the expected ones}`; `sh sources: {same 3}` | 7 | s | .sh |
| `sh static: no line reads the aitools deploy/` | 1 | n | both |
| `ps1: the step 2, 6 and 14 sections were found`; `ps1 frozen: {3}`; `ps1 sources: {3}` | 7 | p | .ps1 |
| `ps1 static: no line reads the aitools deploy/` | 1 | n | both |
| `twins frozen` / `twins sources: .sh and .ps1 results are identical` | 2 | x | dropped |
| `home: the temporary HOME is unchanged` | 1 | n | both |

The twins lines are dropped because no host may run both twins any more. Parity is kept another way: both harnesses assert the same expected records on the same fixtures. They are `SKIP 2 ...|retired: ...`, `PASS/FAIL 6 Full syntax (.sh)`, `PASS/FAIL 6 Full syntax (.ps1)` and `PASS/FAIL 14 ...`, and the text is identical in both files.

- `.ps1` result, in CI order: `sh static`, 7 p, `ps1 static`, `home` = **10**. The run log `deploysteps-run2.log` equals the Windows CI lines minus (s) and (x) (`diff` rc 0).
- Expected `.sh` result on macOS/Linux = **10** (`exp-sh-deploysteps.txt`): the 7 `sh` lines, `sh static`, `ps1 static`, `home`, then `10 passed, 0 failed, 0 skipped`.
- Without pwsh on macOS or Linux, the `.sh` twin's `require_pwsh` stub records `SKIP 6 Full syntax (.ps1)`. The `.sh` harness expects that SKIP, as before, and the line names stay the same.
- In the Linux CI log the twins label carried no suffix, which shows pwsh was installed there. Whether the macOS runner has pwsh is unknown: I have no macOS log.

## What changed inside the harnesses

### .sh harnesses (macOS/Linux)

- The guard block is copied verbatim from cross-platform.md "Test suites", first after `set -uo pipefail`, and names the `.ps1` twin.
- Removed:
  - `IS_WINDOWS` and `native()` / `cygpath`
  - every `pwsh` run of the `.ps1` twin, with its section cases, `run.ps1`, `STEP_BASH` / `DEPLOY_STEPS_BASH` and `bash_native`
  - the `TEST_RUN_TWIN=ps1` run branch
  - the Windows-only snapshot exclusion `AppData/Local/Microsoft/PowerShell`
  - post-push only: the Windows step-14 CRLF limit and the twins block
- Kept:
  - `PRE_COMMIT_PS1` / `POST_PUSH_PS1`, now read by the static cases only (the static cases read both twins' text)
  - `TEST_RUN_TWIN`: `sh` is the default, any other value skips the run case
  - `AITOOLS_TEST_BASH` and `TEST_KEEP_TMP`
  - the `.sh` twin's `require_pwsh` capability branch
- The headers were rewritten. They quote the commander and name the twin each file tests. The `--help` ranges were updated: lines 2-55 and 2-46.
- bash 3.2: the edits only removed code. No new constructs were added.

### .ps1 harnesses (Windows)

- The guard is verbatim from "Test suites", first after `param` and the `-Help` line. `-Help` prints the header from line 1 (60 and 47 lines; checked).
- Helpers come from `tests/lib/platform-lib.ps1`: `New-TestTempRoot`, `Remove-TestTempRoot`, `Invoke-TestScript`, and `Resolve-TestGitBash` (used only to locate Git's perl, and as the post-push `$bashExe`; see below).
- Sections are cut natively. The logic is the same as the perl range (`-cmatch`, CR removed). The cut is dot-sourced in a child `pwsh -NoProfile -NonInteractive -File` with the same stub step functions as the former `run.ps1`.
- Pre-commit: `$gitBash` in the section is a PowerShell stub (`fake-bash.ps1`), not Git Bash. It writes `$HOME/m6b-build-ran` and `$M6B_MARKER`, so a regressed step 3 that runs `& $gitBash build-deploy.sh` fails the "no marker" check without any bash running. Mutation PC-M4 proves it.
- Post-push: `$bashExe` is the Git Bash from `Resolve-TestGitBash`, because the `.ps1` twin's own step 6 runs `& $bashExe -n` on the fixture `.sh` files.
  - This is product behaviour, not the harness running a `.sh`. Without Git for Windows, both fixtures expect `SKIP 6 Full syntax (.sh)|Git Bash not found`.
- Static cases run the exact perl programs of the `.sh` harness as `perl -n <file.pl> <target>`, with `PERLIO=:perlio` and the program text copied byte for byte.
  - The perl is the one on PATH, else `Git\usr\bin\perl.exe`.
  - Without perl these checks FAIL, never PASS.
- Git fixtures use git.exe with `GIT_CONFIG_GLOBAL` (empty file) and `GIT_CONFIG_NOSYSTEM=1`, as `test-user-init.ps1` and `test-adopt-push.ps1` do. Identity comes from `-c user.name/user.email`.
- Child environments get forward-slash paths for HOME, USERPROFILE, the markers and so on. This matches the CI `cygpath -m` form, a point adopted from 08de-01's note.
- The run case (pre-commit) clones W, copies `scripts/` over the clone, and runs `check-pre-commit.ps1 -Fix` in a child pwsh. It uses a temporary HOME, USERPROFILE, APPDATA, LOCALAPPDATA and AITOOLS_LOG_DIR, and removes the four `AITOOLS_*` overrides.
  - It snapshots HOME and the dotprofile by SHA-256, excluding `.git/` and `AppData/Local/Microsoft/PowerShell/`.
  - It parses `checks.log` with the same regex as the `.sh` harness.

## Verification (Windows; logs in `W\.scratch\session-e9d6-22\`)

| Check | Result | Evidence |
|---|---|---|
| pre-commit `.ps1` run | 40 passed, 0 failed, 0 skipped, exit 0 | `precommit-run2.log` (run 1, before the overwrite, also 40/0/0: `precommit-run1.log`) |
| post-push `.ps1` run | 10/0/0, exit 0 | `deploysteps-run2.log` (and run 1) |
| `.ps1` lines vs CI (p)+(n) | identical, in order (`diff` rc 0; 40 and 10 expected) | `verify-static2.log`, `exp-ps1-*.txt` vs `got-ps1-*.txt` |
| `bash -n` on both `.sh` | rc 0 | `verify-static2.log` |
| refusal runs (`bash tests/.../<suite>.sh` in Git Bash, no spoofing) | rc 1; stdout 0 bytes; stderr is exactly the guard line naming the `.ps1`; `git status --porcelain` line count unchanged (11 before and after, the other agents' files) | `verify-static2.log` |
| `perl tests/os-guards/classify-guards.pl W W/.claude/rules/cross-platform.md <4 files>` | `posix` for both `.sh`, `win` for both `.ps1`, rc 0 | `verify-static2.log` |
| pwsh parser on both `.ps1` | 0 errors | `verify-static2.log` |

### Mutations

`W\.scratch\session-e9d6-22\mutate.ps1` built each mutant as a copy, passed it in through `PRE_COMMIT_PS1` / `POST_PUSH_PS1`, and checked 8 real files byte-identical in `finally`. Output: `mutate.log`.

| Id | Mutation | Exit | FAIL lines (examples) |
|---|---|---|---|
| PC-M1 | pre-fix `448ca00^:scripts/check-pre-commit.ps1`; run case off | 1 | 13: section -Fix no-marker / staged / records; no -Fix records / advice; step 6 -Fix deploy/x.sh mode / staged; step 6 no -Fix; all 5 ps1 static |
| PC-M2 | step 6 pathspec without `':!deploy/'` | 1 | 4: step 6 -Fix deploy/x.sh mode, staged; step 6 no -Fix record; ps1 static listing |
| PC-M3 | step 10 SKIP text "retired: run -Fix; ..." | 1 | 6: section records and advice (both modes), ps1 static advice, run records |
| PC-M4 | step 3 `if ($Fix) { & $gitBash ".../build-deploy.sh" ... }` inserted; run case off | 1 | 2: section -Fix no-marker (the PowerShell stub caught it), ps1 static runs-build-deploy |
| PP-M1 | pre-fix `1536e6b^:scripts/check-post-push.ps1` | 1 | 3: frozen results, sources results, ps1 static |
| PP-M2 | step 14 no longer adds shared/hooks/*.sh | 1 | 1: sources results |
| PP-M3 | step 2 SKIP text "retired: see ..." | 1 | 2: frozen and sources results |
| PP-M4 | step 6 (.ps1) also reads deploy/*.ps1 | 1 | 2: frozen results, ps1 static |

The final line of `mutate.log` reads `byte-identical after the mutation runs: True (8 files)`.

## Not run

- The `.sh` harnesses past their guard. The rule forbids it on Windows, and the macOS/Linux CI jobs are their evidence. The expected lines are listed above.
- macOS `/bin/bash 3.2`, locally.
- CI itself: check.yml is 38dc-27's.
- The run case under PC-M1 and PC-M4 (set with `TEST_RUN_TWIN=none`). In those runs the regressed product would run the fake `build-deploy.sh` in the Git Bash it resolves itself. PC-M3 shows the run case catching a regression.

## Lines

- `WRITE_BLOCKED: Write of C:\Users\jdpal\repos\aitools\.aitools\channel\handoffs\2026-11-14_87795dc3-missions\38dc-13\e9d6-22-report.md (the MAIN checkout; my error, I typed the main-checkout path instead of W) -- "Permission for this action was denied by the Claude Code auto mode classifier. Reason: [Destructive or Unwanted Actions]."` I did not retry that path. The report is at its designated path in W.
- `CONFLICT: prompt "mutation-proof ... restore in a finally, check byte-identical" (in-place mutation) vs user rule concurrent-agents.md (e9d6-21 runs suites in the same worktree and reads the same check scripts) -- resolved by tier 1 (rules record the commander's words): mutants are copies passed through the documented override variables, nothing in the repo is edited, and the finally block verifies 8 real files byte-identical (True).`
- `CONFLICT: 08de-01's note "keep STEP_BASH = Git Bash" (relayed by 38dc-27) vs this prompt "NO case runs a .sh check section or script in Git Bash" -- resolved by tier 2 (the prompt; an agent's note carries no commander authority): $gitBash is a PowerShell stub; PC-M4 shows the "no marker" check still fails on a regression. Its other point, forward-slash env paths, was adopted.`
- `INCIDENT: 08de-01 (38dc-27's delegate) overwrote tests/check-pre-commit/test-pre-commit-steps3-10.ps1, a file assigned to e9d6-22, at about 16:29:06 without reading it (user rule concurrent-agents.md: "Never silently overwrite another agent's work"). 38dc-27 reported it and stopped 08de-01. I detected it through a changed-on-disk notice, read the other version in full (saved by 38dc-27 at W\.scratch\session-38dc-27\08de-01-pre-commit-steps3-10.ps1.tmp), restored mine from context, and re-ran everything above after the restore.` Suggested prevention: a delegation prompt names the files already owned by other running delegates (the /delegate "Assign file ownership" rule).
- No product bug found. scripts/ was not touched.

## Open questions (with suggested answers)

1. **The expected records are duplicated inline in both post-push harnesses.**
   - Suggested: a follow-up moves them to committed golden files, `tests/check-post-push/golden/deploy-steps-{frozen,sources}.rec`, read by `golden_match` / `Test-GoldenMatch` (the platform-lib pattern).
   - This was out of my write scope.
2. **Mission 38dc-23 (removing Git Bash from check-*.ps1) will change the `.ps1` twin's step 6 `.sh` record**, which is currently `PASS/FAIL 6 Full syntax (.sh)` via `& $bashExe -n`.
   - Suggested: 38dc-23 updates `$shFrozen` / `$shSources` in `test-post-push-deploy-steps.ps1` in the same PR, and keeps the `.sh` harness's expectations if the `.sh` twin is unchanged.
   - Until then, parity between the twins on those two lines is only by convention.
3. **The windows job must run both new `.ps1` files with `pwsh -NoProfile -File`, and the macos/linux jobs the `.sh` files** (check-ci-suites.pl).
   - Suggested: 38dc-27 adds the steps to check.yml, which it holds.
4. **Residual CI risk, unverified:** the pre-commit run case clones the checkout with `GIT_CONFIG_NOSYSTEM=1` and an empty global config, so a dubious-ownership check could refuse the clone if the runner's user differs from the checkout owner.
   - Suggested: accept. The same isolation is used by `tests/profile/test-user-init.ps1`, and the clone worked locally from a worktree. The Windows CI run of PR #166 will confirm it.
