AUDIT (logging, A): FINDINGS

Scope: static logging and script-standards audit of PR #124 (FO-4) at fcf6edc, diff `f897b74..fcf6edc`: `fanout_harness_skills` + `_fanout_list_dir` (scripts/aitools-lib.sh 2842-3271), `Invoke-HarnessSkillsFanout` + `Get-FanoutSortedNames` (scripts/aitools-lib.ps1 2860-3318), the `skills fan-out` span in scripts/setup-user-claude.sh (693-701) / .ps1 (701-709), and the build-deploy.sh extraction (724, 816). Tests checked for silent failures only. Not functional review. Not deploy-harness. Version 1.0, by S3-FanoutImpl-AuditA124, 2026-10-26. Static only: nothing was run against any HOME.

**Verdict: no blocking findings.** Five non-blocking findings. Four of them follow patterns that already exist in the lib or in FO-3's rules fan-out.

Line numbers are for the fcf6edc versions (`git show origin/feature/fanout-claude-skills:<path>`).

## Findings

### N1 (non-blocking): the .sh drops the failure reason, and raw tool stderr goes to the console

Where the .ps1 puts the .NET reason into the `LogError`, the .sh runs an external command uncaptured. The command's own stderr (`cat: ...: Permission denied`, `mkdir: ...`) goes to the console as an unstructured line that is not in deploy.log. The structured `log_error` that follows carries no reason.

| Step | .sh | .ps1 |
|---|---|---|
| read a harness file | `$(cat "$_fs_sfile")` 3102, `log_error "Cannot read harness skill file X"` 3103 | 3126 `... X: <reason>` |
| create DEST | `mkdir -p` 2989, `log_error "Cannot create X"` 2990 | 3011 `Cannot create X (<reason>)` |
| executable bit | `chmod +x` / `chmod a-x` 3120 / 3125 (messages "cannot set" / "cannot clear") | 3159 (always "cannot set", with the reason) |
| backup root | `mkdir -p` 3200, `log_warn` 3201 | 3234 (with the reason) |
| backup copy | `cp -R` 3205, `log_error "Not removed: ... backup ... failed"` 3210 | 3249 (the reason goes to LogDetail) |
| remove | `rm -rf` 3214, `log_error "Cannot remove X (retired skill)"` 3215 | 3256 / 3261 (two messages, with the reason) |

The rows are identical in both languages. Only the log messages differ.

Rules: `.claude/rules/script-standards.md` "Log line format" ("Every log line must follow ...") and "External command error handling" (capture output), plus check item 7 (log-message parity).

Mitigation: `backup_dir` already uses the same uncaptured `cp -R` (aitools-lib.sh:1066), so this is an existing lib pattern, not a regression.

Suggested fix: capture `2>&1` into a variable and append it to the `log_error`, as the function already does for `_fanout_list_dir` (2907) and `read_harness_manifest` (2923).

### N2 (non-blocking): some log_warn lines do not carry their ACTION's instruction

`reference/script-standards-detail.md` "Severity decision guide" says: "`log_warn` + `write_summary ACTION` -- always pair ACTION with a log_warn carrying the same instruction".

- **Header-bad manifest.** The `log_warn` (sh 2928 / ps 2954) says "every skill fanned out, none retired, adopt not offered". It does not say "Run aitools to rebuild ~/.aitools/skills and its manifest", which is the ACTION text (2929 / 2955).
- **Kept symlink or file.** The `log_warn` (3023 / 3045) says "-- the harness copy is not deployed". The ACTION (3137 / 3167) says "move them aside to get the aitools copy".
- **Retired copy kept.** The `log_warn` (3183 / 3217) is close enough to its ACTION (3223 / 3269).

Mitigation: FO-3's rules fan-out has the same header-bad pair (setup-user-claude.sh:396-397), so the two fan-outs are consistent.

Suggested fix: append the ACTION text to the two `log_warn` lines, in both languages. FO-3 can get the same change later.

### N3 (non-blocking): the retired-prune backup roots are never pruned

Each run that removes a retired skill creates a new `DEST.bak.<UTC>/` directory beside DEST: sh 3192-3202, ps 3226-3236.

`.claude/rules/config-file-safety.md` "Backup before overwrite / Retention" says: "Directories: `<dir>.bak.<TIMESTAMP>/`, keep at most 5, auto-prune oldest".

