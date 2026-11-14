# e9d6-12-guard-ps1-suites: report

Version 1.0, 2026-11-14. Author: e9d6-12 (delegated by 38dc-13-windows-ci-ps1-only).
Worktree W = `C:\Users\jdpal\repos\aitools\.claude\worktrees\38dc-13`. Tested: Windows 11
(pwsh 7, Git Bash only for `bash -n` and the one refusal run). Not committed (38dc-13 ships).

## Summary

1. The three `.ps1` suites now have the Windows test-suite guard, and the `.sh` suite has the POSIX guard with the `BASH_VERSINFO[5]` case. Each guard is the first statement after `param`/`-Help` or `set`, as specified in cross-platform.md "Test suites".
2. All dead non-Windows branches are gone: 13 SKIP-only lines/loops, one always-true `if ($IsWindows)` wrapper in a child script, one `$expectReason` ternary, one unused `Skip` helper, and the `.sh` Windows SKIP branch. No check that runs on Windows was removed or renamed.
3. Before/after on Windows: 76/0/7, 17/0/0 and 37/0/0 (pass/fail/skip). The PASS lines are identical and in the same order. The only skips left are the 7 console cases, which skip because stdin is not a console (not a platform reason).
4. Mutation: each `.ps1` exits 1 when one expected value is flipped (3, 1 and 1 FAILs). Files were restored byte-for-byte (SHA-256 checked). The parser reports 0 errors, `bash -n` is clean, and the `.sh` refusal run gives exit 1 with the guard message on stderr and empty stdout.
5. `classify-guards.pl` gives `win` for each `.ps1` and `posix` (not `weak`) for the `.sh`. `git status`: of the changed files, only these four are mine. The other changes belong to the parallel delegates in their own directories.

## Per file

### tests/aitools-entry/test-console-mode-guard.ps1

- **Guard** (after the `-Help` block): `This script is for Windows. On macOS/Linux, the bash twins of these helpers are tested by tests/menus/test-menu-choice.sh and tests/logging/test-logging.sh with bash.`
  Sources for the twin claim: `tests/menus/test-menu-choice.sh` tests `read_tty_choice` and `_start_spinner`/`_stop_spinner` (its lines 8, 147, 444-549). `tests/logging/test-logging.sh` line 102 runs `_ai_log`. The suite's own comment calls `_ai_log` the parity twin of Write-AiLog.
- **Header**: Platform line changed to "Windows only (pwsh 7; OS guard below)". It quotes the commander (2026-11-14) and names the bash twin suites. `-Help` changed from `-First 25` to `-First 28` (the header is 3 lines longer); verified to print 28 lines ending at the Usage line.
- **Dead code removed**:
  - Child script, `no-console` mode: removed the `if ($IsWindows) { ... }` wrapper around the AitConsoleInput compile and probe. The body is kept and dedented. On Windows the condition was always true.
  - `$expectReason = if ($IsWindows) { "not a console" } else { "not Windows" }` changed to `$expectReason = "not a console"`. The `'not Windows'` versions of these checks were only ever produced off Windows, so this removes no check that runs on Windows.
    - Removed: "no console: Save-ConsoleInputMode returns mode -1, 'not Windows'"
    - Removed: "no console: Restore-ConsoleInputMode returns 'not Windows' (nothing to restore)"
    - Removed: the `not Windows` regex of "no console: deploy.log has the detail line"
    - The Windows versions run unchanged.
  - The `else` loop that printed 5 SKIPs ("type: AitConsoleInput compiles and exposes Get, Set, EnterCooked", "type: Get() is -1 without a console", "type: Set() without a console returns a Win32 error code", "type: Set(-1) is refused (87)", "type: EnterCooked() without a console returns -1 and a Win32 error"; reason "kernel32 console API is Windows only"). The Windows `if` body is kept and dedented.
  - The `if (-not $IsWindows)` arm that printed 3 SKIPs for the console cases (reason "kernel32 console API is Windows only"). The `elseif ([Console]::IsInputRedirected)` arm becomes the `if`.
  - Kept: the check "type: Initialize-AitConsoleInput compiles nothing off Windows or with redirected stdin". It reads the lib's source text for `-not $IsWindows) { return $false }` and runs on Windows.
