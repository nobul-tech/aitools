# e9d6-16-guard-log-menus: report

Version 1.0, 2026-11-14. Author: e9d6-16 (delegate of 38dc-13-windows-ci-ps1-only, under
M6-Polish, Session Commander 87795dc3-e). Worktree W = `C:\Users\jdpal\repos\aitools\.claude\worktrees\38dc-13`
(HEAD 73151d1). Tested on Windows 11 with pwsh 7. Nothing was committed, staged or pushed
(38dc-13 ships it).

**Intent**: **Purpose**: report the Windows guard added to the two `.ps1` suites, the dead
code removed, and the evidence that their Windows behaviour is unchanged. **Scope**:
`tests/logging/test-logging.ps1`, `tests/menus/test-menu-choice.ps1`. NOT their `.sh` twins
(they wait on the open RFI). **Audience**: 38dc-13.

## Summary

1. Both `.ps1` suites now have the Windows test-suite guard, in the exact form from cross-platform.md "Test suites". It is the first statement after `param` and the `-Help` line. `classify-guards.pl` classifies both files as `win`.
2. Dead code removed: 4 `if ($IsWindows)` wrappers, 13 SKIP lines that only printed off Windows, and the `Skip` helper in test-logging.ps1. In test-menu-choice.ps1: 2 `-and $IsWindows` conditions, the bash `claude` stub branch (including `chmod`), and the `$IsWindows` wrapper around the PS 5.1 probe. No check that runs on Windows was removed or renamed.
3. Before, after and CI (875e957) results are the same: test-logging 45/0/0, test-menu-choice 97/0/0 (pass/fail/skip). The PASS lines are identical and in the same order. The full local logs are byte-identical before and after.
4. Mutation: one flipped expectation per suite makes the suite exit 1 with exactly that check FAILing. Both files were restored byte-identical (SHA-256). The PowerShell parser reports 0 errors in each file, and `-Help` still ends at the Usage line.
5. `git status --short tests/logging tests/menus` shows only my two files (` M`). No `.sh` suite was run, and nothing was spoofed.

## 1. tests/logging/test-logging.ps1

**Guard** (after the `-Help` block):

```
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/logging/test-logging.sh with bash.")
    exit 1
}
```

**Header**: the Platform line changed:

- Old: "Platform: Windows, macOS, Linux (pwsh 7). Entry-point run cases need Windows (aitools.ps1 has a Windows OS guard) and are reported as SKIP elsewhere."
- New: "Platform: Windows only (pwsh 7; OS guard below; commander, 2026-11-14: "sh scripts and tests should only run on linux/mac and ps1 on windows"). On macOS/Linux, tests/logging/test-logging.sh tests the bash side (aitools-lib.sh, check-lib.sh, scripts/aitools)."

The bash-side scope comes from test-logging.sh lines 2-3. The header is now 2 lines longer, so `-Help` changed from `-Skip 1 -First 11` to `-Skip 1 -First 13`. Verified: it prints 13 lines, ending at the `# Usage:` line, which is the same end point as before.

**Dead code removed.** Each item ran only when `$IsWindows` was false. The `.ps1` suites run only in the windows CI job, where `$IsWindows` is always true.

| Item | Why it could never run in CI |
|---|---|
| `function Skip(...)` | Its only callers were the four `else` branches below |
| locked deploy.log: `if ($IsWindows) { Check ... } else { # .NET maps FileShare.None ...; Skip "lib: locked deploy.log -- nothing written to it (the lock held)" }` became the bare `Check` | The `else` branch (1 SKIP) printed only off Windows |
| check-lib locked: `if ($IsWindows) { ... } else { foreach ... Skip "check-lib: checks.log/.jsonl locked -- $n" }`. The body was unwrapped and dedented, and the comment "; Windows only" was dropped | The `else` branch (4 SKIPs) printed only off Windows |
| profile locked: `if ($IsWindows) { ... } else { foreach ... Skip "profile: locked deploy.log -- $n" }`. The body was unwrapped and dedented | The `else` branch (3 SKIPs) printed only off Windows |
| entry: `if ($IsWindows) { New-FakeRepo; Invoke-Entry; 5 checks } else { foreach ... Skip $n "aitools.ps1 runs on Windows only" }`. The body was unwrapped and dedented | The `else` branch (5 SKIPs) printed only off Windows |

**Removed checks**: none. Every `Check` that ran on Windows is kept, with the same name and in the same order. Only the 13 off-Windows SKIP lines are gone.

`git diff -w` shows only the header, the `-Help` count, the guard, the removed `Skip` function, the four `if`/`else` shells with their SKIP loops, and one comment line.

Kept: `$script:skip` and the `---- N passed, N failed, N skipped` line (open question 2). Also kept is the comment "Windows only (OS guard)" above the profile case. It refers to aitools-profile.ps1's own guard and is still true.

**Before / after / CI**: rc 0/0. PASS 45/45/45; the lines are identical and in the same order (`compare.ps1`: before==after True, after==ci True). FAIL 0. SKIP 0. The full log is byte-identical before and after.

**Mutation**: `($r.Out -match 'COUNTS=2/1')` changed to `'COUNTS=2/9'` gives rc=1 and `---- 44 passed, 1 failed`, with FAIL `lib: LogError/LogWarn increment the counters`. The file was restored byte-identical (SHA-256).

## 2. tests/menus/test-menu-choice.ps1

**Guard** (after `if ($Help) {...}`): the same form, with the message "This script is for Windows. On macOS/Linux, run tests/menus/test-menu-choice.sh with bash."

**Header**: the Platform line changed:

