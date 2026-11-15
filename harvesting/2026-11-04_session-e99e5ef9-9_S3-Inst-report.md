# S3-Inst report v1.0 (2026-11-01)

## Summary
1. tests/claude-mdm, tests/hookin and tests/build-deploy now run each script only on the platform its guard allows. All guard bypasses are gone: the Perl guard-stripped copies of setup-user-claude.ps1, of the generated deploy/setup-user-claude.ps1 and of deploy-harness.ps1, and `AITOOLS_PROFILE_TEST_ANY_OS=1`.
2. claude-mdm: the dev and MDM cases run .sh on macOS/Linux and .ps1 on Windows (native pwsh). The sh-vs-ps1 dry-run parity is now 4 golden files. build-deploy.sh runs on all three platforms.
3. hookin: the installer cases are macOS/Linux only. The `scripts/aitools` deploy_configs loop runs on all three: the script has no guard and has a Windows branch. The ps cases (hookin-driver.ps1) are Windows only, and the driver now has a Windows guard.
4. build-deploy: the suite ran no real pwsh. Its only pwsh is a stub on PATH, which reaches both of the build's validation branches. It now works on Windows too and needs a windows check.yml step.
5. macOS: claude-mdm 33/0, hookin 31/0, build-deploy 24/0, under both bash 5.3 and /bin/bash 3.2. Windows and Linux have not been run; PR #139 CI will run them.

## Branch and SHAs
Branch `feature/ci-plat-inst`, created off origin/feature/ci-platform-targeting at a857c12, pushed to origin. No PR opened.
- 2851e0f claude-mdm
- 6659307 hookin
- 3e224f2 build-deploy

## Files changed
- tests/claude-mdm/test-claude-mdm.sh
- tests/claude-mdm/golden/dry-1.rows, dry-2.rows, dry-3.rows, dry-4.rows (new)
- tests/hookin/test-hookin.sh
- tests/hookin/hookin-driver.ps1
- tests/build-deploy/test-build-deploy-backup.sh

## Per suite

| Suite | Old macOS (bash 5 / 3.2) | New macOS (bash 5 / 3.2) | Windows expected | Goldens |
|---|---|---|---|---|
| claude-mdm | 29 pass, 9 fail / same (the 9 are the emulated ps1 cases, which fail since 9c3e556) | 33 pass, 0 fail / same | 33 pass, 1 skip (unreadable-file case: chmod does not block reads) | dry-1..4.rows; no `.<platform>` variants; dry-4 is compared only where chmod blocks reads |
| hookin | 46 pass / 46 pass (15 of them ps cases under emulation) | 31 pass / 31 pass | 29 (9 static + 5 bash loop + 15 ps) | none: the suite never asserted sh-vs-ps1 parity |
| build-deploy | 24 / 24 | 24 / 24 | 24 | none: no .sh/.ps1 pair under test |

The goldens hold one row each (for example `OK|claude.md|verified`). They contain no paths, user names or host names.

### claude-mdm details
- **Dev cases (language under test):**
  - The A-25 footer cases now include the "live" no-stub case in both languages.
  - The A-26 dry-run rows are checked explicitly and against the golden files.
- **Resolver stubs:** stub-host.ps1 and no-host.ps1 call aitools-profile.ps1 through a native path. fail.ps1 is new, next to fail.sh (on Windows the lib resolves through the .ps1). LIVE_HOST comes from aitools-profile.ps1 on Windows.
- **Build (all platforms):**
  - HOME stays POSIX for bash.
  - USERPROFILE, AITOOLS_LOG_DIR and AITOOLS_SUMMARY_FILE are native, so the build's child pwsh (Windows resolver, PS1 validation) stays isolated.
  - config.json userRepoPath is written in native form.
- **A-19 runtime:**
  - macOS/Linux keep the generated .ps1's OS-guard exit 1. This is a guard-refusal test, not an emulated Windows run, and tests/os-guards does not scan the dotprofile deploy/.
  - Windows runs each generated .ps1 with -DryRun, with TMP/TEMP isolated, and checks the same temp-dir removal and env restore, also in-process.
  - The pwsh parse runs on every platform where pwsh is installed.
- **MDM ps1 full run (Windows):** runs the real generated setup-user-claude.ps1, guard intact.
- **MDM smoke runs:** use the generated script of the language under test, with the embedded resolver.
- **A-20 on ConPTY:** any SGR sequence counts as colour, because ConPTY re-renders the screen.
- **Not converted:** nothing.

### hookin details
- The fixture holds the real deploy-harness.ps1. The old check "guard disabled" became "fixture is the real script (guard intact)".
- CRs that pwsh writes on Windows are stripped from out, summary, calls and writer-calls.
- On Windows, the bash loop does not relay deploy-harness.ps1 to deploy.jsonl. This is by design (comment in scripts/aitools), so that one check is macOS/Linux only.
- hookin-driver.ps1 gained a canonical Windows guard, placed after Initialize-Logging. Its parse is OK, and under an isolated HOME on macOS it refuses with exit 1 and the guard message.

