# S3-M3-B8a report: settings and skills (sh) use the one dotprofile resolver

**Intent**: **Purpose**: Record what S3-M3-B8a changed on PR #91, why, how it was verified, the review outcome and the follow-ups. **Scope**: scripts/setup-user-settings.sh, scripts/setup-user-settings.ps1, scripts/setup-user-skills.sh on feature/m3-b8a-consumers (stacked on #80). NOT setup-user-skills.ps1 / setup-user-cursor.* (B8b). NOT check-lib / ait-harvest.py (B8c). NOT build-deploy.sh (B5). NOT aitools-lib.*. **Audience**: S3-M3Lead, Jose.

## Summary
1. **Resolver switch.** The three scripts call `resolve_user_repo_path` / `Resolve-UserRepoPath` instead of reading config.json `userRepoPath`.
   - They capture the rc with no `|| true`, then copy `AITLIB_USER_REPO_PATH` / `$script:AitLibUserRepoPath` into their own variable.
   - They add no ACTION row (the #80 contract).
2. **Resolver error (rc 3)**, per S3-M3Lead's decision:
   - setup-user-settings: `log_error` plus ERROR `claude settings|not synced: dotprofile error`; no sync.
   - setup-user-skills.sh: `log_error` plus ERROR rows for `claude skills` and `cursor skills` (`not deployed: dotprofile error`). Nothing is discovered, deployed or offered for adoption, so shared copies cannot replace deployed dotprofile versions.
3. **Shared-only (rc 1):** today's behaviour stays.
   - settings: `log_warn` plus WARN `not synced: no dotprofile`. The old text was 34 characters, over the 30 limit. The console line now says "details in deploy.log" (review m1).
   - skills: deploys shared skills only.
4. **Tests:** smoke 10/10 under bash 5 and 10/10 under /bin/bash 3.2, including the .ps1 cases under pwsh. The tests/profile and tests/logging suites are green.
5. **Merge gate: merge with or after B5.** Without B5, the generated `deploy/setup-user-settings.*` fails with `resolver missing`, and `aitools` regenerates deploy/ on every run.

## Where the old reads were (before, at 28e0f5b + origin/main)
- `scripts/setup-user-settings.sh:64`: `USER_REPO_PATH=$(read_config_key "$HOME/.aitools/config.json" "userRepoPath") || true`
- `scripts/setup-user-settings.ps1:51`: `ReadConfigKey -File (Join-Path $env:USERPROFILE ".aitools\config.json") -Key "userRepoPath"`
- `scripts/setup-user-skills.sh:48`: the same `read_config_key ... || true`
- The header comments in both settings scripts (line 13) named config.json.

## Commits
- e639df2: the resolver switch.
- The follow-up commit on the same branch:
  - the S3-M3Lead rc 3 decision (skip and count);
  - review m1;
  - this report and the review file.

## Logging audit (commander decision 3), touched paths
- **Suppression:** no `|| true`, `2>/dev/null` or SilentlyContinue is left on the touched paths. The removed `|| true` was the old config read. `resolve_user_repo_path || URP_RC=$?` captures the rc rather than suppressing it.
- **Levels and counters:**
  - rc 3 is `log_error` (counted) plus an ERROR row.
  - rc 1 is `log_warn` (counted) plus a WARN row in settings. Skills logs nothing extra at rc 1, since shared-only is expected.
- **Summary rows on every path:** verified by the smoke cases.
- **Text:** at most 30 characters; "skipped" is avoided because it is the governed menu outcome.
- **No false `deploy failed` row:** skills takes `ERRORS_BEFORE_*` after the resolver runs, and with rc 3 the deploy loops never run.
- **Extraction markers:** intact. The settings body (and with it the resolver call) is extracted into deploy/. In skills, the call sits inside the `skill discovery` block, which build-deploy replaces.

## Verification (macOS; isolated HOMEs under .scratch/session-B8a/)
- **Syntax:** `bash -n` under bash 5 and /bin/bash 3.2; the pwsh parser. All clean.
- **smoke.sh, 10 cases** (none, fixture dotprofile and resolver error, for each script):
  - settings.sh;
  - skills.sh;
  - settings.ps1, run as a guard-stripped copy under pwsh 7 with `AITOOLS_PROFILE_TEST_ANY_OS=1`.
  - Result: 10/10 under bash 5 and under /bin/bash 3.2.
- **Suites:**
  - test-lib: 108/0.
  - test-config: 89/0.
  - test-profile: 319/0.
  - tests/logging: sh 24/0, ps 15/0 (5 skipped).
  - The /bin/bash runs give the same counts as bash 5. The suites probably re-invoke `bash` from PATH, so treat them as bash 5 evidence. The real 3.2 evidence is the smoke run.
- **check-pre-commit:** step 6 fails (known). Steps 3, 5, 7, 9 and 11 warn. Step 20 passes.
- **check-pre-push:** step 7 fails (known: dotprofile deploy/ is stale). Steps 1, 5 and 6 warn.
- **deploy-probe.sh:**
  - build-deploy ran under an isolated HOME into a fixture dotprofile;
  - the generated `deploy/setup-user-settings.sh` then exited 1 with `ERROR|dotprofile|resolver missing`;
  - deploy/ held no `aitools-profile.*`.

## Review
S3-M3-B8a-Review posted https://github.com/nobul-tech/aitools/pull/91#pullrequestreview-5621231196. Its file is S3-M3-B8a-Review-pr91.md in this folder.
- **Verdict:** request changes as a merge gate only; the code is correct in its probes.
- **M1, MDM path broken until B5:** confirmed. `scripts/aitools:1524-1531` runs build-deploy on every run. This is not fixable in my files; it is a merge-with/after-B5 condition, stated in the PR body.
- **m1:** fixed ("details in deploy.log").
- **m2, no committed caller test:** follow-up. I suggest `tests/profile/test-callers.sh`, built from `.scratch/session-B8a/smoke.sh`.
- **n1:** superseded, because skills now writes its own ERROR rows on rc 3.
- **n2:** kept deliberately. The rc 1 row carries no remedy, since shared-only is a legitimate mode; the log line names `aitools user init`.
- **n3, n5:** B5's.
- **n4:** SD-7 working as intended.

## Not run
- **Windows:** setup-user-settings.ps1 on a Windows host.
- **The generated deploy .ps1.**
- **The real HOME.**

## Follow-ups
- **B5:** embed `aitools-profile.sh/.ps1` (plus `aitools-json.pl`), or set `AITOOLS_PROFILE_SH` / `AITOOLS_PROFILE_PS1`, in the generated settings scripts. Also fix the `build-deploy.sh:1015` comment and the L8 PS1 blocks.
- **B8b:** setup-user-skills.ps1 needs the same rc 3 skip, for parity with skills.sh here.
- **Caller regression test** (review m2).

## INCIDENT markers (not filed)
- `INCIDENT:` build-deploy inlines aitools-lib but not its sibling resolver. The scripts/ and MDM paths then split silently, and no check catches it: pre-push step 7 only says "stale". Spec: `.claude/rules/deploy-paths.md` "Two deployment methods must produce equivalent results". Suggested prevention: a post-build smoke run of one generated script. (Raised by S3-M3-B8a-Review; I confirmed it with deploy-probe.sh.)

## Open questions (with suggested answers)
- **Q1. Should rc 3 also suppress the WARN in settings when profile.json is missing?** Not applicable: rc 3 branches first. No change needed.
- **Q2. Should PR #91 merge before B5?** Suggest no: merge B5 first, or both together.
