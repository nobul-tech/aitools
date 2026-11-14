# e9d6-09-port-config report (v1.0)

Mission: Windows .ps1 harness for tests/profile/test-config.sh; the .sh harness
becomes macOS/Linux-only. Delegate e9d6-09, for 38dc-13. Date 2026-11-14.
Worktree W = `C:\Users\jdpal\repos\aitools\.claude\worktrees\38dc-13`.

## Summary

1. New `tests/profile/test-config.ps1` (native pwsh, Windows only): 247 passed, 0 failed, 1 skipped locally, the same counts as the .sh harness's Windows CI run on main (247/0/1).
2. The 248 ok/skip lines match CI in name and order. 2 lines differ, both only in a path printed in the check name (temp root; drive root vs Git Bash "/").
3. `tests/profile/test-config.sh`: the exact contract OS guard was added, and the dead ps1/Windows branches and helpers were removed. The macOS/Linux cases, check names and output are unchanged, `--bash-only` still works, and the script stays bash 3.2 compatible.
4. Mutation-proved 3 ways (golden line, expected exit code, case environment): each turned the named PASS into a FAIL with exit 1, and every file was restored. `git diff -- tests/profile/golden` is empty.
5. No product change and no Git Bash case needed. One harness weakness (vacuous JSON check in the .sh) is reported, not changed.

## Windows-reached code this suite tests

| Script (W\scripts\) | What runs |
|---|---|
| `setup-user-config.ps1` | the config.json writer, child pwsh, all cases c1-c24, c12, c22j (`-Help`) |
| `aitools-profile.ps1` | `derive-config`, in-process from the writer: Resolve-UserRepo, Resolve-Machine, Find-MachineId (test override), Find-Hostname (test override) |
| `aitools-json.ps1` | Read-JsonFile, Set-JValue (case-twin refusal), ConvertTo-NodeJson |
| `aitools-lib.ps1` | Initialize-Logging, Log*/Write-Summary (OK->WARN promotion), Backup-File, Write-JsonlRecord, Invoke-ChildRelayed, Send-AitLibChildLine |
| `aitools-install.ps1` "install log helpers" block | Get-AbsoluteReposPath (Step 3), Invoke-ConfigWriter (Step 5), extracted and run by the suite's inst-harness.ps1 |

I read in full: setup-user-config.ps1, aitools-json.ps1, the helper block of aitools-install.ps1 (lines 1-130), and aitools-profile.ps1 lines 1-899, 1000-1089 and 1385-1405. I did not read aitools-profile.ps1 lines 900-999 and 1090-1384 (exception-set, register, migrate: not called by this suite). From aitools-lib.ps1 I read lines 1-240, 440-730, 850-930 and 2125-2175, and grepped every `$env:` read.

## Windows-relevant behaviours ported, by name

