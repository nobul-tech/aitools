# S3-M3-B5a report: deploy/ resolves the dotprofile and machine profile on the target machine

**Intent**: **Purpose**: Record what S3-M3-B5a changed on PR #95, why, how it was verified, the review outcome and the follow-ups. **Scope**: scripts/build-deploy.sh; scripts/check-pre-push.sh/.ps1 step 7. NOT the B5b re-key or profile-check.js. NOT setup-user-*, aitools-lib.*, aitools-profile.*, deploy-harness.*. **Audience**: S3-M3Lead, reviewer, Jose.

## Summary

PR: https://github.com/nobul-tech/aitools/pull/95. Branch: `feature/m3-b5-build-deploy`, made from #83 with the #91, #92 and #90 heads merged in. Merge it after those PRs or together with them; #91 and #92 must not land without it. Commits:

| SHA | What |
|---|---|
| c421511 | The main change |
| 266a1ba | Step 7 log pointer + deploy-paths.md draft |
| ff6e7dd | Review fixes m1-m3, n1 |

1. **Dotprofile from the entry point.** build-deploy takes `AITOOLS_USER_REPO_PATH`. A standalone run asks `resolve_user_repo_path` in a child bash, which returns the path on fd 3. No config.json read (L8 / SD-7).
2. **No build-time interpolation.**
   - Removed: the hardcoded Jose/Nobul defaults and the node alias/hostname/first-profile lookup with its `eval`.
   - The generated `setup-user-claude.sh/.ps1` are now pure extracts of scripts/, which removes this pair's I6 duplication.
   - A generated source block decides where the values come from. With the dotprofile on the machine: the live dotprofile. Without it: the build-time profile snapshot, template and rules.
3. **Embedded resolver (B8a INCIDENT).** `aitools-profile` + `aitools-lib` + `aitools-json`, both the .sh and .ps1 sets, are copied from scripts/ at build time into the claude, settings and cursor deploy scripts.
   - At runtime they go to a temp dir, and `AITOOLS_PROFILE_SH` / `AITOOLS_PROFILE_PS1` point at it.
   - A resolver dependency that is not embedded fails the build.
4. **H1.** The embed sits outside the inliner scan, and the inliners replace only the first line that loads the lib.
   - This also fixed a live bug: the deployed aitool-ops SKILL.md held the whole lib, because the line "Hooks cannot source `aitools-lib.sh`" was replaced by it.
   - PowerShell embeds are `|`-prefixed, so a source line starting with `'@` cannot end the here-string.
5. **Cursor.** The body is extracted whole; only its two preference defaults become the build-time values.
6. **Build safety.** The build goes to a staging dir and replaces deploy/ only at the end (review m1).
7. **Step 7.**
   - H5: the build gets an explicit temp `AITOOLS_USER_REPO_PATH`, and `AITOOLS_PROFILE_FILE` / `AITOOLS_MACHINE_ALIAS` / `AITOOLS_SUMMARY_FILE` are unset.
   - M7: the trigger includes `aitools-profile.*` and `aitools-json.*`.
   - Smoke run: dry runs of claude, settings and cursor, plus an endpoint (no-dotprofile) claude run that must use the snapshot.

## Before (baseline, at f2dcaa9)

Checked with `.scratch/session-B5a/baseline.sh` on a two-profile fixture:
- **build-deploy.sh:156-173 and :207-252** read `~/.aitools/config.json` through node. The build logged `Profile interpolation: name=One & /…/home \1` for every machine: profile m1, with `$HOME` expanded by the `eval`.
- **Generated settings** exited 1 with `ERROR|dotprofile|resolver missing`.

## Smoke check placement

The smoke check runs in step 7, not in build-deploy:
- build-deploy stays a pure generator.
- It runs inside every `aitools` run, where executing the generated scripts would be slow and would act on the machine.
- Step 7 already owns "the built deploy/ is right".

build-deploy keeps only structural invariants: the resolver is embedded exactly once, the dependencies are covered, and PS1 ParseFile passes.

## Cross-machine result (the defect B5 fixes)

**`verify.sh`: 75/0 under bash 5 and 75/0 under /bin/bash 3.2.**
- **With the dotprofile:** for machines m1 and m2, deploy/ gives a CLAUDE.md byte-identical to scripts/, with identical rules and summary. Each machine gets its own name, company and footer `profile m1|m2`.
- **Endpoint without the dotprofile:** each machine resolves its own profile from the snapshot. An unregistered machine gets identity values only plus an ERROR row.
- **Other cases:**
  - rc 3 parity with scripts/;
  - the live dotprofile wins over the build-time copies;
  - an incomplete dotprofile behaves as on scripts/;
  - settings, skills and cursor results equal scripts/.

