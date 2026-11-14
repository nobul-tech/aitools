# e9d6-11 report: Windows .ps1 harness for tests/profile/test-user-init

Version 1.0, 2026-11-14. Author: e9d6-11-port-user-init (delegated by
38dc-13-windows-ci-ps1-only). Worktree W = `C:\Users\jdpal\repos\aitools\.claude\worktrees\38dc-13`.

## Summary

1. New `tests/profile/test-user-init.ps1`: native pwsh harness, Windows only, every case the
   .sh harness ran on Windows, same check names and order, same golden files.
2. Local run: 179 passed, 0 failed, 1 skipped, exit 0. The check lines are identical to the .sh
   harness's Windows CI run on main (179 / 0 / 1), compared line by line.
3. `tests/profile/test-user-init.sh` now refuses Windows (contract guard). Its ps1/Windows
   branches and Windows-only helpers are gone; macOS/Linux behaviour unchanged.
4. Mutations: all three turned a PASS into a FAIL, and each run exited 1: golden line, expected
   exit code, ConPTY keystroke.
5. No Git Bash is needed. The gh stub is now a PowerShell stub (`gh.cmd` runs it with the same
   pwsh). No golden file, product script or shared file was changed.

## What Windows-reached code the suite tests

All runs go through `scripts/aitools.ps1 user init` (block `# --- BEGIN user init ---` .. `END`:
`Invoke-UserInitCommand`, `Invoke-UserInit`, `Invoke-UiRegisterFlow`, `Read-UiChoose`,
`Invoke-UiRegister`, `Invoke-UiMigrate`, `Invoke-UiV1Migrate` (node), `Invoke-UiCreateDotprofile`,
`Invoke-UiScaffoldClaudeMd`, `Invoke-UiPush`, `Test-UiCanAsk`). It reaches:

- `scripts/aitools-lib.ps1`: `Invoke-AitLibProfile` (the resolver, in-process),
  `Invoke-ChildRelayed` (setup-user-config.ps1 and setup-user-hooks.ps1 through the relay),
  `Test-InteractiveConsole`, `Read-ConsoleChoice` (ConPTY menus), `Write-Summary` /
  `Show-Summary`, the deploy.log / deploy.jsonl writers.
- `scripts/aitools-profile.ps1` (resolve, register, migrate) and `scripts/aitools-json.ps1`
  (dot-sourced by it, `aitools-profile.ps1:147`).
- `scripts/setup-user-config.ps1` (the config.json writer, with or without `-NoMachine`).
- `scripts/profile-check.js` (node, run directly by the profile-check case).
- `scripts/setup-user-hooks.ps1` is replaced by a stub, as in the .sh harness.

No case exercises cross-platform bash code. So contract item 4 (Git Bash cases) does not apply,
and `Resolve-TestGitBash` is not used.

## Windows-relevant behaviours ported (class c: .ps1 equivalent written)

Each was a case of the .sh harness's Windows (ps1) run. Each is now in the .ps1 under the same
check names.

