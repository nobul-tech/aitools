# M5-D2 report

v1.0, 2026-11-14 (UTC). Mission M5-D2, delegated by M5-Fixes (Session Commander 87795dc3-e). Branch `docs/m5-docs`, worktree `C:\Users\jdpal\repos\aitools\.claude\worktrees\m5-docs`.

## Summary

1. RELEASE_NOTES.md now has v0.76.2, one entry for PRs #144-#147, between v0.77.0 and v0.76.1. It says "Resolves Incident #173".
2. RELEASE_NOTES.md now has v0.77.3 at the top, for this branch: the check-path-refs fix, the CLAUDE.md ref, incidents #172/#173/#174, issues #72/#29, and the backfill.
3. Incident #173's closedIn is now `v0.76.2 (PR #144, fix/console-and-profile, merge c66d4b1)`. #172's `v0.76.1` was already correct (PR #143), so it is unchanged.
4. New open incident #174 (high), added on M5-Fixes' request: the log writers outside aitools-lib are not fail-safe.
5. Checks run from the worktree: pre-commit 0 FAIL (step 20 PASS), pre-push 0 FAIL (step 7 PASS). There are 2 commits plus this report, all pushed. No PR opened.

## Versions written

| Version | Title | Covers |
|---|---|---|
| v0.76.2 | One self-repairing owner of the shell profile, JSON reviews that name the file, menus that re-ask, cooked-mode console reads on Windows (2026-11-14) | PRs #144, #145, #146, #147 |
| v0.77.3 | Pre-commit path-ref check fixed on Windows; release notes backfilled for PRs #144-#147 (2026-11-14) | branch docs/m5-docs (M5-D1 commits 5b84b8c, e03e90d, 0c7ae6c, e51d895; M5-D2 commits) |

**Why one entry for #144-#147.**

