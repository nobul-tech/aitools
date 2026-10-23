# S3-M3-LibFix report: PR #80 Review3 fixes (aitools-lib wrappers)

**Intent**: **Purpose**: Record what S3-M3-LibFix changed on PR #80, why, how it was verified, and the final result-name contract. **Scope**: the wrapper section of scripts/aitools-lib.sh and scripts/aitools-lib.ps1, and tests/profile/test-lib.sh, on feature/m3-b2-lib-wrappers. NOT callers. NOT the lib's display or diff code (PR #81). **Audience**: S3-M3Lead, the consumer missions (B4, B6/B7, B8a-c, UserInit), Jose.

## Summary
1. **B1 fixed.** The PowerShell wrapper section has no top-level assignment, so dot-sourcing the lib no longer wipes a caller's `-UserRepoPath`. Verified with Review3's `probe-clobber.ps1` and `probe-urp.sh` (both shells now log `via=argument`), and with a new regression case.
2. **M1 fixed.** Every result global carries the lib prefix: bash `AITLIB_*`, PowerShell `$script:AitLib*`. Private helpers are `_aitlib_*` / `*-AitLib*`. `TOOL_EXC_*` also moved, to `AITLIB_TOOL_EXC_*`, so the rule has no exception.
3. **m1-m4 and the logging audit:**
   - m1: no spurious WARN on unchanged or dry-run records.
   - m3: one ACTION per run.
   - m2: the Git Bash branch passes path args in Windows form and forces UTF-8 output. It is testable on macOS through a forced branch; Windows itself stays UNVERIFIED.
   - m4: `mktemp` is checked.
4. **Tests.** test-lib: 108/0 after the review fixes (72/0 at dae07fe; 40 before). Every other suite: green. The negative control (new tests against the old libs) fails the caller-vars case in both shells.
5. **Commits and PR.** dae07fe (Review3 fixes) plus a second commit (review M1, m1-m3, report), both pushed to origin feature/m3-b2-lib-wrappers. The PR #80 body has a new Contract section.

## Contract (final names, also in the PR #80 body)

| Function | bash | PowerShell |
|---|---|---|
| resolve_user_repo_path / Resolve-UserRepoPath | AITLIB_USER_REPO_PATH, AITLIB_USER_REPO_VIA | $script:AitLibUserRepoPath, $script:AitLibUserRepoVia |
| resolve_machine_profile / Resolve-MachineProfile | AITLIB_MACHINE_ALIAS, AITLIB_MACHINE_VIA, AITLIB_PROFILE_FILE, AITLIB_PROFILE_NAME, AITLIB_PROFILE_COMPANY, AITLIB_IDENTITY_GIT_NAME, AITLIB_IDENTITY_GIT_EMAIL, AITLIB_IDENTITY_GITHUB | $script:AitLibMachineAlias, AitLibMachineVia, AitLibProfileFile, AitLibProfileName, AitLibProfileCompany, AitLibIdentityGitName, AitLibIdentityGitEmail, AitLibIdentityGithub |
| tool_exception_get / Get-ToolException | AITLIB_TOOL_EXC_FOUND, _PLATFORM, _METHOD, _PATH, _DECIDED_AT | return value hashtable (no result variable), $null when unavailable |
| tool_exception_record / Set-ToolException | AITLIB_TOOL_EXC_RESULT (new; created/updated/unchanged/dry-run/refused/failed, never empty after the call), AITLIB_TOOL_EXC_PUSHED | $script:AitLibToolExcResult (new), $script:AitLibToolExcPushed |
| internal | AITLIB_PROFILE_OUT, AITLIB_PROFILE_RC | $script:AitLibProfileOut, $script:AitLibProfileRc |

- **How to read them.** Read a result only after the call. Under `set -u`, a bash result that was never set is an error. Copy it right after the call: `resolve_user_repo_path || rc=$?; USER_REPO_PATH="$AITLIB_USER_REPO_PATH"` / `$rc = Resolve-UserRepoPath; $userRepoPath = $script:AitLibUserRepoPath`.
- **ACTION rows (m3).** The wrapper writes the one ACTION for its failure, once per run, and callers do not add their own. ERROR rows are written on every failing call.
- **Removed.** `$script:AitoolsLibDir`: `$PSScriptRoot` inside a function gives the defining file's directory. Probed in `.scratch/session-LibFix/probe-psroot.ps1`.

