# 38dc-27 report: finish 38dc-13 (Windows CI runs .ps1 only) (v1.0, interim)

Mission 38dc-27-windows-ci-finish (agent id ends 08de), delegated by
M6-Polish (session 87795dc3). Branch `fix/38dc-13-windows-ci-ps1-only`,
worktree `.claude/worktrees/38dc-13`. PR #166 (draft, opened early for CI).

## State verified at start

- Branch head 9f1dab9, origin/main 5f962b1 (#154) already merged in.
- Uncommitted check.yml (61+/71-) read in full as a diff: matches the
  38dc-13 description (ported suites to `pwsh -NoProfile -File`, managed-files,
  logging and menus .sh steps dropped, test-platform-lib.ps1 added).
- Re-runs (Windows, pwsh): test-b8-consumers.ps1 31/0/0, test-fanout-lib.ps1
  90/0/20 (both equal 38dc-13's table); test-os-guards.ps1 60/6/0, the 6
  failures being the five unported check suites and tests/bootstrap/test-bootstrap.ps1
  (no standard guard; added by PR #160 after 38dc-13's guard pass).
- check-ci-suites.pl (stdin = git ls-files): only two gaps, both in check
  suites still to port (test-post-push-step7.sh, test-menu-parity.sh not in
  the macos job).

## Done

| Commit | Content | Verification |
|---|---|---|
| 15ce209 | check.yml windows-job rewrite (+ header comment); test-bootstrap.ps1 standard Windows guard | test-bootstrap.ps1 26/0/0 |
| 8c0d59f | e9d6-21: pre-push step7, post-push step7, menu-parity .ps1 harnesses; .sh guarded; check-menu-parity.pl Tests: line | 3/0/0, 7/0/0, 22/0/0 (re-run by 38dc-27) |
| 3065a2a | e9d6-22: pre-commit steps3-10, post-push deploy-steps .ps1 harnesses; .sh guarded; check.yml: windows runs the five .ps1, macos adds post-push step7 + menu-parity (bash 5, /bin/bash 3.2) | 40/0/0, 10/0/0; os-guards .ps1 66/0/0; check-ci-suites "All 63" |

## Orphaned delegates found

38dc-13's delegates e9d6-21 (pre-push step7, post-push step7, menu-parity)
and e9d6-22 (pre-commit steps3-10, post-push deploy-steps), launched about
16:17, were still running after their parent ended; the brief did not list
them. 38dc-27 launched 08de-01/02 on the same files at about 16:22 without
checking for running writers. e9d6-21/22 were further along, so they kept
the files (told: no commit, no push, report to 38dc-27) and 08de-01/02 were
stopped. 08de-01 had already overwritten e9d6-22's pre-commit .ps1 (16:29);
e9d6-22 restored its own from context and re-verified it (40/0/0, 8
mutations). 08de-01's text kept at
.scratch/session-38dc-27/08de-01-pre-commit-steps3-10.ps1.tmp.

## CI

PR #166 at 3065a2a513dc5ce1ddfbb1381aef12ceaddd2f28: CI success (linux,
macos, windows), CodeQL success. The superseded run 43658023159 (15ce209)
was cancelled.

## Next

- After PR #167 (38dc-23) merges (M6-Polish order): merge origin/main
  --no-ff, re-run the five ports (deploy-steps step 6 expectations change),
  independent verification (08de-01 on e9d6-22's files, 08de-02 on e9d6-21's).

## Lines

- RELEASE_NOTES version: v0.77.16 (M6-Polish merge order: #167 v0.77.13, #159 v0.77.6, #165 v0.77.14, #168 v0.77.15, #166 last).
- This v1.0 is interim: the run was ended by the hand-back enforcer while
  waiting for #167. Remaining, in order: (1) after #167 merges, merge
  origin/main --no-ff keeping both sides (check.yml, cross-platform.md,
  test-post-push-deploy-steps.sh, test-resolve-git-bash.ps1), re-run the
  five ports and fix the deploy-steps / any .ps1 expectations #167 changes;
  (2) resume 08de-01 (verify e9d6-22's files) and 08de-02 (verify e9d6-21's
  files): re-run, mutation-proof, review .sh diffs, os-guards; (3) RELEASE_NOTES
  v0.77.16 (insert above main's top entry; 0 deletions); cross-platform-detail.md
  "What CI runs on Windows" after #159; check-pre-commit.ps1 and
  check-pre-push.ps1 (no -Fix); (4) full PR body (inventory, Review after,
  follow-ups), mark ready; (5) independent reviewer, gh pr comment;
  (6) merge origin/main with all four PRs in, CI green, merge, watch main CI.
- INCIDENT (not filed): overlapping delegation (section above); prevention:
  list running subagents (transcript dir, meta.json descriptions) and
  untracked files before delegating into a worktree another mission used.
- INCIDENT (not filed, relayed from 08de-02): the menu-parity/step7 .ps1
  harnesses keep a Git-perl fallback when no perl is on PATH, while
  check-lib.ps1 never falls back ("Fail, don't mask"). Low.
