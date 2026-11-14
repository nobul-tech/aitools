# M5-D1 report

v1.0, 2026-11-14 (UTC). Mission M5-D1, delegated by M5-Fixes (Session Commander 87795dc3-e). Branch `docs/m5-docs`, worktree `C:\Users\jdpal\repos\aitools\.claude\worktrees\m5-docs`.

## Summary

1. Item 6 is fixed: pre-commit step 20 passes (5 dead refs before, 0 after). Four of the five were Windows-only false positives from a bug in `scripts/check-path-refs.py`, which is now fixed. The fifth, CLAUDE.md citing the deleted `.claude/rules/relay-outbound.md`, was a real dead ref and is removed.
2. Item 8: #172 was already closed (v0.76.1, PR #143). Its closed entry now also records the PR #144 follow-up. #173 was verified fixed in code by PR #144 (merge c66d4b1) and is closed through /incident.
3. Item 13, #72: resolved. Both "Done when" conditions hold, shown by CI run 43557171983 on main and a 3-case mutation test. The closing comment is written.
4. Item 13, #29: partly. The EOF defect is fixed at every listed prompt. EOF regression cases are missing for the JSON field prompt and the AI-merge preview/feedback. The comment says so, and the issue stays open.
5. Checks from the worktree: pre-commit 0 FAIL (step 20 PASS), pre-push 0 FAIL. Four commits, all pushed. No PR opened, nothing posted to GitHub.

## Item 6: dead path references

**Status: fixed.**

`python scripts/check-path-refs.py --root <WT>` before the fix:

```
CLAUDE.md:100: .claude/rules/relay-outbound.md
reference/cursor-practices.md:43: .cursor/mcp.json
reference/tool-registry.md:341: .claude/settings.local.json
reference/tool-registry.md:354: .cursor/mcp.json
shared/claude-shared.md:95: .claude/settings.local.json
dead path references: 5
```

After the fix: `dead path references: 0`.

**Four false positives (checker bug, Windows only).**

- `.claude/settings.local.json` and `.cursor/mcp.json` are gitignored: `git check-ignore -v` gives `.gitignore:35` and `.gitignore:45`.
- The checker's docstring says gitignored paths are skipped.
- `git_ignored()` passed the path list to `git check-ignore --no-index --stdin` in Python text mode. On Windows, text mode writes `\n` as `\r\n`, so every path except the last reached git with a trailing CR and never matched.
- Traced in `scan()`: input `.claude/rules/relay-outbound.md, .claude/settings.local.json, .cursor/mcp.json, harvesting/harvest-manifest.json`; output `{harvesting/harvest-manifest.json}`, which is the last line only.
- macOS and Linux are not affected, which is why CI never showed it. PRs #144 and #147 both recorded these refs as "pre-existing" step-20 FAILs.
- Fix: the input goes as UTF-8 bytes with a final newline, and the output is decoded as UTF-8.
- Proof: a scratch fixture (temp git repo; CLAUDE.md cites two gitignored paths and one missing path). The fixed script reports only the missing path (PASS). The pre-fix script also reports `.claude/settings.local.json` (FAIL).

**One real dead ref.**

- `CLAUDE.md` "Relay outbound (git)" cited `.claude/rules/relay-outbound.md`, which commit 3cebd24 deleted on the commander's order (2026-11-13, session 90ea4d3e: "any referendce to them and their scope needs to be cleaned up").
- Its substance is already in CLAUDE.md: the scripts, the `[RELAY]` trigger and `AITOOLS_SKIP_RELAY_PROMPT` in "Relay outbound (git)", and the direct-to-main commit in "Channel exception".
- The sentence now points to "Channel exception".
- `reference/do-what-feels-right.md` still cites the deleted rule. It is preserved history with an allow-list entry in `scripts/check-path-refs-allow.txt`, so it was left as is.

**Dotprofile counterpart** (Template sync, read-only):

- `C:\Users\jdpal\repos\aitools-nobul-jose\claude\CLAUDE.md` line 130: `  (synced to \`settings.json\`), or per-project in \`.claude/settings.local.json\`.`
- It is the same text as `shared/claude-shared.md`. It is not a dead ref (gitignored path; not scanned by the checker either), and `shared/claude-shared.md` was not changed. No counterpart edit is needed.

