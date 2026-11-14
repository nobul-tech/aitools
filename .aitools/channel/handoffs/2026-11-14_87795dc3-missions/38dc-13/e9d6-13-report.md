# e9d6-13 report: platform guards on the four tests/managed-files suites

Version 1.0, 2026-11-14. Author: e9d6-13-guard-managed (delegate of 38dc-13-windows-ci-ps1-only,
under M6-Polish, Session Commander 87795dc3-e). Worktree `.claude/worktrees/38dc-13`
(HEAD 1e454ca at report time; no commit touched `tests/managed-files` since b79bf7c).
Nothing committed, staged or pushed (shared worktree).

**Intent**: **Purpose**: report the guards added to the four managed-files suites, the dead
code removed, the evidence that Windows behaviour is unchanged, and the verified parity gaps
between the `.sh` and `.ps1` twins. **Scope**: `tests/managed-files/test-managed-files.{sh,ps1}`,
`test-adopt-push.{sh,ps1}`. NOT closing the parity gaps (listed only). NOT pty-run.py /
winpty-probe.py, other suites, check.yml or docs. **Audience**: 38dc-13.

## Summary

1. Both `.ps1` suites carry the Windows guard (exact rule form) after `param`/`-Help`; both
   `.sh` suites carry the two-case POSIX guard (uname + `BASH_VERSINFO[5]`) right after `set`.
2. `tests/os-guards/classify-guards.pl` classifies them `win` / `posix` (not `weak`).
3. Windows evidence (`.ps1` only): output byte-identical before and after: managed-files
   56/0/0, adopt-push 22/0/0. Removed `.ps1` checks never ran on Windows.
4. Mutation: one flipped expectation per `.ps1` makes the suite exit 1 (see below); files
   restored byte-identical (SHA256).
5. Parity gaps verified: 16 for test-managed-files, 6 for test-adopt-push (two new ones
   created by removing `.ps1` checks that were gated `-not $IsWindows`, i.e. never run in CI).

## 1. tests/managed-files/test-managed-files.ps1

Guard (after `param([switch]$Help)` and the `-Help` line):

```
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/managed-files/test-managed-files.sh with bash.")
    exit 1
}
```

Header: "Platform: Windows only (OS guard below; commander, 2026-11-14: "sh scripts and tests
should only run on linux/mac and ps1 on windows"). On macOS/Linux,
tests/managed-files/test-managed-files.sh tests aitools-lib.sh." The header grew by one line,
so `-Help` reads `-TotalCount 13` (was 12); verified: `-Help` prints 12 lines ending at `#`,
as before.

Dead code removed (each reached only when `$IsWindows` is false, which the guard now refuses):

| Item | Why it could never run on Windows CI |
|---|---|
| `if ($havePty -and $IsWindows)` -> `if ($havePty)` | `-and $IsWindows` always true on Windows; the pywinpty probe now runs unconditionally after python3 is found (same as before on Windows) |
| `Stub-Claude`: the bash stub branch (`#!/usr/bin/env bash` `bin/claude` + `& chmod +x`) | behind `if ($IsWindows) { ...; return }`; the Windows `.cmd` branch is now the body |
| `Stub-Git-Fail`: the bash `bin/git` + `& chmod +x` line | same pattern; `git.exe` (where.exe copy) + `git.cmd` kept |
| `if (-not $IsWindows) { Setup-Case "readonly-dir" ... }` with checks "write failure: failed, nothing left" and "write failure: the run continues" | gated `-not $IsWindows`; absent from the before-log (56 PASS lines, neither name present) |
| `finally`: `if (-not $IsWindows) { & chmod -R u+w $tmpRoot }` | gated `-not $IsWindows` |
| Header "pywinpty/ConPTY on Windows" -> "python3 with pywinpty/ConPTY" | wording only |

Kept although it calls `chmod`: the merge-restore case (`& chmod 444` / `& chmod 644`) runs on
Windows: pwsh resolves `chmod` to `C:\Program Files\Git\usr\bin\chmod.exe` (checked with
`Get-Command chmod`) and "adopt-target write failure: LOCAL restored, failed" PASSes before
and after. Not dead code (see open question Q2).

