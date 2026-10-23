# S3-M3-UserInit-Review: PR #86 batch 5 (bb43536, tests at f473e55)

**Intent**: **Purpose**: Independent level-3 review of re-key batch 5 (user init on id-keyed profiles) on PR #86. **Scope**: scripts/aitools, scripts/aitools.ps1 (user init block, build-deploy env), scripts/profile-check.js, tests/profile/test-user-init.sh, tests/profile/user-init-harness.ps1, .github/workflows/check.yml at bb43536; f473e55 (test-only: `-b main` on bare remotes and clones) re-checked. NOT the resolver, lib or writer batches. **Audience**: S3-M3-UserInit, S3-M3Lead, Jose.

**Verdict: request changes** -- 0 blockers, 2 majors, 4 minors, 4 nits.

Most of the batch is right, and I checked it by running it: decisions 1, 2 and 6, the menu labels, migrate, dirty-file refusal, push advice, Path 2, Path 3, --force and EOF. The two majors are paths the tests do not cover: a relative `reposPath`, and a machine whose id cannot be detected (`via=config`).

## Majors

**M1. A relative `reposPath` makes user init create the dotprofile, and its GitHub repo, relative to the current directory. Then it fails.**
- Where: scripts/aitools:924-931 (`repos_dir` is used as read; only `~` is expanded), aitools.ps1:1539-1543 (same).
- Probe `relative-repos` (config.json `"reposPath": "repos"`, `--alias spare`, no terminal). Bash, run from the cwd:
  ```
  OK|machine profile|created (spare)
  OK|dotprofile|created            <- Path 3: git init + commit + gh repo create --push
  OK|claude template|created
  ERROR|aitools config|bad arguments
  [setup-user-config] [error] paths must be absolute: repos/aitools-nobul-jose (see --help)
  rc=1
  ```
  The probe ran from my Bash cwd, so it created `repos/aitools-nobul-jose` inside the main aitools checkout. With the gh stub it pushed to a local bare repo; with the real gh it would have created a GitHub repo. I removed the directory after checking that its origin was my probe's remote. pwsh then found that directory (Path 1), so the two shells also gave different rows.
