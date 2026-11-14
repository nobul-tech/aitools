# M6-DE report: setup-pywinpty result checks (item d, #177) and hh.ps1 is pwsh 7 only (item e)

**Version**: v1.1 (2026-11-14). **Author**: M6-DE, delegated by M6-Polish (level 2), delegated by Session Commander 87795dc3-e.
v1.1: PR https://github.com/nobul-tech/aitools/pull/157 opened. The `closedIn` of #174 and #177 in `registries/incidents.json` is now "PR #157 (branch fix/m6-logging, commits ...; the orchestrator adds the version)". The CI result is in the hand-back.
**Branch**: `fix/m6-logging`. It carries M6-F's item f (c2d3587, b39b735). This mission added:
- the merge of origin/main b3c2f2e;
- `bb1edce` (items d and e);
- the merge of origin/main 2ee68d9 (a relay.md commit only);
- this report.

The PR is opened after this commit; its number and CI result are in v1.1 and in the hand-back.

## Summary

1. **Item d.** Post-push step 23 failed on one line only, `setup-pywinpty.ps1:151` (verified). The fix gives that line a real result check, not a comment, and step 23 now passes (12 PASS, 0 FAIL).
2. **Hidden failure behind item d.** pwsh's `Get-ChildItem -Filter` returns nothing and no error for a directory it may not list, even under `-ErrorAction Stop`. So the check had to drop `-Filter` to see the failure. A new test case pins it, and the mutation check shows the case fails against the old script.
3. **Item e.** `hh.ps1` states "Requires PowerShell 7 (pwsh)" and carries `#Requires -Version 7.0`. Under 5.1 that replaces six parse errors with one clean version message, both with `-File` and through the profile's `hh` function (verified). pwsh 7 still runs it.
4. **relay-outbound-prompt.ps1.** It stays ASCII: `aitools.ps1` loads it, parses under 5.1 and has no version requirement. The note now names `aitools.ps1`, not `hh.ps1`.
5. **Incidents.** #177 is filed and closed (high). Item e is not an incident: the PS 7 baseline already covered it, and the commander's decision resolves it, so it is recorded in docs.

## Item d: setup-pywinpty suppressions

### Verify before fix (origin/main's file, saved to scratch)

Step 23 of post-push runs `scripts/check-script-compliance.ps1` (`.sh` on macOS/Linux), and only with `-Extensive`. Its step 11 is the SilentlyContinue check: the next 3 lines must match `-not|if\s|\bif\(|\.Count|\.Length|null|catch`, or the 3 lines before must contain `Get-Command`, or the line must carry `checked on`.

| Run | Result |
|---|---|
| `check-script-compliance.ps1`, whole, worktree = origin/main file | 11 PASS, 1 SKIP, 0 WARN, 1 FAIL: `11. SilentlyContinue has result check [FAIL] 1 unchecked: setup-pywinpty.ps1:151`, exit 1. Every other step passes, so this file is step 23's only failure |
| step 11 copied verbatim (`step23-probe.ps1`), old file | `:197 passes (nearby check)`, `:246 passes (nearby check)`, `FAIL ... 1 unchecked: old-setup-pywinpty.ps1:151` |
| step 11 of the bash twin copied verbatim (`step23-probe.sh`), old file | same three results |

### Every suppression in both files

| File:line (origin/main) | Pattern | Check before | After |
|---|---|---|---|
| `setup-pywinpty.ps1:151` | `Get-ChildItem ... -Filter ... -ErrorAction SilentlyContinue` (Remove-StaleDistInfo) | none: a comment ("a missing target lists nothing; the import verify below decides") | fixed: `-ErrorVariable listErr` + `if ($listErr -and (Test-Path ...)) { LogError; return $false }`; `-like` filter |
| `setup-pywinpty.ps1:197` | `Get-Variable ... -ErrorAction SilentlyContinue` | yes: `IsNullOrWhiteSpace($embedded)` on the next line -> ERROR | unchanged |
| `setup-pywinpty.ps1:246` | `Get-Command ... -ErrorAction SilentlyContinue` | yes: command-existence exemption comment and `if ($cmd) ... else { Log "... not on PATH" }` | unchanged |
| `setup-pywinpty.ps1:80` | `& $Python @Arguments 2>&1` | not a suppression: stderr is captured and logged; the exit code is checked | unchanged |
| `setup-pywinpty.ps1` try/catch blocks (:79, :129, :155, :203, :216, :419) | catch | every catch logs (LogDetail/LogError/LogWarn) or returns a reason | unchanged |
| `setup-pywinpty.sh` | no `2>/dev/null`, `|| true` or `2>&1`; `[ ... ] && ...` lists are not suppressions | n/a | unchanged |