`backup_dir`'s pruning (aitools-lib.sh:1073-1090, `max_backups=5` at 1033) runs only after its own copy. For skills that copy never happens, as PR body "Contract change" 2 says. So these roots pile up, one per such run.

A second, smaller issue: the root is created (3200 / 3232) before the copy is tried. A failed copy leaves an empty `skills.bak.<UTC>/` behind.

The case is rare (it needs a retired skill whose copy matches), so this is non-blocking.

Suggested fix: either prune `DEST.bak.*` roots to 5 after a successful backup (the same name regex as `backup_dir`), or record the exception in FO-7's docs next to Contract change 1.

### N4 (non-blocking): some log_warn conditions get no row that says what went wrong

These are logged with `log_warn` and get no dedicated row:

- "Cannot compare ..." (3179 / 3214)
- "Cannot list DEST for the retired skills" (3148 / 3181)
- "Cannot list DEST for the preserved report" (3238 / 3287)
- invalid manifest lines (2936 / 2958)

The final row becomes WARN only because `write_summary` turns OK into WARN once `WARNINGS > 0`. Its text stays the tracker count (for example `1 added`), so the row does not say what is wrong.

`reference/script-standards-detail.md` "Severity decision guide" says: "`log_warn` + `write_summary WARN` -- ... (disclose the caveat)".

Contract 3.4 does not require these rows, and the log says what happened, so this is non-blocking. A fix is optional.

### N5 (non-blocking, tests): two ways the suite could pass without testing

- `tests/skills-fanout/test-skills-fanout.sh:64-68`: when `perl` or `git` is missing, the suite prints `SKIP all cases` and exits 0, so CI would be green with no cases run. Both tools are always on the CI runners, so the risk is low. A fix would be to exit 1 when `CI` is set.
- `:25` runs `set -uo pipefail` without `-e`, and the fixture setup commands (88-114) are unchecked. A failed setup does surface as failed checks (the row, tree and parity checks), so it is not silent.

The other suppressions in the tests are guarded:

- `:41` cleanup: comment plus a fallback warning.
- `:194-195` `logged` / `logged_re` with `2>/dev/null`: commented, and used only in positive assertions, so a missing log makes the check fail.
- The claude-mdm and deploy-harness-mdm changes check every run's exit code and rows.

### Out of scope (for the functional reviewer, not a logging finding)

Each file is read as text: sh `$(cat)` (3102) drops NUL bytes and trailing newlines, and ps reads with `ReadAllText` UTF-8 (3124). A binary file in a skill would be deployed corrupted, and the result would still be reported as created or verified.

No tracked file under `shared/skills` or `.claude/skills` is binary or empty today (`git ls-tree -r fcf6edc`).

## Checks that passed

1. **Log line format.** Every new log line goes through `log` / `log_ok` / `log_warn` / `log_error` / `log_detail`, or `Log` / `LogOk` / `LogWarn` / `LogError` / `LogDetail`. No `echo`, `printf` or `Write-Host` is used for log output in the new functions or the call spans. The backup-root stamps are UTC with a Z suffix: sh `date -u +%Y-%m-%dT%H%M%SZ` (3193), ps `.ToUniversalTime()` (3227). The one gap is the raw stderr in N1.
2. **log_error pairs with an ERROR row on every error path.**
   - Paired directly: caller bug, `cannot read harness skills`, `cannot read skills manifest`, `cannot create skills dir`.
   - Recorded as a `failed` item, which makes the tracker's `ERROR N failed` row (sh 2596-2597 / ps 2620-2621): dangling symlink, case-only duplicate, walk error, unreadable file, unexpected deploy result (3109-3113 / 3140-3143), executable bit, backup failed, remove failed.
   - Post-write validation: `ERROR validation failed` (3268 / 3316), or the tracker ERROR row when items also failed.
   - Every `deploy_managed_file` `failed` result is recorded with the tracker (the lib returns 0 on every path and logs its own `log_error`).