Before/after (`pwsh -NoProfile -File tests/managed-files/test-managed-files.ps1`, logs
`.scratch/session-e9d6-13/test-managed-files-{before,after}.log`): 56 passed, 0 failed,
0 skipped both times; `diff` of the two logs is empty. No PASS line removed (the two removed
checks never printed on Windows).

## 2. tests/managed-files/test-adopt-push.ps1

Guard: same form, message "... run tests/managed-files/test-adopt-push.sh with bash.".
Header as above (test-adopt-push.sh); `-Help` `-TotalCount 17` (was 16); verified: 16 lines
ending at `#`.

| Item | Why it could never run on Windows CI |
|---|---|
| `if ($havePty -and $IsWindows)` -> `if ($havePty)` | as above |
| `Run-Lib`: `$resolved = if ($IsWindows) { "" } else { "`$script:AitLibUserRepoPath = '...'" }` and the `$resolved` line of the snippet here-string; comment rewritten ("The snippet starts unresolved: Invoke-DotprofileCommitPush falls back to the resolver (aitools-profile.ps1), which finds AITOOLS_USER_REPO_PATH=DP.") | on Windows `$resolved` was `""`, an empty snippet line; removing it changes nothing the lib sees |
| `if (-not $IsWindows) { Setup-Case "direct-commit-fail" ... }` with check "commit failure: commit-failed, WARN + ACTION, nothing pushed" | gated `-not $IsWindows`; absent from the before-log |

Before/after: 22 passed, 0 failed, 0 skipped both times; `diff` of the logs is empty.

## 3. tests/managed-files/test-managed-files.sh

Guard: the rule's two-case form, first after `set -uo pipefail`, before `--help` and
`mktemp`, message "This script is for macOS/Linux. On Windows, run
tests/managed-files/test-managed-files.ps1 with pwsh.". Header Platform: "macOS, Linux (OS
guard below; commander, 2026-11-14: ...). On Windows, tests/managed-files/test-managed-files.ps1
tests the PowerShell side (aitools-lib.ps1)." Same line count as before, so `--help` keeps
`$. >= 2 && $. <= 14` (still ends at the Spec line).

| Item removed | Why dead after the guard |
|---|---|
| `HAVE_READONLY=true` and the `case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*)` block (HAVE_READONLY=false; `python3 -c 'import winpty'` probe) | only the MINGW/MSYS/CYGWIN branch did anything |
| `if $HAVE_READONLY; then ... else printf 'SKIP read-only cases ...'; fi` -> the readonly-dir and backup-fail cases unwrapped | HAVE_READONLY was always true off Git Bash; the SKIP never printed on macOS/Linux |
| `shown()` (cygpath -w) and its comment; `SD="$(shown ...)"; SR=...` -> `SD="$C/dest/a.md"; SR="$C/repo/a.md"` | cygpath exists only under Git Bash/Cygwin; elsewhere `shown` returned its argument unchanged |
| `IS_WINDOWS` and its `case` | always false |
| display-huge: `if $IS_WINDOWS; then` ConPTY-throughput SKIP `else ... fi` -> the case unwrapped | IS_WINDOWS false |
| claude-md: `if $IS_WINDOWS; then` SKIP `elif $HAVE_PTY && command -v node ...` -> `if $HAVE_PTY && command -v node ...` | IS_WINDOWS false |
| Comment "Runs on every platform: no pseudo-terminal needed." -> "No pseudo-terminal needed." | wording |

macOS/Linux behaviour: same cases, same check names, same order, same output (every removed
branch was dead there). Kept unchanged on purpose, to keep the output identical: the SKIP text
"(no pseudo-terminal: python3 missing, or pywinpty not installed on Windows)" (Q1). Bash 3.2:
the only new construct is `${BASH_VERSINFO[5]:-}`. File mode stays 100755.

## 4. tests/managed-files/test-adopt-push.sh

Guard: same two-case form, naming tests/managed-files/test-adopt-push.ps1. Header Platform
rewritten (two lines longer), `--help` range `$. <= 18` -> `$. <= 20` (verified: line 20 is
the `#` before Usage, as line 18 was).