## Item 8: incidents #172 and #173

**#172: already closed** (closedIn v0.76.1, closedDate 2026-11-13).

- v0.76.1 in RELEASE_NOTES.md is PR #143 (`fix/setup-user-shell-replace`, merge 941e64a), "Resolves Incident #172".
- The `$_` bug is gone. `scripts/setup-user-shell.ps1` has no `[regex]::Replace`; blocks are spliced line by line in `Update-MarkedBlock`, with a pre-write parse check (`Get-ParseErrorCount`) and a refusal when the result has more parse errors than the current profile.
- PR #144 added duplicate-block collapse and damage reporting. Its body says that after #143 a profile with 64 blocks still reported OK.
- I amended the closed entry: correctiveAction names PR #143 and its merge, and appends the #144 follow-up; preventionLayer names the .sh suites; `updated` is added.

**#173: closed.** Verified on origin/main 592c5b3:

- `scripts/aitools-install.ps1` Step 7 only calls `Invoke-ValidatedScript setup-user-shell.ps1`, with the comment "single owner of $PROFILE (incident #173)". `scripts/aitools-install.sh` Step 7 only calls `validate_and_run setup-user-shell.sh`.
- `scripts/setup-user-shell.ps1`:
  - A second marked block (`# >>> aitools shell integration >>>`) is replaced in place by `Update-MarkedBlock`.
  - `Remove-LegacyIntegration` removes only known legacy line shapes, so a user line after `function hh {...}` is kept.
  - An unchanged profile is not written ("Profile unchanged").
  - `Backup-File` runs before every write.
- Tests: `tests/setup-user-shell/test-setup-user-shell.ps1` has `legacy: user line right after function hh kept (#173)`, `re-run: profile byte-identical after the 2nd and 3rd run`, and `re-run: no write, so no backup taken`.
  - Local, Windows 11: 37 passed, 0 failed, 0 skipped.
  - CI: Windows step "setup-user-shell PowerShell profile block tests (PowerShell, native)" passed in https://github.com/nobul-tech/aitools/actions/runs/43557171983. The .sh suites passed on macOS (bash 5 and 3.2) and Linux in the same run.
- Closed fields:
  - closedIn: "PR #144 (fix/console-and-profile, merge c66d4b1); release version unknown, pending a RELEASE_NOTES entry for #144". RELEASE_NOTES has no #144 entry: v0.76.1 is #143 and v0.77.0 is #148.
  - closedDate: 2026-11-14.
  - rootCause, correctiveAction (with the full merge SHA c66d4b12c97daa0b8ca5241a9a7c72c301579a44), preventionLayer, updated: 2026-11-14.
- The registry was re-serialised in its own format (indent 2, UTF-8, trailing newline). A round trip of the unmodified file was byte-identical, so the diff holds only these changes: 14 insertions, 26 deletions. After the change: 164 open, 9 closed.

## Item 13: issues #72 and #29

### #72: resolved

Comment: `.aitools/channel/handoffs/2026-11-14_87795dc3-missions/M5-Fixes/M5-D1-issue-72-comment.md`

**"Done when" 1: the Windows job runs the PS1 interactive cases.**

- The Windows backend for `pty-run.py` (pywinpty/ConPTY) came in #139 (B6 a857c12, B5 26c24f1). #148 installs pywinpty in CI through `setup-pywinpty.ps1`.
- Windows job https://github.com/nobul-tech/aitools/actions/runs/43557171983/job/132332536670:
  - Managed-file tests (PowerShell, native): 56/0/0. Every interactive case the issue lists passed by name.
  - Menu-choice PowerShell: 63/0/0.
  - Menu-choice Git Bash ConPTY: 61/0/0.

**"Done when" 2: breaking a menu branch fails the suite.** Mutation test on Windows 11, scratch copies, suite run the same way as the CI step:

| Mutation | Result |
|---|---|
| `[s]kip` returns overwrite | exit 1, 5 FAIL |
| `[a]dopt` returns skip | exit 1, 3 FAIL |
| `[x]abort` without `Invoke-ManagedAbort` | exit 1, 1 FAIL |

**The comment's addition (profile resolver on Windows):** "Profile resolver tests (.ps1, native pwsh)" ends `716 passed, 0 failed (windows: aitools-profile.ps1)`.

