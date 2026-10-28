AUDIT (logging, A): FINDINGS

Scope: static logging and script-standards audit of `scripts/setup-user-cursor.sh` / `.ps1`, commits 282c28b..880749e (two-dot diff). Tests scanned only for silent failures. Line numbers are in the head versions on `origin/feature/fanout-cursor` (880749e). Nothing was run. No blocking findings: every `log_error` / `LogError` I traced ends in an ERROR row, and the sh/ps rows match on every reachable path.

## Findings

1. **non-blocking: summary detail can exceed 30 characters.**
   - Where: step 4's final row is now `deploy_tracker_summary` / `Write-DeployTrackerSummary` (sh:866,874; ps:876,884), and its text now includes `N removed`.
   - Evidence: the suite pins a 41-character detail, `3 added, 1 updated, 1 removed, 1 verified` (tests/rules-fanout-cursor/test-rules-fanout-cursor.sh:428). The text is built in lib.sh:2587-2601.
   - Rule: script-standards.md "Config and file update reporting"; reference/script-standards-detail.md "Summary detail text rules" (max 30 characters).
   - Note: this comes from the lib (FO-1), it already happens for `claude rules`, and contract 3.1 requires the `removed` tracker outcome.
   - Fix: a lib follow-up, for example leave the `verified` count out when other counts exist, or cap the text. Add it to the PR's Follow-ups.

2. **non-blocking: two warnings exist only in the .ps1.**
   - Where: ps:797-799 `LogWarn "Cannot list the backups of ..."` is followed by `LogError "Not removed ..."` at ps:802. ps:836-838 `LogWarn "Cannot list ... for the preserved report"`.
   - The sh counterparts (sh:786-795, sh:823-831) use globs, which cannot fail this way. So in those paths the .ps1 counts one warning more than the .sh and logs a line the .sh never writes.
   - Rule: parity of messages and counts (interactive-menus.md "Cross-platform parity"; brief checklist 7).
   - Fix: make ps:798 a `LogDetail`, since the `LogError` at ps:802 already reports the outcome. Or comment both lines as .ps1-only failure modes.

3. **non-blocking: the header-bad warning does not carry the ACTION's instruction.**
   - Where: sh:556 / ps:566 log `... the first line is not "..." -- every rule fanned out, none removed`. The ACTION at sh:557 / ps:567 says `Run aitools to rebuild ~/.aitools/rules and its manifest`.
   - Rule: reference/script-standards-detail.md "ACTION items" ("Always pair with a `log_warn` carrying the same text") and "Severity decision guide".
   - Fix: append ` -- run aitools to rebuild ~/.aitools/rules and its manifest` to the warning. The lib's skills twin (lib.sh:2929) has the same gap.

4. **non-blocking: the dry-run row ignores the error count.**
   - Where: sh:815-820 / ps:825-830 write `OK dry run (no files written)` whenever `_DT_FAILED` / `dtFailed` is 0.
   - Problem: a `log_error` that is not recorded as `failed`, such as `Unexpected accept & adopt` (sh:717 / ps:712), would give an OK row with exit 1. The real run catches this through the `ERRORS_BEFORE_CURSOR_RULES` check (sh:868 / ps:878). The path is unreachable today, since adopt is never offered.
   - Rule: script-standards.md "End-of-run summary" (the row must match the outcome).
   - Fix: add the same `ERRORS` delta check to the dry-run branch. Or record `failed` instead of `accept & adopt` in the unreachable branch.

5. **non-blocking: the directory backup result is not checked.**
   - Where: `backup_dir "$CURSOR_RULES_DIR"` (sh:647) / `Backup-Dir` (ps:638).
   - Problem: the lib copies only a directory that holds a top-level `*.md` (lib.sh:1019-1022). `~/.cursor/rules` holds `.mdc` files, so it is never backed up as a directory, and that is logged at detail level only.
   - Mitigation: each file is still backed up by `deploy_managed_file`, and removals check that a backup exists first (sh:780-795 / ps:786-805).
   - Rule: config-file-safety.md "Directory deployment (additive pattern)" step 2.
   - Fix: already in the PR's Follow-ups (FO-1 lib).

6. **non-blocking: lib comments are stale after this PR.**
   - lib.sh:2607-2608 says "setup-user-cursor still defines its own copies of lower_name, in_list and read_rules_manifest".
   - lib.sh:2676-2678 says the same about "setup-user-cursor's own copy of read_rules_manifest". The PR body mentions only the first.
   - Rule: documentation-standards.md "No duplication" (one authoritative location per fact).
   - Fix: drop both sentences in the FO-1 follow-up.

