# S3-H2-DraftsM3b handback

**Intent**: **Purpose**: Report to S3-Harness2 which approved #96 M3 rows
(5-8, 12, 13) were written, which were held and why, and what is left. **Scope**:
Per-row status, the PR, the dotprofile commit, verification, re-approval drafts,
deferred files. NOT the approved text itself (the S3-M3-Docs approval page). NOT rows
outside 5-8, 12 and 13. **Audience**: S3-Harness2, Session Commander 10cf255a-c,
mission M3-FINISH.

S3-H2-DraftsM3b, 2026-10-22. Branch docs/m3-approved-intents from origin/main 8a9dcb5.

## Result

- PR: https://github.com/nobul-tech/aitools/pull/105
- Dotprofile commit: nobul-jose/aitools-nobul-jose 525ee49 (pushed to main; only
  claude/CLAUDE.md staged; the other session's `sessions/.DS_Store` change left alone)
- Reviewer (S3-H2-DraftsM3b-Review): NON-BLOCKING, 0 blocking, 4 minor findings, posted on #105
  as a comment review. It compared each row byte for byte with a script
  (`.scratch/session-h2rev/verify-rows.pl`): rows 7, 12 and 13 are exact, and nothing
  outside them changed. Verdict: `S3-H2-DraftsM3b-Review-verdict.md` (this folder).
  - M1, M2: open PRs #106 (relay wiring) and #103 (also touches aitools-lib). I checked
    both with gh pr list and folded them into the row 8 draft. Re-draft row 8 after both
    merge.
  - M3: the draft's grep rationale contradicted itself. Fixed.
  - M4: the PR body cites aitools-profile.sh:56; it should cite :58 on main. A citation
    nit, left as is.

## Per row

| Row | Target | Status | Evidence |
|---|---|---|---|
| 5 | setup-user-config.sh/.ps1 `CONFIG_INTENT_JSON` / `$configIntentJson` scope | Deferred to M3-FINISH. The text is still correct | Open PR #98 (feature/mf-config-no-machine, `--no-machine`) touches both files; it was opened after my first PR check and before the push. Mission order: skip, list for M3-FINISH. OLD matched once (sh:227, ps1:233). Claim holds: the writer sets machineId (setup-user-config.sh:274) |
| 6 | setup-user-config.sh/.ps1 header Intent | Deferred to M3-FINISH; re-check after #98 | Same PR #98. OLD matched once (sh:4-9, ps1:3-8). "callers ... pass --machine-id" holds on main (scripts/aitools:1027, aitools.ps1:1640). #98 adds `--no-machine` / `-NoMachine`, which user init would pass instead when it leaves the machine unregistered, so after #98 "then pass --machine-id" is incomplete |
| 7 | aitools-profile.sh/.ps1 header Intent (1a, 1b) + removal of interim "Writers:" lines | Applied verbatim | OLD matched (sh:9-19, ps1:8-16). Claims: register writes only --out (sh:56); exception-set and migrate commit (sh:1132, 1545); build-deploy reads AITOOLS_USER_REPO_PATH, else resolve_user_repo_path (build-deploy.sh:188, 200); the resolver is embedded in claude/settings/cursor .sh/.ps1 (build-deploy.sh:2210-2211) |
| 8 | aitools-lib.sh/.ps1 relay section Intent (new) | Held. Corrected draft for re-approval | "Consumed by: ... deploy-harness.sh/.ps1" is false: deploy-harness.sh:107, 109 run the writer directly; only aitools-lib and tests/profile/test-lib.sh use the lib's relay; aitools-install.sh uses its own copy (aitools-install.sh:153). Draft: `S3-H2-DraftsM3b-drafts/scripts/aitools-lib.sh.edit.txt` |
| 12 | shared/claude-shared.md, 2 lines | Applied verbatim | OLD matched (lines 36-37). The token is substituted by setup-user-claude.sh:158-159, .ps1:145-148; resolve_user_repo_path aitools-lib.sh:286, Resolve-UserRepoPath aitools-lib.ps1:218 |
| 13 | dotprofile claude/CLAUDE.md, R19 + lines 42-43 repair | Applied verbatim, commit 525ee49 | File was clean before the edit; `git pull --ff-only` up to date; both OLD blocks matched once (lines 42-43, 50-51) |

## Verification

- `bash -n` and the pwsh parser on aitools-profile.sh/.ps1, setup-user-config.sh/.ps1
  and aitools-lib.sh/.ps1: OK.
- tests/profile/test-config.sh, test-lib.sh, test-profile.sh, test-user-init.sh,
  tests/logging/test-logging.sh: PASS; tests/logging/test-logging.ps1: 15 pass, 5 skip
  (Windows-only).
- check-pre-commit: FAIL only on step 6 (known, pre-existing). check-pre-push: FAIL only
  on step 7 (known: dotprofile deploy/ stale).
- Not run: build-deploy (the dotprofile deploy/ is not rebuilt), aitools, setup-*.

## For M3-FINISH

- Rows 5 and 6 (setup-user-config.sh/.ps1): apply after #98 merges. Row 5 applies
  unchanged. Row 6: re-check "callers prompt, then pass --machine-id" against
  `--no-machine`. I suggest re-approving it as "... then pass --machine-id, or
  --no-machine when they leave this machine unregistered" (not drafted; this needs the
  commander).

## Re-approval drafts

- Row 8: `S3-H2-DraftsM3b-drafts/scripts/aitools-lib.sh.edit.txt`. Only the "Consumed by"
  sentence changes. The suggestion is to re-draft it after #103 and #106 merge, because
  #106 changes who consumes the relay. aitools-lib.sh/.ps1 are also touched by open PR
  #103 (for M3-FINISH / that PR's owner).

## Follow-ups / observations

- Row 7's consumer list leaves out the as-is copies `deploy/aitools-profile.sh/.ps1`
  that build-deploy writes for deploy/setup-user-config (build-deploy.sh:1636-1650). That
  is an omission, not a false claim.
- The S3-M3-Docs-Check INCIDENT "no entry point exports AITOOLS_USER_REPO_PATH" is
  stale on main 8a9dcb5. Both entry points now set it for the build-deploy call
  (scripts/aitools:2049, aitools.ps1:2003), so build-deploy.sh:178-179 is accurate.
  Row 7's wording ("unless its caller sets AITOOLS_USER_REPO_PATH") still holds.
- INCIDENT: mission file ownership has no lock against new PRs. #98 opened mid-mission on
  files this mission owned; only the pre-push PR check caught it.

WRITE_BLOCKED: none.
