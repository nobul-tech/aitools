# e9d6-15-port-install report: tests/profile/test-install -- Windows .ps1 harness

Version 1.0 (2026-11-14). Author: e9d6-15-port-install (delegated by 38dc-13-windows-ci-ps1-only).
Worktree W = C:\Users\jdpal\repos\aitools\.claude\worktrees\38dc-13. Nothing committed (scope: no git writes).

## Summary

- New `tests/profile/test-install.ps1`: the Windows harness, native pwsh. It has every case `test-install.sh` ran on Windows (its `ps` branch) and the three bash-only skip lines, with the same check names in the same order. The suite has no golden files.
- Local run (CRLF file, as a checkout gives it): 51 ok, 0 FAIL, 3 skip, exit 0. The check lines are identical, in order, to the Windows CI run of `test-install.sh` (run 43632595172: 51 passed, 0 failed). The only difference is the temp path printed in the name of the `step3-relative` check.
- `test-install.sh` now refuses Windows: the contract guard sits right after `set -euo pipefail`. Every Windows branch, helper and `.ps1` stub is removed, and the macOS/Linux behaviour is unchanged.
- Mutation-proved: 4 mutations (an expected value, an environment variable, two ported helpers). Each turned a PASS into a FAIL with exit 1, and the file was restored byte-identical each time.
- Class (c), no Git Bash cases: the suite tests only the PowerShell installer blocks on Windows, so the new harness never runs Git Bash.
- **Action for 38dc-13:** check.yml line 866-869 (Windows job, step "Installer Step 3/5 relay tests (.ps1, native pwsh)") still runs `bash tests/profile/test-install.sh`, which now exits 1 at the guard. It must run `pwsh -NoProfile -File tests/profile/test-install.ps1` (with `shell: pwsh`). That file is outside my scope.

## What Windows-reached code the suite tests

All of it is `scripts/aitools-install.ps1`, the Windows installer run by `aitools install` / `aitools.ps1` (in-process) and by `bootstrap.ps1`. The suite extracts two blocks from it, "install log helpers" (aitools-install.ps1:59-141) and "install log override" (:143-172), and runs them over `scripts/aitools-lib.ps1`.

