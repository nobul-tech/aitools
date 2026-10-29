AUDIT (logging, B): FINDINGS

Runtime logging and script-standards audit of `scripts/setup-user-skills.sh` / `.ps1` at **72589f9** (origin/feature/fanout-skills-legacy), by S3-FanoutImpl-AuditB125. Independent of auditor A (I did not read A's output). **0 blocking, 5 non-blocking.** The PR's new paths log, count and report every failure I could provoke, with the same summary rows in .sh and .ps1. Each finding below is either older code that the fan-out mode now relies on, or a wording or parity detail.

## What was run

- **Commit**: detached worktree at 72589f9 (`git log -1` = "Make setup-user-skills the fallback skills deployer (FO-6)"). No tracked file was modified (`git status --short` is empty).
- **Isolation**: every run had its own fresh HOME under `.scratch/session-a125b/out/<case>/<sh|ps>`, with `USERPROFILE` set to the same directory. `GIT_CONFIG_GLOBAL` was a file inside that HOME, and `AITOOLS_FORCE`, `AITOOLS_DRY_RUN`, `AITOOLS_USER_REPO_PATH`, `AITOOLS_PROFILE_*`, `AITOOLS_LOG_DIR`, `AITOOLS_ENVIRONMENT` and `CLAUDE_CODE_REMOTE` were unset. deploy.log was read from its default location, `HOME/.aitools/logs/deploy.log`. stdin was `/dev/null`. The scripts ran from a fixture copy of the repo: `scripts/` copied from the worktree, a fixture `shared/skills` holding alpha and beta, and a fixture git dotprofile holding `claude/skills/dpskill`. Adopt targets therefore never point into the worktree. The resolver error came from the lib's override stubs (`AITOOLS_PROFILE_SH`/`_PS1`, exit 2), the same approach as `tests/skills-legacy`. I checked that the real `~/.aitools/logs/deploy.log` gained no `setup-user-skills` lines during the audit window.
- **Guard patch**: the scratch copy of `setup-user-skills.ps1` only, `perl -pe 's/-and -not \$IsWindows\)/-and \$false)/'`. The runner aborts if the copy is identical to the original.
- **Runner and analyzer** (kept in the hand-back dir): `a125b-runner.sh` and `a125b-analyze.pl`. The analyzer checks each case for:
  - exit code against the error count;
  - every deploy.log line against `[YYYY-MM-DDTHH:MM:SSZ] [script] [info|ok|warn|error|detail] msg`;
  - error lines against ERROR rows;
  - the sh and ps summary rows, compared after sorting;
  - the sh and ps deploy.log lines, compared with timestamps stripped and paths normalized;
  - files on disk afterwards.
- **Cases (17, each run with .sh and .ps1)**:

| Case | Setup |
|---|---|
| a_fan | `~/.aitools/skills` present with a manifest: harness names, mixed case, a backup, a retired name, one invalid manifest line, and one user-created skill `mine` |
| b_fallback | no `~/.aitools/skills` |
| c_mfunread | manifest chmod 000 |
| c2_dirunread | `~/.aitools/skills` chmod 000 |
| c3_dirnox | `~/.aitools/skills` chmod 444 |
| c4_mfdir | manifest is a directory |
| c5_mflink | manifest is a dangling symlink |
| d_rerrfan | resolver error, fanned out |
| d2_rerrfb | resolver error, fallback |
| e_dryfan | `--dry-run` / `-DryRun`, fanned out |
| e2_dryfb | `--dry-run` / `-DryRun`, fallback |
| e3_envdry | `AITOOLS_DRY_RUN=1`, fanned out |
| f_nodp | fanned out, no dotprofile |
| g_envwarn | `AITOOLS_ENVIRONMENT=bogus`, which logs a warning before the n/a row |
| h_destunread | `~/.claude/skills` chmod 000, fanned out |
| i_harnessfile | `~/.aitools/skills` is a regular file |
| j_emptyharness | empty `~/.aitools/skills` |

- **The PR's own test**: `tests/skills-legacy/test-skills-legacy.sh` under an isolated HOME gave 38 passed, 0 failed, 0 skipped. That includes the MDM build (node present) and the generated MDM `.sh`/`.ps1`. A second run with `AITOOLS_TEST_BASH=/bin/bash` (macOS bash 3.2) also gave 38/0/0.

## Checklist results

| Item | Result |
|---|---|
| Log line format `[ts] [script] [level] msg`, UTC Z, in deploy.log | PASS: 0 malformed lines in all 34 logs. Script names seen: `setup-user-skills` and the resolver child `aitools-profile` |
| Every logged error counted (exit code) and paired with an ERROR row | PASS: every case with an error line exits 1 and every clean case exits 0. Error cases: c, c2-c5: 1 error line + 1 ERROR row; d_rerrfan: 2 + 2 (`dotprofile`, `skills`); d2_rerrfb: 2 + 3 |
| A summary row on every path, including the new `skills` n/a row | PASS: every fanned-out case writes `OK\|skills\|n/a (fanned out from ~/.aitools/skills)`. Fallback writes `claude skills` / `cursor skills` only. It is OK, not WARN and not "skipped" (see N4 for the `<environment>` wording) |
| No silent failures | PASS for the new code. N1 is older code that the fan-out mode now relies on |
| sh vs pwsh parity (rows, deploy.log) | PASS on rows (17/17 identical), exit codes (17/17) and files on disk (17/17). deploy.log line sets are identical in 10 of 17 cases. The differences are error wording only (N3) and the older FAILED footer |

### sh/pwsh parity table

| Case | rc sh/ps | Summary rows (both) | Rows same | deploy.log lines same |
|---|---|---|---|---|
| a_fan | 0/0 | OK skills n/a | yes | yes |
| b_fallback | 0/0 | OK claude skills 3 added; OK cursor skills 3 added (+DETAIL) | yes | yes |
| c_mfunread | 1/1 | OK skills n/a; ERROR skills "reverse discovery skipped: cannot read skills manifest" | yes | error text differs (N3) |
| c2_dirunread | 1/1 | OK skills n/a; ERROR skills "...cannot read ~/.aitools/skills" | yes | error text differs (N3) |
| c3_dirnox | 1/1 | as c2 | yes | error text differs (N3) |
| c4_mfdir | 1/1 | as c_mfunread | yes | error text differs, ps reason misleading (N3) |
| c5_mflink | 1/1 | as c_mfunread | yes | error text differs (N3) |
| d_rerrfan | 1/1 | OK skills n/a; ERROR dotprofile; ACTION; ERROR skills "reverse discovery skipped: dotprofile error" | yes | FAILED footer only |
| d2_rerrfb | 1/1 | ERROR dotprofile; ACTION; ERROR claude skills / cursor skills "not deployed: dotprofile error" | yes | FAILED footer only |
| e_dryfan | 0/0 | OK skills n/a ("Would offer to adopt mine") | yes | yes |
| e2_dryfb | 0/0 | OK claude skills 3 verified; OK cursor skills 3 verified (N5) | yes | yes |
| e3_envdry | 0/0 | OK skills n/a | yes | yes |
| f_nodp | 0/0 | OK skills n/a | yes | yes |
| g_envwarn | 0/0 | WARN skills n/a (N2) | yes | yes |
| h_destunread | 0/0 | OK skills n/a | yes | yes; ps prints an unlogged console error (N1) |
| i_harnessfile | 0/0 | as b_fallback (a regular file at `~/.aitools/skills` is not treated as fanned out) | yes | yes |
| j_emptyharness | 0/0 | OK skills n/a; `mine` found | yes | yes |

## Findings

**N1 (non-blocking; older code that fan-out mode now relies on).** If `~/.claude/skills` cannot be read, reverse discovery quietly does nothing in both languages. In fan-out mode, reverse discovery is the only work this script still does.
- **.sh**: `scripts/setup-user-skills.sh:225` (`for skill_dir in "$dest_base"/*/`) gets no entries. There is no log line and no row, and the exit code is 0.
- **.ps1**: `scripts/setup-user-skills.ps1:266` (`Get-ChildItem -Path $skillsDest -Directory` with no `-ErrorAction Stop`) raises a non-terminating error. It goes to the console only: not deploy.log, not `$errors`, no row. Exit code 0.
- **Rule broken**: script-standards.md "Error handling requirements": a critical read that feeds output needs explicit error handling, and no silent failures.
- **Contrast**: the PR's own `collect_harness_skill_names` (`.sh:290-293`) and `Get-HarnessSkillNames` (`.ps1:225-231`) report the same condition for `~/.aitools/skills` as ERROR `skills`.
- **Evidence (h_destunread)**: both deploy.logs end `[detail] skills manifest: ignored line bad/name<TAB>shared` then `[ok] COMPLETED successfully`. The ps console shows `Get-ChildItem: .../setup-user-skills.ps1:266 ... Access to the path '.../h_destunread/ps/.claude/skills' is denied.`
- **Suggested fix**: add the same `[ -r ] && [ -x ]` check / `-ErrorAction Stop` + try/catch, then log_error + ERROR `skills` "reverse discovery skipped: cannot read ~/.claude/skills".

**N2 (non-blocking; library behaviour).** A warning logged earlier in the run turns the n/a row into `WARN|skills|n/a (fanned out from ~/.aitools/skills)`. In g_envwarn the only warning is `AITOOLS_ENVIRONMENT='bogus' ignored ...`. This comes from write_summary's OK-to-WARN promotion (`scripts/aitools-lib.sh:957`, `aitools-lib.ps1:822`), and both languages agree. A WARN row whose detail says "n/a" is a little confusing. No change is needed in this PR.

**N3 (non-blocking; parity of error wording).** The rows are identical, but the error log lines differ.
- **.ps1 appends the .NET exception**: `.ps1:228` adds `: $_`; `.ps1:240` adds `` `: $_ ``.
- **.sh adds an exit code and perl's reason**: `.sh:307`, `(exit 1): cannot read ...: <reason>`.
- **Misleading reason (c4_mfdir, manifest is a directory)**:
  - .sh says `cannot read ~/.aitools/skills/.aitools-skills-manifest: is a directory`;
  - .ps1 says `Exception calling "ReadAllText" with "2" argument(s): "Access to the path '...' is denied."`.
  - The cause is `Read-HarnessManifest` (`scripts/aitools-lib.ps1:2686`), which does not check for a directory first, unlike `Read-FanoutText` (`aitools-lib.ps1:2724`).
- **Older difference**: the footer reads `FAILED with N error(s). See log: ...` (ps) vs `FAILED with N error(s)` (sh).

**N4 (non-blocking; question for the author).** The n/a row reads `n/a (fanned out from ~/.aitools/skills)`, not `n/a (<environment>)`.
- The `n/a (<environment>)` form in cross-platform.md "Environment branches" is for environment branches. This condition is harness state, not the environment, so `write_environment_skip` does not apply.
- The row follows the rule's intent: category OK, not WARN, not "skipped". It also matches the deploy-paths.md precedent `n/a (no harness rules)`.
- On the error paths, the same tool name gets two rows, `OK|skills|n/a ...` and `ERROR|skills|...` (cases c, c2-c5, d_rerrfan). The test asserts this (`test-skills-legacy.sh:245, 261, 269`), so it is by design. In the end-of-run panel it reads as OK and ERROR for one row name. Writing the n/a row only on the success path is an option.

**N5 (non-blocking; older library code, fallback path, outside this diff).** A fallback dry run reports `OK|claude skills|3 verified` and `OK|cursor skills|3 verified`, while deploy.log says `[DRY RUN] Would create: alpha -> ...` and nothing was written.
- **Cause**: `deploy_managed_file` sets `MANAGED_FILE_RESULT="verified"` (`aitools-lib.sh:2063`). Its dry-run branch (`aitools-lib.sh:2081-2094`) returns without changing that value.
- **Parity**: the same in ps.

**tests/skills-legacy/test-skills-legacy.sh (silent failures only)**: none found.
- Setup steps whose result is not checked (`cp -R` at :109, `git init` at :102, the guard-patch perl at :113 and :337) would make later checks FAIL loudly, not pass.
- Missing tools give an explicit `SKIP` line.
- Without chmod support, the `_parity` empty-rows case prints `SKIP` before comparing.
- One hardening idea (non-blocking): add a `cmp` after the guard patch so an unpatched copy fails clearly instead of surfacing as 8 unrelated failures.

## Not run

- Windows (real `$IsWindows`, NTFS ACLs, Git Bash `chmod`). The .ps1 ran under pwsh on macOS with its guard patched.
- Interactive adopt (`[a]dopt` at a tty). Every run was non-interactive.
- The generated MDM scripts' error paths (only their fallback and fanned-out cases, through the PR's test).
- `setup-user-claude` / `setup-user-cursor` (the fan-out owners).
- `check-*` scripts.
- A static read of build-deploy.sh beyond the 9-line diff.
