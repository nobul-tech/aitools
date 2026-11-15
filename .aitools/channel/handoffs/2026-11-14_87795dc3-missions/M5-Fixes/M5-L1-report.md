# M5-L1 report -- library fixes: the AI-merge spinner, fail-safe log writes

**Version**: v1.0 (2026-11-14). **Author**: M5-L1, delegated by M5-Fixes
(delegated by Session Commander 87795dc3-e). **Branch**: `fix/m5-lib`, pushed;
no PR opened (M5-Fixes opens it).

## Summary

1. Item 1 fixed: the bash AI-merge spinner now stops when its script ends (owner-PID watch + INT/TERM/EXIT traps around `invoke_ai`); the PowerShell spinner did not have the defect.
2. Item 2 fixed: every `deploy.log` write in aitools-lib (bash and PowerShell) is fail-safe per `reference/logging.md` section 5; a failed write is swallowed silently, the console line prints, the counters count.
3. Both defects were reproduced before the fix; the new tests fail against origin/main (bash logging 12, PowerShell logging 4, spinner 9) and against a mutant without the owner watch (2).
4. Local (Windows): all touched suites pass; check-pre-commit fails only on the known step 20; check-pre-push 8 PASS / 2 WARN / 0 FAIL.
5. Commits `b699d3d` (item 1), `4cb0b46` (item 2), plus this report; macOS/Linux halves run only in CI (no CI run on a branch push; it starts with the PR).

## Item 1 -- spinner survives Ctrl+C: fixed

**Root cause.** `_start_spinner` (`scripts/aitools-lib.sh`) runs the spinner as a
background subshell (`( while true; ... ) &`). In a non-interactive shell,
background jobs start with SIGINT ignored (POSIX), so Ctrl+C ended the script
but not the spinner, which kept drawing on `/dev/tty` forever (`while true`, no
owner check, no trap). This is the M3b observation in Git Bash.

**Fix** (`scripts/aitools-lib.sh`):
- `_start_spinner`: captures the owner PID before the fork (`${BASHPID:-$$}`;
  bash 3.2 has no BASHPID, `$$` is the top shell) and loops `while kill -0 "$owner"`;
  when the owner is gone it clears its line and exits (covers SIGKILL). Draws
  are `|| :` and the subshell's stderr is /dev/null, so with no terminal it draws
  nothing and prints no shell error but stays alive. Starting a spinner stops a
  running one (parity with `Start-AiSpinner`).
- `_stop_spinner`: `kill ... || true` (the spinner may end between check and
  kill -- under `set -e` the bare `kill` could end the caller) and the line clear
  tolerates a missing terminal.
- New `_spinner_traps_set` / `_spinner_traps_restore` / `_spinner_on_signal` /
  `_spinner_on_exit`: around the `invoke_ai` call in `_invoke_ai_merge`. The
  caller's INT/TERM/EXIT traps are saved (`trap -p` written to a temp file, then
  read: I did not rely on `$(trap -p)` seeing the caller's traps on bash 3.2 --
  unverified there), and restored exactly after the call (idempotent). INT/TERM:
  stop the spinner, log `[detail] AI spinner stopped by <SIG>`, restore the
  caller's traps, re-send the signal to this shell (the caller's trap or the
  default action follows; bash then runs the caller's EXIT trap). EXIT: stop the
  spinner, log, run the caller's EXIT command (extracted from the saved
  `trap -- 'CMD' EXIT` line). No temp file: traps are skipped with a detail line;
  the owner watch still stops the spinner. Existing traps checked: no lib or
  setup script sets INT/TERM; several set EXIT (`deploy-harness.sh`,
  `setup-user-config.sh`, `setup-user-shell.sh`, `build-deploy.sh`, ...), which is
  why EXIT chains to the caller's command.

