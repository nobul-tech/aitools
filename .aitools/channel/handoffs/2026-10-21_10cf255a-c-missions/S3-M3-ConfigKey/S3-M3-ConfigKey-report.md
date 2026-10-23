# S3-M3-ConfigKey report: config.json writer on id-keyed profiles (re-key batch 4)

**Intent**: **Purpose**: Record what mission S3-M3-ConfigKey shipped (re-key design batch 4), the writer interface mission HARNESS consumes, how it was verified, and what is left open. **Scope**: scripts/setup-user-config.sh, scripts/setup-user-config.ps1, tests/profile/test-config.sh on PR #86 (feature/m3-rekey). NOT aitools-profile.*, aitools-lib.*, installers, deploy-harness. **Audience**: S3-M3Lead, mission HARNESS, the reviewer, Jose.

## Summary

- PR: https://github.com/nobul-tech/aitools/pull/86 (`feature/m3-rekey`).
- Commits: 17315bf merge of PR #89 head (`fix/m3-b3b-installer-review3`, no conflicts, merged not rebased); c1ca81e "setup-user-config writes machineId for id-keyed profiles (re-key batch 4)".
- Source: commander decisions 5 and 7; re-key design (e) and (h) batch 4; S3-M3-Resolver open question 1 (Q1); S3-M3Lead batch-4 decisions; the Resolver-review INCIDENT on advisory warnings becoming WARN rows.
- test-config.sh: 169 passed, 0 failed (was 85/4 on CI).

## Interface (Contract change for HARNESS)

`setup-user-config.sh` / `.ps1` remains the only writer of `~/.aitools/config.json`. Never prompts; exit 0 done (warnings possible), 1 any error; never 2.