| Code | Windows-relevant behaviour ported (check-name prefix) |
|---|---|
| `Invoke-ConfigWriter` -> lib `Invoke-ChildRelayed` (Step 5) | a writer warning is counted (`warnings=1`), the writer's own OK row is kept, its lines reach the console and deploy.jsonl (5 records, 1 run_id, 3 child records, 1 child warn) (step5-warn) |
| install log override: `$env:AITOOLS_RUN_ID` set once, exported to the child | the child sees the installer's run id, and every record carries it (step5-runid) |
| relay ERROR row for a writer that dies without a row | 1 error, 1 warning, `ERROR\|aitools config\|script failed (exit 1)`, "Step 5: setup-user-config" on the console (step5-crash) |
| relay dedupe of a writer's own ERROR row | 1 error, no second row (step5-ownrow) |
| lib `Write-JsonlRecord` with deploy.jsonl not writable (A-16) | one warning, "deploy.jsonl: cannot write" printed exactly once, the run reaches the end, the writer still runs (jsonl-blocked) |
| `Resolve-ReposDir` / `Get-AbsoluteReposPath` (Step 3, A-17) | a relative path is resolved against the current directory and created, with no summary row (step3-relative); a path under a file is `REPOS_FAILED`, 1 error, `ERROR\|aitools config\|repos dir not created` (step3-uncreatable) |
| override `Log`/`LogWarn`/`LogError` -> lib `Add-AitLibLogText` (incident #174) | writable deploy.log gets the lines (log-written); deploy.log is a directory (log-blocked) or held open with no sharing (log-locked, Windows only); under `$ErrorActionPreference = "Stop"` inside a try the run goes on, both lines print, both counters count, no exception text appears, and nothing is written while the lock holds |
| `Invoke-RelaySync` (Step 22) | the sync runs (marker), stdout and stderr reach deploy.log (relaysync-ok); its exit code comes back (relaysync-rc); a deploy.log that cannot be written neither skips the sync nor ends the run (relaysync-blocked) |

Bash-only cases (skip lines, as on Windows CI before): log-unwritable (mode 000), step3-unresolvable (chmod 000 dir), step3-prompt (pty).

## Class

Class (c): I wrote the .ps1 equivalent. No case needs Git Bash. The old harness used Git Bash only as a driver for native pwsh and never ran bash product code on Windows. One Windows-reached bash path is not covered, by the old harness or by this one: `aitools-install.sh`'s Windows forward to `aitools-install.ps1` (cross-platform.md exemptions). Open question 1 is about it.

## How the port works (and where it differs from the Git Bash harness)

- The stubs `writer.ps1` and `sync.ps1` and the driver `harness.ps1` are the .sh heredoc texts, verbatim. They are written with LF and no BOM (`WriteLf`), so they match the heredoc output byte for byte even though this file checks out CRLF.
- Each case runs a child `& (Get-Process -Id $PID).Path -NoProfile -NonInteractive -File harness.ps1 ...` through `Invoke-TestScript`. The child starts in `$H` (`-WorkingDirectory`; the .sh did `cd "$H"`), stdin is at EOF, and stdout and stderr go to one file, as the .sh's `> out.txt 2>&1` did.
- HOME, USERPROFILE, AITOOLS_LOG_DIR, AITOOLS_SUMMARY_FILE, WRITER, SYNC and SYNC_MARK are in the mixed form (C:/...), as the Git Bash harness passed them (`cygpath -m`). The temp root comes from `New-TestTempRoot` (long form).
- Removed from each child, because the Git Bash harness inherited them and CI sets none: AITOOLS_ENVIRONMENT, AITOOLS_RUN_ID, AITOOLS_DRY_RUN, AITOOLS_FORCE, AITOOLS_PRESERVE_SUMMARY, AITOOLS_PROFILE_PS1, AITOOLS_USER_REPO_PATH, AITOOLS_SYNC_DEPLOY_LOG, AITOOLS_SUPPRESS_SUMMARY_DISPLAY. AITOOLS_RUN_ID matters most: step5-runid needs the installer block to set it. The list is the `$env:AITOOLS_*` names that aitools-lib.ps1 and aitools-install.ps1 read (grep). MSYS_NO_PATHCONV and MSYS2_ARG_CONV_EXCL are dropped, since no MSYS layer sits between the two pwsh processes.
- `-ReposPath` is passed only when the case has a path. The .sh passed `-ReposPath ""`, which equals the parameter's default. This avoids depending on how pwsh hands an empty argument to a native child (I did not test that).
- `from_native` / `WORK_SPELLINGS` are not ported. They mapped native paths back to the Git Bash spelling so the bash string compare matched. Here every compare is native: step3-relative compares separators and letter case loosely (Windows paths), and keeps the .sh's fallback branch "(absolute, created)" for an 8.3 or long spelling of the temp root.
- `jsonl-check.pl` and the step5-runid perl one-liner are ported as `jsonl_check` and `runid_check`. They split lines on LF (no piece after a final LF, like perl's `<:raw>` + chomp), decode strict UTF-8 and parse with `System.Text.Json.JsonDocument`, which is strict like JSON::PP; ConvertFrom-Json is not used. Native pwsh has no guaranteed perl with JSON::PP. Edge differences that no case reaches:
  - A line whose top level is not an object counts as invalid; perl would die on it.
  - An invalid line in runid_check is named in the FAIL text. Perl died with no output, giving an empty FAIL text.
- `want_sum` drops trailing newlines, as the .sh's `$(...)` did. `want_end` joins all `END` matches. `count_out`, `want_out` and `want_no_out` work per line, as grep/perl did. `want_no_out` is case-sensitive (`-cmatch`), as perl is.
- The pwsh-on-PATH check is kept: the relay-sync stub runs `pwsh` from PATH, the same harness text as before.
- Final line: `51 passed, 0 failed, 3 skipped (windows: ps)`, the contract form. The .sh's Windows run printed `51 passed, 0 failed (windows: ps)`.

## CI vs local

- CI baseline: `python W\.scratch\session-38dc-13\ci-section.py W\.scratch\session-38dc-13\ci-windows-875e957.log tests/profile/test-install.sh` -> `W\.scratch\session-e9d6-15\ci.txt` (51 passed, 0 failed, "(windows: ps)").
- Local: `pwsh -NoProfile -File W\tests\profile\test-install.ps1`. Run once on the LF file (`run.log`) and once on the final CRLF file (`run-crlf.log`); both exited 0.
- The comparison (`W\.scratch\session-e9d6-15\compare.py`: check lines plus the suite header line, difflib) found the two runs identical:

| | ok | FAIL | skip | lines compared |
|---|---|---|---|---|
| CI (test-install.sh, Windows, ps) | 51 | 0 | 3 | 55 |
| local (test-install.ps1, CRLF) | 51 | 0 | 3 | 55 |

- Differing lines (normalized by compare.py, reason given):
  - `ok   step3-relative (ps): /tmp/tmp.jZOStiC1ji/home/repos` (CI) vs `ok   step3-relative (ps): C:\Users\jdpal\AppData\Local\Temp\test-install-dfccc6666dc9\home\repos` (local). The check prints the resolved path. The Git Bash harness mapped pwsh's path back to its own `/tmp/...` spelling; the native harness prints what pwsh returned. The temp root differs on every run in both harnesses anyway.
  - The final count line, in the contract form (above).

## Mutation proofs

Script `W\.scratch\session-e9d6-15\mutate.ps1`, log `mutations.log`, per-run logs `mutation-<x>.log`. Each mutation replaced one exact string in my own `tests/profile/test-install.ps1` (checked to occur exactly once), ran the suite, and restored the original bytes in a `finally`.

| # | Mutation | Check that failed | Suite |
|---|---|---|---|
| a | expected value: step3-uncreatable row `repos dir not created` -> `repos dir not made` | `FAIL step3-uncreatable (ps): summary 'ERROR\|aitools config\|repos dir not created', want '...not made'` | 50 passed, 1 failed; exit 1 |
| b | environment variable: the child's `AITOOLS_LOG_DIR` -> `$H/.aitools/otherlogs` | 8 FAILs, e.g. `step5-warn (ps): deploy.jsonl 'records=0 (no file)'`, `step5-runid (ps): no file`, `jsonl-blocked (ps): ... warnings=1`, `log-written (ps): deploy.log lacks ...` | 43 passed, 8 failed; exit 1 |
| c | ported helper `jsonl_check`: childwarn message `stub warning` -> `stub warnings` | `FAIL step5-warn (ps): deploy.jsonl '... childwarn=0'` | 50 passed, 1 failed; exit 1 |
| d | ported helper `runid_check`: `-ceq $child` -> `-cne $child` | `FAIL step5-runid (ps): ids=48cc1304ccdb child=48cc1304ccdb` | 50 passed, 1 failed; exit 1 |

After every mutation the file was byte-identical to the original: SHA-256 C26C514011EE4609... before and after, all four restores reported byte-identical. The final CRLF verification run came after the mutations.

## Syntax and guard

- `bash -n W/tests/profile/test-install.sh`: no output, exit 0.
- PowerShell parser (`W\.scratch\session-e9d6-15\parse.ps1`, `Parser::ParseFile`) on `test-install.ps1`: parse ok. 441 lines, CRLF (CR=441, LF=441; `git check-attr eol` = crlf), 0 non-ASCII bytes.
- `-Help` prints the 46-line header from its first line (it stops at the first non-comment line, so it needs no line range). The .sh's `--help` range changed from 2-44 to 2-46 (the header grew by two lines).
- Guard (`W\.scratch\session-e9d6-15\guard-check.sh`, one plain `bash W/tests/profile/test-install.sh` in Git Bash):
  - exit 1, stdout 0 bytes;
  - stderr: `This script is for macOS/Linux. On Windows, run tests/profile/test-install.ps1 with pwsh.`;
  - /tmp entries 684 before and 684 after (the guard runs before mktemp);
  - environment: Git Bash 5.3.15(2)-release, BASH_VERSINFO[5]=x86_64-pc-cygwin, uname -s=MINGW64_NT-10.0-26300.
- The .ps1 guard is the contract text verbatim, placed after `param(...)` and the -Help line.
- No temp root left behind: no `test-install-*` under %TEMP% after the runs.

## Files changed

- `tests/profile/test-install.ps1` (new): the Windows harness, CRLF.
- `tests/profile/test-install.sh` (edited, +52 -186):
  - Added the guard after `set -euo pipefail`, before --help and mktemp.
  - Rewrote header lines 2-5 and the platform paragraph (commander quote, which harness runs what), and the `log-*` / `relaysync-*` descriptions (PowerShell parts moved to the .ps1).
  - Changed the `--bash-only` text and the `--help` range to 2-46.
  - Removed:
    - `LANG_RUN`, the pwsh-on-PATH check, `NWORK`/`np`, `WORK_SPELLINGS`, `from_native`;
    - the `writer.ps1`, `sync.ps1` and `harness.ps1` heredocs;
    - the pwsh branch of `run_h` (its unused `impl` local too) and the dead `LOCK_LOG` variable from the bash env line (harness.sh never reads it);
    - the `IMPLS="ps"` switch and the Windows fallback branch of step3-relative;
    - the `LANG_RUN != sh` skip branches of log-unwritable, step3-unresolvable and step3-prompt;
    - the log-locked ps case. Its macOS/Linux skip line `skip log-locked (PowerShell installer only: Windows)` is kept, unconditional.
  - Kept: the platform-lib.sh source (for TEST_PLATFORM in the header and final lines), `--bash-only`, and every bash case and check name.
  - macOS/Linux output is unchanged: the removed branches printed nothing there or were never taken (`LANG_RUN` was always `sh`).
  - bash 3.2: nothing new beyond the guard's `case` and `${BASH_VERSINFO[5]:-}`.
  - Not run past the guard here (forbidden on Windows). The macOS (/bin/bash 3.2 `--bash-only`) and Linux CI jobs are the proof.
- `git -C W status --short tests/profile` after all runs: ` M tests/profile/test-install.sh`, `?? tests/profile/test-install.ps1`, nothing else (e9d6-14's files did not show at that moment). `git -C W diff -- tests/profile/golden`: empty.
- Scratch: `W\.scratch\session-e9d6-15\` (ci.txt, run.log, run-crlf.log, compare.py, parse.ps1, guard-check.sh, guard-std*.txt, mutate.ps1, mutations.log, mutation-*.log, to-crlf.py).

## INCIDENT / CONFLICT / WRITE_BLOCKED

- INCIDENT: none in product code.
- CONFLICT: none.
- WRITE_BLOCKED: none.

## Contract change requests (tests/lib, for 38dc-13)

1. No change needed for this suite. A note for `Invoke-TestScript`: an empty-string element in `-ArgumentList` was avoided here, not tested. If a suite must pass `""` to a child pwsh, a test of that in `test-platform-lib.ps1` would settle it.

## Open questions

1. `aitools-install.sh` forwards to `aitools-install.ps1` on Windows (cross-platform.md "Entry points with Windows branches"). Neither the old Git Bash harness nor this one tests that forward, and the grep in tests/ found no other suite that runs aitools-install.sh. Suggested answer: a small follow-up case in this .ps1 that runs `aitools-install.sh --help` (or a dry-run form, if one is safe under an isolated HOME) with `Resolve-TestGitBash` and checks that it reaches the .ps1. It would add new check lines, so it is outside this port's "same lines as CI" target. Check first that the forward has a mode that writes nothing.
2. Should check.yml's Windows step name stay "Installer Step 3/5 relay tests (.ps1, native pwsh)"? Suggested answer: yes, it is accurate for the new harness. Change only `shell`/`run`.

## New operational learning

- A harness that compares paths natively does not need the Git Bash harness's path mapping (`from_native`, `WORK_SPELLINGS`). Compare case-insensitively with separators normalized instead. That mapping existed only because bash compared strings against its own `/tmp/...` spelling.
- A mutation that points AITOOLS_LOG_DIR elsewhere fails 8 checks at once. That makes it a quick way to prove a suite's log checks read the file the child actually writes.
- A full run of this suite (13 child pwsh runs) finished inside one foreground Bash call (under the ~180 s move-to-background limit; not timed exactly). The 4 mutation runs were run as one background job and finished without trouble.
