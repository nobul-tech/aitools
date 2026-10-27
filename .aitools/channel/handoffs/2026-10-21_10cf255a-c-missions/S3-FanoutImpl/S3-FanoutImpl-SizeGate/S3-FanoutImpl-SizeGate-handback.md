# S3-FanoutImpl-SizeGate hand-back (FO-0b, FX-12 / D3)

Version 1.0, 2026-10-27, by S3-FanoutImpl-SizeGate (level 2, under S3-FanoutImpl, Session Commander 10cf255a-c).

## Summary

1. `scripts/build-deploy.sh` post-build step 3 now measures every generated `deploy/*.ps1` (200,000 B) and `deploy/*.sh` (1,000,000 B); at or over the limit is a `blog_warn` naming file, size and limit; the build does not fail.
2. The over-limit warnings are listed again after "Build complete" (end of the build output).
3. deploy-harness keeps its within-5% WARN and OK row; a missing `deploy-harness.ps1/.sh` is still a build error.
4. `tests/deploy-harness-mdm` asserts the WARN (build exit 0; each over-limit script's WARN twice; none for an under-limit one) instead of `deploy-harness.ps1 < 200000`.
5. PR #120 implements RECONCILE FX-12; RECONCILE skips it.

- PR: https://github.com/nobul-tech/aitools/pull/120
- Branch: `feature/fanout-size-warn`, head `978e72d`, start `feature/fanout-base` d7f6855; base `main`.
- Worktree: `/Users/new-jose/repos/aitools/.claude/worktrees/fo-size`
- Review diff: `git diff d7f6855...978e72d`

## Files changed

- `scripts/build-deploy.sh` (step 3 size block; end-of-build WARN list)
- `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` (size check -> `size_gate_warned`)
- `tests/claude-mdm` needed no change (it only asserted build exit 0; `grep -rn "Intune script limit" tests scripts` found only the deploy-harness-mdm check).

## Deviation from the draft

`S3-Reconcile-Fix-drafts/code/edits-pr111.txt` (L211 block) was written against `origin/feature/harness-mdm-followups`: it added a WARN loop for the other scripts and kept the deploy-harness FAIL. Its anchor matches, but applying it would keep the FAIL that the mission removes. Written instead: one loop over every generated script, WARN for deploy-harness too.

## Generated script sizes (build into a local clone of the dotprofile, isolated HOME, base d7f6855 + this change)

Over 200,000 B (WARN): `setup-user-claude.ps1` 489,424; `setup-user-cursor.ps1` 474,385; `setup-user-settings.ps1` 435,488; `setup-user-skills.ps1` 368,502; `setup-user-hooks.ps1` 313,686; `aitools-profile.ps1` 244,457; `deploy-harness.ps1` 202,519.
Under: largest other `.ps1` `setup-user-config.ps1` 190,719; largest `.sh` `setup-user-claude.sh` 454,972 (limit 1 MB); `deploy-harness.sh` 188,534. Build exit 0.

## Verification (macOS)

- `bash -n` both files: OK
- `tests/deploy-harness-mdm`: 64 passed, 0 failed (first run 63/1: my own test's grep missed the indented end-of-build line; fixed before commit)
- `tests/claude-mdm` bash 5.3.15: 34 passed, 0 failed; `/bin/bash` 3.2: 34 passed, 0 failed
- `check-pre-commit`: rc 1, only step 6 FAIL = known harvesting 100644 file; WARN steps 3 (no `--fix` by rule), 5, 9, 11
- `check-pre-push`: rc 1, only step 7 FAIL = known stale dotprofile deploy/
- CI PR #120: all green (macos 14m17s, linux 8m13s, windows 1m3s, CodeQL + 4 Analyze jobs)

## Not run

Windows locally; `check-post-push` (not before merge).

## WRITE_BLOCKED

None.

## INCIDENT

None filed. Observation: the end-of-build list prefixes each message with two spaces, so a grep for `[warn] deploy/<f>` matches only the inline line; tests should match the message text.

## Open questions

- Q: Should the within-5% WARN apply to every generated script, not only deploy-harness? Suggested: no (seven `.ps1` are already over; near-limit noise adds nothing until FX-35).
