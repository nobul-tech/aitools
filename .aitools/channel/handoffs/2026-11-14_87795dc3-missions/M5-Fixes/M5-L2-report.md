# M5-L2 report -- the [RELAY] prompt reads in cooked mode, the installer's repos prompt goes to the terminal

**Version**: v1.0 (2026-11-14). **Author**: M5-L2, delegated by M5-Fixes
(delegated by Session Commander 87795dc3-e). **Branch**: `fix/m5-lib`, pushed;
no PR opened (M5-Fixes opens it).

## Summary

1. Item 5 fixed: the PowerShell `[RELAY]` prompt now reads through the library's `Read-MenuChoice` / `Read-ConsoleChoice` (cooked line mode, previous mode restored); under `hh.ps1` it dot-sources the library inside the function.
2. The defect was reproduced: with the console left raw, the old prompt hung on a pseudo-terminal until killed (60 s); the new one reads, and the raw mode is put back.
3. Found on the way: Windows PowerShell 5.1 could not parse `relay-outbound-prompt.ps1` at all (UTF-8 em dash in a BOM-less file); the file is now ASCII and the prompt runs on 5.1 (tested). `hh.ps1` itself still does not parse on 5.1 (INCIDENT below, not fixed: out of scope).
4. Item 10 fixed: `aitools-install.sh` Step 3 prints its prompt to `/dev/tty` (new helper `prompt_repos_path`); it was the installer's only prompt; the `.ps1` twin already followed the rule.
5. Commits `d590e1d` (item 5), `9462c8f` (item 10), plus this report; all touched suites pass on Windows; macOS/Linux halves run in CI only.

## Item 5 -- [RELAY] prompt read without the cooked-mode guard: fixed

