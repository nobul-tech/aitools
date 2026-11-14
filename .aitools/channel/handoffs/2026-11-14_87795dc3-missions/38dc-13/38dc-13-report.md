# 38dc-13 report: Windows CI runs .ps1 only (v1.1, interim: mission not finished)

Mission 38dc-13-windows-ci-ps1-only, delegated by M6-Polish (session 87795dc3).
Branch `fix/38dc-13-windows-ci-ps1-only`, pushed, head bbb22c6 (v1.0 of this
report: 70aaf09). No PR yet. The run was ended by the hand-back enforcer
before the CI change, the PR and the merge. Resume this agent to continue.

## Done (committed and pushed, each verified locally on Windows, .ps1 only)

| Commit | Content | Local result (re-run by 38dc-13) |
|---|---|---|
| 654900c | tests/lib/platform-lib.ps1 + test-platform-lib.ps1; b8-consumers port | 31/0/0; 31/0/0 (= CI) |
| 82258ae | classify-guards.pl; test-os-guards .sh guarded + .ps1 new; check-ci-suites.pl v2 + test; cross-platform.md / .mdc | probes pass |
| 6bd9886 | fanout-lib port (e9d6-06) | 90/0/20 (= CI) |
| 79fa1f1 | rules-fanout-cursor port (e9d6-04) | 145/0/6 (= CI) |
| 6af271c | skills-fanout port (e9d6-05) | 106/0/7 (= CI) |
| b79bf7c | .ps1 guards: console-mode-guard, resolve-git-bash, setup-user-shell; setup-user-shell.sh guarded (e9d6-12) | unchanged |
| c64d2a4 | profile test-config port (e9d6-09) | 247/0/1 (= CI) |
| 1e454ca | skills-legacy + rules-fanout ports (e9d6-03), ACL deny | 40/0/0, 65/0/2 |
| 5a7db2f | profile test-user-init port (e9d6-11) | 179/0/1 (= CI) |
| 02019e1 | managed-files .sh and .ps1 guarded (e9d6-13) | 56/0/0, 22/0/0 |
| f394020 | profile test-lib port (e9d6-10) | 201/0/1 (= CI) |
| 9d0297b | claude-mdm + hookin ports (e9d6-02) | 33/0/1, 29/0/0 (= CI) |
| c4c588e | deploy-harness port (e9d6-07), ACL deny | 109/0/0 |
| (merge) | origin/main with PR #157 | post-merge re-runs all green |
| 73151d1 | deploy-harness-mdm port (e9d6-08) | 56/0/0 (= CI) |
| 00d1f46 | pywinpty .ps1 Windows guard | 54/0/0 |
| 4a7d57b | logging and menus .ps1 guarded (e9d6-16); exemption row "Test suites pending a decision" for their .sh twins | 45/0/0, 97/0/0 (= CI) |
| bbb22c6 | profile test-install port (e9d6-15) | 51/0/3 (= CI) |

## Not done (next steps, in order)

1. e9d6-14 (tests/profile/test-profile port) was still running at hand-back:
   its files will be uncommitted in the worktree. Verify (run the .ps1; CI
   baseline 725 passed in `.scratch/session-38dc-13/ci-windows-875e957.log`)
   and commit.
2. After 38dc-19 (bash aitools forwarder, commander "3) agreed") merges:
   merge origin/main, guard tests/logging/test-logging.sh and
   tests/menus/test-menu-choice.sh, remove the "pending a decision" row, drop
   their windows-job steps. 38dc-19 also guards hh.sh, bootstrap.sh,
   init-hh-hooks.sh, analyze-session.sh (commander "5) add an OS guard to all
   of them"): do not edit those rows; merge cross-platform.md and
   tests/os-guards keeping both.
3. After PR #154 merges: port check-pre-push step 7, check-post-push step 7,
   menu-parity (perl cases cross-platform) and #154's two new suites.
4. check.yml: run `.scratch/session-38dc-13/rewrite-windows-job.pl` on it
   (tested on a copy; it switches the ported suites to `pwsh -NoProfile -File`,
   drops the managed-files .sh steps, adds test-platform-lib.ps1, rewords the
   heavy-suites comment); add the check suites; update the windows job's
   header comment; preview with
   `perl scripts/check-ci-suites.pl --root . .github/workflows/check.yml`.
5. RELEASE_NOTES, PR, independent review, CI green on all jobs.
6. Do not merge before M6-Polish sends 38dc-20's recommendation on the
   ACL-deny cases (commander asked "why are we dealing with permissions?").
7. After merge: CLAUDE.md tests line direct to main; cross-platform-detail.md
   "What CI runs" after #159.

## Lines

- WRITE_BLOCKED: running the b8 .sh guard under a uname shim with
  OSTYPE=linux-gnu -- "Permission for this action was denied by the Claude
  Code auto mode classifier. Reason: [Undermining Oversight]". Not retried.
- CONFLICT: the brief's CLAUDE.md edit in the PR vs CLAUDE.md "Channel
  exception" (commander, 2026-10-26) -- resolved by tier 1: direct to main
  after the PR merges.
- CONFLICT: the commander's "we only need to test the ps1 here on windows"
  (AI merge, menus) vs M6-Polish "hold the guard decision" -- resolved by
  following the commander's later answer to RFI 38dc-13-1 (fix via 38dc-19
  first, then guard): the menus .sh stays on Windows only until 38dc-19 merges.
- INCIDENT (not filed; reserved #180): .ps1 checks gated `-not $IsWindows`
  never ran in CI (managed-files write failure, adopt-push commit failure);
  16 + 6 parity gaps (e9d6-13-report.md).
- INCIDENT (relayed from 38dc-09, out of scope): the deploy/ steps of check.yml
  always pass on the frozen tree.
- e9d6-13 published its report as a private artifact:
  https://claude.ai/code/artifact/9028057c-e56a-4f16-8fe4-83a98ddc6c20

## Open questions

The three RFIs of v1.0 are answered (commander, 2026-11-14, relayed by
M6-Polish): 38dc-13-1 "3) agreed. fix this in a delegate mission" (38dc-19);
38dc-13-3 "5) add an OS guard to all of them" (38dc-19); 38dc-13-2 under
investigation (38dc-20). No new open question.