- documentation-standards.md says: "Multiple changes on the same day roll into one release." All four PRs merged on 2026-11-14 UTC.
- The entry must sit between v0.76.1 (#143, merged 2026-11-13) and v0.77.0 (#148, merged later on 2026-11-14), so only v0.76.x numbers fit.
- By content (new review features, new menu behaviour) this release would be a minor. The entry says it carries a patch number only because v0.77.0 was written first.
- Four separate patch numbers (v0.76.2-v0.76.5) would break the same-day rule four times.

## Evidence (gh pr view, nobul-tech/aitools)

| PR | Merged (UTC) | Merge SHA | Branch |
|---|---|---|---|
| #143 | 2026-11-13T22:53:18Z | 941e64a9a11aa261d13d11bcafee5cfbf706e993 | fix/setup-user-shell-replace (= v0.76.1, Resolves #172) |
| #144 | 2026-11-14T00:51:44Z | c66d4b12c97daa0b8ca5241a9a7c72c301579a44 | fix/console-and-profile |
| #145 | 2026-11-14T01:47:05Z | e8ebd070df39b3363aec8e0797d64983a2ebce9a | fix/json-review-display |
| #146 | 2026-11-14T02:17:33Z | a98208e765797072d2cd389f644cab6a2f09debd | fix/menus-reask |
| #147 | 2026-11-14T02:54:08Z | 301dd22883a7fca36e1ff3cef8b330ce99933aa3 | fix/console-input-mode |
| #148 | 2026-11-14T04:32:37Z | 592c5b307ef890f7d24357bb85190dad70956aac | feature/pywinpty-adopt (= v0.77.0) |

**No earlier entry.** A grep of RELEASE_NOTES.md for `#14[3-8]` matched only incident ids: line 204 (Incident #144 in v0.74.0) and line 295 (incident registry ranges).

**v0.76.1 is #143.** Its date, title and content match PR #143. Closed #172 also names PR #143's branch.

**Function names checked in the merged code** (Grep on this branch):

- `Update-MarkedBlock` and `Remove-LegacyIntegration` (setup-user-shell.ps1)
- `read_menu_choice` / `Read-MenuChoice`
- `_json_field_detail` / `Write-JsonFieldDetail`
- `MANAGED_NO_REVIEW` (deploy-harness.sh)
- `AitConsoleInput`, `Initialize-AitConsoleInput`, `Save-/Restore-ConsoleInputMode`, `Write-AiLog`, `Start-AiSpinner`
- `READ_TTY_EOF=1` and `$script:ReadConsoleEof = $true`

**Issue states:** #72 CLOSED 2026-11-14T05:19:08Z; #29 OPEN.

## Branch and pushed SHAs (origin/docs/m5-docs)

| SHA | Commit |
|---|---|
| 4f256c4 | File incident #174: log writers outside aitools-lib are not fail-safe |
| 8c34d3c | Add release notes v0.76.2 (PRs #144-#147) and v0.77.3; set #173's release |
| (this commit) | M5-D2 report v1.0 |

## Files changed

- `RELEASE_NOTES.md`: v0.77.3 added at the top, v0.76.2 added between v0.77.0 and v0.76.1. Insertions only: no existing line is changed or deleted (commit 8c34d3c: 82 insertions; its 1 deletion is #173's closedIn line).
- `registries/incidents.json`: #174 appended (28 insertions, 0 deletions); #173 closedIn changed (1 line).
- `.aitools/channel/handoffs/2026-11-14_87795dc3-missions/M5-Fixes/M5-D2-report.md` (new, this file).

## Incident #174

**Title:** Log writers outside aitools-lib (the aitools-install.ps1/.sh log overrides, the aitools-profile.sh/.ps1 log overrides, and the check-lib.sh/.ps1 checks.log and checks.jsonl writers) append to the log file unguarded. A locked or unwritable log can abort the installer, the profile resolver or a check script instead of being swallowed.

**Sites, read on this branch:**

| File | Function | Write |
|---|---|---|
| `aitools-install.ps1` | `Log` | `Add-Content` |
| `aitools-install.ps1` | relay sync step | `$out \| Add-Content` |
| `aitools-install.sh` | `log` | `\| tee -a` under `set -euo pipefail` |
| `aitools-profile.sh` | `log` | `>> "$LOG_FILE"` under `set -euo pipefail` |
| `aitools-profile.ps1` | `Log` | `[IO.File]::AppendAllText`; the script's `trap` exits 2 |
| `check-lib.sh` | `check_log_init`, `_check_log_step`, `print_summary` | `>>` |
| `check-lib.ps1` | `CheckLogInit`, `CheckLogStep`, `PrintSummary` | `Add-Content` |

`check-pre-commit.ps1` sets `$ErrorActionPreference = "Stop"`, so there a failed `Add-Content` is terminating. Every file loads aitools-lib first, so all of them can reach M5-L1's helpers once `fix/m5-lib` merges.

**Expected:** `reference/logging.md` section 5, quoted verbatim.

**Severity: high, not medium.**

- incident-governance.md's table puts "rule violations in production code" at high.
- Under `set -e`, the bash installer and the resolver would exit at their first failed log line. The installer is the first thing to run on a new machine.
- Not reproduced at runtime: the effects are read from the code.

**Release notes:** #174 is listed in v0.77.3 item 4. That follows the precedent of v0.74.0 item 89, which lists registry additions under Documentation.

## Verification (Windows 11, pwsh 7, Git Bash; AITOOLS_LOG_DIR = WT\.scratch\session-M5-D2\logs)

**`check-pre-commit.ps1`: 7 PASS, 11 SKIP, 1 WARN, 0 FAIL.**

- Step 20 PASS: "every cited repo path exists".
- Step 6 PASS.
- Step 11 WARN: uncommitted changes in the dotprofile. These are not mine; I only read the dotprofile.

**`check-pre-push.ps1`: 7 PASS, 0 SKIP, 3 WARN, 0 FAIL.**

- Step 7 PASS: "fresh build OK (dotprofile deploy/ untracked, not compared); resolver consumers dry-run clean".
- WARN 1: checklist reminder.
- WARN 5: RELEASE_NOTES. The check ran before the release-notes commit.
- WARN 6: roadmap reminder.

**incidents.json writes:**

- Both scripts first checked that a round trip of the file is byte-identical (indent 2, `ensure_ascii=False`, trailing newline), and refused to write otherwise.
- The next id came from a full parse: max 173 on this branch, origin/main, origin/fix/m5-lib and origin/fix/m5-checks.

## Not run

- `check-post-push`, test suites: no code change.
- `aitools`, `aitools install`, `setup-user-*`, `deploy-harness`, `build-deploy.sh` against the real HOME: never run.
- No PR opened, nothing posted to GitHub.

## Review after (D-DEL5, old -> new)

**`RELEASE_NOTES.md`**

- v0.76.2: none -> 18 items (7 bug fixes, 3 new features, 4 improvements, 4 documentation), 5 files created, an upgrade note (the harvest manifest and the dotprofile `deploy/` before a pull), and Verified on.
- v0.77.3: none -> 5 items.

**`registries/incidents.json`**

- #173 closedIn: "PR #144 (fix/console-and-profile, merge c66d4b1); release version unknown, pending a RELEASE_NOTES entry for #144" -> "v0.76.2 (PR #144, fix/console-and-profile, merge c66d4b1)".
- #174: none -> open, high, created and updated 2026-11-14. The full entry is in commit 4f256c4.

**This report:** none -> v1.0.

## WRITE_BLOCKED / CONFLICT / INCIDENT

- WRITE_BLOCKED: none.
- `CONFLICT: /incident step 5 "present for review" (skill) vs this prompt ("write the change as a version ... do not ask the user") -- resolved by prompt (tier 2): written, committed, listed under Review after.`
- Judgement, not a conflict: /incident step 1 says to read incidents.json in full with the Read tool before choosing an id. I parsed the whole file with Python instead, which is the skill's own cross-check. That covers every entry, so no partial read is possible.
- One Bash read: `sed -n '295p' RELEASE_NOTES.md`, to see a long table row that Grep omitted. The standing-order-guard allows it.
- INCIDENT: none new beyond #174, which is filed.

## Open questions (each with a suggested answer)

1. **Merge order at the top of RELEASE_NOTES.** v0.77.1 (fix/m5-lib) and v0.77.2 (fix/m5-checks) each insert above v0.77.0, and this branch inserts v0.77.3 there too, so a text conflict is certain. Suggested: when merging, keep descending order: v0.77.3, v0.77.2, v0.77.1, v0.77.0. The v0.76.2 entry sits lower and should not conflict.
2. **Incident id race.** If fix/m5-lib or fix/m5-checks file an incident before merging, it would also take id 174 (both are at max 173 today). Suggested: renumber theirs to 175+ at merge, per incident-governance.md "Concurrency".
3. **Should v0.76.2 have been a minor?** Suggested: no renumbering. The number is fixed by the slot, and the entry says so.

## Operational learning

- **Python `print()` to a Windows console uses cp1252 and crashes on `->` arrows or emoji in PR bodies.** Write gh JSON fields to a UTF-8 file and Read it.
- **`json.dumps(d, indent=2, ensure_ascii=False) + "\n"` reproduces `registries/incidents.json` byte for byte.** Check the round trip before writing; then a scripted edit shows only the intended lines in the diff.
- **Before choosing an incident id, check the max id on every in-flight mission branch** (`git show <rev>:registries/incidents.json`), not only your own.

## Delegates used

None.
