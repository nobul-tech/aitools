# e9d6-08 report: Windows .ps1 harness for tests/deploy-harness-mdm (v1.0)

Delegate e9d6-08-port-dh-mdm, for 38dc-13-windows-ci-ps1-only, 2026-11-14.

## Summary

1. New `tests/deploy-harness-mdm/test-deploy-harness-mdm.ps1`: native-pwsh Windows harness, all 56 cases of the .sh harness's Windows CI run, same names, same order, same 3 golden files.
2. Local run (Windows 11, pwsh 7.6.10): `56 passed, 0 failed, 0 skipped (windows: ps1 scripts)`, identical PASS/FAIL/SKIP lines to CI on main (56/0/0). There are no differing lines.
3. `test-deploy-harness-mdm.sh`: the contract guard is added, every ps1/windows branch and Windows-only helper is removed, and the macOS/Linux cases and output are unchanged. `bash -n` passes. Run in Git Bash, it exits 1 with the guard message and writes nothing.
4. Mutation proof: 4 mutations, and each one fails exactly one check and makes the suite exit 1: a golden line, an expected row, the TMP/TEMP variable, and the fake git.exe. All files were restored byte-identical and the golden diff is empty.
5. No product change and no INCIDENT. I found one pre-existing vacuous check on Windows (fakegit.calls; see Observations), and I have one contract change request (make `Get-TestLongPath` part of the documented contract).

## Windows-reached code this suite tests

| Code | How it runs in the .ps1 harness |
|---|---|
| `scripts/build-deploy.sh` (cross-platform bash builder, approved cross-language exception) | Git for Windows bash from `Resolve-TestGitBash`. HOME is in MSYS form, USERPROFILE and AITOOLS_USER_REPO_PATH in C:/ form. It runs 6 times: b1, the padded `big`, b2 (dup rule), b3 (non-git dotprofile), `nomark`, `dupmark` |
| `scripts/deploy-harness.ps1` (dev path) | native pwsh child (`Invoke-TestScript`): runs eq x3, dry, skipd x2, helpd, dup |
| generated `deploy/deploy-harness.ps1` + `deploy-harness.payload` (MDM path) | native pwsh child with fakegit first on PATH: runs eq x3, dry, help, corrupt, record, crlf, nopayload, malformed, dup, and the pty run |
| generated `deploy/setup-user-config.ps1`, `aitools-profile.ps1`, `aitools-json.ps1` (MDM config writer) | called by the MDM deploy-harness.ps1 (eq: "config.json written by the MDM writer, same as dev") |
| `scripts/setup-user-config.ps1` + `aitools-profile.ps1` + `aitools-json.ps1` (dev writer) | called by the dev deploy-harness.ps1 (rows "aitools config") |
| `scripts/aitools-lib.ps1` (Deploy-ManagedFile review menu, the review diff via `ProcessStartInfo("git")`, Write-Summary) | the pty case through `tests/managed-files/pty-run.py` (pywinpty / ConPTY), python3 |
| Static checks on generated `.sh` files (markers, sha, truncation guard, cursor header) | read-only file checks; the platform-neutral cases the .sh harness ran on Windows |

## Windows-relevant behaviours ported (class c: .ps1 equivalent written)

All 56 check names are verbatim. The checks, in order:

- Build: exit 0 and not skipped; the bundle is generated; the pwsh parser on deploy-harness.ps1 (in-process `Parser.ParseFile`, where the .sh harness started a child pwsh); cursor step 4 once; cursor header ported; no adopt target in MDM; shared rules embedded; no dotprofile or .claude records; payload beside the scripts.
- Size gate (FX-12), and the forced case with a padded fixture dotprofile (setup-user-claude.sh over 1 MB, FX-35 hint).
- Payload sha256 equality (.sh, .ps1, payload with CRs removed); markers not copied; sections 1/3/5b extracted, section 2 replaced; MDM bootstrap check.
- Equivalence dev vs MDM: first run (exit codes, six directories, summary rows, golden `eq-first.rows`, config.json, shared rule deployed, no dotprofile rules or skills, manifests shared-only, no git); rerun; edit then rerun (source wins, 1 updated, same rows and trees, golden `eq-edit.rows`).
- Terminal review (MDM, pywinpty): overwrite offered, adopt and merge not offered, skip keeps LOCAL; without git it shows "diff unavailable" and the menu.
- Dry run, MDM -Help, git used only for the review diff.
- config.json: fresh HOME (no bootstrap, golden `fresh.rows`), half config, bootstrap present (writer stub called once), -SkipConfig on MDM and on dev (config.json unchanged, no "meta"), the dev writer's rows, dev -Help documents -SkipConfig.
- Damaged payload: checksum, damaged record, the stage directory under pstmp created and removed in `finally` (.ps1-only case), CRLF payload, missing payload, the truncation guard (static), malformed record.
- A dotprofile rule named like a shared rule; non-git dotprofile build identical; marker build failures (missing END in the .sh source, duplicated BEGIN in the .ps1 source) leave the dotprofile deploy/ as it was.

