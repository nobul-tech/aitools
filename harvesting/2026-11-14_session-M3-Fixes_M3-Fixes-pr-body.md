## Summary

- `setup-user-shell` becomes the single, self-repairing owner of the PowerShell profile and the shell rc files. Duplicate managed blocks collapse to one. Damage the script cannot safely fix is reported as WARN plus an ACTION that names a clean backup. The Windows shell integration (`aliases.ps1`, `aitools`, `hh`) moves out of `aitools-install.ps1` Step 7 into a second marked block owned by `setup-user-shell.ps1` (incidents #172, #173).
- `aitools.ps1` Step 2 no longer lets build-deploy's Git Bash/MSYS processes change the console input mode: the build gets a pipe for stdin, and the mode is saved before the build and restored after it.
- pywinpty evaluation for running the pty tests locally on Windows. The requirements file now pins every win_amd64 wheel. **Nothing is installed: the install command waits at the Phase 2 gate for the commander's approval.**
- Fixes 1 and 5 (`Read-ConsoleChoice` console mode, the AI-merge spinner) touch `aitools-lib.*`, which is held by the json-review mission until its PR merges. They follow in a separate PR.

## Why

Session 87795dc3 (2026-11-13), commander: "launch mission to create all other fixes in its own worktree".

- **#172**: the commander's `$PROFILE` reached 84 blocks and 135 parse errors. After #143, `setup-user-shell` still reported OK with 64 blocks left on that file.
- **#173**: Step 7 rewrote `$PROFILE` on every run, with no backup. It deleted every non-blank line after its marker, and it could not be tested because it wrote `$PROFILE` directly.
- **Console mode**: while build-deploy runs with the console as stdin, the console input mode flips from 0x1F7 to 0x2E8 and back about 45 times per build. If raw mode is left behind, the next review menu reads with no echo and one key late, and the extra key falls into the next menu's default (overwrite).

## Changes

| File | Change |
|---|---|
| `scripts/setup-user-shell.ps1` | Rewritten as a line-based engine for two marked blocks: PATH (`# >>> aitools managed >>>`) and shell integration (`# >>> aitools shell integration >>>`). <br>- The first block is replaced in place; later blocks and stray marker lines are dropped.<br>- An unchanged profile is not written and not backed up.<br>- After writing, it re-reads the file and checks exactly one start and one end marker per block.<br>- A write that would add parse errors is refused.<br>- Damage is reported as WARN `profile damage left in place` plus an ACTION naming the newest clean `<profile>.bak.<UTC>`, or "repair by hand". Damage means parse errors, or stray `_aitoolsLocalBin` / `Owned by aitools` lines outside the blocks.<br>- Legacy `# aitools shell integration` / `# ai-tooling shell integration` blocks are migrated by known line shapes only, so a user line after `function hh {...}` is kept.<br>- `AITOOLS_ALIASES_PATH` is a test override. A UTF-8 BOM is kept, and a non-UTF-8 profile is refused.<br>- Relative `AITOOLS_PROFILE_PATH` values are resolved to absolute paths before the `[IO.File]` calls. |
| `scripts/setup-user-shell.sh` | The same rules for `~/.bash_profile`, in Perl, with `bash -n` as the parse check. Now owns the `.bashrc`/`.zshrc` aliases source line. The format is unchanged; each file is backed up and `AITOOLS_PROFILE_DIR` is honoured. |
| `scripts/aitools-install.ps1`, `.sh` | Step 7 only runs `setup-user-shell` (the inline profile and rc code is removed). |
| `scripts/aitools.ps1` | New `Save-ConsoleInputMode` / `Restore-ConsoleInputMode` (P/Invoke type `AitConsoleModeGuard`; no-op off Windows or when stdin is not a console). Step 2 runs `$null \| & $bashExe build-deploy.sh` inside that save/restore. |
| `tests/setup-user-shell/test-setup-user-shell.ps1` | 8 → 37 checks. |
| `tests/setup-user-shell/test-setup-user-shell.sh` | New: 23 checks; skips on Windows. |
| `tests/aitools-entry/test-console-mode-guard.ps1` | New: 18 checks. Extracts the helpers with the AST, tests the no-console path and the compiled type, and checks the structure of Step 2. |
| `.github/workflows/check.yml` | New steps:<br>- macOS: setup-user-shell `.sh` suite under bash 5 and under `/bin/bash` 3.2.<br>- Linux: setup-user-shell `.sh` suite.<br>- Windows: console-mode-guard test. |
| `tests/managed-files/requirements-windows.txt` | pywinpty 3.1.2 hashes for every win_amd64 wheel (cp310–cp315, including free-threaded). CI still installs the same cp312 wheel. |
| `reference/ait-shellintegration.md` | v1.1. |
| `reference/evaluations/pywinpty-windows-2026-11-13.md` | New, v1.1. |

## Verification (Windows 11, pwsh 7, Git Bash 5.3.15)

**Test suites**

| Suite | Result |
|---|---|
| `test-setup-user-shell.ps1` | 37/0/0 |
| `test-setup-user-shell.sh` | Skips natively on Windows (exit 0); 23/0/0 on a copy with the OS guard removed, in Git Bash |
| `test-console-mode-guard.ps1` | 18/0/0; mutations of Step 2 make it fail |
| `test-os-guards.sh` | 33/0/0 |
| `test-logging.ps1` | 20/0/0 |

`bash -n` and the pwsh parser are clean on every touched script.

**Real-console harness** (key injection plus `GetConsoleMode` polling in a real console)
- During an isolated build with the console as stdin, the mode changed 47 times. With a pipe for stdin it changed 0 times, in each of 3 builds.
- A child process that leaves the mode at 0x2E8 or 0x208 (or opens `CONIN$` despite the pipe) gets 0x1F7 back from the guard. Without the guard the mode stays raw.

**Scratch copies of the commander's profiles** (the real files were only read)
- Current profile (537 bytes):
  - Run 1: `managed block unchanged` and `legacy integration migrated`, 0 parse errors.
  - Run 2: `unchanged` for both blocks, no write.
- Corrupted backup (84 start markers, 135 parse errors):
  - After: 1 block, 85 parse errors left from fragments outside the markers, which the script does not touch.
  - Rows: WARN plus an ACTION naming the clean backup `…bak.2026-06-22T221110Z`.

**build-deploy and hashes**
- Isolated `build-deploy.sh` (scratch HOME and a scratch clone of the dotprofile): the generated `deploy/setup-user-shell.*` parse. The `.ps1` degrades to WARN `aliases.ps1 not found`.
- pywinpty hashes were re-read from the PyPI JSON API and match the file.

**Repo checks** (Windows `.ps1` halves, run from the worktree)

| Check | Result | Notes |
|---|---|---|
| `check-pre-commit` | 6 PASS, 11 SKIP, 1 WARN, 1 FAIL | The FAIL is step 20: three dead path refs, all in files this PR does not touch (`CLAUDE.md:100`, `reference/tool-registry.md:341`, `shared/claude-shared.md:95`). Pre-existing. |
| `check-post-push` | 25 PASS, 3 SKIP, 4 WARN, 1 FAIL | The FAIL is step 1 (HEAD != origin/main), expected on a branch.<br>Step 19 WARN flags `setup-user-shell.sh` for `cat >`; that is the temp-file heredoc, which is also on main. |
| `check-pre-push` | WARN steps 1, 5, 6; step 7 crashes | Step 7 reads the dotprofile's committed `deploy/`. The dotprofile stopped tracking `deploy/` today (dotprofile fecff7e, json-review mission), so `Get-ChildItem …\committed\deploy` throws at `check-pre-push.ps1:254`.<br>Run from Git Bash instead, the step fails earlier: GNU `tar` on PATH reads `C:` as a remote host.<br>Neither failure is caused by this PR. |

## Not run

- The `.sh` suite on real macOS/Linux; CI runs it, including `/bin/bash` 3.2.
- `aitools` or `aitools install` end to end; agents never run them against the real HOME.
- `pip install pywinpty`: Phase 2 gate.
- The bash entry point `scripts/aitools`: no change, because there is no evidence it needs one.

## Review after (D-DEL5, old → new)

**`reference/ait-shellintegration.md` v1.0 → v1.1**
- Scope: adds the integration block, repair and damage reporting, and the rc targets.
- Marker convention: "rewritten in place on every run" → a current profile is not rewritten; any other write is backed up first.
- New section: "Repair and damage (incident #172)".
- New section: "Shell integration block (Windows)", covering legacy migration and MDM behaviour.
- Owns: the PATH block → both blocks plus the rc source line; Step 7 only runs `setup-user-shell`.
- Per-platform table: `.bash_profile` only → `.bash_profile`, `.bashrc` (created if absent) and `.zshrc` (if it exists); the Windows rc column becomes "`$PROFILE` (shell integration block)".

**Other spec changes**
- `reference/evaluations/pywinpty-windows-2026-11-13.md`: none → v1.1. The recommendation is a `--user` install, hash-pinned, from the repo requirements file. There is no registry entry, because pywinpty is a test-only library.
- `tests/managed-files/requirements-windows.txt`: 2 hashes (cp312, cp313) → 8 (cp310–cp315 win_amd64).
- Profile contract: the shell integration in `$PROFILE` moves from the unmarked `# aitools shell integration` lines to the marked `# >>> aitools shell integration >>>` block. The dot-source now uses single quotes.

**Awaiting the commander (Phase 2 gate)**

Proposed install, from the aitools checkout root in pwsh:

`python -m pip install --user --only-binary=:all: --require-hashes -r tests/managed-files/requirements-windows.txt`

Test it with:

`python tests\managed-files\winpty-probe.py 'C:\Program Files\Git\usr\bin\bash.exe'`

Rollback:

`python -m pip uninstall -y pywinpty`

## Follow-ups

- PR 2: fix 1 (`Read-ConsoleChoice` forces cooked console mode and flushes typeahead) and fix 5 (verify the AI-merge spinner shows on Windows, and replace it if not), once the json-review PR merges. It may also move `AitConsoleModeGuard` into `aitools-lib.ps1`.
- Incidents #172 and #173 can close with this PR (corrective action: this change; prevention: Detection, the setup-user-shell suites in Windows, macOS and Linux CI).
- The `.bashrc`/`.zshrc` aliases line could become a marked block once there is a macOS test run.
- The commander's profile keeps 7 blank lines above the migrated block; only one blank line is removed per legacy block.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
