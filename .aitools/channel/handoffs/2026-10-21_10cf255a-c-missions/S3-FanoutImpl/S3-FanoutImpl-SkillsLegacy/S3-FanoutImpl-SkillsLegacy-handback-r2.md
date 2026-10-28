# S3-FanoutImpl-SkillsLegacy hand-back, round 2 (PR #125 follow-up), v1.0, 2026-10-27

PR: https://github.com/nobul-tech/aitools/pull/125. Head 293ec10.

The finding-to-fix mapping comment is posted: https://github.com/nobul-tech/aitools/pull/125#issuecomment-6433847474

## Not done
- **#125 is DIRTY/CONFLICTING against main**, so check.yml did not run on 293ec10. Only CodeQL ran.
- The brief's rule is to merge origin/main `--no-ff`, resolve, rerun the suites and push. I did not do that: I was told to hand back first.
- Next step: a fresh round, or me again, runs `git merge --no-ff origin/main` in `/Users/new-jose/repos/aitools/.claude/worktrees/fo-skleg`, resolves the conflicts, reruns `.scratch/session-foskl/run-suites2.sh`, pushes, and waits for CI.

## Done (each finding mapped to its fix)
- **Review B1 (merge order)**: merged #124 (through 5267e9e) and #123 with `--no-ff`. The check.yml conflict is resolved by keeping both sides, and the PR body says #125 contains #124 and #123.
- **Review N1 (adopt failure row)**: an adopt failure in fan-out mode now writes `ERROR skills "adopt failed: <name>"`, through `SKILLS_ROW_TOOL` / `$skillsRowTool`. A pty test covers it.
- **Review N2 (duplicate rows)**:
  - 5267e9e is merged.
  - New dev-order test: setup-user-claude, then setup-user-skills, then setup-user-cursor, into one summary file. Each skills tool row appears exactly once, in both modes and in sh and ps.
  - The test stubs rg and agent on PATH, so no installer runs.
- **Review N3 (missing tests)**: added a pty adopt in fan-out mode, a pty adopt failure, and an empty harness.
- **Audit A N1/N2 (detail length, governed "skipped")**: details are now `n/a (fanned out)`, `no adopt: dotprofile error`, `no adopt: harness unreadable`, `no adopt: manifest unreadable` and `no adopt: target unreadable`.
- **Audit A N4 (green CI with skipped cases)**: under `CI=true`, a missing perl, git, pwsh, node or python3 is a FAIL. Locally it is still a SKIP with a message.
- **Audit A N5 / B N3 (log wording)**: sh and ps write the same log text, with the reason last. A manifest that is a directory gives "is a directory" in ps too. Tests assert the exact text.
- **Audit B N1 (unreadable `~/.claude/skills`)**: now log_error + `ERROR skills "no adopt: target unreadable"`, using `Get-ChildItem -ErrorAction Stop` with a catch in ps. A test covers it.
  - Reverse discovery reads only `~/.claude/skills`, as before, so `~/.cursor/skills` has no reverse-discovery read to check.
- **Integration fix in tests/skills-fanout (a file owned by FO-4/FO-5)**: #123's cursor no-harness case still expected the `OK n/a` row that 5267e9e removed. It now expects no row, as 5267e9e did for the claude case. #123 needs the same edit.
- **PR body**: updated, with Audit A N3 and Audit B N2-N5 listed as follow-ups.

## Verification (293ec10, macOS, isolated HOMEs)

| Suite | Result |
|---|---|
| skills-legacy, bash 5 / 3.2 / `CI=true` | 50/50 each |
| skills-fanout, bash 5 | 158 passed, 1 skipped |
| skills-fanout, 3.2 | 65 passed, 28 skipped |
| claude-mdm, bash 5 / 3.2 | 38/38 each |
| deploy-harness-mdm | 67/67 (the size-gate failure is gone after the merges) |
| deploy-harness | 131/131 |
| b8-consumers | 60/60 |
| hookin | 39/39 |
| rules-fanout-cursor | 198 passed, 1 skipped |
| fanout-lib | 358/358 |

- check-pre-commit fails only step 6 (the known harvesting file).
- check-pre-push fails only step 7 (the known stale dotprofile deploy/).

## INCIDENT
- INCIDENT: #123 `tests/skills-fanout` cursor no-harness case is stale after #124's 5267e9e. It is fixed in #125's branch only.
