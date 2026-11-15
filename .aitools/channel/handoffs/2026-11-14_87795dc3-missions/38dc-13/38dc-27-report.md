# 38dc-27 report: finish 38dc-13 (Windows CI runs .ps1 only) (v1.1, pre-merge)

Mission 38dc-27-windows-ci-finish (agent id ends 08de), delegated by
M6-Polish, then M6b-Finish (session 87795dc3). Branch
`fix/38dc-13-windows-ci-ps1-only`, worktree `.claude/worktrees/38dc-13`,
PR #166. v1.1 changes: the #167 merge and its follow-on fix, independent
verification (08de-01, 08de-02) and the fixes it led to, RELEASE_NOTES
v0.77.16, the reserved-id notes in 38dc-13-report.md v1.2 and
e9d6-13-report.md v1.1. Facts after the merge (merge SHA, main CI) are in
the hand-back only (M6b-Finish: no direct pushes to main).

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
| 3065a2a | e9d6-22: pre-commit steps3-10, post-push deploy-steps .ps1 harnesses; .sh guarded; check.yml: windows runs the five .ps1, macos adds post-push step7 + menu-parity (bash 5, /bin/bash 3.2) | 40/0/0, 10/0/0; os-guards .ps1 66/0/0; check-ci-suites "All 63"; CI green (linux, macos, windows, CodeQL) |
| 329cec6 | this report v1.0 | n/a |
| eaf261a | merge origin/main 237bca9 (#167): check.yml, cross-platform.md/.mdc, deploy-steps .sh conflicts resolved keeping both sides; deploy-steps .ps1 expects step 6 (.sh) SKIP (no Git Bash) | five ports green; os-guards 68/0/0; "All 71"; mutation: harness vs pre-#167 check-post-push.ps1 -> exit 1 |
| (next) | verifier fixes: N1 comment lines no longer satisfy "step 29 calls check-menu-parity.pl" (.ps1 and .sh); N2 no Git-perl fallback in the four perl-using .ps1 harnesses, check-lib's Strawberry block loaded in all four, `perl: <path>` printed by menu-parity; N4 macos /bin/bash 3.2 step for test-pre-push-step7.sh; RELEASE_NOTES v0.77.16; 08de-01/02 reports; 38dc-13-report v1.2, e9d6-13-report v1.1 (#180 went to PR #172) | post7 7/0/0, parity 22/0/0 (perl C:\Strawberry\perl\bin\perl.exe), deploy 10/0/0, pre-commit 40/0/0; pwsh parser and bash -n clean; N1 probe: comment-only fixture -> False / exit 1, call fixture -> True / exit 0 |

Repo checks on eaf261a (Windows): check-pre-commit.ps1 (no -Fix) 7 PASS,
11 SKIP, 1 WARN (dotprofile uncommitted), 0 FAIL; check-pre-push.ps1 6
PASS, 4 WARN (release notes then missing, roadmap, commit count, checklist),
0 FAIL.

## Independent verification

- 08de-01 (e9d6-22's files): no blocking finding; 40 mutants on copies
  through PRE_COMMIT_PS1 / PRE_COMMIT_SH / POST_PUSH_PS1 / POST_PUSH_SH, all
  killed; both .sh reviewed (guard, cases, bash 3.2, AITOOLS_TEST_BASH).
  Non-blocking: N1 expected records written twice (golden-file follow-up),
  N2 path forms differ (cosmetic), N3 the pre-commit run case accepts exit
  0 or 1 (steps 20/21 FAIL locally under the redirected LOCALAPPDATA), N4 the
  `$gitBash` stub only catches `& $gitBash`. Report 08de-01-report.md.
- 08de-02 (e9d6-21's files): no blocking finding; 35 mutations (copies via
  POST_PUSH_* or a scratch clone), 34 killed; the survivor (menu-S1b, a
  comment line naming the checker) is fixed (N1 above). N2 Git-perl
  fallback (fixed), N3 perl not printed (fixed for menu-parity), N4 macos
  3.2 step for pre-push step7 (added), N5 check-menu-parity.pl Tests: line
  (already fixed in 8c0d59f; the finding was stale). Report 08de-02-report.md.

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

## Remaining

1. Independent reviewer (fresh delegate) posts its verdict with `gh pr comment`.
2. After #159 merges: cross-platform-detail.md "What CI runs on Windows".
3. After M6b-Finish reports #168 merged: merge origin/main --no-ff (keep
   both sides; #168's test-step7-grepq.sh must pass check-ci-suites and
   os-guards), RELEASE_NOTES order re-checked, CI green on the full head
   SHA, CLEAN, `gh pr merge 166 --repo nobul-tech/aitools --merge`, main CI.

## Lines

- RELEASE_NOTES version: v0.77.16 (M6b-Finish map: #159 v0.77.6, #167
  v0.77.13, #165 v0.77.14, #168 v0.77.15, #166 v0.77.16, M7 v0.77.17-21).
- INCIDENT (not filed): overlapping delegation (section above); prevention:
  list running subagents (transcript dir, meta.json descriptions) and
  untracked files before delegating into a worktree another mission used.
- RFI 38dc-27-1 (the Git-perl fallback) is resolved in this PR: the harnesses
  FAIL without perl on PATH, as check-lib.ps1 does.