### The trap found while fixing

Probes (`probe-acl.ps1`, `probe-acl2.ps1`, pwsh 7.6.10, non-elevated) on a directory with `icacls /deny <sid>:(RD)`:

| Listing | Result |
|---|---|
| `Get-ChildItem -Directory -Filter 'pywinpty-*.dist-info' -ErrorAction Stop` | no throw, 0 items |
| `Get-ChildItem -Directory -ErrorAction Stop` | `UnauthorizedAccessException: Access to the path ... is denied.` |
| `[IO.Directory]::GetDirectories(t, pattern)` | throws |
| `-ErrorAction SilentlyContinue -ErrorVariable e` with `-Filter` | 0 items, `e` empty |
| a missing path | error recorded, `Test-Path` false |

The old line was therefore blind to an unreadable target under any error action. The fix drops `-Filter` and uses `Where-Object { $_.Name -like 'pywinpty-*.dist-info' -and $_.Name -ne $keep }`. `-like` is case-insensitive like the Windows filter. The only difference is that `-Filter` also matches 8.3 short names, and an 8.3 name cannot match this pattern.

### Behaviour

- **Normal runs:** unchanged. The same items are removed, and the same rows and log lines are written.
- **Missing target:** unchanged. It lists nothing and the import verify decides. In practice pip `--target` has just created the target.
- **Target exists but cannot be listed:** before, the removal was silently skipped. Now the run logs `Could not list <target> for stale pywinpty dist-info: <error>` and the caller writes ERROR `stale dist-info not removed`, exit 1. This is the one behaviour change. It is the result check that script-standards requires ("Suppressed errors feeding into ... loops ... silently skips work").

### Tests

- New case 4c in `tests/pywinpty/test-setup-pywinpty.ps1`: "f fake externally managed, target not listable".
  - It denies ListDirectory on the fake user site with icacls (by SID) and restores it in a `finally`. It is a SKIP (a FAIL under CI) if icacls fails.
  - It expects: exit 1, one row `ERROR|pywinpty|stale dist-info not removed`, one pip call, and the log line.
- Results:

| Run | Result |
|---|---|
| `.ps1` before | 53 passed, 0 failed, 0 skipped (uv present, so case h ran) |
| `.ps1` after | 54 passed, 0 failed, 0 skipped; 4c PASS |
| `.sh` before and after | 31 passed, 0 failed, 2 skipped (POSIX-only cases on Windows) |
| mutation: HEAD tree (old script) + new suite, `mut-run.sh` | 53 passed, 1 failed; the old script's row is `ERROR|pywinpty|import failed after install` |

- `check-script-compliance.ps1` after the fix: 12 PASS, 1 SKIP, 0 WARN, 0 FAIL, exit 0. Step 11 copied verbatim from both twins: PASS on the new file (`:157`, `:206`, `:255` pass on the nearby check; `:157` passes because of the new `if`).
- `deploy-paths.md` lists setup-pywinpty as "copy + embed", and the structure is kept. `check-pre-push.ps1` step 7 (isolated fresh build): "fresh build OK; resolver consumers dry-run clean". The suite's case g builds and runs the MDM copy and passed.

### Incident #177

- Filed and closed in `registries/incidents.json`. The full open JSON, the closed JSON and the severity rationale (high: a rule violation in production code) are in the PR body under "Review after".
- `closedIn` is a branch placeholder until the PR exists; v1.1 sets `PR #<n>` for #177 and #174.
- The file parses: 164 open, 11 closed, max id 177, no duplicates. I read `incidents.json` in full (Read in parts, lines 1-4147) before choosing 177; 175 and 176 are free, reserved for M6-B/M6-C.

