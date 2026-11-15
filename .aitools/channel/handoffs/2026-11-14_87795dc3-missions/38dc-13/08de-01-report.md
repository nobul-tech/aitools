# 08de-01 report: verification of e9d6-22's pre-commit steps 3-10 and post-push deploy-steps ports (v1.0)

Verifier 08de-01, delegated by 38dc-27 (08de). Worktree `W` =
`C:\Users\jdpal\repos\aitools\.claude\worktrees\38dc-13`, branch
`fix/38dc-13-windows-ci-ps1-only` at `eaf261a` (origin/main with PR #167 merged in).
Verification only: no file under `tests/` or `scripts/` was edited, nothing was committed
or pushed. Scratch: `W\.scratch\session-08de-01\` (logs named below).

## Verdict

**No blocking findings.** Both `.ps1` harnesses are green, and each of their 50 checks
was made to FAIL by at least one minimal mutation. Both `.sh` harnesses keep every
`.sh`-twin case, run no `.ps1`/pwsh case of the `.ps1` twin, carry the test-suite guard
verbatim and refuse Git Bash. Four non-blocking findings follow (N1-N4).

## Counts

| Run | Result | Log |
|---|---|---|
| `pwsh -NoProfile -File tests/check-pre-commit/test-pre-commit-steps3-10.ps1` | 40 passed, 0 failed, 0 skipped, exit 0 (9 s) | `run-v-pc-base.log` |
| `pwsh -NoProfile -File tests/check-post-push/test-post-push-deploy-steps.ps1` | 10 passed, 0 failed, 0 skipped, exit 0 (2 s) | `run-v-pp-base.log` |
| `pwsh -NoProfile -File tests/os-guards/test-os-guards.ps1` | 68 passed, 0 failed, 0 skipped (windows, pwsh 7.6.10); includes `ok tests/check-post-push/test-post-push-deploy-steps.sh refuses windows` (log line 47) and `ok tests/check-pre-commit/test-pre-commit-steps3-10.sh refuses windows` (line 49) | `run-v-osg.log` |
| `bash -n` on both `.sh` | rc 0, rc 0 | (Bash tool) |
| Refusal, `bash tests/<suite>.sh` in Git Bash, no spoofing | both: rc 1, stdout 0 bytes, stderr exactly `This script is for macOS/Linux. On Windows, run tests/<dir>/<suite>.ps1 with pwsh.`; `git status --porcelain` line count unchanged (2 before and after; both lines are other agents' handoff edits) | `refusal.sh` output |
| File hygiene | both `.sh`: index 100755, 0 CR bytes; both `.ps1`: 0 CR bytes, 0 non-ASCII bytes | `refusal.sh` output |
| `-Help` | both `.ps1` print the header through the `Usage:` line | (Bash tool) |

AITOOLS_LOG_DIR pointed at `W\.scratch\session-08de-01\logs-<tag>` for every run.

## Mutation proofs

Driver: `W\.scratch\session-08de-01\mutate.ps1`. Each mutant is a copy of the script
under test in `W\.scratch\session-08de-01\mut\<Id>\`. It gets exactly one edit (or two,
for PC12), and the driver refuses an edit whose old text does not occur exactly once.
The copy is passed in through the harness override variable: `PRE_COMMIT_PS1`,
`PRE_COMMIT_SH`, `POST_PUSH_PS1` or `POST_PUSH_SH`. `TEST_RUN_TWIN=none` is set unless
the mutant targets the run case.

A row passes ("caught") when the suite exits 1 and every target check prints `FAIL`.
After the runs, the driver confirmed the 8 real files byte-identical by SHA-256: the 4
scripts under test, the 2 `.ps1` and 2 `.sh` harnesses (`real files byte-identical
after the mutation runs: True (8 files)`). Each mutant's full output is in `mut-<Id>.log`.

Correction during the work: my first pass built 9 mutants (PC3, PC3n, PR3a, PR3b, PR4,
PR5, PP3a, PP3b, PP8) with `@($S3, '...; ' + $S3)`. In a PowerShell array literal the
comma binds tighter than `+`, so the edit also dropped the `StepSkip` call. Their target
checks still failed for the intended reason, a marker, HOME or dotprofile file being
present (`mut-PR3b.log` of that pass shows `=> ... ./m6b-build-ran`). But the extra
FAILs made them non-minimal. I wrapped the edit text in parentheses
(`fix-mutate.pl`), guarded PR3b's `ResolveGitBash` call with
`Get-Command ResolveGitBash` so the section driver does not throw, and re-ran the 9
mutants (`mutate-rerun.ps1`). The table shows the re-run results.

### Pre-commit steps 3-10 (`.ps1` harness, 40 checks)

| Id | Mutation (copy only) | Exit | FAILs | Target checks (all FAILed) |
|---|---|---|---|---|
| M0-pc | control: unmodified copy via PRE_COMMIT_PS1, run case on | 0 | 0 | none (40/0/0) |
| PC1 | `# 3. Build freshness` -> `# 3) Build freshness` | 1 | 3 | ps1: the step 3 and step 10 sections were found |
| PC2 | `throw 'm08';` before the step 10 StepSkip | 1 | 4 | ps1 section -Fix: exit 0; ps1 section (no -Fix): exit 0 |
| PC3 | step 3: `if ($Fix) { & $gitBash (Join-Path $scriptDir "build-deploy.sh") }` (the pre-#154 shape) | 1 | 2 | ps1 section -Fix: build-deploy.sh was not run (no marker, HOME untouched); ps1 static: no line runs build-deploy |
| PC3n | the same, unconditional | 1 | 3 | ps1 section (no -Fix): build-deploy.sh was not run (no marker, HOME untouched) |
| PC4 | `InvokeGit add deploy;` before the step 10 StepSkip; run case on | 1 | 4 | section -Fix and (no -Fix): nothing staged under deploy/; ps1 static: no line stages deploy/; run (ps1, fix flag): nothing staged under deploy/ |
| PC5 | step 10 text `retired:` -> `retired (m08):`; run case on | 1 | 3 | section -Fix, section (no -Fix) and run: exactly SKIP 3 and SKIP 10, pointing to check-pre-push step 7 |
| PC6 | step 10 text -> `run -Fix; retired:` | 1 | 5 | section -Fix and (no -Fix): no result advises -Fix; ps1 static: no step result advises -Fix |
| PC7 | `# 6. Executable bit on .sh files` -> `# 6) ...` | 1 | 4 | ps1: the step 6 section was found |
| PC8 | `throw 'm08';` before `$nonExec = InvokeGit ls-files` | 1 | 5 | ps1 step 6 -Fix: exit 0; ps1 step 6 (no -Fix): exit 0 |
| PC9 | pathspec `'*.sh' ':!deploy/'` -> `'*.sh'` | 1 | 4 | step 6 -Fix: deploy/x.sh still 100644 in the index; step 6 -Fix: nothing staged under deploy/; step 6 (no -Fix): exactly FAIL 6, scripts/y.sh only (1 file); ps1 static: the tracked *.sh listing (step 6) excludes deploy/ |
| PC10 | `InvokeGit update-index --chmod=+x $f` -> `$null = $f`; run case on | 1 | 2 | ps1 step 6 -Fix: scripts/y.sh repaired to 100755; run (ps1, fix flag): step 6 still repairs the exec bit (staged file is 100755) |
| PC11 | `$Fix = $true` after `$badFiles = ...` (repairs without -Fix) | 1 | 2 | step 6 (no -Fix): scripts/y.sh unchanged (100644); step 6 (no -Fix): exactly FAIL 6, scripts/y.sh only (1 file) |
| PC12 | PC9 + PC11 | 1 | 7 | step 6 (no -Fix): deploy/x.sh still 100644 in the index; step 6 (no -Fix): nothing staged under deploy/ |
| PC13 | `"(fixed)"` -> `"(repaired)"` | 1 | 1 | ps1 step 6 -Fix: exactly PASS 6 (fixed) |
| PC14 | `file(s) missing +x"` -> `file(s) not executable"` | 1 | 1 | ps1 step 6 (no -Fix): exactly FAIL 6, scripts/y.sh only (1 file) |
| PC15 | usage `# -Fix: auto-fix ...` -> `# -Fix: rebuild deploy/ and auto-fix ...` | 1 | 1 | ps1 static: the -Fix usage line exists and does not say it builds |
| PC16 | usage line -> `# With the fix flag: auto-fix ...` (no `-Fix:` line) | 1 | 1 | the same |
| PR1 | `CheckLogInit "pre-commit"; exit 3`; run case on | 1 | 4 | run (ps1, fix flag): the script ran to its summary (exit 0 or 1) |
| PR3a | step 3 writes `$env:M6B_MARKER` when -Fix (sensitivity); run case on | 1 | 2 | run (ps1, fix flag): build-deploy.sh was not run (no marker) (and the section -Fix marker check) |
| PR3b | step 3 with -Fix runs the clone's fake build-deploy.sh in the Git Bash from `ResolveGitBash` (the pre-#154 regression, realistic); run case on | 1 | 3 | run (ps1, fix flag): build-deploy.sh was not run (no marker); run: HOME unchanged (`./m6b-build-ran` added, so Git Bash writes the forward-slash HOME and marker paths) |
| PR4 | step 3 writes `$HOME/m08.txt`; run case on | 1 | 1 | run (ps1, fix flag): HOME unchanged (every file, by checksum) |
| PR5 | step 3 writes `m08.txt` into `$script:UserRepoPath`; run case on | 1 | 1 | run (ps1, fix flag): the dotprofile working tree unchanged |
| PR7 | step 4 -Fix no longer rewrites the file; run case on | 1 | 1 | run (ps1, fix flag): step 4 still repairs line endings (staged file is LF) |
| PR7b | step 4 text `(fixed CRLF)` -> `(fixed)`; run case on | 1 | 1 | the same |
| SS1 | `.sh` copy: `bash "$SCRIPT_DIR/build-deploy.sh";` before step 3 | 1 | 1 | sh static: no line runs build-deploy |
| SS2 | `.sh`: `git add deploy;` before step 10 | 1 | 1 | sh static: no line stages deploy/ |
| SS3 | `.sh`: pathspec without `':!deploy/'` | 1 | 1 | sh static: the tracked *.sh listing (step 6) excludes deploy/ |
| SS4 | `.sh`: step 10 text `run --fix; retired:` | 1 | 1 | sh static: no step result advises --fix |
| SS5 | `.sh`: usage `# --fix: build deploy/ and auto-fix` | 1 | 1 | sh static: the --fix usage line exists and does not say it builds |
| SS6 | `.sh`: usage line -> `# fix flag: auto-fix` | 1 | 1 | the same |

Coverage: each of the 40 checks fails under at least one row above. Mapping, by
position in the run log:
- 1 PC1
- 2/7 PC2
- 3 PC3, 8 PC3n
- 4/9 PC4
- 5/10 PC5
- 6/11 PC6
- 12 PC7
- 13/18 PC8
- 14/15 PC9
- 16 PC10
- 17 PC13
- 19/20 PC12
- 21 PC11
- 22 PC14
- 23-27 SS1-SS5
- 28 PC3
- 29 PC4
- 30 PC9
- 31 PC6
- 32 PC15/PC16
- 33 PR1
- 34 PC5
- 35 PR3a/PR3b
- 36 PR4
- 37 PR5
- 38 PC4
- 39 PR7/PR7b
- 40 PC10

### Post-push deploy steps (`.ps1` harness, 10 checks)

| Id | Mutation (copy only) | Exit | FAILs | Target checks (all FAILed) |
|---|---|---|---|---|
| M0-pp | control: unmodified copy via POST_PUSH_PS1 | 0 | 0 | none (10/0/0) |
| PP1 | `# 14. Line ending audit` -> `# 14) ...` | 1 | 3 | ps1: the step 2, 6 and 14 sections were found |
| PP2 | `throw 'm08';` before the step 2 StepSkip | 1 | 4 | ps1 frozen: exit 0; ps1 sources: exit 0 |
| PP3a | step 2 writes `$env:DEPLOY_STEPS_MARKER` (sensitivity) | 1 | 2 | ps1 frozen / ps1 sources: build-deploy.sh was not run |
| PP3b | step 2 runs the fake build-deploy.sh with `$bashExe` (Git Bash, passed in by the harness) | 1 | 2 | the same (Git Bash writes the native-path marker) |
| PP4 | step 6 (.ps1) also parses `deploy/*.ps1` | 1 | 2 | ps1 frozen: results are exactly the expected ones; ps1 static: no line reads the aitools deploy/ |
| PP5 | step 14 no longer adds `shared/hooks/*.sh` | 1 | 1 | ps1 sources: results are exactly the expected ones |
| PP6 | a step 3 line `$null = Join-Path $script:RepoRoot "deploy"` (outside the cut sections) | 1 | 1 | ps1 static: no line reads the aitools deploy/ |
| PP8 | step 2 writes `$env:HOME/m08.txt` | 1 | 1 | home: the temporary HOME is unchanged |
| PP9 | step 6 (.sh) SKIP text changed | 1 | 2 | ps1 frozen / ps1 sources: results are exactly the expected ones |
| PS7 | `.sh` copy via POST_PUSH_SH: step 6 loop also globs `"$REPO_ROOT"/deploy/*.ps1` | 1 | 1 | sh static: no line reads the aitools deploy/ |

Coverage: each of the 10 checks fails under at least one row: sh static PS7; sections
PP1; exits PP2; markers PP3a/PP3b; frozen results PP4/PP9; sources results PP5/PP9;
ps1 static PP6/PP4; home PP8.

## `.sh` review (diffs against origin/main)

Diffs: `git -C W diff origin/main -- tests/check-pre-commit/test-pre-commit-steps3-10.sh`
and `-- tests/check-post-push/test-post-push-deploy-steps.sh`.

**Guard form**
- Both carry the block from `W\.claude\rules\cross-platform.md` "Test suites", verbatim
  (the diff adds it at that rule's lines 115-149).
- Both cases are present: the `uname -s` case and the `BASH_VERSINFO[5]` case.
- The message names the `.ps1` twin (`test-pre-commit-steps3-10.sh:62-71`,
  `test-post-push-deploy-steps.sh:52-62`).
- The guard comes first after `set -uo pipefail` and before `--help`.
- The classifier agrees: test-os-guards.ps1 lists both as refusing windows.

**Every `.sh`-twin case kept.** The diffs only remove the `.ps1`/Windows branches and
add the guard and header.
- Pre-commit keeps:
  - the section cases (11)
  - the step 6 cases (11)
  - all 10 static cases (perl reads both twins' text)
  - the `run (sh, fix flag)` cases (8)
  - the expected macOS/Linux total is 40, the Linux CI lines minus nothing.
- Post-push keeps:
  - `sh` sections, frozen and sources (7)
  - `sh static` and `ps1 static`
  - `home`
  - the expected total is 10.
  - The `twins` pair is dropped, because no host may run both twins.

**No `.ps1`/pwsh case left.** `git grep` finds `pwsh` only in comments, the guard
messages and the post-push `require_pwsh` capability branch
(`test-post-push-deploy-steps.sh:83-85,186`). That branch is the `.sh` twin's own
product step 6, which parses `scripts/*.ps1` with pwsh on macOS/Linux; it is not a run
of the `.ps1` twin.

No `IS_WINDOWS`, `cygpath` or `native()` remains. `TEST_RUN_TWIN` survives only as
`none` = skip (`test-pre-commit-steps3-10.sh:93,345-348`).

**bash 3.2.** The only additions are `case` statements and `${BASH_VERSINFO[5]:-}`,
which bash 3.2 has. The rest of each diff is deletions.

**AITOOLS_TEST_BASH.**
- `TB` runs every `.sh`-twin piece:
  - pre-commit section and step 6 drivers, `test-pre-commit-steps3-10.sh:219,242`
  - pre-commit run case, `:312`
  - post-push driver, `test-post-push-deploy-steps.sh:204`
- CI runs both with `/bin/bash` 3.2 on macOS (`check.yml:307,316`).

**`--help` ranges.** These are 2-55 and 2-46, and each ends on its `# Usage:` line
(checked: post-push line 46).

**Case mapping against the pre-port `.sh` (`git -C W show 5f962b1:<path>`).** Every
case the old `.sh` ran on the `.ps1` twin has a `.ps1` equivalent with the same check
name:

| 5f962b1 `.sh`, `.ps1`-twin cases | New `.ps1` harness |
|---|---|
| pre-commit: `ps1: the step 3 and step 10 sections were found` + 5 x `ps1 section -Fix` + 5 x `ps1 section (no -Fix)` | same 11 names (run log lines 1-11) |
| pre-commit: `ps1: the step 6 section was found` + 5 x `ps1 step 6 -Fix` + 5 x `ps1 step 6 (no -Fix)` | same 11 (lines 12-22) |
| pre-commit: 5 x `ps1 static` (perl, platform-neutral) | same 5, plus the 5 `sh static` (lines 23-32) |
| pre-commit: `run (ps1, fix flag)` x 8 (Windows only) | same 8 (lines 33-40) |
| post-push: `ps1: the step 2, 6 and 14 sections were found`, `ps1 frozen` x 3, `ps1 sources` x 3 | same 7. The expected step 6 (.sh) record is now the #167 SKIP, not the 5f962b1 `PASS/FAIL 6 Full syntax (.sh)`: a product change, PR #167 |
| post-push: `ps1 static` | same |
| post-push: `twins frozen`, `twins sources` | dropped (needs both twins on one host); parity is now by identical inline expectations (N1) |
| post-push: `home` | same |

## Findings

Blocking: none.

**Non-blocking**

- **N1. Twin parity in deploy-steps rests on duplicated inline expectations.** The
  expected records sit inline in `test-post-push-deploy-steps.ps1:180-191` and again in
  `test-post-push-deploy-steps.sh:153-169`. The text matches today for steps 2, 6 (.ps1)
  and 14; nothing enforces it. Suggested: the golden-file follow-up e9d6-22 proposed
  (its open question 1), `tests/check-post-push/golden/deploy-steps-{frozen,sources}.rec`
  read by `golden_match` / `Test-GoldenMatch`.
- **N2. The two `.ps1` harnesses pass child paths in different forms.** Pre-commit uses
  forward slashes (`Mixed`, `test-pre-commit-steps3-10.ps1:288-289,337-339`). Post-push
  uses native backslashes (`test-post-push-deploy-steps.ps1:234-236`). Both work, and
  Git Bash writes the marker with either form (PR3b, PP3b). Cosmetic: pick one form when
  someone next touches these files.
- **N3. The run case accepts exit 0 or 1** (`test-pre-commit-steps3-10.ps1:355`, the
  same rule as the old `.sh`), so unrelated step FAILs in the cloned run go unnoticed.
  - Seen locally in the run output (first-pass `mut-PR3b.log`): steps 20 and 21 FAIL
    with `[ERROR] No runtime installed that matches 3. Try running "py install 3".`
  - Cause: the run redirects `LOCALAPPDATA`, and the `py` launcher then finds no
    per-user Python.
  - It does not affect any of the 8 run checks. Recorded so nobody later reads those
    FAIL lines as a product regression.
  - Optional: leave LOCALAPPDATA alone, or document the effect in the header.
- **N4. The section driver's `$gitBash` PowerShell stub only guards one shape of
  regression.** After #167, `scripts/check-pre-commit.ps1` has no `$gitBash` at all
  (`git grep -n -i gitBash` finds nothing), so the stub
  (`test-pre-commit-steps3-10.ps1:224-225,281`) only matters if `& $gitBash` comes back.
  A regression that calls `ResolveGitBash` inside step 3 or 10 is caught two other ways:
  - the section driver throws, because the function is undefined there, and the
    `exit 0` checks FAIL (first-pass PR3b)
  - the run case finds the marker (PR3b)

  No change needed; this is information for reviewers.

## Not run

- The `.sh` harnesses past their guard. The rule forbids it on Windows; the macOS/Linux
  CI jobs are their evidence. I reviewed them by diff, ran `bash -n` and proved the
  refusal.
- macOS `/bin/bash` 3.2 locally (CI `check.yml:307,316`).
- CI itself. `check.yml` (38dc-27's) has the `.ps1` steps at `:956,966` and the `.sh`
  steps at `:303-316,652,662`; I read those lines but did not review the file.
- Whether the GitHub windows runner puts a perl on PATH for the static cases: unknown,
  not verified here. The harness falls back to Git for Windows' `usr\bin\perl.exe` and
  FAILs without any perl.

## Lines

- WRITE_BLOCKED: none.
- CONFLICT: none.
- INCIDENT: none new. The earlier overwrite of e9d6-22's
  `test-pre-commit-steps3-10.ps1` by 08de-01 is recorded in e9d6-22's report and my
  first hand-back. e9d6-22 restored its version, and the file reviewed here is that
  version: its SHA-256 `5aa8d7c6...c29a` and the `.sh`'s `7d4622dd...9216` equal the hashes in
  `e9d6-22-report.md` "Files".
- Changed files: only `W\.scratch\session-08de-01\*` and this report.
