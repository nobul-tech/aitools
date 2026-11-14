# 38dc-13 report: Windows CI runs .ps1 only (v1.0, interim: mission not finished)

Mission 38dc-13-windows-ci-ps1-only, delegated by M6-Polish (session 87795dc3).
Branch `fix/38dc-13-windows-ci-ps1-only`, pushed, head c4c588e. No PR yet.
The run was ended by the hand-back enforcer before the CI change, the PR and
the merge. Resume this agent (SendMessage to it) to continue.

## Done (committed and pushed, each verified locally on Windows, .ps1 only)

| Commit | Content | Local result (re-run by 38dc-13) |
|---|---|---|
| 654900c | tests/lib/platform-lib.ps1 (Windows golden helper) + test-platform-lib.ps1; b8-consumers .ps1 port, .sh guarded | 31/0/0; 31/0/0 (= CI) |
| 82258ae | classify-guards.pl; test-os-guards.sh guarded, test-os-guards.ps1 new; check-ci-suites.pl v2 (per-job platform rule) + its test; cross-platform.md / .mdc "Test suites" patterns, exemption row, enforcement | os-guards.ps1 runs; perl probes pass |
| 6bd9886 | fanout-lib port (e9d6-06) | 90/0/20 (= CI) |
| 79fa1f1 | rules-fanout-cursor port (e9d6-04) | 145/0/6 (= CI) |
| 6af271c | skills-fanout port (e9d6-05) | 106/0/7 (= CI) |
| b79bf7c | Windows guard on console-mode-guard, resolve-git-bash, setup-user-shell .ps1; setup-user-shell.sh guarded (e9d6-12) | 76/0/7, 17/0/0, 37/0/0 (unchanged) |
| c64d2a4 | profile test-config port (e9d6-09) | 247/0/1 (= CI) |
| 1e454ca | skills-legacy + rules-fanout ports (e9d6-03), chmod cases via ACL deny | 40/0/0, 65/0/2 (CI 32/0/2, 61/0/3) |
| 5a7db2f | profile test-user-init port (e9d6-11) | 179/0/1 (= CI) |
| 02019e1 | managed-files .sh guarded, .ps1 guarded (e9d6-13) | 56/0/0, 22/0/0 (unchanged) |
| f394020 | profile test-lib port (e9d6-10), Git Bash cases via Resolve-TestGitBash | 201/0/1 (= CI) |
| 9d0297b | claude-mdm + hookin ports (e9d6-02); -Help fix | 33/0/1, 29/0/0 (= CI) |
| c4c588e | deploy-harness port (e9d6-07), read-only cases via ACL deny | 109/0/0 (CI 99/0/2) |

Every port: same check names and golden files, mutation-proofed (3-6
mutations each, all caught), bash -n, the .sh guard refuses Git Bash.
Delegate reports: e9d6-01..13-report.md in this directory.

## Not done (next steps, in order)

1. e9d6-08 (tests/deploy-harness-mdm port) was still running at hand-back:
   its files will be uncommitted in the worktree. Verify (run the .ps1, read
   the .sh diff) and commit.
2. Blocked by PR #157: ports of tests/profile/test-install.sh and
   test-profile.sh; guards of tests/logging (decide: bash logging reached on
   Windows via scripts/aitools), tests/menus (.sh class b), tests/pywinpty
   .ps1 guard (.sh is in the cross-platform row).
3. Blocked by PR #154: ports of check-pre-push step 7, check-post-push step 7,
   menu-parity (perl cases cross-platform) and #154's two new suites.
4. .github/workflows/check.yml windows job: every ported suite from `bash
   ...sh` to `pwsh -NoProfile -File ...ps1`; drop managed-files and menus .sh;
   add tests/lib/test-platform-lib.ps1; os-guards to the .ps1. CI is red on
   the branch until this lands (guarded .sh still in the windows job).
   Preview: `perl scripts/check-ci-suites.pl --root . .github/workflows/check.yml`.
5. RELEASE_NOTES entry, CLAUDE.md tests line (direct to main, Channel
   exception), reference/cross-platform-detail.md "What CI runs today" after
   #159 merges, PR, independent review, merge.

## Lines

- WRITE_BLOCKED: running the b8 .sh guard under a uname shim with
  OSTYPE=linux-gnu -- "Permission for this action was denied by the Claude Code
  auto mode classifier. Reason: [Undermining Oversight]". Not retried; the
  guard's spoof resistance rests on BASH_VERSINFO[5] being read-only
  (verified: `env BASH_VERSINFO=x bash -c 'echo ${BASH_VERSINFO[5]}'` printed
  x86_64-pc-cygwin, while an exported OSTYPE=linux-gnu overrode $OSTYPE).
- CONFLICT: the brief's CLAUDE.md edit in the PR vs CLAUDE.md "Channel
  exception" (commander, 2026-10-26: CLAUDE.md commits go direct to main) --
  resolved by tier 1: the CLAUDE.md tests line goes direct to main after the
  PR merges.
- INCIDENT (not filed; reserved id #180): .ps1 checks gated `-not $IsWindows`
  in test-managed-files.ps1 (2) and test-adopt-push.ps1 (1) never ran in any
  CI job (write-failure and commit-failure handling untested); 16 + 6 parity
  gaps between the managed-files twins (e9d6-13-report.md).
- INCIDENT (relayed by M6-Polish from 38dc-09, not in this scope): the
  deploy/ syntax, build and drift steps of check.yml always pass on the
  frozen tree. Follow-up.
- e9d6-13 published its report as a private artifact by side effect:
  https://claude.ai/code/artifact/9028057c-e56a-4f16-8fe4-83a98ddc6c20

## Open questions (RFI format)

RFI 38dc-13-1: Should the bash `scripts/aitools` stay a full entry point on Windows?
It runs on Windows from the dashboard-serve SessionStart hook and sources
aitools-lib.sh, so bash logging, read_menu_choice and the relay are reached
on Windows; the logging and menus .sh suites are its only tests there.
Suggest: make it a forwarder to `pwsh -File aitools.ps1` before the lib loads
(as aitools-install.sh does), then guard those suites (why: one runtime per
platform, as the commander's rule asks).

RFI 38dc-13-2: Keep the ACL-deny cases (deploy-harness, skills-legacy, rules-fanout) on Windows?
They replace chmod SKIPs with 22 PASS lines matching the Linux goldens; not
yet run on the elevated CI runner (a probe falls back to SKIP).
Suggest: yes (why: Windows failure-path coverage that did not exist).

RFI 38dc-13-3: hh.sh, bootstrap.sh, init-hh-hooks.sh, analyze-session.sh never run on Windows (e9d6-01).
Suggest: guard analyze-session.sh and hh.sh in a follow-up, keep bootstrap.sh
exempt with its own refusal, delete init-hh-hooks.sh with the git hook (why:
the exemption rows say "rationale unrecorded").
