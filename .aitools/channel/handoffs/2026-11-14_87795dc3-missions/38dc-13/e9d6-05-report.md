# e9d6-05-port-skills-fanout: report (v1.0, 2026-11-14)

**Intent**: **Purpose**: Report the port of tests/skills-fanout to a native
PowerShell Windows harness and the macOS/Linux-only .sh harness, with the
evidence 38dc-13 needs to verify, commit and ship it. **Scope**: what the suite
tests on Windows, the CI comparison, mutations, syntax and guard results, files
changed, findings. NOT the CI workflow, docs or golden files (38dc-13 / never
edited). **Audience**: 38dc-13 (delegating agent).

## Summary

1. New `tests/skills-fanout/test-skills-fanout.ps1` (Windows, native pwsh): 106 passed, 0 failed, 7 skipped. The 106 PASS lines are the same, in the same order, as the .sh harness's Windows CI run on main, and the count line is the same.
2. `tests/skills-fanout/test-skills-fanout.sh`: has the OS guard (uname + `BASH_VERSINFO[5]`, per your contract correction). Every ps/Windows branch and helper is removed (LANG_RUN, win_path, tmp_forms' cygpath part, native_path calls, lang_flag, strip_cr, the .cmd stubs, the pwsh and pywinpty checks, CAN_SYMLINK). macOS/Linux cases and check names are unchanged.
3. 5 mutations each turned a PASS into a FAIL and made the suite exit 1. Both mutated files were restored byte for byte, and `git diff -- tests/skills-fanout/golden` is empty.
4. The 7 SKIPs stay SKIPs on Windows (symlinks, chmod, case-only duplicates). 4 SKIP reason texts changed from "Git Bash" to "on Windows".
5. No INCIDENT and no contract change requests. One CONFLICT (the guard correction) and one WRITE_BLOCKED (my own mistaken write, denied correctly; details below).

## What Windows-reached code the suite tests

Every product script runs as a child pwsh (`-NoProfile -NonInteractive -File`, `-NoProfile -File` on the pty) through `Invoke-TestScript`. Each child gets HOME and USERPROFILE set to a temp case home, AITOOLS_LOG_DIR, AITOOLS_SUMMARY_FILE, GIT_CONFIG_GLOBAL and GIT_CONFIG_NOSYSTEM=1, with the AITOOLS_FORCE / DRY_RUN / USER_REPO_PATH / PROFILE_* variables removed and stdin at EOF:

- `scripts/setup-user-claude.ps1` (a copy, in a temp aitools git checkout and in a payload copy without .git): its skills fan-out step, `Invoke-HarnessSkillsFanout` in `scripts/aitools-lib.ps1`, plus the resolver in `scripts/aitools-profile.ps1` / `aitools-json.ps1` and `Deploy-ManagedFile` (adopt into the fixture dotprofile on a pty, abort exit 2)
- `scripts/setup-user-cursor.ps1` (a copy): step 5, the cursor skills fan-out, with stub `rg.cmd` / `agent.cmd` on PATH
- `scripts/deploy-harness.ps1` (this checkout, `-SkipConfig -Force`, into a temp HOME): the real-harness case
- Pty cases: `tests/managed-files/pty-run.py` with pywinpty (python3 found on PATH, as before)

Class (c): .ps1 equivalent written. No case needs Git Bash. The suite runs no cross-platform bash code on Windows, so `Resolve-TestGitBash` is not used.

## How the .ps1 harness is built (where it had to emulate the Git Bash run)

- **Fixtures** are written byte for byte as the .sh `printf` wrote them: UTF-8 without BOM, LF, and the binary and UTF-8 edge files as raw bytes.
- **Executable bit (" x" in the goldens):** setup-user-*.ps1 sets no mode on Windows (aitools-lib.ps1: "Windows has no executable bit"). Under Git Bash, perl's `-x` and `test -x` followed Cygwin's noacl rule instead. Probe 2026-11-14 (`.scratch/session-e9d6-05/probe-xbit.sh`, Git for Windows, mount `noacl`) found:
  - x: run.sh starting with `#!/bin/sh` (even after chmod 644), t.exe, mz.txt, colon.txt
  - not x: plain.sh, t.bat, t.cmd, t.com
  
  `IsExecLike` reproduces that rule (.exe name, or content starting with `#!`, `MZ` or `:`). So "fanout: executable bit copied", "executable bit restored", "cursor ... x bit kept" and the goldens' ` x` marks give the same result as the old run. The .sh's `chmod 644` before "executable bit restored" has no Windows equivalent and did not change `-x` under Git Bash either; this is commented in the harness. Mutation e proves `IsExecLike` matters.
- **`[x]/a*b?.md`:** Git Bash stored `*` and `?` as U+F02A / U+F03F (probe 2026-11-14, `probe-names.sh`: `0061 F02A 0062 F03F 002E 006D 0064`). The harness creates the same name (`MsysName`), and TreeSig maps U+F001-F07F back to ASCII, as Git Bash's perl showed it. The golden `[x]/a*b?.md` line matches.
- **Paths:** HOME and USERPROFILE use backslash form (needed for the lib's `~/` display; see the old win_path comment, CI run 41265193554). config.json `userRepoPath`, the log dir, the summary file and GIT_CONFIG_GLOBAL use the mixed `C:/...` form the .sh passed (`native_path`). Log text is normalized as `lognorm` did it: CR removed, backslash to slash, and the temp root replaced by `<TMP>` case-insensitively in its mixed and MSYS forms.
- **grep semantics:**
  - `grep -qx` on files: line match with a trailing CR ignored (Git for Windows grep stripped CR).
  - `grep -q` on output: ANSI and CR stripped, then a literal match. Patterns whose BRE parentheses are literal are matched as literal text, not .NET regex. Regex is used only for the `.*` patterns.
  - Ordinal sorts stand in for LC_ALL=C.
- **Not reproduced on purpose:**
  - `strip_cr` on the deploy-harness skills manifest: `deploy-harness.ps1` writes it with LF (`WriteAllText($tmp, $text, UTF8Encoding($false))`, header plus `` `n `` lines), so the old step was a no-op. The harness parses with `\r?` instead of modifying product output.
  - The extensionless bash `rg` / `agent` stubs: native pwsh runs the `.cmd` twins only.
- **Environment the old run leaked from Git Bash** (MSYS PATH with usr/bin, TERM, MSYSTEM, SHELL) is not set: every check matched without it. TERM only switches diff colour in the review menu (aitools-lib.ps1 `return (-not $env:NO_COLOR -and $env:TERM -ne "dumb")`), and ANSI is stripped before matching.

## CI count vs local, and every differing line

Source: `python .scratch/session-38dc-13/ci-section.py .scratch/session-38dc-13/ci-windows-main.log tests/skills-fanout/test-skills-fanout.sh`, saved as `.scratch/session-e9d6-05/skills-fanout-ci.txt`. Comparison script: `.scratch/session-e9d6-05/compare.py`, result in `compare-result.txt`.

| | CI (.sh, Git Bash, main) | local (.ps1, native pwsh) |
|---|---|---|
| check lines | 113 | 113 |
| PASS | 106 (identical list, same order) | 106 |
| FAIL | 0 | 0 |
| SKIP | 7 | 7 |
| count line | `106 passed, 0 failed, 7 skipped (windows: ps1 scripts)` | identical |

Differing lines (SKIP reasons only):

- `SKIP fanout: firecrawl symlink preserved (no symlinks under Git Bash)` -> `(no symlinks on Windows)`
- `SKIP retired removal failure and unlisted DEST (root or Git Bash)` -> `(no chmod on Windows)`
- `SKIP unreadable harness dir and manifest (root or Git Bash)` -> `(no chmod on Windows)`
- `SKIP cursor: firecrawl symlink preserved (no symlinks under Git Bash)` -> `(no symlinks on Windows)`

Reason for all 4: the old text named Git Bash, which no longer runs these cases. Unchanged: `SKIP kept symlink (no symlinks)`, `SKIP case-only duplicate (case-insensitive file system)`, `SKIP dangling symlink (no symlinks)`.

Why the SKIPs stay SKIPs:

- **Symlink cases** (fanout and cursor firecrawl, kept, dangling) need symlinks. These are admin or Developer Mode only on Windows, and the product's reparse-point handling on Windows has never been tested against these goldens. I did not enable untested cases.
- **chmod cases** (rmfail, unlisted, unreadable, manifest-unreadable) have no chmod on NTFS. The rmfail golden also records a POSIX mode (`backup gone/sub mode %o`) that Windows cannot produce.
- **case-only duplicate** runs only if the temp dir is case-sensitive. The probe is kept and the case is ported behind it.

## Mutations (`.scratch/session-e9d6-05/mutate.ps1`, results in `mutation-results.txt`)

Each mutation replaced one exact text in a file of the suite directory, ran the suite with native pwsh, and restored the original bytes in a `finally`.

| # | Mutation | Check that failed | Exit |
|---|---|---|---|
| a | golden/fanout.txt: `OK\|claude skills\|6 added` -> `7 added` | `golden ps: fanout: exit code, tree, summary rows` (105/1/7) | 1 |
| b | harness expected value `'OK\|claude skills\|6 added'` -> `5 added` | `fanout: exit 0, row 6 added` (105/1/7) | 1 |
| c | fixture: retired copy `dskill gone SKILL.md 'gone'` -> `'gone, mutated'` (prune logic) | 9 retired checks, including `retired: copies removed from ~/.claude/skills` and goldens retired / retired-dry (97/9/7) | 1 |
| d | env: AITOOLS_SUMMARY_FILE points elsewhere | 59 row and golden checks (47/59/7) | 1 |
| e | IsExecLike ignores `#!` | `fanout: executable bit copied`, `cursor: ... x bit kept`, 7 fanout/cursor goldens (96/10/7) | 1 |

After all 5: `restored byte-identical: True` for test-skills-fanout.ps1 and golden/fanout.txt. `git -C W status --short tests/skills-fanout` shows ` M test-skills-fanout.sh` and `?? test-skills-fanout.ps1` only. `git -C W diff -- tests/skills-fanout/golden` is empty.

After the mutations, one edit was made: `-Help` now prints from line 1, the name line (it had dropped it, copying the exemplar's `Select-Object -Skip 1`, which suits a .sh shebang but not a .ps1). A final full run follows it (below).

## Syntax and guard

- `bash -n tests/skills-fanout/test-skills-fanout.sh`: clean. Bash 3.2: no new constructs; the guard uses `${BASH_VERSINFO[5]:-}`, valid in 3.2.
- PowerShell parser (`.scratch/session-e9d6-05/parse.ps1`, `Parser::ParseFile`): `OK` for test-skills-fanout.ps1.
- Guard: `bash tests/skills-fanout/test-skills-fanout.sh` in Git Bash exits 1 with `This script is for macOS/Linux. On Windows, run tests/skills-fanout/test-skills-fanout.ps1 with pwsh.` It writes nothing, because the guard sits before `mktemp`. Locally `BASH_VERSINFO[5]` = `x86_64-pc-cygwin`.
- `.ps1` guard: the contract form, first statement after `param` and the -Help line. Both files have LF line endings (0 CR lines). The .sh keeps mode 100755.
- `-Help`: exit 0, prints the header.

## Final run

The final file state (after the -Help fix) was run with `pwsh -NoProfile -File tests/skills-fanout/test-skills-fanout.ps1` from native pwsh (the PowerShell tool), output in `.scratch/session-e9d6-05/skills-fanout-run2.log`. Result: exit 0, `106 passed, 0 failed, 7 skipped (windows: ps1 scripts)`. compare.py gives the same result as the first run: the PASS lists are identical, and only the 4 SKIP reason lines above differ.

## Files changed

- `tests/skills-fanout/test-skills-fanout.ps1` (new, LF)
- `tests/skills-fanout/test-skills-fanout.sh` (edited)

Scratch only: `.scratch/session-e9d6-05/` (probes, logs, compare, mutate, edit scripts).

## .sh changes, besides the guard (macOS/Linux behaviour)

- **Kept the same:** cases, check names, golden calls and the count line. The final printf prints a literal `sh` where it used `$LANG_RUN`; on macOS/Linux that variable was always `sh`.
- **Inlined:** the symlink branches (`CAN_SYMLINK` was always true there).
- **Removed:** `--dry-run -DryRun`, `--force -Force` and `--skip-config -SkipConfig` pairs reduced to the .sh flag; `lang_flag`, `strip_cr`, `win_path`, the cygpath part of `tmp_forms` (`TMP_FORMS="$TMP_ROOT"`); native_path calls (identity off Windows); the `HN` form in golden_record (equal to `HP` off Windows).
- **Changed output, root only:** the 2 chmod SKIP texts went from `(root or Git Bash)` to `(root)`. They print only when running as root (`id -u` = 0), where CAN_CHMOD_READ is false.
- **Kept on purpose:** copying `*.ps1` into the temp aitools checkout and payload (fixture shape; harmless), and the `for lang in $L` single-iteration loops.

## Lines for you

- CONFLICT: contract item 5's guard text (`${OSTYPE:-}`) vs 38dc-13's mid-task correction (`${BASH_VERSINFO[5]:-}`, OSTYPE can be spoofed from the environment) -- resolved by tier 2, the delegation prompt as corrected by the delegating agent; no commander words on this point. Applied the corrected block verbatim.
- WRITE_BLOCKED: Write `C:\Users\jdpal\repos\aitools\.aitools\channel\handoffs\placeholder-never-written.txt` -- "Permission for this action was denied by the Claude Code auto mode classifier. Reason: [Destructive or Unwanted Actions]." This was a mistaken call on my part: a stray placeholder file in the main checkout, outside my access list. The denial was correct, and I did not retry it or route around it. Nothing was written.
- INCIDENT: none. No product deviation found; every difference was in the harness.

## Contract change requests

None required. Optional, if other ported suites need the same thing: move `IsExecLike` (the Cygwin noacl x-bit rule) and `MsysName` / its reverse into `tests/lib/platform-lib.ps1`, so any .ps1 harness checking a golden with ` x` marks or `*?` names uses one rule.

## Open questions (each with a suggested answer)

1. Should the goldens' ` x` marks be tested on Windows at all? On Windows the product does nothing with the executable bit, so the ps1 run checks only that the harness reproduces Git Bash's heuristic on unchanged bytes. Suggested answer: keep it as now (it pins the same golden files without a `.windows` variant). Record in plans/ci-platform-targeting.md "Follow-ups" that x-bit coverage on Windows is by content heuristic, not by product behaviour.
2. Should the 4 symlink cases run on the windows CI runner (elevated, so symlinks work)? Suggested answer: not in this port. It would be new coverage of the product's reparse-point handling, untested locally. Make it a follow-up mission that first runs them on an elevated runner and checks the goldens.
3. The exemplar `tests/b8-consumers/test-b8-consumers.ps1` -Help skips line 1 (the name line). Suggested answer: drop `Select-Object -Skip 1` there too, for consistency (one-line fix in 38dc-13's own file).

## New operational learning

- Git Bash on NTFS (mount `noacl`) derives `-x` from the content or name: `#!`, `MZ` or `:` at the start, or a `.exe` name. `.bat`, `.cmd` and `.com` are not x, and `chmod 644` does not clear it. A Windows harness reproducing a Git Bash golden " x" must use that rule, not the product (probe 2026-11-14).
- Git Bash stores `*` and `?` in file names as U+F02A / U+F03F on NTFS (U+F000 + char for `* ? : < > | "`).
- Run the .ps1 suites from the PowerShell tool (native pwsh), not via `pwsh` from the Bash tool. The latter passes Git Bash's environment to the children, the very difference the port removes.
- While a mutation script that restores files from a snapshot is running, do not edit the files it mutates: its `finally` writes the snapshot back over your edit.