3. **WARN and ACTION rows per contract 3.4.** Header-bad: `log_warn` + ACTION. A symlink or file at DEST/<name>: `log_warn` + `preserved` + one ACTION. A retired copy that matches nothing: `log_warn` + one ACTION. A skipped review: the tracker's WARN `N skipped (user review)`.
4. **A write_summary row on every path.**

   | Path | Row |
   |---|---|
   | caller bug | ERROR `fan-out not run (caller bug)` |
   | no harness skills | OK `n/a (no harness skills)` |
   | unreadable harness dir | ERROR `cannot read harness skills` |
   | empty harness dir | OK `n/a` (or the manifest's ERROR row) |
   | DEST cannot be created | ERROR `cannot create skills dir` |
   | dry run | OK `dry run (no files written)` / ERROR `N failed (dry run)` |
   | normal end | the tracker row, or ERROR `validation failed` |
   | abort | exit 2 from the library, no row, as the contract says (FD-7) |

   Every row is identical in both languages.
5. **log_detail lines are single-line.** The detail lines carry a name, item and adopt path (names holding a newline are filtered out by `_fanout_list_dir` and the walker), or one .NET exception message. Multi-line reasons from `fanout_dir_matches` / `fanout_text_equal` go through `_fanout_log_detail_lines`, one prefixed line each.
6. **No unguarded suppression.** The script diff has no `2>/dev/null`, `|| true`, `-ErrorAction SilentlyContinue`, `2>$null` or empty `catch {}` (grep count 0). Every `|| _fs_*rc=$?` is checked on the next line. Every ps `catch` logs: `LogError`, `LogWarn`, or `LogDetail` followed by a checked fallback.
7. **sh/ps parity of rows.** Category, tool name and detail text are the same on every path, including both ACTION texts and the `~/...` display of DEST. The suite's `parity` check compares sorted rows, trees and exit codes for every case. Log-message differences are listed in N1.
8. **The `removed` outcome and deploy_managed_file return values.**
   - `removed` is recorded at sh 3220 / ps 3266. `deploy_tracker_record` (aitools-lib.sh:2570-2571) and `Record-DeployOutcome` (aitools-lib.ps1:2595) both write `DETAIL <tool> removed: <item>` and count it in the summary text `N removed` (2590 / 2614). `preserved` writes no DETAIL row in either language (2573 / 2597).
   - Every `deploy_managed_file` return value is handled at the call site: `created`, `updated`, `verified`, `accept & adopt`, `skipped` and `failed` go to the tracker, and anything else is `log_error` + `failed` (sh 3109-3113, ps 3140-3143), as the `interactive-menus.md` "Return value contract" requires.
9. **Summary detail text is at most 30 characters.** `n/a (no harness skills)` 23, `cannot read harness skills` 26, `cannot read skills manifest` 27, `fan-out not run (caller bug)` 28, `cannot create skills dir` 24, `dry run (no files written)` 26, `validation failed` 17. ACTION rows are instructions, not detail text. The tracker's own count text comes from the existing lib.
10. **The build-deploy extraction markers match exactly one line each.** `^# --- BEGIN skills fan-out` and `^# --- END skills fan-out` occur once in setup-user-claude.sh (693, 701) and once in setup-user-claude.ps1 (701, 709). They are extracted at build-deploy.sh 724 and 816 (`--crlf`; the regex is anchored at the line start, so CRLF does not matter). `inline_lib_bash` / `inline_lib_ps1` inline the whole lib, so the MDM copies carry the function. Its inputs are defined unconditionally inside extracted spans, so `set -u` is safe: `RULES_AITOOLS_REPO=""` (setup-user-claude.sh:318), `$rulesAitoolsRepo = ""` (ps:348), `CLAUDE_DIR` (62), `${USER_REPO_PATH:-}`.
11. **Manifest edge-case parity.** A dangling-symlink manifest is not "absent" in either language: the .sh tests `! -e && ! -L`, and pwsh 7.6.3 `Test-Path -LiteralPath` returns True for a dangling symlink (probed in scratch). Both then report it as unreadable.

Reviewed against: `.claude/rules/script-standards.md`, `reference/script-standards-detail.md`, `reference/logging.md`, `reference/managed-file-deployment.md`, `.claude/rules/interactive-menus.md`, `.claude/rules/config-file-safety.md`, `plans/skills-and-rules-fanout.md` 3.3, 3.4 and FO-4, the PR #124 body "Contract change (3.4)", and brief section 3 error-handling rules 1-8.