**Not done, and outside "Done when":**

- No `::warning::` annotation for skipped test groups.
- The pwsh `exit $LASTEXITCODE` CI note exists only in `plans/merge-friction-improvements.md` finding 7(d).

### #29: partly

Comment: `.aitools/channel/handoffs/2026-11-14_87795dc3-missions/M5-Fixes/M5-D1-issue-29-comment.md`

**Fix 1 (EOF-safe read per language): done.**

- PR #35 (v0.73.3, 075c3da) added `read_tty_choice` / `Read-ConsoleChoice`. They are now the only raw prompt reads in `aitools-lib.sh` / `.ps1` (grep).
- PR #146 put every choice menu on `read_menu_choice` / `Read-MenuChoice`: re-ask on bad input, the menu default at EOF.
- PR #147 added the EOF flag (`READ_TTY_EOF` / `$script:ReadConsoleEof`).

**Fix 2 (one PS1 interactivity test): done.** `Test-InteractiveConsole` is called by `Prompt-DiffReview`, `Review-JsonFields` and `Prompt-JsonFieldReview`.

**Fix 3 (regression tests): partly.**

- Tested: EOF in the helpers (`tests/menus` .sh and .ps1) and EOF at the text review menu end to end (`tests/menus`, `tests/managed-files` .sh and .ps1). All green in CI on macOS, Linux and Windows.
- Missing: EOF cases for `prompt_json_field_review` / `Prompt-JsonFieldReview` (deploy JSON review and settings sync), the AI-merge preview `[y/r/n]`, and the `[r]` feedback read.

## Branch and commits (all pushed to origin/docs/m5-docs)

| SHA | Commit |
|---|---|
| 5b84b8c | Fix check-path-refs on Windows and drop the deleted relay-outbound rule ref (item 6) |
| e03e90d | Close incident #173 and record the PR #144 follow-up on closed #172 (item 8) |
| 0c7ae6c | Add evidence-backed comment bodies for issues #72 and #29 (item 13) |
| (this commit) | M5-D1 report v1.0 |

## Files changed

- `scripts/check-path-refs.py`: `git_ignored()`
- `CLAUDE.md`: Relay outbound sentence
- `registries/incidents.json`: #173 closed, #172 amended, meta
- `.aitools/channel/handoffs/2026-11-14_87795dc3-missions/M5-Fixes/M5-D1-issue-72-comment.md` (new)
- `.aitools/channel/handoffs/2026-11-14_87795dc3-missions/M5-Fixes/M5-D1-issue-29-comment.md` (new)
- `.aitools/channel/handoffs/2026-11-14_87795dc3-missions/M5-Fixes/M5-D1-report.md` (new, this file)

## Verification (Windows 11, pwsh 7, Git Bash)

- `check-path-refs.py --root <WT>`: 5 dead refs before, 0 after. The scratch fixture passes with the fix and fails without it.
- `tests/setup-user-shell/test-setup-user-shell.ps1`: 37/0/0.
- Mutation test of `Prompt-DiffReview` against `tests/managed-files/test-managed-files.ps1`: 3 of 3 mutations caught.
- CI run 43557171983 on main 592c5b3 is green on every job. The Windows step results are quoted from the job log.
- `check-pre-commit.ps1` from the WT (logs to scratch via `AITOOLS_LOG_DIR`): 7 PASS, 11 SKIP, 1 WARN, 0 FAIL.
  - Step 20 PASS.
  - Step 6 PASS (the known harvesting-mode failure did not occur here).
  - Step 11 WARN: uncommitted `profile.json` in the dotprofile. Not mine: I only read the dotprofile.
- `check-pre-push.ps1` from the WT: 7 PASS, 0 SKIP, 3 WARN, 0 FAIL.
  - Step 7 PASS: "fresh build OK (dotprofile deploy/ untracked, not compared); resolver consumers dry-run clean".
  - WARN 1: pre-commit checklist reminder.
  - WARN 5: non-docs changes without RELEASE_NOTES. RELEASE_NOTES belongs to a later batch.
  - WARN 6: roadmap reminder.

## Not run

