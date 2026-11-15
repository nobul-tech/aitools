# M3b-Finish-C1 evidence v1.0 -- fix 1: Read-ConsoleChoice reads in cooked console mode; one shared console-input helper

Session M3b-Finish-C1, 2026-11-13 (local 17:40-18:00, UTC 2026-11-14T01:40Z-02:00Z), Windows 11
(10.0.26300), pwsh 7.6.x, worktree `C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input`
(branch `fix/console-input-mode`, base origin/main e8ebd07). Nothing staged or committed.
All scratch paths below are relative to `.scratch\session-M3b-C1\` in that worktree.

## 1. What changed

| File | Change |
|---|---|
| `scripts/aitools-lib.ps1` | New section "Console input mode helper (Windows only)" before the prompt helpers: `$script:AitConsoleInputError`, `Initialize-AitConsoleInput` (lazy, once per process, only when `$IsWindows` and stdin is not redirected; a failed Add-Type logs one detail line and is not retried), one C# type `AitConsoleInput` (`Get`, `Set`, `EnterCooked`, `LastError`), and `Save-ConsoleInputMode` / `Restore-ConsoleInputMode` moved from aitools.ps1 onto that type (same return objects and strings, including `"unavailable: <message>"`). `Read-ConsoleChoice`: `EnterCooked()` before the read, `[Console]::ReadLine()` in `try`, `Set(saved)` in `finally` (result checked, detail line on failure); one detail line when the mode at the prompt had line input or echo off. EOF branch and contract unchanged. Comment block updated (parity note: read_tty_choice needs no such step). |
| `scripts/aitools.ps1` | Removed its `Save-ConsoleInputMode` / `Restore-ConsoleInputMode` and the `AitConsoleModeGuard` Add-Type (-68 lines); 4-line pointer comment left in their place; Step 2 comment names aitools-lib.ps1. Step 2 code (`$consoleInMode = Save-ConsoleInputMode`, `$null | & $bashExe ...`, `Restore-ConsoleInputMode $consoleInMode "build-deploy"` in finally) unchanged. |
| `tests/aitools-entry/test-console-mode-guard.ps1` | Rewritten (still one file, same CI step "aitools.ps1 console input mode guard tests (PowerShell, native)" in check.yml): 18 -> 50 checks. Loads the helpers from the lib (child pwsh dot-sources the lib under an isolated HOME / USERPROFILE / AITOOLS_LOG_DIR). Keeps the Step 2 structure checks. |

`git diff --stat` (end):

```
 scripts/aitools-lib.ps1                         | 129 ++++++++++-
 scripts/aitools.ps1                             |  76 +------
 tests/aitools-entry/test-console-mode-guard.ps1 | 274 +++++++++++++++++++-----
 3 files changed, 351 insertions(+), 128 deletions(-)
