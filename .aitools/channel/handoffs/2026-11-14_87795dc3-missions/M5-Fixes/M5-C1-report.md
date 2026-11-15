# M5-C1 report: Git Bash for the PowerShell checks (item 9), CI covers .ps1 suites (item 4)

Version 1.0 (2026-11-14). Author: M5-C1, delegated by M5-Fixes. Branch
`fix/m5-checks` (worktree `.claude/worktrees/m5-checks`), off origin/main 592c5b3.

**Intent**: **Purpose**: hand M5-Fixes the result of items 9 and 4: what changed,
the evidence, what was not run, and what is still open. **Scope**: items 9 and 4
only. NOT check-post-push steps 7 and 29 (M5-C2). NOT the PR (M5-Fixes opens it).
**Audience**: M5-Fixes, then the commander.

## Summary

1. Item 9 fixed: one helper, `ResolveGitBash` in `scripts/check-lib.ps1`; check-pre-commit, check-pre-push and check-post-push (.ps1) run bash only through it; no PATH fallback; the WSL launchers refused.
2. Item 4 fixed: "Every test suite is in CI" now also requires a `pwsh` step for each tracked `tests/*/test-*.ps1`; the logic moved to `scripts/check-ci-suites.pl` with a committed test suite.
3. Two new suites, each with its own CI step: `tests/check-lib/test-resolve-git-bash.ps1` (windows, 17/17) and `tests/ci-suites/test-check-ci-suites.sh` (linux, 21/21).
4. Pushed: fdcffc9 (item 9), 2a5661f (item 4), plus the commit carrying this report.
5. One WRITE_BLOCKED: the RELEASE_NOTES.md v0.77.2 item 2 (item 4) edit was denied; the text is below for M5-Fixes to apply.

## Item 9: check-*.ps1 use the managed Git Bash

Status: fixed.

The bug, as found (origin/main 592c5b3):
- `check-pre-commit.ps1` step 2: `$result = bash -n $f 2>&1` (bare `bash`); step 3 `-Fix`: `(Get-Command bash -ErrorAction SilentlyContinue).Source`.
- `check-pre-push.ps1` step 7: the three Git for Windows locations, then `Get-Command bash` as a fallback.
- `check-post-push.ps1`: `$bashExe = (Get-Command bash -ErrorAction SilentlyContinue).Source` for steps 2, 4, 6, 7.
- No other `check-*.ps1` runs bash (Grep of `bash` over `scripts/check-*.ps1`).