- `check-path-refs.py` on macOS/Linux after the change. Bytes input is platform-neutral, and no test suite covers this script.
- The setup-user-shell, menus and managed-files `.sh` suites locally. CI ran them on all three platforms.
- `check-post-push`, `aitools`, `aitools install`, `setup-user-*`, `deploy-harness`, `build-deploy.sh` against the real HOME. Never run.
- No GitHub comments were posted, no issue closed, no PR opened.

## Review after (D-DEL5, old -> new)

- `scripts/check-path-refs.py` `git_ignored()`: `input="\n".join(paths), ..., text=True` -> `input=("\n".join(paths) + "\n").encode("utf-8")`, stdout and stderr decoded as UTF-8, plus a comment on the reason.
- `CLAUDE.md` "Relay outbound (git)": "See `.claude/rules/relay-outbound.md`." -> "Committing `relay.md`: \"Channel exception\" below."
- `registries/incidents.json` #173: open entry (status open; rootCause, correctiveAction, preventionLayer null; updated 2026-11-13) -> closed entry:
  - closedIn: "PR #144 (fix/console-and-profile, merge c66d4b1); release version unknown, pending a RELEASE_NOTES entry for #144"
  - closedDate: 2026-11-14
  - correctiveAction: PR #144 with its full merge SHA; Step 7 delegates to setup-user-shell; `Update-MarkedBlock`; `Remove-LegacyIntegration`; `Backup-File`; the parse check; three named test cases; the CI run URL; 37/0/0 locally
  - rootCause: two writers of $PROFILE; Step 7 had no end marker, no backup and no test seam; bash Step 7 diverged
  - preventionLayer: "Prevention: one owner of $PROFILE (aitools-install Step 7 only runs setup-user-shell). Detection: tests/setup-user-shell .ps1 suite in the Windows CI job, .sh suite in the macOS (bash 5 and /bin/bash 3.2) and Linux CI jobs."
  - updated: 2026-11-14
  - The other fields were removed, per the skill.
- `registries/incidents.json` #172 (closed):
  - correctiveAction: "v0.76.1 (branch fix/setup-user-shell-replace):" -> "v0.76.1 (PR #143, branch fix/setup-user-shell-replace, merge 941e64a):", and a sentence is appended: "Follow-up PR #144 (fix/console-and-profile, merge c66d4b12c97daa0b8ca5241a9a7c72c301579a44, 2026-11-14): after #143 a profile already multiplied (64 blocks) still reported OK; setup-user-shell.ps1 now collapses duplicate blocks ..., reports damage ... as WARN `profile damage left in place` plus an ACTION naming the newest clean `<profile>.bak.<UTC>`; tests/setup-user-shell 8 -> 37 checks (.ps1) and a new .sh suite."
  - preventionLayer: "Detection (pre-write parse check in setup-user-shell.ps1; tests/setup-user-shell in the Windows CI job)" -> "Detection (pre-write parse check and damage report in setup-user-shell.ps1; tests/setup-user-shell .ps1 suite in the Windows CI job, .sh suite in the macOS and Linux CI jobs)"
  - updated: (absent) -> 2026-11-14
- `registries/incidents.json` meta.lastUpdated: 2026-11-13 -> 2026-11-14.
- `M5-D1-issue-72-comment.md`, `M5-D1-issue-29-comment.md`, `M5-D1-report.md`: none -> v1.0.

## Follow-ups

1. **RELEASE_NOTES (later batch).** Add an entry for PR #144 with "Resolves Incident #173" (the /incident skill's closing step 5). Then update #173's closedIn from "release version unknown" to that version. This report's commit also changes `check-path-refs.py` (a bug fix) and needs a line in the same release.
2. **#29.** Add EOF cases to `tests/menus/test-menu-choice.sh` and `.ps1` for:
   - the JSON field prompt (deploy review, and the settings sync if reachable);
   - the AI-merge preview `[y/r/n]` (EOF -> n, back to the menu);
   - the `[r]` feedback read.
   Then close #29.
3. **#72 optional items.** A `::warning::` annotation for skipped test groups. Move the pwsh `exit $LASTEXITCODE` note from `plans/merge-friction-improvements.md` finding 7(d) into a CI-authoring reference.
4. **check-path-refs.py has no test suite.** The scratch fixture `.scratch/session-M5-D1/test-pathrefs-ignored.py` could become `tests/path-refs/` with a CI step on all three runners, which would have caught this Windows-only bug.
5. **Dotprofile counterpart.** No change is needed. `claude/CLAUDE.md` line 130 is identical to `shared/claude-shared.md` and is not a dead ref.
6. **Dotprofile has an uncommitted `profile.json`** (pre-commit step 11 WARN). Not from this mission; the commander should look.

