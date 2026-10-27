# S3-H2-MDM hand-back (2026-10-22)

S3-H2-MDM to S3-Harness2. PR: https://github.com/nobul-tech/aitools/pull/111. Branch: `feature/harness-mdm-followups`. It is stacked on #100 (`feature/harness-rules-manifest` at 699eba8), so merge it after #100.

## Summary

1. **Q4.** The harness snapshot moved out of the generated scripts into `deploy/deploy-harness.payload`.
   - The scripts hold its sha256 and check it, then each record, before anything deploys.
   - Fixture build: .sh 2,279,683 → 176,200 B, .ps1 2,309,986 → 190,093 B; the payload is 2,075,245 B.
2. **Q3 + `--skip-config`.** There is one skip path in section 1 of `scripts/deploy-harness.*`.
   - The MDM build replaces the "config bootstrap check" span: when reposPath or repoPath is missing it reports `OK|config.json|n/a (no bootstrap)` and exits 0.
   - The flag reports `OK|config.json|n/a (written by installer)`.
3. **Q6.** Markers `# --- BEGIN/END <name> (extracted|replaced by build-deploy) ---` mark four spans: scope, body, config bootstrap check and dotprofile lookup.
   - `extract_markers` fails the build unless each marker is on exactly one line, in order.
   - Section 5b sits inside the last extracted span.
4. Small fix: the snapshot's own EXIT trap replaced build-deploy's BUILD_TMP trap, so BUILD_TMP leaked. MDM_TMP now lives under BUILD_TMP.
5. Tests: `tests/deploy-harness-mdm` 64/64 (from 30), `tests/deploy-harness` 76/76.
6. Review fixes in fdb5109.
   - **B1**: the truncation guard is now the first command of the generated .sh.
   - **N1-N4, N5.1, N5.3**: record-field validation, .ps1 path safety, a build-time size guard plus an ASCII header, a real .ps1 cleanup test, raw-byte hashing on .ps1, and the .ps1 "only reposPath" case.
   - Sizes at fdb5109: .sh 177,181 B, .ps1 190,758 B. The build warns because the .ps1 is within 5% of 200,000 B.

## Q4 limits (chrome-devtools, read 2026-10-22)

| MDM | Limit | Source (verbatim) |
|---|---|---|
| Intune, Windows PowerShell scripts | < 200 KB | https://learn.microsoft.com/en-us/intune/device-management/tools/run-powershell-scripts-windows (updated_at 2026-07-01): "Script location: Browse to the PowerShell script. The script must be less than 200 KB (ASCII)." |
| Intune, macOS shell scripts | < 1 MB | https://learn.microsoft.com/en-us/intune/device-management/tools/run-shell-scripts-macos (updated_at 2026-07-01): "Upload script: Browse to the shell script. The script file must be less than 1 MB in size." |
| Jamf Pro | unknown | https://learn.jamf.com/r/en-US/jamf-pro-documentation-current/Scripts (11.33.0, last edition Apr 2, 2024) states no size limit. Its only size figure: "Jamf Pro truncates the output of policy logs after they reach 25 KB in size." |

Decision: the 2.2 MB scripts exceeded both Intune limits, so the payload is now a data file, as the mission said. After the change, .ps1 is 190,093 B, under 200,000 B.

## Decisions I made (check them)

- **Q3 is conditional.** The MDM variant skips the writer only when the bootstrap keys are missing. With them present, the writer runs as before. Basis: the "no bootstrap" wording in S3-H-MDM's suggestion (S3-H-MDM-handback.md, open question 1).
- **Tool name `config.json`, not `harness files`.** `config.json n/a (written by installer)` is 38 characters, over the 30-character detail limit (script-standards.md). With `config.json` as the tool name, both details fit, and both prompts' texts are kept: `config.json` `n/a (no bootstrap)` and S3-Harness2's `n/a (written by installer)`. The writer's own rows stay under `aitools config`.
- **One payload file for both .sh and .ps1.** Its checksum is computed with CRs removed, so a Windows `autocrlf` checkout of the dotprofile still verifies. This is tested on .sh and .ps1.
- **A damaged payload deploys nothing** (exit 1, `payload damaged`). A missing payload gives `payload missing`. A damaged record, possible only if the whole-file check also passes, keeps the old behaviour: `N embedded file(s) damaged`, the other files deploy, exit 1.

