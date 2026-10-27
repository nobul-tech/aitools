AUDIT (logging, B): FINDINGS -- no blocking findings; 7 non-blocking (1 is a .sh/.ps1 parity break in a fault path that the PR inherits)

Auditor: S3-FanoutImpl-AuditB119 (independent second logging/script-standards audit). Scope: `git diff d7f6855...origin/feature/fanout-harness-skills` (head f0e2c7d), `scripts/deploy-harness.sh` and `scripts/deploy-harness.ps1`, runtime behaviour only. This is not a functional review.

## How I tested

- Scratch harness: `.scratch/session-a119b/audit-run.sh` in a detached worktree at f0e2c7d. Each case has its own fixture aitools repo and dotprofile (both git), a stub config writer, and an isolated `HOME=<scratch>/out/<side>-<case>/home` (with `USERPROFILE` set to the same path for pwsh). `AITOOLS_LOG_DIR` is unset, so logs go to the isolated `~/.aitools/logs/deploy.log`. The .ps1 runs on pwsh 7.6.3 (macOS) with its OS guard patched off in the copy. Each step records the exit code, the `[error]`/`[warn]` line counts, the `AITOOLS_SUMMARY_FILE` rows, the footer line, the skills manifest and the skills tree. The .sh and .ps1 traces are then diffed.
- Real HOME untouched: `grep -c '2026-10-27T02:2.*deploy-harness' ~/.aitools/logs/deploy.log` gives 0.
- PR suite: `bash tests/deploy-harness/test-deploy-harness.sh` gives 113 passed, 0 failed, 0 skipped (pwsh present).

| Case | .sh rc / rows | .ps1 | Parity |
|---|---|---|---|
| Duplicate skill: shared `s2`, .claude `S2`, dotprofile `s2` | rc 1; `ERROR\|harness files\|S2: dup in .claude/skills`, `ERROR\|...\|s2: dup in dotprofile/skills`, `OK\|...\|13 added`; footer "FAILED with 2 error(s)" | same | identical |
| Same, `--dry-run` | rc 1; both ERROR rows; `OK\|...\|dry-run: 0 create, 0 update` | same | identical |
| Manifest write failure (`chmod 555 ~/.aitools/skills`, nothing else to write) | rc 1; `ERROR\|...\|skills manifest not written`, `OK\|...\|13 verified`; no `.tmp` left; next run rc 0 | same (message carries the .NET exception text) | identical |
| Manifest path is a directory | rc 0, WARN only; **manifest not written but logged as written** | rc 1, ERROR row | **different** (N1) |
| Retire a skill with no top-level `*.md` | rc 1 on every run; `ERROR\|...\|retire failed: nomd` | same | identical |
| Retire with a partial backup (unreadable file in the deployed skill) | rc 1; `ERROR\|...\|retire failed: s2` + WARN (backup_dir); after `chmod 644`, retired: `DETAIL\|...\|retired: skills/s2` | same rows and rc; tree differs (partial-copy contents) | rows identical |
| Dry run, a pending retirement and a new skill | rc 0; `OK\|...\|dry-run: 1 create, 0 update`; nothing removed; next real run retires s1 with a verified backup | same | identical |

Holds in every case:
- `ERRORS`/`WARNINGS` (`$errors`/`$warnings`) drive the exit code: every `log_error` path exits 1, and a warnings-only run exits 0 with the final OK row auto-promoted to WARN by `write_summary`.
- Every new `log_error`/`LogError` that guards a write or removal is paired with a `write_summary ERROR` row. That covers `retire_skill_dir` / `Remove-RetiredSkill` on all 5 failure exits, and the manifest plan, write and move.
- Every new summary detail goes through `short` / `Get-ShortDetail` (30 characters at most); "skills manifest not written" is 27.
- The new code adds no `2>/dev/null` and no `|| true`. sh:558 assigns its fallback in an `if !` with a comment. Every new `catch` logs.
- Log lines have the `[UTC Z] [deploy-harness] [level]` format and go to the isolated `~/.aitools/logs/deploy.log` on both sides.

## Findings (all non-blocking)

