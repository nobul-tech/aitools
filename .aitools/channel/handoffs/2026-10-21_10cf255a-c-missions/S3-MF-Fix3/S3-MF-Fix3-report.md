# S3-MF-Fix3 report

**Intent**: **Purpose**: Record what S3-MF-Fix3 shipped (audit A-10 and A-11, PR #98 review m1, PR #108 review n-2; M3-FINISH item 7), how it was verified and reviewed, and what is still open. **Scope**: scripts/setup-user-config.sh/.ps1; the message text of two states in scripts/aitools-profile.sh/.ps1; tests/profile/test-config.sh and test-profile.sh; PR #114. NOT other audit findings. NOT the lib or user init. **Audience**: S3-M3Finish, Jose.

## Summary

- PR: https://github.com/nobul-tech/aitools/pull/114
- Branch: `fix/mf-audit-config`. It is origin/main 8a9dcb5 plus `--no-ff` merges of #98 and #108, plus commit 93569b2. Merge it after #98 and #108.

## Items

All four were confirmed in the code before fixing. None were rejected.

| id | status | evidence |
|---|---|---|
| A-10 | fixed | Each section-1 ACTION now has a log line naming its row and carrying the instruction. The line is `log_error` / `LogError`, the level of its ERROR row: `config: profile.json invalid -- Fix profile.json ...` and `config: machine profile: no machine match -- Run: aitools user init (profiles: ...)`. Tests: C16, C23, C23e. |
| A-11 | fixed | bash `remove_config_tmp` runs after section 2. A failed removal is a counted `log_warn` with the PowerShell text. The EXIT trap checks both removals and logs failures at detail. Test: C25, bash only, with a stubbed `rm`. |
| m1 | fixed | `resolve_machine` and `migrate` in both languages now say "profile.json is not v2" or "profile.json has no profiles object". setup-user-config classifies both as an invalid profile.json, with or without `--no-machine`. Tests: test-profile rm-v1, rm-v2-no-profiles, rm-v2-profiles-array, mig-v1, mig-no-profiles; test-config C23 to C23d. |
| n-2 | fixed | A merge refused on a case twin now names both keys in the error line: `key "MachineId" differs only in case from the managed key "machineId": rename or remove it`. The row and the ACTION count are unchanged. Test: C24. |

## Assumptions (also in the PR body)

- **ACTION pairing.** Section-1 ACTIONs pair with `log_error`, because their row is an ERROR. This adds one counted error on paths that already exit 1. I did not use `log_warn`: that pairing is still undecided (I-2 / #147).
- **No version value in the message.** A probe of 14 version values found that the bash and PowerShell resolvers print some numbers differently (`1e2` / `100`, `-0` / `0`), so the message names no value.
- **A v2 file with no `profiles` object stays "invalid".** That follows the launch prompt and #98.
- **No ACTION row for a case twin.** It could appear alongside a section-1 ACTION and break "at most one ACTION".

## Verification (macOS, isolated HOME, pwsh parity)

- `bash -n` (bash 5.3 and /bin/bash 3.2) and the pwsh parser: clean.

| suite | bash 5 | bash 3.2 |
|---|---|---|
| test-config | 319/0 (was 269) | 319/0 |
| test-profile | 763/0 (was 744) | 763/0 |
| test-lib | 209/0 | 209/0 |
| test-user-init | 200/0 | 200/0 |

- check-pre-commit: 1 FAIL, step 6. This is the known harvesting file mode.
- check-pre-push: 0 FAIL, 4 checklist WARNs. Step 7 was skipped because the isolated HOME has no userRepoPath.
- CI at hand-back: windows, CodeQL and Analyze passed. linux and macos were still pending.

## Not run

- Windows / Git Bash.
- build-deploy.sh: the dotprofile `deploy/` embeds the resolver and is stale until the next build.
- A PowerShell counterpart of C25.
- The claude-code-web environment.

## Review

S3-MF-Fix3-Review (general-purpose, no isolation) was still running at hand-back. Its verdict is unknown. It will write S3-MF-Fix3-Review-pr114.md in this folder and post it with `gh pr comment 114`. That file is not committed yet. The harness forced this hand-back before the review and CI finished.

## Follow-ups

- **Advice for a v2 file without a `profiles` object.** It could be told "Run: aitools user init" when `profiles` is absent, because `register` creates it. Suggested answer: do so only when it is absent, not when it has the wrong type. This needs a commander decision.
- **Pre-existing resolver parity gap.** PowerShell treats `"version": 2.0` as v2 and bash does not. This PR does not change it.

## WRITE_BLOCKED

None.

## INCIDENT markers (not filed)

- `INCIDENT:` the resolvers' version check diverges for non-integer encodings of 2. PowerShell `Get-JText` yields `2` for `2.0` and `20E-1`, while bash reads the raw `2.0` and rejects it (probe: `.scratch/session-mffix3/probe-version.sh`). No spec says how `version` must be compared.

## Delegates

- S3-MF-Fix3-Review: general-purpose agent, no isolation.
