AUDIT (logging, A): PASS -- no blocking findings, 6 non-blocking

Auditor: S3-FanoutImpl-AuditA118 (static logging / script-standards audit, independent of auditor B).
Scope: `git diff d7f6855...14f9fb1` (PR #118 head `14f9fb131285fe752627f093bf304ce5869be0ac`) for `scripts/aitools-lib.sh` and `scripts/aitools-lib.ps1`; `tests/fanout-lib/test-fanout-lib.sh` and `.github/workflows/check.yml` checked for silent failures only. Not run: no code was executed (static audit); functional correctness is out of scope.
Line numbers are at the PR head.

## Checked and clean

| Check | Result | Evidence |
|---|---|---|
| Tracker edits match FAN-PLAN A1-A4 verbatim | yes | `plans/rules-fanout-claude.md` lines 255-318 / 439-497 vs the diff; message text `unknown outcome "<o>" for <item> (<tool>) -- counted as failed` identical in sh and ps |
| Summary order: `removed` after `accepted`, before `verified` | yes | aitools-lib.sh `deploy_tracker_summary` (the `_DT_REMOVED` line between `_DT_ACCEPTED` and `_DT_VERIFIED`); aitools-lib.ps1 `Write-DeployTrackerSummary` same order |
| DETAIL text `removed: <item>`, `failed: <item>` for unknown | yes, sh = ps | aitools-lib.sh:2498-2504, aitools-lib.ps1:2481-2488 |
| Counters: unknown outcome counts ERRORS once (log_error), `_DT_FAILED` once; summary ERROR row does not count again | yes | aitools-lib.sh:2502 + `log_error` at :787; `write_summary` does not touch ERRORS; test `t-mix` asserts `errors=1` |
| Counters reset in both init sites (bash file scope + `deploy_tracker_init`; ps script scope + `Initialize-DeployTracker`) | yes | diff hunks at aitools-lib.sh:2471/2476, aitools-lib.ps1:2460/2465 |
| New helpers do not call log_error / log_warn (return codes; caller decides severity) | yes | `fanout_text_equal`, `fanout_dir_matches`, `read_harness_manifest` and the ps twins log at detail only, matching plan section 3.3 and 3.4 (the caller turns rc 2 into ERROR) |
| Expected failures logged at detail level | yes | aitools-lib.sh:2662, :2719; aitools-lib.ps1:2613, :2637, :2649 |
| Suppression patterns | none unguarded | lib: no `2>/dev/null`, `|| true` or `-ErrorAction SilentlyContinue`; `|| rc=$?` captures and returns the code; every ps `catch` logs and returns 2. Tests: :39 and :129 `2>/dev/null` have a comment and a result check; :34 is a command-existence check |
| Log line format | yes for single-line messages (see N1) | `log_detail` / `LogDetail` used, no raw echo |

## Non-blocking findings

**N1 (non-blocking) -- multi-line detail message breaks the log line format.** aitools-lib.sh:2680-2719 `fanout_dir_matches`: perl prints one `cannot list ...` / `cannot read ...` line per unreadable entry (:2697, :2711), the output is captured into `$why`, and `log_detail "fanout_dir_matches: $why"` writes it as one printf. With two or more unreadable entries the second and later lines land in deploy.log without the `[timestamp] [script] [detail]` prefix (script-standards "Log line format": every log line). The ps twin logs one `LogDetail` per entry (aitools-lib.ps1:2649, and through `Test-FanoutTextEqual` :2613), so it is fine. Suggested fix: join the lines before logging, e.g. `why=${why//$'\n'/; }` (bash 3.2 safe), or loop `while IFS= read -r l; do log_detail "fanout_dir_matches: $l"; done <<< "$why"`.

**N2 (non-blocking) -- bash `fanout_text_equal` logs only rc 2.** aitools-lib.sh:2649-2664: when perl itself fails (rc 255, or 127 if perl is missing) nothing is logged and the code is returned; any perl stderr goes to the console, not the log. Callers that test `-eq 0` treat it as "differ" (safe for the prune, but silent). Suggested: log at detail for any rc other than 0 and 1, and capture perl's stderr as `fanout_dir_matches` does.

**N3 (non-blocking) -- `read_harness_manifest` exit 2 is ambiguous.** The header says "Exit 2 for an unknown KIND; exit non-zero when FILE cannot be read" (aitools-lib.sh:2590-2601), but perl `die` exits with `$!`, which is 2 (ENOENT) for a missing file (`perl -e 'open ... or die'` -> exit 2, checked). A caller cannot tell a caller bug (unknown kind) from a missing manifest by the code. Harmless if every caller treats non-zero as failure and logs the captured message (the contract says so); suggest the header says "any non-zero exit is a failure; the message on stderr says which", or `exit 3` for an unreadable file inside perl.

**N4 (non-blocking) -- tracker outcome matching differs sh vs ps for case.** aitools-lib.ps1:2475 `switch ($Outcome)` is case-insensitive; bash `case` (aitools-lib.sh:2485-2505) is case-sensitive. A mis-cased outcome (`Removed`) is counted `removed` in ps but logged as an unknown-outcome error and counted `failed` in bash. Pre-existing for the old values, but the new `default` branch makes the difference a counted ERROR on one platform only. Suggested: `switch -CaseSensitive ($Outcome)`, as `Read-HarnessManifest` already does, plus one parity test case.

**N5 (non-blocking) -- detail messages are not the same text sh vs ps.** bash `fanout_text_equal: cannot read A or B` (no reason) vs ps `Test-FanoutTextEqual: cannot read A or B: <exception>`; inside the directory walk bash logs `fanout_dir_matches: cannot read P or CP` while ps logs it under the `Test-FanoutTextEqual:` prefix (aitools-lib.ps1:2661 -> :2613). Exit codes match; only the log text differs. Suggested: add `$!` to the bash messages; optional.

**N6 (non-blocking) -- tests do not assert the detail log lines.** The suite checks return codes and the unknown-outcome error line, but no case checks that rc 2 from `fanout_text_equal` / `fanout_dir_matches` writes a detail line, and the reader's stderr in the bash driver (test-fanout-lib.sh:286, `2>"$WORK/err-sh"`) is captured and never inspected. N1 would have been caught by a two-unreadable-entries case that greps the log for unprefixed lines.

## Notes (not findings)

- The `removed` outcome is not yet in `reference/managed-file-deployment.md` (Functions table and the return-value / tracker table). The plan assigns that doc update to a later batch (`plans/skills-and-rules-fanout.md` FO-7 list: "`reference/managed-file-deployment.md` (tracker `removed`, ...)"), so it is a follow-up, not an FO-1 defect.
- PowerShell `$rulesManifestHeader` / `$skillsManifestHeader` (aitools-lib.ps1:2528-2529) are set without `$script:`, unlike the tracker variables. Works when the lib is dot-sourced at script level (all current callers); a style inconsistency only.
- CI (`.github/workflows/check.yml`) adds the suite on macOS (bash 5 + pwsh, /bin/bash 3.2) and Linux; no suppression in the steps.
