# CI platform targeting: every script tested only where it runs

Version 1.0 (2026-11-01). Owner: Session Commander e99e5ef9-9. Branch
`feature/ci-platform-targeting`, one PR (commander: "Branch + PR",
"Everything at once").

**Intent**: **Purpose**: Make CI test each script only on the platforms it is
meant to run on, test every OS guard, and fix every runner warning, so the
Windows code is exercised on Windows and the linux/macOS jobs stop emulating
it. **Scope**: `.github/workflows/check.yml`, the test suites under `tests/`,
the guard bypasses in scripts and tests, a new OS-guard suite, the pty runner
timeout and Windows backend, and the docs that state where tests run. NOT the
setup scripts' behaviour, except bugs that native Windows runs expose (each
fixed in this PR and listed). NOT CI sharding or the per-case pwsh start cost
(follow-up). **Audience**: the commander (review-after) and the agents
converting the suites.

## Commander orders (2026-11-01)

1. "fix it so that linux and macos DO NOT run the windows .ps1 paths under
   emulation"
2. "Have windows run the heavy suite"
3. "fix all other warnings/errors you can see in the logs (deprecated
   runners? update now, node.js version warnings, etc)"
4. "give pty-run.py a 30 second timeout"
5. ".ps1 scripts only run on windows, no need to run them twice on
   linux/mac. linux/mac should only run the scripts meant to run there. the
   override to override the OS guard should be removed. the os guard should
   be tested to ensure it works, ie, the pwsh scripts meant for windows only
   should refuse to run and that functionality should be tested. dont assume
   all ps1 scripts are meant only for windows ... check the guard of each
   script and cross-platform.md. also many .sh files are meant to run on
   linux/mac AND windows, notably the hooks. also, some python scripts,
   notably, ait-harvest.py and others are meant to run on all platforms"
6. Evaluate pywinpty with /tool-eval (Windows pseudo-terminal backend).

## Platform targets (from each script's guard and cross-platform.md)

Inventory 2026-11-01 (guard regex over every tracked script, excluding
`harvesting/`, `.aitools/`, `deploy/`):

| Scripts | Target | Tested on |
|---|---|---|
| 32 `scripts/*.ps1` with the Windows guard | Windows | windows only; their guard is tested on linux and macOS (refusal) |
| 31 `scripts/*.sh` with the POSIX guard | macOS, Linux | linux, macos; their guard is tested on windows (refusal) |
| `shared/hooks/*.sh` (20) | all (cross-platform.md "Hook portability") | linux, macos, windows (Git Bash) |
| `build-deploy.sh`, `build-package.sh`, `bootstrap.sh`, `hh.sh`, `relay-outbound-prompt.sh`, `init-hh-hooks.sh`, `analyze-session.sh`, `aitools-lib.sh`, `check-lib.sh`, `init-logging.sh` | all (exemption table: "each .sh also runs in Git Bash") | linux, macos, windows |
| `scripts/*.py`, `shared/hooks/intelligence-stop.py` | all | linux, macos, windows |
| `aitools-lib.ps1`, `init-logging.ps1` | Windows (dot-sourced only by Windows-guarded scripts; cross-platform.md "PowerShell parity is at the library level") | windows |
| `bootstrap.ps1`, `hh.ps1`, `relay-outbound-prompt.ps1`, `shared/shell/aliases.ps1`, `packaging/windows/*.ps1` | Windows (own headers) | windows |
| `aitools-json.ps1` | any OS (its header: "PowerShell 7 (any OS)") | windows; see open item A1 |
| `check-lib.ps1` and the `check-*.ps1` checks | Windows by guard; `check-lib.ps1` says "pwsh also runs these checks on macOS and Linux" | windows; see open item A2 |

## Design

- **No guard bypass anywhere.** Remove `AITOOLS_PROFILE_TEST_ANY_OS` from
  `aitools-profile.ps1`, `setup-user-config.ps1` and
  `tests/profile/user-init-harness.ps1`; remove the Perl-patched guard-off
  copies in the suites; retire `tests/rules-fanout-cursor/step4-driver.ps1`
  (it runs a script past its guard).
- **Guard tests** (new `tests/os-guards/test-os-guards.sh`): the list of
  scripts comes from the files themselves (guard regex), not a hand list.
  On linux and macos every Windows-guarded `.ps1` run with `pwsh -NoProfile
  -File` exits 1, prints the guard message, and writes nothing under an
  isolated HOME. On windows every POSIX-guarded `.sh` run with Git Bash does
  the same. A script with neither guard must be in the exemption table of
  `.claude/rules/cross-platform.md`, or the suite fails.
- **Parity without running both halves on one machine: golden results.**
  Each parity case's normalized result (exit code, relative file tree,
  summary rows; temp roots replaced by a placeholder, separators and line
  endings normalized) is committed under `tests/<suite>/golden/`. On
  linux/macos the `.sh` run must equal the golden file; on windows the
  `.ps1` run must equal the same file. `AITOOLS_TEST_UPDATE_GOLDEN=1`
  rewrites the files from a linux/macos bash run (the diff is reviewed in the
  PR). Platform-specific results get a `<case>.<platform>` variant.
- **Suite modes.** Each heavy suite selects its language from the platform:
  POSIX runs `sh` cases, Windows (Git Bash) runs `ps` cases natively
  (`pwsh` with Windows paths from `cygpath -m`, `USERPROFILE` set with
  `HOME`). `--bash-only` stays as an alias of the POSIX mode.
- **pty**: `pty-run.py` default timeout 30 s; a timeout prints which command
  and how long. Windows backend through pywinpty if S2-Winpty's /tool-eval
  passes (else interactive cases stay SKIP on windows, reported as such).
- **Runners**: `actions/checkout@v7` (Node 24; v4 targets the deprecated
  Node 20), `macos-15` (macos-14 retired 2026-11-02, brownouts cancelled
  jobs on 2026-10-31), `ubuntu-24.04` (pinned: `ubuntu-latest` moves to 26
  from 2026-10-19; 24.04 is a supported platform), `windows-2022` kept (no
  deprecation notice).

## Batches

| # | Work | Owner |
|---|---|---|
| B1 | Runners, checkout, pty 30 s, remove pwsh steps from linux/macos | commander |
| B2 | Guard bypass removal + `tests/os-guards` | commander |
| B3 | Golden-result helper (shared test lib) + exemplar suite converted end to end, green on all three jobs | commander |
| B4 | Remaining suites converted in parallel, one delegate per 2-3 suites, each on its own branch merged into the feature branch | delegates |
| B5 | Windows bugs found by B3/B4 fixed | delegates / commander |
| B6 | pywinpty backend (if adopted) | commander |
| B7 | Docs: cross-platform.md test matrix, CLAUDE.md tests line, release notes | commander |

## Open items

| # | Question | Suggested answer |
|---|---|---|
| A1 | `aitools-json.ps1` says "any OS"; nothing on macOS/Linux calls it (POSIX uses `aitools-json.pl`). Test it on linux/macos too? | No: test it on windows only, and correct its header to Windows, since every caller is a Windows script |
| A2 | `check-lib.ps1` says pwsh runs the checks on macOS and Linux, but the `check-*.ps1` scripts carry the Windows guard | The guard wins: the PS1 checks are Windows-only; fix the `check-lib.ps1` comment |

## Status

| Batch | State |
|---|---|
| B1-B7 | not started |
