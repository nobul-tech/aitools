# e9d6-02 report: Windows .ps1 harnesses for tests/claude-mdm and tests/hookin

Version 1.0, 2026-11-14. Author: e9d6-02-port-mdm-hookin, delegated by
38dc-13-windows-ci-ps1-only. Worktree W = `C:\Users\jdpal\repos\aitools\.claude\worktrees\38dc-13`.
Nothing committed (the prompt forbids git add/commit/push).

## Summary

1. New `tests/claude-mdm/test-claude-mdm.ps1`: 33 passed, 0 failed, 1 skipped locally; the same 34 result lines as the Git Bash harness's Windows CI run (2 differ only by the machine's hostname inside the check name).
2. New `tests/hookin/test-hookin.ps1`: 29 passed, 0 failed, 0 skipped locally; the same 29 lines as CI, 0 differences.
3. Both `.sh` harnesses: the corrected OS guard (`BASH_VERSINFO[5]`, 38dc-13's contract correction), every ps1/windows branch removed; `bash -n` OK; each refuses Git Bash (exit 1, guard message, no stdout, no temp dir).
4. Mutation proof: 4 mutations per suite, each turns a PASS into a FAIL and exits 1. The files were restored byte for byte, and `git diff -- tests/claude-mdm/golden` is empty.
5. No product bug found; no INCIDENT. One CONFLICT (the guard text), resolved by the newer delegating-agent correction. Two contract change requests.

## Per suite

### tests/claude-mdm

**Windows-reached code tested** (all paths under W):
- `scripts/setup-user-claude.ps1` (dev path), native pwsh, with `scripts/aitools-lib.ps1` and the resolver `scripts/aitools-profile.ps1` (stubbed through `AITOOLS_PROFILE_PS1`, and live).
- `scripts/build-deploy.sh` (cross-platform bash) run with Git Bash (`Resolve-TestGitBash`), and the bash lib `scripts/aitools-lib.sh` it sources, including `_aitlib_profile_run`'s Windows branch (it runs `fail.ps1` through pwsh in the A-20 cases).
- The generated `<fixture dotprofile>/deploy/setup-user-claude.ps1`, `setup-user-cursor.ps1`, `setup-user-settings.ps1` (A-19 dry runs, in-process `& script`, full run, MDM smoke runs); the generated `.sh` files only through Git Bash `test -x` and `bash -n`.
- `tests/managed-files/pty-run.py` (pywinpty / ConPTY) for the A-20 terminal case.

**Class**: c (a .ps1 equivalent written). Cases that need Git Bash, and why: "build: ..." (5 checks), "build A-19 ..." static/parse (2), and A-20 (3), because `build-deploy.sh` is bash (cross-platform.md "Build scripts"). The A-19 runtime and MDM cases need its output. Without Git Bash or node, all of these are one SKIP line, as the .sh did without node.

**CI vs local**: CI (run log `W\.scratch\session-38dc-13\ci-windows-main.log`, step "setup-user-claude dev + MDM tests (.ps1, native pwsh)") 33 passed, 0 failed, 1 skipped. Local: 33 passed, 0 failed, 1 skipped, the same 34 lines in the same order. Differing lines (both are the live hostname, part of the check name in the .sh too):
- line 3: CI `... equals 'aitools-profile hostname' (runnervm9zap3)`, local `(newcopc)`
- line 29: CI `... footer hostname = resolver's (runnervm9zap3), ...`, local `(newcopc)`
- The SKIP `ps1 unreadable CLAUDE.md case (chmod does not block reads here)` stays a SKIP with the same text. The .sh makes the file unreadable with `chmod 000`, which NTFS does not honour, and CI never ran the case on Windows. Golden `dry-4.rows` is therefore checked only by the .sh harness. See open question Q1.

**Mutations** (`W\.scratch\session-e9d6-02\mutate.ps1`; logs `mutate-results.log`, `mutate-claude-mdm-round2.log`):
| # | Mutation | Check that failed | Exit |
|---|---|---|---|
| a | golden `dry-2.rows`: `OK\|claude.md\|verified` -> `...verifiedX` | `parity A-26 (after a deploy): claude.md rows match golden` | 1 |
| b | harness expected row `dry-run: would create` -> `would CREATE` (dev A-26 check) | `ps1 A-26: dry run, no CLAUDE.md -> one row 'dry-run: would create', nothing written` | 1 |
| c | env: the stub override set as `AITOOLS_PROFILE_PSX` instead of `AITOOLS_PROFILE_PS1` | `ps1 A-25: footer hostname is the resolver's (stub-host)`, `ps1 A-25: empty resolver hostname -> footer 'unknown'` | 1 |
| d | Git Bash path: `fail.ps1` prints `stub resolver FAILURE` | `A-20 resolver error: the child's error line is in deploy.log once, ...`, `A-20 on a terminal: ...` | 1 |

I ran the four claude-mdm mutations twice. Round 1 was on the first version. Round 2 was on the final file, after the local-edit guard and the `-Help` fix: identical results, every one exit 1, restored=True.

Final runs on the final files (`claude-mdm-final2.log`, `hookin-final2.log`): claude-mdm exit 0 (33/0/1), hookin exit 0 (29/0/0), each compared again with CI (same differences as above).

### tests/hookin

**Windows-reached code tested**:
- `scripts/aitools`: `deploy_abort` and `deploy_configs` (its Windows branch, the .ps1 list run with pwsh plus the parse check), extracted the same way as the .sh harness (from the `name() {` line to the next line starting with `}`) and run with Git Bash on a fixture repo's `scripts/` (copies of `aitools-lib.sh/.ps1`, `deploy-harness.ps1`, stub setup scripts).
- `scripts/aitools.ps1` `Invoke-DeployAbort` + `Deploy-Configs` and `scripts/aitools-install.ps1` `Invoke-HarnessStep`, loaded by `tests/hookin/hookin-driver.ps1` (AST), native pwsh; through them, the real `scripts/deploy-harness.ps1` (fixture copy, Windows guard intact).
- Static file checks of `scripts/aitools-install.sh/.ps1`, `scripts/aitools`, `scripts/aitools.ps1`.
- `tests/managed-files/pty-run.py` (pywinpty) for the three abort cases.

**Class**: c. Cases that need Git Bash: the 5 `loop (ps1 list) ...` checks, because `scripts/aitools` is the bash entry point with a Windows branch (cross-platform.md exemption table). Without Git Bash they are one SKIP line.

**CI vs local**: CI (step "Installer harness hook-in tests (.ps1 native pwsh, scripts/aitools Windows branch)") 29 passed, 0 failed, 0 skipped. Local: 29 passed, 0 failed, 0 skipped, 0 differing lines.

**Mutations**:
| # | Mutation | Checks that failed | Exit |
|---|---|---|---|
| a | expected `$loopStubs` order (first two names swapped) | `loop (ps1 list): deploy-harness first, then the 7 scripts`, `loop (ps1 list) exit 1: ...`, `ps loop: deploy-harness first, ...`, `ps loop exit 1: ...` | 1 |
| b | `hookin-driver.ps1`: `$stepArgs = @{}` (SkipConfig never passed) | `ps step -SkipConfig: returns 0, writer not run, OK config.json n/a (written by installer)` | 1 |
| c | env: `AITOOLS_SUMMARY_FILE` pointed at `summary2` | 11 checks (every row check, loop and ps) | 1 |
| d | Git Bash loop driver `dry_run=true` | `loop (ps1 list): writer runs once ...`, `loop (ps1 list): deploy-harness first, ...`, `loop (ps1 list) abort: ...` | 1 |

Mutation d, round 1, found a harness defect: with nothing deployed, the abort case's "local edit" write threw (`$ErrorActionPreference = "Stop"`). The suite still exited 1, but with no count line. The .sh's `printf >` reports the error and goes on. Fixed with `LocalEdit` (try/catch, error printed, suite continues), and the same guard was added around claude-mdm's local edit. Round 2 (`mutate-hookin-round2.log`): all four mutations exit 1 with a full count line (d: 26 passed, 3 failed).

## Syntax and guard

- PowerShell parser (`W\.scratch\session-e9d6-02\parse.ps1`): `test-claude-mdm.ps1`, `test-hookin.ps1`, `hookin-driver.ps1` parse with no errors.
- `bash -n`: both edited .sh files OK.
- Guard (`verify-sh.sh`): `bash tests/claude-mdm/test-claude-mdm.sh` -> rc 1, stdout empty, stderr `This script is for macOS/Linux. On Windows, run tests/claude-mdm/test-claude-mdm.ps1 with pwsh.`; same for hookin with its own path; `--help` is refused too (the guard comes first); `/tmp` entry count unchanged (677 before and after). This machine's `BASH_VERSINFO[5]` is `x86_64-pc-cygwin`. The `uname` case refused first; the `BASH_VERSINFO` case was not exercised alone (that would need a uname shim, and the prompt forbids spoofing).
- `--help` ranges: claude-mdm header is now lines 2-40 (the perl range moved from 39 to 40; line 41 is blank); hookin's reader stops at the first non-comment line (no range).
- `-Help` on the new .ps1 files prints the header (claude-mdm 37 lines, hookin 40 lines), exit 0. The exemplar's `-Help` (`Select-Object -Skip 1`) drops the header's first line, the title, because a .ps1 has no shebang. Mine print from line 1 (see observation O2).
- Real-HOME safety: every child ran under temp HOME/USERPROFILE; `build-deploy.sh` wrote only the temp fixture dotprofile. The real dotprofile `C:\Users\jdpal\repos\aitools-nobul-jose` has `deploy/`, the five `deploy.bak.*` directories, `profile.json`, `claude/` and every top-level entry with the same mtimes before and after. The one exception is `.git/` itself: its directory mtime moved from 11:17:36 to 11:39:29 (-0800). Its `index` (2026-11-13 16:04), `HEAD`, `FETCH_HEAD` (11:11) and `refs/` did not change, so a transient file such as a lock was created and removed. Other sessions share this machine. I have no evidence that these tests did it, but I cannot rule it out (unknown).

## Files changed (W)

| File | Change |
|---|---|
| `tests/claude-mdm/test-claude-mdm.ps1` | new, the Windows harness (v1.0) |
| `tests/claude-mdm/test-claude-mdm.sh` | guard; the ps1 branches, the .ps1 resolver stubs, USERPROFILE / TMP / TEMP / native_path, the Windows pty check and the "MDM ps1 full run" block removed; header platform paragraph; `--help` range 39 -> 40 |
| `tests/hookin/test-hookin.ps1` | new, the Windows harness (v1.0) |
| `tests/hookin/test-hookin.sh` | guard; the PowerShell section, the fixture's PowerShell twins, USERPROFILE / native_path, the Windows pty and pwsh checks removed; the always-true `LANG_RUN = sh` wrappers removed (install block de-indented by `W\.scratch\session-e9d6-02\hookin-sh-edit.pl`); header |
| `tests/hookin/hookin-driver.ps1` | header comment only (2 lines): "for test-hookin.ps1" instead of test-hookin.sh |

Golden files are unchanged; nothing in `tests/lib/`, `scripts/`, `shared/`, `.github/` or the docs was touched.

Why the removed .sh lines were dead on macOS/Linux (cross-platform.md "Dead code from platform guards"):
- `native_path` returns its argument unchanged off Windows (`tests/lib/platform-lib.sh` `native_path`).
- `AITOOLS_PROFILE_PS1` / the `.ps1` stubs: the bash lib runs the .ps1 resolver only when `AITOOLS_PLATFORM` is windows or `AITLIB_PROFILE_VIA_PWSH=1` (`scripts/aitools-lib.sh` `_aitlib_profile_run`), and the harness sets neither.
- `USERPROFILE`: no `scripts/*.sh` reads it except as a fallback when HOME is empty (`scripts/hh.sh`, `scripts/setup-user-hooks.sh` node snippets).
- `TMP`/`TEMP` in A-19: the generated embed dir uses `[System.IO.Path]::GetTempPath()` (`scripts/build-deploy.sh` embed block), which is TMPDIR on Unix; TMPDIR is kept.
- The fixture's `.ps1` copies in hookin: `deploy-harness.sh` reads only its `add_source` directories and the three bin CLIs (`scripts/deploy-harness.sh` "add_source" / "for cli in" lines), not `scripts/*.ps1`.

Not run: the edited .sh harnesses past their guards (macOS/Linux CI runs them). Only `bash -n` and the refusal checked them here; the bash 3.2 constructs are unchanged (`${BASH_VERSINFO[5]:-}` is valid in 3.2).

## Port decisions (deviations from a literal translation, each with its reason)

- Env path forms: HOME/USERPROFILE/log/summary values for pwsh children use forward slashes (C:/...), as `cygpath -m` gave the Git Bash harness. For Git Bash children, HOME, the script path and the stub overrides are MSYS paths (`ConvertTo-MsysPath`): `build-deploy.sh` derives its root with `dirname`, which does not split backslash paths.
- claude-mdm writes no `.sh` resolver stubs. The Windows lib reads only `AITOOLS_PROFILE_PS1` (`scripts/aitools-lib.ps1` resolver lookup). `Run-Claude` also removes `AITOOLS_PROFILE_SH/PS1` in live mode, where the old harness inherited them; CI has neither set, so this only adds isolation.
- The A-19 parse check parses in-process (`[Parser]::ParseFile`), not in a child pwsh: same parser.
- `[ -x gen.sh ]` is checked with Git Bash `test -x` (a scratch `is-exec.sh` in the suite's temp dir), so it is the same test as Git Bash makes.
- pty cases: `Invoke-TestScript` cannot be used (it redirects output to the file `pty-run.py` writes with `--log`), so the env is set and restored locally. pywinpty is checked as the .sh did (`python3 -c "import winpty"`). Empty input is passed as `--input=`.
- The ConPTY colour check keeps the Windows .sh semantics: any `ESC[` in the terminal log (see O1).

## Markers

- INCIDENT: none (no product bug found).
- CONFLICT: contract item 5's .sh guard (second case `${OSTYPE:-}`) vs 38dc-13's later CONTRACT CORRECTION (`${BASH_VERSINFO[5]:-}`, `*-msys*|*-cygwin*|*-mingw*`) -- resolved by tier 2, the delegating agent's newer instruction (it supersedes its own earlier prompt text; no commander words on it): used the corrected block verbatim in both .sh files.
- WRITE_BLOCKED: none. Two Bash calls were refused by the standing-order-guard hook (a `$(...)` in a Monitor command, a backtick in a perl one-liner's regex); I did the same work with a scratch script and with Edit. They were not write denials.

## Contract change requests (tests/lib/platform-lib.ps1)

1. `Invoke-TestScript` always redirects stdout+stderr to `-OutFile`. pty cases (`pty-run.py --log FILE`) need "set these variables, run, restore" with no redirection. Both harnesses carry a local copy (`Set-TestEnv` / `Restore-TestEnv` in claude-mdm, inline in hookin's `Run-Env`). Suggest an `Invoke-WithTestEnv -Environment H -ScriptBlock {...}` helper, with `Invoke-TestScript` built on it.
2. Both harnesses define `Lines FILE` (CR-stripped lines, none for a missing file) and grep-style counters. Suggest `Get-TestLines` in the lib.

## Open questions (each with a suggested answer)

- Q1: Should the unreadable-CLAUDE.md case (golden `dry-4.rows`) run on Windows, using an ACL deny-read (`icacls /deny`) instead of chmod? Suggested: yes, as a follow-up mission. It would test `setup-user-claude.ps1`'s B-1 path, which no CI job exercises today. It is a new Windows case (a new PASS line), not part of this like-for-like port.
- Q2 / O1: On Windows, "A-20 on a terminal: the warning is coloured" accepts any `ESC[`. ConPTY re-renders the screen (the .sh comment and the `pty-run.py` docstring), and its own CSI sequences could satisfy that part with no colour from the build. Not verified here: the temp output is removed on exit. Suggested: match an SGR sequence (`ESC\[[0-9;]*m`) on both harnesses' Windows/ConPTY path. It is a check-semantics change, so it belongs to 38dc-13 or a follow-up, not this port.
- O2: the exemplar `tests/b8-consumers/test-b8-consumers.ps1` `-Help` drops its title line (`Select-Object -Skip 1`, copied from the bash `$. >= 2` that skips the shebang). Suggested: drop the `-Skip 1` there.

## New operational learning

- Git for Windows `bin\bash.exe` started from native pwsh runs `build-deploy.sh` and the extracted `deploy_configs` loop correctly when HOME and the script paths are MSYS form. Under ConPTY (`pty-run.py -- <bin\bash.exe> ...`) the wrapper still gives bash a terminal: the loop-abort and A-20 terminal cases pass.
- A pwsh harness with `$ErrorActionPreference = "Stop"` aborts on a fixture write into a directory the product failed to create. The bash harness reported the error and continued. A mutation that makes the product deploy nothing finds this; guard such writes and print the error.
- Do not edit a suite file while a mutation script runs on it: its finally restores the pre-mutation bytes and silently undoes the edit (it happened to my `-Help` fix; I reapplied it and re-ran).
- The standing-order-guard blocks a backtick anywhere in a Bash command, including a PowerShell escape inside a perl regex; use Edit for such replacements.