## Item e: hh.ps1 is PowerShell 7 only

### Evidence

- 5.1 parser on origin/main's `hh.ps1` (`parse-check.ps1` under `powershell.exe` 5.1.26100.9818) gives 6 parse errors: `line 69: Missing argument in parameter list.`, then lines 78, 78, 60, 57 and 78. The pwsh 7.6.10 parser gives OK.
- `#Requires` (`probe-requires.ps1`; the variant has `#Requires -Version 7.0` after the header):

| Run under 5.1 | Result |
|---|---|
| `-File` | rc 1, only `The script 'hh-requires.ps1' cannot be run because it contained a "#requires" statement for Windows PowerShell 7.0 ...` (no parse errors) |
| in-process `& hh-requires.ps1` | the same single `ScriptRequiresException` |
| control (a valid file with `#Requires`) | the same message |

- The real `scripts/hh.ps1` after the change (`probe-hh.ps1`, read-only: `-n -NoPull`, relay prompt skipped):

| Run | Result |
|---|---|
| 5.1, `-File` | the version message |
| 5.1, `function hh { & hh.ps1 @args }; hh -n -NoPull` | the version message |
| pwsh 7, `-File` | ran normally (branch status and harness paths printed, rc 0) |

- Decision: use `#Requires`. It demonstrably improves the 5.1 experience, and pwsh 7 parses and runs the file.

### Who loads what under 5.1 (grep evidence)

- **Callers of `relay-outbound-prompt.ps1`:** `scripts/aitools.ps1:2266-2268` (dot-sources it after `Show-Summary`) and `scripts/hh.ps1` (the `-n` branch). Tests: `tests/menus/test-menu-choice.ps1` runs it under 5.1 on purpose.
- **`aitools.ps1` under 5.1:** it has no version guard (its only `PSVersion` use is the OS guard, `:26`) and parses under 5.1 (`parse-check.ps1`: OK). So it is 5.1-capable at parse level. Whether it runs to the end under 5.1 is unknown (not run).
- **`bootstrap.ps1:48`:** `& powershell -NoProfile -ExecutionPolicy Bypass -File ...aitools-install.ps1`, so the installer runs under 5.1. Then `:58-64` runs `& aitools` in the bootstrap's own session, which is 5.1 on a fresh machine. Whether `aitools` resolves to `aitools.ps1` there was not verified.
- **`aitools-install.ps1`:** it runs `setup-user-shell.ps1` in-process (`Invoke-ValidatedScript`: `& $ScriptPath`), and that script writes `$PROFILE` of the running host (`:63`). So a 5.1 install would write the `hh` and `aitools` functions into the 5.1 profile (read from the code; not run). With `#Requires`, `hh` there now fails with the version message.
- **M6-F's bootstrap note:** verified by reading. `aitools-lib.ps1:639` `Initialize-Logging` calls `Join-Path $HOME ".aitools" "logs"` (3 arguments, PS 6+). M5-L2 observed it fail under 5.1 without `AITOOLS_LOG_DIR` (M5-L2 report, item 5 design). Bootstrap is not fixed here (out of scope); it is a follow-up.
- **5.1 parse of other loaders:** `aitools.ps1`, `aitools-lib.ps1`, `aitools-install.ps1`, `setup-user-shell.ps1`, `shared/shell/aliases.ps1` and `bootstrap.ps1` all OK. No wrapper that launches hh contains its own logic. The only launcher is the one-line profile function, and `#Requires` covers it, so no wrapper version check was added.

### Decision: relay-outbound-prompt.ps1's 5.1 note

The note still applies, because `aitools.ps1` is a 5.1-capable loader (above). The file stays ASCII (verified: no non-ASCII byte; 5.1 parse OK). The note named `hh.ps1` as the 5.1 loader, which contradicts the commander's decision, so its two comments now name `aitools.ps1`. The code is unchanged.

