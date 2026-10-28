# S3-FanoutImpl-SkillsLegacy hand-back (FO-6), v1.0, 2026-10-27

## Summary
- PR: https://github.com/nobul-tech/aitools/pull/125. Branch `feature/fanout-skills-legacy`, head 72589f9, base main.
- Start point: `origin/feature/fanout-claude-rules` (f897b74), then `origin/feature/fanout-harness-skills` merged with `--no-ff` (3178810). One conflict, in the header and `--help` range of `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`; both sides' text is kept and the range is now 2-30.
- **When `~/.aitools/skills` exists**, setup-user-skills.sh/.ps1:
  - do not deploy and do not write the `claude skills` / `cursor skills` rows;
  - write `OK skills n/a (fanned out from ~/.aitools/skills)` and log which scripts own the deploy;
  - keep reverse discovery. It ignores every harness name (directory entry or manifest line of any source, `retired` included, case-insensitive) and every backup or hidden name.
- **Resolver error in that mode** (the choice the brief asked for): reverse discovery is skipped, with `ERROR skills "reverse discovery skipped: dotprofile error"`. The two fan-out names are not used.
- **Unreadable `~/.aitools/skills` or manifest**: `ERROR skills "reverse discovery skipped: cannot read ~/.aitools/skills"` (or `"...: cannot read skills manifest"`), and reverse discovery is skipped.
- **Bad manifest header**: no names are taken from the manifest; this is logged as info, since the fan-out reports it. Directory names still count.
- **No dotprofile**: the harness is not read, because there is no adopt target.
- **Without `~/.aitools/skills`**: unchanged behaviour.
- **MDM**: the check is in the extracted "skills body". build-deploy wraps the embedded deploy in `if [ "$SKILLS_FANNED_OUT" != "true" ]` / `if (-not $skillsFannedOut)`.

## Files changed
- scripts/setup-user-skills.sh, scripts/setup-user-skills.ps1 (CRLF kept)
- scripts/build-deploy.sh (setup-user-skills generator only)
- tests/skills-legacy/test-skills-legacy.sh (new, 100755)
- .github/workflows/check.yml: the suite on macOS (bash 5, /bin/bash 3.2) and Linux, with `!cancelled()`

## Verification
- **tests/skills-legacy**: 38/38 with bash 5 and 38/38 with /bin/bash 3.2. Covers dev .sh/.ps1, row parity across 8 cases, and the MDM .sh/.ps1 with and without the harness.
- **Mutation run**: the suite run against the previous scripts fails 23 cases; the fallback cases pass.
- **Other suites**:

  | Suite | Result |
  |---|---|
  | tests/claude-mdm (bash 5 / 3.2) | 35/35, 35/35 |
  | tests/deploy-harness | 131/131 |
  | tests/b8-consumers | 60/60 |
  | tests/hookin | 39/39 |
  | tests/deploy-harness-mdm | 66/67 |

  The deploy-harness-mdm failure is `size gate (forced)`, and it is inherited: it fails the same way on origin/feature/fanout-claude-rules alone (64/65) and on 3178810.
- **Syntax**: `bash -n` and the pwsh parser pass on the dev and generated scripts; the YAML parses.
- **check-pre-commit**: FAIL step 6 only (known harvesting file, 100644).
- **check-pre-push**: FAIL step 7 only (known stale dotprofile deploy/).
- **PR CI**: still running when this report was written. #125's mergeStateStatus was UNSTABLE, not DIRTY, so no merge of origin/main was needed. Expected red from inherited failures: deploy-harness-mdm `size gate (forced)`, and `fanout-lib bd-special` ps parity on Linux. #121's CI fails both.

## Not run
- The Windows CI job: the suite is not added there, the same as rules-fanout-cursor.
- Real HOME runs: never done.
- PR CI green: not reached (see above).

## INCIDENT
- INCIDENT: tests/deploy-harness-mdm "size gate (forced)" fails on FO-3's head (origin/feature/fanout-claude-rules). The case pads a dotprofile rule so that setup-user-claude.sh goes over 1 MB, but FO-3 no longer embeds dotprofile rules in it. Owner: FO-3 fix round on #121.
- INCIDENT: #121 Linux CI also fails `fanout-lib bd-special` (ps parity). Owner: FO-1 fix round.

## Follow-ups / open questions
- Fallback mode still offers `*.bak.*` directories in ~/.claude/skills for adoption, as before. Suggested: apply the backup and hidden filter in both modes (FO-7 or a small fix PR).
- FO-7 docs: deploy-paths "What IS auto-embedded" and reference/managed-file-deployment.md content sources should describe the fallback.
- Two `skills` rows (OK n/a plus ERROR) appear when the resolver fails while fanned out. Suggested: keep both, since each reports a different fact.

## Other
- No CONFLICT: lines, no WRITE_BLOCKED lines.
- Extra worktree: /Users/new-jose/repos/aitools/.claude/worktrees/fo-skleg-base (detached, used for baseline runs). Not removed, per the brief.