**Other harnesses:**
- **`edge.sh`: 29/0.** Covers skips, a corrupt profile.json, the delimiter guard, hostile rule names, a late failure that keeps deploy/, and determinism.
- **`ps-verify.sh`: 24/0.** The generated .ps1 ran under pwsh 7 on macOS from guard-stripped copies.
- **`step7-test.sh`: 8/0.** The real check-pre-push ran against a fixture. With the H5 sentinel exported, the sentinel dotprofile stayed untouched.

All harnesses are in `.scratch/session-B5a/` (not committed).

## Tests and checks

- **Suites:**
  - test-profile 319/0;
  - test-config 89/0;
  - test-lib 108/0 (3.2 `--bash-only` 44/0);
  - logging: sh 24/0, ps 15/0 (5 skipped);
  - managed-files sh 42/0.
- **Syntax:** `bash -n`, the pwsh parser, and the build's ParseFile pass on 21 generated .ps1 are all clean.
- **check-pre-commit:** step 6 FAIL (known). WARNs on 3, 5, 9 and 11.
  - Step 11 reports uncommitted deploy/ changes in the real dotprofile. They date from 14:46 local, before my first build, and hold no B5 marker, so they are not mine.
- **check-pre-push:** step 7 FAIL "stale" (known). Its smoke run against a copy of the real dotprofile, live and endpoint, was clean. The real dotprofile's `git diff` fingerprint is unchanged.

## Review

S3-M3-B5a-Review: https://github.com/nobul-tech/aitools/pull/95#pullrequestreview-5621746913
- **Verdict:** approve-equivalent, with 0 blockers and 0 majors. The review file is in `../S3-M3-B5a-Review/`.
- **Fixed in ff6e7dd:**
  - m1: a late failure deleted deploy/;
  - m2: the smoke run did not test the snapshot path;
  - m3: an incomplete dotprofile diverged from scripts/;
  - n1: draft wording.
- **Follow-ups:**
  - m4: PowerShell `try/finally` would avoid the temp-dir leak on an early exit. The reviewer proved that `finally` runs on `exit`.
  - n2: the dependency-scan spellings.
  - n3: the hand-written `param()`.
  - n4: the double resolve log lines.

## Not run

- **Windows:**
  - the generated .ps1 end to end;
  - check-pre-push.ps1 step 7, including its smoke run;
  - build-deploy under Git Bash.
- `aitools` end to end.
- A rebuild of the real dotprofile deploy/ (Jose, after merge).

## Protected-file drafts awaiting approval

- `S3-M3-B5a-drafts/dot-claude/rules/deploy-paths.md.edit.txt` (old -> new). It supersedes the R20 text, which named `aitools-profile.js`.

## INCIDENT markers (not filed)

- INCIDENT: build-deploy's inliners replaced every line that named the lib, including text inside embedded content. The deployed `aitool-ops` SKILL.md (MDM path) carried ~2,700 lines of aitools-lib. Spec: deploy-paths.md "equivalent results". Fixed in c421511; it shipped on every build before that.
- INCIDENT: check-pre-push step 7 failure messages said "see checks.log", but its detail lines go to deploy.log (`check_log_init` sets `LOG_FILE` to deploy.log). Fixed in 266a1ba.
- INCIDENT: check-pre-commit step 13 still treats setup-user-claude and setup-user-cursor as duplicated deploy templates (check-pre-commit.sh around :267). Open, and outside my files.

## Open questions (with suggested answers)

1. **Should `aitools` / `aitools.ps1` export `AITOOLS_USER_REPO_PATH` before build-deploy?** Suggest yes, by the UserInit owner (#86). Today build-deploy falls back to the resolver.
2. **Does the PowerShell resolver's `$HOME` follow `USERPROFILE` in the Windows step 7 smoke run?** The reviewer raised it (`aitools-profile.ps1:244,294`); the answer is unknown. Suggest checking it in the Windows pass and preferring `$env:USERPROFILE` on Windows, owned by the Resolver mission.
3. **Should m4 (PowerShell `try/finally` around the generated body) be done now?** Suggest a follow-up batch. It changes every generated .ps1's structure and needs a Windows run.

## Delegates

- S3-M3-B5a-Review: independent, no isolation, launched without my report.
- I verified its m1 against the code: the cursor checks ran after the `rm -rf`.
