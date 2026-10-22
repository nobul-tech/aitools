# S3-GateFix report: mission GATE-FIX

**Intent**: **Purpose**: Report what mission GATE-FIX shipped, how it was verified, and what the session commander and the commander still need to decide. **Scope**: PR #66 (decision tree rev 5, revised drafts, independent B-pass, review page). NOT the content of the drafts (see the files). **Audience**: Session Commander 10cf255a-c; the commander.

## Summary

1. PR #66 fixes all five PR #58 review findings in a new folder, `S3-GateFix/`. The merged S3-Gate files are untouched.
2. Decision tree rev 5 applies approved decision D-TS13 to every place that launches setup scripts. That is the four runners (the installer loops plus `deploy_configs` / `Deploy-Configs`), plus `aitools user init` and bootstrap, which the B-pass found.
3. An independent delegate, S3-GateFix-B, reviewed rev 5 for cross-platform and bootstrap problems. It found no blockers and 5 majors. All 5 majors and 7 minors are merged into rev 5.
4. `/tool-adopt` is revised to ship early as a process-only skill at user level. The review page has a new first section, "TOOL-ADOPT approval", with 5 items.
5. The review page is ready to publish: `S3-GateFix-review-page.json` (98 items; the renderer validated it).

## PR, branch, files

- PR: https://github.com/nobul-tech/aitools/pull/66
- Branch: `docs/gate-fix`, commits 7604c0a and 6553a98, plus a third commit with this report.
- Files, all under `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-GateFix/`:
  - `S3-GateFix-drafts/reference/tool-support-decision-tree.md` (rev 5), with `.rev4-to-rev5.diff`
  - `S3-GateFix-drafts/reference/script-standards-detail.md.edit.txt`, with its diff
  - `S3-GateFix-drafts/shared/skills/tool-adopt/SKILL.md`, with its diff
  - `S3-GateFix-B-review.md`, `S3-GateFix-rev5-changelog.md`, `S3-GateFix-report.md`
  - `S3-GateFix-render-review-page.py`, `S3-GateFix-review-page.json`, `S3-GateFix-review-page.md`
- **Final review-page JSON:** `/Users/new-jose/repos/aitools/.claude/worktrees/gatefix/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-GateFix/S3-GateFix-review-page.json`

## Findings and fixes

1. **Major: `deploy_configs` and `Deploy-Configs` did not export or read the abort marker** (confirmed at `scripts/aitools`:302-424 and `scripts/aitools.ps1`:296-354).
   - Rev 5 §7.5 lists every launch site. The first one in a run creates the marker, and only it deletes it.
   - When no marker path was exported, exit 2 counts as a failure. The library writes the marker only when `AITOOLS_ABORT_FILE` is set; S3-SourceTruth implements that side.
   - The entry point decides "aborted" from the marker, never from `deploy_configs`' return value. That value is an error count (`return $errors`, line 424), so it can be 2.
   - New §10 rows; D-TS13 is marked approved everywhere.
2. **Minor: edit 6 wording.** Reworded as asked. "The only exit that skips the footer" was false, because the OS guard and a missing spec also exit before the footer; it is now "the only deliberate exit 2".
3. **Minor: generator wording.**
   - Only one caller writes `generated/tool-specs/`.
   - Check 7 regenerates into a temp directory on every commit and never writes `generated/`.
   - The spec header no longer says "embedded by build-deploy.sh".
4. **Minor: renderer.**
   - Every summary line is derived from the JSON.
   - Section b rows have explicit fields: `state`, `draftedBy`, `draftStatus`, `draft`.
   - Added `--help` and `--check`; the command is recorded with both arguments.
