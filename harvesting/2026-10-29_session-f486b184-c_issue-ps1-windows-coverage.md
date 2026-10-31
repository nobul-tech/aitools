## Problem

The PowerShell managed-file review menu (`Prompt-DiffReview`, `Review-JsonFields`, `Invoke-AiMerge`, `Invoke-ManagedAbort` in `scripts/aitools-lib.ps1`) is tested only on macOS and Linux CI. That code runs only on Windows in production.

`tests/managed-files/test-managed-files.ps1` drives its interactive cases through `tests/managed-files/pty-run.py`, which uses Python's `pty` module (Unix only). On Windows the whole interactive group is skipped:

```
windows  Managed-file tests (PowerShell, native)  SKIP interactive cases (no python3 pty on this platform)
windows  Managed-file tests (PowerShell, native)  9 passed, 0 failed, 1 skipped
```
(PR #68, run 39719152527, job 119628339941)

So 13 interactive cases (overwrite, skip, accept & adopt, adopt filter, merge & adopt, merge rejection, failed AI merge, adopt-target write failure, abort, per-field JSON review) run on macOS and Linux, where the PS1 entry points stop at their OS guard, and never on Windows, where users see the menu. CI reports the Windows job green because a skipped group counts as a pass.

## How it surfaced

PR #68's Linux job failed on the PS1 "EOF at the menu" pty case: pwsh on Linux did not end `[Console]::ReadLine` on a `\x04` sent through the pty, so it timed out after 60 s. Fixed on the PR branch in 435a7aa by testing `Read-ConsoleChoice` with an empty `Console.In` (portable, runs on Windows too). The investigation showed the larger gap above.

## History

- 2026-03-24 `b698ea7` (v0.66.0): CI created with 3 runners; Linux job checked bash/Python only.
- 2026-10-03 #37 (`62442cb`): PS1 logging tests added to all three runners, the first PS1 run on Linux. Authored in Claude Code web (Linux only).
- 2026-10-22 #68: PS1 managed-file tests with pty interactive cases added to all three runners.

No recorded decision says which PS1 tests belong on which platform.

## Suggested direction

1. **Input seam (preferred, no new dependency):** route the menu's key reads (`Read-ConsoleChoice` and the merge `[y/n]` read) through one replaceable function or `Console.In`, so tests can script keystrokes without a terminal. The interactive cases then run on Windows, macOS and Linux alike. `Test-InteractiveConsole` needs a matching test override so the menu is shown under redirected input.
2. **Alternative:** a Windows ConPTY harness. Needs a `/tool-eval` pass for any third-party package (e.g. pywinpty).
3. **Policy:** write down that PS1 logic tests (parse, JSON merge, file ops, logging) run on all three runners, and console/terminal behavior tests must run on Windows. Candidate home: `.claude/rules/cross-platform.md` (protected, needs review).
4. **Visibility:** make CI surface a skipped test group (e.g. `::warning::` annotation) instead of passing silently.

## Done when

- The Windows job runs the PS1 interactive cases (no `SKIP interactive cases` line).
- Breaking a menu branch in `aitools-lib.ps1` fails the Windows job.
