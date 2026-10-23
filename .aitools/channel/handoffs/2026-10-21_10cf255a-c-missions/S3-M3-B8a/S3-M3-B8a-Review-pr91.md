# S3-M3-B8a-Review: independent review of PR #91 (commit e639df2)

Reviewer: S3-M3-B8a-Review (level 3, delegated by S3-M3-B8a). Date: 2026-10-22.
Scope: e639df2 only -- `scripts/setup-user-settings.sh`, `scripts/setup-user-settings.ps1`,
`scripts/setup-user-skills.sh`. The lib wrappers (#80) were read only as the contract.

## Verdict

**Request changes -- merge gate only.** The caller code is correct: contract use, rc
handling, counters, summary rows, bash 3.2 and set -u safety, and .sh/.ps1 parity all
held in my own probes. The one thing that blocks merge is M1: on a main that has this
PR but not B5, every `aitools` run regenerates a dotprofile `deploy/setup-user-settings.*`
that always fails. Merge only after B5 (or with a stopgap). No code change to the three
files is required for that, so once B5 is in, this can merge as it is. Minors and nits
are optional.

## Findings

### Blockers

None.

### Major

**M1 -- MDM path: generated `deploy/setup-user-settings.sh/.ps1` always fails until B5;
regeneration is automatic, not opt-in.**
- `scripts/setup-user-settings.sh:66-68`: the resolver call sits inside the
  `BEGIN/END settings body` markers (lines 15, 147). `scripts/build-deploy.sh:1021-1025`
  extracts that body and inlines the lib. `build-deploy.sh` has no `aitools-profile` or
  `AITOOLS_PROFILE_SH` reference (my grep of the file found nothing). The inlined
  `_aitlib_profile_run` looks for `$d/aitools-profile.sh` next to the deploy script
  (`aitools-lib.sh:158-159`), and that file is not there.
- Evidence (`probe-deploy.sh`, isolated HOME, fixture dotprofile): build-deploy exit 0,
  42 scripts, `no aitools-profile.* in deploy/`. The generated
  `deploy/setup-user-settings.sh` then exits 1 with `ERROR|dotprofile|resolver missing`
  and `ERROR|claude settings|not synced: dotprofile error`, and writes no settings.json.
  The .ps1 has the same dependency (`Invoke-AitLibProfile` uses
  `Join-Path $PSScriptRoot "aitools-profile.ps1"`, `aitools-lib.ps1:128`). I did not run
  the generated .ps1, so that part is inferred from the code.
- Why this is major: the PR's follow-up says "do not regenerate the dotprofile deploy/
  from a main that has this PR but not B5". Nobody can honour that by hand.
  `scripts/aitools:1524-1531` (Step 2) and `scripts/aitools.ps1:1438` run
  `build-deploy.sh` on every `aitools` run, and `build-deploy.sh:187-188` writes into
  `<userRepoPath>/deploy`.
- Fix options (pick one): (a) merge B5 first and rebase this PR onto it; (b) as a
  stopgap in this PR, have build-deploy copy `aitools-profile.sh/.ps1` and
  `aitools-json.pl` into deploy/ next to the generated scripts (B5 owns build-deploy, so
  it would need that mission's agreement); (c) hold the merge. Suggested: (a). Record
  the merge order in the PR body as "Depends on: #80, B5 PR".

### Minor

**m1 -- A stale or invalid config.json now shows only as "No dotprofile found"; the
cause is a deploy.log detail line.**
- `setup-user-settings.sh:76-78` / `.ps1:62-64`. Probes `settings-stale` and
  `settings-badjson` (bash 5, bash 3.2, pwsh): the console shows only
  `[warn] No dotprofile found (shared-only mode; run 'aitools user init')`. The real
  cause (`config.json userRepoPath does not exist: …` / `config.json is invalid JSON …`)
  goes to deploy.log as `[detail]` only, because the lib logs resolver warnings as detail
  lines (`aitools-lib.sh:269`, D-TS12).
- This is not a regression: the old text "No user repo configured" was just as vague.
  But a stale userRepoPath is the most likely real-world shared-only cause, and running
  `aitools user init` does not obviously fix a stale path.
- Suggested: add "(see deploy.log)" to the rc 1 log_warn in both shells. Or accept it,
  on the grounds that setup-user-config, which runs first in every run, reports the
  warnings once. If you accept it, say so in the PR.

**m2 -- No committed regression test for the three callers' rc paths.**
- The author's smoke script lives in `.scratch/session-B8a/smoke.sh` (gitignored).
  `tests/profile/test-lib.sh` covers the wrappers, not these callers. The rc 1 / rc 3
  branches at `setup-user-settings.sh:72-78`, `.ps1:58-64` and `setup-user-skills.sh:53-56`
  are untested in CI. B8b/B8c will add more callers of the same shape.
- Suggested: a small `tests/profile/test-callers.sh` (isolated HOME; cases none / config
  / env-missing / resolver-missing; assert exit code, summary rows, and the absence of
  `deploy failed`). My `probe.sh` here can serve as a starting point. This could also be
  a follow-up issue.

### Nits

**n1 -- The settings and skills scripts report a resolver error differently.** For rc 3,
settings adds its own `ERROR|claude settings|not synced: dotprofile error`
(`setup-user-settings.sh:75`). Skills adds nothing: its rows stay
`OK|claude skills|15 added` with the info line only (`setup-user-skills.sh:53-56`; probes
`skills-envmiss` and `skills-nores`). Both are defensible, because the lib's
`ERROR|dotprofile` row is there and the exit is 1. Still, a reader of the summary panel
can't tell that the skills run dropped the dotprofile skills. Optional: in skills, a
`WARN|claude skills|shared only: dotprofile error` row (30 chars). Or accept the
difference and note it.

**n2 -- The summary panel lost the remedy for rc 1.** The old row text
`no profile (run aitools user init)` (34 chars, over the limit) carried the instruction.
The new `not synced: no dotprofile` (25 chars) does not, so the remedy is now only in the
console line. Shared-only is a legitimate mode, so an ACTION on every run would be noise.
Keeping it as it is seems right to me. Flagged so the choice is deliberate.

**n3 -- A stale comment in a file owned by B5.** `scripts/build-deploy.sh:1015` still
says "Resolves profile.json at runtime via config.json userRepoPath". After this PR that
is false. Hand it to B5 together with M1.

**n4 -- New behaviour: settings writes to a dotprofile found by scan or convention.**
SD-7, as intended. With config.json stale but `<reposPath>/aitools-<githubUser>` present,
or with exactly one `aitools-*` repo holding a profile.json, settings now syncs against
that repo (probes `settings-staleconv` via=convention and `settings-scan` via=scan:
`OK|claude settings|created`). `sync_managed_json` can auto-adopt live-only leaves into
that profile.json. I did not probe the adopt-into-a-scanned-repo path (my live
settings.json was always absent). This is resolver policy (#73), not a defect here.
Listed because this PR is the first caller that writes to the resolved dotprofile.

**n5 -- Out of scope, seen in passing.** The generated `deploy/setup-user-skills.sh`
contains the inlined lib twice: the lib's contract comment appears at lines 147 and 4587
of my probe build. I did not check whether main has the same, so this is unknown and for
B5 to look at.

## Checklist results (what I verified, with evidence)

| Check | Result | Evidence |
|---|---|---|
| rc captured, no `\|\| true`; global copied right after the call | OK | `settings.sh:66-68`, `skills.sh:50-52`, `settings.ps1:54-55` |
| PS rc is a scalar (no output-stream leak into `$urpRc`) | OK | Instrumented copy printed `type=System.Int32 count=1` for rc 0, 1 and 3 |
| No caller ACTION row | OK | No `write_summary ACTION` in the diff. The lib's `resolve_user_repo_path` writes no ACTION either (`aitools-lib.sh:260-283`), so no ACTION appears for a dotprofile error. That is lib design (#80), not this PR |
| Every rc path writes a summary row | OK | settings: rc 0 OK created/synced/verified, rc 0 without profile.json WARN `profile.json missing`, rc 1 WARN, rc 3 ERROR. skills: tracker rows on every path plus the lib ERROR row on rc 3 |
| Counters: no double count, no false `deploy failed` | OK | rc 3: `FAILED with 1 error(s)` in settings.sh, settings.ps1 and skills.sh. `ERRORS_BEFORE_CLAUDE` is taken after the resolver (`skills.sh:151`), so no `deploy failed` row |
| set -u / bash 3.2 | OK | All 19 cases run under `/bin/bash` 3.2 and bash 5 with identical rows and exits. `AITLIB_USER_REPO_PATH` is assigned on every path (`aitools-lib.sh:261`) |
| .sh vs .ps1 parity (settings) | OK | Same rows, exits and log levels for none / config / env-missing / resolver-missing / stale / convention / no profile.json |
| Summary detail length and vocabulary | OK | `not synced: dotprofile error` 28, `not synced: no dotprofile` 25. "skipped" is not used as a row outcome |
| Extraction markers intact | OK | `settings.sh` 15/147/149/160; `.ps1` 15/135/137/148; `skills.sh` 11/38/228/230/241 |
| Direct config.json userRepoPath reads left in the 3 files | None | My grep for `config.json\|userRepoPath\|read_config_key\|ReadConfigKey` matched only `$userRepoPath` variable uses in the .ps1 |
| Behaviour change in skills (shared-only vs error) | OK, as described | rc 3: shared skills only, no dotprofile skill, no adopt offer (USER_REPO_PATH empty), exit 1 (before: exit 0 and no error). This is the intended visibility change |
| deploy/ impact | See M1 | settings breaks until B5. skills is unaffected (the resolver call sits inside the replaced `skill discovery` block, `skills.sh:38-228`) |

## What I ran (all on macOS, isolated HOMEs under `.scratch/session-B8aRv/`)

- `probe.sh /opt/homebrew/bin/bash` and `probe.sh /bin/bash`: 19 cases each, settings.sh
  and skills.sh × {none, config, env-missing (`AITOOLS_USER_REPO_PATH=/nonexistent/dp`),
  resolver-missing (`AITOOLS_PROFILE_SH=/nonexistent/...`), stale config, stale config +
  convention, convention, scan, invalid config.json}, plus settings with no profile.json.
  `env -i`, `AITOOLS_FORCE=1`, stdin `/dev/null`. Results as in the table above. Exit
  codes: rc 3 cases exit 1, all others exit 0.
- `probe-ps.sh`: a copy of `setup-user-settings.ps1` with the OS guard stripped and the
  rc type printed, pwsh 7 on macOS, `AITOOLS_PROFILE_TEST_ANY_OS=1`, cases none / config /
  env-missing / resolver-missing (`AITOOLS_PROFILE_PS1`) / stale / convention / no
  profile.json. Rows and exits match bash.
- `probe-deploy.sh`: `build-deploy.sh` into a fixture dotprofile, then the generated
  `deploy/setup-user-settings.sh` (M1 evidence).
- Not run: Windows / Git Bash; the generated `deploy/setup-user-settings.ps1`; the
  check-pre-commit / check-pre-push suites (the author reports them); the adopt path of
  `sync_managed_json` against a dotprofile found by scan.

## INCIDENT markers (not filed)

- INCIDENT: The scripts/ and MDM paths can diverge silently whenever a lib function
  depends on a file next to the lib. `build-deploy.sh` inlines `aitools-lib.sh` but not
  its sibling resolver, and no check catches it: pre-push step 7 only reports
  "dotprofile deploy/ stale". A post-build smoke run of one generated script would catch
  it. Spec: `.claude/rules/deploy-paths.md` "Two deployment methods must produce
  equivalent results".
