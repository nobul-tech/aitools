# S3-M3-Install report: PR #79 Review3 fixes + Step 5 / writer logging audit

1. All five Review3 #79 minors and three logging-audit findings are fixed in 69b6420. The reviewer's M1, m1 and m2 are fixed in a second commit.
   - #79 had already been merged at cc597ec before my push, so both commits ship in a fix-forward PR from main: branch fix/m3-b3b-installer-review3.
   - Details are under "Review and fix-forward" below.
2. Tests pass:
   - test-config: 112/0 with pwsh parity, 67/0 under bash 3.2.
   - test-profile: 319/0, and 231/0 under bash 3.2.
   - test-logging: sh 24/0 (also under bash 3.2), ps 15/0 (5 skipped).
3. Writer interface: unchanged, apart from where the dry run puts its temp file and one new ERROR row. See "Interface" below; the same table is in the PR #79 body.
4. Reviewer: S3-M3-Install-Review. Its verdict is under "Review" below.
5. Not run: the full installer (incident #89), Windows, and the Git Bash forwarding path.

## Fixes (commit 69b6420)

**m1: the writer's log lines are missing from deploy.jsonl.**
- Cause: the writer is a child process (bash) or its own script scope (PowerShell), so the installer's JSONL `log` override never applied to it.
- Fix: the installer now relays the writer's output. The relay has to live in the installer because the lib is off-limits and the PowerShell writer redefines `Log` itself.
- bash (`run_config_writer`, `relay_child_log` in scripts/aitools-install.sh):
  - Captures the writer's stdout.
  - Prints each line.
  - Strips colour codes, parses `[ts] [script] [level] msg`, and writes a `deploy.jsonl` record with the writer's own ts, script and level.
- PowerShell (`Invoke-ConfigWriter`, `Send-ChildLogLine` in scripts/aitools-install.ps1): the same, using `& $writer @args 6>&1 | ForEach-Object`. The call stays in-process.
- deploy.log is not written twice: the writer has already written it.
- Found while fixing this: the bash installer's JSONL override did not escape messages, so any message with a quote produced an invalid JSONL line, and the writer's change lines contain quotes. `jsonl_write` now escapes backslash, quote and tab, and drops CR. The PowerShell installer now writes keys in the same order as bash (`[ordered]`).

**m2: the writer's warnings are not counted.**
- The relay counts each `warn` line from the writer in the installer's WARNINGS (`$script:warnings` in PowerShell).
- Errors are not counted line by line. A writer with errors exits 1, which becomes one installer error, as before.

**m3: a relative repos path is rejected by the writer.**
- The old Step 5 (9462ed0^) wrote the relative string as given, and Step 3's `mkdir -p` created the directory relative to the current directory.
- New helpers: `absolute_repos_path` / `Get-AbsoluteReposPath`. The PowerShell one uses `[IO.Path]::GetFullPath(p, (Get-Location).Path)`.
- Step 3 uses them to make the path absolute, relative to the current directory, and logs the conversion. This covers the prompt answer, the flag and an old config value.
- The writer's guard against relative paths is kept.

**m4: the validator comment.**
- The comment now says `validate_json_config` / `ValidateJsonConfig` stay in the installers. B2 (#80) kept them out of aitools-lib, as its commit body states: "validate_json_config stays in the installers".
- In bash, the `$DRY_RUN && log` line no longer sits between the comment and the function.

**m5: the dry run writes a file.**
- A dry run now merges into a system temp location: `$WORK_DIR/config.json` (bash) or `GetTempPath()/aitools-config.<pid>.json` (PowerShell).
- A dry run also no longer creates `~/.aitools`.
- Probe: `--dry-run` on an empty HOME created nothing in HOME in either shell. pwsh's own `.cache` / `.local/share/powershell` files appear, written by the pwsh host, not the writer (`.scratch/session-Install/probe-dry.sh`).

**Logging audit (commander decision 3).** Writer paths that could end without a summary row, now fixed:
- `WORK_DIR=$(mktemp -d)` was unchecked: under `set -e` a failure exited silently. It is now ERROR "temp dir failed".
- `mkdir -p ~/.aitools` was unchecked (bash) and `New-Item` was non-terminating (PowerShell). Both are now ERROR "write failed", and the script exits 1.
- The double-slash check was `perl | perl -ne 'print, exit'`. With many matches, the first perl could get SIGPIPE; pipefail then failed the assignment and `set -e` exited silently, in exactly the error case. It is now a single perl call with its exit code checked.
- Audited and left as is:
  - Every other suppression is commented and result-checked (setup-user-config.sh: the cfg_get, salvage, `pj type` and `pj json` reads).
  - Every exit path after logging_init writes a summary row, except the OS guard (canonical pattern) and `--help`.
  - Levels match reference/logging.md: info, ok, warn, error, detail.

## Tests added (tests/profile/test-config.sh)

- **C8b:** a dry run with `~/.aitools` read-only must succeed with "dry-run: would update".
  - Against the old writer (stash probe) it fails with exit 1 and "merge failed": `.scratch/session-Install/test-config-oldwriter.log`.
- **Installer helpers, bash and PowerShell.** The "install log helpers" block is extracted from each installer and run against the real writer under the isolated HOME:
  - Step 3: a relative path becomes absolute; an absolute path is unchanged.
  - Step 5, with the C13 unregistered-profile fixture, which warns:
    - config.json is written from Step 3's absolute answer;
    - every deploy.jsonl line is valid JSON (JSON::PP);
    - the writer's lines are in deploy.jsonl;
    - the installer's warning count equals the writer's warn lines (2);
    - the writer's lines are shown on the console.
  - A failing writer counts as 1 installer error, and its ERROR "bad arguments" row is kept.

## Verification

- Syntax:
  - `bash -n` (bash 5.3 and /bin/bash 3.2) on aitools-install.sh, setup-user-config.sh and test-config.sh: clean.
  - pwsh parser on both .ps1 files: clean.
  - Script: `.scratch/session-Install/syntax.sh`.
- Suites: `.scratch/session-Install/run-suites.sh` sets HOME and AITOOLS_LOG_DIR to the scratch dir. Logs are in `.scratch/session-Install/suites/`.
- check-pre-commit:
  - Step 6 fails: the known harvesting file is 100644.
  - Step 20 fails: the pre-existing dead `reference/tool-support-decision-tree.md` refs in aitools-profile.* and the tool-adopt skill, fixed on main by #78.
- check-pre-push: step 7 fails: the known stale dotprofile deploy/.

## Interface: setup-user-config.sh / .ps1 (S3-M3Lead request, commander decision 2026-10-22)

- **Arguments:**
  - `--repos-path` / `-ReposPath` and `--repo-path` / `-RepoPath`: absolute paths only.
  - `--drives-json` / `-DrivesJson`: a JSON array.
  - `--github-user` / `-GithubUser`.
  - `--user-repo-path` / `-UserRepoPath`: absolute.
  - `--machine-alias` / `-MachineAlias`.
  - `--dry-run` / `-DryRun`.
  - `--force` / `-Force`: accepted, no effect.
  - `--help` / `-Help`.
  - With no arguments, it re-derives githubUser, userRepoPath and machineAlias from profile.json.
- **Environment variables:**
  - `HOME`.
  - `AITOOLS_DRY_RUN=1`: same as dry run.
  - `AITOOLS_LOG_DIR`, `AITOOLS_SUMMARY_FILE`.
  - `AITOOLS_ENVIRONMENT`: read by the lib.
  - Read by the resolver: `AITOOLS_USER_REPO_PATH` (used for this run only, never saved; test C11), `AITOOLS_MACHINE_ALIAS`, `AITOOLS_PROFILE_FILE`.
  - Tests only: `AITOOLS_PROFILE_TEST_MACHINE_ID`, `AITOOLS_PROFILE_TEST_HOSTNAME`, `AITOOLS_PROFILE_TEST_ANY_OS`.
  - Source: grep of AITOOLS_* in setup-user-config.* and aitools-profile.*.
- **Files read:**
  - `~/.aitools/config.json`.
  - The dotprofile `profile.json`, through `aitools-profile.sh/.ps1 derive-config`.
  - `aitools-json.pl` (bash) or `aitools-json.ps1` (PowerShell), next to the writer.
- **Files written:**
  - `~/.aitools/config.json`, by this path: a temp file beside it, then validation, then a backup to `config.json.bak.<ts>`, then a move into place.
  - A dry run writes no config, temp file or backup. With the default AITOOLS_LOG_DIR, `~/.aitools/logs/deploy.log` is still created, because logging_init creates the log dir.
- **Summary rows (tool name "aitools config"):**
  - OK: created, updated, verified, "dry-run: would update".
  - WARN: "rebuilt (was invalid)". An OK row also becomes WARN when the run logged a warning.
  - ERROR: bad arguments, perl not found (bash only), resolver missing, temp dir failed (new), write failed, derivation failed, merge failed, validation failed, missing bootstrap values.
  - DETAIL: "<key> updated".
- **Other rows:** ERROR "profile.json" "invalid (see log)", ERROR "machine profile" "no machine match", and ACTION rows.
- **Log sinks:**
  - deploy.log.
  - The console: stdout in bash, Write-Host in PowerShell.
  - Not deploy.jsonl. A caller that wants JSONL and warning counts relays the output, as `run_config_writer` / `Invoke-ConfigWriter` now do.
- **Exit codes:** 0 when done (with or without warnings), 1 on any error, 0 for help. Never 2.
- **Interaction:** never prompts, so it is safe for deploy-harness to call.
- **Changed versus the #79 head I started from (cc597ec):**
  - Where the dry-run temp file goes.
  - The new "temp dir failed" row.
  - "write failed" now also covers "could not create ~/.aitools".
  - Nothing else changed.

## Review and fix-forward

**Merge timing.** PR #79 was merged by nobul-jose at 2026-10-22T20:46:29Z, at cc597ec (merge commit 15cc56a). That was before I pushed 69b6420 to its branch.
- Source: `gh pr view 79 --json mergedAt,mergeCommit,headRefOid`.
- So none of these fixes are on main.
- Following the /delegate skill ("If a delegate's PR merged with an unresolved review, launch a fix-forward from the base branch"), I opened a fix-forward PR from origin/main. Its branch, `fix/m3-b3b-installer-review3`, carries both commits, cherry-picked.
- No file in scope changed on main between cc597ec and origin/main (`git diff --stat`), so the cherry-picks applied cleanly.

**S3-M3-Install-Review verdict:** changes requested, posted as a comment on #79. Counts: 0 blockers, 1 major, 3 minors, 3 nits.
- Review: https://github.com/nobul-tech/aitools/pull/79#pullrequestreview-5620818197
- Verdict file: `../S3-M3-Install-Review/S3-M3-Install-Review-verdict.md`

| Finding | Status |
|---|---|
| **M1** The writer's warnings were counted N+1: its footer `COMPLETED with N warning(s)` is logged at warn. The test asserted the wrong number. | Fixed in commit 2 (09e5bdd on the old branch, 2f189a0 on the fix-forward). Both relays skip the footer. The test now asserts the installer's count = the writer's footer N = its warn lines minus the footer (1 for C13). I verified the cause in the code: the writer's exit footer calls `log ... "warn"`. |
| **m1** bash `jsonl_write` left other control characters in the record. | Fixed: newline is escaped, every other `[[:cntrl:]]` character is dropped. Tested with quote, backslash, tab, newline, \001, ESC and CR, in both shells. |
| **m2** `absolute_repos_path` did not normalise: a run from / gave `//repos`; `../` was kept. | Fixed: the path is resolved after mkdir with `cd + pwd`. Tested `../home/repos`, and `tmp` from / giving `/tmp`, in both shells. |
| **m3** The relay helpers exist only in the installers; deploy-harness would need a third copy. | Not changed: a lib change is out of scope. Follow-up below. |
| **nit 1** The dry-run wording: the default log dir still creates `~/.aitools/logs/deploy.log`. | The wording is corrected in the Interface section below and in the PR body. |
| **nit 2** The bash relay buffers the writer's output until it exits. | Accepted: the writer is short and never prompts. |
| **nit 3** The bash 3.2 test ran the writer under PATH bash. | Fixed: `run_config_writer` uses `${BASH:-bash}`. |

After the fixes:
- test-config: 118/0 with pwsh parity, 70/0 under bash 3.2.
- test-profile: 319/0 and 231/0.
- test-logging: sh 24/0 (also under 3.2), ps 15/0.
- All run on the fix-forward branch.

The independent review covered 69b6420 only. Commit 2 has not had an independent review: I do not have a second reviewer in this run.

## INCIDENT markers (not filed)

- INCIDENT: the bash installer's JSONL `log` override did not JSON-escape messages (scripts/aitools-install.sh at 9462ed0, lines 136-137). Any message containing `"` or `\` produced an invalid deploy.jsonl line. The same unescaped override is reproduced as the canonical pattern in reference/script-standards-detail.md:125-131. That file is protected, so it is not edited here; a suggested fix is drafted under Open questions. Fixed in the installer in 69b6420.

## Open questions (with suggested answers)

1. reference/script-standards-detail.md:125-131 shows the unescaped JSONL override as the canonical pattern. Should it be updated to call `jsonl_write`?
   - Suggested: yes, as a protected-file draft in a later batch. It is out of scope here.
2. Should the writer emit JSONL itself, so that deploy-harness gets JSONL without relaying?
   - Suggested: no. Relaying keeps the writer's interface unchanged. A lib-level JSONL sink (for example an `AITOOLS_LOG_JSONL` env var honoured by `log`) would be cleaner, but it is a lib change owned by S3-M3-LibFix or a later mission.
3. The relay helpers are copied in both installers, and deploy-harness would need a third copy (review m3).
   - Suggested: move `jsonl_write`, `relay_child_log` and `run_config_writer` (and their .ps1 twins) into aitools-lib after #80 merges, owned by the lib mission. Until then, deploy-harness copies the fixed version from this PR.
4. A derivation failure produces two rows for "aitools config": ERROR "derivation failed", then the merge row (for example OK "updated"). This is pre-existing and not flagged by Review3.
   - Suggested: leave it. The merge still writes the bootstrap keys. Revisit when deploy-harness consumes the rows.

## Delegates used

- S3-M3-Install-Review (general-purpose, no isolation): an independent review that posts its verdict on PR #79.