| # | Behaviour | Cases |
|---|---|---|
| 1 | Register this machine with -Alias and no terminal; re-run verifies; summary panel (dashed rule); machine.shell = pwsh, machine.os = win32, machine.arch set | alias-new, alias-new-rerun |
| 2 | -Alias of another machine's profile is refused without a terminal (exit 1, one machine-profile ERROR, writer run with -NoMachine) | alias-other |
| 3 | An unregistered machine with no terminal: ERROR + ACTION, exit 1 | unregistered-notty |
| 4 | -Alias claims a profile that no machine owns | alias-claim |
| 5 | Legacy alias-keyed profiles are re-keyed (migrate) | migrate |
| 6 | Dotprofile scaffold, Path 1 (no profile.json) and Path 3 (no dotprofile; gh repo create through the stub) | scaffold-path1, scaffold-path3 |
| 7 | Decision 2 switch: cached machineAlias at default ($false), flipped ($true), and the one-line switch in both entry points | cached-alias-0, cached-alias-1, "decision 2 switch" |
| 8 | Uncommitted profile.json edits are never committed (unregistered and registered) | dirty, dirty-registered |
| 9 | A rejected push (remote ahead) gives a pull --rebase ACTION | push-rejected |
| 10 | Hooks child exit 2 = abort (D-TS13); exit 3 = relay ERROR row; child warnings relayed to the console and deploy.jsonl | hook-abort, hook-crash, relay-jsonl |
| 11 | A relative reposPath is refused, and nothing is created under the cwd | relative-repos |
| 12 | Machine id undetectable (via=config): WARN, and the cached machineId survives two runs | via-config, via-config-rerun |
| 13 | -Alias wins over a stale AITOOLS_MACHINE_ALIAS | env-alias-stale |
| 14 | Path 2: gh repo exists, no clone: cloned, git identity from the profile | path2 |
| 15 | v1 profile.json is migrated to v2 rev 2.2 (node) | v1-migrate |
| 16 | profile-check.js reads machineId, id keys and legacy profiles | profile-check |
| 17 | ConPTY menus: claim, the hostname label, the duplicate-alias confirm and decline, re-ask on an empty answer, -Force without a prompt; menu golden | pty-claim, pty-hostname-other, pty-dup-confirm, pty-dup-decline, pty-claim-reask, pty-dup-reask, pty-force |
| 18 | alias-novalue: SKIP, as in CI (bash entry point only; pwsh binds -Alias) | alias-novalue |

None of these cases needed Git Bash.

## Harness design notes (how the .ps1 reproduces the CI environment)

- Paths given to aitools.ps1, git and config.json are in the mixed form (`C:/...`): HOME,
  USERPROFILE, AITOOLS_LOG_DIR, GIT_CONFIG_GLOBAL, GH_REMOTE, GH_CLONE_SRC, reposPath, repoPath
  and the bare remote URL. This is what the Git Bash harness passed (`cygpath -m` through
  `native_path`) in the CI runs the goldens were checked against. The `<D>` normalization covers
  the native, mixed and MSYS forms, as norm_run did.
- The gh stub is `bin\gh.cmd`, which runs `stub\gh-stub.ps1` with the same pwsh. It has the same
  logic as the bash stub (api user, repo view, repo clone, repo create). Native pwsh cannot run an
  extensionless bash script; the old gh.cmd ran the bash stub through Git Bash. The stub file
  is outside bin\ so that PowerShell never resolves `gh` to a .ps1.
- Fixture edits that perl -pi / -0pi made are byte-exact: `Edit-Bytes` round-trips Latin-1, so
  CRLF and BOMs are kept. The decision-2 flip edits the CRLF-checked-out aitools.ps1.
- JSON checks use System.Text.Json with case-sensitive keys, as aitools-json.pl get/type does.
  PowerShell's ConvertFrom-Json would match keys case-insensitively.
- The harness's own git commands run with an empty GIT_CONFIG_GLOBAL and GIT_CONFIG_NOSYSTEM=1.
  Each aitools.ps1 run gets the case's .gitconfig, as before.
