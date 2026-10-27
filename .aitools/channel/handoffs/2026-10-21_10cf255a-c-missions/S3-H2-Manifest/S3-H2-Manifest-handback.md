# S3-H2-Manifest hand-back (2026-10-22)

## Summary

deploy-harness.sh/.ps1 now write `~/.aitools/rules/.aitools-rules-manifest`
on every run and retire removed rules (back up, remove, keep a `retired`
line). PR https://github.com/nobul-tech/aitools/pull/100, branch
feature/harness-rules-manifest, commits 8c5b01d, 0757364, 161edd0.
The independent reviewer (S3-H2-Manifest-Review) found one BLOCKING issue:
the .ps1 deleted bracket-named rules without a backup. It is fixed in
161edd0, and the follow-up review is APPROVE-EQUIVALENT.

## Files changed

- scripts/deploy-harness.sh, scripts/deploy-harness.ps1 -- section 5b
  (functions only; inside build-deploy's extracted span "# 3." to EOF),
  `add_source`/`Add-Source` record listed sources, preserved report skips
  the manifest, header comments.
- tests/deploy-harness/test-deploy-harness.sh -- 31 new checks (.sh, and the
  .ps1 on pwsh with the OS guard disabled in a temp copy).
- Drafts (protected, awaiting approval) in `S3-H2-Manifest-drafts/`:
  reference/harness.md, dot-claude/rules/managed-file-deployment.md,
  reference/managed-file-deployment.md. Note: open PR #99 also edits
  reference/managed-file-deployment.md; re-check the draft's OLD text after
  #99 merges.

## Final contract (also verbatim in the PR body, "Contract")

- File: `~/.aitools/rules/.aitools-rules-manifest` (no .md extension).
- Format: UTF-8, LF, first line `# aitools rules manifest v1`, then
  `<file name><TAB><source>`, source shared | aitools | dotprofile |
  retired; sorted by file name (byte order); only *.md, never *.bak.*.
- Written every run after the rules copy (temp then move); the winning
  source (first source wins) is recorded.
- Retiring: a name in the previous manifest (non-retired source) that no
  source has this run (case-insensitive) becomes `retired`, **only when its
  previous source was listed this run**. A name whose source was not listed
  (not found, not a git checkout, ls-files failed, no dotprofile) keeps its
  line and file. While a name is `retired`, its file in ~/.aitools/rules is
  backed up and removed whenever it exists (a failed backup leaves it:
  log_error + ERROR row). The line stays until the name reappears. First run:
  nothing is retired. Unknown header: warning, nothing retired, rewritten.
  Invalid lines: ignored with a warning.
- Consumers: take non-retired names they are entitled to; back up and remove
  their copies of `retired` names (Cursor also removes `aitools` names).
- Manifest write failure: log_error + ERROR row, run continues.

Contract changes (why): (1) listed-source-only retirement -- otherwise a
missing dotprofile deletes every user rule; (2) re-removal while retired --
self-healing after a failed backup/removal; (3) case-insensitive names --
otherwise removing a "retired" `Scratch.md` on macOS/Windows deletes the live
`scratch.md`; (4) header/invalid-line/dry-run behaviour added.

## Verification (macOS, pwsh 7, isolated temp HOMEs)

- bash -n and the pwsh parser on both scripts: clean.
- tests/deploy-harness/test-deploy-harness.sh: 76 passed, 0 failed, 0 skipped.
- tests/deploy-harness-mdm/test-deploy-harness-mdm.sh: 30 passed (dev and
  MDM trees, including the manifest, identical).
- check-pre-commit: known step 6 FAIL (harvesting file mode); step 3 WARN
  (--fix would run build-deploy against the real HOME, not run); step 11 WARN
  (another session's uncommitted dotprofile edits: claude/CLAUDE.md,
  sessions/.DS_Store -- not touched). check-pre-push: 0 FAIL.
- Reviews: https://github.com/nobul-tech/aitools/pull/100#pullrequestreview-5623187396
  (BLOCKING), https://github.com/nobul-tech/aitools/pull/100#pullrequestreview-5623233837
  (APPROVE-EQUIVALENT).

## Not run

- The .ps1 on Windows. build-deploy.sh against the real dotprofile. The
  consumers (not in scope).

## Follow-ups

- S3-H2-Cursor: setup-user-cursor.ps1 `Get-ChildItem` lists the dot file and
  logs "Ignoring non-rule file" each run (the .sh glob skips it).
- Low parity notes from the reviewer (open): .ps1 retire backups not pruned
  (.sh keeps 20); failed-backup warning count differs; dangling symlink with a
  retired name removed by .sh, left by .ps1.
- Known limits (in the harness.md draft): case-only rename on Linux leaves the
  old file; a rule moving to an unlisted source is retired then re-deployed.

## WRITE_BLOCKED

None.

## INCIDENT markers (not filed)

- INCIDENT: `Backup-File` in scripts/aitools-lib.ps1 uses `Test-Path` /
  `Copy-Item -Path` / `Get-ChildItem -Path` without `-LiteralPath`. For a path
  with `[ ]` it makes no backup but sets `BackupFileOk = $true`. Every caller
  is affected, including Deploy-ManagedFile. This deviates from
  config-file-safety.md "Backup before overwrite" and from .sh parity
  (source: S3-H2-Manifest-Review probe; aitools-lib.ps1 Backup-File).
- INCIDENT: the rules filter in add_source is case-sensitive in the .sh
  (`*.md`, `*.bak.*`) and case-insensitive in the .ps1 (`-like`), so `X.MD`
  deploys on Windows only (scripts/deploy-harness.sh add_source,
  scripts/deploy-harness.ps1 Add-Source). This predates the mission.

## Delegates

- S3-H2-Manifest-Review (general-purpose, independent; given the PR, the
  packet, the Intent and the contract). It ran two passes and posted both
  reviews on the PR.