Cases that needed Git Bash, and why: the 6 build-deploy.sh runs. build-deploy.sh is bash code that runs in Git Bash on Windows (it is in the cross-platform.md exemption table and is the commander's named cross-platform example), so its Windows behaviour can only be tested there. Its Windows-only branch, the PS1 ParseFile validation via `cygpath -w` (build-deploy.sh "Post-build: Validate PS1 syntax"), runs in every build. If Git Bash is missing, the harness prints `SKIP all cases (Git for Windows bash not found: ...)` and exits 0, which mirrors the .sh harness's `SKIP all cases (<tool> not found)`.

## Harness-environment decisions (contract item 6)

- **TERM**: Git Bash sets `TERM=xterm-256color` for its children (probe 2026-11-14: TERM unset in native pwsh, `xterm-256color` inside `Git\bin\bash.exe`). The old harness's pwsh children therefore had it. Run-Script and the pty run set it explicitly, with a comment. No check depends on it; it only affects review-diff colour, and colour is stripped before matching.
- **Path forms**: HOME, USERPROFILE, AITOOLS_LOG_DIR, AITOOLS_SUMMARY_FILE and the script path are passed in C:/... form, as the .sh harness passed them (`cygpath -m`). PATH puts fakegit first in native form. TMP/TEMP are left as the runner's except for the `record` case, which gets `C:/.../pstmp/` with a trailing slash, exactly as before.
- **Line matching**: Git for Windows grep strips CR before matching, so the .sh harness's grep checks never saw CRs. The port strips CR in `FileLines`/`GrepQ`. Perl-based checks (payload record, manifests, sha capture) use byte-faithful lines that keep CR, as perl did. All perl-style edits (corrupt record, sha rewrite, CRLF payload, malformed record, marker edits) use Latin-1 byte round-trips, so no encoding or BOM changes are introduced.
- **same_trees exec bits**: NTFS has no executable bit, and Git Bash derived it from file content. Identical content (`TreeMap`: names and sha256, `*.bak.*` excluded like `diff -x`) therefore already covers that half. This is documented in a comment.
- **perl**: no product .ps1 the suite runs calls perl (grep of `& perl` in deploy-harness.ps1, setup-user-config.ps1, aitools-profile.ps1, aitools-json.ps1, aitools-lib.ps1: none). perl is needed only inside Git Bash for build-deploy.sh, and Git's launcher puts it on PATH (probe: `/usr/bin/perl`). The harness therefore requires only node and git natively.

## CI vs local

- CI (main, `.scratch/session-38dc-13/ci-windows-main.log`, "Run bash tests/deploy-harness-mdm/test-deploy-harness-mdm.sh"): 56 passed, 0 failed, 0 skipped.
- Local .ps1 run (`.scratch/session-e9d6-08/dh-mdm-run1.log`): 56 passed, 0 failed, 0 skipped.
- The PASS/FAIL/SKIP lines and the final line are identical, with the same order (`compare.py`: "no differences"). The log has no other lines.

## Mutation results (`.scratch/session-e9d6-08/mutate.ps1`, each restored in `finally`)

| Mutation | File | Failed check | Suite exit |
|---|---|---|---|
| (a) golden line `OK\|harness files\|N added` -> `...addedX` | golden/fresh.rows | fresh HOME parity: summary rows (numbers as N) match golden | 1 (55/1/0) |
| (b) expected row `n/a (no bootstrap)` -> `n/a (no bootstrapX)` | .ps1 | fresh HOME (MDM, no bootstrap): exit 0, OK config.json n/a row, no ERROR row | 1 (55/1/0) |
| (c) env: TMP/TEMP for the record case not set | .ps1 | ps1 exit 1 after unpacking: the stage directory was created there and removed (finally) | 1 (55/1/0) |
| (d) fake git.exe copied under another name (the real git.exe is found) | .ps1 | terminal review (MDM) without git: diff unavailable, menu still shown | 1 (55/1/0) |

Every file was restored byte-identical (checked in the script). Afterwards `git status --short tests/deploy-harness-mdm` shows only ` M ...sh` and `?? ...ps1`, and `git diff -- tests/deploy-harness-mdm/golden` is empty.

## Syntax and guard

- `bash -n tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`: exit 0. The file has no CR bytes and stays bash 3.2 compatible (the edit removed the `a+=()` array code and adds only `case` statements). `--help` now prints lines 2..45 (the `--bash-only` line is 45).
- PowerShell parser on the .ps1: no errors. The file is LF, ASCII only. `-Help` prints the header (lines 2..42).
- Guard: `bash tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` in Git Bash exits 1, prints nothing on stdout and puts the guard message on stderr ("This script is for macOS/Linux. On Windows, run tests/deploy-harness-mdm/test-deploy-harness-mdm.ps1 with pwsh."). The temp directory entry count was unchanged.
- `tests/os-guards/classify-guards.pl` on the two files: `posix` (.sh, with the BASH_VERSINFO case, not `weak`) and `win` (.ps1).
- No temp root was left behind (`deploy-harness-mdm-*` in %TEMP%: 0).

## Files changed

- `tests/deploy-harness-mdm/test-deploy-harness-mdm.ps1` (new, 758 lines)
- `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` (edit, 684 -> 578 lines: guard, header platform paragraph, `--help` range 49 -> 45; removed: the pwsh PATH check, `cfg_path` and the native/posix config forms, the Windows `run_build` branch, `git.cmd` / `git.exe` / `FAKE_GIT_EXE`, `ps_args`, the ps1 `run_script` branch, the ps1 `set_payload_sha` branch, the ps1 parse check, the Windows exec-bit condition, the winpty probe and ps1 pty branch, the .ps1 writer stub, the `native_path` calls (identity off Windows), the ps1 SKIP_FLAG branch, the ps1 stage-dir block, the USERPROFILE in `marker_build`; the truncation cases are unconditional). The cases, check names and output are the same on macOS/Linux. This was not run on macOS/Linux (CI does that).

## INCIDENT / CONFLICT / WRITE_BLOCKED

- INCIDENT: none (no product bug found).
- CONFLICT: none.
- WRITE_BLOCKED: none. One Bash call (`head` on classify-guards.pl) was refused by the standing-order-guard as a dedicated-tool violation; I used Read instead. This was a tool-choice correction, not a write denial.

## Observations

- **Vacuous fakegit.calls checks on Windows (pre-existing, already in plans/ci-platform-targeting.md follow-ups: "the vacuous fakegit.calls check on windows")**. Probe on 2026-11-14 (`probe-fakegit.ps1`): with `git`, `git.cmd` and `git.exe` (a where.exe copy) in the first PATH directory, native pwsh `& git` resolves to `git.exe` (`Get-Command git -All` lists .exe, .cmd, then the extensionless file). git.cmd never runs, so nothing is ever recorded. "first run: MDM needed no git" and "runs: MDM called git only to display the review diff" are therefore always true on Windows. A real MDM git dependency would still show up indirectly, because the fake git.exe fails and other checks would fail. The old .sh harness's Windows run had the same weakness, so the port keeps it rather than diverge from the CI lines. Suggested fix (follow-up, not this mission): a recording `git.exe` stub (for example a tiny C# console app compiled with `Add-Type -OutputType ConsoleApplication` in the harness) that appends its arguments to fakegit.calls and exits 2.

## Contract change requests

1. `Get-TestLongPath` in `tests/lib/platform-lib.ps1` is defined but not listed under "Provides". The port uses it in `SameDir` (the `-ef` equivalent for the stage-dir case: 8.3 vs long names). Suggested: list it in the header as a contract helper ("Get-TestLongPath PATH: PATH with 8.3 components expanded; PATH must exist"), so suites may rely on it.

## Open questions

- Should the .ps1 harness honour `AITOOLS_TEST_BASH` (the .sh harness's bash override) as a Git Bash override? Suggested answer: no. Resolve-TestGitBash is the contract (never the WSL launcher); an override invites the bare-`bash` mistake.

## New operational learning

- Native pwsh resolves `git` to `git.exe` before `git.cmd` in the same PATH directory (probe 2026-11-14). A `.cmd` call recorder next to a `.exe` stub records nothing.
- `Git\bin\bash.exe` started from native pwsh converts HOME the same way from `/c/...`, `C:/...` and `C:\...` (all become `/c/...`). It also sets `TERM=xterm-256color`, `MSYSTEM=UCRT64` and puts `/usr/bin/perl` first (probe 2026-11-14).
- To port `perl -pi` edits byte for byte in pwsh, use `[Text.Encoding]::Latin1.GetString([IO.File]::ReadAllBytes(...))` and `WriteAllBytes(..., Latin1.GetBytes(...))`, not `ReadAllText(path, enc)`, which still honours a BOM.
- In `.NET` regex with `(?m)`, `$` matches only before `\n`, and `.` matches `\r`. So `^(X .*)$` on a CRLF line captures the `\r`, which is the same as perl's `-pe` on that line.
- One full .ps1 run takes a few minutes locally; 4 mutation runs in one background script took about 4 runs' time with no foreground waits.
