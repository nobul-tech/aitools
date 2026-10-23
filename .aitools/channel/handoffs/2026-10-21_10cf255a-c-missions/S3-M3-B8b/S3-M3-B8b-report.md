# S3-M3-B8b report: skills (ps1) and cursor use the one dotprofile resolver

PR #92 (https://github.com/nobul-tech/aitools/pull/92) switches the three B8b scripts to the one dotprofile resolver. The independent review found no blockers. One problem remains, and B5 must fix it.

- **The B5 problem:** the generated `deploy/setup-user-cursor.sh` now calls the resolver. Until B5 embeds the resolver or drops that call, the generated script exits 1 with `ERROR|dotprofile|resolver missing`. The cli-config merge itself is still correct.
- **Merge order:** merge #92 together with B5, or after it.
- **Overlap with PR #87:** #87 (harness cursor rules) changes the same two cursor files. `git merge-tree` against it shows no conflict.

**Branch:** feature/m3-b8b-consumers, based on #80 (feature/m3-b2-lib-wrappers), with origin/main merged in.

**Commits:**
- 1554d80: the switch.
- A second commit: the review fix m1 and this report.

## Former config.json reads (base 28e0f5b + origin/main)

| File:line (before) | Read | Now |
|---|---|---|
| scripts/setup-user-skills.ps1:39 | `ReadConfigKey ... config.json -Key "userRepoPath"` | `$urpRc = Resolve-UserRepoPath`; `$userRepoPath = $script:AitLibUserRepoPath` |
| scripts/setup-user-cursor.sh:196-199 | node read `~/.aitools/config.json`, then `cfg.userRepoPath` | bash `resolve_user_repo_path` copies `AITLIB_USER_REPO_PATH` and passes node `"$USER_REPO_PATH" "$URP_RC"` (argv[4], argv[5]) |
| scripts/setup-user-cursor.ps1:165-170 | `Get-Content config.json`, then `$cfg["userRepoPath"]` | `Resolve-UserRepoPath` inside the profile-preferences block |

What each script does with the resolver's return code:

- **rc 0 (found):** use the dotprofile.
- **rc 1 (shared-only):** use defaults or shared skills. Nothing is counted.
- **rc 3 (resolver error):** the wrapper has already counted the error and written the ERROR row `dotprofile`. It writes no ACTION row for the dotprofile.
  - skills.ps1 deploys shared skills only, the same as B8a's skills.sh.
  - cursor skips the `cli-config.json` merge rather than write default preferences over the user's own, and writes the row `ERROR|cursor cli|skipped (dotprofile error)`. The error is not counted a second time.

## Logging audit (touched paths, decision 3)

- **cursor.sh:** a `profile.json` read error used to go to node stderr, so it was never logged or counted. It is now a `WARN:` line, which becomes `log_warn`. A missing `profile.json` is a `DETAIL:` line.
- **cursor.ps1:**
  - `Get-Content -ErrorAction Stop` now sits inside the try.
  - A missing `profile.json` is a `LogDetail`.
  - The type checks now match the .sh. vimMode is used only when it is a bool and model only when it is a string; a string "false" was previously read as `$true`. A non-object `cursor` or `cursor.cli` is ignored (review m1).

## Verification (macOS, isolated HOME)

- **Syntax:**
  - `bash -n`, under bash 5 and /bin/bash 3.2: clean.
  - pwsh parser: clean, including after the m1 fix.
- **setup-user-cursor.sh smoke test:** 26/0 under bash 5 and 26/0 under /bin/bash 3.2. Cases:
  - no dotprofile;
  - fixture dotprofile;
  - re-run;
  - corrupt or missing `profile.json`;
  - missing resolver;
  - stub resolver error;
  - stale config path;
  - --dry-run.
- **PS1 blocks:** 13/0. The blocks were extracted and run with the real lib and a stub resolver that delegates to `aitools-profile.sh`. The 13th case was added for m1.
- **tests/profile:**
  - test-profile 319/0;
  - test-config 89/0;
  - test-lib 108/0;
  - test-lib on /bin/bash 3.2 (`--bash-only`) 44/0.
- **tests/logging:** bash 24/0; PowerShell 15/0 (5 skipped).
- **build-deploy probe** (isolated HOME, fixture dotprofile):
  - The generated .ps1 has no resolver call.
  - The generated .sh merges with the embedded prefs but exits 1, as described above.
- **check-pre-commit:** step 6 fails; this is known and was there before.
- **check-pre-push:** step 7 fails; also known.

Harness scripts are in `.scratch/session-B8b/` (`smoke-cursor.sh`, `smoke-ps.sh`, `ps-block.ps1`, `sh-resolver.ps1`, `deploy-probe.sh`).

## Not run

- Windows end to end for both .ps1 scripts.
- build-deploy against the real dotprofile (B5 owns build-deploy).

## Review

S3-M3-B8b-Review: https://github.com/nobul-tech/aitools/pull/92#pullrequestreview-5621231069

**Verdict:** no blockers.

| Finding | What it says | Status |
|---|---|---|
| M1 | The generated deploy .sh exits 1 | Owned by B5; flagged in the PR body |
| m1 | .ps1 and .sh disagree on non-object `cursor` / `cli` | Fixed |
| m2 | Plan item L8 (the generated settings/skills PS1 blocks in build-deploy) | Belongs to B5 |
| n1, n2 | Backup and parse still run before the rc-3 skip | Harmless; left as they are |
| n3 | node-missing and dry-run paths write no summary row | Was already there before this PR; not touched |
| n4 | Unused node arguments in the deploy copy | Goes away with the M1 fix |

## Follow-ups and open questions

1. **B5:**
   - Embed the resolver in the generated deploy scripts (`AITOOLS_PROFILE_SH`) or drop the cursor.sh resolver call from deploy. B8a's setup-user-settings.sh very likely needs the same.
   - Switch the generated PS1 settings/skills blocks off config.json (L8).
   - I suggest embedding the resolver, because settings needs it anyway.
2. **Lib:** a dotprofile resolver error writes no ACTION row; the machine-profile resolver does. I suggest `_aitlib_action_once "see deploy.log -- the dotprofile could not be resolved"` in the B2 lib.
3. **skills on rc 3: decided and applied.** S3-M3Lead decided that on a resolver error `setup-user-skills.ps1` skips the skills deploy entirely: the error is logged and counted, and the run gets the ERROR row `skills | skipped (dotprofile error)`. rc 1 still deploys shared skills. Applied in the third commit on this branch; the PS1 block harness passes 16/0. B8a gets the same instruction for the .sh.
   - S3-M3Lead also answered the other two questions. Q1: B5 embeds the resolver (queued). Q2: queued for the lib batch.

INCIDENT: none. (The deploy-template duplication behind M1 is the known I6 debt.)
WRITE_BLOCKED: none.
