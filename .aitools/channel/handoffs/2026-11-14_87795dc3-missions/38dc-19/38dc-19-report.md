# 38dc-19-report -- mission 38dc-19-aitools-win-forwarder (v1.0)

**Intent**: **Purpose**: record what mission 38dc-19 changed, why, how it was
verified and what is left, for the orchestrator M6-Polish and the commander.
**Scope**: PR #162 (branch `fix/38dc-19-aitools-win-forwarder`), issue #163,
the evidence behind both. NOT the 38dc-13 test-suite guards. **Audience**: the
commander; M6-Polish.

Version 1.0, 2026-11-14, written before the independent review and the merge;
the merge commit and main's CI run are in the mission's final response.

## Summary

1. On Windows (Git Bash) `scripts/aitools` now `exec`s `pwsh -NoProfile -ExecutionPolicy Bypass -File <aitools.ps1> <args>` inside `main()`, before argument parsing and before `aitools-lib.sh` is sourced.
2. `aitools.ps1`'s dashboard dispatch was broken for every flag (in-process array splat binds by position); it now uses `pwsh -File`, which the dashboard-serve hook needs once the forward is in place.
3. `hh.sh`, `bootstrap.sh`, `init-hh-hooks.sh`, `analyze-session.sh` carry the POSIX guard; the exemptions table is updated.
4. New suite `tests/aitools-entry/test-win-forwarder.ps1`: 32/0, 12/12 mutations killed.
5. Issue #163 filed: Python dashboard-serve path (`aitools.py`, Python hook in exec form, Python logging library).

- PR: https://github.com/nobul-tech/aitools/pull/162
- Issue: https://github.com/nobul-tech/aitools/issues/163

## What ran the bash `aitools` on Windows (investigation)

| Caller | Evidence | Before | After |
|---|---|---|---|
| `dashboard-serve.sh` SessionStart hook | `shared/hooks/dashboard-serve.sh` lines 34-45 (`command -v aitools`, `"$AITOOLS" dashboard --background --project-root "$PROJECT_ROOT"`); registered as `bash "<path>"` (`scripts/setup-user-hooks.ps1`: "Hook command uses Unix-style path (hooks run in bash even on Windows)") | bash entry, `source aitools-lib.sh`, `logging_init`, then `pwsh -File aitools-dashboard.ps1` | forward -> `aitools.ps1` -> `pwsh -File aitools-dashboard.ps1` |
| A Git Bash terminal / an agent's Bash tool | `~/.local/bin/aitools` installed by `aitools-install.ps1` Step 6 and rewritten by `aitools.ps1` at the end of each run (`$bashDst`) | full bash runtime: lib, `read_menu_choice`, `show_summary`, the relay prompt, `deploy_configs` Windows branch | forward -> `aitools.ps1` |
| `aitools-install.ps1`, `bootstrap.ps1` (`& aitools`), `hh.ps1` | pwsh resolves `aitools` to `aitools.ps1` | not callers | unchanged |

Bash library code that still runs on Windows: none from `scripts/aitools`. `aitools.ps1` itself still runs `build-deploy.sh` with Git Bash (approved cross-language exception, cross-platform.md) and Claude Code still runs the hooks in bash.

The four `.sh` entry points: `hh.sh` is installed only by `aitools-install.sh` (`HH_SRC`, Step 6), which forwards to `aitools-install.ps1` on Windows; this machine's `~/.local/bin` has `hh.ps1` and no `hh`. `bootstrap.sh` already died on any uname but Darwin/Linux. `init-hh-hooks.sh` and `analyze-session.sh` have no caller (README / their headers: manual).

Baseline reproduction of the dashboard bug (origin/main, isolated HOME): `pwsh -File scripts/aitools.ps1 dashboard --status` -> `Cannot process argument transformation on parameter 'Port'. Cannot convert value "--status" to type "System.Int32"`, exit 0; same for a native call.

## Forward design

