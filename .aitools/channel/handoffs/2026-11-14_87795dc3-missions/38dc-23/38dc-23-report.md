# 38dc-23 report: OS guards on the relay prompt scripts; no Git Bash in the Windows checks

**Intent**: **Purpose**: Record what mission 38dc-23 found and changed: the
loaders of `relay-outbound-prompt.sh/.ps1`, the bash `aitools` dependency on
the `.sh` and how it is resolved, every Git Bash call in the `check-*.ps1`
scripts and what replaced it, the tests and their mutation results, and the
open question. **Scope**: This mission's branch
`fix/38dc-23-relay-guards-no-gitbash`. NOT the other exemption rows (38dc-13),
the `grep -q` pipefail race (38dc-24), or `build-deploy.sh` itself.
**Audience**: The commander; M6-Polish (orchestrator, id ends 38dc).

v1.1, 2026-11-14. Author: 38dc-23 (delegated by M6-Polish, session 87795dc3).
v1.1: the independent review's blocking finding (the `.ps1` guard does not
end a dot-sourcing caller) and its non-blocking findings are resolved (section
10); the counts and the mutation results are updated.

## Commander's words this mission carries out (2026-11-14)

Answer to RFI 38dc-7: "relay-outbound.sh/.ps1 need os guards they are not
exempt, the aitools dependency needs to be resolved (how to resolve it and
resolving it need to be part of same mission) ... for the check-*.ps1 can youj
explain this further? id like to avoid calling git bash on thowse ps1 scripts.
delegate this as a mission."

## 1. Who loads the relay prompt scripts (origin/main 5f962b1)