### Docs

- I searched `reference/`, `README.md`, `shared/shell/`, `CLAUDE.md` and `shared/claude-shared.md` for "5.1", "Windows PowerShell", "powershell.exe" and `hh`. No doc says hh supports 5.1. `README.md:121` ("`hh.ps1` + a `hh` function in PowerShell (Windows)") makes no version claim and was left as is.
- Claims found, both now fixed: the `relay-outbound-prompt.ps1` comments and `tests/menus/test-menu-choice.ps1:497` ("hh.ps1 may run there").
- Added: the paragraph in `reference/cross-platform-detail.md` "PowerShell 7 baseline". `.claude/rules/cross-platform.md` is unchanged; the reference doc is the detail home, per the prompt.

### Classification: not an incident (no #178)

`.claude/rules/incident-governance.md` decision tree, step 1: a spec exists (cross-platform.md "PowerShell 7 baseline": PS 7 is the baseline), and the code does not deviate from it, since `hh.ps1` runs on pwsh 7. What was missing was a statement for this entry point. The only contrary text was an agent's comment, not a spec. The commander's decision (2026-11-14) resolves it. Resolved ambiguities belong in docs, not in `incidents.json` (incident-governance "Decisions tracking").

Residue: `hh.ps1` still has UTF-8 em dashes in two strings. cross-platform.md "ASCII preference" is a "prefer", and rewriting `hh.ps1` is out of scope (open question 3).

## Local verification (step 5; Windows 11, pwsh 7.6.10, Windows PowerShell 5.1.26100, Git Bash 5.3.15; logs in scratch)