- Multi-line fixture strings are joined with `` `n `` and are not here-strings. Git checks .ps1
  out as CRLF, so a here-string would write CRLF into profile.json on a CI checkout.
- Out-Count passes when the count is at least N, as the .sh did on Windows (ConPTY re-renders).
- Non-pty runs use `-NoProfile -NonInteractive -File` (contract item 3). The pty runs omit
  -NonInteractive, as the .sh did. `Test-InteractiveConsole` reads
  `[Environment]::UserInteractive` and `[Console]::IsInputRedirected`, so the flag does not change
  the outcome.
- The .sh exit-early check "pwsh is not on PATH" is dropped: the harness is itself pwsh.

## CI count vs local count

- CI: `.scratch/session-38dc-13/ci-windows-main.log`, section `bash tests/profile/test-user-init.sh`
  (`ci-section.py`): `test-user-init: 179 passed, 0 failed, 1 skipped (windows: ps1 entry point)`.
- Local: `pwsh -NoProfile -File W\tests\profile\test-user-init.ps1` (run 2, exit 0):
  `test-user-init: 179 passed, 0 failed, 1 skipped (windows: ps1 entry point)`.
- Line-by-line comparison (`.scratch/session-e9d6-11/compare.py`, every `  ok   `, `  FAIL `,
  `  skip ` line and the count line): ok 179/179, FAIL 0/0, skip 1/1, "identical check lines".
  No line differs.
- Run 1 had one FAIL, `path2: clone identity 'J'`. This was a bug in my harness: PowerShell
  unrolled a one-line result to a string and `[0]` took its first character. Fixed with `@()` at
  both call sites (Remote-Count passed only by luck: a one-digit count). Run 2 is the clean run
  above.

## Mutation results

Each mutation ran the harness on a scratch copy (`.scratch/session-e9d6-11/mut-<x>/`) of the
files it reads: scripts/, shared/, tests/lib, tests/managed-files, tests/profile/golden and
test-user-init.ps1. One change was made to the copy (`mutate.ps1`, which checks that its anchor
occurs exactly once). The real files were never modified. Afterwards,
`git diff -- tests/profile/golden` is empty and `git status --short tests/profile` shows only my
two files plus other delegates' files.

| Mutation | Change (in the copy) | Check that failed | Suite |
|---|---|---|---|
| a, golden line | userinit-alias-claim.txt `exit 0` -> `exit 9` | `alias-claim: result differs from golden userinit-alias-claim.txt` | 178 passed, 1 failed; exit 1 |
| b, expected value | `Case-Run "alias-other" 1` -> `0` | `alias-other: ps1 exit 1, want 0` | 178 passed, 1 failed; exit 1 |
| c, ConPTY keystroke | pty-claim input `1\n` -> `s\n` | `pty-claim: ps1 exit 1, want 0`; `pty-claim: result differs from golden userinit-pty-claim.txt`; `pty-claim: profiles.aaaaaaaa-... alias '' id '', want alias nobul-mac`; `pty-claim: menu differs from golden userinit-pty-claim-menu.txt` | 175 passed, 4 failed; exit 1 |

## Syntax and guard

- `bash -n W/tests/profile/test-user-init.sh`: clean (no output, exit 0).
- PowerShell parser (`.scratch/session-e9d6-11/parse.ps1`, `Parser::ParseFile`) on
  test-user-init.ps1: `parse OK`.
- Guard: `bash W/tests/profile/test-user-init.sh` exits 1 and prints
  `This script is for macOS/Linux. On Windows, run tests/profile/test-user-init.ps1 with pwsh.`.
  The guard runs before `mktemp`, so nothing is written. This was the only .sh run.
- `pwsh ... test-user-init.ps1 -Help` prints the header.
- The .ps1 OS guard is the contract's exact form (`if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {`,
  `[Console]::Error.WriteLine(...)`, `exit 1`), the first statement after `param` and the -Help
  line. Not run on macOS/Linux here (no such machine).

## Files changed

- `tests/profile/test-user-init.ps1` (new, LF; git converts to CRLF on checkout).
- `tests/profile/test-user-init.sh` (edited):
  - title line;
  - pty and platform header paragraphs, with the commander's 2026-11-14 quote;
  - the contract guard after `set -euo pipefail`;
  - removed: the pwsh-on-PATH check, the Windows pywinpty probe, `win_path`, the gh.cmd
    creation, the ps1 branch of `run()`, the Windows `>=` clause of `out_count`, the ps1 branch
    of the summary-rule check, the `else` SKIP of alias-novalue (now unconditional), the
    `native_path` calls (the identity off Windows), the win32 arm of the THIS_OS case.
  `--bash-only` is still accepted (it was never parsed). The `--help` range is unchanged:
  `last unless /^#/` stops at the first non-comment line, so no line range needed fixing.
  bash 3.2: no new constructs. The macOS/Linux output is unchanged (same cases, same names, same
  order; the removed branches never ran there). Not run on macOS/Linux by me (Windows machine;
  the guard forbids a .sh run past it here).
- Scratch only, not for commit: `.scratch/session-e9d6-11/` (compare.py, parse.ps1, mutate.ps1,
  run logs, mut-a/b/c copies).

## INCIDENT / CONFLICT / WRITE_BLOCKED

- INCIDENT: none found in product code.
- CONFLICT: contract "Mutate only your own files (your .ps1, and a userinit-* golden file), by a
  scratch script that restores the file in a finally" vs the same prompt's "keep a golden mutation
  to seconds" (a full suite run takes minutes, so an in-place golden mutation would stay live for
  minutes while other delegates run tests/profile suites) -- resolved by tier 2 (this prompt,
  the stricter reading of both): every mutation was applied to a scratch copy, so no real file
  was modified at any time. The proof is the same: the harness code and the goldens are
  byte-identical copies.
