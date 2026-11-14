## Summary

Mission M5-Fixes, library group (items 1, 2, 5, 10 of the 2026-11-14 remaining-fixes list).

- Item 1: the bash AI-merge spinner (`_start_spinner` in `scripts/aitools-lib.sh`) no longer survives Ctrl+C. It watches the shell that started it (`kill -0`) and `_invoke_ai_merge` sets INT/TERM/EXIT traps around `invoke_ai`, restoring the caller's traps afterwards.
- Item 2: a failed `deploy.log` write never breaks a run (`reference/logging.md` section 5): `Add-AitLibLogText` / `_aitlib_log_append` swallow the failure; console output and counters are unchanged.
- Item 5: the PowerShell [RELAY] prompt (`Read-RelayOutboundChoice` in `scripts/relay-outbound-prompt.ps1`) reads through the library's `Read-MenuChoice` / `Read-ConsoleChoice` (cooked line mode on a Windows console, previous mode restored). Under `aitools.ps1` it uses the loaded library; under `hh.ps1` it dot-sources the library inside the function; without the library it keeps the old local loop. The file is now ASCII, so Windows PowerShell 5.1 can parse it (it had 11 parse errors there).
- Item 10: `aitools-install.sh` Step 3 prints its repos-path prompt to `/dev/tty`, not stdout (`prompt_repos_path`); it is the installer's only prompt; the `.ps1` twin already used `[Console]::Write` + `Read-ConsoleChoice`.

## Why

- Item 1 (mission M3b): a background job of a non-interactive bash ignores SIGINT, so the spinner kept drawing on /dev/tty after Ctrl+C ended the script.
- Item 2 (mission M3b): `Log` / `LogDetail` threw `MethodInvocationException` with deploy.log locked by another process; bash `>>` ended `set -euo pipefail` scripts when deploy.log was unwritable. logging.md section 5: "A failed log write is swallowed (the only sanctioned silent-suppression in the harness), because a broken log must not break the operation it records."

- Item 5 (missions M3b, M2): a local `[Console]::ReadLine()` misses the cooked-mode guard; with the console left raw by a child, the old prompt hung on a pseudo-terminal until killed at 60 s.
- Item 10 (mission M2): interactive-menus.md "Console I/O" -- bash prompts go to `/dev/tty`.

## Changes

- `scripts/relay-outbound-prompt.ps1`, `scripts/aitools-install.sh` (`prompt_repos_path`); `tests/menus/test-menu-choice.ps1` (24 relay checks incl. a ConPTY raw-console case and a 5.1 parse/run case), `tests/profile/test-install.sh` (`step3-prompt-*` pty cases); `.claude/rules/interactive-menus.md` "Answers", `reference/managed-file-deployment.md` "Menu answers", `reference/cross-platform-detail.md`, `reference/logging.md` section 3.

- `scripts/aitools-lib.sh`: spinner owner watch, `_spinner_traps_set` / `_spinner_traps_restore` / `_spinner_on_signal` / `_spinner_on_exit`, `_aitlib_log_append`; `logging_init` tolerates an uncreatable log dir.
- `scripts/aitools-lib.ps1`: `Add-AitLibLogText` used by `Log`, `LogDetail`, `Write-AiLog`; `Initialize-Logging` tolerates an uncreatable log dir.
- `tests/menus/test-menu-choice.sh` (16 spinner checks), `tests/logging/test-logging.sh` / `.ps1` (locked / unwritable log cases).
- `reference/logging.md` section 5, `reference/cross-platform-detail.md` (spinner paragraph), `RELEASE_NOTES.md` v0.77.1.
- Mission reports under `.aitools/channel/handoffs/2026-11-14_87795dc3-missions/M5-Fixes/`.

## Verification

Windows 11 (Git Bash 5.3, pwsh 7), by delegate M5-L1: logging sh 36/0, ps1 26/0; menus sh 78/0, ps1 63/0; managed-files sh 79/0 (3 skipped), ps1 56/0; adopt-push sh 28/0, ps1 22/0; os-guards 34/0. New tests fail against origin/main (bash logging 12, PowerShell logging 4, spinner 9). By delegate M5-L2 (pwsh 7.6.10, Windows PowerShell 5.1): menus ps1 87/0 (14 new checks fail and the pty case times out against the old relay file); profile test-install 19/0 (ps half), its new bash `step3-prompt-*` cases 13/0 through a Git Bash + pywinpty scratch runner (11 fail against the old bare `printf`); test-config 247/0/1; relay-outbound-prompt.ps1 parses under 5.1 and 7. check-pre-commit.ps1: only step 20 FAIL (Windows-only false positives, fixed in the docs PR of this mission); check-pre-push.ps1: 0 FAIL. macOS / Linux / bash 3.2: this PR's CI.

CI on the head c1e534e (run 43563499026): linux, macos, windows green. An earlier run failed on Windows at `tests/aitools-entry/test-console-mode-guard.ps1` "Write-AiLog writes the log file only" (a static check that expected `AppendAllText` inside `Write-AiLog`); c1e534e (M5-Fixes) lets it accept `Add-AitLibLogText` and checks that helper instead (76/0/7 locally).

## Not run

- macOS and Linux suites locally (CI only).
- A real Ctrl+C at a terminal (tests send signals with `kill`).
- check-post-push (its step 7 rebuilds deploy/ against the real HOME; fixed in the checks PR).

## Review after (D-DEL5, old -> new)

1. Bash spinner: `while true` until killed -> ends within one tick after its shell is gone, clears its line.
2. `_invoke_ai_merge`: no traps -> INT/TERM/EXIT traps while `invoke_ai` runs; caller's traps restored. New detail lines "AI spinner stopped by INT|TERM", "AI spinner stopped at exit".
3. PowerShell / bash log writes: threw / ended `set -e` -> silently swallowed through one helper per language.
4. logging.md section 5: names the helpers and their guarantee.
5. cross-platform-detail.md: new paragraph "The bash spinner is a separate process".
6. RELEASE_NOTES.md: v0.77.1 entry (items 1-7).
7. `Read-RelayOutboundChoice`: local ReadLine loop -> `Read-MenuChoice` (local loop kept only as the no-library fallback); EOF / 50-try messages -> the library's (counted) warnings; answers now logged at detail (a new `deploy.log` writer `relay-outbound` under `hh.ps1`); em dash and ellipsis -> `[char]` codes.
8. interactive-menus.md "Answers" and managed-file-deployment.md "Menu answers": the relay-prompt sentence -- the PowerShell prompt reads through the library; `aliases.*` and the bash relay prompt keep a local loop.
9. `aitools-install.sh` Step 3: prompt on stdout -> `/dev/tty` via `prompt_repos_path`; `user_path` is local.

## Follow-ups

- The same unguarded log writes remain in `aitools-install.*`, `aitools-profile.*` and `check-lib.*` (filed as an incident in this mission's docs PR).
- `scripts/hh.ps1` does not parse under Windows PowerShell 5.1 (UTF-8 em dashes, no BOM; cross-platform.md "ASCII preference"); low, since the `hh` function is written only to the pwsh 7 profile.
- The bash relay prompt could use `read_menu_choice` under `scripts/aitools` to log answers.
- The PowerShell spinner runs in a runspace thread and is stopped in a `finally`; judged not affected from code reading, not tested with a real Ctrl+C.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
