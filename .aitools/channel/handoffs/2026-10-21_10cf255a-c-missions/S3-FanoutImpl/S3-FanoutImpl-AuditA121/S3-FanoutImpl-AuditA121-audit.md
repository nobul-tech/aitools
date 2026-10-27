AUDIT (logging, A): FINDINGS

Static logging / script-standards audit of PR #121 by S3-FanoutImpl-AuditA121 (2026-10-26). Read-only: diffs of b27ab1a and a0bd5e4, branch files at `origin/feature/fanout-claude-rules` (66c58cb), test file from bba5fad. Nothing was run. Line numbers are the branch versions.

**No blocking findings.** Eight non-blocking findings: five in the scripts, three in the test.

## Findings

### N1 (non-blocking): ACTION rows not paired with a log_warn that carries the same instruction
- `scripts/setup-user-claude.sh:380-381`, `scripts/setup-user-claude.ps1:410-411`: the bad-header ACTION `Run aitools to rebuild ~/.aitools/rules and its manifest` is paired with a log_warn about the header. That log_warn does not say "run aitools".
- `scripts/setup-user-claude.sh:561,594`, `scripts/setup-user-claude.ps1:590,634`: the retired-rule ACTION is paired with per-file `Kept ...` warnings. They carry similar text, not the ACTION text.
- Rule: `reference/script-standards-detail.md` "ACTION items" ("Always pair with a `log_warn` carrying the same text") and the severity decision guide. Both languages do the same thing, and both match the plan contract (section 3 ACTION rows). Suggested fix: append the ACTION instruction to the paired log_warn, or log one more log_warn with the ACTION text.

### N2 (non-blocking): log message text differs between sh and ps1 (summary rows are identical)
- Unreadable harness dir: sh:356 `Cannot list X (permission denied)` vs ps1:384 `Cannot list X -- <exception>`.
- Retired removal failure: sh:586 has one message, `Cannot remove X (retired rule)`. ps1 has two: :621 `... -- <exception>` and :626 `...: still present`.
- ps1:521 and :565 append the exception text to messages that have it in sh only implicitly (sh:502, :543).
- Warning paths in one language only: ps1:557, :577, :610, :649 (`LogWarn` when a .NET directory enumeration throws; bash has no such failure point), and sh:312 (`log_warn` when `cd` fails while resolving the aitools checkout).
- Rule: `.claude/rules/interactive-menus.md` / mission brief "sh/ps1 parity of rows and messages". Rows and levels match. A warning in one language only can turn the final OK row into WARN in that language alone, but only on an I/O failure. The test's `parity` compares rows, not log text.

### N3 (non-blocking, carried over): `Get-Item` without error handling in post-write validation
- `scripts/setup-user-claude.ps1:663`: `(Get-Item -LiteralPath $destFile).Length -eq 0` has no `-ErrorAction` and no try. If the file disappears between `Test-Path` and `Get-Item`, a non-terminating error prints and the empty-file check is silently false.
- Rule: `reference/plan-execution-detail.md` error-handling audit checklist ("Get-Content (no -ErrorAction): error handling present"), rule 7 (prefer `-ErrorAction Stop` + try/catch). The code before the PR had the same pattern.

### N4 (non-blocking, note): the catch body does not log itself
- `scripts/setup-user-claude.ps1:466-470`: the catch only stores `$mkdirError`. The error is logged at :475 (`LogError` + ERROR row) after the re-check at :473.
- Rule 4 ("catch MUST log or re-throw") is met in effect, not literally. This is acceptable as written: the re-check is the documented fix for `New-Item -Force` returning without an error (plan section 12, item 4).

### N5 (non-blocking, out of this diff): the tracker OK detail can exceed 30 characters
- `deploy_tracker_summary` (`scripts/aitools-lib.sh:2515-2529`, PS twin `Write-DeployTrackerSummary`) joins every non-zero count, for example `3 added, 2 updated, 1 removed, 31 verified` (42 characters).
- This PR sends every project and shared rule through this row (about 35 files), so long rows become likely on mixed runs.
- Rule: `.claude/rules/script-standards.md` / `reference/script-standards-detail.md` "Summary detail text rules" (max 30 characters, "compliance-checked"). The lib code is not in this PR (FO-1). I do not know which check step enforces the 30-character limit or whether it inspects runtime rows. Suggested: a lib follow-up, for example `N files: N changed` past 30 characters.

### N6 (non-blocking, test): an assertion that can pass vacuously
- `tests/rules-fanout/test-rules-fanout.sh:367` ("adopt map: aitools -> aitools .claude/rules") ANDs two independent `logged` matches:
  - `claude rules: p.md source=aitools adopt=` also matches `adopt=none`.
  - `/.claude/rules/p.md` also matches the lib's `Created: p.md -> <HOME>/.claude/rules/p.md` (`scripts/aitools-lib.sh:2048`). That is the deploy destination, not the adopt target.
- So the check passes even when no adopt target is offered.
- L366 (shared) uses the same two-part pattern. No vacuous source for it is known, but it is equally weak.
- Mitigation: the pty adopt test (L379, needs python3) and the payload test (L402) cover the real behaviour.
- Suggested fix: match the full line as L368 does, `adopt=$A/.claude/rules/p.md`. On macOS, mind the `/var` vs `/private/var` spelling of `$TMP_ROOT`.

