# S3-MF-Runner-Review: independent review of PR #113

**Reviewer**: S3-MF-Runner-Review (independent; wrote none of this code). **Date**: 2026-10-22.
**Scope**: commits e427e60 and 8967660 on `fix/mf-lib-runner-result` (diff `53bc7b4..origin/fix/mf-lib-runner-result`), reviewed at 8967660 in a detached worktree `.claude/worktrees/mf-runner-review`. Not reviewed: the merged-in heads of #103 and #98, audit findings A-12..A-18.

## Verdict: approve with minors

No blocking or major findings. 0 B, 0 M, 2 m, 5 n.

- No behaviour of the removed private runners is lost at any user-init call site (register, migrate, resolve, hostname). The one deliberate change is that an exit 0/1 without result lines now becomes 2. That case was the bug the lib runner already guarded against, and it now covers the resolvers' own OS-guard / PS-version `exit 1` (aitools-profile.sh:84, aitools-profile.ps1:70, :93).
- Existing lib callers keep their rows, counts and return codes. Every one checks the runner's return before it reads RC (aitools-lib.sh:319, 369, 412, 455, 1071; aitools-lib.ps1:239, 288, 332, 375, 961).
- The flag is placed correctly in both entry points. `--no-machine` and `--machine-id` cannot both be passed: they are an if/elif. Two regression probes show the tests catch both a missing flag and the wrong placement.
- All four test files pass in bash 5 + pwsh and in /bin/bash 3.2 `--bash-only`, and the syntax checks pass.

## Findings

### m1. A failed temp-file removal in user init's resolver calls was a warning and is now a detail line
- Old: `ui_profile_run` removed its stderr capture with `ui_rm_tmp`, which calls `log_warn "could not remove ..."` (scripts/aitools:187-190; old body: `git show e427e60:scripts/aitools`, ~line 230). New: `_aitlib_rm_tmp` calls `log_detail` (scripts/aitools-lib.sh:153-156).
- Effect: if `rm -f` of the temp file fails during user init, WARNINGS stays lower and no console line appears. It is not silent, since deploy.log records it. The author's plan row 9 explains the reason (a warning would promote every lib caller's OK rows, D-TS12), and A-4 suggested this fix. Of everything the old runner did, this is the only behaviour that weakened.
- Suggested fix: none required. Say it in the PR body's Changes section ("user init: temp-file removal failure is now a detail line, as in the lib"), so that S3-M3Finish knows it was a deliberate choice.

### m2. The resolver-override environment variables now reach user init, including the commands that write
- New: user init's resolver comes from `${AITOOLS_PROFILE_SH:-$d/aitools-profile.sh}` / `$env:AITOOLS_PROFILE_PS1` (scripts/aitools-lib.sh:188-189, scripts/aitools-lib.ps1:148), and the bash pwsh branch obeys `AITLIB_PROFILE_VIA_PWSH=1` (aitools-lib.sh:194). Old: user init always used `$repo_path/scripts/aitools-profile.*` and ignored them (old ui_profile_run / Invoke-UiProfile).
- Effect: if a user's shell exports `AITOOLS_PROFILE_SH` (the generated deploy scripts export it inside themselves: scripts/build-deploy.sh:525), user init would run `register` / `migrate`, which write and push profile.json, through that resolver. I found no path today where user init inherits it, because user init is not a child of a deploy script. The risk is low, but neither the `ui_profile_run` comment (scripts/aitools:192-199) nor the `Invoke-UiProfile` comment (scripts/aitools.ps1:804-810) mentions it. The test suites rely on the override, which is fine.
- Suggested fix: add one line to both comments ("AITOOLS_PROFILE_SH / AITOOLS_PROFILE_PS1 override the resolver, as for every lib caller"). Optionally, have user init log a detail line when an override is set. Not blocking.

### n1. The result-line check does not depend on the command
aitools-lib.sh:245-248 and aitools-lib.ps1:178 accept a `via` or a `result` line for any command other than hostname / machine-id. In practice the command decides which one appears: register and migrate print `result` (aitools-profile.sh:1232, 1447), and the others print `via`. The resolver prints all of its tagged lines at once in `finish` (aitools-profile.sh:251-265), so a crash cannot leave a partial result line, and this looseness has no effect today. The comment at aitools-lib.sh:166-169 already documents which command prints which. No change needed.

### n2. A resolver throw now changes the error text of the existing lib wrappers (rows and counts unchanged)
A throw now produces an `error` line (aitools-lib.ps1:163-165; bash pwsh branch aitools-lib.sh:221). `resolve_user_repo_path` therefore logs `dotprofile: aitools-profile user-repo-path threw: ...` instead of `dotprofile: resolver failed (exit 2)` (aitools-lib.sh:337-338). The ERROR row, the ACTION and the counts are identical. The new text is more precise. Strictly, though, it differs from "exactly as before", so it is recorded here.

