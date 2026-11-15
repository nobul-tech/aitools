# M6-B report: check-pre-commit never builds against the real HOME; steps 3 and 10 retired (items b and the pre-commit half of c)

Version 1.0 (2026-11-14). Author: M6-B, delegated by M6-Polish (level 2), under
Session Commander 87795dc3-e. Branch `fix/m6-checks` (worktree
`.claude/worktrees/m6-checks`), off origin/main 846ab24. PR
https://github.com/nobul-tech/aitools/pull/154.

**Intent**: **Purpose**: hand M6-Polish, M6-C and the reviewer what changed in
check-pre-commit steps 3 and 10 and the fix flag, the evidence, the incident
bookkeeping, and what is left for others. **Scope**: item b and the
pre-commit half of item c. NOT check-post-push (M6-C). NOT RELEASE_NOTES.md,
`.claude/rules/cross-platform.md`, `.claude/rules/deploy-paths.md` (other
owners; the text they need is below). **Audience**: M6-Polish, M6-C, an
independent reviewer, the commander.

## Summary

1. Both twins of `check-pre-commit` retire step 3 ("Build freshness") and step 10 ("Deploy drift") to an unconditional SKIP `retired: check-pre-push step 7 rebuilds into a temp dotprofile copy`; no code path runs `build-deploy.sh`, stages `deploy/`, or advises the fix flag.
2. `--fix` / `-Fix` keeps line endings (step 4) and exec bits (step 6); the `.sh` step 4 repair moved from `sed -i ''` (exit 2 on GNU sed, ends the run on Linux) to `perl -pi`.
3. New suite `tests/check-pre-commit/test-pre-commit-steps3-10.sh`: 38/0/0 on Windows; 22 of 38 fail against the origin/main twins. In CI on macOS (bash 5, /bin/bash 3.2), Linux and Windows.
4. Incident: #136 (open, high) already described item b exactly, so it is closed here; #175 was NOT filed (it would duplicate #136) and is unused.
5. PR #154 open; CI run and per-job result in the final response to M6-Polish (watched after this file was committed).

## Step 1: verify before fix (origin/main 846ab24)

Recorded in `.scratch/session-M6-B/verify-before-fix.txt` (script `verify-before-fix.sh`).

- `check-pre-commit.sh` step 3 (lines 111-118): `if $FIX_MODE; then bash "$SCRIPT_DIR/build-deploy.sh" >/dev/null 2>&1; git add deploy/ 2>/dev/null; step_pass "3" "Build freshness" "(rebuilt + staged)"`, else `step_warn "3" ... "scripts/ or shared/ modified -- run with --fix"`. No exit-code check.
- `check-pre-commit.ps1` step 3 (lines 116-125): `& $gitBash "$script:RepoRoot/scripts/build-deploy.sh" 2>$null | Out-Null; InvokeGit add deploy/; StepPass "3" ... "(rebuilt + staged)"`; WARN `... -- run with -Fix`. No `$LASTEXITCODE` check (the M5 finding reproduces).
- What it builds against: `build-deploy.sh` lines 202-241 take `AITOOLS_USER_REPO_PATH`, else run `resolve_user_repo_path` (which reads `$HOME/.aitools/config.json`), and set `DEPLOY_DIR="$_urp/deploy"`. The check passes no override, so it builds the real dotprofile `deploy/` of the caller's HOME.
- Step 10 (both twins): `git diff deploy/` on the aitools tree; `deploy/` there last changed in bda38a2 (2026-06-14) and `build-deploy.sh` stopped writing it in 2c0fd32 (2026-06-14, "Build deploy into the user's dotprofile repo"). git-safety.md line 5: "The aitools `deploy/` directory is frozen: `build-deploy.sh` no longer writes it."
- Origin: `git log -S` -> d5d1ddd (2026-02-26, "Add checklist verification scripts ..."): step 3 rebuilt and staged the aitools `deploy/`, step 10 proved no unstaged `deploy/` drift remained. That purpose ended with 2c0fd32.
- Existing record: incident #136 (filed 2026-10-21, open, high) has this exact defect; `S3-Reconcile-Ledger-findings.md:218` records an unexplained rebuild of the real dotprofile `deploy/` on 2026-10-21 "possibly #136's step 3 --fix".

Everything reproduced; nothing was executed against the real HOME.

## Decisions

