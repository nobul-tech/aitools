# S3-M3-UserInit report: user init on id-keyed profiles (re-key batch 5)

**Intent**: **Purpose**: Record what mission S3-M3-UserInit shipped on PR #86 (re-key batch 5, decisions 1-3, 5, 6, the Review3 #82 UI findings), how it was verified and reviewed, and what is left open. **Scope**: scripts/aitools, scripts/aitools.ps1, scripts/profile-check.js, tests/profile/test-user-init.sh, tests/profile/user-init-harness.ps1, .github/workflows/check.yml. NOT the resolver, lib or writer (batches 1-4), NOT build-deploy.sh. **Audience**: S3-M3Lead, the reviewer, Jose.

## Summary

- PR: https://github.com/nobul-tech/aitools/pull/86 (`feature/m3-rekey`).
- Commits:
  - bb43536 batch 5;
  - f473e55 test fix (bare remotes on `main`; CI's default branch is master);
  - the review-fix commit that carries this report.
- **Found first:** user init did not run on this branch. Both entry points still called the pre-LibFix helper names (`_aitools_profile_run`, `Invoke-AitoolsProfile`, `$script:ProfileRc`).
- **The lib runner rejects register and migrate.** `_aitlib_profile_run` / `Invoke-AitLibProfile` rewrite an exit 0 or 1 without a `via` line to 2. `register` and `migrate` print no `via` line, so through the lib every register reads as an error (`.scratch/session-UInit/probe-librunner.sh`: `rc=2 ... error resolver exited 0 without result lines`). User init therefore uses its own runner: `ui_profile_run` / `Invoke-UiProfile`.

## Behaviour per required item

1. **`--alias <new>` without a terminal** creates `profiles.<id>`. An alias used by another machine's profile (resolver exit 4):
   - without a terminal: ERROR "alias used by another machine", exit 1;
   - on a terminal: a y/N confirm, then `--allow-duplicate-alias`;
   - the other machine's profile is never written.
   - `--alias` naming a profile that no machine owns claims it (`--claim`).
   - A stale `AITOOLS_MACHINE_ALIAS` is ignored when `--alias` is given.
2. **Decision 2 switch:** one line per entry point, `AITOOLS_REGISTER_CACHED_ALIAS_SILENTLY=0` (scripts/aitools) and `$script:RegisterCachedAliasSilently = $false` (aitools.ps1), with a comment citing the decision. At 0, via=alias goes to the menu, or ERROR without a terminal. At 1 it claims silently. Both values are tested.
3. **Menu:**
   - Unclaimed legacy profiles are numbered; picking one passes `--claim KEY`.
   - Another machine's profiles are shown `[-] <alias> (registered to another machine)`, or `(suggested, registered to another machine)` when the hostname suggests them, and cannot be picked.
   - `(owner unknown ...)` is shown when this machine's id cannot be detected.
   - The bash and PowerShell menus are identical (pty compare).
4. **`migrate`** runs before resolve (backup, commit, push), so the writer's "re-keys machine profiles" ACTION clears (test `migrate`: no such row).
5. **Scaffold:**
   - A missing profile.json (Path 1, Path 2) is created by `register --create` with the identity from gh/git (asked on a terminal), committed and pushed.
   - Path 3 commits, then creates and pushes the private GitHub repo (asked on a terminal, default yes). The test checks that profile.json reaches the remote.
   - No `meta.intent` is written (TODO(PR #96) in both scaffolds).
6. **Decision 3 (summary):**
   - The summary file is created before the user block and shown before returning (`user init` branch / `Invoke-UserInitCommand`).
   - Every path writes a row, and ACTIONs are deduped (`ui_action` / `Write-UiAction`).
   - Exit codes: not registered at the end = 1 (with an error line), abort in the hooks menu = 2, otherwise 0.
7. **Writer:** gets `--machine-id` / `-MachineId` only for this machine's own key.
   - Another machine's key is refused (ConfigKey Q3).
   - A key that only config.json vouches for (`via=config`) is not passed, so the writer keeps the cached `machineId` (review M2).
8. **AITOOLS_USER_REPO_PATH:** both entry points resolve the dotprofile (`resolve_user_repo_path` / `Resolve-UserRepoPath`), pull it, and pass it to build-deploy with forward slashes, scoped to that one call (`env ...` / try-finally restore).
9. **Review3 #82 minors:**
   - (1) via=alias goes to the menu only per the switch.
   - (3) One outcome gets one exit code (above).
   - (4) A rejected push gets "git pull --rebase, then git push in <dir>". Without a terminal git cannot prompt (`GIT_TERMINAL_PROMPT=0`, `ssh -o BatchMode=yes` unless `GIT_SSH_COMMAND` is set).
   - (5) Uncommitted profile.json edits are never committed: an unregistered machine is refused (ERROR); a registered one is not refreshed (WARN).
   - (6) `machine.shell` is pwsh on Windows from both entry points and `$SHELL` on macOS/Linux.
   - (7) The dead PS `--alias` scan is removed.
   - (8) The Path 2 clone and `git config` results are checked.
   - Also: the CLAUDE.md scaffold commit has the identity fallback and no `|| true`; a relative `reposPath` is refused (review M1); prompts never block without a terminal.
10. **profile-check.js and the v1 migration:**
    - profile-check.js reports `machineId` and checks it against profile keys; a legacy profile is found by `machine.id`. `machineAlias` is kept.
    - The v1->v2 migration converts the identity, keeps the other machines as claimable `machine1...` profiles, and registers this machine through `register` (id key).
    - It commits profile.json only and no longer writes config.json (decision 7).

## Tests (tests/profile/test-user-init.sh, new; in CI on macOS and Linux)

- Setup: isolated HOME per case, a throwaway aitools copy (setup-user-hooks stubbed), a gh stub (api, view, clone, create), local bare remotes, injected machine id and hostname. Each run starts from the fixture directory.
- How it runs: the bash entry point runs whole. PowerShell runs the BEGIN/END user-init block of aitools.ps1 through `user-init-harness.ps1`.
- What each case checks: bash and PowerShell exit codes, summary rows, profile.json bytes and remote commits.
- Cases: alias-new (+rerun), alias-other, unregistered-notty, alias-claim, migrate, scaffold-path1, scaffold-path3, cached-alias-0/1, dirty, dirty-registered, push-rejected, hook-abort, relative-repos, via-config (+rerun), env-alias-stale, path2, v1-migrate, profile-check, and on a pty: claim, hostname-other, dup-confirm, dup-decline, --force.
- Results:
  - 200/0 under bash 5 + pwsh, and 200/0 under /bin/bash 3.2 + pwsh with a global gitconfig whose defaultBranch is master (the CI condition).
  - test-profile 689/0 (3.2: 498/0), test-config 190/0, test-lib 209/0, logging sh 24/0 (bash 5 and 3.2) and ps 15/0, managed-files sh 42/0 and ps 24/0.
  - `bash -n` (5, 3.2), the pwsh parser and `node --check` are clean.
- Checks:
  - check-pre-commit: FAIL step 6 (known); WARN step 11 (the live dotprofile has someone else's uncommitted change; not touched).
  - check-pre-push under an isolated HOME: 0 FAIL.
- CI on f473e55: all green. CI on the review-fix commit: see the final hand-back.

## Review

- **Reviewer:** S3-M3-UserInit-Review (independent, no isolation, not given this report).
- **Review:** https://github.com/nobul-tech/aitools/pull/86#pullrequestreview-5622357229 ; file `../S3-M3-UserInit-Review/S3-M3-UserInit-Review-pr86-batch5.md`.
- **Verdict on bb43536:** request changes. 0 blockers, 2 majors, 4 minors, 4 nits.
- **Fixed in the review-fix commit:**
  - M1 (relative reposPath refused);
  - M2 (no `--machine-id` on via=config);
  - m1 (child scripts' output goes to `Out-Host`; `Invoke-UserInitCommand` takes the last value and logs stray output);
  - m3 (`--alias` beats `AITOOLS_MACHINE_ALIAS`; comment corrected);
  - m4 partly (cases for v1 migration, Path 2, via=config, --force, relative path, stale env);
  - n1 (error line on skip), n2 (errf removal checked), n3 (ERROR row for a failed writer), n4 (owner unknown).
- **Not fixed:**
  - m2: the writer still adds its own "no machine match" ERROR and ACTION when user init leaves the machine unregistered. Fixing it needs a writer flag (batch 4 contract); open question 1.
  - m4 rest: the mutations of the ACTION dedupe, the BatchMode env, the pathspec and the info-level routing still survive.
  - The `machine.shell` test cannot tell `$SHELL` apart from pwsh (both write pwsh, for byte parity).

## Not run

- Windows / Git Bash: the pwsh branch of `ui_profile_run` (cygpath arguments, UTF-8 output), aitools.ps1 end to end, the real setup-user-hooks.ps1.
- The real gh. `aitools` sync with build-deploy (req 8 checked by reading only).
- The live dotprofile was never read or written.

## INCIDENT markers (not filed)

- `INCIDENT:` the lib runner (`_aitlib_profile_run` / `Invoke-AitLibProfile`) treats a `register` or `migrate` exit 0 as a resolver crash: it requires a `via` line, and those commands print none. Owner: lib (aitools-lib.*). Fix: also accept a `result` line.
- `INCIDENT:` both entry points called removed pre-LibFix helper names after LibFix merged into #86, and no test ran user init (now covered by test-user-init.sh).
- `INCIDENT:` (reviewer) the isolated-HOME rule does not cover the cwd: a relative path from config.json writes into the agent's cwd.
- `INCIDENT:` (reviewer) no harness rule says that a PowerShell function returning an exit code must keep in-process child scripts out of its output stream.
- `INCIDENT:` `.ps1` files are checked out with CRLF (`eol=crlf`): line-anchored grep / perl patterns in tests silently miss them (found while testing the decision-2 switch).

## Open questions (with suggested answers)

1. **Writer noise when the machine stays unregistered (review m2).** Suggested: a writer flag `--no-machine` / `-NoMachine` (batch 4 contract change, owner of setup-user-config) that skips the machine-profile part. User init would pass it when it already wrote the machine row.
2. **Path 3 creates the private GitHub repo without asking when there is no terminal** (needed for "the scaffold reaches the remote"). Suggested: keep it. It only happens in Path 3 (no local dotprofile and no GitHub repo), and the repo is private and named `aitools-<user>`.
3. **Lib runner fix (INCIDENT 1).** Suggested: the lib owner accepts `result` lines; user init can then drop its own runner.

## WRITE_BLOCKED

None. Several Bash calls were refused by standing-order-guard (`;`, `||`, `&&`, `cat`, `tail`); they were moved into scratch scripts or Read, as prescribed.

## Delegates

- S3-M3-UserInit-Review (general-purpose, no isolation).