### N7 (non-blocking, test): pipelines under `set -o pipefail`
- `logged()` (L174: `cat ... 2>/dev/null | grep -qF`) and the `ls ... | grep -q` checks: `grep -q` exits on the first match. A large `cat` can then get SIGPIPE, and pipefail turns a match into a false FAIL. That makes a flaky failure, never a silent pass.
- The negated forms (`! ls ... | grep -q`, L245, L276; `! grep -q`, L271) pass if `ls` or `grep` cannot read their input. Each one is ANDed with a positive condition in the same check (L245 `mine.md`, L276 and L271 via the case's row checks), so none passes alone.
- The `2>/dev/null` at L36 and L174 is commented and result-checked.

### N8 (non-blocking, test): fixture setup unchecked
- The script runs `set -uo pipefail` without `-e`, by design: checks count failures.
- The fixture commands (L81-L104: `cp`, `perl`, `git init/commit`) are not checked. A failed fixture shows up as failed cases. The exceptions are checks made only of negations: L246, L270, L273 would pass on their own, though their sibling checks in the same case would fail.
- Suggested fix: a `|| { printf 'FATAL ...'; exit 1; }` on the fixture block.

## Checked and clean

- **Log line format:** every new line goes through lib `log` / `log_ok` / `log_warn` / `log_error` / `log_detail` (`Log` / `LogOk` / `LogWarn` / `LogError` / `LogDetail`). There is no raw `echo` or `Write-Host` in the new spans (sh:291-640, ps1:323-681). `build-deploy.sh` keeps its own `blog` / `blog_ok` / `blog_warn` / `blog_error` (L44-52, `[ts] [script] [level] msg`, UTC Z). The PR only deletes `blog` calls and adds comments there.
- **Every log_error is paired with an ERROR row:**
  - Direct rows: sh:356/357, ps1:384/385 (cannot read harness rules); sh:376/377, ps1:405/406 (manifest); sh:451/452, ps1:475/476 (rules dir).
  - Rows through the tracker (`failed`, then `deploy_tracker_summary` writes `ERROR N failed`): manifest item, dangling symlink, case-duplicate, unreadable rule, unexpected result, and every retired-removal failure (sh:466, 483, 502, 514, 543, 581, 586; ps1:490, 504, 521, 533, 565, 614, 621, 626).
  - Validation failures (sh:623, ps1:664) go to `ERROR validation failed` (sh:635, ps1:676), or to the tracker ERROR row when an item failed.
- **write_summary on every terminal path:** dir missing / empty gives `OK n/a (no harness rules)`, and the n/a row is suppressed after a manifest error (RC-2). The error paths are above. Dry run gives `OK dry run (no files written)` or `ERROR N failed (dry run)`. Success goes through the tracker. `[x]abort` writes no row, by contract (plan section 4 item 6).
- **Script-written detail text is at most 30 characters:** `n/a (no harness rules)` 22, `cannot read harness rules` 25, `cannot read rules manifest` 26, `cannot create rules dir` 23, `dry run (no files written)` 26, `validation failed` 17, `N failed (dry run)`. ACTION free text follows the existing ACTION convention.
- **WARN rows:** warnings (bad header, invalid manifest lines, kept retired copies, compare failures) raise WARNINGS, and the lib turns the final OK row into WARN. The test expects this (L300, L307, L347, L352).
- **Suppression:** the new code has no `2>/dev/null`, `|| true`, `-ErrorAction SilentlyContinue` or empty `catch {}` (grep over both spans). The only `2>&1` (sh:375) is a capture with an exit check. `|| rm_rc=$?` (sh:551) captures the code and checks it on the next line. `rm -f` is inside an `if !` with an existence re-check (sh:585). `Remove-Item -ErrorAction Stop` is in try/catch (ps1:619). Every catch logs (ps1:383, 404, 448 detail, 520, 556, 564, 576, 609, 620, 648; 468 see N4).
- **Exit footer:** unchanged and checks both counters (sh:643-652, ps1:684-693). Script block order and OS guard are unchanged.
- **Plan contract (rules-fanout-claude.md sections 3 and 4):**
  - Every final row, both ACTION texts, the `removed` outcome and the tested log lines appear verbatim in both languages: `claude rules: <name> source=... adopt=...` at detail level, `Ignoring non-rule file ...`, `Not fanned out: ...`, `No rules manifest at ...`, `[DRY RUN] Would back up and remove ...`.
  - Contract paths, the adopt-target rule (`.git` required) and `$claudeScriptDir` match.
  - The lib helpers the scripts call exist on the branch: `fanout_text_equal`, `rule_name_kind`, `read_rules_manifest`, `lower_name`, `in_list`, `RULES_MANIFEST_HEADER`, `BACKUP_FILE_OK`, the tracker `removed` (aitools-lib.sh:982, 2485-2531, 2544-2665), and their PS twins (aitools-lib.ps1:847, 2473, 2494, 2528-2607).
- **build-deploy.sh (a0bd5e4):** deletions plus comments. No `USER_RULE_*`, `embed/rules`, `aitoolsEmbedRules` or `Rules fallback` is left (grep). No new error path.
- **CRLF:** `.gitattributes` has `*.ps1 text eol=crlf`. The blob is LF throughout (694 of 694 lines), so the checkout is uniformly CRLF.

## Not done
- Nothing was run (static audit by mission scope): no bash -n, no pwsh parser, no tests.
- The runtime auditor's output (AuditB121) was not read.