| # | Behaviour | Cases | How the .ps1 harness does it |
|---|---|---|---|
| W1 | Long temp path, never the 8.3 short form (PR #139 run 41265193554) | all | `New-TestTempRoot` returns the long form. `$NWORK` is its mixed form (`C:/...`), the form the Git Bash harness passed (`cygpath -m -l`) |
| W2 | Mixed-form paths as HOME / USERPROFILE / -ReposPath / fixture values. Backslash-escaped JSON paths normalized | all | `$H="$NWORK/home"`. `norm_json` is the same rule as the .sh one (CR, `\\`->`/`, NWORK->`<TMP>`, case-insensitive) |
| W3 | Machine id (MachineGuid) is never read from the registry | all | `AITOOLS_PROFILE_TEST_MACHINE_ID` / `_HOSTNAME`, `none` in c19/c21 |
| W4 | PowerShell property names are case-insensitive: a `MachineId` twin is refused with both names | c24 | unchanged case |
| W5 | `-DrivesJson` JSON with quotes and spaces through native argument passing | c9 | passed as one argument (`$PSNativeCommandArgumentPassing` = Windows, pwsh 7.6.10) |
| W6 | Drive-letter absolute answer kept as is (`C:/abs/repos`). A relative answer is resolved against the cwd. A run from a root gives no double separator | Step 3 | the child cwd is set by `Invoke-TestScript -WorkingDirectory` |
| W7 | deploy.jsonl records stay valid JSON with quotes, backslashes and control characters | jsonl, step5 | strict System.Text.Json parse (see below) |
| W8 | Step 5 in-process relay: the writer's warnings are counted once, a failed writer is 1 error, and its ERROR row is kept | step5 | unchanged checks |
| W9 | The dry run merges into the system temp, so ~/.aitools is untouched | c8, c8b, c22l | unchanged checks |
| W10 | `-Help` names `-NoMachine` | c22j | child pwsh `-Help` |

Class (c): a .ps1 equivalent was written. No case needed Git Bash: the suite exercises only the .ps1 writer and the .ps1 helper block, no cross-platform bash code, so `Resolve-TestGitBash` / `ConvertTo-MsysPath` are not used.

### Harness choices

- **Base environment.** Every child gets `$null` for the AITOOLS_* variables that the writer, lib and resolver read: AITOOLS_ENVIRONMENT, _USER_REPO_PATH, _MACHINE_ALIAS, _PROFILE_FILE, _PROFILE_PS1, _DRY_RUN, _FORCE, _RUN_ID, _SUMMARY_FILE, _PRESERVE_SUMMARY and _TEST_UPDATE_GOLDEN. A case then sets its own. CI sets none of these, so results are unchanged. Without this, a developer shell could change a result: for example, `AITOOLS_ENVIRONMENT=claude-code-web` makes `Write-AitoolsEnvironmentLog` LogWarn on Windows, which promotes rows to WARN.
- **Git Bash environment.** In CI the old harness's child pwsh inherited Git Bash's environment (TERM, MSYSTEM, MSYS PATH). Nothing the writer runs reads TERM (`Test-ReviewColour` is only used by review menus), and the writer starts no external program. So no variable had to be re-created. The local and CI ok lines match.
- **Strict JSON.** deploy.jsonl lines are parsed with `System.Text.Json.JsonDocument`, not ConvertFrom-Json. Checked by mutation script part d: a raw U+0001 inside a string is accepted by ConvertFrom-Json and rejected by System.Text.Json, so the check is as strict as perl `decode_json`.
- **Missing or empty deploy.jsonl fails.** The .sh `perl -ne` passes in that case (see Open question 2).
- **c8b.** The .sh uses `chmod 555`. The .ps1 checks the dry run with a writable ~/.aitools, as the Git Bash run did (its chmod had no effect on Windows). This is commented in both harnesses.
- **c25** stays a skip with the CI text: `.sh writer only (the .ps1 removes with Remove-Item)`.
- **`-Help`** prints the whole 26-line header. The exemplar's `Select-Object -Skip 1` drops line 1, which is content, not a shebang.

## CI vs local

CI source: `python W\.scratch\session-38dc-13\ci-section.py ...ci-windows-main.log tests/profile/test-config.sh`, saved as `W\.scratch\session-e9d6-09\config-ci.txt`. Local: `W\.scratch\session-e9d6-09\config-run.log`, compared with `compare-ci.py`.

- CI: 248 ok/skip lines; `247 passed, 0 failed, 1 skipped (windows: ps1 writer)`.
- Local: 248 lines; the identical summary line.
- Differing lines: 2 of 248.
  - [237] CI `ok   ps1 step3: relative 'repos' -> C:\Users\runneradmin\AppData\Local\Temp\tmp.JaHifGJ8bD\home\repos`, local `... -> C:\Users\jdpal\AppData\Local\Temp\test-config-b88e512a55ba\home\repos`. Reason: the temp root is printed in the name, and it differs on every run in both harnesses.
  - [240] CI `ok   ps1 step3: relative from / -> C:\Program Files\Git\tmp`, local `... -> C:\tmp`. Reason: for Git Bash, "/" was the Git install directory. For a native program, "/" is the root of the drive (the harness uses the drive root of its temp root; on a GitHub runner, RUNNER_TEMP puts that on D:, so CI will print `D:\tmp`). It is the same check: a run from a root gives no double separator. Commented in the harness.
- Every other line, including `writer lines in deploy.jsonl (13)` and `writer warnings counted (2)`, is identical.

## Mutation results (`W\.scratch\session-e9d6-09\mutate-config.ps1`, output `mutate-run.log`)

| # | Mutation | FAIL produced | Suite exit |
|---|---|---|---|
| a | golden `config-c1-fresh.txt`: `OK\|aitools config\|created` -> `CREATED` (mutated for 1 s, restored as soon as the c1 golden check printed) | `c1-fresh: result differs from golden config-c1-fresh.txt` (246/1/1) | 1 |
| b | harness: `case_run c6-no-bootstrap 1` -> `0` | `c6-no-bootstrap: ps1 exit 1, want 0` (246/1/1) | 1 |
| c | harness: c19 loses `AITOOLS_PROFILE_TEST_MACHINE_ID=none` | `c19-id-unavailable: no row 'WARN\|aitools config\|verified'`, its golden check, and `deploy.log lacks 'machineAlias=nobul-mac via=config'` (244/3/1) | 1 |

After the run: suite and golden hashes are equal to the originals, and `git -C W diff -- tests/profile/golden` is empty.

The first attempt of the script died on a log the suite held open (`ReadAllText` cannot share a file that is open for writing). Its `finally` restored the golden. I ended the orphaned suite process tree (`taskkill /T`, PIDs 9340 and 49820, mine) and removed its leftover temp root `C:\Users\jdpal\AppData\Local\Temp\test-config-1cc442a283c0` (`cleanup-leftover.ps1`). Then I fixed the script (FileShare.ReadWrite) and reran it.

## Syntax and guard

- `bash -n tests/profile/test-config.sh`: clean.
- PowerShell parser (`parse-check.ps1`, ParseFile) on the final `test-config.ps1`: no errors.
- Guard (`guard-check.sh`): `bash tests/profile/test-config.sh` exits 1. Stdout is empty, and stderr is `This script is for macOS/Linux. On Windows, run tests/profile/test-config.ps1 with pwsh.`. The temp dir entry count is unchanged (681/681), and nothing is written under tests/profile. This was the only .sh run.
- The .ps1 guard is the contract form verbatim (the first statement after `param` and the -Help line, no `}` before `exit 1`).

## Files changed

- `W\tests\profile\test-config.ps1`: new, 749 lines, LF. `.gitattributes` makes it `eol=crlf` on checkout; nothing in it depends on the line ending.
- `W\tests\profile\test-config.sh`: edited, 762 -> 681 lines.
  - Header (platform paragraph, line 2, `--bash-only` text) and the OS guard after `set -euo pipefail`.
  - Removed: `PS`, the pwsh check, `NWORK`/`NH`/`NDP` (uses -> `H`/`DP`, the same values off Windows), `map_args`, the ps1 branches of `run_writer`, c22j, c25, `inst_run`, `same_path` and step 3, and the `inst-harness.ps1` here-document (moved to the .ps1).
  - `LANG_RUN=sh`. `norm_json` now uses `WORK`, which is what `NWORK` held off Windows.
  - `--help` still stops at the first non-# line, so it needs no range change.
- Report: this file. Scratch: `W\.scratch\session-e9d6-09\` (parse-check.ps1, guard-check.sh, compare-ci.py, mutate-config.ps1, wait-mutate.ps1, cleanup-leftover.ps1, logs).

## INCIDENT / CONFLICT / WRITE_BLOCKED

- INCIDENT: none in product code.
- CONFLICT: none.
- WRITE_BLOCKED: none.

## Contract change requests

None needed. One optional request: the exemplar's `-Help` drops line 1 (`Select-Object -Skip 1`), which is content, not a shebang. Suggest the same fix in `tests/b8-consumers/test-b8-consumers.ps1`.

## Open questions (each with a suggested answer)

1. **CI step.** The Windows step "Config writer tests (.ps1, native pwsh)" in `.github/workflows/check.yml` still runs `bash tests/profile/test-config.sh`, which the guard now refuses (exit 1). Suggested: 38dc-13 switches it to `pwsh -NoProfile -File tests/profile/test-config.ps1` in the same PR. The macOS step (`--bash-only`, /bin/bash 3.2) and the Linux step stay as they are.
2. **Vacuous JSON check in the .sh harness.** `perl -MJSON::PP -ne 'decode_json($_)' FILE` exits 0 when FILE is missing. I saw this with Git for Windows perl: it prints "Can't open ...: No such file or directory." and the Bash tool reported no error. The same behaviour on macOS/Linux perl is unknown. So "jsonl: control characters give valid JSON" would pass with no deploy.jsonl. Suggested: in a follow-up, add `[ -s "$j" ] &&` before the perl in both .sh checks, after confirming it on a macOS/Linux run. I did not change it, because the mission says to keep macOS/Linux behaviour identical. The .ps1 already fails on a missing or empty file.
3. **c8b on Windows.** The dry-run read-only check has no read-only directory on Windows. Suggested: a follow-up adds a deny-write ACL (`icacls <dir> /deny "%USERNAME%:(W)"`, removed in `finally`), as part of PR #139's "Windows symlink / chmod / read-only coverage" follow-up. Not done here, so the case stays identical to CI.

## New operational learning

- `Start-Process -RedirectStandardOutput F` holds F open: read it while the process runs with `FileStream(..., FileShare.ReadWrite)`, not `[IO.File]::ReadAllText` (that throws "being used by another process"). A script that dies in that loop leaves the child running: end its tree and remove its temp root, because a killed `New-TestTempRoot` suite never runs its `finally`.
- ConvertFrom-Json (pwsh 7.6) accepts a raw control character inside a JSON string. Use `System.Text.Json.JsonDocument.Parse` for RFC-strict validity checks.
- PowerShell names ignore case: a `rows_n([int]$N)` with a local `$n` is one variable. I caught this on review before the first run. `$host` is the read-only `$Host`, so do not name a hostname parameter `$host`.
- "/" for a native Windows program is the drive root. Git Bash's "/" is the Git install directory. Native `Get-Location` / `GetFullPath` from "C:\" gives "C:\tmp".
- No case of this suite needed Git Bash's environment (TERM, MSYS PATH): the writer runs no external program and reads no terminal variable.