| Loader | Loads | Runs on |
|---|---|---|
| `scripts/aitools` `main()`, after the sync summary | `relay-outbound-prompt.sh` (source) | macOS/Linux. On Windows `main()` hands off to `aitools.ps1` at its top (`aitools_win_forward`, PR #162) and returns 1 if the hand-off cannot run, so the source line is never reached |
| `scripts/hh.sh -n` | `relay-outbound-prompt.sh` (source) | macOS/Linux (POSIX guard since PR #162) |
| `scripts/aitools.ps1`, end of the sync | `relay-outbound-prompt.ps1` (dot-source) | Windows (Windows guard) |
| `scripts/hh.ps1 -n` | `relay-outbound-prompt.ps1` (dot-source) | Windows (no guard yet: RFI 38dc-19-1, open) |
| `tests/menus/test-menu-choice.ps1` | `relay-outbound-prompt.ps1` | CI windows job |
| any `.sh` test, hook, packaging script | none | |

Source: `git grep relay-outbound-prompt origin/main -- scripts shared tests packaging .github`.

## 2. The bash `aitools` dependency: before and after

- Before PR #162: Git Bash on Windows ran `scripts/aitools` (dashboard-serve
  hook, a Git Bash terminal, an agent's Bash tool), which sourced
  `aitools-lib.sh` and, at the end of a sync, `relay-outbound-prompt.sh`.
- After PR #162 (f345c41): the hand-off runs first inside `main()`, so on
  Windows the relay source line is unreachable. That is the resolution.
- This mission makes it hold: `relay-outbound-prompt.sh` refuses Windows
  itself (anything else that sources it gets `return 1` and a structured
  error line), and `tests/relay-outbound/test-relay-outbound.ps1` fails if
  the relay source line ever moves before the hand-off, if the hand-off stops
  returning 1 on failure, or if anything before it names the relay script.

## 3. The guards

- `.sh`: canonical `uname -s` POSIX guard; prints
  `[<UTC>] [relay-outbound-prompt] [error] This script is for macOS/Linux. On Windows, use relay-outbound-prompt.ps1 (pwsh).`
  to stderr; `[ "${BASH_SOURCE[0]}" = "$0" ] || return 1`, then `exit 1`.
- `.ps1`: canonical `-not $IsWindows` guard; prints the same structured line
  ("This script is for Windows. On macOS/Linux, use relay-outbound-prompt.sh.")
  with `[Console]::Error`, `exit 1`. ASCII only (5.1 may load it).
  Dot-sourced, `exit 1` ends only the guarded file (probed: the caller goes on
  with `$LASTEXITCODE` 1 and neither function defined); `hh.ps1`, under
  `$ErrorActionPreference = "Stop"`, then ends nonzero at its call, and
  `aitools.ps1` never gets there (its own Windows guard). `exit 1` stays: the
  classifier needs it and a direct run must exit 1.
- Why the guards write their own line instead of loading init-logging: both
  files are sourced into other scripts; init-logging would re-initialize the
  caller's log. Recorded in `.claude/rules/cross-platform.md` "OS guard
  patterns".
- Both match the OS guard classifier (`tests/os-guards`), so the existing
  `test-os-guards.sh` now checks them in CI (the `.sh` refuses Git Bash in the
  windows job; the `.ps1` refuses pwsh in the linux and macos jobs).

## 4. Every Git Bash call in a `.ps1`, and what replaced it

| Call (origin/main 5f962b1) | What it checked | What would be lost without it | Done |
|---|---|---|---|
| `check-pre-commit.ps1` step 2: `& $gitBash -n <staged .sh>` | bash syntax of staged `.sh` files | nothing that CI does not catch on the push: the CI linux and macos jobs ran `bash -n` on `scripts/*.sh`, `shared/hooks/*.sh`, `deploy/*.sh` and the git hook; staged `.sh` elsewhere (`tests/`, `packaging/macos/`, `shared/shell/aliases.sh`) were not in that loop | Removed. Step 2 (.sh) reports SKIP and names CI and `check-pre-commit.sh`. The CI loop now covers every tracked shell script under `scripts/`, `shared/`, `packaging/`, `tests/`, `deploy/` (126 files, extensionless ones included; all parse) and fails on an empty list. Not covered: the 424 archived `.sh` under `.aitools/channel/handoffs/` and `harvesting/` (never run; all parse today), which the old step checked when staged |
| `check-pre-commit.ps1` step 3: `build-deploy.sh` | | | Already retired by PR #154 |
| `check-post-push.ps1` step 2: `bash -n deploy/*.sh` | | | Already retired by PR #154 |
| `check-post-push.ps1` step 4: `& $bashExe scripts/aitools --version` | the CLI entry point answers `--version` | nothing: after PR #162 the bash entry on Windows only hands off to `aitools.ps1`; the hand-off is tested by `tests/aitools-entry/test-win-forwarder.ps1` (CI windows) and the bash entry by `check-post-push.sh` step 4 | Replaced by `pwsh -NoProfile -NonInteractive -File scripts/aitools.ps1 --version`. Also fixed: the old step passed on any output, even an empty one after a failure; it now needs exit 0 and an `aitools <version>` line, and FAILs without pwsh |
| `check-post-push.ps1` step 6: `& $bashExe -n` on `scripts/*.sh`, `shared/hooks/*.sh` | bash syntax of every source `.sh` | nothing: CI runs the same (now wider) check on the same push, and post-push runs after the push | Removed. SKIP naming CI and `check-post-push.sh` |
| `check-pre-push.ps1` step 7: `& $d7Bash build-deploy.sh` | the real dotprofile builds from this branch; the generated `.ps1` resolver consumers dry-run on Windows | the only check of the real dotprofile build from a Windows push: CI has no dotprofile, and `build-deploy.sh` is bash-only | Kept (RFI 38dc-23-1). The "Unrecorded" row narrows to this one call |
| `aitools.ps1` sync: `build-deploy.sh` | | | Approved exception (2026-02-17); out of scope |
| `setup-bash.ps1`: `bash --version` | the managed bash version | it is the setup script of Git Bash itself | Out of scope, unchanged |

The orchestrator's explanation to the commander (three uses: `bash -n`, the
bash entry's `--version`, `build-deploy.sh` in pre-push step 7) is correct;
pre-commit step 3 and post-push step 2 were further Git Bash calls, retired
by PR #154 before this mission started.

## 5. Tests

- `tests/relay-outbound/test-relay-outbound.ps1` (Windows): 20/0.
- `tests/check-no-git-bash/test-check-no-git-bash.ps1` (Windows): 28/0.
- `tests/relay-outbound/test-relay-outbound.sh` (macOS/Linux): CI only. Its
  first version expected a dot-sourcing caller to end with exit 1 and failed
  in CI (run 43658142484); v1.1 checks what pwsh does (probed on Windows with
  a stand-in guard: `after: lastexit=1 defined=False,False`; a caller under
  Stop exits 1).
- Existing suites rerun on Windows: `test-resolve-git-bash.ps1` 15/0,
  `test-menu-choice.ps1` 97/0, `test-win-forwarder.ps1` 45/0,
  `test-logging.ps1` 45/0.
- Mutations (scratch harness, each applied to the worktree file and restored
  byte for byte, after a baseline run of both suites must pass): 14 of 14
  killed: pre-commit 2 runs `bash -n` again;
  post-push 4 ignores the exit code; post-push 4 runs the bash entry via Git
  Bash; post-push 4 without the pwsh check; post-push 6 runs `bash -n`
  again; post-push resolves Git Bash at the top; post-push 6 runs Git Bash by
  literal path; pre-commit starts bash with Start-Process; the `.sh` guard exits when
  sourced; the `.sh` guard exits 0; the `.sh` guard removed; the `.ps1` guard
  removed; the hand-off in `scripts/aitools` falls through; the relay
  script named before the hand-off.
- `check-pre-commit.ps1` (no -Fix): 10 PASS, 7 SKIP, 2 WARN, 0 FAIL.

## 6. Rows changed (old -> new)

- Exemptions, "Entry points sourced or run on any platform": scripts
  `bootstrap.ps1`, `hh.ps1`, `relay-outbound-prompt.sh/.ps1` ->
  `bootstrap.ps1`, `hh.ps1`; the rationale now says the relay scripts carry
  the POSIX and Windows guards (commander's words quoted).
- "Unrecorded" cross-language row: `check-pre-commit.ps1`,
  `check-post-push.ps1`, `check-pre-push.ps1` -> Git Bash ("They check `.sh`
  files (`bash -n`), the bash entry point's `--version`, and the bash-only
  `build-deploy.sh`", `& $bashExe ...`) -> `check-pre-push.ps1` step 7 -> Git
  Bash (build-deploy.sh into a temporary dotprofile copy; no other
  check-*.ps1 runs Git Bash), pending RFI 38dc-23-1,
  `& $d7Bash "$script:RepoRoot/scripts/build-deploy.sh"`.

## 7. Not run

- No `.sh` suite locally (Windows; CI judges macOS and Linux):
  `test-relay-outbound.sh`, `test-post-push-deploy-steps.sh`,
  `test-os-guards.sh`. `bash -n` on every touched shell script passed.
- `check-post-push.ps1` in full (it reads the real HOME's MCP and session
  config); its steps 4 and 6 run through the section tests.

## 8. Open questions

RFI 38dc-23-1: Keep the one Git Bash call left in the Windows checks (check-pre-push step 7, build-deploy.sh)?
`check-pre-push.ps1` step 7 rebuilds the real dotprofile from the pushed branch into a temporary copy and dry-runs the generated `.ps1` resolver consumers. `build-deploy.sh` is bash-only, and you named it cross-platform ("such as build-deploy.sh"); `aitools.ps1` already runs it through Git Bash on every sync (approved 2026-02-17). Without step 7 on Windows, a push from Windows is never checked against the real dotprofile build (CI has no dotprofile; a macOS push runs the `.sh` twin).
Suggest: keep it, and record `check-pre-push.ps1` step 7 under the approved `build-deploy.sh` exception (why: it is the only check of the real build from Windows, and it is the same approved call `aitools.ps1` makes).

Still open from 38dc-19: RFI 38dc-19-1 (guard `hh.ps1` and `bootstrap.ps1`).
With the relay `.ps1` guard, `hh.ps1 -n` under pwsh on macOS/Linux prints
the guard line and ends nonzero at its call to `Invoke-RelayOutboundPrompt`
(reasoned from `hh.ps1`'s `$ErrorActionPreference = "Stop"`; not run).

## 9. Operational learning

- pwsh puts its own directory first on PATH when it starts, so an empty PATH
  set for a child pwsh (ProcessStartInfo) does not hide `pwsh`; set PATH
  inside the child script to test "pwsh not on PATH".
- pwsh writes `AppData\Local\Microsoft\PowerShell\StartupProfileData-*` under
  any USERPROFILE it starts with; a "writes nothing" check must allow it.
- `ProcessStartInfo.ArgumentList` passes each argument as is (no quoting
  trouble with `bash -c '<script>'`); `Start-Process -ArgumentList` does not.
- A guard in a sourced bash file: `[ "${BASH_SOURCE[0]}" = "$0" ] || return 1`
  then `exit 1`, with no `;` between the message and `exit 1`, so the OS guard
  classifier (`[^;]{0,200}`) still sees it.
- In pwsh 7, `exit` in a dot-sourced file ends only that file; the caller
  goes on with `$LASTEXITCODE` set. I assumed the opposite and the `.sh`
  suite I could not run on Windows caught it in CI: probe a language
  behaviour before writing a test that asserts it.
- A mutation harness must first prove the suites pass on the unmutated tree:
  a later comment containing "function " made one case fail on the baseline,
  and every mutation then looked "killed".

## 10. Independent review and what was done

Review: https://github.com/nobul-tech/aitools/pull/167#issuecomment-6886680027
(38dc-23-01-review, CHANGES NEEDED: 1 blocking).

| Finding | Done |
|---|---|
| B1 (blocking): `exit 1` in a dot-sourced `.ps1` does not end the caller; the `.sh` suite and the docs said it did; CI linux and macos failed | Comment in the `.ps1`, RELEASE_NOTES, this report corrected; the `.sh` suite now checks `$LASTEXITCODE` 1 with no function defined, and that a caller under Stop ends nonzero before its next line |
| 1: an installed `aitools` older than v0.77.12, run in Git Bash, ends nonzero once | RELEASE_NOTES item 1 says so |
| 2: the static test missed bash by literal path and Start-Process | Both caught now (AST command names and string constants outside check-lib.ps1); two more mutations, killed |
| 3: "nothing goes unchecked" was not exact | Wording corrected: the archived `.sh` under `.aitools/channel/handoffs/` and `harvesting/` are not listed (never run) |
| 4: an empty list passed the CI step | The step fails on an empty list |
| 5: `check-post-push.ps1` header said PS 5.1 compatible | Now "pwsh 7" |
| 6: step 4 runs the worktree's `aitools.ps1` with the configured repo's library | Not a regression (the bash entry did the same); recorded |
| 7: 126 scripts, not 125 | Corrected |
| 8: `test-relay-outbound.ps1` runs Git Bash to prove the `.sh` refuses Windows | Kept: it is the `tests/os-guards` pattern (a `.ps1` suite runs only the product script under test in Git Bash); recorded for the #159 test-practice doc |
| 9: overlap with PR #166 (check.yml, cross-platform.md/.mdc, test-resolve-git-bash.ps1) | Recorded in the PR follow-ups; whichever merges second keeps both sides |