## Files changed

- `scripts/deploy-harness.sh`, `scripts/deploy-harness.ps1`: markers, `--skip-config` / `-SkipConfig`, and the section 1 skip branch. Nothing else.
- `scripts/build-deploy.sh`: `extract_markers` / `extract_marked`, the assembly by markers, the MDM bootstrap blocks, the payload writer and readers, and the trap fix.
- `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`.
- This folder:
  - `S3-H2-MDM-handback.md`
  - `S3-H2-MDM-drafts/dot-claude/rules/deploy-paths.md.edit.txt`
  - `S3-H2-MDM-drafts/reference/harness.md.edit.txt`

## Verification

| Command | Result |
|---|---|
| `bash tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` | 64 passed, 0 failed, 0 skipped at fdb5109. It was 57/57 at 633d1d7; the baseline before my changes was 30/30 |
| `bash tests/deploy-harness/test-deploy-harness.sh` | 76 passed, 0 failed, 0 skipped |
| `bash -n` on the three scripts and the generated .sh; pwsh parser on scripts/deploy-harness.ps1 and the generated .ps1 | OK |
| Scratch `measure.sh` (isolated HOME, temp dotprofile): sizes before and after | see Summary |
| Scratch `inspect.sh`: generated scripts | 0 marker lines; sections 1, 2 (MDM), 3 and 5b present; .ps1 has 9 non-ASCII bytes |
| `check-pre-commit.sh` | FAIL step 6 only (known 100644 harvesting file); WARN 3, 5, 9, 11 |
| `check-pre-push.sh` | FAIL step 7 only (known stale real dotprofile deploy/; the rebuild into a copy succeeded) |
| `gh pr list` before editing and before pushing | Only #100 and #110 touch deploy-harness. #110 inherits #100's changes and makes none of its own (`git diff` of the two branches on these files is empty). Nothing else touches build-deploy.sh |

The tests caught one real bug, now fixed. PowerShell names are case-insensitive, so a variable named `$skipConfig` was the `[switch]$SkipConfig` parameter, and the row read `n/a (True)`. It is now `$configSkip`, with a comment explaining why.

## Not run

- The generated .ps1 on Windows, and a build on Windows.
- A live Jamf or Intune endpoint, or an Intune Win32 or package upload of `deploy/`.
- `build-deploy.sh` against the real HOME or dotprofile.

## WRITE_BLOCKED

None.

## INCIDENT markers (not filed)

- INCIDENT: generated deploy scripts are over the Intune Windows limit of 200 KB: `setup-user-claude.ps1` is 450,142 B and `setup-user-skills.ps1` is 356,911 B (fixture build). The cause is the inlined aitools-lib.ps1 (154,412 B) plus embedded content. deploy-harness.ps1 is under the limit by about 10 KB only, with the lib inlined.
  - Options: ship aitools-lib beside the scripts instead of inlining it, or package `deploy/` as a Win32 app.
- INCIDENT: every MDM script needs files beside it: deploy-harness needs the payload and the config writer bundle, and the setup scripts need nothing extra today. Intune "PowerShell scripts" and "shell scripts" upload one file, so the whole `deploy/` must ship as a package (Win32 app / pkg). No doc or rule says how `deploy/` reaches an endpoint.
- INCIDENT: a generated bash script truncated inside its inlined library fails with a bash parse error, exit 2 (verified: scratch trunc-probe.sh gave exit 2). That collides with exit 2 = user abort (D-TS13) and writes no summary row.
  - deploy-harness is fixed here: its guard is the first command (B1).
  - The other generated .sh files (setup-user-*) have no guard. This is pre-existing.
- INCIDENT (reviewer, unknown scope): in the generated deploy-harness.ps1, an uncaught error inside `try { } finally { }` returned rc 0 under `pwsh -File`.
  - The one known trigger, the `[long]` cast (N1), is now validated first.
  - Whether other unexpected exceptions in sections 3-7 also exit 0 is untested.
- INCIDENT (reviewer): the truncation guard was placed by content offset. Moving the payload out silently invalidated it, and I adjusted the test instead of the guard.
  - Prevention added: a test asserts the guard comes before `set -euo pipefail`.