- **Removed checks that could only run off Windows**: none as separate checks. The only off-Windows-only items were the SKIP lines and the `'not Windows'` versions above. Windows CI never produced them because `$IsWindows` is true there.
- **Before / after**: rc 0/0; PASS 76/76, identical in order; FAIL 0/0; SKIP 7/7 (the same console SKIPs: stdin or stdout not a console).
- **Mutation**: `$expectReason = "not a console"` changed to `"not Windows"` gives rc=1 with 3 FAILs ("no console: Save-ConsoleInputMode returns mode -1, 'not Windows'", "...Restore-ConsoleInputMode returns 'not Windows'...", "no console: deploy.log has the detail line"). Restored=True.

### tests/check-lib/test-resolve-git-bash.ps1

- **Guard**: `This script is for Windows. ResolveGitBash and the check-*.ps1 scripts it serves are Windows-only, so there is no macOS/Linux side to run.`
  Source: grep for `git_bash|GitBash` in `scripts/*.sh` finds nothing, so there is no bash twin of ResolveGitBash (`scripts/check-lib.ps1` `function ResolveGitBash`).
- **Header**: Platform line changed to "Windows only (pwsh 7; OS guard below)". It says there is no macOS/Linux side and quotes the commander. `-Help` changed from `-First 16` to `-First 17`; verified to print 17 lines ending at the Usage line.
- **Dead code removed**:
  - The `if ($env:SystemRoot) { ... } else { Skip ×2 "SystemRoot not set (not Windows)" }` wrapper. The two refuse checks now run unconditionally.
  - The `if ($appsBash) { ... } else { Skip "LOCALAPPDATA not set (not Windows)" }` wrapper. The WindowsApps refuse check now runs unconditionally.
  - The `if (-not $IsWindows) { Skip ×2 "not Windows" } else { ... }` wrapper around the default probe. The body is dedented.
  - Kept: the last `Skip "default: never the bash a native PATH resolves to ..."`. It is not a platform skip: it fires when the native PATH bash is not a WSL launcher.
- **Removed checks**: none. Only SKIP lines were removed, and they never printed on Windows.
- **Before / after**: rc 0/0; PASS 17/17, identical in order; FAIL 0/0; SKIP 0/0.
- **Mutation**: the expected value of "probe: the list order decides" changed from `$gitB` to `$gitA` gives rc=1 with 1 FAIL. Restored=True.

### tests/setup-user-shell/test-setup-user-shell.ps1

- **Guard**: `This script is for Windows. On macOS/Linux, run tests/setup-user-shell/test-setup-user-shell.sh with bash.`
- **Header**: Platform line changed to "Windows only (OS guard below; setup-user-shell.ps1 has a Windows OS guard)". It quotes the commander and names the `.sh` twin. `-Help` changed from `-First 12` to `-First 14`; verified to print 14 lines ending at the Usage line.
- **Dead code removed**:
  - The `if (-not $IsWindows) { Skip "setup-user-shell.ps1 cases" ... } else {` wrapper and its closing `}`. The 112 body lines are dedented by 4 spaces (scratch `unwrap-shell.pl`, which asserts the exact shape). `git diff -w` shows only the 4 removed wrapper lines plus the header and guard.
  - The `Skip` helper function, whose only caller was the removed branch.
  - Kept: `$script:skip` and the `---- N passed, N failed, N skipped` line. This matches the house summary format and the `.sh` twin, which also keeps a `SKIP=0` counter (open question 2).
- **Removed checks**: none. The removed SKIP printed only off Windows.
- **Before / after**: rc 0/0; PASS 37/37, identical in order; FAIL 0/0; SKIP 0/0.
- **Mutation**: the expected value of "re-run: no write, so no backup taken" changed from `-eq 0` to `-eq 1` gives rc=1 with 1 FAIL. Restored=True.

### tests/setup-user-shell/test-setup-user-shell.sh