| Item | Contract (changes marked NEW) |
|---|---|
| Arguments | `--repos-path`/`-ReposPath`, `--repo-path`/`-RepoPath` (absolute), `--drives-json`/`-DrivesJson` (JSON array), `--github-user`/`-GithubUser`, `--user-repo-path`/`-UserRepoPath` (absolute), NEW `--machine-id ID`/`-MachineId ID` (this machine's profile key, any case; passed to the resolver as its override), `--dry-run`/`-DryRun`, `--force`/`-Force` (no effect), `--help`/`-Help`. No arguments: re-derive from profile.json. |
| Deprecated | `--machine-alias A`/`-MachineAlias A` accepted for one release (alias or key); logs `[detail] deprecated flag: ...`. NEW: both flags together = ERROR `bad arguments`, exit 1. The old writer's flag was `--machine-alias`, not `--alias` (the launch prompt's name); I kept the real old flag and added no `--alias`. |
| Env vars | unchanged (see PR #89 interface). |
| Files | read `~/.aitools/config.json`, dotprofile `profile.json` via `aitools-profile.* derive-config`; write config.json: temp -> validate -> backup -> move; dry run writes nothing under ~/.aitools. |
| config.json fields | version, meta, reposPath, repoPath, googleDrives, githubUser, userRepoPath, NEW `machineId` (resolver `derived.machineId`: the matched key, only for this machine's id-keyed profile), `machineAlias` (now display only, one release; still the cache for a 2.1 alias-keyed profile). Derived fields are kept when the derivation does not yield them, with one exception (review fix): when the derivation matched a profile (derived machineAlias set) but yields no machineId (a 2.1 alias-keyed profile, or a chosen profile that is not this machine's), a cached machineId is stale and is removed (info line `cached machineId "..." removed`), so resolver step 4L stays usable. New keys on an existing file are appended (an existing file with `meta` gets machineId after meta: cosmetic). |
| Summary rows | OK created/updated/verified/dry-run; WARN `rebuilt (was invalid)`; an OK row turns WARN only after a real warning (NEW). ERROR rows unchanged. DETAIL `<key> updated` now includes machineId. |
| ACTION rows | NEW: at most one advisory ACTION, written after the config row with one paired, counted `log_warn`: `Run: aitools user init (registers this machine)` (matched profile has no machine.id) or `Run: aitools user init (re-keys machine profiles by machine id)` (2.1 alias-keyed profile; the resolver says `run: aitools-profile migrate`) or `Run: aitools user init (updates this machine's profile)` (stored hostname differs: rename/clone signal, itself a real warning). Precedence init > re-key > update; never two. Error-path ACTIONs unchanged. **Merge condition: the re-key advice is true only once batch 5 makes user init call `migrate`; PR #86 must not merge before batch 5** (today's user init resolves a legacy entry with this id via=id and never re-keys it -- `scripts/aitools` ui_register_flow). |
| Warning routing | handled (config.json-related, shared-only, githubUser guess) -> info; advisory (the two above) -> info "(see ACTION)"; real (rename/clone signal, duplicate alias, hostname-only match, undetectable id, key/machine.id mismatch, other-machine profile, ...) -> `log_warn`, counted. |
| Callers | `scripts/aitools:1296,1302` and `scripts/aitools.ps1:1261` (user init) pass the old flag: still works; batch 5 should switch to `--machine-id <key>` / `MachineId`. Installers pass neither flag: no installer change needed. |

What changed for HARNESS, in four lines:
1. Pass `--machine-id <key>` / `-MachineId <key>` (old alias flag works one more release).
2. config.json gains `machineId`; `machineAlias` is display only.
3. The unregistered / run-migrate advice is one ACTION row; the config row stays OK.
4. Exit codes, env vars, files and dry-run behaviour unchanged.

Why the migrate ACTION names `aitools user init`: design (f) and batch 5 (h) make user init call `migrate` when legacy entries exist; it is the user-facing command (aitools-profile.sh is not on PATH). Correction to my first draft: today's user init does NOT re-key a legacy entry with this id (it resolves via=id and skips register), so the advice depends on batch 5 -- hence the merge condition above (reviewer finding 1, verified with `grep -n migrate scripts/aitools`).

Why the ACTION goes after the config row: script-standards-detail.md "Severity decision guide" says ACTION is always paired with a `log_warn`, and `write_summary` promotes an OK row to WARN once WARNINGS > 0. Writing the pair after the row keeps the row about the write (OK) while the warning is still counted (footer `COMPLETED with 1 warning(s)`, installer relay counts 1).

## Tests (tests/profile/test-config.sh)

- Fixtures re-keyed to revision 2.2: `profiles.<lower-cased id>` with `alias`, plus an unclaimed 2.1 `laptop` entry; `write_profile` builds every variant.
- Updated: c1 (machineId in the exact layout, 0 ACTION), c3 (machineId DETAIL + position), c4 (salvage + machineId), c7 (another id's profile; 1 ACTION; no machineId), c13 (2.1 entry without machine.id: OK row + one ACTION + `COMPLETED with 1 warning(s)`).
- Review fixes (commit 2): c10 asserts `via=override` (the flag reaches the resolver); c18 asserts the update advice; c20 stale machineId removed; c21 machineId salvaged from a corrupt config; `out_has` checks the pwsh output too (footer counts in both shells).
- New: c10 `--machine-id` (upper-case id selects the lower-case key), c10b deprecated `--machine-alias` (detail line, one ACTION), c10c both flags, c10d unknown id, c17 legacy 2.1 profile (Resolver Q1: one ACTION `Run: aitools user init (re-keys ...)`, zero WARN rows, no machineId), c18 real warning (WARN row, 2 counted warnings), c19 undetectable id (via=config keeps machineId).
- Installer Step 5 relay cases (from #89) still pass: the C13 fixture now yields exactly 1 counted warning (the ACTION's).

## Verification (tested: macOS, isolated HOME under .scratch/session-CfgKey)

- `bash -n` (bash 5, /bin/bash 3.2) on the writer and the test; pwsh parser on the .ps1: clean.
- test-config.sh 169/0 on c1ca81e, 190/0 after the review fixes (pwsh parity: config bytes and rows identical); /bin/bash 3.2 `--bash-only` 109/0, then 121/0.
- test-profile.sh 689/0 (bash 5 and `AITOOLS_TEST_BASH=/bin/bash`); test-lib.sh 40/0; tests/logging sh 24/0 (bash 5 and 3.2), ps 15/0 (5 skipped).
- Probe: legacy profile, both shells: identical output, `OK|aitools config|created` + one ACTION.
- check-pre-commit: FAIL step 6 (known); WARN step 11 (uncommitted changes in the live dotprofile /Users/new-jose/repos/aitools-nobul-jose -- not from this work; also seen by S3-M3-Resolver); step 20 passes now (the #89 merge brought #78's fix). check-pre-push: FAIL step 7 (known).
- CI (`gh pr checks 86`) on c1ca81e: all green -- linux pass (6m15s), macos pass (6m10s), windows pass, CodeQL + Analyze (actions, js-ts, python) pass. The review-fix commit's CI is reported in the hand-back.

## Review

- Reviewer: S3-M3-ConfigKey-Review (independent, level 3, no isolation, not given this report). Review: https://github.com/nobul-tech/aitools/pull/86#pullrequestreview-5621581060 ; file `../S3-M3-ConfigKey-Review/S3-M3-ConfigKey-Review-pr86-batch4.md`.
- Verdict on c1ca81e: approve-equivalent, condition: #86 does not merge before batch 5. 0 blockers, 1 major, 4 minors, 3 nits.
- Major 1 (migrate advice names a command that does not migrate yet): accepted as a merge condition (PR body + this report), wording kept per the lead decision; code comment added.
- Fixed: minor 2 (stale machineId removed, c20), minor 3 (c10 asserts via=override), minor 5 (c21 salvage), nit 6 (separate rename/clone advice), nit 7 (pwsh footer asserted), nit 8 (ordering comment).
- Minor 4 (stale intent texts): drafted below, not written (protected).

## Not run

- Windows, Git Bash (CI windows job covers what it covers).
- user init end to end with `--machine-id` (batch 5).

## Drafts for approval (protected: intent statements; not written)

1. setup-user-config.sh header `Intent:` (lines 4-11):
   - old: `... derived from the dotprofile's profile.json by aitools-profile.sh (dotprofile path, GitHub user, machine alias and how it was chosen). ... NOT an interactive prompt (callers prompt, then pass --machine-alias).`
   - new: `... derived from the dotprofile's profile.json by aitools-profile.sh (dotprofile path, GitHub user, this machine's profile key -- machineId -- with its display alias, and how they were chosen). ... NOT an interactive prompt (callers prompt, then pass --machine-id).`
2. setup-user-config.ps1 header `Intent:`: same, with `aitools-profile.ps1` and `-MachineId` (old: `-MachineAlias`).
3. config.json `meta.intent.scope` (`CONFIG_INTENT_JSON` in .sh, `$configIntentJson` in .ps1, identical text):
   - old: `... values derived from profile.json (githubUser, userRepoPath, machineAlias). ...`
   - new: `... values derived from profile.json (githubUser, userRepoPath, machineId, and machineAlias as a display value). ...`
   Applying it rewrites every machine's config.json once (meta differs), with a backup.

## Open questions (with suggested answers)

1. Merge order: batch 5 (S3-M3-UserInit) must land on #86 before it merges, or the re-key ACTION never clears on the live 2.1 dotprofile. Suggest S3-M3Lead records this in the merge order (section 4 of the plan).
2. Should an explicit `--machine-id` that resolves to another machine's profile (owner other) be refused by the writer? Today it saves that profile's alias as `machineAlias` (no machineId: derive-config yields it only for owner this), same as the old flag. Suggest: refuse in batch 5's caller, not here (the writer has no owner input today; adding it means reading `owner` from derive-config -- small, can be a follow-up).
3. Approve the three intent drafts above? Suggest yes, in batch 8 (docs) or as a fix-up on this PR.

## INCIDENT markers (not filed)

- `INCIDENT:` script-standards-detail.md "Severity decision guide" pairs every ACTION with a `log_warn`, but never says `write_summary` auto-promotes OK to WARN once a warning is counted, so an advisory ACTION turns every later OK row of the same script into WARN; callers must order rows by hand (this batch: ACTION after the row, with a comment). Also raised by the reviewer. Needs a stated rule.
- `INCIDENT:` the launch prompt named the old flag `--alias`; the writer's real flag is `--machine-alias` (PR #89 interface). Prompt/spec drift between missions.

## WRITE_BLOCKED

None. (One Bash call refused by standing-order-guard for `&&`; split into separate calls as prescribed.)