- INCIDENT (carried from S3-H-MDM, still open): the pre-push step 7 trigger regex (`scripts/check-pre-push.sh` line 123) does not include `scripts/deploy-harness.*`, `reference/`, `registries/` or `.claude/{rules,skills}/`. This PR changes `build-deploy.sh`, which is in the trigger, so step 7 ran here.
- INCIDENT (carried, still open): the README MDM run order omits deploy-harness.
- Resolved, not an incident any more: the S3-H-MDM INCIDENT about `rm -rf "$DEPLOY_DIR"` leaving a partial deploy/. It is already fixed on main: the build is staged in BUILD_TMP and swapped in ("review m1", scripts/build-deploy.sh near "Swap the staged build in"). The new marker-failure tests confirm a failed build leaves deploy/ intact.

## Protected-file drafts awaiting approval

- `.claude/rules/deploy-paths.md`, three edits based on PR #99's text: MDM run order, extract-by-markers, and the embed bullet. `.cursor/rules/deploy-paths.mdc` takes the same edits.
  - Draft: `S3-H2-MDM-drafts/dot-claude/rules/deploy-paths.md.edit.txt`
- `reference/harness.md`, one sentence: `--skip-config` and the MDM no-bootstrap path. Apply it on top of #100's draft of the same file.
  - Draft: `S3-H2-MDM-drafts/reference/harness.md.edit.txt`

## Follow-ups

- ACTION (commander): after merge, rebuild the dotprofile `deploy/` (`bash scripts/build-deploy.sh`, real HOME) and commit it, including the new `deploy-harness.payload`.
- Installer Step 8b (#106) should pass `--skip-config` / `-SkipConfig`.
- Reviewer N5.2: in the MDM bootstrap check, a corrupt config.json behaves differently by platform.
  - The .ps1 warns and reports "no bootstrap".
  - The .sh greps the file and may run the writer.
  - Suggested: report `ERROR config.json unreadable` on both.
- Size headroom: deploy-harness.ps1 is about 9 KB under 200,000 B, and almost all of it is the inlined aitools-lib.ps1. The next lib growth may trip the new build guard. Suggested: ship aitools-lib beside the scripts.

## Open questions (with suggested answers)

1. **How does `deploy/` reach an endpoint?** Suggested: as one package per OS (an Intune Win32 app or a macOS pkg; for Jamf a package plus a policy script), with a short "MDM packaging" section in deploy-paths.md. This needs the commander's decision before a live Intune test.
2. **Should the MDM writer also be skipped when bootstrap keys exist?** Suggested: no (current behaviour). An endpoint where the installer ran should get the profile-derived keys.

## Reviewer verdict

- **First pass, at 633d1d7: BLOCKING** (B1; N1-N5 non-blocking). https://github.com/nobul-tech/aitools/pull/111#pullrequestreview-5623396152
  - B1 was real, and the test change that hid it was mine.
  - Fixed in fdb5109: B1, N1-N4, N5.1, N5.3. N5.2 became a follow-up.
- **Re-verify, at fdb5109: NO BLOCKING FINDINGS.** https://github.com/nobul-tech/aitools/pull/111#pullrequestreview-5623460206
  - The reviewer re-ran its own probes: the truncation cuts now exit 1 with the row.
  - It raised three new non-blocking findings:
    - **N6:** the .ps1 parsed record paths as Latin-1, so a non-ASCII file name would be unpacked under a garbled name. This regression came from my N5.1 fix. Fixed in the final commit: decode as UTF-8 after the byte check. MDM tests 64/64 after the fix; the reviewer has not re-checked it.
    - **N7:** real builds will print the 5% size warning. That is intended and honest; see the size headroom follow-up.
    - **N8:** the first-line guard is skipped when perl is missing. Recorded only. macOS and Git for Windows ship perl, and the later check reports "perl not found".
- The verdict files are in the reviewer's worktree: `/Users/new-jose/repos/aitools/.claude/worktrees/h2-mdm-review/.scratch/session-h2mrev/S3-H2-MDM-Review-verdict.md` and `S3-H2-MDM-Review-reverify.md`. Both full texts are also posted on the PR.

## Delegates used

- S3-H2-MDM-Review: general-purpose, no isolation, given only the PR number, the packet and the intent.
  - It did the review and the re-verify. Both were posted as comment reviews; a blocking verdict is marked by its first word.
  - Its worktree `.claude/worktrees/h2-mdm-review` is kept. Do not remove it while anyone may re-verify.