## Changes (dae07fe)
- **scripts/aitools-lib.ps1, wrapper section:**
  - renames as above;
  - no top-level assignments;
  - `Write-AitLibActionOnce`;
  - the m1 result check;
  - a guarded `Split-Path` for an empty profileFile.
- **scripts/aitools-lib.sh, wrapper section:**
  - renames as above;
  - no top-level assignments;
  - `_aitlib_action_once` (`grep -qxF` on the summary file);
  - the m1 result check.
- **scripts/aitools-lib.sh, Git Bash branch:**
  - `cygpath -w` on the resolver path and on `--path` values that start with `/`;
  - the args are passed in `AITLIB_PS_ARGS`, one per line, so `pwsh -Command` can set `[Console]::OutputEncoding` to UTF-8 before it calls the resolver;
  - CR is stripped from stderr lines;
  - `AITLIB_PROFILE_VIA_PWSH=1` forces the branch.
- **scripts/aitools-lib.sh, error handling:**
  - a `mktemp` failure is a log_warn, then stderr goes to /dev/null;
  - a `cygpath -u` failure falls back to the input.
- **Section header.** It now carries the contract as a non-intent comment. The intent text is unchanged; it is still awaiting confirmation in the PR.
- **tests/profile/test-lib.sh:** renamed globals, plus new cases:
  - caller-vars-survive (bash vars; PS params `-UserRepoPath -MachineAlias -ProfileFile` and `$profileName`);
  - rmp-nomatch-twice (one ACTION);
  - eset-unchanged and eset-dry-run (no warning);
  - override-missing and override-stub (AITOOLS_PROFILE_SH/PS1);
  - via-pwsh-urp, via-pwsh-rmp-utf8 (José), via-pwsh-eset-refused and via-pwsh-stub.
- **Every PS case** now passes the three B1 params to the driver.

## Logging audit (commander decision 3), wrapper section
- **Levels.**
  - Missing resolver or resolver failure in the resolvers: log_error + ERROR row.
  - Store unavailable (get) or record not saved or not pushed: log_warn + ACTION, with no ERROR row (the tool itself is fine; D-TS12; tree section 8).
  - Everything else is detail.
- **Counters.** log_error and log_warn come from the lib, so ERRORS and WARNINGS are counted. The tests assert the counters.
- **Suppression.**
  - `command -v ... >/dev/null 2>&1`: exempt (existence check with a fallback).
  - `2>"${errf:-/dev/null}"`: /dev/null only after a logged mktemp failure.
  - PS `catch`: logs a detail line and sets rc 99; the caller then logs an error or warning with the exit code.
  - No `|| true` and no empty catch in the section.
- **Deliberate warn, no summary row: tool_exception_get "unavailable".** The warning promotes the caller's OK row to WARN. Documented in the function comment.

## Verification (macOS; isolated HOME = .scratch/session-LibFix/isohome or the tests' mktemp HOMEs)
- **test-lib, after the review fixes:**
  - bash 5 + pwsh: 108/0;
  - /bin/bash 3.2 `--bash-only`: 44/0;
  - /bin/bash 3.2 + pwsh: 108/0.
- **test-lib at dae07fe:** 72/0, 32/0 and 72/0.
- **Other suites:**
  - test-config: 89/0 (3.2: 55/0);
  - test-profile: 319/0 (3.2: 231/0);
  - tests/logging: sh 24/0, ps 15/0 (5 skipped);
  - tests/managed-files: sh 42/0, ps 24/0.
  - Logs: `.scratch/session-LibFix/suites/`.
- **Negative control** (`.scratch/session-LibFix/negative.sh`): the new test-lib against the 18218ce libs gives rc=1.
  - bash: caller-vars-survive fails.
  - PS: `kept=urp:<resolved dotprofile> ... alias:nobul-mac name:Jose`. The lib functions' `$script:` writes clobbered the caller's params.
- **Review3 probes, copied:**
  - `probe-clobber.ps1`, before the fix: `after lib: UserRepoPath=[]`;
  - `probe-clobber.ps1`, after: `UserRepoPath=[/x/aitools-me]`;
  - `probe-urp.sh`: bash and PS both write `.../elsewhere/aitools-newuser`, `via=argument`.
- **Syntax:** `bash -n` (bash 5 and 3.2) and the pwsh parser: clean. `.scratch/session-LibFix/syntax.sh` also checks that no old name and no top-level AitLib/AITLIB assignment is left in the libs.
- **Repo grep for readers of the old names** (`.scratch/session-LibFix/grep-readers.sh`):
  - the only reader of the wrapper globals was tests/profile/test-lib.sh, now switched;
  - the other hits are callers' own variables (setup-user-*, check-lib, build-deploy), which is exactly what the prefix protects.