- WRITE_BLOCKED: none. The standing-order guard twice refused a long inline `perl -pi` (it saw
  backticks inside the perl program). These were my own violations of "Simple Bash only", not
  denials of a needed write. I made the same edits with the Edit tool.

## Contract change requests

None needed. Two notes for 38dc-13:
- `.github/workflows/check.yml` (not my scope): the Windows step "User init tests (.ps1, native
  pwsh, ConPTY menus)" must now run `pwsh -NoProfile -File tests/profile/test-user-init.ps1`. It
  needs python3 with pywinpty on PATH for the 7 pty cases (otherwise one SKIP line replaces them).
- `tests/lib/platform-lib.ps1`: a shared `Invoke-TestPty` (env set/restore + pty-run.py) would
  save each port from re-writing it. Optional; I used Invoke-TestScript with python3 as the
  FilePath.

## Open questions (each with a suggested answer)

1. The bash `aitools user init` Windows branch (`scripts/aitools`, per e9d6-01's inventory
   `:988-1026`) is tested on no platform. The .sh harness never had a case for it, and none was
   invented. Suggested answer: decide it together with e9d6-01's Q1. If bash `aitools` on Windows
   becomes a forwarder to aitools.ps1, a single forwarding case in a Git Bash-driven .ps1 harness
   is enough. Otherwise, add a Windows case that runs `scripts/aitools user init` with
   Resolve-TestGitBash.
2. The paths are in the mixed form (`C:/...`), kept from the CI environment the goldens were
   proven in. A real Windows USERPROFILE uses backslashes. Suggested answer: keep the mixed form
   for this port (parity first). As a follow-up, add one case with native backslash HOME and
   USERPROFILE to cover what Windows users actually have.
3. The new harness has not run in CI yet. Suggested answer: 38dc-13's PR CI run is the check; the
   local runs give no reason to expect a difference. RUNNER_TEMP is honoured by
   New-TestTempRoot, and python3 is used by test-adopt-push.ps1 in the same job.

## New operational learning

- A PowerShell function's array return is unrolled: a one-line result becomes a string, and
  `$x[0]` then takes its first character (path2 FAIL in run 1). Wrap calls you index in `@()`.
- `$script:PtyInput = '1\n'` (literal backslash-n) is the safest way to pass pty keys from
  pwsh. pty-run.py decodes the escapes, so no newline crosses the Windows command line.
- `[regex]::Replace` / `.Replace` with a scriptblock: cast it to
  `[Text.RegularExpressions.MatchEvaluator]`. Otherwise overload resolution can pick the string
  overload.
- PowerShell variable names are case-insensitive, so a function parameter named `$Case` or
  `$Script`, or a local `$h`, shadows script variables `$CASE` and `$H`. Use distinct names.
- A harness written with here-strings would write CRLF into fixtures after a CI checkout
  (.ps1 = eol=crlf). Join lines with `` `n ``.
- A golden mutation can run on a scratch copy of the harness inputs instead of the shared golden
  file. This keeps the shared worktree untouched however long the suite runs.
- Run time: not measured (I did not time the runs); measure it in the CI step.