- `aitools_win_forward` (scripts/aitools): `command -v pwsh` or exit 1 with an install hint; aitools.ps1 = `<repoPath>/scripts/aitools.ps1` (repoPath / aiToolingRepoPath from `~/.aitools/config.json`, default `~/repos/aitools`), else `$(dirname "$0")/aitools.ps1`, else exit 1; `exec pwsh ... -File "$(cygpath -w "$ps1")"`.
- `aitools_ps1_args`: probed with the real param block under `pwsh -File` from Git Bash: `--version`, `-v`, `--help`, `--force`, `--patch`, `--alias V` bind by name; `--dry-run`, `--skip-gh-auth`, `--skip-drive-detection`, `--repos-path P`, `--project-root` go to `$Remaining`; `--addmcp a b` binds `-AddMcp a` and makes `b` the command; `-AddMcp a,b` arrives as one string. So it rewrites `--dry-run`, `--skip-gh-auth`, `--skip-drive-detection`, `--repos-path P` (`cygpath -w`), `--addmcp ...` (joined, emitted last), and passes `--alias V`, everything from `dashboard` on, and all else unchanged and in order. `aitools.ps1` splits `-AddMcp` on commas.
- Detection: `uname -s` like every other Windows branch in the file (no shim in product use); not the 38dc-13 `BASH_VERSINFO[5]` test-suite case.
- Known differences from the old bash behaviour on Windows (they are `aitools.ps1`'s behaviour, the same as a pwsh user gets): `--alias` with no value is a pwsh binding error (exit 1) instead of the bash message; an unknown `--flag` is ignored by `aitools.ps1` instead of "unknown argument"; `--help`/`--force`/`--version` after `dashboard` bind to `aitools.ps1`.

## Tests

`tests/aitools-entry/test-win-forwarder.ps1` (Windows guard, CI windows job): 3 static cases (placement inside `main()` before the parse loop and `source "$aitools_lib"`; the uname case and `return 1`; `command -v pwsh` before `exec pwsh ... -File "$(cygpath -w ...)"`), 15 argument cases against a stub `aitools.ps1` built from the real param block (AST), exit codes 0/1/2/7, stdin, no pwsh, the `~/.local/bin` fallback, no aitools.ps1, and 5 e2e cases with the real `aitools.ps1` and a stub `aitools-dashboard.ps1` built from its real param block. A fixture `aitools-lib.sh` writes a marker and exits 99 if sourced; every case checks it was not.

Mutation check (`.scratch/session-38dc-19/mutate.ps1`, one tree copy per mutation): 12/12 killed -- forward call removed (30 failing cases), forward block removed (30), `--skip-gh-auth` not rewritten (1), `--addmcp` not collected (5), no `exec` (22), aitools.ps1 splat restored (3), AddMcp split removed (2), no sibling fallback (1), no pwsh check (2), `--dry-run` not rewritten (2), dashboard args rewritten (1), `--repos-path` without `cygpath -w` (1).

Other runs: `test-console-mode-guard.ps1` 76/0/7 skip; the four guards under Git Bash with an isolated HOME exit 1 with the message and write only `~/.aitools/logs`; 38dc-13's `classify-guards.pl` classifies them `posix`; `bash -n` on each touched `.sh`; pwsh parser on `aitools.ps1` (CRLF 2288, bare LF 0); `check-pre-commit.ps1` 12 PASS / 3 WARN / 0 FAIL; `check-pre-push.ps1` 8 PASS / 2 WARN / 0 FAIL; `check-ci-suites.pl` 42 suites OK.

## Guards added

| Script | Form | Message |
|---|---|---|
| `scripts/hh.sh` | standalone (installed alone as `~/.local/bin/hh`): `printf '[%s] [hh] [error] ...' >&2` | "This script is for macOS/Linux. On Windows, use hh.ps1 (pwsh)." |
| `scripts/bootstrap.sh` | standalone (run from curl) | "This script is for macOS/Linux. On Windows, use bootstrap.ps1 (irm ... \| iex)." |
| `scripts/init-hh-hooks.sh` | aitools-lib + init-logging, `log_error` | "This script is for macOS/Linux. On Windows, run: git config core.hooksPath scripts/githooks" |
| `scripts/analyze-session.sh` | aitools-lib + init-logging, `log_error` | "This script is for macOS/Linux. It has no Windows version yet." |

## Exemptions table (old -> new)

- "Entry points sourced or run on any platform (rationale unrecorded, pending approval)": `bootstrap.sh/.ps1`, `hh.sh/.ps1`, `relay-outbound-prompt.sh/.ps1`, `init-hh-hooks.sh` / "Bootstrap/shell helpers; each `.sh` also runs in Git Bash" -> `bootstrap.ps1`, `hh.ps1`, `relay-outbound-prompt.sh/.ps1` / which run where, and that the four `.sh` are guarded since 2026-11-14.
- "Analysis tools (rationale unrecorded, pending approval) | `analyze-session.sh`" -> removed.
- "Entry points with Windows branches": `aitools` "dispatches the `.ps1` setup scripts" -> "forwards to `aitools.ps1` (`pwsh -File`) before its library loads, so no bash library code runs on Windows (commander, 2026-11-14, RFI 38dc-3)".
- "OS guard patterns": new paragraph on the standalone guard form. `.cursor/rules/cross-platform.mdc` mirrors all of it.

## Not run

`.sh` suites (CI only); `check-post-push`; a live Claude Code session running the dashboard-serve hook against the newly installed `~/.local/bin/aitools`.

## Signals

- WRITE_BLOCKED: Write `C:\Users\jdpal\repos\aitools\.scratch\placeholder-ignore.txt` -- "Permission for this action was denied by the Claude Code auto mode classifier. Reason: [Destructive or Unwanted Actions]." My mistake (a wrong path into the main checkout while preparing the PR body); not retried, nothing needed there.
- CONFLICT: cross-platform.md "Source `init-logging` before the guard" vs `bootstrap.sh` (curl, no files on disk) and `hh.sh` (installed alone) -- resolved by tier 1 (the rule's structured-logging requirement) over its mechanism: the guard prints the structured line itself; the rule now records this form (review after).
- CONFLICT: prompt "forwards to `pwsh -NoProfile -File <repo>/scripts/aitools.ps1 <same args>`" vs `pwsh -File` binding, which changes the meaning of five flags if passed verbatim -- resolved by tier 1 ("make no mistakes") and the prompt's intent: same meaning, five flags rewritten; the `~/.local/bin` copy as fallback when the repo copy is missing.
- CONFLICT: cross-platform.md "Dead code from platform guards" vs scope (38dc-13 is rewriting `tests/hookin`, which runs `deploy_configs`' Windows branch) -- resolved by tier 2 (scope): the existing Windows branches below the forward stay; follow-up.
- CONFLICT: delegate naming "`<last 4 hex of YOUR id>-<seq>-<objective>`" vs my agent id not being visible to me -- resolved by tier 2: the reviewer is `38dc-19-01-pr162-review`.
- INCIDENT: `aitools.ps1` never stamps the installed version: `-replace '^\$AITOOLS_INSTALLED_VERSION = ".*"'` and `'^AITOOLS_INSTALLED_VERSION=".*"'` run on whole-file strings without `(?m)` (scripts/aitools.ps1, self-update and reload blocks), so both `~/.local/bin` copies say `dev` (this machine). Not filed (a bug with repro: GitHub issue per incident-governance).
- INCIDENT: `aitools.ps1` dashboard dispatch bug (fixed in #162): every `aitools dashboard <flag>` failed in pwsh and exited 0. Not filed; fixed.

## Open questions

RFI 38dc-19-1: Guard the Windows-only `.ps1` twins too?
`bootstrap.ps1` and `hh.ps1` stay exempt with no Windows guard; under pwsh on macOS/Linux they would run. Suggest: the canonical Windows guard on both in a follow-up after #160 (which edits `bootstrap.ps1`) merges (the commander's "ps1 on windows").

RFI 38dc-19-2: Remove the dead Windows branches of `scripts/aitools`?
They are unreachable on Windows now. Suggest: remove them after 38dc-13 merges, in one PR with the `tests/hookin` Windows `loop` case (it tests that branch).

## Operational learning

- `pwsh -File` binds a GNU-style `--name` to a parameter when the name matches exactly (`--force` -> `-Force`, `--alias`), never a hyphenated one (`--dry-run`, `--project-root`); a `[string[]]` parameter takes one value per `-File` token, so lists need a comma string and a split. A native pwsh call binds `--name` as a literal positional string. (probes in `.scratch/session-38dc-19/probe-args*.sh`)
- An in-process array splat of strings (`& $script @array`) binds every element by position; `-Name` strings are not parameter names there. Run the script with `pwsh -File` for GNU-style flags.
- A PowerShell function that returns an empty array returns `$null`: `return , @(...)`.
- `bash -n a b c` checks only `a`.
- Git for Windows bash 5.3.15 reports `x86_64-pc-cygwin` in `BASH_VERSINFO[5]`, `uname -s` `MINGW64_NT-...`.
- Claude Code 2.1.325 hooks: exec form (`command` + `args`) runs with no shell on every platform; on Windows `command` must be a real `.exe`; `shell: "powershell"` exists (code.claude.com/docs/en/hooks, read 2026-11-14).