### build-deploy details
- The suite contains no real pwsh call. The "~5 calls" are the per-case stub (`$C/bin/pwsh`: `exit 0` or `exit 1`).
- On Windows, Git Bash finds the stub before pwsh.exe. Both validation branches print "PS1 file(s) failed validation" when it exits 1. The old header claim that Windows takes a branch the stub does not reach was wrong, and is fixed.
- AITOOLS_USER_REPO_PATH is now passed in the C:/... form on Windows, as scripts/aitools passes it.

## Proposed check.yml steps (not edited; out of scope)
- **linux:**
  - rename `setup-user-claude dev + MDM tests (bash + pwsh)` to `setup-user-claude dev + MDM tests (.sh)`, run: `bash tests/claude-mdm/test-claude-mdm.sh`
  - rename `Installer harness hook-in tests (bash + pwsh)` to `Installer harness hook-in tests (.sh)`, run: `bash tests/hookin/test-hookin.sh`
  - build-deploy: unchanged
- **macos, bash 5:**
  - `setup-user-claude dev + MDM tests (.sh, bash 5)`, run: `bash tests/claude-mdm/test-claude-mdm.sh`
  - `Installer harness hook-in tests (.sh, bash 5)`, run: `bash tests/hookin/test-hookin.sh`
  - build-deploy: unchanged
- **macos, /bin/bash 3.2:**
  - the existing claude-mdm and build-deploy 3.2 steps stay as they are
  - optional new step `Installer harness hook-in tests (macOS /bin/bash 3.2)`, run: `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/hookin/test-hookin.sh` (passes 31/31)
- **windows** (`shell: bash`, `if: ${{ !cancelled() }}`; place after the pywinpty install step, in the "Heavy suites" block):
  - `setup-user-claude dev + MDM tests (.ps1, native pwsh)`, run: `bash tests/claude-mdm/test-claude-mdm.sh`
  - `Installer harness hook-in tests (.ps1 native pwsh, scripts/aitools Windows branch)`, run: `bash tests/hookin/test-hookin.sh`
  - `build-deploy backup + swap tests (incident #86, via Git Bash)`, run: `bash tests/build-deploy/test-build-deploy-backup.sh`

## Windows risks (unverified, for CI to settle)
- **hookin bash loop on Windows (new coverage):** this is the first run of the MINGW branch of deploy_configs. It needs `pwsh -File` stubs, USERPROFILE isolation, and a ConPTY abort through bash and its pwsh child.
- **claude-mdm MDM ps1 smoke:** expects the same rows as .sh (`OK|claude rules|1 added`, `OK|claude skills|2 added`), on the strength of the library twins. The old suite never ran this on .ps1.
- **claude-mdm A-19 on Windows:** relies on .NET GetTempPath reading TMP. The generated setup-user-cursor/settings dry runs may exit non-zero. That is not asserted; only the cleanup is.
- **Duration:** the build runs twice in claude-mdm (once full, once a fast skip), plus the tty run, on Windows.

## Proposed diffs for platform-lib.sh or scripts/
- **Required:** none.
- **Optional (platform-lib.sh):** a `pty_available` helper, because the "python3 + import winpty on Windows" probe is now copied in 5 suites. Also a `strip_cr FILE...` helper.

## WRITE_BLOCKED, CONFLICT, INCIDENT
- WRITE_BLOCKED: none.
- CONFLICT: D-DEL4 (a code-change delegate opens its own PR) vs the commander's 2026-11-01 words "Branch + PR" (one PR, #139) and "Everything at once". Resolved by tier 1: I pushed `feature/ci-plat-inst` and opened no PR.
- INCIDENT: `scripts/aitools` is an extensionless bash entry point with no OS guard and explicit Windows branches. It is not in the cross-platform.md "OS guard exemptions" table, and not in the plan's "Platform targets" table. tests/os-guards classifies only `.ps1`/`.sh`, so it is never checked. Suggested fix: add it to the exemption table ("Entry points ... each also runs in Git Bash"), and make test-os-guards include extensionless scripts that have a bash shebang.

## Open questions
1. Keep the bash loop running on Windows? Suggested answer: yes. It is real user code. If CI fails it, that is a B5 bug or a wrong expectation to fix, not a reason to stop testing it.
2. Keep the A-19 generated-.ps1 guard-exit cases on macOS/Linux? Suggested answer: yes. They are guard-refusal tests, which the commander asked for, and no other suite covers the generated deploy/.
3. Add hookin under /bin/bash 3.2 on macOS? Suggested answer: yes. It is cheap and already passes.