### n3. The missing-resolver message formats the directory differently in bash and PowerShell (pre-existing)
Bash uses `display_path` (aitools-lib.sh:198, 227) and PS uses the raw `Split-Path -Parent` (aitools-lib.ps1:151). The old private runners differed in the same way, so this PR does not make it worse. The test-lib `run-missing` cases do not show the difference because `$WORK` is outside HOME.

### n4. Git Bash: path arguments are converted only when absolute
The old private runner applied `cygpath -w` to any value after `--profile/--out/--config`. The lib applies it only to values starting with `/` (aitools-lib.sh:207-211). User init never passes a relative path: user_repo_dir is checked to be absolute at scripts/aitools:908-915. No change in behaviour for user init.

### n5. The Windows branch is still unverified
The cygpath / pwsh `-Command` branch is tested only through `AITLIB_PROFILE_VIA_PWSH=1` and a cygpath stub on macOS (aitools-lib.sh:181-183 says so). The old runner's `-File` branch was also UNVERIFIED. This PR does not change the risk, but the new path conversion for `--profile/--out/--config` should be checked on the first real Windows run.

## Case-by-case: removed private runners vs the lib runner (at 8967660)

Old bash = `git show e427e60:scripts/aitools` `ui_profile_run`. Old PS = `git show e427e60:scripts/aitools.ps1` `Invoke-UiProfile`. New = `_aitlib_profile_run` (aitools-lib.sh:184-257) and `Invoke-AitLibProfile` (aitools-lib.ps1:145-187), wrapped by scripts/aitools:200-206 and aitools.ps1:811-816.

| # | Behaviour | Old bash | Old PS | New (both) | Verdict |
|---|---|---|---|---|---|
| 1 | exit 0 with `result`, no `via` (register, migrate) | kept | kept | kept (lib.sh:247, lib.ps1:178) | same; test-lib run-register-result, run-migrate-result, run-real-register/migrate, via-pwsh-* |
| 2 | exit 1 with `result failed` + error | rc 1 | rc 1 | rc 1 | same; run-register-exit1-result |
| 3 | exit 2/3/4 with lines | passed through | passed through | passed through (lib.sh:240 only touches 0/1) | same; run-exit2/3/4 |
| 4 | exit 0/1 without result lines | read as 0/1 | read as 0/1 | 2 + `error` line + detail | deliberate fix; run-silent0/1-register. At the call sites: register -> "register failed" (aitools:490), migrate -> "re-key failed" (aitools:534), resolve -> error logged (aitools:562-567), hostname -> host "" (aitools:721) |
| 5 | hostname: bare value | `host=$UI_PROF_OUT` when rc 0 | `UiProfOut[0]` when rc 0 | non-empty value with exit 0 accepted (lib.sh:243-244, lib.ps1:175-176) | same; run-hostname-stub, run-real-hostname; v1-migrate's "machine1 = other-box" (test-user-init:460) shows the value reaching migrate_profile_v1_to_v2 in both shells |
| 6 | resolver missing | return 1, RC 2, `error resolver aitools-profile.sh not found (dir)` | $false, RC 2, same text | return 1 / $false, RC 2, same text (lib.sh:195-199, 224-228; lib.ps1:149-152); the wrappers ignore the return and read RC | same; run-missing (both), via-pwsh-run-missing |
| 7 | PS throw | n/a | RC 2 + `error aitools-profile CMD threw: MSG` | same, newlines collapsed, plus a detail line; bash pwsh branch prints the same line | same; run-throw, via-pwsh-run-throw |
| 8 | Windows Git Bash path args | cygpath -w after --profile/--out/--config | n/a | after --path/--profile/--out/--config, absolute only | equivalent for user init (n4); via-pwsh-run-path-args |
| 9 | stderr -> deploy.log | detail `aitools-profile CMD: LINE` (ui_log_lines, CR stripped) | detail `aitools-profile CMD: LINE` | same prefix and format (lib.sh:233-237, lib.ps1:170-172) | same |
| 10 | mktemp failure | log_warn | n/a | same log_warn (lib.sh:190-193) | same |
| 11 | temp-file removal failure | log_warn (ui_rm_tmp) | n/a | log_detail (_aitlib_rm_tmp) | changed (m1) |
| 12 | resolver location | $repo_path/scripts | $repoPath/scripts | lib dir = $repo_path/scripts (lib sourced from there: aitools:1467, aitools.ps1:489) or the env override | same unless overridden (m2) |
| 13 | pwsh invocation (Git Bash) | `-File` + argv | in-process | `-Command`, args in env, UTF-8 output | equivalent; UTF-8 is an improvement |
| 14 | Windows detection | `uname -s` MINGW/MSYS/CYGWIN | n/a | `$AITOOLS_PLATFORM = windows` (set from the same uname patterns, lib.sh:36-39) | same |
| 15 | wrapper return value | 1 when missing | $false when missing | always 0 / nothing; every call site discards it (aitools:454, 530, 556, 720; aitools.ps1:1062, 1141, 1167, 1333 `$null =`) | same |