- Old: "Platform: Windows (pwsh 7; aitools-lib.ps1 is a Windows library, so CI runs this suite on the windows job only, plans/ci-platform-targeting.md)."
- New: "Platform: Windows only (pwsh 7; OS guard below; commander, 2026-11-14: "sh scripts and tests should only run on linux/mac and ps1 on windows"; aitools-lib.ps1 is a Windows library, so CI runs this suite on the windows job only, plans/ci-platform-targeting.md)."

The header still says "Mirror of tests/menus/test-menu-choice.sh." It is 2 lines longer, so `-Help` changed from `-TotalCount 46` to `-TotalCount 48`. Verified: it prints 47 lines, ending at the `# Usage:` line.

**Dead code removed:**

| Item | Why it could never run in CI |
|---|---|
| `if ($havePty -and $IsWindows)` became `if ($havePty)` (the pywinpty probe) | `-and $IsWindows` was always true on Windows. The probe runs exactly as before |
| `Stub-Claude`: the `if ($IsWindows) { ...; return }` wrapper was removed and the `.cmd` body kept (dedented). The bash stub branch was deleted: `$path = ... "bin/claude"`, the bash `$rec`, the `#!/usr/bin/env bash` write, and `& chmod +x $path` | That code was reached only when `$IsWindows` was false. The `.cmd` stub with `%SystemRoot%\System32\find.exe` (PR #155) is unchanged |
| PS 5.1 probe: `$ps51 = $null; if ($IsWindows) { $ps51 = Get-Command powershell.exe ... }` became `$ps51 = Get-Command powershell.exe ...` (the Get-Command exempt comment is kept) | The wrapper was always true on Windows. The `else` SKIP "Windows PowerShell not available" is kept, because powershell.exe can be missing on Windows |
| relay pty: `if ($havePty -and $IsWindows)` became `if ($havePty)` | The same reason as the first row |

**Removed checks**: none. The suite never had a check behind a non-Windows branch. The only SKIPs it has (node missing, no pty, no PS 5.1) can fire on Windows, so all are kept with their text unchanged (open question 1).

**Before / after / CI**: rc 0/0. PASS 97/97/97; the lines are identical and in the same order. FAIL 0. SKIP 0. The full log is byte-identical before and after. The pty cases ran (pywinpty is present locally).

**Mutation**: `Check "word answer: 'Yes' with y/yes/n/no -> yes" (ResIs "yes")` changed to `(ResIs "no")` gives rc=1 and `96 passed, 1 failed`, with FAIL `word answer: 'Yes' with y/yes/n/no -> yes`. The file was restored byte-identical (SHA-256).

## 3. Verification (Windows 11, pwsh 7)

| Check | Result |
|---|---|
| Baseline vs CI (`ci-section.py ... ci-windows-875e957.log`) | The CI PASS lines are identical to local before and after (45 and 97). 875e957 contains 4d881f7, the last commit to either file (`git merge-base --is-ancestor`) |
| PowerShell parser (`Parser::ParseFile`) | 0 errors in both files |
| `-Help` | rc 0 for both; 13 and 47 lines, each ending at `# Usage:` |
| `classify-guards.pl W W/.claude/rules/cross-platform.md <list>` | `win` test-logging.ps1, `win` test-menu-choice.ps1, rc 0. Neither guard message contains `}` |
| Leftover tokens (`IsWindows`, `chmod`, `not Windows`, `Skip "`) | Only the guard line in each file, plus `StepSkip` in the check-lib child script (a check-lib function, not the removed helper) |
| Line endings (`git ls-files --eol`) | `i/lf w/crlf` both, the same as before; no mixed endings |
| `git -C W status --short tests/logging tests/menus` | Only ` M tests/logging/test-logging.ps1` and ` M tests/menus/test-menu-choice.ps1` |

Not run: the `.sh` twins (out of scope; per the rule, a `.sh` suite is never run on Windows), the off-Windows refusal of the `.ps1` guards (that needs macOS or Linux; the CI side is `tests/os-guards/test-os-guards.sh`), and no aitools, setup-user-*, deploy-harness, build-deploy.sh or check script.

Scratch (gitignored) is `W\.scratch\session-e9d6-16\`. It holds run-suites.ps1, compare.ps1, mutate.ps1, verify-static.ps1, wait-mutant.sh, classify-list.txt, and the `*-before.log`, `*-after.log`, `*-mutant.log` and `.rc` files.

## Lines

- INCIDENT: none.
- CONFLICT: none. The mission prompt and cross-platform.md "Test suites" give the same guard text.
- WRITE_BLOCKED: none.
- Operational learning, confirmed: my first run-suites.ps1 looped with `foreach ($s ...)` while `$S` held the scratch path. PowerShell names are case-insensitive, so the loop overwrote the path and the first baseline run wrote nowhere. I caught it from the error output, renamed the variables, and reran; the baseline above comes from the corrected run.

## Open questions (each with a suggested answer)

1. Three SKIP texts in test-menu-choice.ps1 still mention Windows, although each can fire on Windows:
   - "SKIP pty case (no pseudo-terminal: python3 missing, or pywinpty not installed on Windows)"
   - "SKIP relay pty case (Windows console API, and a pseudo-terminal: pywinpty)"
   - The header phrase "pywinpty/ConPTY on Windows"

   Suggested: leave them. They are reachable on Windows, and the brief asks for unchanged output. A later wording pass can drop "on Windows" and "Windows console API".
2. `$script:skip` in test-logging.ps1 is never incremented now, because there are no Skip calls left. Suggested: keep it, so the summary line stays `---- N passed, N failed, N skipped`, byte-identical to before. This matches e9d6-12's choice for test-setup-user-shell.ps1.
3. test-logging.sh's header still says "Platform: macOS, Linux, Windows (Git Bash)". Suggested: decide this together with the open RFI on the bash `scripts/aitools` entry point. I did not edit it, as it is out of scope.