## WRITE_BLOCKED / CONFLICT / INCIDENT

- `WRITE_BLOCKED: Write C:\Users\jdpal\repos\aitools\.aitools\channel\handoffs\2026-11-14_87795dc3-missions\M5-Fixes\M5-D1-issue-72-comment.md -- "Permission for this action was denied by the Claude Code auto mode classifier. Reason: [Destructive or Unwanted Actions]."`
  - The block was correct: that path is the main checkout (read-only for this mission), and I gave it by mistake. I did not retry that path. The file was written to the path the prompt designates, under the worktree. Nothing was written to the main checkout.
- `CONFLICT: /incident "Closing an incident" step 4 (keep only id, title, correctiveAction, closedIn, closedDate, rootCause, preventionLayer; #172's closed entry had no "updated") vs this prompt ("closed date, updated date") -- resolved by prompt (tier 2): kept "updated" on #173 and added it to #172.`
- `CONFLICT: /incident step 5 ("Mention in release notes: Resolves Incident #N") vs this prompt ("NOT RELEASE_NOTES") -- resolved by prompt (tier 2): RELEASE_NOTES not edited; recorded as follow-up 1.`
- `CONFLICT: the auto-mode system note (Bash cat/sed allowed for file ops) vs USO "Dedicated tools for file ops" (commander's words) -- resolved by the commander's words (tier 1): Read/Edit/Write/Grep used throughout.` One deviation: a read-only `sed -n '106p'` to read one long table row of `plans/merge-friction-improvements.md`, which Grep had truncated. It is allowed by the standing-order-guard exemption but is still a Bash read.
- Judgement, not a conflict: item 6 said to fix each ref's path or remove it. For four refs I fixed the checker instead, because the refs are correct and the checker's own spec exempts gitignored paths. Changing correct docs to work around a checker bug would have been wrong. `check-path-refs.py` is not a `check-*.ps1`, so there is no overlap with M5-C1.
- `INCIDENT: pre-commit step 20 reported 4 Windows-only false positives (check-path-refs.py text-mode stdin) and at least PR #144, PR #147 and missions M2/M3b/M4 recorded them as "pre-existing" step-20 FAILs instead of investigating; the same "red by design, so red is ignored" pattern as plans/merge-friction-improvements.md finding 8.` Not filed. The code defect is fixed in 5b84b8c; the process side needs a decision.

## Open questions (each with a suggested answer)

1. Should #29 close now, accepting coverage at the helper level? Suggested: no. Keep it open until the three per-prompt EOF cases exist (follow-up 2). The issue's own fix 3 asks for each prompt, and the cases are small.
2. Is amending an already-closed incident (#172) acceptable? Suggested: yes. The closed entry is the only durable record of how it was fixed, and #144 changed that fix materially. The change is listed under Review after.
3. Which version does #144 ship in (for #173's closedIn)? Suggested: the RELEASE_NOTES batch decides, probably one entry with #144-#147, then updates closedIn in the same commit.

## Operational learning

- **Python `subprocess.run(..., input=str, text=True)` on Windows writes `\n` as `\r\n`.** A `git ... --stdin` reader then sees each line but the last with a trailing CR, and matches fail silently. Pass bytes. Watch for this in any harness Python that pipes paths to git.
- **A Windows-only check failure that CI never shows can be a checker bug.** Pre-commit checks do not run in CI, so their Windows half is exercised only by local Windows runs. Investigate before labelling a failure "pre-existing".
- **`git show <rev>:<path> --output=<file>` does not write a blob to the file.** It prints to stdout. Use a plain `>` redirect.
- **In a worktree mission, build every output path from the worktree root.** A path starting at the main checkout's `.aitools/` is denied; my one write error came from this.
- **The check scripts honour `AITOOLS_LOG_DIR`** (`CheckLogInit`). Set it to scratch to keep `checks.log` out of the real `~/.aitools/logs`. Pre-push step 7 isolates HOME itself.

## Delegates used

None.
