# S3-FanoutImpl-Cursor hand-back (FO-5)

Version 1.0, 2026-10-27, by S3-FanoutImpl-Cursor (level 2, delegated by S3-FanoutImpl).

## Round 2 (v1.1, 2026-10-27)

I fixed every finding the commander's delegate asked for (review, audit A and audit B on PR #123):

- **Commit:** cb4d986, then merges of FO-4 282c28b, FO-1 f69e2db and ec6c4ac, and main 167dcbe.
- **Head:** 096a8bf. CI is green on macos, linux and windows; the PR is CLEAN.
- **Mapping comment:** https://github.com/nobul-tech/aitools/pull/123#issuecomment-6435073458

Local runs after the merges:

| Suite | bash 5 + pwsh | /bin/bash 3.2 |
|---|---|---|
| rules-fanout-cursor | 215 passed, 0 failed | 140 passed, 0 failed |
| skills-fanout | 210 passed, 0 failed | 85 passed, 0 failed |
| fanout-lib | 336 passed, 0 failed | 122 passed, 0 failed |
| b8-consumers | 60 passed, 0 failed | 60 passed, 0 failed |
| managed-files | 57 passed, 0 failed | - |
| claude-mdm | 38 passed, 0 failed | - |
| rules-fanout | 118 passed, 0 failed | - |
| deploy-harness-mdm | 67 passed, 0 failed | - |

pre-commit and pre-push fail only on their known steps (6 and 7).

Conflict and deviations:

- `CONFLICT: delegating agent's text "n/a (nothing to fan out)" vs its stated goal "step 4 and step 5 write consistent row text" -- resolved by tier 2 (prompt): step 5's text now comes from the FO-1 tracker (f69e2db) as "n/a (nothing to deploy)", so step 4 uses the tracker's text too. Two different texts for one case was what B6 flagged. It is a one-line change to the other wording if wanted.`
- B1 fix: the suggested `[System.IO.File]::Exists` is also True for a dangling link on pwsh 7 (probed with `exists-probe.sh`), so I used the lib's `Get-FanoutEntryType -Follow` instead.
- Review 3: the case-insensitive lookup was tested on APFS, which is case-insensitive. The test still tells old from new: the old lookup reported the manifest name `Gone.mdc`, the new one reports the on-disk name `gone.mdc`. The fully case-sensitive path was checked by reasoning only (Linux CI runs it).

## Summary

1. `setup-user-cursor.sh/.ps1` step 4 now fans out every rule in `~/.aitools/rules` except the retired ones. PR #110's user-level filter is reversed (FD-2, RECONCILE Q3).
2. Pruning applies to retired names only. #110's marker and legacy-content checks stay, and a backup with the same text must now be verified before removal. Each removal is recorded with the tracker outcome `removed`.
3. The script uses the FO-1 lib helpers; its own manifest reader and list helpers are deleted. The bash deploy list is read on fd 3, so the review menu prompts. A pty test and a negative control prove the fix.
4. New step 5 calls FO-4's `fanout_harness_skills "cursor skills" "$CURSOR_DIR/skills" "" ""` and its ps twin. Cursor cases were added to `tests/skills-fanout`.
5. PR #123 is open against main. Every touched suite passes locally (bash 5, pwsh, bash 3.2).

## PR

- https://github.com/nobul-tech/aitools/pull/123
- Branch `feature/fanout-cursor`, head 880749e.
- CI is green on macos, linux, windows and CodeQL; `mergeStateStatus` CLEAN.
- #123 contains #124 (FO-4 5267e9e) and FO-1 32a1354.
- Commits:
  - f67fde4 rules
  - c5d1bd8 step 5
  - c108954 no-row assertion
  - merges of FO-2, FO-4, FO-1 and origin/main 613f0be
- Review diff: `git diff origin/feature/fanout-claude-skills...880749e`

## Files changed

- `scripts/setup-user-cursor.sh`, `scripts/setup-user-cursor.ps1`
- `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh`
- `tests/skills-fanout/test-skills-fanout.sh` (cursor cases added only)
- `tests/fanout-lib/test-fanout-lib.sh`: FO-1's file. The rr cases compared against the deleted copy.
- `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`: FO-2's file. The header check expects "five things", and I resolved the merge conflict in its header comment when merging FO-2 into FO-3.
- `.github/workflows/check.yml`: new macOS /bin/bash 3.2 step for rules-fanout-cursor.