| Item removed | Why dead after the guard |
|---|---|
| `case "$(uname -s)" in MINGW*...` pywinpty probe | MINGW-only branch |
| `DPD` (cygpath -w of `$DP`) and its comment; the five `$DPD` uses (ACTION-row checks) -> `$DP` | cygpath absent on macOS/Linux, where DPD was `$DP` |

## 5. Verification (Windows 11, pwsh 7, Git for Windows bash; tested: Windows)

| Check | Result |
|---|---|
| PowerShell parser (`Parser::ParseFile`) on both `.ps1` | PARSE-OK both (`.scratch/session-e9d6-13/parse-check.ps1`) |
| `-Help` on both `.ps1` | rc 0; 12 and 16 lines, last line `#` (unchanged) |
| `bash -n` on both `.sh` | clean (no output, exit 0) |
| `classify-guards.pl` on the four files | `posix` test-managed-files.sh, `posix` test-adopt-push.sh, `win` test-managed-files.ps1, `win` test-adopt-push.ps1 |
| Plain refusal run `bash tests/managed-files/<suite>.sh` (no spoofing; `uname -s` MINGW64_NT-10.0-26300, `BASH_VERSINFO[5]` x86_64-pc-cygwin) | both: exit 1, stdout empty, stderr exactly the guard message, no new entry in `/tmp` (`.scratch/session-e9d6-13/refusal.sh`) |
| `.ps1` before/after | identical logs (above) |
| Mutation (`.scratch/session-e9d6-13/mutation.ps1`) | test-managed-files.ps1 with "created: missing LOCAL is written" expecting `created-MUTANT`: exit 1, 55 passed 1 failed, that check FAILs; test-adopt-push.ps1 with "direct: committed-pushed" expecting `committed-pushed-MUTANT`: exit 1, 21 passed 1 failed; both files restored in `finally`, SHA256 identical to before |
| `git status --short tests/managed-files` | only the four files (` M`) |

Not run: the `.sh` suites past their guard (by rule: their evidence is the macOS and Linux CI
jobs); no aitools, setup-user-*, deploy-harness, build-deploy.sh or check script was run.

## 6. Parity gaps (verified against the files; the `.ps1` twin lacks each)

Line numbers are of the edited `.sh` files.

test-managed-files:

