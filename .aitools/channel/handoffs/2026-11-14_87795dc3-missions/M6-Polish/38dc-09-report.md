# 38dc-09 report: check-post-push steps 2, 6 and 14 no longer read the frozen aitools deploy/ (post-push half of item c)

Version 1.1 (2026-11-14; v1.0 -> v1.1: the suite's HOME check excludes pwsh's macOS/Linux state, after the first CI run). Author: 38dc-09-postpush-deploy-checks, delegated by
M6-Polish (agent 38dc, level 2), under Session Commander 87795dc3-e. Branch
`fix/m6-checks` (worktree `.claude/worktrees/m6-checks`), continuing after M6-B.
Code commit 1536e6b; PR https://github.com/nobul-tech/aitools/pull/154.

**Intent**: **Purpose**: hand M6-Polish, an independent reviewer and the
commander what changed in check-post-push steps 2, 6 and 14, the evidence, the
incident bookkeeping and what is left. **Scope**: the post-push half of item c.
NOT check-pre-commit (M6-B). NOT `scripts/check-lib.*` (fix/m6-logging). NOT
RELEASE_NOTES.md (the rows are below). NOT the CI workflow's own deploy/ steps
(reported, not changed). **Audience**: M6-Polish, an independent reviewer, the
commander.

## Summary

1. Step 2 ("Smoke-test deploy scripts") is retired in both twins to an unconditional SKIP `retired: check-pre-push step 7 rebuilds into a temp dotprofile copy`; steps 6 ("Full syntax") and 14 ("Line ending audit") drop their `deploy/` globs and audit `scripts/` and `shared/hooks/` only. No step of either twin reads the aitools `deploy/`. Step numbers kept.
2. New suite `tests/check-post-push/test-post-push-deploy-steps.sh`: 19/0/0 on Windows; 6 of 19 fail against the origin/main 2ee68d9 twins; CI on macOS (bash 5 and /bin/bash 3.2), Linux and Windows.
3. Incident #176 filed and closed (no duplicate in the registry; #136 is the pre-commit sibling, already closed in this PR by M6-B).
4. Docs: `reference/post-push-checklist.md` (steps 2, 6, 11, 14), `.claude/rules/deploy-paths.md` item 3 and `.cursor/rules/deploy-paths.mdc` (both halves of item c), README.md, scripts/README.md.
5. Gap stated, not hidden: pre-push step 7 does not `bash -n` every generated `.sh` or audit their line endings (neither did the frozen-tree steps); proposed follow-up below.

## Step 1: verify before fix (origin/main 2ee68d9, after merging it into the branch)

Evidence: `.scratch/session-38dc-09/verify-before-fix.log` (script `verify-before-fix.sh`).

| Step | Code at origin/main | What it was meant to prove | Origin |
|---|---|---|---|
| 2 "Smoke-test deploy scripts" | `.sh` :53-65 `for f in "$REPO_ROOT"/deploy/*.sh; do bash -n ...`; `.ps1` :49-73 `Get-ChildItem (Join-Path $script:RepoRoot "deploy") -Filter "*.sh"`, `& $bashExe -n`, FAIL when none found | the generated deploy scripts parse (catch build corruption) | d5d1ddd 2026-02-26 "Add checklist verification scripts ..." |
| 6 "Full syntax (.sh)/(.ps1)" | `.sh` :167 and :183 add `"$REPO_ROOT"/deploy/*.sh` and `deploy/*.ps1`; `.ps1` :181 and :210 add `RepoRoot "deploy"` `*.sh` / `*.ps1` | every script in the repo, generated ones included, parses | d5d1ddd |
| 14 "Line ending audit" | `.sh` :313, `.ps1` :367 add `deploy/*.sh` | no CRLF in any `.sh`, generated ones included | d5d1ddd |

All three read the aitools `deploy/`, which is frozen: last content change bda38a2 (2026-06-14); 2c0fd32 (same day) "Build deploy into the user's dotprofile repo" moved the build output to `<userRepoPath>/deploy/` (`.claude/rules/git-safety.md` "deploy/ is frozen"). 18 tracked `.sh` and 18 `.ps1` there; all parse and have no CR today (`probe-cr-files.sh`), so the steps passed whatever the build produced.