## Verification

All runs were local on macOS, from `.scratch/session-focur/final/`, after FO-4 was merged:

| Suite | Result |
|---|---|
| rules-fanout-cursor | 198 passed, 0 failed, 1 skipped |
| rules-fanout-cursor, 3.2 | 133 passed, 0 failed |
| skills-fanout | 158 passed, 0 failed, 1 skipped |
| skills-fanout, 3.2 | 65 passed, 0 failed |
| fanout-lib | 358 passed, 0 failed |
| fanout-lib, 3.2 | 128 passed, 0 failed |
| managed-files | 57 passed, 0 failed |
| b8-consumers | 60 passed, 0 failed |
| b8-consumers, 3.2 | 60 passed, 0 failed |
| claude-mdm | 38 passed, 0 failed |
| rules-fanout | 118 passed, 0 failed |
| deploy-harness-mdm | 67 passed, 0 failed |
| profile/test-lib.sh | 361 passed, 0 failed |

Other checks:

- Negative control (`neg-pty.sh`): with the here-string loop restored, there is no prompt and the local edit is lost.
- `check-pre-commit`: only the known step 6 FAIL.
- `check-pre-push`: only the known step 7 FAIL.

## Not run

- Windows pwsh and Git Bash. The .ps1 was exercised only through `step4-driver.ps1` on macOS pwsh.
- Linux locally (CI covers it).
- check-post-push.

## Findings (for the lib owner / orchestrator)

- F1 (lib, FO-1): `read_harness_manifest` matches `*.md` names case-sensitively, but `rule_name_kind` is case-insensitive. A manifest line `Up.MD` is therefore rejected while the file `Up.MD` is still fanned out.
- F2 (lib): `backup_dir` / `Backup-Dir` copy only a directory that holds a top-level `*.md`. `~/.cursor/rules` holds only `.mdc` files, so its directory backup never happens (per-file `backup_file` still runs). The same holds for `~/.claude/skills` and `~/.cursor/skills`.
- F3 (lib comments): "setup-user-cursor still defines its own copies" in both libs is stale after FO-5.
- F4: until FO-6 lands, setup-user-skills also writes `cursor skills` rows and files into `~/.cursor/skills`, so two writers are live (FD-9).
- F5: the `size gate (forced)` check failed on the FO-3 head f897b74 (#120 fixture vs FO-3). FO-4 fcf6edc fixed it.

## WRITE_BLOCKED

None.

## CONFLICT

- `CONFLICT: prompt scope (tests: rules-fanout-cursor, skills-fanout, check.yml) vs deleting the script's reader (prompt "Lib API" / FAN-PLAN F1), which breaks FO-1's tests/fanout-lib rr cases -- resolved by tier 2 (prompt): kept the deletion, made the smallest edit to tests/fanout-lib (rr compares the lib wrapper with the lib reader, and fails if the script defines a copy again).`
- `CONFLICT: prompt "NOT ... FO-2 files" (implicit) vs the merge conflict and the five-things header check in tests/deploy-harness-mdm -- resolved by tier 2: the smallest edit, listed in the PR.`

## INCIDENT

- `INCIDENT: lib name-case mismatch between read_harness_manifest (*.md, case-sensitive) and rule_name_kind (case-insensitive)`. Spec deviation from the commander decision of 2026-10-22, "case-insensitive".
- `INCIDENT: backup_dir skip rule ("no top-level *.md") makes directory backups of ~/.cursor/rules and of skills directories no-ops`. Spec: config-file-safety "Directory deployment" step 2.

## Open questions (with suggested answers)

- Q1: Should Cursor rules prune also find the `.mdc` case-insensitively, as the Claude rules prune does? Suggested: yes, in a follow-up. Today it uses the exact path, which is fine on APFS and NTFS.
- Q2: none. FO-4's check.yml already runs skills-fanout on macOS (bash 5 and 3.2) and on Linux (check.yml lines 184, 188, 449), so the Cursor cases run in CI.

## Delegates used

None.