**PowerShell twin.** `Start-AiSpinner` runs in a second runspace of the same
process and `Invoke-AiMerge` calls `Stop-AiSpinner` in a `finally` around
`Invoke-AI`. Ctrl+C stops the pipeline and runs the `finally`; a killed process
takes its threads with it. Not the same defect (code reading; not exercised
with a real Ctrl+C). Unchanged.

**Evidence.** Tests added to `tests/menus/test-menu-choice.sh` (no pty needed,
so they run in every CI job of that suite, including macOS `/bin/bash` 3.2):
- `spinner (KILL|TERM of its shell): running before the kill` / `gone within 1 s`
  (the snippet `exec sleep 30`s so the PID stays its shell's; the test kills it in
  the background and polls)
- `spinner (INT|TERM trap): spinner gone when the script ends`, `stopped by the
  trap (logged)`, `the script ended at the signal`, `the caller's EXIT trap ran`
  (foreground run; SKIP if the signal is ignored at entry)
- `spinner (exit): gone, stopped by the EXIT trap, exit status kept` (exit 3), `the caller's EXIT command ran`
- `spinner (normal): stopped, the script went on`, `INT, TERM and EXIT traps restored exactly` (trap -p before/after compared with cmp), `the caller's EXIT trap still runs`
- Locally: 78 passed, 0 failed. Against origin/main lib: 9 failed. Against a
  mutant with `while true` instead of the owner watch: the 2 `gone within 1 s` cases fail.
- tty choice: no tty override variable was added. CI has no controlling
  terminal, so the spinner keeps its process alive without drawing, and the tests
  observe the process, not the frames. The existing pty case `merge preview: ...`
  still drives `_invoke_ai_merge` (with the traps) end to end.

## Item 2 -- a failed log write breaks a run: fixed

**Root cause.** `reference/logging.md` section 5: "**Fail-safe**: logging must
never crash the tool. A failed log write is swallowed (the only sanctioned
silent-suppression in the harness), because a broken log must not break the
operation it records." Section 5 names no warning for `deploy.log` (only the
section 3 table gives `deploy.jsonl` "one warning, then records are skipped"),
so the fix is a silent swallow. The code did not do it:
- PowerShell `Log`, `LogDetail`, `Write-AiLog` called `[IO.File]::AppendAllText`
  unguarded. Reproduced (`.scratch/session-M5-L1/repro-lock.ps1`): with deploy.log
  held `FileShare.None` by another process, `Initialize-Logging` printed a
  `MethodInvocationException`, a `Log` inside the caller's `try` jumped to its
  `catch`, and under `$ErrorActionPreference = "Stop"` the script would end.
  (`check-pre-commit.ps1`, `check-pre-push.ps1` etc. set `Stop`.)
- bash `log`, `log_detail`, `_ai_log` appended with a bare `>>`; under
  `set -euo pipefail` the first failed write ended the script, already inside
  `logging_init` (its environment `log_detail`). `mkdir -p "$LOG_DIR"` ended it
  when the directory could not be created. Reproduced
  (`.scratch/session-M5-L1/repro-unwritable.sh`): rc=1 for a directory as
  deploy.log, a log dir under a file, and `chmod 000` (Git Bash enforces it).
- `_rotate_log` / `Rotate-Log` were already fail-safe; `jsonl_record` /
  `Write-JsonlRecord` already handle their own failure (one warning, A-16).
  `Write-Summary` writes the run summary, not a log (logging.md section 3 lists no
  summary file): left unchanged.