Other steps that read the aitools `deploy/`: none in either check-post-push or check-pre-push twin (grep in the verify log; step 26 and 32 read `scripts/build-deploy.sh` source text, not the tree; pre-push step 7 reads only its temp build). Same class outside these twins, not changed: `.github/workflows/check.yml` (see INCIDENT below).

## Step 2: decisions

| Step | Covered by pre-push step 7? | Decision | New output |
|---|---|---|---|
| 2 | Partly. Pre-push step 7 rebuilds into a temp dotprofile copy on every push; the build exits 1 on a generated `.ps1` that does not parse (build-deploy.sh "Post-build: Validate PS1 syntax", where pwsh is installed) and the step dry-runs `setup-user-claude/-settings/-cursor.sh` (and `.ps1` on Windows) plus the endpoint run. It does not `bash -n` the other generated `.sh` files. | Retire to SKIP (M5-C2 / M6-B pattern). Retargeting at the real build would mean a second isolated build per post-push run (`check-pre-push.ps1` took 42 s here; M6-B measured 38 s, nearly all of it step 7) or new code in check-lib (another branch's). Nothing is lost relative to before: the frozen-tree check never covered the generated scripts. | `  2. Smoke-test deploy scripts  [SKIP] retired: check-pre-push step 7 rebuilds into a temp dotprofile copy` (both twins) |
| 6 | The source scripts: no (and they need no build). The generated `.ps1`: yes, as above; generated `.sh`: no. | Retarget: drop `deploy/` from the globs; the step keeps auditing `scripts/*.sh`, `shared/hooks/*.sh`, `scripts/*.ps1`. | Unchanged text (`PASS 6 Full syntax (.sh)` / `(.ps1)`); `.ps1` FAIL texts: `no .sh files found in scripts/ or shared/hooks/`, `no .ps1 files found in scripts/` |
| 14 | Generated `.sh` line endings: no. | Retarget: drop `deploy/`; audits `scripts/*.sh` and `shared/hooks/*.sh`. | Unchanged (`PASS 14 Line ending audit` / `FAIL 14 ... N file(s) with CRLF`) |

The `.ps1` twin's `$bashExe = ResolveGitBash` sat inside step 2; it moved just above the step 2 heading (comment: "every bash step (4, 6)") because steps 4 and 6 use it; `tests/check-lib/test-resolve-git-bash.ps1` still finds `= ResolveGitBash` (17/0/0).

## Exact output changes

Before (both twins): `  2. Smoke-test deploy scripts  [PASS]` (or FAIL `N file(s) failed bash -n`; `.ps1` also FAIL `no .sh files found in deploy/`, SKIP `Git Bash not found`). After: always `[SKIP] retired: check-pre-push step 7 rebuilds into a temp dotprofile copy`. Steps 6 and 14: same texts, minus `deploy/` in the two `.ps1` "no files found" FAILs.

## Tests

`tests/check-post-push/test-post-push-deploy-steps.sh` (100755, `--help`, bash 3.2-safe; `POST_PUSH_SH` / `POST_PUSH_PS1` to test other twins, `AITOOLS_TEST_BASH`, `TEST_KEEP_TMP`):

- frozen (per twin): steps 2, 6, 14 cut out (heading to next step's heading) and run with stub step functions, a temporary HOME, a fake repo whose sources are clean and whose `deploy/` holds a bash syntax error, a PowerShell parse error and a CRLF `.sh`; `scripts/build-deploy.sh` is a fake that writes a marker. Exactly `SKIP 2 <retired>`, `PASS 6 (.sh)`, `PASS 6 (.ps1)`, `PASS 14`; no marker.
- sources (per twin): the same problems in `scripts/` and `shared/hooks/`, clean `deploy/`: `SKIP 2`, `FAIL 6 (.sh) 1 file(s) failed`, `FAIL 6 (.ps1) 1 file(s) failed`, `FAIL 14 1 file(s) with CRLF`.
- twins: `.sh` and `.ps1` results identical (all four lines where the `.sh` twin's pwsh part runs, i.e. macOS/Linux with pwsh).
- static (per twin): no non-comment line names the aitools `deploy/`.
- home: the temporary HOME byte-identical (cksum of every file; pwsh's own state excluded: `AppData/Local/Microsoft/PowerShell` on Windows, `.cache/powershell` and `.local/share/powershell` on macOS/Linux). v1.1: the first CI run (43628370255) failed only this case on linux and macos (pwsh wrote `.cache/powershell/StartupProfileData-NonInteractive` and `telemetry.uuid`); every other case passed there, including the `.sh` twin's real pwsh parse and CRLF cases on bash 5 and /bin/bash 3.2. A mutant whose step 2 writes `$HOME/leak` and `$HOME/.cache/other/leak` still fails the check (`mutation-home.sh`).
- Limits (in the header): on Windows the `.sh` twin's `.ps1` audit is stubbed to SKIP (pwsh cannot open a POSIX path) and its CRLF case is not checked (Git for Windows grep strips CR); macOS and Linux CI run both.

Mutation (`.scratch/session-38dc-09/mutation.sh`, log `mutation.log`):

| Case | New twins | origin/main 2ee68d9 twins | Mutant: steps 6/14 glob nothing |
|---|---|---|---|
| sections found (2) | pass | pass | pass |
| sh frozen / sources: exit 0, no marker (4) | pass | pass | pass |
| sh frozen: results | pass | FAIL (FAIL 2, FAIL 6 from deploy/) | pass |
| sh sources: results | pass | FAIL (PASS 2, not SKIP 2) | FAIL (PASS 6) |
| sh static | pass | FAIL (4 lines) | pass |
| ps1 frozen / sources: exit 0, no marker (4) | pass | pass | pass |
| ps1 frozen: results | pass | FAIL (FAIL 2, 6, 6, 14) | FAIL (no files found) |
| ps1 sources: results | pass | FAIL (PASS 2) | FAIL |
| ps1 static | pass | FAIL (4 lines) | pass |
| twins (2) | pass | pass | FAIL, FAIL |
| home | pass | pass | pass |
| total | 19 passed, 0 failed | 13 passed, 6 failed | 14 passed, 5 failed |

On Windows the old `.sh` twin's step 14 still passes the frozen case (grep cannot see CR); the macOS/Linux CI jobs check it.

CI wiring: `.github/workflows/check.yml` macos (bash 5 and `/bin/bash` 3.2), linux, windows; `check-ci-suites.pl`: "All 44 test suites are in CI or exempt".

## Local results (Windows 11, pwsh 7, Git Bash 5.3.15; `.scratch/session-38dc-09/run-suites.log`)

test-post-push-deploy-steps 19/0/0; test-post-push-step7 10/0/0; test-menu-parity 24/0/0; test-pre-commit-steps3-10 38/0/0; test-check-ci-suites 21/0; test-os-guards 34/0/0; test-resolve-git-bash.ps1 17/0/0; check-ci-suites.pl all 44 in CI; `bash -n` and the pwsh parser on both twins and the suite; incidents.json parses, max id 176, no duplicate ids.

`check-pre-commit.ps1` (no -Fix, AITOOLS_LOG_DIR in scratch): 10 PASS, 6 SKIP, 3 WARN (5 platform note: the message was not yet committed; 9 release notes: orchestrator; 11 dotprofile has uncommitted changes, not mine), 0 FAIL. `check-pre-push.ps1` after the commit: 7 PASS, 3 WARN (1, 5, 6), 0 FAIL, step 7 PASS "fresh build OK (dotprofile deploy/ untracked, not compared); resolver consumers dry-run clean", 42 s.

## Isolated check-post-push.ps1 run

`run-postpush-isolated.sh`: HOME/USERPROFILE/APPDATA/LOCALAPPDATA and AITOOLS_LOG_DIR in `.scratch/session-38dc-09/iso/`, config.json pointing at the worktree and a scratch `git clone` of the dotprofile. Result: exit 1; 19 PASS, 6 SKIP, 5 WARN, 3 FAIL. Step 2 SKIP (retired), 6 PASS/PASS, 7 SKIP, 14 PASS. FAILs, none from this change: 1 (HEAD != origin/main, a branch), 3 (no `.claude.json` / `.cursor/mcp.json` in the isolated HOME), 23 (check-script-compliance 11: `setup-pywinpty.ps1:151` SilentlyContinue, pre-existing, as M5-C2 saw). Logs went to the isolated dir only (`checks.jsonl`, `checks.log`, `deploy.log`). Real state before/after (`iso-before.txt`, `iso-after.txt`): dotprofile `deploy/` 51 files, content checksum `3421848201 1943` both times; `~/.aitools/logs/checks.log` and `checks.jsonl` 549 lines, mtime 2026-11-14T18:17:42Z both times; `~/.aitools/config.json` cksum and mtime unchanged.

## Incident #176

Duplicate search first (`incident-search.py`, `incident-titles.py`: all 175 entries parsed, every title listed, every entry that names `deploy/` with a check script, CI or a step number printed). No incident described post-push 2/6/14; #136 (closed in this PR) is the pre-commit 3/10 sibling; #10 (planned) is about CI not running installers. Filed #176 and closed it in the same change, directly in the `closed` array (after #173, id order) with `correctiveAction`, `rootCause`, `preventionLayer`, `closedIn` "PR #154 (branch fix/m6-checks, mission 38dc-09)", `closedDate` 2026-11-14, `updated`. Severity medium (the steps reported PASS for checks they did not perform; no data was written; M5-C2 also rated it medium). #175 stays unused; #177/#178 untouched. The full open-form entry (observation, expected, impact, discoveryContext, suggestedResolution) is in the PR body "Review after".

## Files changed

`scripts/check-post-push.sh`, `scripts/check-post-push.ps1`, `tests/check-post-push/test-post-push-deploy-steps.sh` (new), `.github/workflows/check.yml`, `reference/post-push-checklist.md`, `.claude/rules/deploy-paths.md`, `.cursor/rules/deploy-paths.mdc`, `README.md`, `scripts/README.md`, `registries/incidents.json`, this report. Merge commit for origin/main (2ee68d9) first.

## Proposed RELEASE_NOTES rows (for M6-Polish)

Bug fixes:

| # | Severity | Fix |
|---|----------|-----|
| n | Medium | `check-post-push` steps 2, 6 and 14 read the frozen aitools `deploy/` (bash -n, PowerShell parse, line endings), which build-deploy.sh has not written since 2c0fd32, so they passed whatever the dotprofile build produced. Step 2 ("Smoke-test deploy scripts") is now a SKIP in both twins, `retired: check-pre-push step 7 rebuilds into a temp dotprofile copy`; steps 6 and 14 audit `scripts/` and `shared/hooks/` only. Resolves Incident #176 |

Files created:

| File | Purpose |
|------|---------|
| `tests/check-post-push/test-post-push-deploy-steps.sh` | Steps 2, 6 and 14 of both check-post-push twins ignore problems planted in `deploy/`, still FAIL on the same problems in the sources, and no line of either twin reads `deploy/` (CI: macOS bash 5 and /bin/bash 3.2, Linux, Windows) |

## Not run

- `check-post-push.sh` outside the harness (POSIX-guarded on Windows); the whole `.sh` twin on macOS/Linux before CI.
- The CI workflow's deploy/ steps were not changed (see INCIDENT).

## WRITE_BLOCKED / CONFLICT / INCIDENT

- WRITE_BLOCKED: none.
- CONFLICT: auto-mode note allowing Bash file edits vs USO "Dedicated tools for file ops" -- resolved by tier 1 (commander's CLAUDE.md): Read/Edit/Write for every file; Bash only for scripts in scratch, git and gh.
- CONFLICT: prompt and /incident skill "read incidents.json in full" vs the Read tool's limits (411 KB; refused "more than fits in the context you have left") -- resolved by tier 2 intent (no duplicate, no id clash): parsed the whole file with python (all 175 entries, ids, duplicates), printed every title and every deploy/-and-check entry, read the candidates (#10, #136, #141) and the closed-array tail in full. Not a line-by-line read of all 4,152 lines.
- CONFLICT: prompt "incident covering pre-commit 3/10 and post-push 2/6/14" vs the registry already holding #136 (closed in this PR) for pre-commit 3/10 -- resolved by tier 1 (governance records: no duplicate tracking): #176 names the post-push steps and cites #136 as the sibling, so the class is covered by the two without double-counting.
- INCIDENT (not filed; for M6-Polish triage):
  - `.github/workflows/check.yml`: "Validate bash script syntax" (macos, linux, windows) loops over `deploy/*.sh`, "Validate PowerShell script syntax" over `deploy/*.ps1`, and every job runs "Build deploy scripts" (`bash scripts/build-deploy.sh`, which writes only a dotprofile `deploy/` and skips with exit 0 when it finds no dotprofile, build-deploy.sh :231-234; whether a runner resolves one was not checked) then "Check deploy drift" (`git diff -- deploy/` on the frozen aitools tree, which the build never writes). Same class as #176, in CI; they always pass. Also the macOS "Line ending audit" step's comment says deploy/ and scripts/ hold intentional CRLF, but none of the 79 `.sh` files in scripts/, deploy/, shared/hooks/ contains a CR today. Suggested: a new incident (medium), resolution: drop the deploy/ globs and the build/drift steps (pre-push step 7 is the build check), or point them at a temp build like pre-push step 7.
  - `scripts/check-lib.ps1` `ResolveGitBash` comment (line ~223) says "check-post-push steps 2, 4 and 6"; now 4 and 6 (low; fix/m6-logging owns check-lib).
  - `reference/post-push-checklist.md` step 26 and `CLAUDE.md`: step 26 always SKIPs ("could not find deploy reference in CLAUDE.md"); already documented as such, not changed.

## Open questions (each with a suggested answer)

1. Should generated `.sh` files get `bash -n` and a CR check somewhere real? Suggested: yes, in `build-deploy.sh` "Post-build" beside its PS1 ParseFile (exit 1 on failure), so pre-push step 7 fails on them on every push; a small follow-up PR with a test in `tests/build-deploy/`.
2. Should the `.claude/rules/cross-platform.md` "Unrecorded" row (check-*.ps1 -> Git Bash) be split per script? Suggested: not in this PR; this change does not make it stale for post-push (steps 4 and 6 still use Git Bash), and the row's reasons are still true as a union.
3. Should step 2 instead run `bash -n` on the real dotprofile `deploy/` when it exists? Suggested: no; that tree is machine-local build output that may be stale or absent, so a PASS or FAIL there says nothing about this push (pre-push step 7 builds from the pushed branch).

## New operational learning

- With `MSYS_NO_PATHCONV=1`, a `/c/Users/...` argument reaches the native `git.exe` unconverted and fails ("cannot change to '/c/Users/...'"); use the `C:/Users/...` form in scratch scripts that need `origin/main:<path>`. A failed `git show` there left empty files, and a static scan of an empty file passes: pair static checks with a "section found" check (the suite does).
- A pwsh `ParseFile('<POSIX path>')` from Git Bash on Windows cannot open the file; a `.sh` twin's pwsh step can only be exercised on macOS/Linux.
- The isolated run's `ls | sort | tail -1` picked the `..` entry, not the newest file; compare content checksums instead (done here).
- pwsh started with HOME at a temp dir on macOS and Linux writes `$HOME/.cache/powershell/StartupProfileData-NonInteractive` and `telemetry.uuid` at every start (the Unix twin of the Windows `AppData/Local/Microsoft/PowerShell` cache): a HOME snapshot in any suite that runs pwsh must exclude it.
