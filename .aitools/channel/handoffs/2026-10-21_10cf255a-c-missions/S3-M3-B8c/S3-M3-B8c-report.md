# S3-M3-B8c report: check-lib and ait-harvest.py use the one dotprofile answer

**Intent**: **Purpose**: Record what S3-M3-B8c changed, why, how it was verified, and what the independent review found. **Scope**: scripts/check-lib.sh, scripts/check-lib.ps1, scripts/ait-harvest.py on feature/m3-b8c-consumers (PR #90, stacked on #80). NOT setup-user-* (B8a/B8b/Claude), NOT aitools-lib.*, NOT check-pre-push step 7 internals. **Audience**: S3-M3Lead, the reviewer, Jose.

## Summary
1. **check-lib.** `resolve_config` (bash) and `ResolveConfig` (PowerShell) now take the dotprofile from the lib resolver, `resolve_user_repo_path` / `Resolve-UserRepoPath`, following the #80 contract.
2. **ait-harvest.py.** It reads config.json with `utf-8-sig`, so a BOM config no longer disables archiving. Three paths that used to crash now log a warning: UTF-16 config, non-object config, non-string `userRepoPath`. A configured dotprofile that is missing is now a warning, not a detail line.
3. **Tests.**
   - New scratch tests: 12/0 (bash 5 and /bin/bash 3.2, plus pwsh) and 8/8.
   - Negative controls against the old code: 0/12 and 3/8.
   - Every repo suite is green.
4. **PR.** https://github.com/nobul-tech/aitools/pull/90, commit 4b345cc (plus the review-fix commit, see Review).

## Config reads in the three files (before the change)

| File:line | Read |
|---|---|
| scripts/check-lib.sh:152 | `CONFIG_FILE="$HOME/.aitools/config.json"` (path only; check-pre-push step 7 copies the file) |
| scripts/check-lib.sh:157 | `USER_REPO_PATH=$(read_config_key "$CONFIG_FILE" "userRepoPath" 2>/dev/null \|\| true)` -- **replaced** |
| scripts/check-lib.ps1:158 | `$script:ConfigFile = Join-Path $HOME ".aitools/config.json"` (path only) |
| scripts/check-lib.ps1:161 | `ReadConfigKey -File $script:ConfigFile -Key "userRepoPath"` -- **replaced** |
| scripts/ait-harvest.py:201-218 | `read_config_user_repo`: `config_file.read_text(encoding="utf-8")` + `data.get("userRepoPath")` -- **fixed** (the only config.json read; callers at :603 archive and :992 catchup) |

Other reads in ait-harvest.py (`HarvestLock` at :346, the manifest at :736, the `current` file at :769) are files this tool writes itself. They are not config.json, so they were not changed.

## Changes
- **check-lib.sh `resolve_config`:**
  ```bash
  local rc=0
  resolve_user_repo_path || rc=$?
  USER_REPO_PATH="$AITLIB_USER_REPO_PATH"
  ```
  On rc 3 it adds one `log` info line: "dotprofile unresolved (resolver error above) -- dotprofile steps skip as 'not configured'". `CONFIG_FILE` is kept.
- **check-lib.ps1 `ResolveConfig`:**
  ```powershell
  $rc = Resolve-UserRepoPath
  $script:UserRepoPath = $script:AitLibUserRepoPath
  ```
  The rc 3 handling is the same as in bash.
- **Header comments:** they name the new lib function.
- **ait-harvest.py `read_config_user_repo`:**
  - reads with `utf-8-sig`;
  - catches `(OSError, ValueError)`;
  - checks with `isinstance` that the config is a dict and `userRepoPath` is a str;
  - `log_warn` for a missing dotprofile directory;
  - the docstring explains each of these.

## Logging audit (commander decision 3)
- **Sink.** In every check script, `resolve_config` runs after `init-logging` and before `check_log_init`. The resolver's lines therefore go to `~/.aitools/logs/deploy.log` under the init-logging name (`check-pre-push`, ...), not to checks.log. Verified in the test logs.
- **Counters.** `check_log_init` resets `ERRORS` / `WARNINGS` afterwards. That has no effect on a check's result: checks report through PASS/FAIL counts (the bridge pattern).
- **rc 1 (shared-only).** Only a detail line, and no `[error]` in deploy.log (test case `none`). A check does not treat it as an error.
- **rc 3:**
  - the lib writes log_error to the console and deploy.log;
  - it adds an ERROR row only when `AITOOLS_SUMMARY_FILE` exists, which check runs normally do not have;
  - check-lib adds one info line;
  - there is no second error and no ACTION.
- **Suppression.** No new suppression. The old `2>/dev/null || true` in check-lib.sh is gone. `|| rc=$?` captures the code and checks it right away.
- **ait-harvest.** Every path that leaves archiving off now logs at warn or detail. Before, three of them crashed the helper. The shims (session-archive.sh and the others) log a non-zero exit, but the cause never reached ait-harvest.log.

## Verification (macOS; isolated HOMEs via mktemp/tempfile)
- **Syntax:** `bash -n` (bash 5 and /bin/bash 3.2) on check-lib.sh plus the four check scripts, the pwsh parser on check-lib.ps1 / check-pre-push.ps1 / check-pre-commit.ps1, and `python3 -m py_compile`: all clean.
- **`.scratch/session-B8c/test-checklib.sh`:**
  - Cases: config, BOM, none, env, missing env path, stale config -> convention.
  - Drivers copy the check block order; the PS driver runs under `$ErrorActionPreference = "Stop"` with `AITOOLS_PROFILE_TEST_ANY_OS=1`.
  - Results: bash + pwsh 12/0; /bin/bash 3.2 + pwsh 12/0.
  - Negative control against the pre-change scripts (`negative-checklib.sh`): 0/12.
- **`.scratch/session-B8c/test_harvest_bom.py`:**
  - Cases: plain, BOM, UTF-16, list, int path, missing dir, no key, corrupt.
  - Result: 8/8.
  - Old file: 3/8. BOM was rejected; UTF-16, list and int raised UnicodeDecodeError, AttributeError and TypeError; missing dir was detail only.
- **Suites** (`.scratch/session-B8c/suites/`):
  - test-profile 319/0;
  - test-config 89/0;
  - test-lib 108/0 (/bin/bash 3.2 `--bash-only` 44/0);
  - tests/logging: sh 24/0, ps 15/0 (5 skipped).
- **check-pre-commit:** FAIL step 6 (known). WARNs 3, 5, 9 and 11; step 11 found `/Users/new-jose/repos/aitools-nobul-jose` through the resolver.
- **check-pre-push:** FAIL step 7 (known, dotprofile deploy/ stale). WARNs 1, 5 and 6.

## Not run
- **Windows:**
  - check-*.ps1 (OS guard);
  - aitools-profile.ps1 for real;
  - the Git Bash `/c/...` path form, which `USER_REPO_PATH` now takes from `cygpath -u`.
- **Hooks end to end:** SessionEnd and SessionStart with a BOM config.
- **check-post-push and check-prereq-detection:** syntax-checked only, not run.

## Review
S3-M3-B8c-Review reviewed 4b345cc independently. Verdict: request changes, with 0 blockers, 1 major, 4 minors and 3 nits.
- Review on the PR: https://github.com/nobul-tech/aitools/pull/90#pullrequestreview-5621229237
- Review file: S3-M3-B8c-Review-pr90.md in this folder.

What the fix commit did with each finding:
- **M1: fixed.** The finding: check-post-push step 5 could PASS while archiving was off. Its dotprofile now came from convention, scan or env, but ait-harvest reads only config.json.
  - **Fix:** check-lib now also sets `USER_REPO_VIA` / `$script:UserRepoVia`. Step 5 in check-post-push.sh/.ps1 warns "dotprofile found via <via>, not config.json -- sessions not archived; run aitools user init" whenever the via is not `config`.
  - **Scope:** check-post-push.* were not in my file list. I edited them because this change caused the regression, and no parallel mission owns those files.
  - **Verified:**
    - the reviewer's `rv-step5.sh` now gives WARN (was PASS);
    - the real check-post-push gives step 5 PASS (379 archives, via config);
    - test-checklib now also asserts the via: 12/0 under bash 5 and 3.2.
- **m1: fixed.** check-lib cited `reference/user-repo.md "Resolution"`, which does not exist on main; that section is still a draft. It now cites `aitools-profile.sh resolve_user_repo` / `aitools-profile.ps1 Resolve-UserRepo`.
- **m2: not changed.** On rc 3 the skip text still says "not configured" in each caller. The info line from check-lib tells the user that the reason is the resolver error. Changing the callers' skip texts would widen this PR. Suggested follow-up: expose `USER_REPO_RC`.
- **m3: follow-up.** The tests are in scratch only; see Q2.
- **m4: not changed.** These are resolver parity gaps in #80 territory: `~` in config `userRepoPath`, and UTF-16 config.json. See the INCIDENT marker below.
- **n1: fixed.** A falsy non-string `userRepoPath` (`false`, `0`) now gets the non-string warning. New test case `false-path`; the harvest tests are now 9/9.
- **n2: noted.** The Git Bash "Not run" item is moot: every check-*.sh exits at its OS guard on Windows.
- **n3: not changed.** It is pre-existing and inside step 7 (out of scope).

## INCIDENT markers (not filed)
- `INCIDENT:` (from the review, m4) aitools-profile.sh and aitools-profile.ps1 disagree in `user-repo-path` in two cases:
  - **`~` in config `userRepoPath`:** bash falls through to scan; PowerShell returns the literal `~/...` with via=config.
  - **UTF-16 config.json:** bash rejects it; PowerShell reads it.

  Suggest a follow-up on #80 or the re-key PR #86 (owner: S3-M3-Resolver).

## Open questions (with suggested answers)
- **Q1. Should ait-harvest.py use the resolver too (env, convention, scan)?** Suggest not now. It would be a Python-to-bash/pwsh call across languages, and that needs approval under cross-platform.md. Once deploy-harness generates config.json from profile.json (decision 7), config.json `userRepoPath` is already the resolver's answer.
- **Q2. Promote the scratch tests into tests/?** Suggest yes, in a later batch: `tests/profile/test-checklib.sh` and a new `tests/harvest/`, both run in CI.
- **Q3. H5 for B5:** once build-deploy uses the resolver, check-pre-push step 7 must pass `AITOOLS_USER_REPO_PATH=<temp copy>` and unset `AITOOLS_PROFILE_FILE` / `AITOOLS_MACHINE_ALIAS`. Suggest that S3-M3-B5 owns it, since it is not safe to leave until later. At this head build-deploy reads config.json directly, so step 7 is still safe.

## Delegates used
- S3-M3-B8c-Review (general-purpose, no isolation): independent review, posted on PR #90.