7. **non-blocking: the step 5 row comment is incomplete.**
   - Where: sh:890 / ps:899 say `Rows: "cursor skills"`. With no `~/.aitools/skills`, the lib writes no row by design (lib.sh:2900-2905, the contract change in 5267e9e).
   - Until FO-6, `setup-user-skills` also writes `cursor skills` rows (setup-user-skills.sh:174-179). `show_summary` keeps only the most severe row per tool (lib.sh:3784-3803), so the panel shows one row, but it may come from either writer.
   - Fix: say in the step 5 comment that the no-row case is owned by setup-user-skills. FO-6 tracks the second writer.

## Scope note

282c28b is not an ancestor of 880749e. The commits 3d351ac, 2fdcefb, 7296a38 and 282c28b on `feature/fanout-claude-skills` are not in this head (`git log 880749e..282c28b`).

- The two-dot diff of `tests/skills-fanout` therefore shows their changes as removals: the CI missing-tool FAIL guard, `die()`, and the payload fixture. These are not FO-5 changes.
- The base side did not touch `setup-user-cursor.*` after the merge base (`git diff --stat 880749e...282c28b`), so the script diff audited here is FO-5's alone.
- Merge #124 first, as the PR body says.

## Checked clean

- **Log line format:** steps 4-5 use only the lib's `log` / `log_ok` / `log_warn` / `log_error` / `log_detail` and their PS twins. There is no raw echo, printf or Write-Host (scan of sh:397-895, ps:409-905). The exit footers match the standard (sh:898-907, ps:908-917).
- **ERROR rows follow every error:**
  - `cannot read harness rules`: sh:531-532 / ps:538-539
  - `cannot read rules manifest`: sh:552-554 / ps:561-563; the manifest is also counted as a failed item at sh:662 / ps:662, as contract 3.1 asks
  - `cannot create rules dir`: sh:642-643, 651-652 / ps:633-634, 650-651
  - dangling symlinks, duplicates, conversion and read failures, and prune failures are recorded as `failed`, which gives the tracker's ERROR row
  - validation errors give `ERROR validation failed` (sh:877-878 / ps:887-888)
- **No double OK row** after an unreadable manifest (sh:633-636 / ps:626-627).
- **WARN and ACTION:**
  - each kept retired file gets a `log_warn`, plus one ACTION row (sh:772, 811-812 / ps:777, 821-822)
  - bad header gets a `log_warn` and an ACTION
  - invalid manifest lines and listed-but-missing rules get `log_warn`, so the later OK row is promoted to WARN (lib.sh:957-959, lib.ps1:822-824)
- **A row on every path:** missing dir, unreadable dir, empty, dry run and nocreate each write a row. Abort is the documented exception (no row; the caller records the exit 2).
- **Length of the literal detail texts:** `n/a (no harness rules)` (22), `cannot read rules manifest` (26), `cannot read harness rules` (25), `cannot create rules dir` (23), `dry run (no files written)` (26), `validation failed` (17).
- **Error suppression:**
  - sh:844 `|| true` has its comment and `first_line` is checked afterwards
  - sh:742 `|| rm_rc=$?` is checked (exit 1 versus other codes)
  - ps:605-610, 752-759 and 762-767 catch blocks log at detail and fall through to a reported outcome
  - no empty catch blocks and no `SilentlyContinue` in steps 4-5
  - step 5: both lib functions return 0 on every path (lib.sh:2879-3272; lib.ps1 `Invoke-HarnessSkillsFanout` has only bare `return`s), so `set -e` cannot kill the .sh before the exit footer
- **sh/ps parity:** the same rows, tool names, details and order on every reachable path (missing, unreadable, no manifest, bad header, unreadable manifest, empty, dry run, nocreate, deploy, prune, kept, preserved, validation, final row). The only differences are the ones in finding 2.
- **Tracker outcome `removed`:** recorded at sh:809 / ps:819 and handled in the tracker (lib.sh:2570-2571, lib.ps1:2600). The final row counts it, so a prune-only run reports `N removed` and not `n/a` (sh:869 / ps:879). Every `deploy_managed_file` / `Deploy-ManagedFile` result is handled at the one call site per script (sh:710-722 / ps:705-719), and an unknown result becomes `failed`.
- **Tests (silent failures):** the new lines in tests/rules-fanout-cursor, tests/skills-fanout and tests/fanout-lib add no `2>/dev/null`, `|| true` or `SilentlyContinue` that could hide a failure. A missing pwsh or python3 is reported as SKIP (test-rules-fanout-cursor.sh, the pty block's SKIP lines). The `|| { diff ...; false; }` parity checks still fail when they should.
