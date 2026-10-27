# S3-M3Lead plan: finish M3 (one owner, stable key for machine identity)

**Intent**: **Purpose**: Split the remaining M3 work into missions sized for one
agent each, with order, dependencies, file ownership, the PR each one fixes or
opens, and the merge order. **Scope**: fixes to open PRs #79, #80, #82, #83;
batches B5, B8a-c, B9, B10; the M3 logging / script-standards audit (commander
decision 3). NOT M2. NOT PR #81 (mission DIFF-UX). **Audience**: S3-M3Lead's
delegates (shared brief, read in full), Session Commander 10cf255a-c, Jose.

## 1. State verified 2026-10-22 (gh pr list, git worktree list)

PRs are stacked on one line; each branch contains the one below it:

```
main <- #84 fix/m3-review2-fixes            (worktree m3fix)
     <- #79 feature/m3-b3b-installer-config  (worktree m3inst)
     <- #80 feature/m3-b2-lib-wrappers       (no worktree: create m3wrap)
     <- #82 feature/m3-b6-user-init          (worktree m3lib)
     <- #83 feature/m3-b4-setup-user-claude  (worktree m3claude; on #80, not on #82)
#78 docs/m2-tree-user-repo (worktree m3docs) -- docs only, independent
#81 fix/review-diff-display (DIFF-UX, not ours): owns aitools-lib display code
    and tests/managed-files. Do not edit those regions.
```

All open PRs: CI green, MERGEABLE. Review: Review3 (S3-Profile-Review3-pr79-80-82.md)
found #80 B1+M1, #82 M1+M2, #79 5 minor. #83 and #84 have no posted review.

## 2. Commander decisions (2026-10-22) binding on every mission

1. `--alias <new>` without a terminal creates the profile. An alias whose
   profile carries a different machine's `machine.id` is refused, unless the run
   is interactive and the user confirms. Registration never silently overwrites
   another machine's id (#82 M2).
2. PENDING: cached config alias (config.json `machineAlias`) -> profile without
   `machine.id`: keep today's behaviour (ask on a terminal, ERROR without one)
   behind a one-line switch (a single named variable/constant at the top of the
   code path, documented in a comment), so flipping to "register silently" is a
   one-line change.
3. `aitools user init` renders its run summary (summary file created before the
   user block, shown before returning), and all M3 code is audited for logging
   against script-standards.md, reference/script-standards-detail.md,
   reference/logging.md and fixed: structured levels, write_summary on every
   path, warnings/errors counted, no silent failures, deploy.jsonl coverage,
   the relative repos path regression.
4. Dotprofile writes auto-commit and push (N-Q2). D-TS13 reversed (bare exit 2
   = abort). Native resolver only (scripts/aitools-profile.sh/.ps1; the S5 plan's
   aitools-profile.js text is superseded).

5. (added 2026-10-22, via SC) Profiles keyed by the raw machine id:
   `profiles.<machineId>` replaces `profiles.<alias>`; the human-readable name
   becomes a field inside the profile; tool exceptions at
   `profiles.<machineId>.toolExceptions`; config.json fields, decision record
   wording, user-repo.md (R18) adjusted; live dotprofile migrated with a backup,
   committed and pushed (N-Q2).