- **Guard**: the block from the mission and cross-platform.md "Test suites", verbatim. It has the comment, the `uname -s` case, and the `${BASH_VERSINFO[5]:-}` case. Both messages read `This script is for macOS/Linux. On Windows, run tests/setup-user-shell/test-setup-user-shell.ps1 with pwsh.` It is the first statement after `set -euo pipefail`, before `--help` and before any temp dir.
- **Dead code removed**: the old Windows `case` branch. It printed `SKIP all cases (...)` and `0 passed, 0 failed, 1 skipped` and then exited 0.
- **Header**: Platform line changed to "macOS/Linux only (OS guard below; ...)". It quotes the commander and names the `.ps1` twin. The header is 1 line longer, so `--help` changed from `$. <= 17` to `$. <= 18`. This keeps the old behaviour of printing through the blank line after the second Usage line. Line 17 is now the second Usage line and line 18 is blank (read back).
- macOS/Linux behaviour is unchanged: nothing after the guard was modified. Bash 3.2: the guard uses only `case`, `printf` and `${BASH_VERSINFO[5]:-}`, all available in 3.2, and is the same as the exemplar in `tests/b8-consumers/test-b8-consumers.sh`.
- **Syntax**: `bash -n` is clean.
- **Refusal run** (plain `bash tests/setup-user-shell/test-setup-user-shell.sh` through the scratch `refusal.sh`, no spoofing): exit=1, stdout 0 bytes, stderr is `This script is for macOS/Linux. On Windows, run tests/setup-user-shell/test-setup-user-shell.ps1 with pwsh.` Environment: `uname -s=MINGW64_NT-10.0-26300`, `BASH_VERSINFO[5]=x86_64-pc-cygwin`. This was the only `.sh` run.
- **CI check** (read only; check.yml is not in my scope): `.github/workflows/check.yml` runs this `.sh` at lines 279 and 283, in the macos job (lines 25-391; bash 5 and `/bin/bash` 3.2), and at line 587, in the linux job (lines 392-624). The windows job (from line 625) runs only the three `.ps1` suites, at lines 752, 789 and 796. So no CI job runs a suite past its new guard.

## Classifier

Command: `perl tests/os-guards/classify-guards.pl W W/.claude/rules/cross-platform.md <list of the 4 files>`, rc=0. Results:

- `tests/aitools-entry/test-console-mode-guard.ps1`: `win`
- `tests/check-lib/test-resolve-git-bash.ps1`: `win`
- `tests/setup-user-shell/test-setup-user-shell.ps1`: `win`
- `tests/setup-user-shell/test-setup-user-shell.sh`: `posix`

No guard message contains `}` (the `.ps1` regex) or `;` (the `.sh` regex).

## git status

`git -C W status --short`: my four files are `M`. Every other entry belongs to the parallel delegates' directories (claude-mdm, deploy-harness(-mdm), hookin, profile, rules-fanout, skills-fanout, skills-legacy, and e9d6-05's report). I touched none of them. My scratch files live in the gitignored `W/.scratch/session-e9d6-12/`: run-suites.ps1, verify-static.ps1, unwrap-shell.pl, mutate.ps1, refusal.sh, and the before/after/mutant logs.

## Lines

- INCIDENT: none.
- CONFLICT: none. The mission prompt and cross-platform.md "Test suites" give the same guard text.
- WRITE_BLOCKED: none.

## Open questions (each with a suggested answer)

1. `test-resolve-git-bash.ps1` keeps its value defaults `$winRoot = if ($env:SystemRoot) {...} else { "C:\Windows" }` and `$appsBash = if ($env:LOCALAPPDATA) {...} else { "" }`. These defaults make no SKIP. If either variable were unset on Windows, the refuse checks would pass without testing anything. Before this change they printed a misleading "(not Windows)" SKIP instead. The System32 and WindowsApps refuse checks are also vacuous on a machine where the launcher file does not exist; that predates this change. Suggested: leave as is (Windows always sets both variables), or in a follow-up make those three checks require the variable. That would change check semantics, so it is outside this mission.
2. `$script:skip` in test-setup-user-shell.ps1 and `SKIP` in the `.sh` are never incremented now. Suggested: keep both, so every suite prints the same `passed, failed, skipped` summary.
3. `scripts/aitools-lib.ps1` still branches on `-not $IsWindows` (lines 1677, 1724-1725 `Reason = "not Windows"`, 3667, 3779, 4332, 4737). It is a guard-exempt shared library, and the plan's "Platform targets" table says it is Windows-only. These are product scripts, outside this mission. Suggested: a separate product cleanup mission decides whether those branches are dead (cross-platform.md "Dead code from platform guards" does not apply to an unguarded library as written).
