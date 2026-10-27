AUDIT (logging, B): FINDINGS

Runtime logging / script-standards audit of `scripts/setup-user-claude.sh` and `.ps1` in PR #121, by S3-FanoutImpl-AuditB121 (independent runtime auditor; the static audit is separate). No blocking findings. There are 7 non-blocking ones: 4 in this PR's code and 3 owned by the lib but reached through the fan-out.

- **Head:** `66c58cb` (`origin/feature/fanout-claude-rules`; contains b27ab1a, a0bd5e4, bba5fad).
- **Platform:** macOS 27 (Darwin arm64). The .sh ran under bash 5, plus a suite run under `/bin/bash` 3.2. The .ps1 ran under pwsh 7 from a scratch copy with its Windows OS guard patched off. The tracked file was not edited.
- **Isolation:** every run had its own HOME and USERPROFILE under `.claude/worktrees/fo-aud121b/.scratch/session-a121b/runs/<case>/<lang>`. `AITOOLS_LOG_DIR` was unset, so the logs are the default `HOME/.aitools/logs/deploy.log`. stdin was `/dev/null` (non-interactive), except the pty abort run.
- **Line numbers:** branch version at 66c58cb.

## Findings

### N1 (non-blocking; lib, reached through the fan-out): dangling symlink in `~/.claude/rules` breaks sh/ps parity, and sh logs a create that went elsewhere

**Case `destlink`:** harness rule `s.md`; `~/.claude/rules/s.md` and `stale.md` are dangling symlinks.

- **sh:** rc 0. Log `[ok] Created: s.md -> <H>/.claude/rules/s.md`. Rows `DETAIL|claude rules|added: s.md` and `OK|claude rules|3 added`. The write followed the link and created `<H>/nowhere1.md` outside `~/.claude/rules`. `s.md` is still a symlink.
  - Code: `aitools-lib.sh:2046` (`[ ! -f "$dest" ]` is true for a dangling link, so `_managed_write` writes through it).
- **ps:** rc 1.
  - `[warn] Could not back up <H>/.claude/rules -- proceeding without backup: Could not find file '<H>/.claude/rules/s.md'.` (`Backup-Dir`, `aitools-lib.ps1:892`)
  - `[error] Failed: s.md: cannot read <H>/.claude/rules/s.md: Could not find file ...`
  - Rows `DETAIL|claude rules|failed: s.md` and `ERROR|claude rules|1 failed`.
- **Parity:** rows, exit code and level counts differ (sh error=0 warn=0; ps error=1 warn=1).
- **Also different:** the dangling `stale.md` is skipped silently in sh (preserved loop `[ -f ]`, `setup-user-claude.sh:606`). ps counts it: `Preserved unmanaged rule: stale.md`; `Get-ChildItem -File`, `setup-user-claude.ps1:647`. So the log says "1 preserved" in sh and "2 preserved" in ps.
- **Suggested:** in the fan-out loop, treat a symlink at the destination as `failed` with a log_error in both languages (`[ -L ]` / `LinkType`), or fix it in `deploy_managed_file` / `Deploy-ManagedFile`. Count dangling links the same way in the preserved report.
- **Why non-blocking:** the lib behaviour predates this PR. The old dotprofile rules loop hit it too. Plan section 4 does not list a destination symlink.

### N2 (non-blocking; this PR plus the lib): raw stderr on the console, and the reason is missing from deploy.log (sh only)

The sh error lines say what failed but not why. The ps lines include the exception text.

| Case | sh console (unstructured) | sh deploy.log | ps deploy.log |
|---|---|---|---|
| `srcunread` | `cat: <H>/.aitools/rules/p.md: Permission denied` | `[error] Cannot read harness rule <H>/.aitools/rules/p.md` | `... : Exception calling "ReadAllText" ... is denied.` |
| `nocreate` | `mkdir: <H>/.claude/rules: File exists` | `[error] Cannot create <H>/.claude/rules` | `... (not a directory)` |
| `destro`, `retunread` | `cp: ...: Permission denied` | (from lib backup) | (exception text) |

