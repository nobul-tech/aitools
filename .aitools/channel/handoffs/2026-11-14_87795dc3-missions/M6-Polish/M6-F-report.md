# M6-F report: every log writer outside aitools-lib is fail-safe (incident #174)

**Version**: v1.0 (2026-11-14). **Author**: M6-F, delegated by M6-Polish (level 2),
delegated by Session Commander 87795dc3-e. **Branch**: `fix/m6-logging`, off
origin/main 846ab24. Fix commit `c2d3587`; this report is the next commit. Pushed.
No PR was opened: M6-DE opens it after items d and e.

## Summary

1. All six writers named in #174 failed on origin/main. I reproduced each one in a scratch harness: an unwritable, locked or missing log ended the bash installer, the resolver and check-lib (exit 1 at the first line), made the PowerShell Log and check-lib throw under `Stop`, made aitools-profile.ps1 exit 2 with no data, and made the bash installer skip the relay sync.
2. Each writer now appends through the lib's existing helpers, `_aitlib_log_append` / `Add-AitLibLogText`. There is no third copy of the swallow logic. Two small helpers were added: `run_relay_sync` / `Invoke-RelaySync` for the installer's Step 22, and `Write-CheckLogText` for check-lib.ps1.
3. New tests cover every writer in both twins. The new failure-mode checks fail against origin/main's scripts and all of them pass on the fix.
4. #174 is closed in `registries/incidents.json`. `closedIn` names the branch; the orchestrator sets the PR number and version.
5. Locally, every touched suite and every suite that exercises the changed files passes. The only failures are pre-existing local artefacts, which fail the same way on origin/main. check-pre-commit has 0 FAIL and check-pre-push has 0 FAIL.

## Confirmed writer list (step 1)

I grepped `scripts/` and `shared/` (tests excluded) for `Add-Content`, `AppendAllText`, `Out-File -Append`, `>>`, `tee -a` and `printf ... >>`, then read each hit.

