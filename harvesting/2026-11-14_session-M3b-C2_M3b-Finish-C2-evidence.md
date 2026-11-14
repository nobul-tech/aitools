# M3b-Finish-C2 evidence v1.0 -- fix 5: the AI-merge spinner draws on Windows (in-process), AI telemetry file-only

Session M3b-Finish-C2, 2026-11-13 (local 18:00-18:25, UTC 2026-11-14T02:00Z-02:25Z), Windows 11
(10.0.26300), pwsh 7.6.10, worktree `C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input`
(branch `fix/console-input-mode`, HEAD 59680ed = origin/main e8ebd07 + batch C1). Nothing staged or
committed. Scratch paths below are relative to `.scratch\session-M3b-C2\` in that worktree.

## 1. What changed

| File | Change |
|---|---|
| `scripts/aitools-lib.ps1` | `Start-AiSpinner` / `Stop-AiSpinner` rewritten: in-process runspace (`[powershell]::Create()` + `BeginInvoke()`), `ManualResetEventSlim` stop, `Wait(200)` period; Start calls Stop first and is a no-op when stdout is redirected or the session is not interactive; Start failure -> one detail line, no spinner; Stop is synchronous (signal, `WaitOne(2000)` then `PowerShell.Stop()`, `EndInvoke`, dispose runspace/PowerShell/event in `finally`, then the clear `` `r  `e[K ``); Stop with no spinner writes nothing. Header comment names the bash parity and the one difference. New `Write-AiLog` (file-only twin of bash `_ai_log`: same `[ts] [script] [level] msg` line, same `$logFile`, no console, no counters); the 7 `Log` calls in `Invoke-AI` now call it. `Invoke-AiMerge`: the `$merged = ... Invoke-AI ...` statement wrapped in `try { } finally { Stop-AiSpinner }` (nothing else in that function changed). Lib header lists `Invoke-AI (Write-AiLog)`. |
| `tests/aitools-entry/test-console-mode-guard.ps1` | Appended spinner + telemetry section (one file, same CI step): 50 -> 81 checks (+31). Child modes `spinner-redirected`, `telemetry`, `spinner-console`; Run-Child stdin option `tty` (Start-Process -NoNewWindow, results via a file). Header and `-Help` line count updated. |
| `reference/cross-platform-detail.md` | New section "Windows console: input mode, jobs, spinner" (v1.0; the section did not exist). |

`git diff --stat` (end, `eol-check.ps1`):

```
 reference/cross-platform-detail.md              |  43 +++++
 scripts/aitools-lib.ps1                         | 117 +++++++++----
 tests/aitools-entry/test-console-mode-guard.ps1 | 216 +++++++++++++++++++++++-
 3 files changed, 341 insertions(+), 35 deletions(-)
