AUDIT (logging, B): FINDINGS -- 0 blocking, 5 non-blocking

Second, independent logging and script-standards audit of PR #118. I ran the code; I did not review it for function. Auditor: S3-FanoutImpl-AuditB118 (level 2, under S3-FanoutImpl). I did not read the other auditor's output or the author's notes.

**Scope**: `git diff d7f6855...origin/feature/fanout-lib` (head 14f9fb1), `scripts/aitools-lib.sh` / `.ps1` only.
**Method**: I sourced each lib under an isolated HOME (`<worktree>/.scratch/session-a118b/home-*`; pwsh launched with `HOME=` set, and the script refuses to run if `$HOME` is outside scratch). Both harnesses run the same 40 cases with fixtures from `fixtures.sh` (chmod 000 files and directories, a directory passed as a file, missing files, a symlink, a FIFO, a BOM+CRLF manifest and invalid lines). Each prints return codes, counters, summary rows and `deploy.log` lines with the timestamps stripped. Then I diffed the two outputs.
**Rules applied**: `.claude/rules/script-standards.md`, `reference/logging.md`, `reference/script-standards-detail.md`, the error-handling rules 1-8 (`reference/plan-execution-detail.md`, delegate brief section 3).

## Passed (runtime evidence)

| Check | Result |
|---|---|
| Unknown tracker outcome (`bogus`, `""`) | sh and ps both log one `[error]` line each (`deploy_tracker_record: unknown outcome "bogus" for f.md (claude rules) -- counted as failed` / `Record-DeployOutcome: ...`), count it (`ERRORS`/`$script:errors` = 2), write `DETAIL\|claude rules\|failed: f.md`, and the tracker summary writes `ERROR\|claude rules\|2 failed`. Identical in both. |
| `removed` rows | `DETAIL\|<tool>\|removed: <item>` per item. The summary text lists the count (`1 added, 1 updated, 2 removed, 1 verified, 2 failed`; with no failures `OK\|cursor rules\|1 removed, 1 verified`). Identical in both. |
| Log line format | Every new line is `[<utc>Z] [audit-118b] [error\|detail] msg`. Detail lines are file-only (`log_detail` / `LogDetail` write only `$LOG_FILE`). |
| Library-style contract (`logging.md` section 7) | The manifest reader and the compare helpers write no summary rows and touch no counters. They return codes (sh) or throw (ps) and leave the leveled log line to the caller. Read failures go to `detail`. |
| Manifest: unreadable / directory / missing / unknown kind | sh exits non-zero with the reason on stderr. ps throws with the reason. Header-bad, BOM+CRLF, duplicate (case-insensitive), `/`, `.bak.`, bad source, missing source and an unterminated `\r` last line give the same result lines in both (ps keeps `Rules` and `Invalid` apart, so the interleaving order differs; the content is the same). |
| `fanout_text_equal` / `Test-FanoutTextEqual` | Same codes for all 6 cases: same 0, different 1, unreadable 2, directory 2, missing 2, CRLF vs LF 0. A detail line on each 2. |
| `fanout_dir_matches` / `Test-FanoutDirMatches` | Same codes for 9 of 9 shared cases: match 0, empty 1, unreadable file 2, unreadable subdirectory 2, symlink 1, missing in candidate 1, different 1, `.BAK.` only 1, no target 1. A detail line on each 2. |
| Error-handling rules 1-8 | The new code has no `-ErrorAction SilentlyContinue`, `2>/dev/null` or `\|\| true`. `\|\| rc=$?` is captured and checked. Every `catch` calls `LogDetail` and returns 2. |
| Syntax / suite | `bash -n` ok. pwsh `Parser::ParseFile` ok. `HOME=<scratch> bash tests/fanout-lib/test-fanout-lib.sh`: 284 passed, 0 failed, 0 skipped. |

## Findings (all non-blocking)