- **This PR's code:** `setup-user-claude.sh:501` (`_rule_content=$(cat "$rule_src")`) and `:450` (`mkdir -p "$RULES_DEST"`).
- **Lib:** `aitools-lib.sh:991` (`backup_file` cp) and `:1024` (`backup_dir` cp -R).
- **Effect:** the installer relays console lines into deploy.jsonl, so an unformatted line goes there, and deploy.log loses the reason.
- **Suggested:** capture with `2>&1` into the message, as the manifest read already does (`setup-user-claude.sh:375`).

### N3 (non-blocking; this PR): the dry run does not preview a failure the real run reports

**Case `nocreatedry`:** `~/.claude/rules` is a file, with `--dry-run` / `-DryRun`.

- **Dry run, both languages:** rc 0. Log `[DRY RUN] Would create: d.md -> <H>/.claude/rules/d.md` (three times). Row `OK|claude rules|dry run (no files written)`.
- **Real run (`nocreate`), both languages:** rc 1. Row `ERROR|claude rules|cannot create rules dir`.
- **Code:** the rules-dir check is skipped under dry run (`setup-user-claude.sh:448`, `.ps1:462`).
- **Suggested:** in a dry run, when the destination exists and is not a directory, log it at error (or warn) and write `ERROR|claude rules|cannot create rules dir` or `N failed (dry run)`, so the preview matches the run.

### N4 (non-blocking; lib and spec conflict): tracker row longer than 30 characters

**Case `many`, both languages:** `WARN|claude rules|1 added, 1 updated, 2 removed, 2 verified` (41 characters).

- **Spec:** `.claude/rules/script-standards.md` and `reference/script-standards-detail.md` "Summary detail text rules" say "Max 30 characters (compliance-checked)". No check script enforces it: grep of `check-pre-commit.sh`, `check-pre-push.sh` and `check-post-push.sh` finds no 30-character test.
- **Contract:** the plan's section 3 row pins `N added, N updated, N accepted, N removed, N verified, N failed`. The new `removed` part makes long rows more likely.
- **Code:** `deploy_tracker_summary` (`aitools-lib.sh:2529`) and `Write-DeployTrackerSummary` (`aitools-lib.ps1:2511`). Older behaviour, shared by every tracker caller.
- **Suggested:** route as an ambiguity (the spec conflicts with the contract). Either cap or abbreviate the tracker text, or exempt tracker rows in the standard.

### N5 (non-blocking; this PR): a directory in place of the manifest is treated as "no manifest"

**Case `mfdir`:** `~/.aitools/rules/.aitools-rules-manifest` is a directory.

- **Both languages:** `[info] No rules manifest at ... -- every rule fanned out, none retired, adopt not offered`. Row `OK|claude rules|1 added`, rc 0. No warning.
- **Code:** `setup-user-claude.sh:371` (`[ ! -f ]`) and `.ps1:398` (`-PathType Leaf`) send a directory to the "absent" branch.
- **The lib already handles this:** `read_harness_manifest` reports a directory as unreadable (`aitools-lib.sh:2614`, "is a directory"), but it never gets called.
- **Suggested:** test existence (`[ -e ]` / `Test-Path` without `-PathType`) and let the reader fail, which gives `ERROR|claude rules|cannot read rules manifest`. That matches plan section 4.3 "Unreadable".

### N6 (non-blocking; vocabulary): "verified" when nothing was compared

**Case `retonly`:** the manifest retires `gone.md`; there is no rule to fan out; the user-edited `gone.md` is kept.

- **Both languages:** rows `ACTION||Claude Code still loads retired rules ...: gone.md ...` and `WARN|claude rules|verified`. Log `[ok] Rules: verified, 1 preserved`.
- **Problem:** the governed term "verified" means deployed content matches its source, and no file was deployed or compared.
- **Code:** the lib's default `parts="verified"` (`aitools-lib.sh:2521`, PS twin) when every count is 0.
- **Suggested:** have the fan-out write its own row in this case, for example `n/a (no harness rules)` or `0 deployed`. Decide this with plan question Q7 (vocabulary).