5. **Independent B-pass: S3-GateFix-B.** Majors merged into rev 5:
   - GB-01: `user init`.
   - GB-02: bash helpers that are called inside `$(...)` lose their counter increments and globals, so they now return results in globals.
   - GB-03: bootstrap.
   - GB-04: Windows uses the persistent PATH.
   - GB-05: realpath keeps the caller's case on APFS, so RP now compares file identity with `-ef`.
   - Minors merged: GB-07, GB-08, GB-09, GB-10 (new check 12), GB-11, GB-15, O-1.
   - Still open: GB-06, GB-12, GB-13, part of GB-14, O-2, O-3. They are listed in review-page item E-rev5-minors.
   - I spot-checked GB-01 (`scripts/aitools`:1229-1243) and GB-03 (`scripts/bootstrap.ps1`:48), and both are confirmed. O-1 is confirmed in rev 5 §7.2.

New review-page content:
- **Section ta**, five items:
  - TA-PLACE: placement.
  - TA-SKILL: the skill text.
  - TA-INTENT: the intent, verbatim.
  - TA-GLOSSARY: the "tool adoption" definition, revised for the approved model.
  - TA-M2: which parts wait for M2.
- **Section k**: SD-1..8, D-TS13, and the managed-file model.
- **Managed-file model check:** the tool-adopt draft and the glossary text said "[a]dopt"; both are fixed. The /tool-eval, /tool-registry and framework drafts do not describe adopt or merge.
- **New known defects:**
  - E-node-corrupt: confirmed at `scripts/aitools-lib.sh`:448-452.
  - E-merge-revert: today's [m]erge writes the deployed copy only (`reference/managed-file-deployment.md` state machine), so the next run reverts it.
  - E-mdc-model.
  - E-relay-exit2.
- Every existing blocking item is kept, including C.1.

## Verification

- Renderer, run with the exact command in the changelog: `ok: 98 items; ta=5, k=3, a=26, b=26, c=7, d=18, e=13`.
- Negative test: `--check` on the S3-Gate JSON exits 1.
- `--help` prints usage.
- All 84 S3-Gate items are kept (84 + 14 new = 98).
- `check-pre-commit.sh`: 6 PASS, 2 WARN, 1 FAIL. The failure is step 6, which the packet lists as known and pre-existing.
- `check-pre-push.sh`: 5 PASS, 3 WARN, 1 FAIL. The failure is step 3, a false positive on the line "Path tokens:" (known pattern issue).

## Not run

- Nothing was run on Windows; every Windows claim is marked UNVERIFIED.
- No code was changed, so no script tests were needed.

## WRITE_BLOCKED

None.

## INCIDENT markers (not filed)

- `aitools user init` ignores the `setup-user-hooks` exit code (`scripts/aitools`:1229-1243; `scripts/aitools.ps1`:1161-1166, per GB-01).
- `scripts/bootstrap.ps1`:48 runs the installer with `powershell` (5.1) and ignores its exit code.
- `reference/cross-platform-detail.md` recommends `Refresh-Path` for Git Bash PATH shadowing, yet says it only adds entries (GB-04). This is an ambiguity.
- `aitools.ps1`:1428 hard-codes one Git Bash path, unlike `setup-bash.ps1`, and none of the paths are marked verified (GB-13).
- `~/.claude/CLAUDE.md` names the governance repo `nobul-Jose/aitools`, but `git remote -v` shows `nobul-tech/aitools`.

## Open questions for the commander (suggested answers)

- **TA-PLACE:** should `/tool-adopt` go at user level, given that documentation-standards.md "Skill placement" puts governance workflows at project level? Suggested: user level, next to /tool-eval and /tool-registry under SD-8, plus a one-line rule clarification (option c).
- **B-09 (still open):** does Windows run Git Bash in Windows Terminal or in mintty? Suggested: answer before M2 B3.

## Delegates used

- **S3-GateFix-B** (Agent tool, general-purpose, not worktree-isolated): independent cross-platform review.
  - Output: `S3-GateFix-B-review.md` and its probes in `.scratch/session-S3-GateFix-B/`.
  - I verified it by spot-checking two majors and one outside-lens finding (above). Its `.md` file has the required prefix.
  - It said it did not read the reference subset in full. Its findings rest on code and probes, so I accepted them.
