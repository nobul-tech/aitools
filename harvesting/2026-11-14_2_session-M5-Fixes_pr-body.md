## Summary

Mission M5-Fixes, docs group (items 6, 7, 8, 13, plus a new incident).

- Item 6: check-pre-commit step 20's five "dead path refs" were four Windows-only false positives and one real dead ref. `scripts/check-path-refs.py` `git_ignored()` wrote its stdin in text mode, so on Windows every path but the last reached `git check-ignore --stdin` with a trailing CR and never matched; it now writes UTF-8 bytes. `CLAUDE.md` no longer cites the deleted `.claude/rules/relay-outbound.md`.
- Item 7: RELEASE_NOTES.md v0.76.2 covers PRs #144-#147 (merged 2026-11-14 before #148's v0.77.0, rolled into one entry per the same-day rule); v0.77.3 covers this branch.
- Item 8: incident #173 closed (fixed by PR #144, closedIn v0.76.2); #172 (closed in v0.76.1 by PR #143) amended to record the #144 follow-up.
- Item 13: issue #72 closed with evidence (CI run 43557171983, a three-mutation test); #29 commented and left open (EOF regression cases still missing for the JSON field prompt and the AI-merge preview/feedback reads).
- New incident #174 (high): log writers outside aitools-lib (`aitools-install.*`, `aitools-profile.*`, `check-lib.*`) are not fail-safe (logging.md section 5).

## Why

- Pre-commit step 20 had failed on Windows in every mission today and was logged as "pre-existing"; the checker itself was wrong.
- documentation-standards.md requires a release-notes entry; #144-#147 had none, and #173's closedIn needed a version.

## Changes

- `scripts/check-path-refs.py` (`git_ignored`), `CLAUDE.md` (relay section), `registries/incidents.json` (#172 amended, #173 closed, #174 filed, through /incident), `RELEASE_NOTES.md` (v0.76.2, v0.77.3), mission reports and issue-comment bodies under `.aitools/channel/handoffs/2026-11-14_87795dc3-missions/M5-Fixes/`.

## Verification

Windows 11, by delegates M5-D1 and M5-D2: check-path-refs 5 dead refs before, 0 after (a scratch fixture passes with the fix, fails without); `git check-ignore -v` confirms `.claude/settings.local.json` and `.cursor/mcp.json` are gitignored; setup-user-shell .ps1 suite 37/0 for #173; check-pre-commit.ps1 0 FAIL (step 20 PASS); check-pre-push.ps1 0 FAIL. incidents.json edits round-trip byte-identically outside the intended lines. Issue #72's evidence run 43557171983 verified green on main 592c5b3 by M5-Fixes before posting.

After merging main (#149, #150; RELEASE_NOTES kept v0.77.3, v0.77.2, v0.77.1 descending, insertion-only vs main): check-pre-commit.ps1 0 FAIL (step 20 PASS), check-pre-push.ps1 0 FAIL (step 7 PASS); CI run 43568576946 on cd87d21 green on linux, macos, windows. The mission report `M5-Fixes-report.md` (v1.0) is in this PR.

## Not run

- check-path-refs on macOS / Linux (unaffected: the bug is Windows text-mode only); CI runs it.
- check-post-push.

## Review after (D-DEL5, old -> new)

1. `check-path-refs.py` `git_ignored()`: text-mode `input="\n".join(paths)` -> UTF-8 bytes with a final newline.
2. `CLAUDE.md`: "See `.claude/rules/relay-outbound.md`." -> "Committing `relay.md`: \"Channel exception\" below."
3. Incident #173: open -> closed (closedIn "v0.76.2 (PR #144, fix/console-and-profile, merge c66d4b1)", closedDate 2026-11-14, rootCause / correctiveAction / preventionLayer written).
4. Incident #172: correctiveAction names PR #143 (merge 941e64a) and the #144 follow-up; preventionLayer adds the .sh suites; `updated` 2026-11-14.
5. Incident #174: none -> open, high.
6. RELEASE_NOTES.md: v0.76.2 (18 items) and v0.77.3.

## Follow-ups

- #29: add EOF cases for `prompt_json_field_review` / `Prompt-JsonFieldReview` and the AI-merge `[y/r/n]` preview and `[r]` feedback reads, then close it.
- `check-path-refs.py` has no test suite; promote M5-D1's fixture to `tests/path-refs/`.
- #174: route the remaining log writers through `Add-AitLibLogText` / `_aitlib_log_append`.
- The dotprofile `claude/CLAUDE.md` counterpart of `shared/claude-shared.md` needs no change (the cited path was a false positive).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