### N7 (non-blocking; existing code outside the rules span): multi-line detail entry in the ps deploy.log

**Every ps run (macOS):** line 15 of `runs/clean/ps.deploy.log` is `[detail] footer OS: Get-CimInstance Win32_OperatingSystem failed (The term 'Get-CimInstance' is not recognized ...`. Line 16, `Check the spelling of the name, ... -- using 'Windows'`, has no `[ts] [script] [level]` prefix.

- **Code:** `setup-user-claude.ps1:174` (`LogDetail "... ($_) ..."`). The exception text holds a newline.
- **Scope:** only seen because the .ps1 runs off Windows here. On Windows it fires only if CIM fails. Not part of this PR's change. Recorded so a log parser is not surprised by it.

## What was checked and passed (all 25 cases plus the abort run, both languages)

- **Line format:** every `[setup-user-claude]` line in every deploy.log matches `[YYYY-MM-DDTHH:MM:SSZ] [setup-user-claude] [info|ok|warn|error|detail] msg`, apart from N7. The resolver child's `[aitools-profile] [detail]` lines in the same file are correctly formatted.
- **Counters and exit:** the footer `FAILED with N error(s)` equals the number of `[error]` lines in every case. rc is 1 exactly when errors were logged, 0 otherwise, and 2 for abort.
- **Errors and warnings pair with rows:** every case with an error has an ERROR row. Every warning without an error has a WARN or ACTION row; OK rows are promoted to WARN. Each ACTION is paired with a log_warn (bad header, kept retired rules).
- **write_summary on every path:** n/a (missing, empty), dry run (`dry run (no files written)`), and every error path (`cannot read harness rules`, `cannot read rules manifest`, `cannot create rules dir`, `N failed`). No silent failures: every failure path logged a line and wrote a row. N1 is the exception: sh reports success for a write that went outside `~/.claude/rules`.
- **sh/ps parity:** summary rows, exit code and error/warn counts are the same in 24 of 25 cases. The exception is `destlink` (N1). Message texts differ only in the appended reason (N2) and in `--force` vs `-Force`.
- **Plan sections 3 and 4:** the observed rows match the contract rows in each covered case: 4.1, 4.2, 4.3 (absent, bad header, unreadable with the `.aitools-rules-manifest` failed item and final `ERROR N failed`, invalid lines), 4.4 (dangling source link, non-`.md` ignored with a log line, `*.bak.*` and hidden skipped), 4.5, 4.6 (abort), 4.7 (removed vs kept + ACTION, dry-run preview) and 4.8. Log lines tests rely on are present: the `claude rules: <name> source=... adopt=...` detail lines, `Ignoring non-rule file in harness rules`, `Not fanned out: ... (retired in the rules manifest)`, `No rules manifest at`, `[DRY RUN] Would back up and remove`.
- **Suite baselines:**
  - `tests/rules-fanout/test-rules-fanout.sh` (bash 5 + pwsh): 110 passed, 0 failed, 1 skipped (the case-only duplicate needs a case-sensitive file system).
  - `AITOOLS_TEST_BASH=/bin/bash ... --bash-only`: 42 passed, 0 failed, 21 skipped.
  - Both match plan section 12 item 6.

## Per-case table

rc and the final `claude rules` row are the same for sh and ps unless the row says otherwise.