6. (added) `aitools user init` scaffolds profile.json when the dotprofile has
   none (identity + this machine's profile under its id), commits and pushes.
7. (added) config.json is generated from profile.json by deploy-harness
   (mission HARNESS owns scripts/deploy-harness.*), which calls
   setup-user-config.sh/.ps1 as the single writer. Writer interface: stated by
   S3-M3-Install (report + PR #79 "Interface" section); any change is reported
   to SC.

Effect on sequencing: S3-M3-Register was redirected (before shipping its guard)
to produce the re-key design (S3-M3-Register-keydesign.md). Decision 1's guard is
re-expressed for id keys (a name already used by another id's profile is refused
unless interactive confirm). Implementation batches (resolver, lib, writer,
user init, setup-user-claude) follow that design. Migration of the live
dotprofile happens only after the code reads both shapes and is merged/deployed
(no flag day: already-deployed code reads the live file).

## 3. Missions

| Phase | Mission | PR / branch | Owns (only these code files + named test) | Depends on |
|---|---|---|---|---|
| 1 | S3-M3-LibFix | push to #80 `feature/m3-b2-lib-wrappers` | scripts/aitools-lib.sh, scripts/aitools-lib.ps1 (wrapper section only), tests/profile/test-lib.sh | -- |
| 1 | S3-M3-Install | push to #79 `feature/m3-b3b-installer-config` | scripts/aitools-install.sh/.ps1 (Step 5 + its logging), scripts/setup-user-config.sh/.ps1, tests/profile/test-config.sh | -- |
| 1 | S3-M3-Register | DONE: re-key design only (abd5bde on #82) | -- | -- |
| 1b | S3-M3-JsonRename (design batch 1) | opens new PR `feature/m3-rekey` (stacked on #82) | scripts/aitools-json.pl/.ps1, tests/profile/test-profile.sh | design |
| 2 | S3-M3-Resolver (design batch 2) | push to `feature/m3-rekey` | scripts/aitools-profile.sh/.ps1, tests/profile/test-profile.sh | JsonRename |
| 2 | S3-M3-LibKey (design batch 3) | push to `feature/m3-rekey` (after merging #80 head) | aitools-lib.sh/.ps1 wrapper section, tests/profile/test-lib.sh | LibFix, Resolver |
| 2 | S3-M3-ConfigKey (design batch 4) | push to `feature/m3-rekey` (after merging #79 head) | setup-user-config.sh/.ps1, tests/profile/test-config.sh | Install, Resolver |
| 3 | S3-M3-UserInit (design batch 5 + decision 3 summary + decision 6 scaffold) | push to `feature/m3-rekey` | scripts/aitools, scripts/aitools.ps1 | LibKey, ConfigKey |
| 2 | S3-M3-Claude (+ design batch 6) | push to #83 `feature/m3-b4-setup-user-claude` | scripts/setup-user-claude.sh/.ps1 | LibFix (batch 6 part after LibKey) |
| 2 | S3-M3-B8a | new PR `feature/m3-b8a-consumers` from #80 branch | setup-user-settings.sh/.ps1, setup-user-skills.sh | LibFix |
| 2 | S3-M3-B8b | new PR `feature/m3-b8b-consumers` from #80 branch | setup-user-skills.ps1, setup-user-cursor.sh/.ps1 | LibFix |
| 2 | S3-M3-B8c | new PR `feature/m3-b8c-consumers` from #80 branch | scripts/check-lib.sh/.ps1, scripts/ait-harvest.py | LibFix |
| 3 | S3-M3-B5a | new PR `feature/m3-b5-build-deploy` from #83 branch (merging #90-#92 heads) | scripts/build-deploy.sh (embed aitools-profile.sh/.ps1 into deploy/, dotprofile from entry point, review L8 PS1 blocks, smoke-run of a generated script), scripts/check-pre-push.sh/.ps1 step 7 (H5: pass temp dotprofile via AITOOLS_USER_REPO_PATH; trigger regex incl. aitools-profile.*) | Claude; B8a/b/c done (#91 #92 #90 must merge with/after B5a) |
| 4 | S3-M3-B5b (design batch 7) | push to B5a branch or re-key PR | build-deploy embedded lookup by id, scripts/profile-check.js | B5a, LibKey |
| 5 | S3-M3-Migrate | dotprofile direct push (N-Q2) | live profile.json (backup first) | re-key PR merged to main and pulled on both machines |
| 3 | S3-M3-Docs | new PR `docs/m3-b9-docs` + dotprofile direct push (B10) | protected docs R13, R18, R19 (approved text only), dotprofile profile.json meta.intent (R23) | UserInit |
| 4 | S3-M3-Audit | read-only; PR comments | none | all above |

setup-user-hooks.sh/.ps1: deferred to M6 (S5 plan B8). X-B1 (toolExceptions writer,
N-Q1 a): landed in #76 + #80 wrappers; Audit confirms. X-B4 (MDM deploy/setup-user-config):
after M3 B8 and M2 B3, outside this mission. X-B2/X-B3: definition not found in the
packet sources; Audit reports where they are defined, if anywhere.

### Shared contract (LibFix produces, every consumer reads)

LibFix renames every result global of the profile/dotprofile/tool-exception
wrappers to one lib prefix (bash `AITLIB_*`, e.g. `AITLIB_USER_REPO_PATH`,
`AITLIB_PROFILE_FILE`, `AITLIB_MACHINE_ALIAS`; PowerShell `$script:AitLib*`, e.g.
`$script:AitLibUserRepoPath`), initialises them only inside the functions (no
top-level assignment in the lib), and lists the final names in a "Contract" section
of its PR body and in its hand-back. Consumers copy the result into their own
local variable right after the call. A consumer that needs a different name records
a "Contract change" section in its PR body.

## 3b. State changes during the mission

- 2026-10-22T20:45Z/20:46Z Jose merged #78 and #79. #79 carried #84's commits, so
  #84 now has only a merge commit over main: recommend closing #84 as landed.
- S3-M3-Install's #79 fixes shipped as fix-forward PR #89
  (fix/m3-b3b-installer-review3, from main). Writer interface: #89 body.
- Re-key PR is #86 (feature/m3-rekey, stacked on #82).
- Install open Q1: relay helpers (child console -> deploy.jsonl) move into
  aitools-lib in the LibKey batch, so deploy-harness reuses them.

- Writer contract change for HARNESS (batch 4, #86 e1743ec): pass
  `--machine-id <key>` / `-MachineId <key>` (old `--machine-alias` /
  `-MachineAlias` accepted one release; both = ERROR `bad arguments`);
  config.json gains `machineId`, `machineAlias` display-only; at most one ACTION
  row for re-key/unregistered advice; exit 0/1 (never 2), no prompts, env/dry-run
  unchanged. #86 must not merge before batch 5 (user init re-keys 2.1 profiles).

## 4. Merge order (for Jose)

#84 -> #79 -> #80 -> #82 -> re-key PR (immediately after #82: it resolves #82 M1/M2) -> #83 -> B8a/B8b/B8c (any order) -> B5 -> B9 docs.
#78 any time (docs only); #81 any time, then rebase anything that touches
aitools-lib display code. Every stacked PR is opened with base `main`; after a
lower PR merges, its diff shrinks to its own commits.

## 5. Per-mission rules

- Every delegate reads the packet (SC-mission-packet.md) and this file in full.
- Each mission runs its own independent reviewer delegate, which posts its verdict
  on the PR with `gh pr review <n> --comment|--request-changes --body-file`.
- Isolated HOME for any run of setup scripts / build-deploy (#86).
- Outputs: `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/<NAME>/` in the
  delegate's worktree, committed on its branch.
- Final response to S3-M3Lead: 10 lines max + report path + PR URL.
