AUDIT (logging, A): FINDINGS

**No blocking findings. 4 non-blocking.** Auditor: S3-FanoutImpl-AuditA119 (level 2). I worked alone and did not read the other auditor's output or the author's notes.

**Scope:** `git diff d7f6855...origin/feature/fanout-harness-skills`, covering `scripts/deploy-harness.sh` and `scripts/deploy-harness.ps1`. For the two test files I looked only for silent failures. Line numbers refer to the files on `origin/feature/fanout-harness-skills`.

**Standards checked:** `.claude/rules/script-standards.md`, `reference/script-standards-detail.md`, `reference/logging.md`, `reference/plan-execution-detail.md` (error-handling rules 1-8, quoted in the delegate brief section 3).

## Checklist

| Check | .sh | .ps1 |
|---|---|---|
| Log line format (lib `log`/`Log` only, no raw echo/Write-Host in new code) | PASS | PASS |
| Each new `log_error`/`LogError` for a failure has a `write_summary ERROR` | PASS: sh 547/548, 553/554, 562/563, 568/569, 573/574, 594/595, 624/625, 629/630 | PASS: ps1 541/542, 548/549, 560/561, 567/568, 572/573, 595/596, 634/635 |
| `log_warn`/`LogWarn` counts WARNINGS (lib helpers, not overridden) | PASS | PASS |
| `write_summary` on every path, dry run included (section 7 is unconditional; dry run gives OK "dry-run: ...") | PASS: sh 684-701 | PASS: ps1 679-697 |
| Summary detail 30 chars or less | PASS: every variable detail goes through `short`. The fixed details are at most 26 chars ("skills manifest not written") | PASS: `Get-ShortDetail`, same fixed strings |
| No `2>/dev/null`, `\|\| true`, `-ErrorAction SilentlyContinue` or empty catch without a comment and an immediate check | PASS. New redirects go to files that are read back (sh 546, 552, 567, 593). The perl fallback at sh 558-560 is commented and checked at 561 | PASS. ps1 610 is `SilentlyContinue` with a comment at 611 and a `$null` check at 612. Every new catch logs |
| Exit footer | PASS: sh 703-712 | PASS: ps1 699-708 |
| sh/ps1 emit the same rows | PASS. The test trace compares exit codes, rows, manifest and tree for both scripts (test-deploy-harness.sh, "skills parity") | PASS |
| sh/ps1 emit the same messages | Small differences: see N3 | |
| Tests: silent failures | No blocking issue. The suites run under `set -uo pipefail` (no `-e`), so a failed fixture command is not checked where it runs. It shows up as a failed assertion later, which is acceptable for test fixtures | |

## Findings

**N1 (non-blocking): wrong cause given when a retired skill directory has no top-level `*.md`.** Locations: sh 551 + 561-564, ps1 538 + 547-551.
- `backup_dir` / `Backup-Dir` (aitools-lib.sh 1018-1021, aitools-lib.ps1 887-888) return without a backup and without logging when the directory has no top-level `*.md` file.
- deploy-harness then logs `backup failed (no new <name>.bak.* directory)` with an ERROR row. It does this on every run and exits 1, until someone removes the directory by hand.
- The code comment admits the limitation (sh 539, ps1 528), but the log line and the row give the wrong cause and tell the user nothing to do.
- Suggestion: before calling `backup_dir`, check for a top-level `*.md`. If there is none, log_error "has no top-level *.md (backup_dir cannot back it up) -- not removed" and add a paired `log_warn` + ACTION row (for example "remove ~/.aitools/skills/<name> by hand"). Alternatively, back the directory up with `cp -R` directly.

**N2 (non-blocking): the library's warning contradicts the retire step.** Location: lib sh 1025 / ps1 894, as used from sh 551 / ps1 538.
- When the copy fails, `backup_dir` logs_warn "Could not back up ... -- proceeding without backup".
- deploy-harness does not proceed: it logs_error "backup failed ... not removed". One failure therefore gives a counted warning that says the opposite of what happens, plus the error.
- The test `bakfail` case exercises this path.
- Suggestion: this is a library message, out of this PR's diff. Note it as a follow-up, for example a quiet or result-returning variant of `backup_dir`.

**N3 (non-blocking): sh/ps1 message differences in `retire_skill_dir` / `Remove-RetiredSkill`.** The rows match; these are message differences only.
- **Backup comparison failure** (sh 568 vs ps1 554-560):
  - The .sh error line includes the first line of `diff -r -q` output. That shows both a real difference and a read failure such as "Permission denied".
  - The .ps1 sends a `Test-SameTree` exception only to `LogDetail` (file-only) at 556. It then logs_error "backup ... differs from the directory", so a read failure is reported on the console as a content difference.
  - Suggestion: in the catch, set a reason string and include it in the `LogError` at 560.
- **Listing failure:**
  - sh 547: `Retired skill X: <perl error> -- <d> not removed`
  - ps1 541: `Retired skill X: backup check failed: <error> -- <d> not removed`
- **Removal failure:**
  - sh 573 has one message.
  - ps1 has two: 567 (with `$_`) and 572 ("(still there)").
- Suggestion: align the wording if you touch this code again.

**N4 (non-blocking, observation): dry run does not count retirements in its row.**
- The row text "dry-run: N create, M update" (sh 685, ps1 680) leaves out retirements.
- A pending retirement appears only as an `[info] [DRY RUN] Would back up and remove ...` log line (sh 543, ps1 533).
- This matches the existing rules behaviour, and the dry-run test checks the log line.
- Suggestion: optionally add a DETAIL row `would retire: skills/<name>` in dry run.

## Verified clean (spot checks)

- The new perl helpers report failures through their exit code and stderr, captured to a file and logged (sh 526-534, 593-597).
- `retire_skill_dir` checks the removal twice: `rm -rf` and then `[ -e ]` (sh 572). The .ps1 does the same with try/catch and `Test-Path` (565-575).
- The manifest is written atomically. If the temp-file write or the move fails, it logs an error, writes an ERROR row, and removes the temp file; that cleanup is checked too (sh 623-633, ps1 630-640).
- The new `log_detail`/`LogDetail` skip lines for hidden and `*.bak.*` skill directories are file-only, as `reference/logging.md` section 5 requires.

## Not run

I ran no scripts or tests: this audit is static only. Functional behaviour is out of scope (the separate functional reviewer covers it).

## Outside this PR's diff (seen, not counted)

- ps1 222-223: the comment explaining the `-ErrorAction SilentlyContinue` on temp-file cleanup comes after the line, not before it. Unchanged by this PR.
- DETAIL rows (`retired:`, `failed:`) are written before the section-7 parent row. `script-standards-detail.md` "DETAIL lines" says DETAIL rows follow their parent row. Unchanged by this PR; the rules retirement has the same order.