**N1. The detail lines for read failures differ between sh and ps.** `scripts/aitools-lib.sh:2662`, `:2711`; `scripts/aitools-lib.ps1:2613`, `:2661`.
- sh `fanout_text_equal` logs `fanout_text_equal: cannot read <A> or <B>`. It does not say which file failed or why. ps logs the same text plus the .NET exception (`Access to the path '<B>' is denied.`, `Could not find file ...`).
- For an unreadable file inside a tree, sh logs under `fanout_dir_matches:`. ps logs only under `Test-FanoutTextEqual:` (called from `:2661`); no `Test-FanoutDirMatches:` line is written.
- Counters, rows and codes are the same, but a log search by function name or reason finds different things on each platform.
- Suggest: in the sh perl blocks, print the failing path and `$!` to STDERR and log that. In ps, when `$eq -eq 2`, also write `LogDetail "Test-FanoutDirMatches: cannot read $($e.FullName) or $cp"`.

**N2. A missing manifest exits 2 in `read_harness_manifest`, the same code as an unknown KIND.** `scripts/aitools-lib.sh:2599-2615`.
- The read failures use perl `die`, so the exit code comes from errno: missing file = 2 (ENOENT), permission denied = 13, directory = 255. The header documents exit 2 as "unknown KIND".
- The header only promises "non-zero" for a read failure, so the contract holds. But a caller that treats 2 as its own bug would misreport a missing manifest.
- Suggest: `print STDERR ...; exit 1` for the read failures, so the codes are fixed and distinct.

**N3. `Test-FanoutDirMatches` does not reject non-regular entries; it hangs on a FIFO.** `scripts/aitools-lib.ps1:2655-2661` vs `aitools-lib.sh:2703-2705`.
- With a FIFO under Target, pwsh on macOS blocked in `ReadAllBytes` until my 20 s alarm killed it (exit 142). sh returns 1 ("another non-regular entry").
- The `.ps1` runs only on Windows (OS guard), where an NTFS tree has no FIFOs, so in practice the risk is low.
- The PS header says "Parity: ... same results" but documents only reparse points. Suggest: either document the gap in the PS comment, or skip any entry that is not a plain `FileInfo` / `DirectoryInfo` with no special attributes.

**N4. `removed` is a new deployment outcome without governed vocabulary.**
- It is not in the term list in `.claude/rules/glossary.md` (which has `created`, `updated`, `verified`, `skipped`, `preserved`, `recovered`, ...), nor in `reference/script-standards-detail.md` "Governed summary outcomes".
- The tracker row in `reference/managed-file-deployment.md` does not list it either. `interactive-menus.md` "Return value contract" step 2/4 lists `Record-DeployOutcome` and the spec doc as things to update when an outcome is added.
- `TODO(glossary)`: define `removed` (deployed file backed up and deleted by a fan-out prune) and list it in the two reference tables.

**N5. Adding `removed` makes the summary text more likely to exceed the 30-character cap.**
- `reference/script-standards-detail.md` "Summary detail text rules" caps detail text at 30 chars. The OK row's text now joins up to 5 counts, e.g. `12 added, 3 updated, 4 removed, 40 verified` (43 chars).
- The behaviour was there before this PR; `removed` widens it. Suggest a follow-up: shorten the parts, or move the long form to `DEPLOY_TRACKER_TEXT` / a log line only.

## Not run
- A FIFO on the **candidate** side (sh and ps would both open it). I believe both would block, but I did not test it.
- Windows: everything was run with pwsh 7 on macOS, so the Windows ACL and reparse-point paths were not exercised there.
- The consumers (setup-user-claude/cursor) do not call these helpers in this PR. Whether a caller logs the returned diagnostics at level is for the consumer PRs' audits.

Artifacts (scratch, unharvested): `.claude/worktrees/fo-aud118b/.scratch/session-a118b/{fixtures.sh,audit-sh.sh,audit-ps.ps1,run-all.sh,syntax-and-suite.sh,out-sh.txt,out-ps.txt,diff-sh-ps.txt,out-ps-fifo.txt,suite.txt}`.