| # | `.sh` case / check | `.sh` lines | `.ps1` has it? |
|---|---|---|---|
| M1 | backup-fail: "failed backup: step failed, LOCAL unchanged" | 146-150 | No |
| M2 | readonly-dir: "write failure: result failed, nothing left", "... log_error with the reason", "... the run continues" | 138-144 | No (the `.ps1` case was gated `-not $IsWindows`, never ran in CI, removed now; not in e9d6-01's list) |
| M3 | force: "--force on a terminal: overwrite, no menu" | 160-163 | No |
| M4 | json-skip: "json skip: skipped, both unchanged" | 443-446 | No (json-fields skips one field, but its result is accept & adopt) |
| M5 | json-restore: "json write failure: LOCAL restored, failed" | 448-452 | No |
| M6 | array-detail matrix (14 plan-mode checks: scalars, duplicates, mixed types, empty arrays, nested, identity keys, key order, reorder, 20-line cap, escaping, scalar/non-array/source-only columns) | 337-375 | No; the `.ps1` has 3 `Write-JsonFieldDetail` render checks (ps1:191-198) and the json-array-display pty checks |
| M7 | "json review node script: found in both libs, identical" (static cross-lib check) | 320-323 | No (static text check, runs only in the `.sh`, reads aitools-lib.ps1's text; per e9d6-01 Q2 that executes nothing) |
| M8 | claude-md: setup-user-claude.sh CLAUDE.md adopt filter round trip (4 checks) | 458-486 | No: the `.ps1` has only the generic `-AdoptFilter` scriptblock case ("adopt filter: the repo gets the filtered LOCAL", ps1:227); `setup-user-claude.ps1`'s `$claudeMdAdoptFilter` round trip has no Windows test (grep for "adopt" in tests/claude-mdm/test-claude-mdm.ps1, e9d6-02's in-progress file: no match) |
| M9 | nostate: "deploy state: old files left on disk, noted once (detail)" | 131-136 | No |
| M10 | "verified: no backup made" | 121 | No |
| M11 | "adopt: repo backed up, uncommitted change logged" | 184 | No |
| M12 | "failed AI merge: reason logged" | 212 | No |
| M13 | "json: LOCAL-only field alone -> verified (kept, no prompt)" | 298 | No |
| M14 | "json LOCAL-only: no [o]verwrite offered" (`choice [a/s/x]`) | 433 | No |
| M15 | eof: "EOF at the menu: overwrite, warning logged" (EOF through the pty, menu outcome asserted) | 165-168 | Partly: the `.ps1` tests `Read-ConsoleChoice` with an empty `Console.In` (ps1:200-206), not the menu's overwrite outcome |
| M16 | merge-reject asserts the final result `skipped` | 201-205 | Partly: the `.ps1` does not assert the result (documented pty limitation, ps1 comment above the check) |

Checked and NOT a gap (e9d6-01 listed it): "json per-field: precedence -> accept & adopt": the
`.ps1` "json per-field: overwrite/adopt/skip + LOCAL-only adopt" asserts `(Result) -eq
"accept & adopt"` (ps1:260).

test-adopt-push:

| # | `.sh` case / check | `.sh` lines | `.ps1` has it? |
|---|---|---|---|
| A1 | direct-new-file: "new (untracked) file: added, committed, pushed" | 150-153 | No |
| A2 | direct-preresolved: "caller-resolved dotprofile wins (AITLIB_USER_REPO_PATH), no resolver call" | 160-163 | No (the `.ps1` has only the `""` variant, "caller resolved shared-only (empty)") |
| A3 | direct-action-once: "two push failures in one run: one ACTION row" | 189-193 | No |
| A4 | adopt-dotprofile: "accept & adopt: the backup file is not committed" | 199-207 | No |
| A5 | merge-dotprofile: "merge & adopt into the dotprofile: committed and pushed" | 209-214 | No |
| A6 | direct-commit-fail: "commit failure: commit-failed, WARN + ACTION, nothing pushed" | 183-187 | No (the `.ps1` case was gated `-not $IsWindows`, never ran in CI, removed now; not in e9d6-01's list) |

Weaker `.ps1` assertions (same case exists): direct-pushed (the `.sh` also asserts notes.md
still shows in `git diff` and that the remote lacks staged.md), direct-unchanged (`.sh` also
asserts no ACTION row), adopt-dotprofile (`.sh` also asserts the commit message).

## Lines for 38dc-13

- WRITE_BLOCKED: none.
- CONFLICT: none.
- INCIDENT: `test-managed-files.ps1` (readonly-dir, 2 checks) and `test-adopt-push.ps1`
  (direct-commit-fail, 1 check) held checks gated `if (-not $IsWindows)`, while CI runs the
  `.ps1` suites only in the windows job (`plans/ci-platform-targeting.md`): aitools-lib.ps1's
  write-failure and commit-failure handling had no test in any job while the files read as if
  it had. Removed now as dead code; listed as gaps M2 and A6. Coverage gap disguised as a
  test, low/medium.
- INCIDENT (carried, not new): e9d6-01's gap list for these suites was incomplete (missed
  M2, M9-M14, A6); the table above supersedes it.

## Open questions (each with a suggested answer)

- **Q1. The pty SKIP text in both `.sh` suites still says "or pywinpty not installed on
  Windows".** Suggested: change it to "(no pseudo-terminal: python3 missing)" in the follow-up
  that closes the gaps; it was kept now because the brief requires identical macOS/Linux output.
- **Q2. merge-restore in test-managed-files.ps1 depends on Git's `usr\bin\chmod.exe` on the
  pwsh PATH.** Suggested: a follow-up replaces `& chmod 444/644` with
  `(Get-Item ...).IsReadOnly = $true/$false`, so the suite needs no Git Bash tool.
- **Q3. Close M1-M16 and A1-A6?** Suggested: file them as one follow-up per suite (38dc-13
  reserved ids #180, #182); M2/M5/A6 (failure handling) first.