What the bare `bash` is on this workstation (probe from a pwsh with the registry PATH, `.scratch/session-M5-C1/probe-bash.ps1`): `C:\Users\jdpal\AppData\Local\Microsoft\WindowsApps\bash.exe` (the WSL app-execution alias). `C:\Windows\System32\bash.exe` does NOT exist here (the prompt's learning named System32; the launcher on this machine is the WindowsApps one). From a pwsh started by Git Bash (Claude Code), `Get-Command bash` finds `C:\Program Files\Git\usr\bin\bash.exe` first, so the bug only shows in a native pwsh terminal.

The fix:
- `ResolveGitBash` (check-lib.ps1, "Managed Git Bash (Windows)"): probes `$env:ProgramFiles\Git\bin\bash.exe` (verified 2026-11-13, Git for Windows 2.56.0, bash 5.3.15), `${env:ProgramFiles(x86)}\Git\bin\bash.exe` and `$env:LOCALAPPDATA\Programs\Git\bin\bash.exe` (both marked `# UNVERIFIED`, from the setup-bash.ps1 list); returns the first existing file or `$null`; refuses any candidate under `%SystemRoot%` or `%LOCALAPPDATA%\Microsoft\WindowsApps` (case-insensitive) even when it exists; `-Candidates` replaces the list (tests). Named in the check-lib style (`ResolveConfig`, `InvokeGit`). Put in check-lib, not aitools-lib, because M5-L1 edits aitools-lib in parallel.
- check-pre-commit.ps1: `$gitBash = ResolveGitBash` once after `Set-Location`, logged at detail (`Git Bash: <path>` or `not found`). Step 2: `& $gitBash -n $f`; new branch: no Git Bash -> WARN `Git Bash not found -- N .sh file(s) not checked`. Step 3 `-Fix`: `& $gitBash ... build-deploy.sh`, FAIL text `Git Bash not found for build-deploy.sh`.
- check-pre-push.ps1 step 7: `$d7Bash = ResolveGitBash` (list and PATH fallback removed; comment updated). Not-found behaviour unchanged (WARN).
- check-post-push.ps1: `$bashExe = ResolveGitBash` plus a comment; nothing else touched (M5-C2 owns steps 7 and 29). The SKIP texts there still say "bash not found".
- The `.sh` twins are unchanged: POSIX-guarded, and `bash` on PATH is correct on macOS/Linux.

Evidence:
- `pwsh -NoProfile -File tests/check-lib/test-resolve-git-bash.ps1`: 17 passed, 0 failed, 0 skipped. Cases: probe order, missing candidate skipped, `$null` with nothing found (no fallback), empty list, empty entries, a directory named bash.exe; System32 launcher refused (any case); the WindowsApps launcher (exists here) refused and the next candidate wins; the default probe returns `...\Git\bin\bash.exe` and not the native-PATH WSL launcher; an AST scan: no check-*.ps1 runs a bare `bash` or calls `Get-Command bash`; the three checks call `ResolveGitBash`.
- Mutation check (`.scratch/session-M5-C1/mutation-old-callers.ps1`): the same suite against the origin/main check-*.ps1 -> 13 passed, 4 failed (`check-post-push.ps1:50: Get-Command bash; check-pre-commit.ps1:60: bare bash; check-pre-commit.ps1:110: Get-Command bash; check-pre-push.ps1:133: Get-Command bash`), exit 1.
- How I know check-pre-commit's `bash -n` step uses Git Bash (`.scratch/session-M5-C1/proof-step2.ps1`): a temp clone of the worktree, a good and a broken `.sh` staged, run from a pwsh with the registry PATH (bare `bash` = the WindowsApps launcher). New script: step 2 FAIL, `FAIL: proof/broken.sh` only, deploy.log `[detail] Git Bash: C:\Program Files\Git\bin\bash.exe`. Pre-fix script: FAIL on both files, good.sh included (the launcher ran it). And in the real run from the worktree (item 4 commit, `test-check-ci-suites.sh` staged): step 2 (.sh) PASS, deploy.log line `Git Bash: C:\Program Files\Git\bin\bash.exe`.
- check-pre-push.ps1 from the worktree, both pushes: step 7 PASS `fresh build OK (dotprofile deploy/ untracked, not compared); resolver consumers dry-run clean` with the new resolver; 8 PASS, 2 WARN (steps 1 and 6, advisory), 0 FAIL.

## Item 4: CI "Every test suite is in CI" covers .ps1 suites

Status: fixed.

- `.github/workflows/check.yml` (linux job): the step now runs `git ls-files 'tests/*/test-*.sh' 'tests/*/test-*.ps1' | perl scripts/check-ci-suites.pl .github/workflows/check.yml`; its comment states the new scope and points to the script (the "covers test-*.sh only" sentence is gone). New step right after it: `bash tests/ci-suites/test-check-ci-suites.sh`.
- `scripts/check-ci-suites.pl` (new, 100755): the old inline logic unchanged for `.sh`; `.ps1` counts when a single-line `run:` (before any `#`) contains `pwsh` and then the path, `-File` optional (any case), `/` or `\` separators, optional quotes, followed by whitespace or end of line. Same `%exempt` table (empty) and stale-exemption checks; an unsupported suite type fails; exit 0/1, 2 for usage or an unreadable workflow; `--help`.
- Choice recorded: extracted to a script (not kept inline) so the logic has a committed test; a clean change, since the step's behaviour for `.sh` is identical and CI already calls `scripts/check-hook-parity.py` the same way. The new suite runs in the linux job only, next to the check (the check is static, like the one-copy step).
- Every tracked `.ps1` suite already had a windows-job step: aitools-entry/test-console-mode-guard, logging/test-logging, managed-files/test-adopt-push, managed-files/test-managed-files, menus/test-menu-choice, pywinpty/test-setup-pywinpty, setup-user-shell/test-setup-user-shell, and the new check-lib/test-resolve-git-bash. None added for item 4.

Evidence:
- `bash tests/ci-suites/test-check-ci-suites.sh`: 21 passed, 0 failed (current tree passes; planted `tests/planted/test-planted.ps1` and `.sh` fail and are named; a copy of check.yml without the `tests/logging/test-logging.ps1` run line fails naming it while `test-logging.sh` still counts; without the os-guards run lines fails; 5 forms count, 5 do not, including the documented `run: |` blind spot; `.py` input, empty input, unreadable workflow, `--help`).
- The step's run line verbatim from the worktree root (`.scratch/session-M5-C1/ci-step.sh`): `All 40 test suites are in CI or exempt`, exit 0.
- `perl -c` OK, `bash -n` OK; `git ls-files -s`: both new files 100755.

## Branch, commits, files

- Branch `fix/m5-checks`, pushed to origin: fdcffc9 (item 9), 2a5661f (item 4), and the report commit.
- Files changed: `scripts/check-lib.ps1`, `scripts/check-pre-commit.ps1`, `scripts/check-pre-push.ps1`, `scripts/check-post-push.ps1`, `.github/workflows/check.yml`, `RELEASE_NOTES.md`; new `tests/check-lib/test-resolve-git-bash.ps1`, `scripts/check-ci-suites.pl`, `tests/ci-suites/test-check-ci-suites.sh`, this report.

## Verification (commands and results)

| Command | Result |
|---|---|
| pwsh parser on the 5 touched/new .ps1 (`parse-touched.ps1`) | 0 errors |
| `pwsh -NoProfile -File tests/check-lib/test-resolve-git-bash.ps1` | 17 passed, 0 failed |
| same suite against origin/main check-*.ps1 (`mutation-old-callers.ps1`) | 4 failed, exit 1 (as intended) |
| `proof-step2.ps1` (native PATH, good + broken .sh) | new: broken.sh only; old: both |
| `bash tests/ci-suites/test-check-ci-suites.sh` | 21 passed, 0 failed |
| CI step run line, worktree root | All 40 test suites, exit 0 |
| `bash tests/os-guards/test-os-guards.sh` (Git Bash) | 34 passed, 0 failed |
| `check-pre-commit.ps1` (item 9 staged) | 9 PASS, 6 SKIP, 3 WARN, 1 FAIL (step 20) |
| `check-pre-commit.ps1` (item 4 staged) | 9 PASS, 5 SKIP, 4 WARN (3, 5, 9, 11), 1 FAIL (step 20) |
| `check-pre-push.ps1` (before each push) | 8 PASS, 2 WARN, 0 FAIL; step 7 PASS |

All check runs had `AITOOLS_LOG_DIR` in `.scratch/session-M5-C1/logs-*` (nothing written to `~/.aitools/logs`). Known pre-existing: pre-commit step 20 (5 dead path refs: CLAUDE.md:100, reference/cursor-practices.md:43, reference/tool-registry.md:341 and :354, shared/claude-shared.md:95; M5-D1); step 11 WARN (uncommitted changes in the dotprofile, not mine; I never wrote there); step 9 WARN on the item 4 commit (the RELEASE_NOTES edit was blocked).

## Not run

- `check-post-push.ps1` / `.sh` (step 7 runs build-deploy.sh against the real HOME); its change is covered by the AST caller cases and the same helper.
- CI itself (first Linux run of `check-ci-suites.pl`, first windows run of the new .ps1 suite: the PR run).
- macOS `/bin/bash` 3.2 for `test-check-ci-suites.sh` (written 3.2-safe; not in the macos job).

## Review after (old -> new)

- `scripts/check-lib.ps1`: (none) -> `ResolveGitBash` (Git for Windows locations, no PATH fallback, WSL launchers refused, `-Candidates`).
- `check-pre-commit.ps1` step 2: bare `bash -n` -> `& $gitBash -n`, plus WARN when Git Bash is not found; step 3 `-Fix`: `Get-Command bash` -> `ResolveGitBash`, "bash not found for build-deploy.sh" -> "Git Bash not found for build-deploy.sh".
- `check-pre-push.ps1` step 7: Git for Windows list + `Get-Command bash` fallback -> `ResolveGitBash`.
- `check-post-push.ps1`: `Get-Command bash` -> `ResolveGitBash`.
- `check.yml` "Every test suite is in CI": inline perl, `.sh` only -> `perl scripts/check-ci-suites.pl` over `.sh` and `.ps1`; comment rewritten.
- `check.yml`: new windows step `check-lib ResolveGitBash tests`; new linux step `check-ci-suites tests`.
- `scripts/check-ci-suites.pl`, `tests/ci-suites/test-check-ci-suites.sh`, `tests/check-lib/test-resolve-git-bash.ps1`: new.
- `RELEASE_NOTES.md`: new `v0.77.2` entry (item 1 bug fix + its suite; item 2 missing, see WRITE_BLOCKED).

## WRITE_BLOCKED / CONFLICT / INCIDENT

WRITE_BLOCKED: Edit of `RELEASE_NOTES.md` (add v0.77.2 Improvements item 2, two Files-created rows, and the item-4 "Verified on" text) -- "Permission for this action was denied by the Claude Code auto mode classifier. Reason: [Destructive or Unwanted Actions]." Not retried. Text for M5-Fixes to apply to the v0.77.2 entry (after the Bug fixes table; replace the Files created table and the Verified line):

```
### Improvements

| # | Change |
|---|--------|
| 2 | CI "Every test suite is in CI" (linux job) covers `tests/*/test-*.ps1` too: a tracked `.ps1` suite fails the step unless a single-line `run:` runs it with `pwsh` (`-File` optional, `/` or `\` in the path). It was `.sh`-only, so a new `.ps1` suite could go untested. The inline perl moved to `scripts/check-ci-suites.pl` (same `%exempt` table and blind spots, `--help`), which the step calls and a new suite tests. All 8 tracked `.ps1` suites already had a step |

### Files created

| File | Purpose |
|------|---------|
| `tests/check-lib/test-resolve-git-bash.ps1` | Probe order, no fallback, the WSL launchers refused, the default probe on the machine, no check-*.ps1 resolving bash through PATH (CI windows job) |
| `scripts/check-ci-suites.pl` | The "Every test suite is in CI" logic (was inline perl in `check.yml`) |
| `tests/ci-suites/test-check-ci-suites.sh` | The current tree passes; planted `.sh` / `.ps1` suites and removed steps fail; the `.ps1` forms that count and those that do not (CI linux job) |

**Verified on:** Windows 11 (Git for Windows 2.56.0, bash 5.3.15, pwsh 7, Git Bash perl): `test-resolve-git-bash.ps1` 17/17 (against the pre-fix check scripts it fails 4 cases); `test-check-ci-suites.sh` 21/21. check-pre-commit.ps1 and check-pre-push.ps1 run from the branch; check-post-push.ps1 not run (its step 7 rebuilds deploy/ against the real HOME). The linux CI job is the first run of `check-ci-suites.pl` on Linux.
```

CONFLICT: prompt "read IN FULL every file below" vs the D-DEL6 order -- no real conflict; all listed rules and references were read in full (script-standards-detail.md in four reads). The rules already in context came from the main checkout (e8ebd07); I read the worktree diffs of the four rules that differ (agentic-standards, deploy-paths, hook-lifecycle, interactive-menus) and the rules not in context from the worktree.

INCIDENT: none filed. Candidate for M5-Fixes triage: `check-pre-commit.ps1` step 3 `-Fix` runs `build-deploy.sh` with `2>$null | Out-Null` and no exit-code check (pre-existing, script-standards "Error handling requirements"; untouched here, out of scope).

Process note (no effect): one Edit call was mistakenly addressed to the main checkout's `.github/workflows/check.yml` with a placeholder string; it failed with "String to replace not found" and changed nothing (`git -C <main> status -- .github scripts tests RELEASE_NOTES.md` is clean).

## Follow-ups

1. Apply the WRITE_BLOCKED RELEASE_NOTES text (M5-Fixes).
2. `scripts/setup-bash.ps1` and `scripts/aitools.ps1` (Step 2) keep their own Git Bash lookups; moving `ResolveGitBash` to aitools-lib.ps1 would let all of them share it (after M5-L1 merges, to avoid a conflict).
3. The check-post-push SKIP texts still say "bash not found" (steps 2, 6, 7); M5-C2 can say "Git Bash not found" while it is in step 7.
4. The two UNVERIFIED Git Bash locations (x86, per-user) need an empirical check on a machine that has them (script-standards "KnownPaths empirical verification").

## Open questions

- Should pre-commit step 2 be FAIL rather than WARN when Git Bash is missing and `.sh` files are staged? Suggested answer: WARN, as written: it matches pre-push step 7 ("Git Bash not found" WARN), and a Windows machine without Git for Windows cannot run Claude Code anyway.
- Should `test-check-ci-suites.sh` also run in the macos and windows jobs? Suggested answer: no; the check it tests is static and runs once, in the linux job.

## New operational learning

- On this workstation the WSL launcher a native pwsh finds is `%LOCALAPPDATA%\Microsoft\WindowsApps\bash.exe`; `C:\Windows\System32\bash.exe` does not exist. From pwsh started by Git Bash, `Get-Command bash` finds Git's `usr\bin\bash.exe` instead, so a PATH bug in the checks is invisible from Claude Code; reproduce with the registry PATH (`[Environment]::GetEnvironmentVariable('Path','Machine')` + `'User'`).
- In Git Bash, `git -C <worktree> ls-files tests/*/test-*.ps1` (unquoted) is expanded by the shell against the CURRENT directory (the main checkout), not the worktree, and silently lists the wrong set; quote git pathspecs.
- The auto-mode classifier denied a plain RELEASE_NOTES.md table edit in the worktree; plan for M5-Fixes applying release-note text by hand.