**Fix flag: option B (retire the build).** Reasons: (1) pre-push step 7 already performs the isolated rebuild on every push, with exit-code checks and dry runs; (2) option A would mean a second copy of that ~130-line block in pre-commit, or a shared helper in `check-lib.*`, which M6-F owns on another branch; (3) cost, measured on this branch: `check-pre-commit.ps1` 2 s, `check-pre-push.ps1` 38 s (step 7 is nearly all of it), so a rebuild per commit is ~20x slower. Kept: step 4 (line endings) and step 6 (exec bits); both touch only repo files. Step 4's `.sh` repair was itself unsafe on Linux (`sed -i ''` with GNU sed: "can't read s/\r$//", exit 2, the run ends under `set -e`; probe `.scratch/session-M6-B/probe-sed.sh`, GNU sed 4.9), so it now uses `perl -pi -e 's/\r$//'`.

**Steps 3 and 10: retire to a documented SKIP**, the M5-C2 pattern for post-push step 7, same detail text, step numbers kept. Retargeting would be the same isolated build per commit (reasons above).

## Exact new step outputs

```
  3. Build freshness                           [SKIP] retired: check-pre-push step 7 rebuilds into a temp dotprofile copy
 10. Deploy drift                              [SKIP] retired: check-pre-push step 7 rebuilds into a temp dotprofile copy
```

Both twins, with or without the fix flag, whatever is staged. Removed outputs: PASS 3 `(rebuilt + staged)`, WARN 3 `scripts/ or shared/ modified -- run with --fix` / `-- run with -Fix`, FAIL 3 `Git Bash not found for build-deploy.sh`, SKIP 3 `no scripts/ or shared/ changes`, PASS 10, FAIL 10 `unstaged deploy/ changes remain`, SKIP 10 `no build needed`.

## For M6-C (continues on this branch)

What changed in steps 3 and 10: see "Exact new step outputs". Code: `scripts/check-pre-commit.sh` and `.ps1`, the `# 3. Build freshness` and `# 10. Deploy drift check` sections (headings unchanged) are one `step_skip` / `StepSkip` each plus a history comment citing incident #136; `build_needed` / `$buildNeeded` no longer exists. `check.yml` has 4 new steps named "check-pre-commit steps 3 and 10 tests ..." (macos bash 5 and /bin/bash 3.2 after "check-pre-push step 7 tests"; linux after "check-post-push step 29 ..."; windows after "check-post-push step 29 ...").

The sentence in `.claude/rules/deploy-paths.md` that must change ("When changing `scripts/setup-*.sh/.ps1`", item 3), verbatim:

> 3. Verify the dotprofile `deploy/` includes the change. Pre-commit steps 3 and 10 still inspect the frozen `aitools/deploy/` and prove nothing about the dotprofile build (step 3 `--fix` also runs `build-deploy.sh` against the real `HOME`: never pass it from an agent); `check-pre-push` step 7 is the real check

Suggested new text (adjust for post-push steps 2/6/14 as M6-C changes them):

