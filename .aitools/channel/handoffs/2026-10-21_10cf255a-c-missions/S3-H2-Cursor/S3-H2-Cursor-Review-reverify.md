NO BLOCKING FINDINGS

# S3-H2-Cursor-Review: re-verification of PR #110 at 7f7fc5c

I checked commit 7f7fc5c against my findings 1-4 from the first review (`S3-H2-Cursor-Review-verdict.md`), working read-only in my own worktree, detached at `origin/feature/harness-cursor-user-rules` = 7f7fc5c. All four findings are resolved. I found no new blocking issues.

## Findings 1-4

1. **Resolved.** A #87-era `.mdc` of an aitools rule edited since that run is now recognised.
   - Code: `scripts/setup-user-cursor.sh` prune loop, `scripts/setup-user-cursor.ps1` prune loop.
   - Legacy recognition now also compares the file with the conversion of each `<name>.bak.*` beside the harness copy.
   - Those backups exist in practice: deploy-harness backs up a rule it updates (through `deploy_managed_file`) and one it retires (`retire_rule_file` calls `backup_file`, `scripts/deploy-harness.sh:447-467`).
   - A file that still matches nothing is now a `[warn] Kept ...` line plus one `ACTION||Cursor still loads project/retired rules in ~/.cursor/rules: <files> -- delete them unless you wrote them`.
   - The PR's Follow-ups now say this, and note the remaining gap: a backup pruned after 20 updates.
   - Case 1 (no backup): both scripts give `WARN|cursor rules|n/a (no user-level rules)` and the ACTION row naming `p.mdc`.
   - Case 1b (new; v1 backup beside an edited v2, a retired rule with a backup only, a user `r.mdc`, and a shared rule):
     - both scripts remove `p.mdc` ("same content as the conversion of p.md.bak.2026-10-22T010203Z") and `q.mdc`, each with a backup;
     - both keep `r.mdc` and write a warning and `ACTION ... r.mdc`;
     - both deploy `s.mdc`; the row is `WARN|cursor rules|1 added`.
     - The trees, rows and ACTION are identical for `.sh` and `.ps1`.
2. **Resolved.** PS1 now tests the full `$rmPath` for `[ ] * ?` before choosing the `-LiteralPath` backup.
3. **Resolved.** The marker regex now refuses to pass a `---` line inside the frontmatter: `(?:(?!---[ \t]*\n)[^\n]*\n)*`, with no dot-all.
   - Case 2: a user `p.mdc` with a body `---` followed by the marker text is now kept by both scripts, with a warning and ACTION.
   - An empty frontmatter (`---\n---\n<marker>`) still matches: zero repetitions.
4. **Resolved.** The PS1 manifest reader strips a CR only before an LF.
   - Case 3: both scripts now ignore `b.md<TAB>shared` with a warning, deploy only `a.mdc`, and write `WARN|cursor rules|1 added`.
   - A one-line header ending in a lone CR is header-bad in both scripts.

Case 4 (dot names) is unchanged and safe. Both scripts keep the user's `..mdc` and remove the marked `.h.mdc` with a backup. The row is now `WARN|cursor rules|1 removed`, because the kept `..mdc` warns.

## New observations (info, no action needed)

- A. When the only thing to report is a kept file, the row reads `WARN|cursor rules|n/a (no user-level rules)`. The ACTION row carries the detail. The wording is slightly odd but not wrong.
- B. Backup candidates are tried in glob collation order in `.sh` and ordinal order in `.ps1`. This can change only which backup name appears in the "same content as the conversion of X" log text. The outcome and the rows are the same.

## Commands run (worktree h2-cursor-rv at 7f7fc5c)

- `bash tests/rules-fanout-cursor/test-rules-fanout-cursor.sh`: **164 passed, 0 failed, 1 skipped** (dupcase, case-insensitive file system).
- The same suite with `/bin/bash` 3.2.57 first on PATH: **164 passed, 0 failed, 1 skipped**, rc 0.
- `bash -n` and `/bin/bash -n` on `scripts/setup-user-cursor.sh` and the test script: rc 0.
- The pwsh parser on `setup-user-cursor.ps1`, `step4-driver.ps1` and `convert-rule.ps1`: clean.
- `bash .scratch/session-h2cursrv/adversarial.sh`: cases 1, 1b (new), 2, 3 and 4, each run through `setup-user-cursor.sh` and through `step4-driver.ps1` under isolated HOMEs. Results as above. `.sh` and `.ps1` agree in every case.

## Housekeeping

The author committed my first verdict file in 7f7fc5c. To check the commit out, I moved my untracked copy to `.scratch/session-h2cursrv/verdict-local-copy.tmp`. `git diff --no-index` showed it is byte-identical to the committed file.

## Not run

The `.ps1` on Windows; Cursor itself; the interactive review menu.
