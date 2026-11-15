Status on `main` (592c5b3): the defect is fixed at every prompt this issue lists, and EOF is tested in CI on all three platforms through the shared read helpers and the text review menu. What remains is per-prompt EOF regression cases for two of the listed prompt families (see the end).

## Fix 1: one EOF-safe read per language (done)

- #35 (PR C1, v0.73.3, `075c3da`) added `read_tty_choice` (`scripts/aitools-lib.sh`) and `Read-ConsoleChoice` (`scripts/aitools-lib.ps1`).
  - At EOF, each logs `[warn] No input at prompt (EOF) -- defaulting to <what the default does>` and returns `""` with exit 0. There is no `set -e` abort and no `.ToLower()` on `$null`.
  - `read_tty_choice` holds the only `read -r ... < /dev/tty` in `aitools-lib.sh`. `Read-ConsoleChoice` holds the only `[Console]::ReadLine()` in `aitools-lib.ps1`.
- #146 put every choice menu on `read_menu_choice` / `Read-MenuChoice`, which read through those helpers:
  - An empty line or an unknown answer asks again.
  - EOF takes the menu's documented default and is logged at detail as `menu answer (<context>): EOF -> <default>`.
  - 50 unrecognised answers in a row count as EOF.
- #147 made the helpers set an explicit EOF flag (`READ_TTY_EOF=1` / `$script:ReadConsoleEof = $true`), so a typed empty line and EOF are told apart.

Where each listed prompt reads now:

| Prompt (this issue) | bash | PowerShell | EOF result |
|---|---|---|---|
| `prompt_json_field_review` / `Prompt-JsonFieldReview` | `read_menu_choice` | `Read-MenuChoice` | the menu default (`o`, or `s` without overwrite) |
| `prompt_diff_review` / `Prompt-DiffReview` | `read_menu_choice` | `Read-MenuChoice` | `o` (overwrite) |
| `_invoke_ai_merge` / `Invoke-AiMerge`: merge preview `[y/r/n]` | `read_menu_choice` | `Read-MenuChoice` | `n` (reject, back to the review menu) |
| `_invoke_ai_merge` / `Invoke-AiMerge`: `[r]` feedback text | `read_tty_choice` | `Read-ConsoleChoice` | empty feedback |

## Fix 2: one non-interactive test in PowerShell (done)

`Test-InteractiveConsole` (`[Environment]::UserInteractive -and -not [Console]::IsInputRedirected`) is now the only interactivity check. `Prompt-DiffReview`, `Review-JsonFields` and `Prompt-JsonFieldReview` all call it. The bash twin is `tty_interactive`.

## Fix 3: regression tests (partly)

CI on `main` 592c5b3 (https://github.com/nobul-tech/aitools/actions/runs/43557171983) is green on macOS, Linux and Windows.

The tests deliver EOF in two ways. The `.sh` suites send Ctrl-D (`\x04`) on a pty through `tests/managed-files/pty-run.py`, which uses ConPTY via pywinpty on Windows. The `.ps1` suites give `Read-ConsoleChoice` an empty `Console.In`; PowerShell on Linux does not end `ReadLine` on `\x04` through a pty, see #72.

- **Read helpers**:
  - `tests/menus/test-menu-choice.sh`: `EOF: default returned`, `EOF: read_tty_choice warning logged`, `re-ask then EOF: ...`, `READ_TTY_EOF=1: ...`.
  - `tests/menus/test-menu-choice.ps1`: the same cases, plus `ReadConsoleEof = true: ...`.
  - The `.sh` suite runs on macOS (bash 5 and `/bin/bash` 3.2), Linux and Windows (Git Bash, ConPTY). The `.ps1` suite runs on Windows.
- **Text review menu end to end**:
  - `tests/menus/test-menu-choice.sh` / `.ps1`: `EOF at the review menu: overwrite` and `... warning and 'EOF -> o' logged, no hint`.
  - `tests/managed-files/test-managed-files.sh`: `EOF at the menu: overwrite, warning logged`.
  - `tests/managed-files/test-managed-files.ps1`: `EOF at a prompt: empty choice, warning logged`.

## What remains

1. No end-to-end EOF case for the JSON field prompt (`prompt_json_field_review` / `Prompt-JsonFieldReview`), in either the `deploy_managed_file` JSON review or the settings sync (`sync_managed_json` / `Sync-ManagedJson`). The JSON cases in `tests/menus` cover re-ask, not EOF.
2. No EOF case for the AI-merge preview `[y/r/n]` (EOF should reject the merge and return to the review menu), and none for the `[r]` feedback read.

Both prompts read through the helpers whose EOF path is tested above, so a regression would have to be at the call site. One `\x04` / empty-`Console.In` case per prompt in `tests/menus/test-menu-choice.sh` and `.ps1` would complete fix 3. This issue can be closed once those cases are in.