| Suite / check | Result |
|---|---|
| tests/pywinpty .ps1 / .sh | 54/0/0 / 31/0/2 |
| tests/os-guards | 34/0/0 |
| tests/logging .sh / .ps1 (M6-F's) | 54/0 / 45/0/0 |
| tests/aitools-entry test-console-mode-guard.ps1 | 76 passed, 0 failed, 7 skipped |
| tests/menus .ps1 / .sh | 87/0/0 / 78/0/0 |
| tests/setup-user-shell .ps1 / .sh | 37/0/0 / SKIP (POSIX suite on Windows) |
| tests/ci-suites | 21/0 |
| pwsh parser: setup-pywinpty.ps1, hh.ps1, relay-outbound-prompt.ps1, both touched tests | all OK |
| 5.1 parser: relay-outbound-prompt.ps1, setup-pywinpty.ps1 | OK |
| check-pre-commit.ps1 (no `-Fix`, staged) | 10 PASS, 4 SKIP, 5 WARN, 0 FAIL |
| check-pre-push.ps1 (after the merge) | 7 PASS, 0 SKIP, 3 WARN, 0 FAIL; step 7 fresh build OK |

check-pre-commit WARNs:
- 3: `-Fix` builds against the real HOME.
- 5: the platform note is in the commit message.
- 7: install-command consistency. Advisory: the pip arguments are unchanged.
- 9: RELEASE_NOTES is the orchestrator's file.
- 11: dotprofile changes, not mine.

check-pre-push WARNs: 1, 5 and 6 are advisory.

No pre-existing failures were seen. No suite or check has a FAIL.

## Proposed RELEASE_NOTES rows (for the orchestrator)

| n | Severity | Fix |
|---|---|---|
| d | Medium | `setup-pywinpty.ps1` checks the result of its stale-dist-info listing: when the `--target` user site exists but cannot be listed, the run reports ERROR `stale dist-info not removed` instead of silently skipping the removal. The listing no longer uses `-Filter`, which hides the error. Post-push step 23 passes again. Resolves Incident #177. |
| e | Documentation (Improvements) | `scripts/hh.ps1` is PowerShell 7 (pwsh) only (commander, 2026-11-14). Its header says so, and `#Requires -Version 7.0` makes Windows PowerShell 5.1 print one version message instead of parse errors. `reference/cross-platform-detail.md` records it. |

Note: the d row says "Medium" for the release-notes severity column (the user impact needs an unreadable target). The incident severity is high per the incident-governance table ("rule violations in production code"). The orchestrator may align them.

## Not run

- macOS and Linux (CI).
- `check-post-push` as a whole (only its step 23 script).
- `check-pre-commit -Fix`.
- `aitools`, `aitools install`, `setup-user-*`, `deploy-harness` or `build-deploy.sh` against the real HOME.
- A 5.1 run of `bootstrap.ps1`, `aitools-install.ps1` or `aitools.ps1`.
- An elevated (administrator) run of case 4c. CI's windows runner covers that.

## WRITE_BLOCKED / CONFLICT / INCIDENT

- WRITE_BLOCKED: none.
- CONFLICT: the auto-mode note allowing Bash file edits vs USO "Dedicated tools for file ops". Resolved by tier 1 (the commander's CLAUDE.md): Read, Edit, Write and Grep for every file operation.
- CONFLICT: /incident "present for review" and "mention in release notes" vs this prompt. Resolved by tier 2 (the prompt): written as a version and listed under Review after; the release-notes rows are above.
- CONFLICT (minor): the prompt says "no behaviour change" and also "add a test only if a check introduces a new branch with observable behaviour". Resolved by tier 2, reading both together. The one new branch is the result check itself: an error path that was silent now reports ERROR. Normal runs are unchanged.
- INCIDENT filed: #177 (closed in this PR).
- INCIDENT candidates (not filed):
  1. Nothing runs `check-script-compliance` before merge (only post-push `-Extensive`). This is #177's root cause and a possible structural fix.
  2. `reference/tool-registry.md:582` says Windows PowerShell 5.1 is used only as the bootstrap fallback in `aitools-install.sh`, but `bootstrap.ps1:48` also runs the installer under 5.1.
  3. M6-F candidate 4 (bootstrap under 5.1 + 3-argument `Join-Path`) is confirmed by reading at `aitools-lib.ps1:639`.

## Open questions (each with a suggested answer)

1. Run `check-script-compliance` in CI or pre-push? Suggested: yes, in CI (windows job `.ps1`, linux and macOS jobs `.sh`), so a #177-class line fails the PR rather than a post-push run.
2. Should `bootstrap.ps1` launch the installer with pwsh 7 (installing it first) instead of `powershell`? Suggested: yes. The project baseline is PS 7, and under 5.1 the lib's logging init already fails. Track it as M6-F candidate 4.
3. Make `hh.ps1` ASCII anyway? Suggested: no, while it is pwsh-7-only. `#Requires` gives 5.1 users a clear message.
4. Align the severity of the d release-notes row with #177 (high)? Suggested: keep "Medium" in the notes (user impact) and say why, or use high for consistency. The orchestrator's call.

## New operational learning

- **`Get-ChildItem -Filter` and unreadable directories.** On a directory the user may not list, `Get-ChildItem -Filter` returns nothing and reports no error, even with `-ErrorAction Stop` (pwsh 7.6.10, Windows). Without `-Filter` it raises `UnauthorizedAccessException`. A result check on a filtered listing therefore needs no `-Filter`, with a `Where-Object -like` instead.
- **`#Requires -Version 7.0` under Windows PowerShell 5.1.** It is honoured even when the rest of the file does not parse. 5.1 prints only the version message, with `-File` and with an in-process `&` call. It is the cheap way to make a pwsh-7-only script fail cleanly on 5.1.
- **A deny-ACL test case.** `icacls <dir> /deny "*<SID>:(RD)"` (SID from `[Security.Principal.WindowsIdentity]::GetCurrent().User.Value`) denies listing to the current user while child creation by path still works. Remove it with `icacls <dir> /remove:d "*<SID>"` in a `finally`, before the temp root is deleted.
- **Worktrees share refs.** `origin/main` can move while you work (a channel commit pushed from the main checkout): `git diff --stat origin/main` then shows the other commit as a deletion on your branch. Merge `origin/main` again before pushing.
- **`git show --output`.** `git show <rev>:<path> --output=<file>` does not write the blob to the file in this git; it prints to stdout. Use a scratch script with `>` redirection.

## Delegates used

None.