The `|| :` at aitools:203 and the `$null =` at aitools.ps1:814 are commented, and every caller checks the result through UI_PROF_RC / UiProfRc, which is 2 with an error line. This meets the no-silent-failure rule. The result globals are set inside the lib functions only and copied right after the call (contract at aitools-lib.sh:125-131).

## Flag placement (M3-FINISH item 2)

- Bash: `no_machine=true` is set inside `if [ -z "$machine_key" ]` (scripts/aitools:965-974), before the owner-"config" branch clears machine_key (aitools:983-985). At the writer call it is `if machine_key -> --machine-id; elif no_machine -> --no-machine` (aitools:994-995, 1001-1002).
- PS: `$noMachine = $true` in `if (-not $script:UiMachineKey)` (aitools.ps1:1595-1605); `if ($machineKey) MachineId elseif ($noMachine) NoMachine` (aitools.ps1:1629-1630).
- Both flags at once: impossible. They are an if/elif, and no_machine is set only when machine_key is already empty; later code only clears machine_key and never sets it.
- The defensive branch "not this machine's profile" (aitools:986-990, aitools.ps1:1622-1626) clears machine_key without setting the flag. ui_register_flow always sets owner "this" or "config" (register returns owner=this, aitools-profile.sh:1428), so I found no way to reach it. Not a finding.
- Unchanged, as required: `AITOOLS_REGISTER_CACHED_ALIAS_SILENTLY=0` (aitools:143) and Path 3 (aitools:959-962). The diff does not touch either.
- Tests: `unregistered_once` (one `ERROR|machine profile|` row, no "no machine match" row, no writer ACTION, the flag in both shells) for alias-other, unregistered-notty, cached-alias-0 and dirty. Flag plus no "no machine match" for pty-dup-decline. `no_machine_flag no` for alias-new (registered), dirty-registered, and via-config (registered, id undetectable) (test-user-init.sh:288, 311-386, 425-426, 520-521).

## Commands run (all from /Users/new-jose/repos/aitools/.claude/worktrees/mf-runner-review, HOME under `.scratch/session-mfrrev/`)

| Command | Result |
|---|---|
| `bash .scratch/session-mfrrev/run-tests.sh pr` (bash 5.3.15 + pwsh, then `AITOOLS_TEST_BASH=/bin/bash /bin/bash ... --bash-only`, bash 3.2.57) | test-lib 287/0 (baseline 209) and 122/0; test-user-init 229/0 (baseline 200) and 128/0; test-config 269/0 and 174/0; test-profile 689/0 and 498/0 |
| `bash -n` (bash 5 and 3.2) on scripts/aitools-lib.sh, scripts/aitools, tests/profile/test-lib.sh, test-user-init.sh | all rc 0 |
| pwsh Parser.ParseFile on scripts/aitools-lib.ps1, scripts/aitools.ps1 | parse OK |
| Regression probe 1 (`regress.sh`): remove `--no-machine` / `-NoMachine` from both entry points, run test-user-init | 209 passed, 20 failed (alias-other, unregistered-notty, dirty: 2 ERROR rows + "no machine match" + writer ACTION + flag missing; cached-alias-0 and pty-dup-decline: flag missing); files restored |
| Regression probe 2 (`regress2.sh`): pass the flag whenever machine_key is empty at the writer call | 227 passed, 2 failed: `via-config (bash/ps): writer flag --no-machine yes, want no`; files restored |

## Not run

- Windows (Git Bash and native pwsh): no machine available. See n5.
- `scripts/check-pre-commit.sh` / `check-pre-push.sh` (the author's job before push; known pre-existing failures are pre-commit step 6, pre-push step 7, pre-push step 3).
- `build-deploy.sh` (never against the real HOME). The lib is inlined whole (build-deploy.sh:124-146), so `_aitlib_rm_tmp` reaches the generated scripts. I checked this by reading the code; I did not build.
- A user-init test with a missing resolver. The runner case is covered in test-lib only, and the user-init call sites read the same RC and error line.