```

(The diff stat is against HEAD 59680ed, which already contains C1.) `git diff --summary`: empty (no mode
changes). `git status --short`: the three files only. `.ps1` files: CRLF, 0 bare LF; `.md`: LF (its
attribute is `eol=lf`); 327 added lines, 0 with non-ASCII. PowerShell parser: OK on both `.ps1`
(`parse-check.ps1`, also all 19 scratch `.ps1`).

## 2. try/finally decision: YES (evidence)

`Invoke-AI` can end with a terminating error that propagates out of `Invoke-AiMerge`, and Ctrl+C
always can. `scripts/aitools.ps1` runs each setup script in-process inside
`try { & $scriptPath } catch { LogError ...; continue }` (read: the deploy loop), so the spinner thread
would keep drawing over the next scripts. Runs in driver-owned consoles (`run-evidence.ps1`,
`evidence-run.log`):

**throw** (`target-throw.ps1`): the fake backend (a session function `claude`) holds an exclusive
lock on deploy.log when it returns, so `Invoke-AI`'s next log write throws -- the outer catch mirrors
aitools.ps1. Without finally (`lib-nofinally.ps1`), verbatim:

```
18:09:48.603 CAUGHT by the outer catch (as aitools.ps1 does): Exception calling "AppendAllText" with "3" argument(s): "The process cannot access the file '...\logs\throw-nofin\deploy.log' because it is being used by another process."
18:09:48.617 spinner still registered: True
18:09:48.628 runspaces after the catch: 1:Opened/Available,2:Opened/Busy
18:09:49.230 DRIVER PEEK 2 mode=0x1F7 screen:   >> AI merge: claude (balanced) -- merging a.md... ||   | merging a.md (attempt 1)... || next setup script output line ||   \ merging a.md (attempt 1)...
18:09:51.146 runspaces at end: 1:Opened/Available,2:Opened/Busy
```

With finally (worktree lib), verbatim:

```
18:11:05.710 CAUGHT by the outer catch (as aitools.ps1 does): Exception calling "AppendAllText" ...
18:11:05.718 spinner still registered: False
18:11:05.723 runspaces after the catch: 1:Opened/Available
18:11:06.281 DRIVER PEEK 2 mode=0x1F7 screen:   >> AI merge: claude (balanced) -- merging a.md... || next setup script output line
```

**Ctrl+C** (`target-ctrlc.ps1`, run as `pwsh -NoExit -File`, i.e. a pwsh prompt follows, as when
aitools.ps1 is typed at a prompt; the fake backend sleeps 20 s; the driver sends CTRL_C_EVENT).
Without finally, verbatim:

```
18:10:46.098 DRIVER PEEK 2 mode=0x1E4 screen: PowerShell 7.6.10 ||   >> AI merge: claude (balanced) -- merging a.md... ||   | merging a.md (attempt 1)... ||   | merging a.md (attempt 1)...>
18:10:47.147 AT PROMPT runspaces: 1:Opened/Busy,2:Opened/Busy
18:10:48.137 DRIVER PEEK 4 mode=0x1E4 screen:   >> AI merge: claude (balanced) -- merging a.md... ||   | merging a.md (attempt 1)... ||   / merging a.md (attempt 1)...> showrs ||   - merging a.md (attempt 1)...>
```

With finally, verbatim:

```
18:11:12.535 DRIVER PEEK 2 mode=0x1E4 screen: PowerShell 7.6.10 ||   >> AI merge: claude (balanced) -- merging a.md... || PS C:\Users\jdpal\repos\aitools>
18:11:13.590 AT PROMPT runspaces: 1:Opened/Busy
18:11:14.576 DRIVER PEEK 4 mode=0x1E4 screen:   >> AI merge: claude (balanced) -- merging a.md... || PS C:\Users\jdpal\repos\aitools> showrs || PS C:\Users\jdpal\repos\aitools>
```

Harness note: the target calls `SetConsoleCtrlHandler(NULL, FALSE)` first, because a process started
by Start-Process did not react to CTRL_C_EVENT in the first attempt (the first ctrlc-nofin run ran
until the driver killed it); whether that is the new-process-group "ignore Ctrl+C" flag is not
verified. The first ctrlc-nofin run also had a harness bug (a prompt function `rs` collided with the
helper `RS`, PowerShell names are case-insensitive); both fixed before the runs quoted above.

## 3. Tests

| Suite | Result | Log |
|---|---|---|
| `tests/aitools-entry/test-console-mode-guard.ps1`, stdin a pipe (Claude Code / CI shape) | **74 passed, 0 failed, 7 skipped** (3 C1 `console:` + 4 `console spinner:` -- stdin/stdout not a console), exit 0, 4.2 s | `guard-test-final.log` |
| same, in-process in a driver-owned console (`target-suite.ps1`) | **81 passed, 0 failed, 0 skipped**, exit 0 | `result-suite-console.log` |
| `tests/logging/test-logging.ps1` | 20 passed, 0 failed, 0 skipped, exit 0, 5 s | `suite-logging.log` |
| `tests/managed-files/test-managed-files.ps1` | 56 passed, 0 failed, 0 skipped, exit 0, 42 s (pty cases ran: pywinpty present) | `suite-managed-files.log` |
| `tests/managed-files/test-adopt-push.ps1` | 22 passed, 0 failed, 0 skipped, exit 0, 19 s | `suite-adopt-push.log` |

New checks (31): Start-/Stop-AiSpinner and Write-AiLog defined once; no `*-Job` command in the
spinner; `[powershell]::Create()` + `BeginInvoke()`; the first command of Start-AiSpinner is
Stop-AiSpinner and comes before Create; the redirected/not-interactive gate returns before Create;
frame / chars / period strings equal bash's; the clear comes after EndInvoke; Stop returns before
writing when no spinner; `WaitOne(2000)` and >= 3 `Dispose()` in Stop's finally; Invoke-AiMerge:
Invoke-AI inside a try whose finally calls Stop-AiSpinner, Start before that try, Stop-AiSpinner
only there; Invoke-AI calls no Log/LogOk/LogWarn/LogError/Write-Host; all 7 `AI invocation` strings
are arguments of Write-AiLog; Write-AiLog has AppendAllText to `$logFile` and no
Write-Host/[Console]/counters. Child, redirected stdout: Stop without Start no-op; Start creates no
runspace; nothing written (no frame text, no ESC[K); no warning/error. Child, fake `claude`
function: a Log control line IS on the captured console, no `AI invocation` line is; results
unchanged for accepted / rejected+exhausted / empty / CLI throw / no CLI; deploy.log has all 8 lines
in the `[ts] [console-guard-test] [level] ...` format; counters 0/0. Console only (SKIP otherwise):
frames drawn (CursorLeft = 4 + message length after 450 ms), Stop clears (CursorLeft 2) and
unregisters, runspace count back to baseline, Start/Stop < 1000 ms.

Child values on a real console (`target-ttyprobe.ps1` -> `result-ttyprobe.log`):
`CONSPIN before=1 during=2 after=1 col=25 want=25 colafter=2 registered=False startms=7.6 stopms=8.3`.

A test-harness gotcha found on the way: `Remove-Item function:global:claude` returns without error and
leaves the function in place; `Remove-Item -Path Function:\claude` removes it (`probe-nocli.ps1`).
And `R` is the built-in alias of Invoke-History (aliases beat functions).

## 4. Mutations (`mutate.ps1`; temp tree copies, worktree untouched)

| Mutation | pipe (`mutate-pipe.log`) | console (`mutate-console.log`) | Failing checks (console run adds) |
|---|---|---|---|
| M0 none (control) | 74/0/7 exit 0 | 81/0/0 exit 0 | -- |
| M1 Start-Job spinner back (origin Start-/Stop-AiSpinner) | exit 1, 10 fail | exit 1, 11 fail | 8 structure + redirected "creates no runspace" (during=2) + "nothing written" (ESC[K in the pipe); console: "frames are drawn" (col=0, want=25) |
| M2 Stop does not dispose | exit 1, 1 fail | exit 1, 2 fail | "waits ... disposes ... in a finally"; console: "runspace count back to baseline" (after=2) |
| M3 Invoke-AI telemetry back to Log | exit 1, 3 fail | exit 1, 3 fail | "no console logger" (Log x7), "every line through Write-AiLog" (7 of 7 not), "no 'AI invocation' line on the console" |
| M4 Invoke-AiMerge without try/finally | exit 1, 2 fail | exit 1, 2 fail | both `merge:` checks |
| M5 Start does not stop first | exit 1, 1 fail | exit 1, 1 fail | "stops a running spinner first" (first command: LogDetail) |
| M6 no redirected-stdout gate | exit 1, 3 fail | exit 1, 3 fail | gate structure; redirected "creates no runspace" (registered=True); "nothing written" (frames in the pipe) |
| M7 Write-AiLog also writes the console | exit 1, 2 fail | exit 1, 2 fail | "Write-AiLog writes the log file only"; "no 'AI invocation' line on the console" |
| M8 Stop does not wait (WaitOne(0), no EndInvoke) | exit 1, 2 fail | exit 1, 2 fail | "clears ... after EndInvoke"; "waits with a 2 s cap ..." |
| M9 before: origin/main lib e8ebd07 | 26/43/7 exit 1 | 29/47/0 exit 1 | every C1 and C2 lib check |

## 5. Real-console before/after (driver-owned minimized consoles only)

Harness copied from session-M3b-C1 (`drv.ps1`, `conmode.cs.ps1`) with one added step (`ctrlc`) and a
`-NoExit` switch; targets written here. "main" = origin/main e8ebd07 lib (`origin-aitools-lib.ps1`,
`git show`; it predates C1); "new" = the worktree lib. `target-spin.ps1`: Start-AiSpinner, 1.2 s, then
`Invoke-AI` against a stub `claude.cmd` on a scratch PATH (reads the prompt, ~3 s, prints a valid merge;
same shape as `Stub-Claude` in test-managed-files.ps1) while the spinner runs, Stop-AiSpinner, then
`Read-ConsoleChoice` with one `y<CR>` from the driver.

main, verbatim (`result-spin-main.log`):

```
18:09:33.895 Start-AiSpinner returned after 145.1 ms
18:09:34.590 DRIVER PEEK 1 mode=0x1F7 screen: line before the spinner
18:09:36.678 DRIVER PEEK 2 mode=0x1F7 screen: line before the spinner || [2026-11-14T02:09:35Z] [m3bc2-spin-main] [info] AI invocation: speed=balanced backend=claude attempt=1
18:09:38.214 Stop-AiSpinner returned after 18.7 ms
18:09:38.607 DRIVER PEEK 4 mode=0x1F7 screen: line before the spinner || [2026-11-14T02:09:35Z] [m3bc2-spin-main] [info] AI invocation: speed=balanced backend=claude attempt=1 || [2026-11-14T02:09:38Z] [m3bc2-spin-main] [info] AI invocation: speed=balanced backend=claude attempt=1 result=accepted ||     answer:
18:09:38.619 Read-ConsoleChoice returned [y] after 389 ms
```

new, verbatim (`result-spin-new.log`, run after the finally was added):

```
18:10:57.612 Start-AiSpinner returned after 7.5 ms
18:10:58.293 DRIVER PEEK 1 mode=0x1F7 screen: line before the spinner ||   | merging test...
18:10:58.833 runspaces while spinning: 1:Opened/Available,2:Opened/Busy
18:11:00.379 DRIVER PEEK 2 mode=0x1F7 screen: line before the spinner ||   - merging test...
18:11:01.928 Invoke-AI returned after 3087 ms: [# Title\nmerged line]
18:11:01.937 Stop-AiSpinner returned after 7.6 ms
18:11:01.940 runspaces after stop: 1:Opened/Available
18:11:02.329 DRIVER PEEK 4 mode=0x1F7 screen: line before the spinner ||     answer:
18:11:02.330 DRIVER sends y<CR>
18:11:02.341 Read-ConsoleChoice returned [y] after 392 ms
18:11:02.363 deploy.log: [2026-11-14T02:10:58Z] [m3bc2-spin-new] [info] AI invocation: speed=balanced backend=claude attempt=1
18:11:02.370 deploy.log: [2026-11-14T02:11:01Z] [m3bc2-spin-new] [info] AI invocation: speed=balanced backend=claude attempt=1 result=accepted
```

The spinner draws while Invoke-AI runs (PEEK 2 is 1.5 s into the 3 s stub call), no telemetry line is
on screen, the same two lines are in deploy.log, the row is cleared after Stop (PEEK 4: the next prompt
starts with 4 blanks, as with bash), and the read takes the first `y<CR>` (392 ms = the driver's
300 ms wait + send).

Under the pty harness (`pty-merge-probe.ps1` -> `pty-merge-probe.log`; `tests/managed-files/pty-run.py`,
ConPTY), the real `[m]erge & adopt` path through Deploy-ManagedFile:

| lib | case | result | spinner frames in pty output | `AI invocation` on the terminal | deploy.log AI lines |
|---|---|---|---|---|---|
| main | `m y` | accept & adopt | 0 | 2 | 2 |
| main | `m n s` | skipped | 0 | 2 | 2 |
| new | `m y` | accept & adopt | 11 | 0 | 2 |
| new | `m n s` | skipped | 11 | 0 | 2 |

Cosmetic harness artifact, cause unknown: some screen peeks end with `??` after trailing blanks
(e.g. PEEK 3 of both spin runs, a prompt row in ctrlc-new); it appears with both libs and on rows the
spinner never wrote, so it is not spinner output. M3b-Finish-R saw similar trailing blanks.

## 6. Timings

| What | Value | Source |
|---|---|---|
| Start-AiSpinner, new (console) | 9.0, 7.5 ms (target-spin); 7.6 ms (CONSPIN) | result-spin-new.log (both runs), result-ttyprobe.log |
| Start-AiSpinner, main (Start-Job) | 145.1 ms | result-spin-main.log |
| Stop-AiSpinner, new (console) | 7.9, 7.6, 8.3 ms | same |
| Stop-AiSpinner, main | 18.7 ms | result-spin-main.log |
| Start/Stop with redirected stdout | no runspace, nothing written (suite) | guard-test-final.log |
| Console suite (81 checks) | ~6.4 s wall (driver start to exit) | result-suite-console.log |

## 7. Bash (no change made)

`_start_spinner` / `_ai_log` behave as the brief says. One real defect found, NOT fixed (brief: report
only): `_invoke_ai_merge` has no trap, and the spinner subshell survives Ctrl+C. `probe-bash-sigint.sh`
(a replica of `_start_spinner` writing frames to a file; the "setup script" is a non-interactive bash in
its own process group; SIGINT sent to that group), verbatim under Git Bash:

```
setup-script pid=149690 spinner pid=149693 frames before SIGINT=6
setup script ended after SIGINT
after SIGINT: spinner alive=yes frames +0.5s=9 +2.0s=16
cleanup: killed spinner 149693
```

Bash ignores SIGINT in asynchronous commands when job control is off, so the subshell keeps writing to
`/dev/tty` after the script died. Shown under Git Bash (MSYS) only; on macOS/Linux (where the bash
setup scripts run) the same is expected but not verified here.

## 8. Not run

- `aitools`, `aitools install`, setup-user-*, deploy-harness, build-deploy.sh; check-pre-commit /
  check-post-push / check-pre-push.
- macOS / Linux (the suite's non-Windows paths, the bash spinner on a real POSIX tty), PowerShell 5.1,
  Windows Terminal / mintty (only conhost consoles started by the driver, and ConPTY via pywinpty).
- CI. Expected on the Windows runner: 74 passed / 7 skipped (stdin/stdout not a console) -- inferred
  from the pipe run, not observed.
- A real `claude` / `agent` call (stubs and fake functions only).

## 9. Observations

- The spinner draws in the real aitools flow because `scripts/aitools.ps1` runs setup scripts
  in-process (`& $scriptPath`; deploy-harness via `Invoke-ChildRelayed`, also in-process), so their
  stdout is the user's console. If a caller ever pipes a setup script's stdout, the spinner turns
  itself off (by design; bash would still draw on /dev/tty).
- `tests/managed-files/test-managed-files.ps1` (merge-reject case) says the read after a rejected merge
  "comes back corrupted" after the Start-Job spinner and does not assert it. In the pty probe the
  `m n s` input ended `skipped` with BOTH libs (one run each), so that symptom did not reproduce here.
- clip2md (`shared/shell/aliases.ps1`) calls Invoke-AI when the lib is loaded: its telemetry lines no
  longer print in the user's shell (now as bash).
- `Log` / `LogDetail` / `Write-AiLog` throw when deploy.log cannot be written (the throw run above);
  `reference/logging.md` section 5 says a failed log write is swallowed. Pre-existing for Log; Write-AiLog
  copies Log's write on purpose (same behaviour as before the change).
