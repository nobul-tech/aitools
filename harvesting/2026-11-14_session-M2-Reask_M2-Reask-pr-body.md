## Summary

Every choice menu now accepts only an offered answer. A bare Enter, a word such as `skip`, or a letter that is not offered asks again with `  please type one of o/a/m/s/x`, and nothing is applied until an offered answer arrives. EOF, `--force` and non-interactive runs keep their documented defaults. Every answer is logged to deploy.log at `detail`.

## Why

The commander, session 87795dc3 (2026-11-13), answering RFI fa81-2: "no default or other characters should re-ask". Before this change, Prompt-DiffReview, Prompt-JsonFieldReview and their bash twins treated any unrecognised input as overwrite: a bare Enter, a whole word, and keystrokes left over from the raw-console bug (PR #144 fixes the console mode). A leaked or empty answer silently overwrote files, and deploy.log did not record what was typed.

## Changes

- **Library** (`scripts/aitools-lib.sh` / `.ps1`): new `read_menu_choice` / `Read-MenuChoice` (after `read_tty_choice` / `Read-ConsoleChoice`, whose bodies are unchanged). It prints the prompt, reads through `read_tty_choice` / `Read-ConsoleChoice`, trims and lowercases, re-asks on anything not offered, returns the default only at EOF, logs every answer at detail, and stops after 50 unrecognised answers (an undetected closed input cannot loop). Converted: the text review menu (explicit `o` branch; `a`/`m` re-ask when not offered), the JSON field review (offered letters built from the same flags as the menu lines; explicit `o` branch), and the AI merge preview (`y r n`, EOF `n`).
- **User init** (`scripts/aitools` / `aitools.ps1`): the which-profile menu (numbers + `n s`, EOF `s`), the profile-migrate and duplicate-alias confirms (`[y/n]`, `y yes n no`, EOF `n`), and the create-dotprofile confirm (`[y/n]`, EOF `y`).
- **Reverse discovery** (`setup-user-hooks.*`, `setup-user-skills.*`): `a adopt s skip`, case-insensitive in both shells (bash used to skip on `A` while PS1 adopted), EOF `s`.
- **No-library prompts**: `relay-outbound-prompt.sh/.ps1` (`c/continue q/quit s/show`, exact, no prefix match; prompt `choice [c/q/s]: `; EOF continues and says so; PS1 moved to `[Console]` I/O, treats redirected stdin as non-interactive, and keeps `git status` out of the return value) and `shared/shell/aliases.*` `cc` / `clip2md` (`[y/n]`, `y yes n no`, EOF no). Local loops with the same hint text; no logging (no logging framework there).
- **Specs** (versions, D-DEL5): interactive-menus.md, hook-lifecycle.md, agentic-standards.md, reference/managed-file-deployment.md.
- **Tests**: new `tests/menus/test-menu-choice.sh/.ps1` (wrapper contract and end-to-end menus) with CI steps on macOS (bash 5 and /bin/bash 3.2), Linux and Windows; two re-ask cases in `tests/profile/test-user-init.sh`; the stale `test-managed-files.ps1` case "empty choice at the menu: overwrite" now asserts re-ask then skip; the PS1 merge-reject case sends spare `s` lines.

## Verification

Local, Windows 11 (pty cases skip: pywinpty is not installed; its install waits for the commander's Phase 2 approval, PR #144's evaluation):
- `bash -n` on every touched .sh; pwsh parser on every touched .ps1; no mode changes.
- Before the merge of #145, an integration tree (#145 head + this branch + the library change): tests/menus PS1 60 passed / 1 skipped, bash 63/63 on a fake terminal; managed-files sh 36 passed / 3 skipped, ps1 21 passed / 1 skipped; user-init 136 passed / 2 skipped; skills-legacy 30/2; adopt-push sh 18/1, ps1 14/1; deploy-harness 89/3; hookin 25/2; os-guards 33/0; logging sh 24, ps1 20.
- Mutants that take the default on an unrecognised answer fail 31 (bash) and 29 (PS1) checks of tests/menus.
- Real console (Windows, `WriteConsoleInputW` key injection into a separate pwsh console, the delegating session's harness): Prompt-DiffReview got Enter, `skip`, `q`, `o`: three `please type one of o/a/m/s/x` re-asks, then `>> overwritten`; deploy.log has the four `menu answer (review menu-target.md)` lines.
- check-pre-commit.ps1 / check-pre-push.ps1 / check-post-push.ps1 -Extensive: only known items (pre-commit step 20 dead path refs, none from this PR; post-push step 1 "HEAD != origin/main" before merge).
- Local, final branch (after merging main with #144 and #145): all 36 suites pass (tests/menus sh 5/2 skipped, ps1 60/1; managed-files sh 36/3, ps1 21/1; user-init 136/2; profile config 247, lib 201, profile 716, install 19; deploy-harness 99/2; deploy-harness-mdm 56; skills-legacy 32/2; hookin 29; fan-out suites; hooks; logging; os-guards 33), and the real-console check above re-run on the branch library.
- CI run 43542753176, all green, real pty everywhere: tests/menus macOS bash 5 63/0/0, macOS /bin/bash 3.2 63/0/0, Linux 63/0/0, Windows Git Bash ConPTY 61/0/0, Windows pwsh 63/0/0; managed-files macOS/Linux 88/0/0, Windows bash 79/0/3, Windows pwsh 56/0/0; user-init macOS (bash 5 and 3.2) and Linux 184/0/0, Windows 179/0/1; deploy-harness macOS/Linux 110, Windows 99/2; setup-user-skills macOS/Linux 39, Windows 32/2.

## Not run

- Real-pty cases locally (no pywinpty); CI runs them on macOS, Linux and Windows.
- zsh for `shared/shell/aliases.sh` (zsh not installed here); the helper avoids bash-only syntax.
- The bash `scripts/aitools` user-init re-ask cases (the bash entry point does not run on Windows): macOS/Linux CI.
- `aitools` / `aitools install` against a real HOME (never run by agents).

## Review after (D-DEL5: every spec/rule change, old -> new)

- `.claude/rules/interactive-menus.md`: (none) -> new section "Answers: only an offered answer counts"; "Non-interactive fallback": + "An empty or unrecognised answer at an interactive prompt is not a non-interactive case: it re-asks"; "Console I/O": + choice menus read through `read_menu_choice` / `Read-MenuChoice`.
- `.claude/rules/hook-lifecycle.md` "Prompts in the hook deploy": "read with `read_tty_choice` / `Read-ConsoleChoice`" -> "read with `read_menu_choice` / `Read-MenuChoice` (which reads through ...)"; + "Only an offered answer counts, in any case ... reverse discovery takes `a`, `adopt`, `s`, `skip`. Every answer is logged at `detail`."
- `.claude/rules/agentic-standards.md` "Choices" table: + row "anything else (bare Enter, a word, a letter not offered) | unchanged | unchanged; the menu asks again" and a paragraph quoting the commander.
- `reference/managed-file-deployment.md`: "An unrecognised answer selects `overwrite`, as today." -> only an offered letter counts, re-ask, EOF still overwrites, answers logged; JSON menu prompt letters and re-ask; new section "Menu answers (`read_menu_choice` / `Read-MenuChoice`)"; "Non-Interactive Behavior" + typed empty/unrecognised is not a non-interactive case; functions table + `Read-MenuChoice` row, `Prompt-JsonFieldReview` "unchanged" note corrected; AI merge step 3 + "any other answer asks again, EOF rejects".
- Prompt texts: `[y/N]` -> `[y/n]` (profile migrate, duplicate alias, `cc`, `clip2md`), `[Y/n]` -> `[y/n]` (create dotprofile), relay `choice [c/q/s] (default c): ` -> `choice [c/q/s]: `.

## Decisions taken under the commander's words (please confirm)

- D1/D2: `[y/N]` / `[Y/n]` prompts read `[y/n]` (an Enter default is no longer honoured); `yes` / `no` accepted; "yep" now re-asks.
- D2 (open): EOF at the create-dotprofile confirm still answers yes (creates and pushes the repo), unchanged; non-interactive and `--force` already do. Suggested: keep.
- D3: which-profile menu: empty used to skip; now re-asks.
- D5: relay prompt answers are exact (`qx` no longer quits).
- D7: answers are logged at `detail` (deploy.log only), not `info`, because the console already shows the outcome line.

## Contract change (proposed to the owner of `read_tty_choice` / `Read-ConsoleChoice`)

`read_tty_choice` / `Read-ConsoleChoice` return `""` both at EOF and for a typed empty line. Proposed: at EOF they also set `READ_TTY_EOF=1` (bash) / `$script:ReadConsoleEof = $true` (PS1). The wrapper already resets and honours the flag (tested with a stub). Until they set it, the wrapper treats an empty answer as EOF when the warnings counter rose during the read (their EOF branch calls `log_warn` / `LogWarn`). This PR does not edit those two function bodies.

## Follow-ups

- `read_tty_choice` / `Read-ConsoleChoice`: set the EOF flag (Contract change above) and update their header comments ("each caller's default branch applies" now means the menu helper's EOF default).
- check-post-push step 29 (menu parity) matches `printf` / `Console.*Write` lines with a one-letter bracket; the merge preview's `[y]es/[r]efine/[n]o` line is now a wrapper argument in both twins, so the audit no longer sees it (both sides drop it, parity still holds). Extend step 29 to the `-Prompt` / PROMPT arguments.
- The relay prompt's bash twin has no `[ -t 0 ]` gate (PS1 now checks redirected stdin); `shared/shell/aliases.*` still read stdin / Read-Host.
- Pre-existing, found by the inventory (not changed here): the aitools-install.sh Step 3 repos-path prompt prints to stdout, not /dev/tty; CLAUDE.md cites the deleted `.claude/rules/relay-outbound.md`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