**Fix.** `Add-AitLibLogText` (PS) / `_aitlib_log_append` (bash): one guarded
append used by `Log`, `LogDetail`, `Write-AiLog` / `log`, `log_detail`, `_ai_log`
(so `LogOk/LogWarn/LogError`, `log_ok/log_warn/log_error`). PS: `try { resolve;
AppendAllText } catch { $null = $_ }` -- also covers an unset `$logFile`. bash:
`{ printf ... >> "$2"; } 2>/dev/null || true`. `Initialize-Logging` wraps
`New-Item -ErrorAction Stop` in try/catch; `logging_init` uses
`mkdir -p ... 2>/dev/null || true`. Each suppression carries a comment citing
section 5. No exemptions-table row was added (section 5 is the sanction; the
table needs the commander's approval -- see open questions).

**Evidence.**
- `tests/logging/test-logging.ps1` (26 passed): `locked deploy.log -- no exception,
  the run goes on (exit 0)`, `-- console lines still printed (info, warn, error, ok)`,
  `-- LogError/LogWarn still count`, `-- detail and AI telemetry stay off the console`,
  `-- nothing written to it (the lock held)` (Windows only; SKIP elsewhere: .NET's
  non-Windows lock is advisory, not verified), `log dir cannot be created --
  Initialize-Logging and LogWarn go on`. The snippet runs under `Stop` inside a `try`.
- `tests/logging/test-logging.sh` (36 passed): for `deploy.log is a directory`,
  `deploy.log not writable (chmod 000)`, `log dir cannot be created`: set -e run
  goes on (exit 0), console lines still printed, counters still count, no shell
  error on the console. Under root, chmod 000 does not block the write; the
  checks still hold.
- Against origin/main: bash 12 failed, PowerShell 4 failed (`.scratch/session-M5-L1/old-lib-tree.sh`).
- CI: both suites already have steps (`check.yml`: "Logging unit tests (bash)" in
  the linux and macOS jobs, "Logging unit tests (bash, via Git Bash)" and
  "(PowerShell, native)" in the windows job). The menus suite already has steps in
  all three jobs (macOS also under /bin/bash 3.2). No check.yml change.

## Branch and commits

- `fix/m5-lib`, pushed to origin (tracking set).
- `b699d3d` Stop the bash AI-merge spinner when its script ends (Ctrl+C, TERM, kill)
- `4cb0b46` Make a failed deploy.log write never break a run (bash and PowerShell)
- report commit: see `git log` (this file)

## Files changed

- `scripts/aitools-lib.sh` (both items)
- `scripts/aitools-lib.ps1` (item 2)
- `tests/menus/test-menu-choice.sh` (item 1: spinner cases, header, --help range)
- `tests/logging/test-logging.sh`, `tests/logging/test-logging.ps1` (item 2)
- `reference/cross-platform-detail.md` (item 1), `reference/logging.md` (item 2)
- `RELEASE_NOTES.md`: new `## v0.77.1` entry (bug fixes 1-2, documentation 3-4) -- M5-L2 appends to it
- this report

## Verification (Windows 11, Git Bash 5.3, pwsh 7; all from the worktree)

| Command | Result |
|---|---|
| `pwsh -NoProfile -File .scratch/session-M5-L1/parse.ps1` (`bash -n` via Git Bash on aitools-lib.sh, test-logging.sh, test-menu-choice.sh; PS parser on aitools-lib.ps1, test-logging.ps1) | all OK |
| `bash tests/logging/test-logging.sh` | 36 passed, 0 failed |
| `pwsh -NoProfile -File tests/logging/test-logging.ps1` | 26 passed, 0 failed, 0 skipped |
| `bash tests/menus/test-menu-choice.sh` | 78 passed, 0 failed, 0 skipped (pty cases ran: pywinpty 3.1.2) |
| `pwsh -NoProfile -File tests/menus/test-menu-choice.ps1` | 63 passed, 0 failed |
| `bash tests/managed-files/test-managed-files.sh` | 79 passed, 0 failed, 3 skipped |
| `pwsh -NoProfile -File tests/managed-files/test-managed-files.ps1` | 56 passed, 0 failed |
| `bash tests/managed-files/test-adopt-push.sh` | 28 passed, 0 failed |
| `pwsh -NoProfile -File tests/managed-files/test-adopt-push.ps1` | 22 passed, 0 failed |
| `bash tests/os-guards/test-os-guards.sh` | 34 passed, 0 failed (windows, bash 5.3.15) |
| `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/check-pre-commit.ps1` (item 1 staged, then item 2 staged) | 1 FAIL each time: step 20, the 5 known dead path refs (M5-D1); WARN 3 build freshness (not run with -Fix: it builds against the real HOME), WARN 5 platform note (in the commit messages), WARN 11 dotprofile has uncommitted changes (not mine) |
| `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/check-pre-push.ps1` | 8 PASS, 2 WARN (steps 1 and 6, advisory), 0 FAIL; step 7 fresh build OK |

The bash suites ran in the Claude Code Bash tool, which is Git Bash here.

## Not run

- The macOS (bash 5 and /bin/bash 3.2) and Linux halves: CI only. `gh run list
  --branch fix/m5-lib` shows no run after the push; CI starts with the PR. The
  bash 3.2 path (`$$` instead of `BASHPID`, `trap -p` through a file) is
  exercised only by the macOS `/bin/bash` step of the menus suite.
- check-post-push (forbidden by the mission). A real Ctrl+C on a terminal (the
  tests use signals sent by `kill`, which is what the terminal does).

## Review after (D-DEL5: each change, old -> new)

1. bash spinner lifetime: ran `while true` until killed by `_stop_spinner` -> ends at the first 200 ms tick after the shell that started it is gone, clearing its line.
2. bash spinner without a terminal: each draw failed with a shell message on stderr (and under `set -e` the subshell ended at once) -> draws nothing, prints nothing, keeps watching.
3. `_start_spinner` with a spinner already running: started a second one -> stops the running one first (parity with `Start-AiSpinner`).
4. `_stop_spinner`: bare `kill` (could end a `set -e` caller if the spinner was already gone) and an unconditional `/dev/tty` write -> both tolerate failure.
5. `_invoke_ai_merge`: no traps -> INT/TERM/EXIT traps only while `invoke_ai` runs, the caller's traps saved and restored exactly; INT/TERM re-sent to the shell after the spinner stops; new detail lines `AI spinner stopped by INT|TERM`, `AI spinner stopped at exit`, `AI spinner: mktemp failed -- no INT/TERM/EXIT traps (...)`.
6. PS `Log`/`LogDetail`/`Write-AiLog` on a failed write: threw `MethodInvocationException` -> silent, via `Add-AitLibLogText`.
7. bash `log`/`log_detail`/`_ai_log` on a failed write: ended a `set -e` script with a shell error -> silent, via `_aitlib_log_append`.
8. `Initialize-Logging` / `logging_init` when the log dir cannot be created: error record / script end -> silent, the run continues.
9. `reference/logging.md` section 5: principle only -> also names the helpers and their guarantees, and the `deploy.jsonl` difference.
10. `reference/cross-platform-detail.md`: new paragraph "The bash spinner is a separate process".
11. `RELEASE_NOTES.md`: new v0.77.1 entry (items 1-4).
12. `tests/menus/test-menu-choice.sh`: 16 new spinner checks; `--help` prints lines 2-33 (was 2-29).
13. `tests/logging/test-logging.sh` / `.ps1`: 12 / 6 new checks.

## Reading done (honest account)

Read in full or in context: the user CLAUDE.md and user rules, every project
rule the prompt lists except `hook-lifecycle.md` (not opened), `reference/logging.md`,
the spinner section of `reference/cross-platform-detail.md`, the exemptions
table of `reference/script-standards-detail.md`, the `/scratch` skill, and all
code changed. Not read in full: `reference/script-standards-detail.md`,
`reference/managed-file-deployment.md`, `reference/pre-push-checklist.md`,
`.aitools/channel/CLAUDE.md` (seen only at the end). `/delegate` was not loaded:
no delegate was launched. No relay entry appended (the relay is a main-checkout
path; the learning below is for M5-Fixes to relay).

## WRITE_BLOCKED / CONFLICT / INCIDENT

- WRITE_BLOCKED: none.
- CONFLICT: the session's mode note allows Bash for file edits vs USO "Dedicated tools for file ops" -- resolved by tier 1 (the commander's CLAUDE.md): Read/Edit/Write/Grep used for every file operation.
- CONFLICT: the prompt suggested "e.g. a one-time console warning" vs `reference/logging.md` section 5 ("swallowed", no warning) -- resolved by tier 2 (the prompt itself says "implement exactly" what section 5 says): silent swallow, no warning.
- INCIDENT (for M5-Fixes to file via `/incident`, not filed by me): the same unguarded-log-write class remains outside aitools-lib -- `scripts/aitools-install.ps1` `Log` (`Add-Content`), `scripts/aitools-install.sh` `log` (`| tee -a` under pipefail), `scripts/aitools-profile.sh` `log` (`>>`), `scripts/aitools-profile.ps1` `Log` (`AppendAllText`), `scripts/check-lib.sh` / `.ps1` checks.log/checks.jsonl writers (`>>`, `Add-Content`). Expected: `reference/logging.md` section 5. Severity suggestion: medium (high for the installers, which run first on a new machine).

