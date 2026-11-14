## Summary

Mission M5-Fixes, checks group (items 9, 4, 3, 11, 12).

- Item 9: the PowerShell checks (`check-pre-commit.ps1`, `check-pre-push.ps1`, `check-post-push.ps1`) find bash only through `ResolveGitBash` (`scripts/check-lib.ps1`): Git for Windows install folders, no PATH fallback, WSL launchers under `%SystemRoot%` or `%LOCALAPPDATA%\Microsoft\WindowsApps` refused.
- Item 4: CI "Every test suite is in CI" also fails a tracked `tests/*/test-*.ps1` with no `pwsh` step. The inline perl moved to `scripts/check-ci-suites.pl` with its own suite.
- Item 3: check-post-push step 7 is retired in both twins (always SKIP, never runs `build-deploy.sh`); `shared/rules/tool-lifecycle.md` "Rebuild + propagate" now points at the pre-push checklist (whose step 7 rebuilds into a temp dotprofile copy) and then the post-push checklist.
- Item 11: check-post-push step 29 also compares the prompts passed to `read_menu_choice` / `Read-MenuChoice` (e.g. the merge preview's `[y]es/[r]efine/[n]o`), through `scripts/check-menu-parity.pl` shared by both twins.
- Item 12: tool-lifecycle "Lifecycle field completeness" says `null` (not `pending`) for an unverified platform version, and `null` on an `n/a` platform -- matching the registry (57 tool-platform versions: 31 strings, 26 null, 0 pending; the 4 n/a platforms null). No registry change.

## Why

- Item 9 (mission M1): from a native pwsh, `Get-Command bash` finds the WSL launcher (`%LOCALAPPDATA%\Microsoft\WindowsApps\bash.exe` on the commander's workstation). cross-platform.md "Windows: managed bash": Git Bash is the managed bash.
- Item 4 (mission M3b): the check covered `test-*.sh` only (FO-0).
- Item 3 (mission M3b): post-push step 7 ran `build-deploy.sh` with the caller's HOME -- replacing the real dotprofile `deploy/` (incident #86 class) -- then diffed the frozen aitools `deploy/`, so it always passed; yet tool-lifecycle told agents to run check-post-push. check-pre-push step 7 already does the isolated rebuild on every push (commander, 2026-10-26); its ~130-line block is entangled with pre-push's env scrubbing, so retiring beat a third copy.
- Item 11 (mission M2): prompts moved into the menu helpers' arguments had dropped out of the parity audit.
- Item 12 (mission M4): rule text and registry convention disagreed.

## Changes

- `scripts/check-lib.ps1` (`ResolveGitBash`), `scripts/check-pre-commit.ps1`, `scripts/check-pre-push.ps1`, `scripts/check-post-push.ps1` / `.sh` (bash resolution, step 7 retired, step 29 via the new script, "Git Bash not found" texts).
- New: `scripts/check-ci-suites.pl`, `scripts/check-menu-parity.pl`, `tests/check-lib/test-resolve-git-bash.ps1`, `tests/ci-suites/test-check-ci-suites.sh`, `tests/check-post-push/test-post-push-step7.sh`, `tests/check-post-push/test-menu-parity.sh`.
- `.github/workflows/check.yml`: suite step calls `check-ci-suites.pl`; steps for the new suites.
- `shared/rules/tool-lifecycle.md`, `reference/post-push-checklist.md`, `RELEASE_NOTES.md` v0.77.2, mission reports.

## Verification

Windows 11 (Git for Windows 2.56.0, bash 5.3.15, pwsh 7.6), by delegates M5-C1 and M5-C2:
- test-resolve-git-bash.ps1 17/0 (4 failures against the pre-fix scripts); test-check-ci-suites.sh 21/0; test-post-push-step7.sh 10/0 (6 failures against the pre-fix twins); test-menu-parity.sh 24/0 (old extraction shown to miss both planted prompt mismatches); os-guards 34/0; all 42 suites in CI per `check-ci-suites.pl`.
- In a clone run with the native registry PATH, the old pre-commit step 2 failed a good `.sh` (WSL bash), the new one fails only the broken one.
- check-post-push.ps1 run once after the step 7 fix under an isolated HOME/USERPROFILE/APPDATA/LOCALAPPDATA/AITOOLS_LOG_DIR with a cloned dotprofile: step 7 SKIP, step 29 PASS; before/after snapshots show the real dotprofile `deploy/` and `~/.aitools/logs` unchanged. Its 3 FAILs are not from this PR (step 1 branch != origin/main; step 3 no `.claude.json` in the isolated HOME; step 23 `setup-pywinpty.ps1` SilentlyContinue without a result check, from #148).
- check-pre-commit.ps1: only step 20 FAIL (Windows-only false positives fixed in #151); check-pre-push.ps1: 0 FAIL.

## Not run

- `check-post-push.sh` (POSIX-guarded; its steps 7 and 29 are exercised by the suites).
- macOS bash 3.2 for the new suites locally (CI).

## Review after (D-DEL5, old -> new)

1. check-lib: nothing -> `ResolveGitBash`.
2. pre-commit step 2: bare `bash -n` -> `& $gitBash -n`, WARN when Git Bash is missing; step 3 `-Fix`: `Get-Command bash` -> the helper, FAIL "Git Bash not found for build-deploy.sh".
3. pre-push step 7 / post-push: `Get-Command bash` (+ folder list) -> the helper.
4. check.yml suite step: inline perl over `.sh` -> `scripts/check-ci-suites.pl` over `.sh` and `.ps1`; 6 new suite steps.
5. post-push step 7: build-deploy + `git diff deploy/` -> SKIP "retired: check-pre-push step 7 rebuilds into a temp dotprofile copy".
6. post-push step 29: inline printf/Console letter extraction -> `check-menu-parity.pl` (menu lines + helper prompts, multiset compare), SKIP when perl is missing.
7. tool-lifecycle "Rebuild + propagate" step 3: "`bash scripts/check-post-push.sh` — all checks pass" -> pre-push checklist before each push (both platforms' commands), new step 5 post-push checklist after the push.
8. tool-lifecycle "Lifecycle field completeness": "a last verified version per platform (`pending` when unverified)" -> "a last verified version and date per platform: `null` until verified on that platform, and `null` on a platform the tool does not support (platform status `n/a`)".
9. reference/post-push-checklist.md steps 2, 7, 29 rewritten to match the code.
10. RELEASE_NOTES.md: v0.77.2.

## Follow-ups

- RELEASE_NOTES v0.77.2 has no row for item 4 (the CI suite check): M5-C1's edit adding it was denied by the auto-mode classifier (WRITE_BLOCKED); the exact text is in `M5-C1-report.md` for the commander to apply.
- `setup-bash.ps1` and `aitools.ps1` keep their own Git Bash lookups; move `ResolveGitBash` into aitools-lib.
- Post-push steps 2, 6, 14 and pre-commit steps 3, 10 still inspect the frozen aitools `deploy/`; pre-commit step 3's WARN suggests `-Fix`, which runs build-deploy against the real HOME.
- `setup-pywinpty.ps1` SilentlyContinue without a result check (post-push step 23 FAIL).
- `check-menu-parity.pl` could also check other script pairs (`scripts/aitools`/`.ps1`, `setup-user-hooks`, `setup-user-skills`).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