- **check-pre-commit:**
  - FAIL step 6: known;
  - FAIL step 20: dead refs to `reference/tool-support-decision-tree.md` (lib, profile, the tool-adopt skill) and `scripts/gen-tool-specs.py`; present before dae07fe;
  - WARN step 11: dotprofile dirty, not mine.
- **check-pre-push:**
  - FAIL step 7: known;
  - WARN steps 1, 5 and 6.

## Not run
- **Windows / Git Bash:** the real cygpath conversion, MSYS argument and environment translation, and the console code page. On macOS they are covered only through `AITLIB_PROFILE_VIA_PWSH=1`; the code comment says UNVERIFIED.
- **Callers:** none is switched on this branch.

## Review
S3-M3-LibFix-Review reviewed dae07fe independently and posted its verdict at https://github.com/nobul-tech/aitools/pull/80#pullrequestreview-5620940373.
- **Verdict:** request changes. It was posted as a comment because GitHub refuses request-changes from the PR author's account.
- **Counts:** 0 blockers, 2 majors, 4 minors, 1 nit.
- **Its file:** S3-M3-LibFix-Review-pr80.md, in this folder.

What the second commit (see Changes) did with each finding:
- **M1, the resolver exit code is trusted without output: fixed in both shells.**
  - Exit 0 or 1 without a `via` line now becomes rc 2, with an `error` line. Every resolver command prints `via` on 0 and 1: aitools-profile.sh `cmd_user_repo_path`, `put_head`, `put_exc`, `put_set`.
  - The pwsh `-Command` wrapper catches throws and parse failures (exit 2) and passes `-ExecutionPolicy Bypass`.
  - Tests: silent exit 0 and exit 1 stubs for urp, rmp, eget and eset in both shells; throw and parse stubs in PS in-process and in the forced pwsh branch.
- **M2, the decision tree rev 5 uses the old names: doc fix drafted, not applied.** The file is protected and owned by PR #78. The draft is in S3-M3-LibFix-tree-draft.md and in the PR body.
- **m1: fixed.** `AITLIB_TOOL_EXC_RESULT` / `$script:AitLibToolExcResult` is never empty after the call: refused or failed. A failure (resolver missing, usage error, crash) now gets the ACTION "see deploy.log -- a tool choice (tool exception) was not saved". A refusal keeps "run aitools user init to remember tool choices".
- **m2: fixed.** The PS in-process resolver's `[Console]::Error` is captured (`[Console]::SetError`) and logged as detail lines, as in bash. Probe: `.scratch/session-LibFix/probe-pserr.sh` (console stderr empty, deploy.log has the line).
- **m3: fixed.** `-ExecutionPolicy Bypass` is added, and the `cygpath -w` results are checked (on failure the value is passed unchanged, with a detail line).
- **m4 (tests): partly fixed.**
  - Added: an eget-found case and the resolver-error cases.
  - Not changed: the negative control's bash half fails on unbound names. The reviewer's own probe confirmed the fix is real.
  - Not added: a Windows CI job for test-lib. It would need path-form normalisation in the test, because the PS impl prints Windows paths. Follow-up.
- **Nit: not changed.** Under `set -u`, calling a wrapper with a missing argument aborts the caller. That is a caller bug, and `set -u` surfacing it is intended (cross-platform.md "Hook portability" says the same of `-u`).

## INCIDENT markers (not filed)
- `INCIDENT:` No harness rule covers naming lib result globals or the scope of a dot-sourced PowerShell lib. This repeats Review3's marker; this PR's Contract is the de facto rule. Suggest a paragraph in reference/script-standards-detail.md (protected; draft needed).
- `INCIDENT:` pre-commit step 20 fails on the branch. `reference/tool-support-decision-tree.md` is cited by the lib, the resolver and shared/skills/tool-adopt, but it does not exist in the repo at this head. Neither does `scripts/gen-tool-specs.py`. Verify whether they live on another branch or PR.

## Open questions (with suggested answers)
- **Q1. Should ERROR rows also be deduped per run?** Today "machine profile|no machine match" is written by every script that calls the resolver. Suggest no: each row names a failing step. Revisit if the summary gets noisy once B8 lands.
- **Q2. Is the section intent (adapted R22 text, flagged in the PR) approved?** Suggest yes as written. dae07fe did not change it.

## Delegates used
- S3-M3-LibFix-Review (general-purpose, no isolation): independent review, posted on the PR.