## Follow-ups

1. M5-L2 (owns `aitools-install.sh` in this worktree): make the installer `log` override use `_aitlib_log_append "$line" "$LOG_FILE"` plus its console print instead of `| tee -a "$LOG_FILE"`; the `.ps1` twin `Log` likewise `Add-AitLibLogText $line` instead of `Add-Content`. Both are loaded after the lib, so the helpers exist.
2. `aitools-profile.sh/.ps1` and `check-lib.sh/.ps1`: same change (separate batch; check-lib touches M5-C1's area).
3. The comment in `Invoke-AiMerge` ("an error thrown inside Invoke-AI (e.g. a failed log write)") is now partly stale: a log write no longer throws; the `finally` is still right for Ctrl+C and other errors. Reword in a later doc pass.

## Open questions

1. Should the fail-safe log write be listed in the exemptions table of `reference/script-standards-detail.md` (it needs the commander's approval)? Suggested answer: no -- `reference/logging.md` section 5 already sanctions it as "the only sanctioned silent-suppression"; add a pointer row only if the commander wants every suppression listed in one place.
2. Should a failed `deploy.log` write warn once on the console, like `deploy.jsonl` does? Suggested answer: no for now -- section 5 says swallowed, and a counted warning would promote every OK row to WARN on a machine with a locked log; if wanted, a one-time uncounted console note (not `log_warn`) is the smallest change, and section 5 must say it first.

## New operational learning

- A background job (`( ... ) &`) of a non-interactive bash ignores SIGINT, so it survives Ctrl+C; and a signal ignored at shell entry cannot be trapped. Tests that need SIGINT delivered must run the target in the foreground (or detect the ignore with `trap -p SIG > file`).
- bash defers a trapped signal until the foreground command (a `$(...)` included) ends; a signal a shell sends to itself with `kill` runs the trap right after the `kill` builtin.
- `exec sleep N` at the end of a test snippet keeps the shell's PID (also in Git Bash/MSYS), so killing that PID kills "the shell" without leaving an orphaned `sleep`.
- In Git Bash, `chmod 000` on a file does make `>>` fail with "Permission denied" (NTFS ACL emulation), so the POSIX unwritable-log test runs on Windows too.
- A .NET method exception inside a PowerShell function is statement-terminating: the function goes on, but the error record prints, and inside a caller's `try` (or under `Stop`) control jumps to the `catch`. Guard library writes with their own try/catch.
- To split one file's changes into two commits without interactive staging: `git diff -U3 -- file > p`, keep the wanted hunks with perl (`split /(?=^@@ )/m`), `git apply --cached --check p` then `git apply --cached p`.