- Decision 3 names "the relative repos path regression", so a relative `reposPath` is a real config state.
- Fix: before choosing Path 1/2/3, make `repos_dir` absolute, or refuse. For example: relative -> `log_error` + ERROR `dotprofile` "reposPath not absolute" + ACTION, exit 1 (or resolve it the way the installer's `absolute_repos_path` does). Same in PS. Add a test case run from a throwaway cwd.

**M2. On a machine whose id cannot be detected (`via=config`), user init deletes the config.json `machineId` that made it resolve. The next run fails.**
- Where: scripts/aitools:680-686 sets `machine_key` from via=config and :994-995 passes `--machine-id`; aitools.ps1:1280-1287, 1607.
- Probe `via-config` (`AITOOLS_PROFILE_TEST_MACHINE_ID=none`, config.json `machineId` = this machine's id-keyed profile):
  - First run: exit 0, `WARN|machine profile|not refreshed (no machine id)`. The writer logs `via=override ... cached machineId "aaaa..." removed (the matched profile "mine" is not keyed by this machine's id)`. config.json `machineId` is now absent.
  - Second run, same fixture: exit 1, `ERROR|machine profile|not registered (no terminal)`, and the resolver warns `config.json machineAlias "mine" not in profiles (mine)`.
- Cause, isolated with probes3.sh (the writer alone, same fixture):
  - `setup-user-config.sh --github-user .. --user-repo-path ..` keeps `machineId` (`via=config`).
  - Adding `--machine-id <key>` removes it (`via=override`).
  - So the argument that user init adds is what breaks it.
- Fix:
  - Do not pass `--machine-id` / `-MachineId` when the match is `via=config`; the writer re-derives it and keeps the cache.
  - Or the writer keeps a cached `machineId` it was given while the id is undetectable. That is a batch 4 contract change: report it to SC.
  - Add the case to test-user-init (two runs).

## Minors

**m1. PowerShell: `Invoke-UserInit` returns the exit code, but it runs child scripts in-process. Their pipeline output would become part of that return value.**
- Where: aitools.ps1:1610 `& $configWriter @writerArgs`, :1627 `& $hookSetup`.
- Before this batch these calls were at script level. Now they are inside a function whose return value becomes `exit (Invoke-UserInitCommand)`.
- Mechanism probe (exit-array.ps1): a function that emits one line and then `return 1` gives `System.Object[] count 2`, and `exit` of it exits **0**. So a hooks abort (2) or a failure (1) would come out as 0.
- The tests replace setup-user-hooks.ps1 with a stub, so the real script's output stream is untested. I could not run it on macOS (Windows guard). Whether it emits anything today: UNVERIFIED.
- Fix: `& $hookSetup | Out-Host` and `& $configWriter @writerArgs | Out-Host`, or `$null = ...`. Optionally `[int]` the value in `Invoke-UserInitCommand` and log a detail line when it is not a single int.

**m2. Every "not registered" path also gets the writer's ERROR and a second ACTION. The writer's ACTION tells the user to run user init while user init is running.**
- Probes `pty-eof-menu`, `pty-force-unreg`, `pty-force-dup` (both shells):
  ```
  WARN|machine profile|skipped                (or ERROR ...not registered (no terminal))
  ERROR|machine profile|no machine match      <- setup-user-config
  ACTION||Run: aitools user init (profiles: laptop, nobul-mac)
  [aitools] [error] user init: setup-user-config failed (exit 1)
  ```
- The panel shows `[ERR] machine profile no machine match` and hides user init's own outcome ("skipped").
- Requirement 6 ("ACTIONs deduped") holds for identical text only.
- Fix options:
  - (a) When `machine_key` is empty, call the writer in a mode that skips the machine part. This needs a writer flag (contract change).
  - (b) Treat the writer's exit 1 as expected when user init already reported the machine row: log at info, no second log_error. Drop the writer's "Run: aitools user init" ACTION when user init has written one.

**m3. A stale `AITOOLS_MACHINE_ALIAS` defeats `--alias`.**
- Probe `env-bogus-with-alias` (`AITOOLS_MACHINE_ALIAS=bogus`, `--alias spare`): `ERROR|machine profile|resolver error`, then the writer's ERROR and ACTION, exit 1. Nothing is registered.
- `AITOOLS_MACHINE_ALIAS=spare` (a new name) also errors, but the comment at scripts/aitools:670 (aitools.ps1:1268) says the env var "is an explicit choice, as --alias is". The design says an unknown override is an error (b, step 1), so the comment overstates. The `--alias` case is the real problem.
- Fix: when `--alias` / `-Alias` is given, run `resolve` (and `migrate`) with `AITOOLS_MACHINE_ALIAS` unset for that call, and log that it was ignored. Correct the comment.

**m4. Test coverage: 8 of 10 applied mutations survive.**
- mut.sh, bash-only, mutating copies of scripts/aitools:

| Mutation | Result |
|---|---|
| drop "not registered = rc 1" | killed (pty-hostname-other) |
| ui_profile_dirty always false | killed (dirty, 6 failures) |
| drop the `machine_owner != this` guard | survived |
| ui_action without dedupe | survived |
| machine.shell hardcoded `pwsh` | survived |
| commit without `-- "$@"` pathspec | survived |
| push without BatchMode/GIT_TERMINAL_PROMPT | survived |
| resolver warnings logged at info | survived |
| v1 migration not committed | survived |
| via=config WARN row removed | survived |
| Path 2 clone rc unchecked | not applied (2 matches) |

- There is no case for v1 migration, Path 2, via=config, `--force` on a terminal, or EOF at a prompt. My probes passed for all of these except via=config (M2), so they work as test templates (probes1/2.sh in my scratch dir).
- The `machine.shell` check cannot fail in bash: `SHELL=/test/bin/pwsh` gives the same value PowerShell hardcodes. Use a distinct `$SHELL` in the bash run and compare bytes with a per-shell expectation for that field.

## Nits

- **n1.** A skip at a prompt exits 1 with only a WARN row and no error line. Example: pty-hostname-other, where the writer succeeds. Minor 3's choice (1) is fine, but add one `log_error "machine profile: not registered"` at scripts/aitools:974 / aitools.ps1:1590 so the exit code has a logged reason.
- **n2.** scripts/aitools:211, 227, 236: `rm -f "$errf"` is unchecked, while `ui_rm_tmp` exists for exactly this.
- **n3.** A missing or crashing writer (exit 127 / a throw) gets a log_error but no ERROR row. The hooks call has one (scripts/aitools:999-1002, aitools.ps1:1611-1615).
- **n4.** When this machine's id cannot be detected, `ui_entries` / `Get-UiEntries` label every profile that has a `machine.id` as "(registered to another machine)", although one may be this machine's. Show "(owner unknown)" when THIS_ID is empty.

## Checked and fine (by run or by reading)

- Req 1: `--alias spare` without a terminal creates `profiles.<id>` (alias-new). `--alias laptop` (another machine's) gives ERROR, exit 1, and the other profile stays byte-identical. On a pty it asks y/N, then passes `--allow-duplicate-alias`; declining gives WARN and exit 1. `[n]` + another machine's alias also asks (pty-new-dup). `--force` on a pty never asks.
- Req 2: one line per entry point; both values tested.
- Req 3: `--claim KEY` from the menu. `[-] laptop (registered to another machine)`, also `(suggested, registered to another machine)`. Menus identical in both shells.
- Req 4: migrate runs before resolve, with backup, commit and push. The remote-ahead case gives one deduped `git pull --rebase` ACTION and exit 0 (legacy-ahead).
- Req 5: Path 1 scaffold committed and pushed. Path 3 pushes through `gh repo create`, also with `--force` (no [Y/n]).
- Req 6: the summary file is created before the block and shown before return, in both shells.
- Req 7: `--machine-id` only when owner = this. Apart from M2, correct.
- Req 8 (read): `env AITOOLS_USER_REPO_PATH=... bash build-deploy.sh` (bash, `cygpath -m` on Windows); PS sets and restores it in try/finally with `\` -> `/`.
- Req 9: minors 4, 5 (dirty refused / not refreshed), 6, 7, 8 (Path 2 identity from profile: remote commit author `Jose <jose@example.com>` with no git identity on the machine). The CLAUDE.md scaffold commit has no `|| true`.
- Req 10: profile-check.js matches keys and legacy `machine.id` case-insensitively. The v1 migration writes 2.2, keeps `cursor`, and registers under the id. No config.json write.
- EOF at the menu and at the confirm: warns and defaults, never blocks. Exit 2 only from the hooks abort. No sed/awk in added lines. `/bin/bash -n` clean.

## What I ran (macOS, isolated HOMEs under mktemp, injected ids, local bare remotes, gh stub)

- `bash tests/profile/test-user-init.sh`: 150 passed, 0 failed. `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/profile/test-user-init.sh`: 150/0, at bb43536.
- f473e55 only changes the test (`-b main`) and was not re-run separately.
- probes1.sh, probes2.sh (pty), probes3.sh (writer attribution), mut.sh (mutations), exit-array.ps1. All are in `.scratch/session-UIRev/` of the m3rekey worktree.

## Not run

- Windows / Git Bash (the pwsh branch of `ui_profile_run`, cygpath), the real setup-user-hooks.ps1 (m1), real gh, `aitools` sync with build-deploy (req 8 by reading only), check-pre-commit / check-pre-push.

## Process note

- My relative-path probe inherited the Bash tool's cwd, the main checkout, and wrote `repos/` there. I removed it after confirming its origin was the probe's bare remote. `git status` of the main checkout is clean again.

## INCIDENT markers (not filed)

- `INCIDENT:` the isolated-HOME rule (packet section 5, #86) does not cover the cwd. A relative path in a fixture's config.json (or any relative path a script takes from config) writes into the agent's cwd, here the main checkout. Probe and test scripts should `cd` into scratch first.
- `INCIDENT:` there is no harness rule that PowerShell functions returning an exit code must not run child scripts in-process without discarding their output stream (m1). Success-stream output turns `exit (Fn)` into exit 0.
