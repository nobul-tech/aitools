# 38dc-14 report: PR #157 record fix (B1, N1-N3, N5 of review 38dc-10)

**Version**: v1.0 (2026-11-14). **Author**: 38dc-14-pr157-record-fix, delegated by
M6-Polish (level 2 under Session Commander 87795dc3-e). **Branch**: `fix/m6-logging`
(PR #157), started at 63ea0db (clean). **Review answered**: 38dc-10's verdict,
https://github.com/nobul-tech/aitools/pull/157#issuecomment-6882816582.
No code behaviour change: one comment in `scripts/aitools-install.ps1`, docs, the
release notes and the incident registry.

## Summary

1. B1 confirmed on the branch: the `aitools` entry points (`scripts/aitools:1237`,
   `:1243`, `:2107`; `scripts/aitools.ps1:286`, `:2046`) and two hooks
   (`standing-order-guard.sh:63` and `:99-101`, `tool-ops-session-audit.sh:101-103`)
   append unguarded. Probes confirm each failure mode (below).
2. Filed **#178** (open, high): one incident for both groups, with the hooks' lower
   impact stated in the entry. The incident rules do not require two entries, so #183
   is not used.
3. #174's `correctiveAction`, `closedIn`, `rootCause` and `preventionLayer` now claim
   only the six writers it names, and point to #178. #177's `closedIn` names v0.77.5.
4. RELEASE_NOTES v0.77.5 is narrowed: title, row 1 (and its PowerShell-installer
   claim, corrected by the N3 check), row 2 is now High, and rows 4 and 5 record
   the new docs and #178. `reference/logging.md` section 5 names what is not
   fail-safe yet.
5. N3: verified, and the comment fixed. N5: both doc examples fixed. N4 is left for
   PR #155 (follow-up). The subject of commit c2d3587 still says "every log writer"
   because changing it would need a force-push.

## Findings verified (step 1)

| Finding | Verified against | Result |
|---|---|---|
| B1, bash entry point | `scripts/aitools:2107` `if env ... bash ".../build-deploy.sh" >> "$LOG_FILE" 2>&1; then` / else `log_error "build failed ..."` / `return 1`. Inside `main()` (:11), and `main "$@"; exit` (:2366), so `return 1` ends the run. `:1237` and `:1243`: the relay sync uses the same construct. | Confirmed. `probe-redirect.sh` (38dc-10's probe, re-run): `deploy.log: Is a directory`, `branch: else (rc=1)`, `command ran: no` |
| B1, PowerShell entry point | `scripts/aitools.ps1:286` `$out \| Add-Content -Path $logFile -Encoding utf8` (in a try; the catch logs a LogWarn). `:2046` `Add-Content -Path $logFile -Value $buildResult` (top level). | Confirmed. `aitools.ps1` sets no `$ErrorActionPreference`, but `hh.ps1:18` sets `"Stop"` and `:98` runs `& $aitoolsPs1` in-process. `probe-stop.ps1`: at the default preference, an error record and the run goes on (exit 0). With a caller that set Stop, the run ends at the Add-Content (exit 1). So under `hh`, `:2046` ends the run. |
| B1, hooks | `standing-order-guard.sh:48` `set -euo pipefail`, `:63` `mkdir -p "$LOG_DIR"`, `:99-101` an unguarded observe-mode append. `tool-ops-session-audit.sh:8` "Always exit 0", `:12` set -euo pipefail, `:101-103` an unguarded append. | Confirmed. `probe-hooks.ps1` (fake HOME): when `~/.aitools/logs` is a file, the guard exits 1 on `git status` **and on `git status && git log`, which is not blocked** (the control exits 2). When the jsonl is a directory, the audit exits 1 (the control exits 0). |
| B1, the four claims | #174 `correctiveAction` ("Every log-file writer outside aitools-lib now writes through ..."); the subject of commit c2d3587 ("Make every log writer outside aitools-lib fail-safe (incident #174)"); RELEASE_NOTES row 1; logging.md section 5 ("The log writers outside the lib use the same helpers") | All four confirmed. Three are fixed. The commit subject stays (no force-push). |
| N1 | RELEASE_NOTES row 2 "Medium"; row 5 and #177 say high | Confirmed; fixed |
| N2 | #174 and #177 `closedIn` "...; the orchestrator adds the version)"; #174 `correctiveAction` "PR placeholder fix/m6-logging until the PR number is known" | Confirmed; fixed |
| N3 | The comment above `Invoke-RelaySync` says the old Add-Content error "ends the run under $ErrorActionPreference = "Stop"" | Confirmed. No `$ErrorActionPreference` assignment in `aitools-install.ps1`; its callers are `aitools.ps1:2101` (in-process; it sets none) and `bootstrap.ps1:48` (it sets Stop, but starts the installer in a new process with `-File`, so Stop is not inherited); `packaging/windows/install-user.ps1` is a stub (exit 1). The old code (origin/main `:791`, `$out \| Add-Content -Path $logFile`) printed an error record and went on (M6-F report row 4: "One error record. The sync itself ran."). The same claim was in RELEASE_NOTES row 1 ("throws from the PowerShell installer ... under Stop"): fixed too |
| N5 | `reference/script-standards-detail.md` text-file and hook-script PowerShell examples: `Add-Content -Path $logFile -Value ...` (3 lines each) | Confirmed; fixed |

## Changes (Review after, D-DEL5, old -> new)

1. `registries/incidents.json` #174 `closedIn`: "PR #157 (branch fix/m6-logging, commits c2d3587 and b39b735; the orchestrator adds the version)" -> "v0.77.5 (PR #157, branch fix/m6-logging, commits c2d3587 and b39b735)".
2. #174 `correctiveAction`, opening: "Branch fix/m6-logging (mission M6-F; PR placeholder fix/m6-logging until the PR number is known). Every log-file writer outside aitools-lib now writes through ..." -> "PR #157 (branch fix/m6-logging, mission M6-F, commits c2d3587 and b39b735). The six writers named in this incident, and the installers' Step 22 relay sync in the same files, now write through ...". Closing sentence added: "Not covered by this fix: the same class in the aitools entry points (scripts/aitools, scripts/aitools.ps1) and two hooks (shared/hooks/standing-order-guard.sh, shared/hooks/tool-ops-session-audit.sh), tracked as open incident #178."
3. #174 `rootCause`: "The six writers outside it each appended" -> "The six writers named here, outside it, each appended".
4. #174 `preventionLayer`: "Prevention: reference/logging.md section 5 names each writer outside the lib and the helper it must use." -> "Prevention: reference/logging.md section 5 names the writers outside the lib that are fail-safe and the helper each uses, and the ones that are not yet (#178)."
5. #177 `closedIn`: "PR #157 (branch fix/m6-logging, commit bb1edce; the orchestrator adds the version)" -> "v0.77.5 (PR #157, branch fix/m6-logging, commit bb1edce)".
6. #178: none -> filed, open, high (the full entry is in the registry and in the PR body). Severity rationale: high, from `.claude/rules/incident-governance.md` "Severity" ("Silent wrong behavior, rule violations in production code"). The entry points skip build-deploy and end the run, against `reference/logging.md` section 5. The hooks alone would be medium, and the entry says so. Affected spec: `reference/logging.md` section 5, plus each hook's own header contract.
7. `RELEASE_NOTES.md` v0.77.5 title: "Fail-safe log writers outside the library; ..." -> "Fail-safe log writers in the installers, the profile resolver and check-lib; ...".
8. RELEASE_NOTES row 1: "Log writers outside aitools-lib are fail-safe" -> "The six log writers outside aitools-lib named in incident #174 are fail-safe". The clause "throws from the PowerShell installer or check-lib under `$ErrorActionPreference = "Stop"`" -> "throws from check-lib under the check scripts' `$ErrorActionPreference = "Stop"`, prints an error record for every log line of the PowerShell installer" (N3 check: check-pre-commit, check-pre-push, check-post-push and check-prereq-detection set Stop; the installer and its callers do not). Added: "Not yet fail-safe: the `aitools` entry points' own appends and two hooks (open incident #178)."
9. RELEASE_NOTES row 2 severity: Medium -> High (N1).
10. RELEASE_NOTES row 4: + "that are fail-safe ..., and the ones that are not yet (#178)", and + the script-standards-detail example change.
11. RELEASE_NOTES row 5: + "#178 (high, the `aitools` entry points' and two hooks' unguarded log appends) filed, open".
12. `reference/logging.md` section 5: "The log writers outside the lib use the same helpers" -> "These log writers outside the lib use the same helpers". Added after the list: "Not fail-safe yet (open incident #178): the `aitools` entry points' own appends to deploy.log (`scripts/aitools`: the build-deploy output and the relay sync output; `scripts/aitools.ps1`: the same two, through `Add-Content`) and two hooks (`standing-order-guard.sh`: its log directory and observe-mode line; `tool-ops-session-audit.sh`: its result line)." No line numbers (documentation-standards).
13. `scripts/aitools-install.ps1`, the comment above `Invoke-RelaySync`: "... swallowed (...; incident #174) instead of an Add-Content error, which ends the run under $ErrorActionPreference = "Stop"." -> "... swallowed (...; incident #174). The old `$out | Add-Content` printed an error record and the run went on: the installer sets no $ErrorActionPreference, and neither do its callers (aitools.ps1 runs it in-process; bootstrap.ps1 sets "Stop" but starts it in a new process)." Comment only, ASCII, inside the "install log helpers" block (the tests extract it by its markers; comments are inert).
14. `reference/script-standards-detail.md` "Canonical patterns by file type": the six `Add-Content -Path $logFile -Value X` lines (text files and hook scripts) -> `Add-AitLibLogText X`. One added sentence: diff lines go to deploy.log fail-safe (bash `>> "$LOG_FILE" 2>&1 || true`; PowerShell `Add-AitLibLogText`).
15. This report: none -> v1.0.

Not changed: the subject of commit c2d3587 (a history rewrite would need a force-push).
The M6-F report's title ("every log writer outside aitools-lib is fail-safe") belongs
to M6-F and was left as is. Its body (line 42) already lists the writers that were
not fixed.

## Verification (step 3; Windows 11, pwsh 7.6.10, Git Bash 5.3.15; logs in scratch, `AITOOLS_LOG_DIR` in scratch)

- `registries/incidents.json`: edited by `edit-incidents.py`. The script refuses to write unless the unmodified file round-trips byte for byte, and each text replacement must match exactly once. Result: the file parses, 165 open, 11 closed, max id 178, no duplicates. `git diff` shows only the five fields and the new entry.
- pwsh parser on `scripts/aitools-install.ps1`: OK. The added lines contain no non-ASCII bytes (perl scan of the staged diff of the code and doc files).
- `tests/logging/test-logging.ps1`: 45 passed, 0 failed, 0 skipped (exit 0). The count is the same as M6-F's.
- `scripts/check-pre-commit.ps1` (no `-Fix`, staged): 10 PASS, 6 SKIP, 3 WARN, 0 FAIL (exit 0).
  - WARN 3: build freshness (`-Fix` builds against the real HOME, so it is not run).
  - WARN 5: platform note (the commit message carries "(tested: Windows)").
  - WARN 11: dotprofile changes, not this mission's.
  - Step 20, path references: PASS.
- Probes for #178, in `.scratch/session-38dc-14/` (not tracked; the key lines are quoted in #178 `observation`):
  - `probe-redirect.sh`
  - `probe-stop.ps1`
  - `probe-hooks.ps1`

## Not run

- macOS and Linux (CI).
- `check-pre-push`, `check-post-push`.
- `check-pre-commit -Fix`.
- Any `.sh` suite: commander, 2026-11-14, ".ps1 here on windows". The one bash run was the `probe-redirect.sh` probe and the hooks under `probe-hooks.ps1`, as evidence for #178.
- `aitools`, `aitools install`, `hh`, setup scripts or `build-deploy.sh` against the real HOME. The hh -> aitools.ps1 Stop path was shown with `probe-stop.ps1`, not by running `hh`.
- Claude Code's handling of a hook's exit 1: #178 cites the hooks documentation, which was not re-read in this mission.

## WRITE_BLOCKED / CONFLICT / INCIDENT

- WRITE_BLOCKED: none.
- CONFLICT: /incident "present for review" vs this prompt. Resolved by tier 2 (the prompt): written as a version, and listed under Review after.
- CONFLICT: this prompt's "read incidents.json in full" and the /incident step 1 "Read in parts" vs the cost of paging 4,157 lines. Resolved by tier 2, by its purpose. `ids.py` parsed every entry, open and closed, and listed the ids: max 177, none duplicated, 175 and 176 free on the branch and on origin/main (max 174 there). It also scanned every field of every entry for the writers and hooks named here. `show.py` printed #70, #162, #174 and #177 in full. I did not page the whole file through Read.
- DEVIATION (disclosed): USO "Dedicated tools for file ops" (tier 1). The `incidents.json` edit was made by a scratch Python script with a round-trip guard, not with Edit, so that the JSON escaping of the long new entry is exact. The resulting diff was reviewed in full (`git diff --word-diff`). Every other file was edited with Edit and Write.
- INCIDENT filed: #178 (open).
- INCIDENT (not filed): #70's first half no longer matches the code. #70 says `tool-ops-session-audit.sh` looks for `reference/tool-ops.json`, but the hook now reads `registries/tool-ops.json` (`:23-26`). Its second half, the log location `~/.claude/hooks/logs`, stands. Suggested: update #70's observation when it is next touched, or fix the log location together with #178's hook part.

## Follow-ups

1. N4 (not done here): the `tests/menus/test-menu-choice.ps1` labels. PR #155 is changing that file, so fix them after #155 merges.
2. #178: the entry points and the hooks (suggested resolution in the entry).
3. The subject of commit c2d3587 overstates the scope. The commit body, #174 and the release notes now carry the correct scope.

## Open questions (each with a suggested answer)

1. Should #178 be split into an entry-point incident (high) and a hook incident (medium) when someone picks it up? Suggested: keep one entry. Ship two PRs if the hook-rollout verification makes the hook part slower.
2. The standing-order guard fails open when `~/.aitools/logs` cannot be created. Does that make the hook part high on its own? Suggested: no, medium. It needs a broken home directory, and Claude Code shows the error on every call, so the condition is visible.

## Delegates used

None.
