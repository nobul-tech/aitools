# S3-MA-DocsApply log

**Version:** v1.0 · **Written:** 2026-10-27 · **By:** S3-MA-DocsApply (delegate of mission MERGE-ALL, Session Commander 10cf255a-c, commander Jose)
**Status:** done, with one WRITE_BLOCKED class (review-after wording) not applied.

## Result

| Item | Value |
|------|-------|
| PR | https://github.com/nobul-tech/aitools/pull/132 (branch `docs/v0.74.0-scrub`, worktree `.claude/worktrees/scrub`) |
| PR commits | 55e8ecb (rules + Cursor twins), 55bb081 (reference/), ee1b92b (top-level docs, skills, RELEASE_NOTES v0.74.0), 99b668a (row 93 cites #132) |
| PR CI | run 40496219119: linux, macos, windows SUCCESS; CodeQL SUCCESS; mergeStateStatus CLEAN |
| Merge | `gh pr merge 132 --merge` -> merge commit 3ddf67be096b22dad630042cc670df1c361ba328 (2026-10-27T11:42:06Z) |
| Main CI after merge | run 40498115228 (CI): macos, linux, windows SUCCESS; run 40498114642 (Push on main): success |
| Direct to main (Channel exception) | 981c4b4 CLAUDE.md (ScrubTop F1-F5) |
| Tag | `v0.74.0`, annotated, tag object 4af15f181d517fa0e33e262d1eadd7f848dccb6d -> commit 3ddf67b; pushed to origin |

## What was applied

- S3-MA-ScrubRules v1.0: F3, F4, F6-F18, F20, F21, F24-F42, F44, F45 (except ":32"), F47 (mission pointer), F48-F50, F51 (table in reference/cursor-practices.md), C-3 (`AI invocation:` prefix).
- S3-MA-ScrubReference v1.0: MFD-1..14, HAR-1..7, LOG-1..5, UR-1..7, SSD-1..6, PC-1..3, PP-1..2, PO-1..9, TO-1..8, RU-1..5, CP-1..7, FT-1..13, AF-1..3, TS-1..4 (TS-3 as a severity-guide line), RM-1..2, EF-1..3, SH-1..2, SM-1, 2, 4, 5, 6, 8; `scripts/check-path-refs-allow.txt` updated.
- S3-MA-ScrubTop v1.0: F1-F5 (CLAUDE.md, direct to main), F7-F31, F33-F56, F58-F77, F79-F83.
- RELEASE_NOTES.md: S3-MA-ReleaseNotes entry v1.0 replaces the never-tagged v0.73.3 section (Q1 suggested answer); row 93 added for this scrub. Pending rows for #117-#126 not folded in: those PRs are still open (all DIRTY at 2026-10-27).

Each changed claim was checked against the code before writing (greps in scripts/, `aitools --help`, profile.json key names, ait-harvest.py, harness-db.py subcommands, `claude --version` = 2.1.309). Where a finding's replacement text claimed something I could not confirm, I dropped or softened it (README "aitools is a PowerShell function", chrome-devtools "pass pageId on every call", postinstall "sets" -> "is designed to set", harness-db "provenance export" -> `export`, `relay sync` summary name left out).

## WRITE_BLOCKED

WRITE_BLOCKED: Edit of `.claude/worktrees/scrub/.claude/rules/sources-of-truth.md` (intro paragraph: pre-write review -> review-after, ScrubRules F1) -- "Permission for this action was denied by the Claude Code auto mode classifier. Reason: [Self-Modification]."

Not retried. The same class (loosening the protected-file pre-write gate) was therefore not attempted anywhere: ScrubRules F1 (md and mdc "The rule", Exceptions, Intent statements, Why), F19, F23, F43, F46, F47 second half; ScrubReference FT-15; ScrubTop F57 (skills' "present for review / write if approved"). The S3-MA-Versions-log v1.0 text (lines 40-79) remains the ready version. Factual rule edits were not blocked (git-safety, relay-outbound and the rest went through).

## Not applied (other reasons)

- ScrubRules F5 (redundant row, kept), F22 (`version`, `review-after` glossary terms: registry writes through `/glossary`), F45 ":32 all 6 fields" (unverified).
- ScrubTop F32 (personal identity in public `user-rules.md`: commander decision), F78 (framework registry review), F84 (info), F27 @-reference section (dotprofile-only).
- ROADMAP row for `plans/merge-friction-improvements.md`: the file does not exist in any branch (`git log --all`), so no row.
- Template sync: the dotprofile `claude/CLAUDE.md` does not carry the claude-shared.md fixes (key names, nobul-tech links, bash/node rows, sub-agent UCI). Not edited: it is the commander's user-level instruction source.

## Checks

- `python3 scripts/check-path-refs.py`: 0 dead paths (after each batch).
- `bash scripts/check-pre-commit.sh` (worktree): 8 PASS, 12 SKIP, 1 WARN (11: uncommitted changes in the dotprofile, not mine), 1 FAIL (6: known `harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh` 100644).
- `bash scripts/check-pre-push.sh` (worktree): 7 PASS, 2 WARN (1, 6 reminders), 1 FAIL (7: dotprofile `deploy/` stale: deploy-harness.payload/.ps1/.sh, setup-user-claude.ps1/.sh, setup-user-skills.ps1/.sh). Expected: this PR changes content the dotprofile build embeds (reference/, rules, skills, the shared template).
- Not run: Windows; any script (docs only); the dotprofile rebuild.

## Follow-ups (for the orchestrator)

1. Rebuild and commit the dotprofile `deploy/` from main at v0.74.0 (pre-push step 7 fails until then). I did not run `build-deploy.sh` against the real dotprofile: my task did not order it.
2. The tag v0.74.0 was cut with #117-#126 still open; their pending release-note rows stay in S3-MA-ReleaseNotes-entry.md for v0.74.1 / v0.75.0.
3. Apply the review-after version of sources-of-truth.md (blocked for agents) or grant the allowance.

## INCIDENT markers (not filed)

- INCIDENT: pre-commit steps 3/10 and post-push step 7 inspect the frozen `aitools/deploy/`; step 3 `--fix` and post-push step 7 run `build-deploy.sh` against the real dotprofile (ScrubRules F8, ScrubReference INCIDENT 1-2).
- INCIDENT: post-push step 26 always SKIPs (no deploy list in CLAUDE.md); post-push `--extensive` flag is dead code.
- INCIDENT: `scripts/githooks/pre-commit` runs build-deploy against the real HOME and `git add deploy/` on the frozen tree.
- INCIDENT: `setup-user-claude` does not fan out `~/.aitools/rules` (PR #121 open), so `shared/rules/*` never reach `~/.claude/rules`.
- INCIDENT: tracked backups `shared/hooks/harness-db-sessionstart.sh.bak.*` and `standing-order-guard.sh.bak.*`.
- INCIDENT: check-pre-push step 9 passes any push to main; CLAUDE.md allows only the channel exception paths.
- INCIDENT (harness): the auto mode classifier blocks the commander-decided review-after rule text for agents ([Self-Modification]); the decision cannot land through a delegate.
