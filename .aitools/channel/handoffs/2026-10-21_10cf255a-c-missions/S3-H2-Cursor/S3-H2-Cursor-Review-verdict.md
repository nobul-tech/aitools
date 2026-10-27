NO BLOCKING FINDINGS

# S3-H2-Cursor-Review: independent review of PR #110

Reviewer: S3-H2-Cursor-Review (launched by S3-H2-Cursor, the author). I worked read-only in my own checkout of `origin/feature/harness-cursor-user-rules` at c91c5ea. I compared it with its base, `origin/feature/harness-rules-manifest` (PR #100).

## Summary

The PR delivers the Intent. Cursor now gets only `shared` and `dotprofile` rules. Names are matched case-insensitively. Fan-out `.mdc` files of `aitools` and `retired` rules are backed up and removed. A user's `.mdc` is kept in every case I could build except one contrived case (finding 3). If the manifest is missing or its header is wrong, the script does nothing and writes WARN and ACTION rows. Dry run, error counting and `.sh`/`.ps1` parity are correct in all the cases I ran. One parity gap exists only for a manifest that breaks the contract (finding 4).

Finding 1 should be fixed before merge or tracked as a follow-up. A project rule that #87 deployed is not recognised if its source changed after that deploy. The `.mdc` then stays loaded in Cursor, and the run reports only an info line under an OK row. The PR's Follow-ups section says the opposite for the aitools rules.

## Findings

1. **Medium.** A #87-era project-rule `.mdc` is kept, and the run does not say so at WARN level, when the rule changed after #87 deployed it.
   - Where: `scripts/setup-user-cursor.sh:762-774`, `scripts/setup-user-cursor.ps1:725-740`.
   - Mechanism: legacy recognition compares the file with the conversion of the **current** harness copy. deploy-harness refreshes `~/.aitools/rules` before step 4 runs. So any aitools rule edited between the user's last #87 run and their first run with this PR no longer matches, and its `.mdc` is kept with an `[info] Kept ...` line. The row stays `OK|cursor rules|n/a (no user-level rules)` and the warning count is 0, so the project rule keeps loading in every Cursor chat and the user is never told at WARN level.
   - How likely: `.claude/rules` changed in 5 commits on main between 2026-10-21 and 2026-10-22 (`git log --since=2026-10-15 -- .claude/rules`: 15a2b80, 9462ed0, 6dc9c99, 378423c, c0381f9). #87 merged at e0f178d (2026-10-22 18:30 -0700).
   - The PR body's Follow-ups say "The 26 aitools rules are handled because their harness copies stay". That is true only while the harness copy is unchanged.
   - Evidence: my case 1 below. Both scripts give `Kept p.mdc ...`, an OK row, and 0 WARN lines.
   - Suggested fix: at minimum, make the "Kept" line for an `aitools` or `retired` name a `log_warn` / `LogWarn`, add an ACTION row naming the kept files, and correct the Follow-up text. Optionally, widen legacy recognition without risking user files. For example, treat a file as fan-out-created when its frontmatter equals the frontmatter of the conversion and it has no marker. That is weaker evidence, so it needs commander sign-off.

2. **Low.** On PS1, the `[ ] * ?` backup workaround checks only the file name, not the whole path.
   - Where: `scripts/setup-user-cursor.ps1:746`.
   - `if ($rmDest -match '[\[\]\*\?]')` decides between `Copy-Item -LiteralPath` and `Backup-File`. `Backup-File` (`scripts/aitools-lib.ps1:784,790`) uses `Test-Path $FilePath` and `Copy-Item -Path`, which treat the path as a wildcard. If `$cursorRulesDir` itself held `[` or `]`, `Backup-File` would return with `BackupFileOk = $true` and no copy, and the file would then be removed.
   - Windows user names cannot contain `[ ]`, so I expect no impact on Windows. Testing `$rmPath` instead of `$rmDest`, or always using the `-LiteralPath` branch, closes the gap at no cost.
   - The workaround also skips `Backup-File`'s retention pruning (`MaxBackups`). This is minor.

3. **Low.** The marker test is not anchored to the first closing `---`.
   - Where: `scripts/setup-user-cursor.sh:484`, `scripts/setup-user-cursor.ps1:489`.
   - The pattern is `\A---[ \t]*\n(?:.*?\n)?---[ \t]*\n<marker>` with dot-all. The `(?:.*?\n)?` can stretch past the real frontmatter close to any later `---` line in the body.
   - Result: a user's `.mdc` named after an aitools rule, whose body has a `---` line followed by the literal marker text (for example, quoted from a generated file), is taken as fan-out-created and removed. A backup is kept. This is contrived but real, and it is the one way I found to remove a user's file.
   - Evidence: my case 2. Both scripts `Removed p.mdc (... aitools-fanout marker ...)`.
   - Fix: match the frontmatter without crossing a `---` line, e.g. `\A---[ \t]*\n(?:(?!---[ \t]*\n)[^\n]*\n)*?---[ \t]*\n<marker>`, or parse the first closing `---` and then compare the next line. Optionally, also require the name in the marker to equal the rule's name.

4. **Low.** `.sh` and `.ps1` give different results for a manifest whose last line ends in a lone CR with no LF.
   - Where: `scripts/setup-user-cursor.sh:505` (`s/\r?\n\z//`), `scripts/setup-user-cursor.ps1:509` (`-replace "\r$", ""`).
   - `.sh` keeps the `\r`, so the source is `shared\r`: the line is ignored with a warning and the row is `WARN|cursor rules|1 added`. `.ps1` strips the CR: the line is accepted and the row is `OK|cursor rules|2 added`.
   - Such a manifest breaks the contract (LF), so the impact is small, but parity requires the same outcome. Fix: use `s/\r?\n?\z//` in Perl, or drop the CR strip in PS1.
   - Evidence: my case 3.

5. **Info, no action.** These checks gave the expected result:
   - Entitlement: `shared` and `dotprofile` only, matched case-insensitively. Tests `invalid` and `users`, and the code at `.sh:595-606` / `.ps1:581-585`.
   - Path safety: a name must match `\A[^/\\]+\.md\z` and contain no `.bak.`, so no separators reach a path. `..md` maps to the plain file `..mdc`, never `..`. My case 4 kept a user's `..mdc` and removed a marked `.h.mdc` with a backup.
   - No manifest, or a bad header: nothing is fanned out or removed, and the run writes WARN and ACTION rows. Unreadable manifest: ERROR row.
   - Backup before every removal: per file, never `backup_dir`. `BACKUP_FILE_OK` is checked, and a failed backup or removal gives a failed tracker entry and an ERROR row.
   - Dry run removes nothing.
   - The manifest is skipped silently by both scripts.
   - The marker sits after the closing `---`, contains no `---`, and passes `cursor_rule_check` / `Test-CursorRuleParse`, so it cannot change how Cursor parses the frontmatter. I did not verify Cursor's own loader (it is not run here). The author also lists it as not run.
   - bash 3.2: `bash -n` passes, and the full suite passes with `/bin/bash` 3.2.57 as the `bash` on PATH.
   - The drafts (`S3-H2-Cursor-drafts/`) match the code. If finding 1 is fixed, the `tool-ops-cursor.md` draft should mention the WARN for kept files.

Context outside this PR, for the commander: on this branch `scripts/aitools` and `scripts/aitools-install.sh` do not list `deploy-harness` among the deploy scripts. Their lists are at `scripts/aitools:1108,1151` and `scripts/aitools-install.sh:833`. Only `build-deploy.sh` (the MDM path) runs it before step 4 (`build-deploy.sh:855,895`). If no other change wires it in, the dev path will report "no rules manifest" on every run. I do not know which PR is meant to wire it.

## Commands run (all from my worktree, isolated HOMEs under `.scratch/session-h2cursrv`)

- `bash tests/rules-fanout-cursor/test-rules-fanout-cursor.sh`: **145 passed, 0 failed, 1 skipped**. The skip is dupcase, which needs a case-sensitive file system.
- The same suite with `/bin/bash` 3.2.57 first on PATH: **145 passed, 0 failed, 1 skipped**, rc 0.
- `bash -n` and `/bin/bash -n` on `scripts/setup-user-cursor.sh` and the test script: rc 0.
- The pwsh `Parser::ParseFile` on `scripts/setup-user-cursor.ps1`, `step4-driver.ps1` and `convert-rule.ps1`: no errors.
- `.scratch/session-h2cursrv/adversarial.sh` runs `setup-user-cursor.sh` and `step4-driver.ps1` on the same seed in each case:
  - Case 1 (stale #87 `.mdc`): `.sh` and `.ps1` both keep `p.mdc`, write `OK|cursor rules|n/a (no user-level rules)` and an `[info] Kept p.mdc ...` line, with 0 WARN lines.
  - Case 2 (user `.mdc` with an HR followed by the marker text): both write `Removed p.mdc (aitools rule: ...; aitools-fanout marker; backup kept)`, `OK|cursor rules|1 removed`.
  - Case 3 (manifest with a lone CR at EOF): `.sh` writes `line ignored: b.md<TAB>shared` and `WARN|cursor rules|1 added`. `.ps1` deploys `a.mdc` and `b.mdc` and writes `OK|cursor rules|2 added`.
  - Case 4 (`..md` aitools, `.h.md` retired): both keep the user's `..mdc` and remove `.h.mdc` with a backup, `OK|cursor rules|1 removed`.

I did not run anything on Windows, did not run Cursor itself, and did not run the interactive review menu.
