# M3b-Finish-R findings v1.0 -- fix 5 (AI-merge spinner) and fix 1 (console input mode)

Session M3b-Finish-R, 2026-11-13 (local 16:33-16:39, UTC 2026-11-14T00:33Z-00:39Z), Windows 11
(10.0.26300), pwsh 7.6.10, Git for Windows bash. Research and prototypes only: no tracked file
was edited (`git -C <worktree> status --short` empty at the end).

All paths below are relative to
`C:\Users\jdpal\repos\aitools\.claude\worktrees\console-profile\.scratch\session-M3b-R\`.
Code read (not edited): worktree `scripts/aitools-lib.ps1` `Start-AiSpinner` / `Stop-AiSpinner` /
`Test-InteractiveConsole` / `Read-ConsoleChoice` / `Invoke-AiMerge` / `Invoke-AI` / `Log`;
`scripts/aitools-lib.sh` `_start_spinner` / `_stop_spinner` / `tty_interactive` / `read_tty_choice` /
`_invoke_ai_merge` / `_ai_log`; `scripts/aitools.ps1` `Save-ConsoleInputMode` /
`Restore-ConsoleInputMode` (type `AitConsoleModeGuard`). `aitools-lib.ps1` here is a COPY of the
worktree lib taken at the start of the mission.

## Summary

1. The current `Start-AiSpinner` never draws: the Start-Job child pwsh has no console window
   (`consoleWindow=0x0`) and a redirected stdout; four screen captures show no spinner text.
2. An in-process runspace prototype (`proto-spinner.ps1`) draws, stops in 6 ms with no runspace
   left, clears the line, and a following `Read-ConsoleChoice` reads `y` at the first Enter.
3. The fix-1 helper prototype (`proto-conin.ps1`, one type `AitConsoleInput`) makes the first
   `o<CR>` count after a child left the console at 0x2E8 or 0x208 (current code needs two), echoes
   it, and restores the child's mode; with redirected stdin it compiles nothing.
4. Bash: Git Bash `read -r < /dev/tty` is immune to a raw Windows console mode (MSYS keeps its own
   termios); on macOS/Linux a tty left raw does break the read (mechanism shown under the Cygwin
   termios emulation); no harness child is known to leave it raw; the guard is optional.
5. New risk found for fix 5: once the spinner draws, `Invoke-AI`'s console `Log` lines interleave
   with the frames (bash `_ai_log` writes the log file only).

## 1. Spinner evidence (fix 5)

Harness: `drv.ps1` starts a minimized `pwsh` in its own new console running the target, attaches to
that console only (AttachConsole on the PID it started), and runs the steps: `peek` = last 4 screen
rows via `ConMode.ScreenTail` + CONIN$ mode; `send` = WriteConsoleInputW. Target `target-spin.ps1`
(isolated HOME/USERPROFILE = `home\`, AITOOLS_LOG_DIR = `logs\spin-<variant>\`, dot-sources the lib
copy, `Start-AiSpinner "merging test..."`, READY, 4 s, `Stop-AiSpinner`, STOPPED, then
`Read-ConsoleChoice`).

### 1a. Current code (Start-Job) -- `result-spin-job.log`, verbatim

```
16:33:04.176 Start-AiSpinner returned after 141 ms
16:33:04.186 job state after start: Running
16:33:04.190 READY
16:33:04.670 DRIVER PEEK 1 mode=0x1F7 screen: line before the spinner
16:33:05.587 DRIVER PEEK 2 mode=0x1F7 screen: line before the spinner
16:33:06.914 DRIVER PEEK 3 mode=0x1F7 screen: line before the spinner
16:33:08.211 runspaces while spinning: 1:Opened/Available,2:Opened/Busy
16:33:08.233 job state before stop: Running; child job state: Running
16:33:08.258 Receive-Job -Keep: 0 chars: []
16:33:08.294 job error stream: []
16:33:08.340 Stop-AiSpinner returned after 32 ms
16:33:08.364 STOPPED
16:33:08.739 DRIVER PEEK 4 mode=0x1F7 screen: line before the spinner ||     answer:
```

Verdict: **does not draw.** Why -- `result-jobprobe.log` (`target-jobprobe.ps1`, a Start-Job that
reports on itself, run in a driver-owned console):

```
16:33:23.009 parent pid 46564: stdout redirected=False
16:33:23.627 job says: job pid=17444 stdoutRedirected=True stdinRedirected=True consoleWindow=0x0
16:33:23.628 job says: after Console.Write
```

The job runs in another pwsh process with no console and a redirected stdout; its
`[Console]::Write` frames go nowhere visible (not even to Receive-Job: 0 chars).

### 1b. Prototype (in-process runspace) -- `result-spin-rs.log`, verbatim

```
16:33:28.134 Start-AiSpinner returned after 21 ms
16:33:28.141 READY
16:33:28.612 DRIVER PEEK 1 mode=0x1F7 screen: line before the spinner ||   \ merging test...
16:33:29.527 DRIVER PEEK 2 mode=0x1F7 screen: line before the spinner ||   \ merging test...
16:33:30.851 DRIVER PEEK 3 mode=0x1F7 screen: line before the spinner ||   - merging test...
16:33:32.150 runspaces while spinning: 1:Opened/Available,2:Opened/Busy
16:33:32.159 Stop-AiSpinner returned after 6 ms
16:33:32.169 spinner invocation IsCompleted after stop: True
16:33:32.174 runspaces after stop: 1:Opened/Available
16:33:32.179 STOPPED
16:33:32.552 DRIVER PEEK 4 mode=0x1F7 screen: line before the spinner ||     answer:
16:33:32.553 DRIVER sends y<CR>
16:33:32.561 Read-ConsoleChoice returned [y] after 378 ms
16:33:32.850 DRIVER PEEK 5 mode=0x1F7 screen: line before the spinner ||     answer: y
```

(PEEK 3 in the raw log carries trailing blanks after `merging test...`; cause unknown, cosmetic.)
Draws; frames change between samples; after Stop the spinner row is cleared (PEEK 4 shows only the
next prompt, written after the `\r  \e[K` clear, so it starts with 4 blanks -- same as bash, whose
clear also leaves 2 blanks); the runspace is gone and the invocation completed; the next read takes
the first Enter (378 ms = the driver's 300 ms wait + send).

### 1c. Prototype, script ends without Stop -- `result-spin-leak.log`

```
16:33:40.133 Start-AiSpinner returned after 7 ms
16:33:40.706 DRIVER PEEK 1 mode=0x1F7 screen: line before the spinner ||   \ merging test...
16:33:41.654 EXITING without Stop-AiSpinner
16:33:41.817 DRIVER EXITED code=0
```

A forgotten spinner does not keep the process alive (exit 163 ms after `exit 0`). It does keep
drawing until the process ends, so `Invoke-AiMerge` should stop it in a `finally` (today
`Start-AiSpinner ... Invoke-AI ... Stop-AiSpinner` has no try/finally).

### 1d. Redirected stdin + stdout -- `run-spin-redir.ps1` output, verbatim

```
=== variant rs (exit 0, 5215 ms)
captured stdout+stderr (37 chars): [line before the spinner<CR><LF>  answer: <CR><LF>]
contains 'merging test': False
...
16:33:49.510 Start-AiSpinner returned after 2 ms
16:33:53.535 Stop-AiSpinner returned after 0 ms
=== variant job (exit 0, 5342 ms)
captured stdout+stderr (44 chars): [line before the spinner<CR><LF><CR><LF>  <ESC>[K  answer: <CR><LF>]
```

The prototype is a no-op when stdout is redirected (no frames, no clear sequence in the pipe). The
current code writes `\r  \e[K` into a redirected stdout on Stop. Note `UserInteractive=True` even
when both streams were redirected, so the gate that matters is `[Console]::IsOutputRedirected`.

### 1e. New risk: Invoke-AI console log lines interleave -- `result-spin-rslog.log`, verbatim

Target variant `rslog` calls `Log "AI invocation: speed=balanced backend=claude attempt=1"` 900 ms
after Start-AiSpinner, which is what `Invoke-AI` does (`Log` -> `Write-Host`, aitools-lib.ps1
`Invoke-AI`, "AI invocation: speed=$Speed backend=$cliCmd attempt=$attempt"):

```
16:38:42.916 DRIVER PEEK 2 mode=0x1F7 screen: line before the spinner ||   / merging test...[2026-11-14T00:38:42Z] [m3br-spin-rslog] [info] AI invocation: speed=balanced backend=claude attempt= || 1 ||   | merging test...
```

The log line is appended to the spinner row and the next frame redraws on the following row. In
bash `_ai_log` writes only to `$LOG_FILE` (aitools-lib.sh `_ai_log`), so the bash spinner has no
such collision. Suggested resolution for the fix-5 batch: make Invoke-AI's telemetry file-only
(a PS `_ai_log` twin, parity with bash; levels and texts unchanged), or accept the interleave.

### 1f. Prototype code -- `proto-spinner.ps1`

Runspace via `[powershell]::Create()` + `BeginInvoke()` (no module; Start-ThreadJob not needed and
not checked further). Loop `do { [Console]::Write("`r  $c $msg") } while (-not $stop.Wait(200))`
on a `ManualResetEventSlim`. Stop: `Set()`, wait up to 2 s (`PowerShell.Stop()` after that),
`EndInvoke`, dispose runspace/PowerShell/event, then `[Console]::Write("`r  `e[K")`. Start calls
Stop first (one spinner at a time). Gate: no-op when `[Console]::IsOutputRedirected` or not
`[Environment]::UserInteractive`.

Parity with bash `_start_spinner` / `_stop_spinner`: same frame text `\r  <c> <msg>`, same chars
`/-\|`, same 200 ms period, same clear `\r  \e[K`. Differences that stay: bash writes `/dev/tty`
(draws even when stdout is redirected, as long as a terminal exists); PS writes stdout like the
rest of `Invoke-AiMerge` and skips when it is redirected. Bash `_stop_spinner` clears the line even
when no spinner ran; the prototype clears only when one ran.

## 2. Fix 1 -- console input mode around Read-ConsoleChoice

Target `target-cook.ps1`: a CHILD (`setraw.ps1`, copied from M3-B) sets this console's input mode
to 0x2E8 or 0x208 and exits without restoring; the target then prompts `choice [o/s]:` and calls
`Read-ConsoleChoice "overwrite"`. Driver: `mode`, `send o<CR>`, 1.5 s, `peek`, a second `o<CR>`
only if the first was not read (`sendunless:GOT`). Runner `run-cook.ps1`.

| Run (`result-cook-*.log`) | Child left | Mode during read | `o<CR>` sent | Returned | Echo on screen | Mode after |
|---|---|---|---|---|---|---|
| current-2E8 | 0x2E8 | 0x2E8 | 2 | `[o]` after 2050 ms | none (`  choice [o/s]:`) | 0x2E8 |
| current-208 | 0x208 | 0x208 | 2 | `[o]` after 2110 ms | none | 0x208 |
| proto-2E8 | 0x2E8 | **0xEF** | **1** | `[o]` after 573 ms | `  choice [o/s]: o` | 0x2E8 (restored) |
| proto-208 | 0x208 | **0xF** | **1** | `[o]` after 552 ms | `  choice [o/s]: o` | 0x208 (restored) |

Verbatim, current-2E8:
```
16:34:46.551 CHILD pid 29904: conin=False stdinRedirected=False before=0x1F7 set 0x2E8 ok=True after=0x2E8
16:34:47.152 DRIVER MODE 0x2E8
16:34:47.153 DRIVER sends o<CR>
16:34:48.668 DRIVER PEEK 1 mode=0x2E8 screen:   choice [o/s]:
16:34:48.685 DRIVER sends o<CR>
16:34:48.688 GOT [o] after 2050 ms
```
Verbatim, proto-2E8:
```
16:34:55.116 CHILD pid 32172: conin=False stdinRedirected=False before=0x1F7 set 0x2E8 ok=True after=0x2E8
16:34:55.196 mode after child: 0x2E8
16:34:55.759 DRIVER MODE 0xEF
16:34:55.761 DRIVER sends o<CR>
16:34:55.779 GOT [o] after 573 ms
16:34:55.786 mode after Read-ConsoleChoice: 0x2E8
16:34:57.289 DRIVER PEEK 1 mode=0x2E8 screen:   choice [o/s]: o
16:34:57.300 DRIVER skip send (GOT seen)
```

In the current runs the second `o<CR>` completed the first line; the commander's
investigation-findings.md explains the mechanism (.NET StreamReader receives `\r`, blocks for a
possible `\n`; the extra key stays buffered for the next prompt). Same result as the commander's
`result-nofix-0x2E8.log` / `result-fix-0x2E8.log`, now with a child process as the cause.

### 2a. Redirected stdin -- `run-redir.ps1` output, verbatim

```
=== piped (exit 0)
console output: []
16:35:25.219 Read-ConsoleChoice returned [o] in 18.66 ms
16:35:25.224 AitConsoleInput type loaded: False
16:35:25.232 Save-ConsoleInputMode: Mode=-1 Reason=not a console
16:35:25.239 Restore-ConsoleInputMode: not a console
16:35:25.243 AitConsoleInput type loaded after Save/Restore: False
=== eof (exit 0)
console output: [<CR><LF>[2026-11-14T00:35:25Z] [m3br-redir-eof] [warn] No input at prompt (EOF) -- defaulting to overwrite<CR><LF>]
16:35:25.566 Read-ConsoleChoice returned [] in 23.32 ms
16:35:25.571 AitConsoleInput type loaded: False
--- deploy.log lines:
[2026-11-14T00:35:25Z] [m3br-redir-eof] [warn] No input at prompt (EOF) -- defaulting to overwrite
[2026-11-14T00:35:25Z] [m3br-redir-eof] [detail] console input mode around test: not guarded (not a console)
```

Contract kept: piped line returned; EOF returns "" with
`LogWarn "No input at prompt (EOF) -- defaulting to $DefaultDesc"`; no Add-Type when stdin is
redirected.

### 2b. Prototype code -- `proto-conin.ps1`

- `Initialize-AitConsoleInput`: `$false` off Windows (`$PSVersionTable.PSVersion.Major -ge 6 -and
  -not $IsWindows`, the guard aitools.ps1 already uses) or with redirected stdin; otherwise compiles
  `AitConsoleInput` once (try/catch -> LogDetail + `$false`).
- `AitConsoleInput` (one Add-Type): `Get()` (mode or -1), `Set(long)` (0 or Win32 error),
  `EnterCooked()` (GetConsoleMode; FlushConsoleInputBuffer; SetConsoleMode((m|0x1|0x2|0x4)&~0x200);
  returns m or -1).
- `Read-ConsoleChoice`: `EnterCooked` when initialized, `[Console]::ReadLine()` in try, `Set(saved)`
  in finally; EOF branch unchanged.
- `Save-ConsoleInputMode` / `Restore-ConsoleInputMode`: the aitools.ps1 functions moved onto the
  shared type, same return objects and strings, except an Add-Type failure returns Reason
  `"unavailable"` (the message goes to LogDetail) where aitools.ps1 returns `"unavailable: <msg>"`.

Load order fact for the implementer: aitools.ps1 defines its `Save-/Restore-ConsoleInputMode` at
its line ~164 and dot-sources the lib at line ~607 (`. $aitoolsLib`), so lib functions of the same
name REPLACE the aitools.ps1 ones for the rest of the run. And aitools.ps1 is installed as a copy in
`~/.local/bin` (aitools-install.ps1 "Install PowerShell aitools.ps1") while the lib comes from
`repoPath`, so an installed aitools.ps1 and the repo lib can be at different versions (see open
question 2).

## 3. Timings

| What | Value | Source |
|---|---|---|
| Start-Job spinner: Start-AiSpinner returns | 141 ms (console), 111 ms (redirected) | result-spin-job.log, run-spin-redir |
| Start-Job: first output from job | ~618 ms (23.009 -> 23.627) | result-jobprobe.log |
| Start-Job spinner: Stop-AiSpinner | 32 ms / 19 ms | same |
| Runspace prototype: Start | 21 ms, 22 ms, 7 ms (console); 2 ms (redirected, no-op) | result-spin-rs/-rslog/-leak, run-spin-redir |
| Runspace prototype: Stop | 6 ms, 6 ms; 0 ms (no-op) | same |
| AitConsoleInput cold Add-Type (first in process) | 137.2 ms, 138.3 ms | result-cook-proto-2E8/-208.log |
| (M3-B, AitConsoleModeGuard cold, during builds) | 294 ms, 311 ms | M3-Fixes-B-evidence.md |
| Initialize-AitConsoleInput warm | 0.854 ms, 0.779 ms | result-cook-proto-*.log |
| EnterCooked + Set, warm | 0.108 / 0.112 ms each (x50) | same |
| Read-ConsoleChoice, redirected stdin (first call) | 18.66 ms (piped), 23.32 ms (EOF) | run-redir output |

One shared type instead of two (`AitConsoleModeGuard` + `AitConsoleIn`/`AitConsoleInput`) saves one
cold compile per `aitools` run (137-311 ms measured).

## 4. Bash decision

### Callers (worktree, `scripts/`; `shared/` has none; `deploy/` is the frozen inlined copy)

| Caller | Function | Runs on Windows Git Bash? | Evidence |
|---|---|---|---|
| `scripts/aitools` profile migrate (`read_tty_choice answer "no"`), user init prompts (`read_tty_choice choice/UI_CHOICE/UI_NAME/UI_COMPANY/ans/v/UI_ID_COMPANY/alias/gh_user`) | read_tty_choice | **yes** | the extensionless bash entry point runs in Git Bash on Windows (cross-platform.md exemption "Entry points with Windows branches"); its Windows branches only swap the CHILD scripts to `.ps1` (`MINGW*|MSYS*|CYGWIN*` in user init writer/hook dispatch, `deploy_configs`, install forwarding) -- the prompts themselves are bash |
| `scripts/aitools-install.sh` repos-path prompt (`read_tty_choice user_path "~/repos"`) | read_tty_choice | no | "Windows forwarding" block near the top forwards to aitools-install.ps1 before the prompt; comment "Windows never reaches here" |
| `scripts/aitools-lib.sh` `prompt_diff_review` (`read_tty_choice choice "overwrite"`), `_invoke_ai_merge` (`_start_spinner`, `read_tty_choice feedback/accept`), the field-review prompt (`read_tty_choice choice "$default_desc"`) | both | no | reached only through `deploy_managed_file` / `sync_managed_json` from setup-user-claude/-cursor/-hooks/-skills/-settings.sh, deploy-harness.sh, aitools-profile.sh -- all have the POSIX OS guard (`MINGW*|MSYS*|CYGWIN*) ... exit 1`); on Windows `deploy_configs` runs the `.ps1` list |
| `scripts/setup-user-hooks.sh`, `setup-user-skills.sh` | read_tty_choice | no | POSIX OS guard |

### Windows Git Bash: no change needed -- `result-msys-none.log`, `result-msys-raw.log`

`target-msys.ps1` runs `msys-read.sh` (the exact read of `read_tty_choice`:
`IFS= read -r x < /dev/tty`) in a driver-owned console, after a child left the console at 0x2E8:

```
16:37:11.380 CHILD pid 43364: conin=False stdinRedirected=False before=0x1F7 set 0x2E8 ok=True after=0x2E8
16:37:12.706 DRIVER MODE 0x2E8
16:37:12.708 DRIVER sends o<CR>
16:37:12.729 MSYS GOT[o] rc=0 stdin-tty=yes
16:37:14.224 DRIVER PEEK 1 mode=0x2E8 screen:   msys prompt: o
16:37:15.760 DRIVER MODE 0x2E8
```

First key accepted and echoed. In the control (no raw child) the mode during the MSYS read was also
0x2E8 and returned to 0x1F7 after bash exited: MSYS reads the console raw and does its own line
editing from its termios state, so the Windows console mode a previous child left does not matter.

### macOS/Linux: the mechanism is real; no trigger is known

termios settings belong to the terminal device, so a program that exits (or is killed) in raw mode
leaves the terminal raw for the next reader. `help read` (bash) lists no option that changes the
terminal for a plain `read -r` (only `-s` "do not echo input coming from a terminal", `-e`
Readline). Shown under Git Bash's termios emulation (Cygwin), NOT on a macOS/Linux kernel tty
(no WSL distro, no pywinpty, no Mac here) -- `result-stty-plain.log` / `result-stty-guarded.log`
(`msys-stty.sh`: `stty raw -echo`, then the read):

```
=== stty-plain
16:38:02.638 STTY left raw: 0:8:bf:d18:0:f:0:0:4:7f:3:15:16:1:1c:12:11:13:1a:1a:0:17
16:38:03.484 DRIVER sends o<CR>
16:38:05.001 DRIVER PEEK 1 mode=0x2E8 screen:   stty prompt:
16:38:05.010 DRIVER sends <LF>
16:38:05.042 BASH GOT[ o \r] rc=0; stty after read equals raw state
=== stty-guarded
16:38:08.323 DRIVER sends o<CR>
16:38:08.376 BASH GOT[ o] rc=0; stty after read equals raw state
16:38:09.842 DRIVER PEEK 1 mode=0x1F7 screen:   stty prompt: o
```

Plain: Enter does not end the read, nothing echoes, and the answer is `o\r` -- in
`prompt_diff_review` that is not `o`, so the `*)` default (overwrite) would apply silently.
Guarded (`stty -g` save, `stty icanon echo icrnl`, read, `stty "$saved"`): first Enter accepted,
echoed, raw state restored.

Which harness children could leave a POSIX tty raw: unknown. The Windows trigger (MSYS console
churn during build-deploy, node CLIs at 0x208 while running -- commander's investigation-findings.md)
has no POSIX counterpart that I can cite.

**Recommendation:** no bash change is needed for fix 1 (Windows Git Bash is immune; bash setup
menus never run on Windows). The stty guard is optional defense for macOS/Linux; if taken (for
parity with the PS fix, since the failure there would be a silent overwrite), use
`proto-read-tty-choice.sh` and test it on a real macOS and Linux pty (CI runners, or pywinpty once
approved) -- the function form was only `bash -n` checked. No `_start_spinner` change is needed
(it already writes /dev/tty in-process).

## 5. Prototype files

| File | Proves / is |
|---|---|
| `proto-spinner.ps1` | fix-5 replacement Start-/Stop-AiSpinner (runspace) |
| `proto-conin.ps1` | fix-1 shared type `AitConsoleInput` + Initialize-AitConsoleInput, Read-ConsoleChoice, Save-/Restore-ConsoleInputMode |
| `proto-read-tty-choice.sh` | optional bash guard (function form; `bash -n` only) |
| `drv.ps1` | real-console driver (own console only; peek/mode/send/exit steps) |
| `tcommon.ps1` | isolated HOME/USERPROFILE/AITOOLS_LOG_DIR + lib copy load |
| `target-spin.ps1`, `run-spin-redir.ps1` | spinner variants job / rs / leak / rslog; redirected run |
| `target-jobprobe.ps1` | where Start-Job's Console.Write goes |
| `target-cook.ps1`, `run-cook.ps1`, `setraw.ps1` | fix-1 matrix with a raw-leaving child |
| `target-redir.ps1`, `run-redir.ps1` | fix-1 with piped / EOF stdin |
| `target-msys.ps1`, `msys-read.sh`, `run-msys.ps1` | Git Bash read after a raw console |
| `target-stty.ps1`, `msys-stty.sh`, `run-stty.ps1` | termios raw -> plain vs guarded read |
| `parse-check.ps1` | PS parser: all 19 .ps1 OK; `bash -n` OK on both .sh prototypes |

## 6. Risks

- **Flush drops typeahead** (`FlushConsoleInputBuffer`): keys typed before a prompt appears are
  discarded on Windows. Intended (stale keys from a raw-mode leak) but a behavior change; key
  injection tests (pywinpty, this driver) must send after the prompt is up. Bash does not flush.
- **Restore puts the raw mode back**: after the read the console is raw again (by design: leave it
  as found). Typing between prompts does not echo until the next Read-ConsoleChoice.
- **Uncovered reads**: `scripts/relay-outbound-prompt.ps1` uses `Read-Host` (not Read-ConsoleChoice);
  its behavior in a raw console is unknown (not tested).
- **Spinner/log interleave** (1e) and **no try/finally** around Invoke-AI in Invoke-AiMerge (1c).
- **Two threads write the console** while the spinner runs; frames and any other output on the
  main thread can interleave (bash has the same property with /dev/tty).
- **Version skew** between the installed `~/.local/bin/aitools.ps1` and the repo lib (2b).
- MSYS immunity was shown for `read < /dev/tty` in a conhost console; mintty (pty) was not tested
  (expected unaffected: no Windows console input there -- unverified).

## 7. Not run

- No `aitools`, `aitools install`, setup-user-*, deploy-harness or build-deploy.sh run; no install.
- No macOS/Linux test (no Mac, no WSL distro, pywinpty not installed).
- Start-ThreadJob availability not checked (runspace needs no module).
- `Read-Host` under raw mode; mintty; PowerShell 5.1.
- The prototypes were not run through the repo test suites (no tracked file changed).

## 8. Open questions (each with a suggested answer)

1. Make Invoke-AI telemetry file-only so the spinner row stays clean? Suggested: yes, a PS
   `_ai_log` twin writing deploy.log only (parity with bash `_ai_log`); the user-facing
   ">> AI merge: <backend> (balanced)" line already satisfies agentic-standards "Transparency".
2. Remove aitools.ps1's own Save-/Restore-ConsoleInputMode once the lib has them? Suggested: yes,
   but keep the call sites tolerant of an older lib (`Get-Command Save-ConsoleInputMode` check, or
   keep the aitools.ps1 copies until one release later), because the installed aitools.ps1 and the
   repo lib can differ.
3. Adopt the bash stty guard? Suggested: not in this batch; file it as a low-severity item and
   take it when a macOS/Linux pty test can verify it.
4. Wrap Start-/Stop-AiSpinner in try/finally in Invoke-AiMerge (and bash `_invoke_ai_merge` with a
   trap)? Suggested: PS yes (cheap); bash already continues on failure (`|| true`).