**Verified first.** `scripts/relay-outbound-prompt.ps1` `Read-RelayOutboundChoice`
read with its own `[Console]::ReadLine()` (its comment: "hh.ps1 does not load
aitools-lib, so this mirrors the library's Read-MenuChoice locally"). Callers:
`scripts/aitools.ps1` (end of the run, after `Show-Summary`; the lib is loaded)
and `scripts/hh.ps1` (`-n`; no lib). `hh` is `function hh { & "$HOME\.local\bin\hh.ps1" @args }`
in the profile (`tests/setup-user-shell/test-setup-user-shell.ps1`), so `hh.ps1`
runs in its own script scope, in the user's process.

**Reproduced.** The new pty case run against the HEAD version of the file
(`.scratch/session-M5-L2/old-relay-tree.sh`): `pty-run: timeout after 60.3s ...
0 input line(s) not sent` -- all input sent, the read never returned. The old
file also failed every 5.1 case: `powershell.exe` parse of it gave 11 errors
(`Missing ')' in method call` at line 41: 5.1 reads a BOM-less file as ANSI,
and the em dash's UTF-8 bytes E2 80 94 include 0x94, a right double quote,
which PowerShell treats as a string delimiter).

**Design (one source of truth).** `Read-RelayOutboundChoice`:
- When `Read-MenuChoice` exists (aitools.ps1), it is used with the caller's log.
- Else it dot-sources `$PSScriptRoot\aitools-lib.ps1` inside the function: the
  lib's functions are defined in the function's scope and end with the call
  (test: `the lib's functions do not outlive the call`); its `$script:`
  variables land in hh.ps1's script scope, which ends with hh.ps1. What does
  persist in the process: the `AitConsoleInput` type (only once a console
  read happens; the same type the lib compiles anyway) and the lib's
  normalisation of an already-set `AITOOLS_ENVIRONMENT`. It then calls
  `Initialize-Logging "relay-outbound"` in a try/catch (a log that cannot be set
  up must not stop the prompt, `reference/logging.md` section 5; on 5.1 without
  `AITOOLS_LOG_DIR` it fails at the 3-argument `Join-Path`, and the answers are
  not logged, the read still goes through the lib).
- When the lib is missing or does not load: a console line says so, and the old
  local loop runs (no cooked-mode guard, no logging).
- `Read-MenuChoice -Valid c continue q quit s show -Default c -DefaultDesc continue -Context 'relay outbound' -Prompt "  choice [c/q/s]: "`.
  Same prompt text, answers, hint (`please type one of c/continue/q/quit/s/show`,
  identical to the old local hint), EOF default and 50-try limit. Changed: at
  EOF and at the 50-try limit the message is the library's warning, and every
  answer is logged at `detail`.
- The file is ASCII: em dash and ellipsis are `[char]0x2014` / `[char]0x2026`
  (console output unchanged).

Not replicated: the C# type. A local copy of `AitConsoleInput` would be a second
source, and since `aitools` and `hh` run in the same pwsh process, a diverging
local definition of the same type name would be used by the lib later
(`'AitConsoleInput' -as [type]` short-circuits the compile).

**.sh twin.** `scripts/relay-outbound-prompt.sh` `_relay_outbound_choice` reads
stdin redirected from `/dev/tty` in a local loop (`< /dev/tty > /dev/tty`), the
equivalent of `read_tty_choice`; no cooked-mode guard is needed (Git Bash keeps
its own terminal state: `reference/cross-platform-detail.md` "Windows console").
Unchanged. Remaining difference: the bash prompt does not log answers and says
`(no input -- continuing)` at EOF, where the PowerShell prompt now uses the
library's warning (see Follow-ups).

**Evidence** (`tests/menus/test-menu-choice.ps1`, 24 new checks; the suite: 87 passed, 0 failed, 0 skipped):
- `relay (lib loaded by caller): 'x' and empty re-ask, then 'quit' -> quit (one value)`, `2 hints`, `prompt ... asked 3 times`, `answers logged in the caller's log`
- `relay (hh path): 'C' -> continue ...`, `answer logged as relay-outbound`, `the lib's functions do not outlive the call`, `' s ' -> show`, `'maybe' re-asks, then q -> quit`, `EOF -> continue (one value)`, `EOF warning and 'EOF -> c' logged`, `50 unrecognised answers -> continue, warning, 49 hints`
- `relay (no lib): 'x' re-asks, then 'Q' -> quit, said why`, `nothing logged`, `EOF -> continue, '(no input -- continuing)'`
- `relay (PS 5.1): relay-outbound-prompt.ps1 parses`, `is ASCII`, `relay (PS 5.1, hh path): 'x' re-asks, then s -> show (one value)`, `answers logged`
- `relay pty: the console was set raw before the prompt`, `[RELAY] shown, 'x' re-asks, then q -> 2 (quit)`, `the reads ran in cooked mode (Read-ConsoleChoice saw line input / echo off)`, `the raw mode is put back after the prompt`, `both answers logged` -- the whole `Invoke-RelayOutboundPrompt` on the hh path, in a temp git repo with an untracked relay.md, `CI` cleared, console mode set to `mode & ~0x6` first.
- Against the HEAD relay file: 73 passed, 14 failed (all the relay checks that depend on the change).
- Probe (`.scratch/session-M5-L2/run-probe.sh`) under pwsh 7.6.10 and Windows PowerShell 5.1.26100: same results on both, including 5.1 without `AITOOLS_LOG_DIR` (read works, nothing logged, as designed).

## Item 10 -- the installer's repos prompt printed to stdout: fixed

**Verified first.** `scripts/aitools-install.sh` Step 3: `printf 'Where should
new repos live? [~/repos]: '` (stdout), answer via `read_tty_choice` (`/dev/tty`).
Every other prompt in the file checked by reading the whole script: there is
none; Step 2 runs `gh auth login`, which talks to the terminal itself.

**Fix.** New helper `prompt_repos_path` in the "install log helpers" block (so
the suites can extract and run it; `test-config.sh` evals the same block, still
247 passed): `printf ... > /dev/tty`, `read_tty_choice user_path "~/repos"`,
`REPOS_PATH` = answer with `~` expanded, else `$HOME/repos`. Step 3 calls it.
`user_path` is now local (it was a global used nowhere else).

**Parity.** `scripts/aitools-install.ps1` Step 3: `[Console]::Write("Where should
new repos live? [$defaultPath]: ")` + `Read-ConsoleChoice $defaultPath` -- the
form `interactive-menus.md` "Console I/O" prescribes for PS1; unchanged. The
default shown differs by platform (`~/repos` vs `C:\Users\<u>\repos`):
pre-existing. Note: `[Console]::Write` goes to the process's stdout handle, so
the PS1 prompt would also land in a redirected stdout; the rule accepts it and
.NET has no `/dev/tty` short of opening `CONOUT$` (not changed; see Open questions).

**Evidence** (`tests/profile/test-install.sh`, new `step3-prompt-*` cases, bash
half only -- macOS/Linux CI, also `/bin/bash` 3.2): on a pseudo-terminal with the
harness's stdout and stderr sent to a file, for an answer, `~/code`, an empty
answer and EOF: `REPOS=<expected>`, `the prompt reached the terminal`,
`no prompt on stdout/stderr`; plus `EOF warning logged`. Locally (Windows, where
the suite runs its PowerShell half) the same harness and case code, extracted
from the suite, ran under Git Bash with pywinpty
(`.scratch/session-M5-L2/step3-tty-local.sh`): 13 passed; against a mutant with
the old bare `printf`: 11 failed (the prompt in the stdout file, not on the
terminal, and splicing the `REPOS=` line).

## Branch and commits

- `fix/m5-lib`, pushed to origin.
- `d590e1d` Read the [RELAY] prompt answer through the library's cooked-mode read
- `9462c8f` Print the installer's repos-path prompt to the terminal, not stdout
- report commit: this file plus `reference/logging.md` section 3 and RELEASE_NOTES item 6 (see `git log`)

## Files changed

- `scripts/relay-outbound-prompt.ps1` (item 5)
- `scripts/aitools-install.sh` (item 10)
- `tests/menus/test-menu-choice.ps1` (item 5), `tests/profile/test-install.sh` (item 10)
- `.claude/rules/interactive-menus.md`, `reference/managed-file-deployment.md`, `reference/cross-platform-detail.md`, `reference/logging.md` (item 5 docs)
- `RELEASE_NOTES.md` v0.77.1: title, intro line, items 5, 6, 7
- this report

No new suite, so no `check.yml` change: both suites already have CI steps
(`tests/menus/test-menu-choice.ps1` in the windows job; `tests/profile/test-install.sh`
in the linux and macOS jobs, macOS also under `/bin/bash` 3.2, and the windows job).

## Verification (Windows 11, Git Bash 5.3, pwsh 7.6.10, Windows PowerShell 5.1; all from the worktree)

| Command | Result |
|---|---|
| `powershell.exe -File .scratch/session-M5-L2/parse51.ps1 scripts/relay-outbound-prompt.ps1` (5.1 parser) | OK (old file: 11 errors) |
| same with `pwsh` | OK |
| `pwsh -NoProfile -File tests/menus/test-menu-choice.ps1` | 87 passed, 0 failed, 0 skipped (pty cases ran: pywinpty 3.1.2) |
| same against the HEAD relay file (`old-relay-tree.sh`) | 73 passed, 14 failed (pty case: timeout after 60.3 s) |
| `bash -n scripts/aitools-install.sh`, `bash -n tests/profile/test-install.sh` | OK |
| `bash tests/profile/test-install.sh` | 19 passed, 0 failed (windows: ps); step3-prompt skipped (bash installer only: macOS/Linux) |
| `bash .scratch/session-M5-L2/step3-tty-local.sh` (the suite's step3-prompt cases under Git Bash) | 13 passed; against the stdout mutant 2 passed, 11 failed |
| `bash tests/profile/test-config.sh` | 247 passed, 0 failed, 1 skipped |
| `bash tests/os-guards/test-os-guards.sh` | 34 passed, 0 failed, 0 skipped |
| `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/check-pre-commit.ps1` (item 5 staged; item 10 staged), `AITOOLS_LOG_DIR` in scratch | 1 FAIL each time: step 20, the 5 known dead path refs (`CLAUDE.md:100` etc., none in my files); WARN 3 (not run with -Fix: builds against the real HOME), WARN 5 (the note is in the commit messages), WARN 11 (dotprofile changes, not mine) |
| `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/check-pre-push.ps1`, `AITOOLS_LOG_DIR` in scratch | 8 PASS, 2 WARN (steps 1 and 6, advisory), 0 FAIL; step 7 fresh build OK |

## Not run

- The bash halves on macOS/Linux (CI only; CI starts with the PR). The new
  `step3-prompt-*` cases there run under stdlib `pty`; locally they ran under
  Git Bash + pywinpty instead.
- The full installer and `aitools` / `hh` themselves (never against the real
  HOME; incident #89: the full installer cannot run in the suite). The relay
  pty case runs the real `Invoke-RelayOutboundPrompt` in a temp repo instead.
- `tests/menus/test-menu-choice.sh` and `tests/aitools-entry/test-console-mode-guard.ps1`
  (their code is untouched: the bash relay prompt and the lib did not change).
- A hand test on a real terminal; check-post-push (forbidden).

## Review after (D-DEL5: each change, old -> new)

1. `Read-RelayOutboundChoice`: local `[Console]::ReadLine()` loop -> `Read-MenuChoice` (lib from the caller, else dot-sourced inside the function); the local loop kept only as the fallback when the lib is missing or fails to load (with a console line saying so).
2. `[RELAY]` prompt at EOF / after 50 unrecognised answers: `(no input -- continuing)` -> the library's warnings `No input at prompt (EOF) -- defaulting to continue` / `No valid answer after 50 tries at relay outbound -- treating input as ended, defaulting to continue` (counted warnings; under aitools.ps1 they are counted after the summary is shown).
3. `[RELAY]` answers: not logged -> logged at `detail` (`menu answer (relay outbound): ...`), in aitools' log, or in `deploy.log` as `relay-outbound` under hh.ps1 (a new writer of `deploy.log`).
4. `relay-outbound-prompt.ps1`: UTF-8 em dash / ellipsis literals -> `[char]0x2014` / `[char]0x2026` (same output); comment em dashes -> `--`; header notes why the file is ASCII.
5. `.claude/rules/interactive-menus.md` "Answers": "Prompts that cannot load the library (the relay-outbound prompt, `shared/shell/aliases.*`) re-ask the same way with a local loop; they do not log." -> aliases and the bash relay prompt keep the local loop; the PowerShell relay prompt reads through `Read-MenuChoice`, loading the lib itself under hh.ps1, falling back to the local loop only without the lib.
6. `reference/managed-file-deployment.md` "Menu answers" users paragraph: same change.
7. `reference/cross-platform-detail.md` "Windows console": new bullet on the `[RELAY]` prompt.
8. `reference/logging.md` section 3 table, `deploy.log` writers: "setup scripts" -> also the PowerShell `[RELAY]` prompt under hh.ps1 (`relay-outbound`).
9. `aitools-install.sh` Step 3: `printf` prompt to stdout -> to `/dev/tty`, moved into the new helper `prompt_repos_path` (install log helpers block); `user_path` global -> local.
10. `RELEASE_NOTES.md` v0.77.1: title extended, intro "batch M5-L1 ... mission M3b" -> "batches M5-L1, M5-L2 ... missions M3b and M2"; new items 5 (bug), 6 (docs), 7 (bug).
11. `tests/menus/test-menu-choice.ps1`: 24 new checks, header paragraph, `-Help` prints 40 lines (was 34).
12. `tests/profile/test-install.sh`: harness mode `step3prompt`, 13 new checks, header line, `--help` prints lines 2-35 (was 2-33).

## WRITE_BLOCKED / CONFLICT / INCIDENT

- WRITE_BLOCKED: none.
- CONFLICT: the session's auto-mode note allows Bash for file edits vs USO "Dedicated tools for file ops" -- resolved by tier 1 (the commander's CLAUDE.md): Read/Edit/Write/Grep for every file operation; the one Perl one-liner wrote a scratch mutant.
- CONFLICT: the mission says keep "the prompt text, choices, EOF default ('continue'), re-ask and the 50-try limit identical" vs routing through the library, whose EOF / 50-try messages differ from the local ones -- resolved by tier 2 (the prompt lists what must stay identical; the messages are not on that list, and the prompt prefers one source of truth): all listed items kept; the messages are the library's; recorded under Review after 2.
- INCIDENT (for M5-Fixes to file via `/incident`, not filed by me): `scripts/hh.ps1` does not parse under Windows PowerShell 5.1 (6 parse errors, first at line 69 `Missing argument in parameter list`; cause: UTF-8 em dashes in strings on lines 61 and 96, in a BOM-less file 5.1 reads as ANSI). Expected: `relay-outbound-prompt.ps1`'s comment and this mission's brief treat hh.ps1 as loadable in 5.1; `.claude/rules/cross-platform.md` "ASCII preference for PS1 executable code". Impact: `hh` cannot run in a Windows PowerShell 5.1 session at all (low: setup-user-shell writes the `hh` function into the running pwsh 7 `$PROFILE` only). Suggested resolution: replace the em dashes in hh.ps1 strings with `--` or `[char]0x2014`, and add a 5.1 parse check for hh.ps1 next to the relay one in `tests/menus/test-menu-choice.ps1` (or a general "PS1 files 5.1 may load are ASCII" pre-commit step). Severity suggestion: low.

## Follow-ups

1. Bash `[RELAY]` prompt: when `scripts/aitools` has loaded the lib, read through `read_menu_choice` (answers logged, same EOF wording as aitools.ps1); keep the local loop for hh.sh. Needs pty cases in `tests/menus/test-menu-choice.sh`.
2. The INCIDENT above (hh.ps1 on 5.1).
3. M5-L1's follow-up 1 (installer `log` overrides through the fail-safe helpers) was not in my scope and is not done.

## Open questions

1. Should the bash `[RELAY]` prompt also log its answers (follow-up 1)? Suggested answer: yes under `scripts/aitools` (the lib is loaded there anyway); no under hh.sh (loading the bash lib into hh only for logging is not worth it).
2. Should PS1 prompts write to the console device (`CONOUT$`) instead of `[Console]::Write` so a redirected stdout cannot swallow them, as bash does with `/dev/tty`? Suggested answer: no -- the rule prescribes `[Console]::Write`, every PS1 menu uses it, and the installers already skip prompts when stdin is redirected; revisit only if a real case appears.
3. Should hh.ps1 be supported on Windows PowerShell 5.1 at all? Suggested answer: no -- say "pwsh 7 only" in its header (the project baseline is PS 7, `cross-platform.md` "PowerShell 7 baseline"), and drop the 5.1 remarks; or, if yes, make it ASCII (the INCIDENT).

## Delegates used

None (no independent review delegate was launched; `/delegate` and `/scratch` were loaded).

## New operational learning

- Windows PowerShell 5.1 reads a `.ps1` without a BOM as ANSI (Windows-1252). The UTF-8 em dash is E2 80 94, and 0x94 is a right double quote, which PowerShell accepts as a string delimiter: the file stops parsing. Keep any `.ps1` that 5.1 may load ASCII; build non-ASCII output with `[char]` codes.
- In a child that swaps `[Console]::Out` with `SetOut` around a read, later stdout of that child can be lost (seen: nothing printed after the restore, the work itself done). Write test results to files, as the existing suites do.
- Dot-sourcing a library inside a function: its functions live only for the call, but its `$script:` variables land in the nearest script scope (the caller's script). Good for "use it once without polluting the session".
- With the console input mode raw (line input and echo off), a plain `[Console]::ReadLine()` under ConPTY never returns, even after all input is sent: a deterministic test for the cooked-mode guard (set `mode & ~0x6` first, expect a read and the raw mode back).
- PowerShell parameter names are case-insensitive: a test helper parameter `-Lib` hides a script variable `$lib` (here: the library path). Name switches distinctly (`-WithLib`).
- To test a bash-only suite case on Windows without changing the suite's platform targeting, extract the suite's own harness heredoc and case block with Perl into a scratch runner.

## Reading done (honest account)

Read in full: the user CLAUDE.md and user rules `concurrent-agents.md`, `scratch.md`,
`tool-evaluation.md`, `tool-lifecycle.md`, `tool-ops.md`, `web-sources.md`; the
worktree `CLAUDE.md` (identical to the main checkout's, which was in context: `git
diff` showed no change), `.aitools/channel/CLAUDE.md`; every listed project rule
(the ones in context came from the main checkout; for the four that differ on
this branch -- agentic-standards, deploy-paths, hook-lifecycle,
interactive-menus -- I read the diff or the whole worktree file);
`reference/cross-platform-detail.md`, `script-standards-detail.md`, `logging.md`,
`managed-file-deployment.md`, `pre-push-checklist.md`; `relay-outbound-prompt.ps1`/
`.sh`, `hh.ps1`/`.sh`, `aitools-install.sh`/`.ps1`, the `aitools.ps1` call site; the
named lib functions in both libraries; the M5-L1 report; `tests/menus/test-menu-choice.ps1`/`.sh`,
`tests/profile/test-install.sh`, `tests/aitools-entry/test-console-mode-guard.ps1`,
`tests/managed-files/pty-run.py`. Not read in full: none of the mandated files.
No relay entry appended (the relay is a main-checkout path; the learning above is for M5-Fixes to relay).
