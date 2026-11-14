## Summary

- **Fix 1, console input mode:** `Read-ConsoleChoice` now reads in cooked console mode. If a child process (Git Bash/MSYS, a node CLI) left the Windows console raw, the menu used to need two Enters, showed nothing as you typed, and the extra key fell into the next menu, whose default is overwrite. Now the first answer is accepted and echoed, and the previous mode is put back afterwards.
- **One shared console helper:** a single `AitConsoleInput` type in `aitools-lib.ps1` serves `Read-ConsoleChoice` and `Save-/Restore-ConsoleInputMode`. The latter two move out of `aitools.ps1`, so a run compiles one type instead of two.
- **Fix 5, AI-merge spinner:** the spinner now draws on Windows. It used to run in `Start-Job`, a separate process with no console, so nothing ever appeared. It now runs in a second runspace of the same process, at parity with bash `_start_spinner`. `Invoke-AI` telemetry is file-only (`Write-AiLog`, the twin of bash `_ai_log`), so it no longer prints into the spinner row.
- **Menu contract (PR #146):** `read_tty_choice` / `Read-ConsoleChoice` now set the EOF flag that `read_menu_choice` / `Read-MenuChoice` asked for (`READ_TTY_EOF=1` / `$script:ReadConsoleEof = $true`).
- **Bash:** no change for fixes 1 and 5. Git Bash keeps its own terminal state, so a raw Windows console does not affect `read_tty_choice`, and `_start_spinner` already draws through `/dev/tty`.

## Why

Session 87795dc3 (2026-11-13), commander: "launch mission to create all other fixes in its own worktree". Fixes 1 and 5 were held back from #144 because they touch `aitools-lib.*`, which #145 (json-review) owned until it merged.

## Changes

| File | Change |
|---|---|
| `scripts/aitools-lib.ps1` | New "Console input mode helper (Windows only)": the `AitConsoleInput` type (`Get`, `Set`, `EnterCooked`, `LastError`), compiled lazily once per process, and only on Windows with a console as stdin (`Initialize-AitConsoleInput`). `Save-/Restore-ConsoleInputMode` moved here with the same return values and log lines. `Read-ConsoleChoice`: `EnterCooked` before the read, the restore in `finally`, the EOF flag; EOF contract unchanged. Spinner: in-process runspace; no-op when stdout is redirected or the session is not interactive; Stop is synchronous and disposes. `Write-AiLog` added; `Invoke-AI`'s 7 telemetry lines use it. `Invoke-AiMerge`: `Stop-AiSpinner` in `finally` around `Invoke-AI`. |
| `scripts/aitools.ps1` | Its own `Save-/Restore-ConsoleInputMode` and the `AitConsoleModeGuard` type are removed; Step 2 uses the lib's helpers (the lib is dot-sourced before Step 2). |
| `scripts/aitools-lib.sh` | `read_tty_choice` sets `READ_TTY_EOF`; header comments. |
| `tests/aitools-entry/test-console-mode-guard.ps1` | 18 → 83 checks, still one file under the existing Windows CI step. |
| `reference/cross-platform-detail.md` | New section "Windows console: input mode, jobs, spinner" (v1.0). |
| `reference/agentic-framework.md`, `reference/script-standards-detail.md` | PowerShell telemetry is `Write-AiLog`, not `Log`. |

## Verification (Windows 11, pwsh 7)

**Real console** (key injection into consoles the harness started; a child process leaves the input mode at 0x2E8 or 0x208)

| Run | Mode during read | `o<CR>` needed | Echo | Mode after |
|---|---|---|---|---|
| origin/main, 0x2E8 | 0x2E8 | 2 (2076 ms) | none | 0x2E8 |
| origin/main, 0x208 | 0x208 | 2 (2090 ms) | none | 0x208 |
| this PR, 0x2E8 | 0xEF | 1 (536 ms) | yes | 0x2E8 (restored) |
| this PR, 0x208 | 0xF | 1 (553 ms) | yes | 0x208 (restored) |

- Step 2 pattern (Save, then a child that opens `CONIN$` and leaves 0x2E8, then Restore): `restored`, mode 0x1F7, and only `AitConsoleInput` loaded.
- Spinner, origin/main: three screen reads show no frame (the job runs in a separate process with no console window and redirected output). With a stub `claude`, the telemetry line appears on screen.
- Spinner, this PR: frames on screen (`| merging test...`, `- merging test...`); after Stop the line is cleared, and the next `Read-ConsoleChoice` takes the first `y<CR>`. Telemetry is in deploy.log only.
- Under the pty harness on the real `[m]erge & adopt` path: 11 frames and 0 telemetry lines on the terminal (origin/main: 0 frames, 2 lines).
- An error thrown inside `Invoke-AI`, or Ctrl+C at a pwsh prompt, used to leave the spinner drawing; with the `finally` it stops.

**Timings**
- One shared Add-Type: 118–150 ms cold, about 0.8 ms warm.
- Spinner Start: 7.5–9 ms (Start-Job: 145 ms). Stop: about 8 ms.

**Tests**
- `test-console-mode-guard.ps1`: 76/0/7 with stdin piped; the 7 are console-only checks. 81/0/0 inside a console, before the 2 EOF-flag checks were added.
- 17 mutations (cooked mode, restore, Start-Job, Dispose, telemetry, finally, ...): each one fails the suite.
- `test-logging.ps1` 20/0/0, `test-managed-files.ps1` 56/0/0 (pty cases ran), `test-adopt-push.ps1` 22/0/0.

**Full local run at 7fecf4f** (origin/main a98208e + this branch)
- All 38 tracked suites exit 0 with 0 failed cases: 2,899 passed, 57 platform skips. They ran the way the Windows CI job runs them, with an isolated HOME. Among them: menus sh 61/0/0 (ConPTY) and ps1 63/0/0, managed-files sh 79/0/3 and ps1 56/0/0, user-init 179/0/1, deploy-harness 99/0/2, profile 716/0/0.
- Isolated `build-deploy.sh` (scratch HOME and a dotprofile clone): 50 scripts. `bash -n` passes on 24/24 and the pwsh parser on 25/25. All 23 lib-inlining `.ps1` contain `AitConsoleInput` and `Write-AiLog`.
- Check scripts (`.ps1`, native pwsh, isolated HOME):
  - pre-commit: 1 FAIL, step 20, dead path refs on main in files this PR does not touch (`CLAUDE.md:100`, `reference/cursor-practices.md:43`, `reference/tool-registry.md:341,354`, `shared/claude-shared.md:95`).
  - pre-push: 0 FAIL (step 7 PASS); WARNs on steps 1, 5 (no RELEASE_NOTES) and 6.
  - post-push: FAIL step 1 (branch != main) and step 3 (MCP files absent from the isolated HOME).
- CI on PR #147: every job green. On Windows: console-mode-guard 76/0/7, menus ps1 63/0/0, menus Git Bash ConPTY 61/0/0, managed-files ps1 56/0/0.

## Not run

- macOS/Linux locally (the bash change is the EOF flag only; CI runs the `tests/menus` pty EOF cases on both).
- PowerShell 5.1, mintty, Windows Terminal.
- A real `claude` / `agent` call (stub CLI only).
- `aitools` / `aitools install` against a real HOME (agents never run them).

## Review after (D-DEL5, old → new)

- `reference/cross-platform-detail.md`: none → new section "Windows console: input mode, jobs, spinner" v1.0 (console input mode belongs to the console; `Read-ConsoleChoice` cooked read; Start-Job has no console; the in-process spinner and file-only telemetry).
- `reference/agentic-framework.md` "File-only telemetry (bash)" → "File-only telemetry": "PS1 `Invoke-AI` uses standard `Log`" → "`Invoke-AI` uses `Write-AiLog` (file-only)".
- `reference/script-standards-detail.md`: "`_ai_log` (bash only)" → "`_ai_log` / `Write-AiLog`"; the PowerShell telemetry snippet `Log` → `Write-AiLog`; library table row adds `Write-AiLog`.
- Contracts:
  - `Read-ConsoleChoice` / `read_tty_choice` now also set the EOF flag (#146 "Contract change"); return values unchanged.
  - `Save-/Restore-ConsoleInputMode` now live in the lib; return values unchanged.
  - `Invoke-AI` no longer prints its telemetry to the console (deploy.log unchanged).
- Deviation from the proven prototype: typeahead is **not** flushed (`FlushConsoleInputBuffer` dropped). A cold compile takes 118–311 ms and the pty test driver sends keys after 0.4 s of quiet, so keys arriving during the compile would be lost.

## Follow-ups

- Bash spinner leak: `_start_spinner`'s subshell survives Ctrl+C (Git Bash: still drawing 2 s after SIGINT). Not verified on a real macOS/Linux tty. Suggested fix: exit the loop when the parent is gone, or a trap in `_invoke_ai_merge`.
- `Log` / `LogDetail` throw when deploy.log is locked, while `reference/logging.md` §5 says a failed log write is swallowed. Pre-existing; `Write-AiLog` copies the same write.
- Version skew: a newer installed `aitools.ps1` with an older repo lib (checked out back past this change) would fail at Step 2 with "Save-ConsoleInputMode is not recognized". An older `aitools.ps1` with the new lib works.
- Optional stty save/restore around `read_tty_choice` on macOS/Linux, once it can be tested on a real tty.
- `relay-outbound-prompt.ps1` does not read through `Read-ConsoleChoice`, so it gets no cooked-mode read.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