| # | File:function | Write on origin/main | Failure on origin/main (reproduced) |
|---|---|---|---|
| 1 | `scripts/aitools-install.sh`:`log` | `printf ... \| tee -a "$LOG_FILE"` under `set -euo pipefail` | rc 1 after the first console line. `tee: .../deploy.log: Is a directory` (also `Permission denied` and `Not a directory`). The counters were never reached. |
| 2 | `scripts/aitools-install.sh` Step 22 (relay sync) | `if python3 ... >>"$LOG_FILE" 2>&1` | The redirection fails, so the sync **never runs**. The run logs "sync ... failed", and that warn line itself then ends the run through #1 (rc 1). |
| 3 | `scripts/aitools-install.ps1`:`Log` | `Add-Content -Path $logFile` | Under `Stop` inside a try: jumps to the catch after the first console line (`CAUGHT: The process cannot access the file ... being used by another process`). Counters not counted. Default preference: one `Add-Content` error record per log line. |
| 4 | `scripts/aitools-install.ps1` Step 22 | `$out \| Add-Content -Path $logFile` | One error record. The sync itself ran. |
| 5 | `scripts/aitools-install.ps1` top level | `New-Item ... $logDir` (no guard, a duplicate of `Initialize-Logging`) | Prints an error when the directory cannot be created. Found by reading; same class. |
| 6 | `scripts/aitools-profile.sh`:`log` | `printf >> "$LOG_FILE"` under `set -euo pipefail` | rc 1, `aitools-profile.sh: line 74: .../deploy.log: Is a directory`, no data. |
| 7 | `scripts/aitools-profile.ps1`:`Log` | `[IO.File]::AppendAllText` (unguarded) | **rc 2** through the script's `trap`: `aitools-profile: Exception calling "AppendAllText" ...`. No stdout data. |
| 8 | `scripts/check-lib.sh`:`check_log_init`, `_check_log_step`, `print_summary` | `mkdir -p` and `>>` | rc 1 at the first write (`check-lib.sh: line 56: .../checks.log: Is a directory`). The `mkdir` fails when the directory cannot be created. |
| 9 | `scripts/check-lib.ps1`:`CheckLogInit`, `CheckLogStep`, `PrintSummary` | `New-Item` and `Add-Content` | Under `Stop`: `CAUGHT: ... checks.log ...` at `CheckLogInit`. Locked, directory and no-dir cases all fail. Note: `New-Item` with a file as parent returned silently (the #169 trap). |

Evidence: `.scratch/session-M6-F/repro-sh-main.log` and `repro-ps-main.log` (origin/main snapshot), and `repro-sh-new.log` and `repro-ps-new.log` (the fix). The harnesses are `repro-sh.sh`, `repro-ps.ps1` and `repro-child.ps1`. Scratch is not tracked; the key lines are quoted above.

Already fail-safe (not changed):
- `scripts/ait-harvest.py`: falls back to a `NullHandler` on `OSError`.
- `scripts/harness-db.py`: `except OSError: pass`.
- `shared/shell/aliases.ps1`:`_clip2md_log`: try/catch.
- `shared/shell/aliases.sh` clip2md: `2>/dev/null`.

Writes that are not logs: `deploy-harness.sh` plan files, `build-deploy.sh` generated files and `setup-user-shell.sh` rc lines.

Additions beyond #174's list, all the same class, all **not fixed** (see Follow-ups): `scripts/aitools` (bash entry point) lines 1237/1243 and 2107, `scripts/aitools.ps1` lines 286 and 2046, `shared/hooks/standing-order-guard.sh` lines 63 and 101, and `shared/hooks/tool-ops-session-audit.sh` line 103.

## Fix (step 2)

Every file loads aitools-lib before it defines the writer, so each one reuses the lib's helpers:
- aitools-install.sh/.ps1 source or dot-source the lib (lines 15 and 42).
- aitools-profile.sh/.ps1 source the lib, then define `log`/`Log`, then call `logging_init`.
- check-lib.sh/.ps1 source the lib at their top.

No minimal mirror was needed.

- **Installer `log` / `Log`**: `_aitlib_log_append "$line" "$LOG_FILE"` plus `printf '%s\n' "$line"`, and `Add-AitLibLogText $line`. The console format is unchanged: plain, the same as `tee` printed.
- **Installer Step 22**: `run_relay_sync CMD ARGS` / `Invoke-RelaySync EXE ARGS` in the "install log helpers" block, so the test can extract them. They capture the output, append it fail-safe and return the sync's exit code.
- **Installer.ps1**: the duplicate `New-Item` of the log directory is removed. `Initialize-Logging` already creates the directory, fail-safe.
- **Resolver `log` / `Log`**: `_aitlib_log_append` and `Add-AitLibLogText`. Console lines still go to stderr, and stdout stays data only.
- **check-lib.sh**: every `checks.log` / `checks.jsonl` line goes through `_aitlib_log_append LINE FILE`. `mkdir -p ... 2>/dev/null || true` carries a comment citing section 5. The bytes written are the same as before.
- **check-lib.ps1**: new `Write-CheckLogText PATH TEXT`. It sets a local `$logFile = $Path` and calls `Add-AitLibLogText`, which resolves `$logFile` through the caller's scopes (dynamic scoping), so no third copy of the try/catch is needed. A test proves that the bridged `$script:logFile` stays `deploy.log` and that no check line lands in deploy.log. The `New-Item` is wrapped in `try { ... -ErrorAction Stop } catch { $null = $_ }`, with a comment citing section 5.
- Each swallow site has a comment that cites `reference/logging.md` section 5 and #174.
- **Docs**:
  - `reference/logging.md` section 5 now names these writers and their helpers.
  - `reference/script-standards-detail.md`: the installer override examples now show the new code, instead of `tee -a` and `Add-Content`.

## Tests (step 3)

| Suite | New cases | Fail-safe modes |
|---|---|---|
| `tests/profile/test-install.sh` | `log-written`, `log-blocked`, `log-unwritable` (bash), `log-locked` (PS, Stop + try, lock held in-process), `relaysync-ok`, `relaysync-rc`, `relaysync-blocked`. Two new harness modes, `logprobe` and `relaysync`, plus stubs `sync.sh` and `sync.ps1` | directory, mode 000, lock |
| `tests/profile/test-profile.sh` | `log-written`, `log-blocked`, `log-unwritable` (bash; skipped as root and on Windows). `hostname --hostname-value probe-host` with `AITOOLS_ENVIRONMENT=bogus`, so the override logs a warning | directory, mode 000 |
| `tests/logging/test-logging.sh` | check-lib: writable (6 checks.log lines, 6 valid JSON records), directories, chmod 000, log dir not creatable | set -euo pipefail |
| `tests/logging/test-logging.ps1` | check-lib: writable (also: no check line in deploy.log, `$script:logFile` unchanged), directories, locked (Windows; explicit SKIP elsewhere), log dir not creatable. aitools-profile.ps1 with a locked deploy.log (Windows; SKIP elsewhere) | Stop + try, lock from another process |

What the checks assert:
- the run reaches its end with the expected exit code;
- every console line printed;
- the counters counted;
- no write error or catch text on the console;
- under a lock, nothing was written to the locked file;
- for relay sync, the stub ran (marker file) and its exit code came back.

Markers: all existing BEGIN/END markers are unchanged. The two new helpers sit inside the existing "install log helpers" block. `--help` ranges were updated to match.

**Mutation table.** The mutation tree is the new tests plus origin/main 846ab24's `scripts/` (`.scratch/session-M6-F/mut-tree`, built by `build-mut-tree.sh`). The bash halves run in Git Bash under a `uname -s` → Linux spoof (`spoof-linux.sh`), as local evidence only; CI runs them natively.

| Suite | origin/main scripts | This change | New checks failing on main |
|---|---|---|---|
| test-logging.sh | 42 passed, 12 failed | 54 passed, 0 failed | 12 (all check-lib failure modes) |
| test-logging.ps1 | 34 passed, 11 failed | 45 passed, 0 failed | 11 |
| test-install.sh (ps, Windows) | 34 passed, 17 failed | 51 passed, 0 failed | 17 |
| test-install.sh (bash, spoof) | 43 passed, 23 failed | 63 passed, 3 failed | 20 (the other 3 below) |
| test-profile.sh (ps, Windows) | 717 passed, 8 failed | 721 passed, 4 failed | 4 (the other 4 below) |
| test-profile.sh (bash, spoof) | 729 passed, 23 failed | 737 passed, 15 failed | 8 (the other 15 below) |

The new writable-log checks (`log-written`, check-lib writable) are regression guards and pass on both trees.

Pre-existing local failures, identical on origin/main and this change (not mine):
- `step3-unresolvable` (3): bash under the spoof; on NTFS, `chmod 000` on a directory does not block `cd`.
- `a78-exc-ro`, `a8-mig-ro`, `a8-reg-ro` (15): same cause, read-only directories.
- `jr-unicode-exists`, `jr-set-case-unicode` (4, ps): non-ASCII stderr through this console's code page.

CI already runs every touched suite in the right jobs (`.github/workflows/check.yml`): test-logging.sh in all three jobs, test-logging.ps1 on Windows, and test-profile.sh and test-install.sh in all three jobs (macOS also under /bin/bash 3.2). No check.yml change and no new suite file, so `check-ci-suites.pl` is unaffected.

## Local verification (step 5)

Windows 11, pwsh 7, Git Bash 5.3.15.

- Touched suites: see the table above.
- Other suites that exercise the changed files or functions (`run-other-suites.sh`), all rc 0:
  - os-guards 34/0
  - aitools-entry console-mode-guard 76/0 (7 skipped)
  - check-lib resolve-git-bash 17/0
  - b8-consumers 31/0
  - profile test-lib 201/0
  - test-config 247/0 (1 skipped)
  - test-user-init 179/0 (1 skipped)
  - managed-files .ps1 56/0
  - adopt-push .ps1 22/0
  - hookin 29/0
  - deploy-harness 99/0 (2 skipped)
  - deploy-harness-mdm 56/0
  - claude-mdm 33/0 (1 skipped)
  - skills-fanout 106/0 (7 skipped)
  - rules-fanout 61/0 (3 skipped)
  - skills-legacy 32/0 (2 skipped)
  - ci-suites 21/0
- `bash -n` and the PowerShell parser on all 10 touched scripts and tests: 0 failures. No new non-ASCII bytes. Line endings unchanged.
- `check-pre-commit.ps1` (no `-Fix`, `AITOOLS_LOG_DIR` in scratch): 11 PASS, 4 SKIP, 4 WARN, 0 FAIL.
  - WARN 3: build freshness. `-Fix` builds against the real HOME, so it is forbidden here.
  - WARN 5: platform note. The note is in the commit message.
  - WARN 9: RELEASE_NOTES. The orchestrator owns that file.
  - WARN 11: uncommitted changes in the dotprofile. They are not mine.
- `check-pre-push.ps1`: 7 PASS, 3 WARN (1, 5, 6: advisory), 0 FAIL. Step 7 reported "fresh build OK; resolver consumers dry-run clean".

## Incident #174 (step 4)

Closed through the /incident process:
- The entry moved from `incidents` to `closed`, keeping `id` and `title`.
- Added `closedIn` (the branch; the PR number and version are pending) and `closedDate` 2026-11-14, plus `correctiveAction`, `rootCause`, `preventionLayer` and `updated`.
- `meta.lastUpdated` was already 2026-11-14.
- The file round-trips byte for byte, parses, and has 164 open, 10 closed, max id 174, no duplicates.

## Review after (D-DEL5, old -> new)

1. `aitools-install.sh` `log`: `printf | tee -a "$LOG_FILE"` (a failed write ended the installer) -> `_aitlib_log_append` + `printf` (swallowed; the console line and counters are unaffected).
2. `aitools-install.sh` Step 22: `python3 ... >>"$LOG_FILE"` inside `if` -> `run_relay_sync python3 ...` (new helper). The output is captured and then appended. Its formatting differs only in that trailing blank lines are dropped (`$(...)`).
3. `aitools-install.ps1` `Log`: `Add-Content` -> `Add-AitLibLogText`. The deploy.log line ending on Windows is now LF (it was CRLF from `Add-Content`), the same as the lib's lines.
4. `aitools-install.ps1` Step 22: `$out | Add-Content` -> `Invoke-RelaySync` (new helper). The output is one block joined with LF.
5. `aitools-install.ps1`: the top-level `New-Item` of `$logDir` -> removed, with a comment (Initialize-Logging creates it).
6. `aitools-profile.sh` `log`: `>> "$LOG_FILE"` -> `_aitlib_log_append`.
7. `aitools-profile.ps1` `Log`: unguarded `AppendAllText` (trap exit 2) -> `Add-AitLibLogText`.
8. `check-lib.sh`: `mkdir -p` -> `mkdir -p ... 2>/dev/null || true`, and 8 `>>` appends -> `_aitlib_log_append`. Line content is unchanged.
9. `check-lib.ps1`: `New-Item` -> guarded; 6 `Add-Content` -> new `Write-CheckLogText`. On Windows, checks.log and checks.jsonl lines now end in LF (they were CRLF). No consumer depends on CRLF: `tests/b8-consumers` greps checks.jsonl and passed.
10. `reference/logging.md` section 5: names only the lib's writers -> also the writers outside the lib and their helpers.
11. `reference/script-standards-detail.md` "Entry points" examples: `tee -a` / `Add-Content` -> the new override code, plus one sentence naming the fail-safe helpers.
12. `registries/incidents.json`: #174 open, high -> closed (the entry is in commit c2d3587).
13. Tests: `tests/profile/test-install.sh` gains 32 checks on Windows (51, was 19) and 31 in the bash half, plus header lines and `--help` 2-35 -> 2-44. `tests/profile/test-profile.sh` gains 3 cases (13 checks on macOS/Linux, 9 on Windows). `tests/logging/test-logging.sh` gains 18 checks (54, was 36). `tests/logging/test-logging.ps1` gains 19 checks (45, was 26). The headers of both logging suites name the new writers.
14. This report: none -> v1.0.

## Proposed RELEASE_NOTES row (for the orchestrator)

| n | High | Log writers outside aitools-lib are fail-safe (`reference/logging.md` section 5). The installers' log override and Step 22 relay sync (`run_relay_sync` / `Invoke-RelaySync`), the profile resolver's log override, and check-lib's checks.log / checks.jsonl writers append through `_aitlib_log_append` / `Add-AitLibLogText`. A locked, unwritable or missing log no longer ends the bash installer, resolver or a check script (set -e), throws from the PowerShell installer or check-lib under `$ErrorActionPreference = "Stop"`, turns `aitools-profile.ps1` into exit 2, or skips the bash installer's relay sync. Resolves Incident #174. (branch fix/m6-logging) |

## Not run

- macOS (bash 5 and /bin/bash 3.2) and Linux natively: CI only. The bash halves ran here under a Linux uname spoof in Git Bash, as local evidence.
- `check-pre-commit -Fix` and `check-post-push`: the first builds against the real HOME (forbidden), and the second is M6-B/M6-C's.
- `aitools` and `aitools install`, `aitools-install.*` as a whole, `setup-user-*`, `deploy-harness` and `build-deploy.sh` against the real HOME: not run. The suites that run build-deploy use isolated HOMEs.
- A real Windows PowerShell 5.1 run of anything.
- No CI run: no PR is open (CI starts with the PR).

## WRITE_BLOCKED / CONFLICT / INCIDENT

- WRITE_BLOCKED: none.
- CONFLICT: the auto-mode note allowing Bash file edits vs USO "Dedicated tools for file ops" -- resolved by tier 1 (the commander's CLAUDE.md): Read, Edit, Write and Grep for every file operation.
- CONFLICT: the /incident skill's "present for review" and "mention in release notes" steps vs this prompt -- resolved by tier 2 (the prompt): written as a version and listed under Review after; the release-notes line is above for the orchestrator.
- INCIDENT (not filed; candidates for M6-DE's 177/178 or the orchestrator):
  1. **High.** `scripts/aitools` Step 2 runs `build-deploy.sh ... >> "$LOG_FILE" 2>&1` inside `if`. With an unwritable deploy.log the redirection fails, build-deploy never runs, the step logs `build failed` and `return 1`. Lines 1237/1243 skip the relay sync the same way. `scripts/aitools.ps1` lines 286 and 2046 use `Add-Content` (error records; terminating under `Stop`). The class is the same as #174, and the same construct was reproduced in the installer here. These sites were not run; they are read from the code. Not fixed: outside #174's files, and there is no extraction harness for the entry points (new markers and tests would be needed), so not "small".
  2. **Medium.** `shared/hooks/standing-order-guard.sh` (`set -euo pipefail`) runs `mkdir -p "$LOG_DIR"` (line 63) on every Bash call, unguarded, and appends its observe-mode line (line 101) unguarded. `shared/hooks/tool-ops-session-audit.sh` appends its result (line 103) unguarded under `set -euo pipefail`, against its "always exit 0" contract (its log path is #70). Read from the code, not run. Hooks follow the hook-rollout and hook-lifecycle rules, so they were not changed here.
  3. **Low.** aitools-lib `jsonl_record`'s one-time warning, in Git Bash, when the log directory cannot be created: it prints a raw `cygpath: error converting ".../deploy.jsonl" - Not a directory` line, and `deploy.jsonl: cannot write  --` with an empty path (display_path fails). Seen in `repro-sh-new.log` (installer, nodir). The lib is out of scope.
  4. **Medium, unverified.** `scripts/bootstrap.ps1` line 48 runs the installer with Windows PowerShell 5.1 (`& powershell ... aitools-install.ps1`). The installer dot-sources aitools-lib.ps1, whose `Initialize-Logging` uses 3-argument `Join-Path` (PS 6+), and `.claude/rules/cross-platform.md` says deploy scripts error on PS 5.1. Not run.

## Open questions (each with a suggested answer)

1. Does the swallowed write need a row in the `reference/script-standards-detail.md` exemptions table? Suggested: no. Section 5 itself sanctions it as "the only sanctioned silent-suppression", and each swallow site cites it, as M5-L1 concluded for the lib. If the commander wants every suppression listed in one place, add one pointer row "fail-safe log writes: logging.md section 5" (his approval is needed for that table).
2. Should the entry points' same-class sites (INCIDENT 1) ride on this branch with M6-DE? Suggested: file them as their own incident and fix them in a follow-up with extraction markers, so `aitools`'s Step 2 gets a test. Do not grow this branch further.
3. Is the dynamic-scope reuse in `Write-CheckLogText` acceptable, rather than a `-Path` parameter on `Add-AitLibLogText`? Suggested: yes for now (the lib was out of scope; the test pins the behaviour). When the lib is next touched, give `Add-AitLibLogText` an optional `-Path` and drop the local `$logFile`.

## New operational learning

- A failed output redirection on a command in an `if` condition (`if cmd >>"$LOG"; then`) does not trip `set -e`. The command **never runs**, and the `else` branch reports it as failed. Unwritable logs therefore silently skip the work they were meant to record. Capture the output, then append it fail-safe.
- Windows enforces `FileShare.None` per handle, so a test can hold the lock in the same process that writes. This was verified: the installer harness writes nothing while it holds the handle.
- PowerShell variable lookup is dynamic: a callee reads the caller's local variable of the same name. A fixed-target helper (`Add-AitLibLogText` reads `$logFile`) can be pointed elsewhere for one call by setting a local. Pin that with a test, because it depends on the callee not using `$script:`.
- A `uname -s` spoof exported as a bash function (`export -f uname`) runs a platform-targeted suite's bash half in Git Bash. It is useful local evidence; expect NTFS-permission artefacts (`chmod 000` directories) to fail there and nowhere else.
- In this environment, a foreground Bash call is moved to the background after about 180 s. Bound wait loops to under 180 s and repeat them.

## Delegates used

None.
