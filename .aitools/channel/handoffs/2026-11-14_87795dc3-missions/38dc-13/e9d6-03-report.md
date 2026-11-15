# e9d6-03-report -- Windows .ps1 harnesses for tests/skills-legacy and tests/rules-fanout

Version 1.0, 2026-11-14. Author: e9d6-03-port-skills-rules (delegated by
38dc-13-windows-ci-ps1-only). Worktree W = `C:\Users\jdpal\repos\aitools\.claude\worktrees\38dc-13`.
Scratch: `W\.scratch\session-e9d6-03\`. Nothing committed (mission scope: 38dc-13 commits).

## Summary

1. Both suites now have a native PowerShell Windows harness (`test-skills-legacy.ps1`, `test-rules-fanout.ps1`) with the .sh harness's cases, check names, order and golden files; neither runs anything in Git Bash except the MDM build (build-deploy.sh, cross-platform bash) and its `bash -n` check.
2. Before the extra cases, the local .ps1 runs printed exactly the CI Windows lines: skills-legacy 32 passed / 2 skipped, rules-fanout 61 passed / 3 skipped, identical text and order.
3. The chmod SKIPs became real cases with an ACL deny entry for the current user (evidence below): skills-legacy now 40 passed / 0 skipped, rules-fanout 65 passed / 2 skipped. Each new case matches the golden file the macOS/Linux .sh run wrote.
4. Both .sh harnesses have the OS guard (BASH_VERSINFO[5] form, per the 38dc-13 contract correction) and no Windows branches; both refuse Git Bash with exit 1, the guard message, and no temp dir.
5. Six mutations (three per suite: a golden line, an expected value, an environment variable a case depends on) each turned the target PASS into FAIL and made the suite exit 1; every file was restored byte for byte, golden diff empty.

## Suite 1: tests/skills-legacy

**Windows-reached code tested** (all from a fixture copy of `W\scripts`): `scripts/setup-user-skills.ps1` (fallback deploy, fan-out mode, reverse discovery, dry run, resolver error via `AITOOLS_PROFILE_PS1` stub, unreadable manifest / harness dir / target dir, pty adopt and adopt failure), `scripts/aitools-lib.ps1`, `scripts/aitools-profile.ps1`, `scripts/aitools-json.ps1`; the dev-order run of `scripts/setup-user-claude.ps1`, `setup-user-skills.ps1`, `setup-user-cursor.ps1` (stub `rg.cmd` / `agent.cmd`); `scripts/build-deploy.sh` (run with Git for Windows bash under an isolated HOME and a fixture dotprofile) and the generated `<fixture dotprofile>/deploy/setup-user-skills.ps1` (parsed in-process, run in a child pwsh) and `.sh` (`test -x` and `bash -n` with the same Git Bash). `tests/managed-files/pty-run.py` (pywinpty) for the pty cases.

**Class**: c (.ps1 equivalent written). Cases that need Git Bash: the MDM build (build-deploy.sh is an all-platform bash script; cross-platform.md exemptions table) and the `bash -n` / `-x` check of the generated .sh. No other case touches Git Bash.

**CI vs local** (CI = the .sh harness's Windows step on main, `W\.scratch\session-38dc-13\ci-windows-main.log`; compare script `W\.scratch\session-e9d6-03\compare-ci.py`):

| Run | PASS | FAIL | SKIP | Final line |
|---|---|---|---|---|
| CI (.sh, Git Bash driving pwsh) | 32 | 0 | 2 | `32 passed, 0 failed, 2 skipped (windows: ps1 scripts)` |
| local run 1 (`skills-legacy-run.log`, no ACL cases yet) | 32 | 0 | 2 | identical; every result line identical in text and order |
| local run 2 (`skills-legacy-run2.log`, final harness) | 40 | 0 | 0 | `40 passed, 0 failed, 0 skipped (windows: ps1 scripts)` |

Every line that differs between CI and run 2, with the reason:

```
-SKIP ps unreadable cases (chmod does not block reads here)
+PASS ps unreadable manifest: exit 1, ERROR skills row, reverse discovery not run
+PASS golden ps: mfu: summary rows
+PASS ps unreadable ~/.aitools/skills: exit 1, ERROR skills row, reverse discovery not run
+PASS golden ps: hdu: summary rows
+PASS ps unreadable ~/.claude/skills: exit 1, ERROR skills 'no adopt: target unreadable', logged
+PASS golden ps: dstu: summary rows
-SKIP ps pty adopt failure (chmod does not block writes here)
+PASS ps pty adopt failure (fanned out): exit 1, ERROR skills 'adopt failed: mine', no claude skills row
+PASS golden ps: adoptfail: summary rows
```

Reason: these SKIPs existed only because chmod changes nothing under Git Bash on NTFS. The .ps1 harness denies the same access with an ACL deny entry for the current user (`Deny-Access`: ReadData on the manifest, ListDirectory on `~/.aitools/skills` and `~/.claude/skills`, CreateFiles/CreateDirectories/DeleteSubdirectoriesAndFiles on the dotprofile's `claude/skills` for the adopt failure), and removes it right after the run (`Undo-Deny`, plus a sweep in the `finally`). The check names and conditions are the .sh's macOS/Linux ones, and the four golden files (`mfu.rows`, `hdu.rows`, `dstu.rows`, `adoptfail.rows`) were written by a macOS/Linux .sh run and are unchanged. A capability probe (`Test-DenyBlocksRead`) keeps the old SKIP lines, same text, where a denied read still succeeds.

## Suite 2: tests/rules-fanout

**Windows-reached code tested** (from a temp aitools checkout holding copies of `setup-user-claude.ps1`, `aitools-lib.ps1`, `aitools-profile.ps1`, `aitools-json.ps1` and their .sh twins): the rules fan-out of `scripts/setup-user-claude.ps1` (`~/.aitools/rules` -> `~/.claude/rules`: filters, preserved files, rerun, edit, `-Force`, retired rules and their backups, `[ ]` and case-only names, no / bad / invalid manifest, adopt target per manifest source, package payload without .git, pty adopt and abort, `-DryRun`, unreadable harness dir and manifest, a file in place of `~/.claude/rules`, a directory at the manifest path); the `aitools-lib.ps1` helpers `Record-DeployOutcome` ("removed", unknown outcome), `Write-DeployTrackerSummary`, `Get-RuleNameKind`.

**Class**: c. No case needs Git Bash.

| Run | PASS | FAIL | SKIP | Final line |
|---|---|---|---|---|
| CI (.sh, Git Bash driving pwsh) | 61 | 0 | 3 | `61 passed, 0 failed, 3 skipped` |
| local run 1 (`rules-fanout-run.log`, no ACL cases yet) | 61 | 0 | 3 | identical; every result line identical in text and order |
| local run 2 (`rules-fanout-run2.log`, final harness) | 65 | 0 | 2 | `65 passed, 0 failed, 2 skipped` |

Differences between CI and run 2:

```
-SKIP unreadable harness dir and manifest (root or Git Bash)
+PASS unreadable harness dir: ERROR row, exit 1
+PASS parity: unreadable: exit code, ~/.claude/rules and summary rows match golden (sh and ps share it)
+PASS unreadable manifest: rules fanned out, ERROR rows, final row ERROR, exit 1
+PASS parity: manifest-unreadable: exit code, ~/.claude/rules and summary rows match golden (sh and ps share it)
```

Reason: as in suite 1 (ListDirectory deny on `~/.aitools/rules`, ReadData deny on the manifest; goldens `unreadable.result` and `manifest-unreadable.result` from the .sh run, unchanged). Two SKIPs stay, with the CI text:
- `SKIP case-only duplicate (case-insensitive file system)`: NTFS is case-insensitive; the harness keeps the .sh's probe (`cs-probe` / `CS-PROBE`) and would run the case on a case-sensitive directory.
- `SKIP dangling symlink (Git Bash)`: kept, same text. Evidence (`W\.scratch\session-e9d6-03\probe-acl.ps1`, this machine, non-elevated): `New-Item -ItemType SymbolicLink` fails with "Administrator privilege required for this operation." The CI runner (runneradmin) may well be able to create it (unknown), but a case that would run only in CI cannot be verified here, so it stays SKIP (open question 2). The text says "Git Bash" although this harness is native pwsh: kept so the SKIP line matches the CI line; the header and a comment say why.

## Mutation proof

Script `W\.scratch\session-e9d6-03\mutate.ps1` (one occurrence replaced, suite run, original bytes written back in a `finally` and compared); summary `mutate-summary.log`, full runs `mut-SL-a.log` ... `mut-RF-c.log`.

| Id | File mutated | Mutation | Exit | FAIL lines (the target first) |
|---|---|---|---|---|
| SL-a | `tests/skills-legacy/golden/fan.rows` | `OK\|skills\|n/a (fanned out)` -> `... (fanned outX)` | 1 | `golden ps: fan: summary rows` (only FAIL; 39 passed) |
| SL-b | `test-skills-legacy.ps1` | fallback check expects `OK\|claude skills\|4 added` instead of `3 added` | 1 | `ps fallback: exit 0, claude skills and cursor skills rows, no skills row` (only FAIL) |
| SL-c | `test-skills-legacy.ps1` | resolver-error stub not set (`AITOOLS_PROFILE_PS1 = $null`) | 1 | `ps fanned out, resolver error: ...`, `golden ps: rerr`, `ps fallback, resolver error: ...`, `golden ps: rerrfb` (4 FAIL, exactly the two stub cases) |
| RF-a | `tests/rules-fanout/golden/fanout.result` | `OK\|claude rules\|4 added` -> `5 added` | 1 | `parity: fanout: ...` (only FAIL; 64 passed) |
| RF-b | `test-rules-fanout.ps1` | fanout check expects `3 added` | 1 | `fanout: exit 0, row 4 added` (only FAIL) |
| RF-c | `test-rules-fanout.ps1` | lib case run without `AITOOLS_SUMMARY_FILE` | 1 | `lib ps: removed outcome ...`, `lib ps: unknown outcome ...`, `lib parity: tracker rows match golden` (3 FAIL, the summary-dependent lib checks; the kinds check still passes, as it should) |

Afterwards: `git -C W status --short tests/skills-legacy tests/rules-fanout` shows only the two edited .sh and the two new .ps1; `git -C W diff -- tests/skills-legacy/golden tests/rules-fanout/golden` is empty. The unmutated parts of the six runs repeat the final results (40/0/0 and 65/0/2), so the ACL cases passed three more times each.

## Syntax and guard

- `bash -n` on both edited .sh: clean (no output, exit 0).
- PowerShell parser (`W\.scratch\session-e9d6-03\parse.ps1`, `[Parser]::ParseFile`) on both new .ps1: `parse ok`.
- Guard (`W\.scratch\session-e9d6-03\guard-check.ps1`, Git Bash `C:\Program Files\Git\bin\bash.exe`, the only .sh runs made):
  - `tests/skills-legacy/test-skills-legacy.sh`: exit 1, stdout empty, stderr `This script is for macOS/Linux. On Windows, run tests/skills-legacy/test-skills-legacy.ps1 with pwsh.`, no new `tmp.*` dir.
  - `tests/rules-fanout/test-rules-fanout.sh`: exit 1, stdout empty, stderr `This script is for macOS/Linux. On Windows, run tests/rules-fanout/test-rules-fanout.ps1 with pwsh.`, no new `tmp.*` dir.
  - Git Bash `${BASH_VERSINFO[5]}` = `x86_64-pc-cygwin` here (matches `*-cygwin*`); uname and OSTYPE were not spoofed.
- `-Help` on both .ps1 prints the header (lines 2 to the first non-comment line, the exemplar's convention of skipping line 1).
- Both new .ps1 guards match the tests/os-guards classifier (`classify-guards.pl`: `-not $IsWindows) {` ... `This script is for Windows` ... `exit 1`, no `}` between); both .sh guards match its POSIX pattern (no `;` between `MINGW*|MSYS*|CYGWIN*)` and `exit 1`).

## Files changed

| File | Change |
|---|---|
| `tests/skills-legacy/test-skills-legacy.ps1` | new, 600 lines: Windows harness |
| `tests/skills-legacy/test-skills-legacy.sh` | 576 -> 527 lines: guard; header platform paragraph; removed `LANG_RUN`/`L=ps`, the pwsh-on-PATH check, the pywinpty probe, the Git Bash `CAN_CHMOD_READ` line, `win_path`, `strip_cr`, the .ps1 branches of `script_cmd`, the `fail.ps1` stub and its `AITOOLS_PROFILE_PS1` setting, `native_path` uses, the `.cmd` stub twins, the `-DryRun` spelling, the `USERPROFILE` settings (run env and build), the Windows-only parse check of the generated .ps1; final line `(%s: sh scripts)` (same text as before on macOS/Linux) |
| `tests/rules-fanout/test-rules-fanout.ps1` | new, 596 lines: Windows harness |
| `tests/rules-fanout/test-rules-fanout.sh` | 529 -> 487 lines: guard; header; `--help` range 2-27 -> 2-26; `L=sh`; removed the pwsh check, pywinpty probe, Git Bash `CAN_CHMOD_READ` line, the ps branches of `run_one` / `run_pty` / the lib case, `strip_cr`, the cygpath branch of `adopt_is`, `native_path` uses, `USERPROFILE`; `case_run NAME SEED [FLAG]` and `rerun [FLAG]` take the .sh flag only (callers updated); the dangling-symlink case no longer sits in a `uname` case (its Git Bash branch was dead) |

Golden files: none edited (`git -C W diff -- tests/skills-legacy/golden tests/rules-fanout/golden` empty after the mutation runs). tests/lib: not edited.

Behaviour of the .sh on macOS/Linux: the same cases, check names and output. Two environment variables are no longer passed to the scripts under test there: `USERPROFILE` (a Windows variable; no `.sh` under test reads it: grep of `scripts/*.sh` finds it only in `hh.sh` and `setup-user-hooks.sh` as a fallback after `HOME`, and in `build-deploy.sh`'s embedded PowerShell) and `AITOOLS_PROFILE_PS1` for the resolver-error stub (`aitools-lib.sh` reads it only on Windows or with `AITLIB_PROFILE_VIA_PWSH=1`, `_aitlib_profile_run`). Not run: the .sh harnesses on macOS/Linux (CI does that).

## Environment differences found (old Git Bash flow vs native pwsh)

- None changed a result. The harness passes the same path forms the .sh did (skills-legacy: HOME/USERPROFILE in `C:\...` form, log dir and summary in `C:/...` form; rules-fanout: all in `C:/...` form), sets the variables the .sh unset to `$null`, and gives the build HOME in MSYS form plus USERPROFILE in Windows form, as the .sh did under Git Bash.
- No product script reads `MSYSTEM`, `SHELL`, `TMP`/`TEMP` or `OSTYPE` (grep of `scripts/*.ps1`); `TERM` is read only for the review-diff colour (`aitools-lib.ps1`, `"dumb"` check), which no check depends on.

## INCIDENT / CONFLICT / WRITE_BLOCKED

- INCIDENT: none. No product script misbehaved; every new ACL case gave the macOS/Linux golden result.
- CONFLICT: contract item 4 ("If Git Bash is absent, report those cases as SKIP with the reason") vs the suite's own rule ("A missing perl, git, node or python3 ... skips its cases locally; under CI=true it is a failure", `need_skip`) -- resolved by tier 2 (this prompt's "same cases" plus item 4, read together): a missing Git Bash prints `SKIP MDM cases (Git for Windows bash not found; build-deploy.sh runs in it)` locally and, like every other missing tool in this suite, a FAIL under `CI=true`. CI has Git Bash, so CI never takes the branch. If 38dc-13 wants a plain SKIP under CI too, change `Need-Skip` to `Skip` on that one line.
- CONFLICT: contract item 1 (the same PASS/SKIP lines as the CI run) vs the skills-legacy suite note ("decide with evidence whether a native equivalent exists (e.g. an ACL deny)") and the verification rule ("a SKIP that existed only because of Git Bash ... may become a PASS") -- resolved by tier 2, the more specific instruction: the chmod SKIPs became PASS lines with the .sh's own check names; every other line is identical to CI.
- CONFLICT: contract item 5's guard (`case "${OSTYPE:-}"`) vs 38dc-13's mid-task CONTRACT CORRECTION (`case "${BASH_VERSINFO[5]:-}"` with `*-msys*|*-cygwin*|*-mingw*`; evidence: an exported OSTYPE overrides bash's own) -- resolved by tier 2 (the delegating agent's newer instruction, no commander words either way): both .sh use the corrected block verbatim.
- WRITE_BLOCKED: none.
- Relay: `.aitools/channel/relay.md` is outside this mission's write access, so no relay entry was written; the operational learning below is for 38dc-13 to carry into it.

## Contract change requests (tests/lib/platform-lib.ps1)

1. `Get-TestLongPath` is used by `test-rules-fanout.ps1` (`Loc`, the 8.3-tolerant path compare that replaced `cygpath -m -l`) but is not in the helper's "Provides" list. Suggest: list it as part of the API (no code change).
2. `Deny-Access` / `Undo-Deny` / `Test-DenyBlocksRead` (ACL deny for the current user, the Windows twin of chmod 000/555) are duplicated in both new harnesses. Suggest: move them to platform-lib.ps1 (with the `$script:Denied` sweep as a `Clear-TestDenies` helper) so tests/rules-fanout-cursor, tests/skills-fanout and other suites with chmod SKIPs can use them; then delete the suite-local copies.
3. A `Native { cmd 2>&1 }` helper (stderr merged under `ErrorActionPreference` Continue) is duplicated too; same suggestion.

## Open questions (each with a suggested answer)

1. Should the chmod-replacement cases (12 new PASS lines) stay, given they make the Windows lines differ from the old CI run? Suggested answer: yes; they are the .sh's own checks against the unchanged .sh-written golden files, the plan lists "Windows symlink / chmod / read-only coverage" as a follow-up (plans/ci-platform-targeting.md, Status), and the probe falls back to the old SKIP line.
2. Should the dangling-symlink case run on Windows where symlinks can be created (elevated CI runner)? Suggested answer: not in this batch; it would run only in CI, unverifiable locally. Follow-up: run it behind a "symlink creation works" probe and confirm in one CI run.
3. The kept SKIP texts mention Git Bash / chmod ("dangling symlink (Git Bash)", "(root or Git Bash)" on the .sh side, "(chmod does not block reads here)"). Suggested answer: keep them while the CI-line comparison is the acceptance test; reword in the docs pass (38dc-13) if wanted.

## Operational learning (new)

- In PowerShell, a function named `R` is shadowed by the built-in alias `r` (Invoke-History): aliases win over functions. The first run died with "Cannot locate most recent history." Name helpers so they collide with no alias (`RulesDir`).
- PowerShell variable names are case-insensitive: a `foreach ($l in ...)` loop overwrote the harness's `$L = "ps"` and sent the parity rows to `<line>.summary` (18 parity FAILs with "- every row" diffs). Never reuse a script variable's name in any case.
- An ACL deny entry for the current user (`FileSystemAccessRule($me, ReadData|ListDirectory|CreateFiles..., Deny)`) is the native Windows equivalent of chmod 000/555 for these tests: reads, listings and mkdir fail with "Access to the path ... is denied", `Test-Path` still sees the item, and the owner can remove the entry again with `Set-Acl` (READ_CONTROL/WRITE_DAC are separate rights). Verified here non-elevated. On the elevated CI runner a deny entry for the user SID is expected to apply too (.NET file APIs do not enable backup privilege) -- not yet seen in CI; if it does not, `Test-DenyBlocksRead` turns the cases back into the old SKIP lines rather than failing them.
- `git init` on Windows marks `.git` hidden; the harness copies the fixture dotprofile with `Copy-Item -Recurse -Force` so the hidden `.git` is copied (whether Copy-Item skips it without `-Force` was not tested here).
- Calling a harness function with `-Force` or `-DryRun` as a value makes PowerShell bind it as a parameter name; quote it (`Rerun "-Force"`).
- Real HOME check after the runs: `~/.aitools/logs` and the real dotprofile `deploy/` were not written. The real dotprofile's `.git/FETCH_HEAD` has mtime 11:11:25 local (the first harness run's log was completed at 11:22:12); no script these suites run calls `git fetch`, and every case's config.json points at a fixture dotprofile (grep of `aitools-lib.ps1`, `aitools-profile.ps1`, `setup-user-*.ps1`, `build-deploy.sh`), so it did not come from these suites; its source is unknown.

## Scratch artifacts (W\.scratch\session-e9d6-03\)

`skills-legacy-run.log`, `skills-legacy-run2.log`, `rules-fanout-run.log`, `rules-fanout-run2.log` (runs), `compare-ci.py` (CI vs local), `parse.ps1`, `guard-check.ps1`, `probe-acl.ps1` (evidence), `mutate.ps1` + `mutate-summary.log` + `mut-*.log` (mutations), `fix-*.pl` (perl edits).