| Case | Seed | rc sh/ps | Final `claude rules` row | Result |
|---|---|---|---|---|
| clean | shared/aitools/dotprofile rules, `notes.txt`, `*.bak.*`, user `mine.md` | 0/0 | `OK 3 added` | pass |
| missing | no `~/.aitools/rules` | 0/0 | `OK n/a (no harness rules)` | pass |
| empty | empty rules dir | 0/0 | `OK n/a (no harness rules)` | pass |
| unreaddir | rules dir chmod 000 | 1/1 | `ERROR cannot read harness rules` | pass (N2 text only) |
| mfunread | manifest chmod 000, rules present | 1/1 | `ERROR cannot read rules manifest` + `ERROR 1 failed` | pass |
| mfunreadonly | manifest chmod 000, no rules | 1/1 | `ERROR cannot read rules manifest` (no n/a row) | pass |
| badheader | header `v9` | 0/0 | ACTION + `WARN 1 added` | pass |
| mfempty | 0-byte manifest | 0/0 | ACTION + `WARN 1 added` | pass |
| mfdir | manifest is a directory | 0/0 | `OK 1 added` | N5 |
| invalid | bad name, bad source, duplicate | 0/0 | `WARN 2 added` (3 warns) | pass |
| srclink | dangling link in source | 1/1 | `ERROR 1 failed` | pass |
| destlink | dangling links in `~/.claude/rules` | **0/1** | sh `OK 3 added` / ps `ERROR 1 failed` | **N1** |
| nocreate | `~/.claude/rules` is a file | 1/1 | `ERROR cannot create rules dir` | pass (N2) |
| nocreatedry | same, dry run | 0/0 | `OK dry run (no files written)` | N3 |
| retired | removed (2) and kept (1, user-modified) | 0/0 | ACTION + `WARN 1 added, 2 removed` | pass |
| retireddry | same, dry run | 0/0 | ACTION + `WARN dry run (no files written)` | pass |
| retonly | only a retired, user-edited copy | 0/0 | ACTION + `WARN verified` | N6 |
| srcunread | harness rule chmod 000 | 1/1 | `ERROR 1 failed` | pass (N2) |
| destro | `~/.claude/rules` chmod 555 | 1/1 | `ERROR 2 failed` | pass |
| retunread | retired copy chmod 000 | 1/1 | `ERROR 1 failed` | pass (N2) |
| dryclean | clean, `--dry-run` / `-DryRun` | 0/0 | `OK dry run (no files written)` | pass |
| envdry | clean, `AITOOLS_DRY_RUN=1` | 0/0 | `OK dry run (no files written)` | pass |
| edited | local edit, stdin not a tty | 0/0 | `WARN 1 updated, 2 verified` | pass |
| force | local edit, `--force` / `-Force` | 0/0 | `WARN 1 updated, 2 verified` | pass |
| many | added, updated, removed, verified | 0/0 | `WARN 1 added, 1 updated, 2 removed, 2 verified` | N4 |
| abort (pty) | local edit, answer `x` | 2/2 | no row (by design, plan 4.6) | pass |

## Not run

- Native Windows: the .ps1 ran under pwsh on macOS with the OS guard patched off in a scratch copy, so Windows-only paths (CIM, `HKLM`, `COMPUTERNAME`) were not exercised.
- The generated MDM `deploy/setup-user-claude.*` from `build-deploy.sh`.
- The installer / `aitools` caller rows after exit 2 (`script failed (exit 2)`).
- Case-only duplicate names (APFS here is case-insensitive).
- Runs as root.
- Interactive adopt by hand (the suite's pty cases cover adopt).
- Linux.

## Reproduce

Scripts are copied beside this file:

- `a121b-runner.sh WORKTREE OUTDIR [case...]` seeds the cases and runs both languages.
- `a121b-analyze.pl OUTDIR` evaluates format, counters, rows, the 30-character limit, unstructured console output and parity.
- `a121b-abort.sh WORKTREE OUTDIR` runs the pty abort.

The real HOME was not touched. A before/after listing of `~/.claude`, `~/.claude/rules`, `~/.aitools`, `~/.aitools/rules` and `~/.aitools/logs` differs only in `~/.claude/history.jsonl` (written by the live Claude Code sessions). The real `~/.aitools/logs/deploy.log` has no line from the audit window.