```

`git diff --summary`: empty (no mode changes). `git status --short`: the three files only. All three
files CRLF, 0 bare LF, 0 non-ASCII characters in added lines (`eol-check.ps1`). PowerShell parser: OK on
all three (`parse-check.ps1`).

### Deviation from the prototype: no FlushConsoleInputBuffer

`proto-conin.ps1` `EnterCooked` called `FlushConsoleInputBuffer` before setting the mode. The shipped
`EnterCooked` does not flush. Reasons:

1. Not needed for the fix: the real-console runs below (section 4) accept the first `o<CR>` with echo
   and restore the mode without a flush.
2. Race with the pty test harness: `tests/managed-files/pty-run.py` sends each input line once the
   child has been quiet `QUIET_SECONDS = 0.4`. The first Read-ConsoleChoice in a process compiles the
   type (118-149 ms here; M3-Fixes-B measured 294-311 ms under build load). On a slower CI runner a
   compile over 400 ms would let the key arrive before the flush, the flush would drop it, and the case
   would hang until the 30 s timeout. Not testable here (fast machine).
3. Parity with `read_tty_choice` (no flush) and no typeahead behaviour change.

Open question 1 below offers the flush back with a condition.

## 2. Tests

| Suite | Result | Log |
|---|---|---|
| `tests/aitools-entry/test-console-mode-guard.ps1` (stdin a pipe: Claude Code) | 47 passed, 0 failed, 3 skipped (the 3 `console:` cases: "this suite's stdin is not a console"), exit 0, 2.1 s | `guard-test-1.log`, `guard-test-final.log` |
| same, run inside a driver-owned console (`target-suite.ps1`) | **50 passed, 0 failed, 0 skipped**, exit 0 | `result-suite-console.log` |
| `tests/logging/test-logging.ps1` | 20 passed, 0 failed, 0 skipped, exit 0 | `suite-logging.log` |
| `tests/managed-files/test-managed-files.ps1` | 56 passed, 0 failed, 0 skipped, exit 0, 43 s | `suite-managed-files.log` |

The managed-files interactive cases did NOT skip: pywinpty is importable on this machine
(`probe-pty.ps1`: python3 = `C:\Program Files\PyManager\python3.exe` 3.14.6, `winpty` from
`C:\Users\jdpal\AppData\Roaming\Python\Python314\site-packages\winpty\__init__.py`, pywinpty 3.1.2).
I did not install it; who did is unknown. So cases 21-56 ("EOF at a prompt", adopt, merge & adopt,
abort, json per-field, display ...) ran on ConPTY against the new Read-ConsoleChoice and passed.

New checks in test-console-mode-guard.ps1 (beyond the kept no-console Save/Restore and Step 2 checks):
lib defines each helper once; aitools.ps1 defines none and compiles no console type; one console type in
the lib; the C# source declares `Get`, `Set(long m)`, `EnterCooked` and sets `(m | ProcessedInput |
LineInput | EchoInput) & ~VirtualTerminalInput`; Initialize returns before Add-Type off Windows / with
redirected stdin; Read-ConsoleChoice structure (EnterCooked before the try, ReadLine inside the try,
`[AitConsoleInput]::Set($saved)` in the finally with the variable EnterCooked assigned); EOF returns ""
+ the warn line + one warning; piped `o` returns `o` with no warning; the type is not loaded by
Save/Restore or by either read with redirected stdin; the type (compiled from the lib's own source)
exposes Get/Set/EnterCooked, and without a console Get=-1, Set(503)=Win32 error, Set(-1)=87,
EnterCooked=-1 with LastError set; with a console: Initialize compiles, EnterCooked turns on
0x7 and clears 0x200, Set(previous) restores; the lib is dot-sourced (`. $aitoolsLib`) before the
build-deploy pipeline.

## 3. Mutations (`mutate.ps1` -> `mutate.log`; temp tree copies, worktree untouched)

| Mutation | Result | Failing checks |
|---|---|---|
| M0 none (control) | exit 0, 47/0/3 | -- |
| M1 finally does not restore (`$rc = [AitConsoleInput]::Set($saved)` -> `$rc = 0`) | exit 1, 45/2/3 | "the finally block puts the saved mode back"; "Set in the finally restores the mode EnterCooked returned" |
| M2 no EnterCooked (`::Get()` instead) | exit 1, 44/3/3 | "EnterCooked() is called"; "EnterCooked runs before the try"; "Set in the finally restores the mode EnterCooked returned" |
| M3 EnterCooked without ECHO | exit 1, 46/1/3 | "EnterCooked sets PROCESSED \| LINE \| ECHO and clears VIRTUAL_TERMINAL_INPUT" |
| M4 Initialize compiles with redirected stdin | exit 1, 43/4/3 | "compiles nothing off Windows or with redirected stdin"; "Initialize-AitConsoleInput returns False"; "not loaded by Save/Restore or the read"; "piped: AitConsoleInput is not loaded" |
| M5 ReadLine moved out of the try | exit 1, 46/1/3 | "[Console]::ReadLine() runs inside the try" |
| M6 origin/main aitools.ps1 (own copies) + new lib | exit 1, 45/2/3 | "entry: defines none of the console helpers" (Save-, Restore-ConsoleInputMode); "entry: compiles no console type of its own" |
| M7 before: origin/main lib + origin/main aitools.ps1 | exit 1, 14/28/3 | every lib/type/read check and the child (Save-ConsoleInputMode not in the lib) |
| M8 origin/main lib + new aitools.ps1 | exit 1, 16/26/3 | same as M7 minus the two entry checks |

## 4. Real-console before/after (driver-owned minimized consoles only; `run-evidence.ps1` -> `evidence-run.log`)

Harness copied from M3b-Finish-R (`drv.ps1`, `conmode.cs.ps1`, `setraw.ps1`, unchanged); targets
written here (`target-cook.ps1`, `target-guard.ps1`, `target-timing.ps1`, `target-redir.ps1`,
`tcommon.ps1`). "main" = origin/main e8ebd07 lib (`origin-aitools-lib.ps1`, via `git show`); "new" =
the worktree lib. Driver steps: wait READY, 500 ms, mode, send `o<CR>`, 1.5 s, peek, second `o<CR>`
only if GOT not yet logged, wait DONE, mode, peek.

### 4a. A child leaves the console raw, then one Read-ConsoleChoice

| Run | Child left | Mode during read | `o<CR>` sent | Returned | Echo on screen | Mode after |
|---|---|---|---|---|---|---|
| cook-main-2E8 | 0x2E8 | 0x2E8 | 2 | `[o]` after 2076 ms | none | 0x2E8 |
| cook-main-208 | 0x208 | 0x208 | 2 | `[o]` after 2090 ms | none | 0x208 |
| cook-new-2E8 | 0x2E8 | **0xEF** | **1** | `[o]` after 536 ms | `choice [o/s]: o` | 0x2E8 (restored) |
| cook-new-208 | 0x208 | **0xF** | **1** | `[o]` after 553 ms | `choice [o/s]: o` | 0x208 (restored) |

In the "new" runs nothing was compiled before the read (`type AitConsoleInput loaded before the read:
False`), so the 536 / 553 ms include the lazy cold compile inside the first Read-ConsoleChoice plus the
driver's 500 ms wait.

Verbatim, cook-main-2E8:
```
17:58:05.216 CHILD pid 30704: conin=False stdinRedirected=False before=0x1F7 set 0x2E8 ok=True after=0x2E8
17:58:05.301 READY
17:58:05.829 DRIVER MODE 0x2E8
17:58:05.831 DRIVER sends o<CR>
17:58:07.355 DRIVER PEEK 1 mode=0x2E8 screen:   choice [o/s]:
17:58:07.375 DRIVER sends o<CR>
17:58:07.380 GOT [o] after 2076 ms
```
Verbatim, cook-new-2E8:
```
17:58:13.514 type AitConsoleInput loaded before the read: False
17:58:13.914 CHILD pid 42420: conin=False stdinRedirected=False before=0x1F7 set 0x2E8 ok=True after=0x2E8
17:58:14.012 READY
17:58:14.538 DRIVER MODE 0xEF
17:58:14.540 DRIVER sends o<CR>
17:58:14.551 GOT [o] after 536 ms
17:58:14.561 mode after Read-ConsoleChoice (AitConsoleInput::Get): 0x2E8
17:58:16.054 DRIVER PEEK 1 mode=0x2E8 screen:   choice [o/s]: o
17:58:16.064 DRIVER skip send (GOT seen)
[2026-11-14T01:58:14Z] [m3bc1-cook-new-2E8] [detail] console input mode 0x2E8 at prompt (line input or echo off) -- read in cooked mode
```
Verbatim, cook-new-208:
```
17:58:17.313 CHILD pid 25624: conin=False stdinRedirected=False before=0x1F7 set 0x208 ok=True after=0x208
17:58:17.950 DRIVER MODE 0xF
17:58:17.951 DRIVER sends o<CR>
17:58:17.967 GOT [o] after 553 ms
17:58:17.977 mode after Read-ConsoleChoice (AitConsoleInput::Get): 0x208
17:58:19.471 DRIVER PEEK 1 mode=0x208 screen:   choice [o/s]: o
[2026-11-14T01:58:17Z] [m3bc1-cook-new-208] [detail] console input mode 0x208 at prompt (line input or echo off) -- read in cooked mode
```

### 4b. aitools.ps1 Step 2 pattern: Save / child (pipe stdin, opens CONIN$, leaves 0x2E8) / Restore in finally, then a read

| Run | Save (cold compile) | Child left | Restore returned | Mode after restore | Types loaded | Read |
|---|---|---|---|---|---|---|
| guard-main-2E8 (origin lib + Save/Restore AST-extracted from origin aitools.ps1) | 122.7 ms, Mode=0x1F7 | 0x2E8 | `restored` (4.06 ms) | 0x1F7 | AitConsoleModeGuard only | `[o]` first key |
| guard-new-2E8 (worktree lib) | 149.3 ms, Mode=0x1F7 | 0x2E8 | `restored` (4.03 ms) | 0x1F7 | AitConsoleInput only (also after the read: one compile per process) | `[o]` first key, echoed |

Verbatim, guard-new-2E8:
```
17:58:24.150 Save-ConsoleInputMode (cold compile) 149.3 ms: Mode=0x1F7 Reason=console
17:58:24.528 CHILD pid 33840: conin=True stdinRedirected=True before=0x1F7 set 0x2E8 ok=True after=0x2E8
17:58:24.617 child exit=0
17:58:24.622 Restore-ConsoleInputMode returned [restored] in 4.03 ms
17:58:24.630 mode after restore (AitConsoleInput::Get): 0x1F7
17:58:24.636 console types loaded: AitConsoleModeGuard=False AitConsoleInput=True
17:58:25.236 GOT [o] after 580 ms
17:58:25.245 console types loaded after the read: AitConsoleModeGuard=False AitConsoleInput=True
17:58:26.741 DRIVER PEEK 1 mode=0x1F7 screen:   choice [o/s]: o
[2026-11-14T01:58:24Z] [m3bc1-guard-new-2E8] [detail] console input mode 0x2E8 after build-deploy, restored 0x1F7
```
The deploy.log line is byte-identical in form to main's
(`[detail] console input mode 0x2E8 after build-deploy, restored 0x1F7`).

### 4c. Redirected stdin (`target-redir.ps1`)

| Run | Read-ConsoleChoice | Type loaded | Save / Restore | Counters |
|---|---|---|---|---|
| redir-main-piped | `[o]` in 3.24 ms | False | not in this lib | errors=0 warnings=0 |
| redir-main-eof | `[]` in 23.19 ms | False | not in this lib | errors=0 warnings=1 |
| redir-new-piped | `[o]` in 21.01 ms | False | Mode=-1 Reason=not a console / `not a console`; type still not loaded | errors=0 warnings=0 |
| redir-new-eof | `[]` in 24.92 ms | False | same | errors=0 warnings=1 |

Verbatim, redir-new-eof:
```
17:58:30.667 Read-ConsoleChoice returned [] in 24.92 ms
17:58:30.676 AitConsoleInput type loaded: False
17:58:30.686 Save-ConsoleInputMode: Mode=-1 Reason=not a console
17:58:30.699 Restore-ConsoleInputMode: not a console
17:58:30.706 AitConsoleInput type loaded after Save/Restore: False
17:58:30.715 counters: errors=0 warnings=1
[2026-11-14T01:58:30Z] [m3bc1-redir-new-eof] [warn] No input at prompt (EOF) -- defaulting to overwrite
[2026-11-14T01:58:30Z] [m3bc1-redir-new-eof] [detail] console input mode around test: not guarded (not a console)
```
Console output of the EOF run (both libs): `<CR><LF>[...] [warn] No input at prompt (EOF) -- defaulting
to overwrite<CR><LF>`. (In `evidence-run.log` each redir run's "console output" line is printed just
above its own `===` header -- an ordering quirk of `run-evidence.ps1`, not of the code.)

## 5. Timings

| What | Value | Source |
|---|---|---|
| Cold `Initialize-AitConsoleInput` (Add-Type) | 126.9 ms, 118.0 ms | result-timing-1/-2.log |
| Cold compile inside the first `Save-ConsoleInputMode` | 149.3 ms (new), 122.7 ms (main's AitConsoleModeGuard) | result-guard-*.log |
| Warm `Initialize-AitConsoleInput` | 0.822 ms, 0.825 ms | result-timing-*.log |
| Warm `EnterCooked` + `Set` | 0.085 / 0.086 ms each (x50) | same |
| Warm `Save` + `Restore` (one detail log line each) | 0.714 / 0.605 ms each (x50) | same |
| `Restore-ConsoleInputMode` after a raw child | 4.06 ms (main), 4.03 ms (new) | result-guard-*.log |
| Read-ConsoleChoice, redirected stdin | 21.01 ms piped, 24.92 ms EOF (new); 3.24 / 23.19 ms (main) | result-redir-*.log |

Compile count per `aitools` run: origin/main compiles one type (AitConsoleModeGuard, Step 2 only;
its Read-ConsoleChoice compiles nothing). This change compiles one type (AitConsoleInput) shared by
Step 2 and every Read-ConsoleChoice in that process. Each setup script is its own pwsh process, so a
setup script that shows a menu in a console pays one cold compile (~120-150 ms here) on its first
prompt; with redirected stdin it pays nothing.

## 6. Not run

- `aitools`, `aitools install`, setup-user-*, deploy-harness, build-deploy.sh (any HOME); check-pre-commit /
  check-post-push / check-pre-push (pre-push step 7 rebuilds the dotprofile deploy/; `inline_lib_ps1`
  copies the whole lib with no markers, `scripts/build-deploy.sh` lines 165-187, so the new section
  needs nothing there -- read, not run).
- Typeahead behaviour (keys typed before the prompt) in a real console: not driven.
- `FlushConsoleInputBuffer` variant against the pty suite (deviation reason 2 is a timing argument, not a
  measured CI failure).
- macOS / Linux (the suite's non-Windows SKIP paths were not executed); PowerShell 5.1; mintty; CI.
- No bash change (decision from M3b-Finish-R section 4); `scripts/aitools-lib.sh` untouched.

## 7. Observations

- pywinpty 3.1.2 is installed in the user site-packages although the mission brief says it awaits the
  commander's approval; the managed-files pty cases therefore ran locally.
- The removed aitools.ps1 comment referred to "the lib's AitConsoleIn (Read-ConsoleChoice)"; no such
  type exists in origin/main's lib (stale reference, now gone).
- aitools.ps1 dot-sources the lib (line ~543 now) before `git pull` in Step 1, and the running
  aitools.ps1 is the installed `~/.local/bin` copy. A NEW installed aitools.ps1 with an OLD repo lib
  (repo checked out back to before this change) would fail at Step 2 with "Save-ConsoleInputMode is not
  recognized". An OLD installed aitools.ps1 with the NEW lib works: the lib's functions replace its
  copies when the lib is dot-sourced.