**N1, parity break in a fault path, inherited from the rules manifest code.** `scripts/deploy-harness.sh:623-634`. When `~/.aitools/skills/.aitools-skills-manifest` is a directory, `mv -f "$tmp" "$manifest"` moves the temp file *into* it (`.aitools-skills-manifest/.aitools-skills-manifest.tmp`). The run then logs `Skills manifest: wrote ...` and exits 0. Its only warning is the header warning, because perl opens the directory and reads an empty first line. The .ps1 (`deploy-harness.ps1:632`, `[IO.File]::Move`) fails with "Is a directory", writes `LogError` plus `ERROR|harness files|skills manifest not written`, and exits 1. The rules manifest has the same lines unchanged from before this PR. Suggested fix, applied to both kinds: before the move, `if [ -d "$manifest" ] && [ ! -L "$manifest" ]; then log_error ...; write_summary ERROR ...; fi`. Alternatively, after the move, check `[ -f "$manifest" ] && [ ! -e "$tmp" ]`.

**N2, a retire that fails on every run, with a log line that does not say why.** `deploy-harness.sh:551, 561-565`; `deploy-harness.ps1:538, 547-551`. `backup_dir` / `Backup-Dir` silently back up nothing when the directory has no top-level `*.md` (`aitools-lib.sh:1018-1021`). A retired skill directory without one (e.g. only `sub/x.md`) therefore gets `ERROR ... backup failed (no new nomd.bak.* directory)` and exit 1 on every run, and the log never says the cause is the missing top-level `.md`. The code comment knows it (sh:539, ps1:528). Suggestion: check for a top-level `*.md` first and log that reason. Or back the directory up with a plain recursive copy that has no `*.md` precondition.

**N3, partial backups are left behind, and the lib's backup name can collide.** When the copy in `backup_dir` fails part-way (for example, an unreadable file), a partial `<name>.bak.<UTC>` stays on disk. `retire_skill_dir` correctly refuses to remove the skill ("differs ... Only in .../s2: secret.md"). But the partial directory is never reported, because the preserved scan skips `*.bak.*`, and each retry adds another until the prune at 5. Separately, two runs within one second reuse the timestamp. `cp -R` then copies into the existing backup, which I observed as `s2.bak.TS/s2/SKILL.md` nested inside the earlier partial backup. The retire guard caught it ("no new s2.bak.* directory"), so nothing was lost. The root cause is in `aitools-lib.sh:1023-1024` and `aitools-lib.ps1:889-892` (no collision check), which predate this PR. Suggestion: on a failed or unproven backup, remove the new partial `.bak` directory, or log its path at warn as "unverified backup kept".

**N4, the .ps1 "differs" error has no reason.** `deploy-harness.ps1:553-562`. The .sh error names the first `diff -r -q` line (sh:568). The .ps1 says only "backup ... differs from the directory". When `Test-SameTree` throws, the real reason goes to `LogDetail` (file only), while the console and the ERROR line still say "differs". Suggestion: have `Test-SameTree` return the first difference, and put an exception's text in the `LogError` line ("backup comparison failed: ...").

**N5, a SilentlyContinue that treats every error as absent.** `deploy-harness.ps1:610-613`. `Get-Item -ErrorAction SilentlyContinue` with a null check on the next line meets rule 1. But an access-denied error is then handled as "nothing to remove", with no log line. Rule 7 prefers `-ErrorAction Stop` with try/catch. Suggestion: `Test-Path -LiteralPath $p` first, then `Get-Item -ErrorAction Stop` inside try/catch with `LogWarn`.

**N6, cosmetic: dry-run wording.** `deploy-harness.sh:606`, `deploy-harness.ps1:604`. In `--dry-run`, `Retired skill: s1 (was shared; no source has it now)` is logged without the `[DRY RUN]` prefix and reads as done. The next line, `[DRY RUN] Would back up and remove`, is correct. The dry-run summary row counts creates and updates only, not pending retirements. The rules manifest predates this PR and behaves the same way.

**N7, cosmetic and by design (pre-existing): the final row can be OK while the run exits 1.** `deploy-harness.sh:684-701`, `deploy-harness.ps1:679-697`. On a duplicate, retire or manifest failure, the final row is still `OK|harness files|N verified` beside the ERROR rows, because only `N_FAILED` turns it into ERROR. This matches the commander's rule (each duplicate is log_error plus an ERROR row). I record it only because a reader of the summary panel sees both OK and ERROR for "harness files".

## Not run

- Windows (real `$IsWindows`, Git Bash `.sh`): I ran only on macOS, with the .ps1 on pwsh with its guard patched off.
- The MDM variant (`build-deploy.sh` output): build-deploy was not run.
- Interactive review-menu paths (pty).

Evidence: `.claude/worktrees/fo-aud119b/.scratch/session-a119b/out/` (per-case `trace`, `log-<step>`, `errwarn.txt`, `diff-mfail.txt`, `diff-unr.txt`).