> 3. Verify the dotprofile `deploy/` includes the change: `check-pre-push` step 7 rebuilds it into a temporary copy of the dotprofile under a temporary `HOME` on every push and dry-runs the result. Pre-commit steps 3 and 10 are retired SKIPs (incident #136): no check script runs `build-deploy.sh` against the real `HOME`

Its Cursor twin `.cursor/rules/deploy-paths.mdc` line 31, verbatim (left for the same change):

> 3. Verify the dotprofile `deploy/` includes the change (the shared `aitools/deploy/` is frozen; pre-commit steps 3 and 10 still inspect it and prove nothing about the dotprofile build; `check-pre-push` step 7 is the real check)

## Tests

`tests/check-pre-commit/test-pre-commit-steps3-10.sh` (100755, `--help`, bash 3.2-safe; env `PRE_COMMIT_SH` / `PRE_COMMIT_PS1` to test other twins, `TEST_RUN_TWIN`, `AITOOLS_TEST_BASH`, `TEST_KEEP_TMP`):

- section (per twin, fix flag on and off): steps 3 and 10 cut out and run with stub step functions, a staged `scripts/` file, a fake repo whose `scripts/build-deploy.sh` writes a marker into HOME and at an absolute path, and a modified tracked `deploy/` file. Checks: exit 0; no marker; nothing staged under `deploy/`; exactly SKIP 3 and SKIP 10 with the retired text; no `--fix` / `-Fix` advice.
- static (per twin): no non-comment line runs build-deploy; none stages `deploy/`; no step result mentions the fix flag; the fix flag's usage line exists and does not say "build".
- run: the whole script with the fix flag from a clone of the repo whose `build-deploy.sh` is the fake (`.ps1` on Windows, `.sh` on macOS/Linux), a CRLF 100644 `.sh` staged, a tracked `deploy/` file modified, under a temporary HOME (and USERPROFILE/APPDATA/LOCALAPPDATA on Windows) whose config.json points at a fixture dotprofile. Checks: the run reaches its summary (exit 0/1); exactly SKIP 3 and SKIP 10; no marker; HOME and the dotprofile working tree byte-identical (cksum of every file, `.git/` and pwsh's own `AppData/Local/Microsoft/PowerShell` startup cache excluded); nothing staged under `deploy/`; step 4 still fixes CRLF (`PASS 4 (fixed CRLF)`, file LF) and step 6 the exec bit (100755).

Mutation (`.scratch/session-M6-B/mutation.sh`, origin/main 846ab24 twins):

| Case group | New twins | Old twins |
|---|---|---|
| sh section, --fix (5) | 5 pass | 3 fail: marker/HOME written, deploy/ staged, PASS 3 + PASS 10 |
| sh section, no --fix (5) | 5 pass | 2 fail: WARN 3 + SKIP 10 "no build needed"; advises --fix |
| ps1 section, -Fix (5) | 5 pass | 3 fail (same as sh) |
| ps1 section, no -Fix (5) | 5 pass | 2 fail (same as sh) |
| static, sh and ps1 (8) | 8 pass | 8 fail (build call, `git add deploy/`, `run with --fix`, header says build freshness) |
| run, ps1 with -Fix (8) | 8 pass | 4 fail: steps 3/10 not the two retired SKIPs, marker, HOME written, deploy/ staged |
| sections found (2) | 2 pass | 2 pass |
| total | 38 passed, 0 failed | 16 passed, 22 failed |

The `.sh` run case on Windows (local smoke only, a guard-stripped copy, `smoke-sh-run.sh`): new twin 37/1, old twin 24/14 (old: 5 of the 8 run checks fail, including step 4). The 1 failure on the new twin is step 4's CRLF detection: Git for Windows grep strips CR before matching, so `grep -rl $'\r'` cannot fire there; the `.sh` twin never runs on Windows, and the suite itself checks CR with perl. macOS and Linux CI run the real case.

Local counts (Windows 11, `.scratch/session-M6-B/run-suites.sh`): test-pre-commit-steps3-10 38/0/0; test-post-push-step7 10/0/0; test-menu-parity 24/0/0; test-check-ci-suites 21/0; test-os-guards 34/0/0; test-logging.sh 36/0; test-logging.ps1 26/0/0; test-resolve-git-bash.ps1 17/0/0; `check-ci-suites.pl` "All 43 test suites are in CI or exempt". `check-pre-commit.ps1` (no -Fix, AITOOLS_LOG_DIR in scratch): 10 PASS, 6 SKIP, 3 WARN (5 platform note, 9 release notes, 11 dotprofile has uncommitted changes, not mine), 0 FAIL. `check-pre-push.ps1`: 7 PASS, 3 WARN (1, 5, 6), 0 FAIL, step 7 PASS, 38 s. Real dotprofile `deploy/` newest mtime 2026-11-13 16:04 PST (unchanged). No active git hooks (`.git/hooks` holds samples only), so committing ran nothing.

## Incident #136

Closed in PR #154 (`closedIn` "PR #154 (branch fix/m6-checks, mission M6-B)", `closedDate` 2026-11-14), moved to `closed` in id order (after #82), with `correctiveAction`, `rootCause`, `preventionLayer`, `updated`; the detail fields removed per the /incident skill. Severity stays high (silent wrong behavior; a real-HOME write of the #86 class). Full old and new JSON: PR #154 body, "Review after". `meta.lastUpdated` was already 2026-11-14. JSON parses; highest id is 174.

## Files changed

`scripts/check-pre-commit.sh`, `scripts/check-pre-commit.ps1`, `tests/check-pre-commit/test-pre-commit-steps3-10.sh` (new), `.github/workflows/check.yml`, `reference/pre-commit-checklist.md`, `README.md`, `scripts/README.md`, `registries/incidents.json`, this report.

## Proposed RELEASE_NOTES rows (for M6-Polish)

Bug fixes:

| # | Severity | Fix |
|---|----------|-----|
| n | High | `check-pre-commit` step 3 with `--fix` / `-Fix` ran `build-deploy.sh` under the caller's HOME, which rebuilds the real dotprofile `deploy/`, discarded its output and exit code, staged the frozen aitools `deploy/` and reported PASS; without the flag the step advised it. Steps 3 and 10 (which diffed the frozen aitools `deploy/`) are now SKIPs in both twins, `retired: check-pre-push step 7 rebuilds into a temp dotprofile copy`; no path of the script runs `build-deploy.sh`. `--fix` / `-Fix` repairs line endings and exec bits only, and the `.sh` line-ending repair uses perl (GNU `sed -i ''` ended the run on Linux). Resolves Incident #136 |

Files created:

| File | Purpose |
|------|---------|
| `tests/check-pre-commit/test-pre-commit-steps3-10.sh` | Steps 3 and 10 of both twins never run build-deploy.sh, stage deploy/ or advise the fix flag; the whole script with the fix flag leaves a temporary HOME and dotprofile unchanged (CI: macOS bash 5 and /bin/bash 3.2, Linux, Windows) |

## Not run

- `check-pre-commit.sh` outside the harness (POSIX-guarded here); the fix flag outside the harness (by design); `check-post-push` (M6-C's scope, and not required).
- macOS / Linux runs of the new suite before CI.

## WRITE_BLOCKED / CONFLICT / INCIDENT

- WRITE_BLOCKED: none.
- CONFLICT: prompt "file and close incident #175 for item b" vs the governed incident registry (#136 open with the same defect; the registry's meta audience is "agents checking whether a deficiency has already been filed"; the /incident skill's known gap is that it lacks matching against existing incidents) -- resolved by tier 1 (the commander's governance records) over tier 2: closed #136, did not file #175. The prompt's premise ("highest id on main is 174", no incident for b) was checked and the id is indeed free; the duplicate was the issue.
- CONFLICT: auto-mode note allowing Bash file edits vs USO "Dedicated tools for file ops" -- resolved by tier 1 (commander's CLAUDE.md): Read/Edit/Write for files; one scratch python script moved the closed #136 block in incidents.json (text-level move, JSON validated) because the Edit tool could not move a block without retyping it.
- INCIDENT (not filed; for M6-Polish triage):
  - `scripts/check-lib.ps1` `ResolveGitBash` comment says "check-pre-commit steps 2 and 3"; now step 2 only (low; M6-F owns check-lib).
  - `.claude/rules/cross-platform.md` "Unrecorded" table: the `check-pre-commit.ps1` row's reason includes the bash-only `build-deploy.sh`; it no longer applies to pre-commit (low; another PR edits that rule).
  - `reference/pre-commit-checklist.md` step 4 still tells macOS users `sed -i '' 's/\r$//' <file>` (works on BSD sed only; fine for macOS, wrong if copied on Linux; low).
  - `reference/claude-code-effectiveness.md:129` says pre-commit "step 3+10 catch stale builds" (historical RCA text; left as history).

## Open questions (each with a suggested answer)

1. Should #175 be used by M6-C instead of #176? Suggested: no; keep #176 as briefed (ids are unique, a gap is harmless) and record "#175 unused" in the orchestrator report.
2. Should step 3 instead WARN when `scripts/` or `shared/` changes are staged, as a reminder that pre-push step 7 will verify? Suggested: no; pre-push step 7 runs on every push regardless, and a WARN on most commits is noise (M5-C2 chose the same for post-push step 7).
3. Should the `.sh` twin's CRLF detection use perl so it also works under Git Bash? Suggested: no; the `.sh` twin is POSIX-guarded and never runs on Windows.

## New operational learning

- Git for Windows `grep` strips CR before matching, so `grep $'\r'` cannot detect CRLF under Git Bash; use `perl -ne '$c = 1 if /\r/; END { exit($c ? 0 : 1) }'` in tests that run there.
- GNU `sed -i '' 's/x//' f` (the BSD in-place idiom) exits 2 with "can't read s/x//"; use `perl -pi -e` on both.
- A pwsh started with USERPROFILE pointed at a temp HOME writes `AppData/Local/Microsoft/PowerShell/StartupProfileData-NonInteractive` under it at every start; a byte-for-byte HOME snapshot must exclude that path.
- Overriding LOCALAPPDATA breaks the Python install manager's `python` launcher ("No runtime installed that matches 3"), so check steps that call python FAIL in such a run; harmless for steps that do not.
- Before filing a pre-assigned incident id, parse the registry for an existing entry on the same defect: #136 had been open for this item since 2026-10-21.
