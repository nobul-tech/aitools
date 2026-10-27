# S3-Handoff2-S2 session state audit (session 10cf255a-c, 2026-10-21/22)

Author: S3-Handoff2-S2 (Intelligence), for S3-Handoff2. Read-only audit, written 2026-10-22 (local) /
2026-10-23 UTC. Worktree audited: `.claude/worktrees/ho10cf` at origin/main 8a9dcb5.
"MF" = mission folder `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/` on 8a9dcb5.
PR facts come from `gh pr list/view -R nobul-tech/aitools` (run during this audit) unless a file:line is given.
Times are GitHub `mergedAt` (UTC).

## 0. Findings the handoff must not miss (read first)

1. **PRs #74 and #75 were merged, but NOT into main.** #74 (base `fix/registry-paths`, merged 2026-10-22T04:24:16Z, merge commit 66e680f) and #75 (base `feature/user-level-skills`, merged 04:24:26Z, f61d6fc) were merged into their stacked base branches after those bases had already merged to main (#71 merged 04:10:06Z). `git merge-base --is-ancestor` exits 1 for both against 8a9dcb5. Effect on main today: the 7 governance skills are still in `.claude/skills/` (tool-ops, tool-eval, tool-registry, harvest, incident, glossary, frameworks), `shared/skills/aitool-ops/` and `shared/skills/aitool-eval/` and `.claude/rules/aitool-ops.md` still exist, `scripts/check-skill-levels.py` (pre-commit step 21) and `shared/README.md` do not exist (`git ls-files` on 8a9dcb5), and `MF/S3-Layout/` (S3-Layout-follow-ups.md, S3-Layout-design-web-skills.md) is absent from main (only on branches layout-b/layout-c). SD-8-ext, S2L-QA, R-S2L5 retargeting, E-paths-PRb, T-Q9 and incidents #113/#123/#124 depend on this. The dotprofile `claude/rules/delegation.md` was repointed to `/tool-ops` (dotprofile 2f2e0a9, PR #75 body), but `/tool-ops` is not user-level on main.
2. **The main checkout `/Users/new-jose/repos/aitools` is 105 commits behind origin/main** (`git rev-list --left-right --count main...origin/main` = `0 105`; HEAD 638d3ee). Rules loaded from it are pre-session versions.
3. **Commander approval of drafts happened outside the repo record.** PR #96 (M3 drafts) was merged by nobul-jose at 01:58:10Z with no comments and no reviews (`gh pr view 96 --json comments,reviews` = empty). The only written approval evidence found: worktree h2-draftsh commit 95b9805 body "Why: commander approval 2026-10-22 (S3-Harness2 launch decisions)". Branches `docs/m3-approved-drafts` / `docs/m3-approved-intents` (worktrees h2-draftsm3, h2-draftsm3b) are applying M3 rows; their approval text is unknown.
4. **No incident status was updated for any fix the session's PRs claim** (section 1E/metrics). Every #87-#145 entry is `open`.
5. `MF/S3-Profile/S3-Profile-Review3-pr79-80-82.md` (cited by S3-M3Lead-plan.md:25 and PR #89 body) exists only as an **untracked file in worktree m3lib**; never committed anywhere (`git log --all -- "*S3-Profile-Review3*"` empty).

## 1A. Completed work (merged PRs of this session, #54-#96)

PRs #50-#53 (merged 2026-10-21T02:54-04:03Z) belong to the prior session 360aa8f3-8 (#53 = its handoff). #72 is a GitHub issue (opened 2026-10-22T04:04:43Z: "PS1 managed-file review menu has no Windows test coverage"), not a PR.

| PR | What | Merged (UTC) | On main |
|---|---|---|---|
| #54 | /delegate: delegates read all project + user rules | 10-22 00:42:47 | yes |
| #55 | Records macOS verification of pre-push step 7; closes issue #32 (fixed earlier in 7aacdef) | 00:43:03 | yes |
| #56 | Hooks: adopt writes shared/hooks only, EOF-safe prompt, `sed -n` exemption (#80, #81, #82) | 00:43:38 | yes |
| #57 | Ledger: draft incident batch #87-#128 (drafts only) | 00:44:15 | yes |
| #58 | Gate: A/B review of tree rev 3, rev 4, review page (drafts only) | 00:44:44 | yes |
| #59 | tool-ops-claude-code: launch path decides delegate nesting (probe) | 00:44:58 | yes |
| #60 | standing-order-guard sed check back to enforce; hook rule drafts | 02:48:58 | yes |
| #61 | /scratch skill rewrite; scratch rule draft | 02:49:13 | yes |
| #62 | /delegate: lessons from parallel missions | 02:49:32 | yes |
| #63 | Managed-file spec drafts (SOURCE-truth model) | 02:49:50 | yes |
| #64 | Registry: Claude Code entry draft | 02:50:20 | yes |
| #65 | Files incidents #87-#145; closes #80-#82 | 02:50:32 | yes |
| #66 | Gate fix: tree rev 5, independent B-pass, review page (98 items) | 02:51:08 | yes |
| #67 | Records the 95 gate decisions in plans/tool-support-and-machine-profile.md | 03:40:04 | yes |
| #68 | Managed files: SOURCE is source of truth, one menu, per-field JSON review, no deploy state (claims #129, #130, closes issue #30) | 04:09:30 | yes |
| #69 | /tool-adopt at user level + approved glossary terms | 04:09:42 | yes |
| #70 | Apply approved drafts: hook + scratch rules, managed-file spec, Claude Code registry entry, /delegate reviewer posts verdict | 04:09:54 | yes |
| #71 | S2-Layout PR-a: path-reference check (step 20), registry repoints, tool-versions.json deleted, tool-registry.md deprecated | 04:10:06 | yes |
| #73 | M3 B1: native resolver aitools-profile.sh/.ps1 | 04:24:03 | yes |
| #74 | S2-Layout PR-b: 7 skills to user level, step 21 | 04:24:16 | **NO (merged into fix/registry-paths)** |
| #75 | S2-Layout PR-c: retire aitool-ops/aitool-eval cards | 04:24:26 | **NO (merged into feature/user-level-skills)** |
| #76 | M3 B1b: exception-get/set | 04:37:58 | yes (review fixes landed via #84) |
| #77 | M3 B3: setup-user-config.sh/.ps1, aitools-json.pl/.ps1 | 04:38:28 | yes (review fixes via #84) |
| #78 | Lands reference/tool-support-decision-tree.md (R1 rev 5 + decisions) | 20:45:19 | yes |
| #79 | M3 B3b: installers write config.json via setup-user-config | 20:46:29 | yes (merged before its review fixes; fixed forward in #89, S3-M3-Install-report.md:128-131) |
| #80 | M3 B2: aitools-lib profile/exception wrappers (AITLIB_* contract) | 10-23 00:37:47 | yes |
| #81 | Managed-file review diff readable (LOCAL->SOURCE, legend, colour) | 01:29:20 | yes |
| #82 | M3 B6/B7: user init registers this machine | 00:37:59 | yes |
| #83 | M3 B4: setup-user-claude uses the one resolver, literal-safe tokens | 01:13:31 | yes |
| #84 | Review fixes for #76/#77 | 00:37:10 | yes |
| #85 | /tool-ops, /aitool-ops read ~/.aitools/reference first | 01:29:35 | yes |
| #86 | M3 re-key: profiles keyed by machine id (batches 1-5) | 00:59:29 | yes |
| #87 | Cursor rules fan-out to ~/.cursor/rules/*.mdc | 01:30:14 | yes |
| #88 | deploy-harness.sh/.ps1 populate ~/.aitools | 01:29:56 | yes |
| #89 | Installer Step 5 fix-forward for #79 | 00:37:33 | yes |
| #90 | M3 B8c: check-lib + ait-harvest | 01:28:19 | yes |
| #91 | M3 B8a: settings + skills (sh) | 01:28:53 | yes |
| #92 | M3 B8b: skills (ps1) + cursor | 01:29:08 | yes |
| #93 | MDM: build-deploy generates deploy/deploy-harness.* | 01:57:36 | yes |
| #94 | S3-Harness brief + hand-back | 01:57:58 | yes |
| #95 | M3 B5a: deploy/ resolves dotprofile + machine profile on the target | 01:23:09 | yes |
| #96 | M3 protected-file drafts (no protected file changed) | 01:58:10 | yes |

Merge-order checks: the M3Lead gates held (#95 merged before #91/#92, S3-M3-B8a-report.md:5; #86 after batch 5, PR #86 body; #93 after #87/#88, S3-H-MDM-handback.md:3).

## 1B. Decisions approved but not yet implemented

Source: plans/tool-support-and-machine-profile.md (95 items; table rows at :38-:132) plus S3-M3Lead-plan.md section 2 (m3lead worktree, :28-:61).

| Decision | Approved text (file:line) | State on main 8a9dcb5 |
|---|---|---|
| SD-8-ext / S2L-QA (7 skills to user level, git mv) | plan :22, :52, :59 | **Implemented in #74 but not on main** (section 0.1) |
| T-Q9 (schema in /tool-registry skill) | :47 | Not done; tree says "once LAYOUT PR-b's move is on main" (PR #78 body) -- it is not |
| E-paths-PRb (retarget after PR-b) | :118 | Blocked by 0.1 |
| R2 tool-lifecycle.md rewrite | :65 | Not applied (no "update policy"/tree reference in .claude/rules/tool-lifecycle.md; last commit 6dc9c99) |
| R3 framework-tool-lifecycle.md | :66 | Not applied (draft differs +9/-55) |
| R5 / R6 tool-eval / tool-registry SKILL.md edits | :68-:69 | Not applied (drafts differ from .claude/skills targets) |
| R7 interactive-menus.md new intent | :70 | Rule text updated by #70, **no Intent block** (grep count 0) |
| R8 sources-of-truth.md new intent (+R-S2L5 fold-in) | :71, :89 | Not applied (no Intent block) |
| R11 registry schema 1.1 + meta.intent | :74 | Not applied (`"schemaVersion": "1.0"`, registries/tool-registry.json:4) |
| R12 framework-registry Tool lifecycle entry | :75 | Not applied (write only once every path exists) |
| R14 tool-lifecycle.mdc mirror | :77 | Not applied (draft differs +99/-30); mfd/interactive .mdc applied by #70 |
| R15 git-safety.md generated/ | :78 | Not applied (no "generated/" in .claude/rules/git-safety.md) |
| R16 script-standards-detail.md 6 edits | :79 | Not applied (only #88's "harness files" row landed) |
| R18 user-repo.md rewrite | :81 | Not applied; superseded draft = #96 row 3 |
| R19 claude-shared.md + dotprofile CLAUDE.md lines | :82 | Not applied; #96 rows 12-13; being edited in h2-draftsm3b (uncommitted) and live dotprofile claude/CLAUDE.md is dirty (+4/-2) |
| R20 deploy-paths.md | :83 | Not on main; applied in h2-draftsh commit 95b9805 (**unpushed**, no remote branch) |
| R22 code intents | :85 | Partly (adapted intents in #73/#76/#77/#80 flagged "please confirm"); #96 rows 6-8 pending |
| R23 meta.intent (config.json + dotprofile profile.json) | :86 | config.json half verbatim in #77; #96 rows 4-5 pending (row 4 waits for B10) |
| R25 setup-script intents (26 scripts) | :88 | Not applied (M2) |
| N-Q1 writer/reader exist; M2 callers (tool_* helpers, [k]eep) | :38 | Store done (#76/#80); M2 callers pending |
| D-TS10/11/12, T-Q1, T-Q4, T-Q5, N-Q6, T-Q12, C.1, E-registry-resolveBy, E-go-knownPaths | :39-:41, :46, :98-:99, :112, :103, :61, :119-:120 | Text in the tree (#78); **M2 code not started** (`write_platform_skip` / `gen-tool-specs` exist nowhere in scripts/, only in check-path-refs-allow.txt) |
| D-TS13 reversed at every launch site | :42 | Tree (#78), lib abort (#68), user init hooks step (#82). Installers still continue after exit 2 (no `exit 2`/`aborted` handling in scripts/aitools-install.sh; incident #87 open, incidents.json:1946) |
| P-Q1 identity.name/company | :48 | Not done (dotprofile; B10) |
| P-Q6 googleDrives under profiles.<machineId> | :106 | Deferred ("Later") |
| N-Q2 dotprofile writes commit+push | :110 | Done for exception-set/register/migrate/user init; **managed-file adopt does not commit/push** (S3-H-Core-handback.md:50, S3-Harness-handback.md:50) -- mission MF adopt (worktree mf-adopt) is fixing it, uncommitted |
| E-independence (re-run A and B independently) | :122 | B re-run independently (S3-GateFix-report.md:9, :100); independent A re-run: unknown |
| M3Lead decision 2 (cached alias -> silent register) | S3-M3Lead-plan.md:34-38 | Still PENDING; switch implemented at default 0 (S3-M3-UserInit-report.md:23) |
| M3Lead decision 7 (config.json generated by deploy-harness) | S3-M3Lead-plan.md:57-61 | deploy-harness calls the writer (#88); installer/sync hook-in (S3-H-Hookin) not done |
| S3-M3-Migrate (live dotprofile re-key) | S3-M3Lead-plan.md:89 | Not done; needs `aitools user init` on nobul-mac (`--claim`), approval page row 4 notes (S3-M3-Docs-approval-page.md:649-668) |
| S3-M3-Audit (read-only audit of all M3) | S3-M3Lead-plan.md:91 | Not run (unknown; no file found) |

Implemented and done (for contrast): R1 (#78), R4 (#69), R9/R10 + all G-* and C-14 (#69), R13 partial (#70 + #88 row), R17 void, R21 (#79), R24 (#65), REV5, N-Q3, P-Q2, P-Q3, P-Q4, P-Q5 (resolver), P-Q7 (#93 embeds setup-user-config in deploy/), P-Q12 (#82/#86), P-Q13 (#83), S2L-Q6/T-Q7/PR-a (#71), SD-8-reg (#88 copies registries), TA-* (#69), E-node-corrupt / E-merge-revert (#68), E-glossary-1 (#69), E-mdc-model (#70).

## 1C. Work products ready but not approved / not applied (protected drafts)

Comparison method: `S3-Handoff2-S2-drafts.sh` (numstat draft vs target on 8a9dcb5) and `S3-Handoff2-S2-grep.sh` (NEW-text probes), both in this scratch dir. "Applied" = identical or NEW text present.

Applied (no action): MF/S3-ScratchRule/...-drafts/shared/rules/scratch.md (identical), MF/S3-HooksFix/...-drafts/shared/rules/hook-lifecycle.md (identical), HooksFix hook-rollout .md/.mdc (applied by #70 with the single-line adjustment; diff +3/-2, +1/-1), SpecRewrite 5 drafts (applied by #70 with stated adjustments), RegCC evaluation (applied by #70, header edited), GateFix tree rev 5 (landed #78 with "Changes at landing"), GateFix tool-adopt (landed #69 with banner removed + new section). Superseded: S3-Hooks drafts (by HooksFix), S3-Gate rev 4 tree / ssd edit / tool-adopt (by GateFix), S3-Profile user-repo.md (by S3-M3-Docs row 3), S3-M3-B5a deploy-paths edit (adopted as #96 row 14), S3-M3-LibFix-tree-draft.md (folded into #96 row 11).

Pending (not on main):

| Draft (MF/...) | Target | Status / evidence |
|---|---|---|
| S3-M3-Docs/S3-M3-Docs-drafts/* (16 files, rows 1-17; table S3-M3-Docs-approval-page.md:41-59) | plans decision record, glossary.json, reference/user-repo.md, dotprofile profile.json meta, setup-user-config/aitools-profile/aitools-lib intents, mfd rule + .mdc, decision tree, claude-shared.md, dotprofile CLAUDE.md, deploy-paths.md, script-standards-detail.md, logging.md, tool-adopt SKILL.md | None on main (probes 0 hits). Being applied, uncommitted: h2-draftsm3 (M .claude/rules/managed-file-deployment.md, plans/..., registries/glossary.json), h2-draftsm3b (M aitools-profile.sh/.ps1, setup-user-config.sh/.ps1, shared/claude-shared.md). Rows 3, 4, 6 were marked "VERIFY after #86 batch 5" (approval page :61); batch 5 has since merged (#86). Approval: section 0.3 |
| S3-H-Core/S3-H-Core-drafts/reference/managed-file-deployment.md ("Deployed harness" subsection) | reference/managed-file-deployment.md | Not applied (no "Deployed harness" in target). Was blocked on #81, which merged 01:29:20Z. h2-draftsh shows `M reference/managed-file-deployment.md` uncommitted |
| S3-H-MDM/S3-H-MDM-drafts/dot-claude/rules/deploy-paths.md | .claude/rules/deploy-paths.md (+ .mdc not drafted, S3-H-MDM-handback.md:138) | Applied with #96 row 14 in h2-draftsh 95b9805, **unpushed**; staleness note held for re-approval, corrected draft MF/S3-H2-DraftsH/... on that branch (95b9805 body) |
| S3-H-Cursor/S3-H-Cursor-drafts/registries/tool-ops.json.cursor-entry.json + reference/tool-ops-cursor.md | registries/tool-ops.json, new reference/tool-ops-cursor.md | Not on main (no "cursor" key; target missing). Applied in h2-draftsh 76a4c45, unpushed |
| S3-H-ToolOps/S3-H-ToolOps-drafts/S3-H-ToolOps-intent-tool-ops-skill.md | .claude/skills/tool-ops/SKILL.md Intent | Not on main; applied in h2-draftsh e4e1dea, unpushed |
| PR #68 body draft: config-file-safety.md "Backup before overwrite" | .claude/rules/config-file-safety.md | Not applied: old sentence "Backup failures are non-fatal (warn and proceed)" still present (probe 1 hit); SourceTruth Q1 (S3-SourceTruth-report.md:64) |
| S3-Gate drafts for R2/R3/R5/R6/R14 (tool-lifecycle.mdc)/R15 and S3-GateFix ssd edit (R16), S3-Gate-row25-setup-script-intents.md (R25) | see 1B | Approved at the gate, not applied (wait for M2 / PR-b) |
| Intent drafts in reports/PR bodies: aitools-json.pl/.ps1 intents marked `DRAFT` in the files (PR #77; `DRAFT` present in scripts/aitools-json.pl), resolver migrate intent (S3-M3-Resolver-report.md:111-113 = #96 row 7), lib section intent (#80 body), relay section intent (S3-M3-LibKey-report.md:84 = #96 row 8), setup-user-config intents (S3-M3-ConfigKey-report.md:70-77 = #96 rows 5-6), SpecRewrite optional reference Intent (S3-SpecRewrite-report.md:25) | scripts / reference | Not applied (relay Intent absent from aitools-lib.sh; migrate clause absent from aitools-profile.sh) |
| PR #54 follow-up: dotprofile claude/rules/delegation.md element 2 wording | dotprofile | Drafted "waiting on commander approval" (PR #54 body); draft location unknown; applied: unknown |
| PR #62 follow-up: tool-ops-claude-code.md item #25 (SendMessage) | reference/tool-ops-claude-code.md | Not drafted/applied: item #25 still says "SendMessage ... unavailable" (reference/tool-ops-claude-code.md:60); "Current version" still 2.1.81 (:17) |

## 1D. Investigations complete (findings recorded, no further research needed)

- Gate A/B review of tree rev 3 (MF/S3-Gate/S3-Gate-A-review.md, S3-Gate-B-review.md) and independent B-pass of rev 5 (MF/S3-GateFix/S3-GateFix-B-review.md).
- Scratch/harvester behaviour incl. S3-SR-8 long-name catch-up bug, worktree `.scratch` deletion (MF/S3-ScratchRule/S3-ScratchRule-findings.md; report :63-:71).
- Cursor user-rule location and loader (MF/S3-H-Cursor/S3-H-Cursor-research.md; handback :13-:20). Live canary NOT run (handback :22-:29).
- Claude Code registry provenance (MF/S3-RegCC/S3-RegCC-report.md, -Check-report.md).
- Re-key design (MF/S3-M3-Register/S3-M3-Register-keydesign.md; batches 1-6 done, 7 partial, 8 = #96 drafts, keydesign.md:272-283).
- Delegate nesting / Workflow agents / HOME refusal probe (PR #59; incidents #139-#140).
- Pre-push step 7 macOS verification (MF/S3-Path32/S3-Path32-verification.md).
- Managed-file spec consistency (MF/S3-SpecRewrite/S3-SpecRewrite-consistency.md, 34 rows).

## 1E. Open threads (what is needed)

1. **Re-land #74/#75 on main** -- new PR(s) from layout-b (ed1b75c) / layout-c (2375fea) heads rebased on main; expect conflicts with #85 (edited `.claude/skills/tool-ops/SKILL.md` and `shared/skills/aitool-ops/SKILL.md`, S3-H-ToolOps-handback.md:15-16) and with #71's step numbering. Needs: commander go-ahead; then aitools run on every machine (PR #74 "ACTION after merge").
2. **Merge PR #97** (S3-M3Lead plan; open, created 01:59:21Z, body "Commander-directed").
3. **HARNESS-2 running**: S3-H-Hookin (worktree h2-hookin: clean, no commits) -- its blockers (#80, #82, #83, #88, #89) are all merged; constraints at S3-Harness-handback.md:19-24. Rules manifest / retired-rule pruning (h2-manifest: uncommitted M deploy-harness.sh/.ps1, tests/deploy-harness/test-deploy-harness.sh; S3-Harness-handback.md:43). Approved drafts (h2-draftsh: 3 commits unpushed + uncommitted reference/managed-file-deployment.md).
4. **S3-H-Claude** (setup-user-claude fan-out + tests/rules-fanout/) not started; needs commander answer to **Q1** "should project `.claude/rules` reach user level at all?" (S3-Harness-handback.md:37-42); 17 always-apply Cursor rules load in every chat under ~ (S3-H-Cursor-handback.md:72-73). Will conflict with mf-adopt (edits setup-user-claude.*).
5. **M3-FINISH running**: mf-nomach pushed b5292fd (`--no-machine`, remote branch exists, **no PR yet**; caller change "S3-MF-Runner passes the flag" not done -- commit body); mf-adopt uncommitted (aitools-lib.*, setup-user-claude.*, new tests/managed-files/test-adopt-push.*); mf-audit and mf-inc clean, no commits.
6. **Dotprofile**: live repo has uncommitted `claude/CLAUDE.md` (+4/-2) and `sessions/.DS_Store`; 825aed4 (2026-10-23T01:59:05Z) committed "regenerated deploy/ and profile.json from recent aitools runs" -- whether deploy/ now matches main's build-deploy is unknown. B10 migration pending (1B).
7. **Open questions awaiting commander** (each has a suggested answer in its file): Harness Q2-Q6 (S3-Harness-handback.md:43-47: retired rules, MDM fresh endpoint, 2.2 MB payload vs Jamf/Intune limits, Windows repos path `C:\repos\` vs `%USERPROFILE%\repos`, body markers); M3-Docs Q1-Q4 (approval page :65-:74); UserInit Q1-Q3 (:102-:106, Q1 answered by mf-nomach); SourceTruth Q1-Q5 (:62-:68); RegCC Q1-Q5 (:77-:82, partly decided in #70); SpecRewrite Q1-Q14 (decided in #70 except Q9/A1 wording); ScratchRule Q2 rule name (decided: kept scratch.md + pre-push narrowing, #70); B5a Q2-Q3 (:113-:117); ConfigKey Q2 (:82); H-MDM Q1-Q5 (:113-:129); N-Q6 scope (PR #78 follow-up).
8. **Unfiled INCIDENT markers** (not in incidents.json; next id #146): S3-Harness-handback.md:49-60 (11), S3-M3-Docs-approval-page.md:76-109 (7), S3-M3-UserInit-report.md:94-100 (5), S3-M3-Resolver-report.md:121-126 (4), S3-M3-LibKey-report.md:92-95 (2), S3-M3-ConfigKey-report.md:85-88 (2), S3-M3-Claude-report.md:77-81 (3), S3-M3-B5a-report.md:107-111 (3), S3-M3-B8a-report.md:82-83 (1), S3-M3-B8c-report.md:108-113 (1), S3-M3-Install-report.md:156-158 (1), S3-M3-JsonRename-report.md:65-69 (2), S3-M3-LibFix-report.md:128-130 (2), S3-DiffUX-handback.md:39-45 (2), S3-SourceTruth-report.md:49-60 (5), S3-SpecRewrite-report.md:45-53 (7), S3-RegCC-report.md:67-75 (7), S3-GateFix-report.md:85-91 (5), S3-ScratchRule-report.md:61-71 (9), S3-HooksFix-report.md:68-71 (2), S3-Incidents-report.md:34-36 (2), PR #61/#68/#71/#85 follow-ups. Mission mf-inc (`docs/mf-incidents`) may be filing these: unknown (no commits yet).
9. **Never-independently-reviewed code**: #89 commit 2f189a0 (S3-M3-Install-report.md:154); #69 (PR #69 "No independent reviewer delegate"); #58 A/B were one agent (PR #58 Not run).
10. **Windows never executed** for any session PR (every PR "Not run"); Windows paths UNVERIFIED (MachineGuid, Git Bash pwsh branch, generated .ps1).
11. **Rebuild of the dotprofile deploy/** after merges is the commander's (S3-Harness-handback.md:16; PR #95 Not run).

## 2. Dependency graph / parallel groups

```
[A] Re-land #74/#75 ─┬─> T-Q9, R5/R6 retarget (E-paths-PRb), R8/R-S2L5, incidents #113/#123/#124
                     └─> dotprofile delegation.md /tool-ops citation becomes true
[B] Approved-draft apply: h2-draftsh (push+PR) ; h2-draftsm3 / h2-draftsm3b (commit+PR)
        └─> S3-M3-Migrate / B10 (user init --claim on nobul-mac; dotprofile CLAUDE.md dirt resolved first)
                └─> dotprofile profile.json meta (row 4), P-Q1 identity fields
[C] HARNESS-2: S3-H-Hookin (unblocked)  ║  rules manifest (h2-manifest)  ║  S3-H-Claude (needs Q1)
        Hookin also owns the installer relay-helper switch (S3-M3-LibKey-report.md:51, :88)
[D] M3-FINISH: mf-nomach -> caller passes --no-machine (user init) ; mf-adopt (N-Q2 adopt push) ; mf-audit ; mf-inc
[E] M2 tool support (not started): R2/R3/R11/R12/R16/R25 + D-TS10..12, T-Q1/4/5, N-Q6 ; depends on [A] for T-Q9
```

File-ownership collisions to manage: mf-adopt and S3-H-Claude both touch `scripts/setup-user-claude.*`; mf-adopt touches `aitools-lib.*` (also used by Hookin's relay switch); h2-manifest edits `scripts/deploy-harness.*`, whose section headings are cut points for build-deploy's MDM generator (S3-H-MDM-handback.md:38-43 -- rewording a heading fails the build); h2-draftsm3b and mf-nomach both edit `scripts/setup-user-config.*` (intent header vs `--no-machine`) -- rebase needed.

Parallel now: [A], [B], [C-Hookin], [C-manifest], [D]. Serial: B10 after [B]; S3-H-Claude after Q1 and after mf-adopt merges; M2 after [A].

## 3. Harvest notes (reusable scripts)

Tracked in MF on main (candidates for `/harvest review`):
- MF/S3-GateFix/S3-GateFix-render-review-page.py (JSON review page renderer with `--help`/`--check`; supersedes MF/S3-Gate/S3-Gate-render-review-page.py).
- MF/S3-HooksFix/harness/S3-HooksFix-guard-smoke.sh (standing-order-guard smoke, 40 cases on bash 5 and 3.2 per PR #70) -- candidate for tests/hooks/; S3-HooksFix-report.md:62 says the earlier S3-Hooks harnesses were lost.
- MF/S3-HooksFix/S3-HooksFix-apply-drafts.sh (draft-to-target copier; one-shot).
- MF/S3-SourceTruth/S3-SourceTruth-blocks/apply-edits.pl, apply-lib.pl, spec-sh.tsv, spec-ps1.tsv (verbatim old/new block application -- the plan-execution pattern), review-json.js.

Untracked, in worktree `.scratch/` only (never harvested -- S3-SR-4; lost on worktree removal):
- m3drafts and h2-draftsm3 `.scratch/session-*/check-old.pl` (verifies every OLD block of a draft matches its target once; reusable for every protected-draft batch).
- incidents87 `.scratch/session-S3-Incidents/{build_batch,apply_batch,validate}.py` (incident batch build, round-trip-safe apply, id validation; relevant to #122).
- m3b5 `.scratch/session-B5a/{verify,edge,step7-test}.sh` (cross-machine deploy/ equivalence harness).
- m3b8a `.scratch/session-B8a/smoke.sh` (suggested as tests/profile/test-callers.sh, S3-M3-B8a-report.md:66), m3b8c `.scratch/session-B8c/{test-checklib.sh,test_harvest_bom.py}` (suggested promotion, S3-M3-B8c-report.md:117).
- m3lib: MF/S3-Profile/S3-Profile-Review3-pr79-80-82.md (untracked review record, section 0.5).
This audit's own scripts (S3-Handoff2-S2-*.py/.sh in .scratch/session-ho2/) are one-off probes.

## 4. Top 3 to close

1. **Re-land #74 and #75 on main** (section 0.1). Highest leverage: it unblocks SD-8-ext, T-Q9, R5/R6, step 21, three incidents, and makes the dotprofile's `/tool-ops` citation true.
2. **Finish the approved-draft apply and push it** (h2-draftsh is 3 commits ahead with no remote branch; h2-draftsm3/-m3b uncommitted), then B10 dotprofile migration. Record the approval text in the repo (PR comment or decision record), since #96 carries none.
3. **Sync the incident ledger with the code**: re-verify, then update status/correctiveAction for the incidents session PRs claim to fix (#129, #130 by #68; #84, #93, #102, #114, #115, #116, #122 by #71; #74 by #73; #75, #77, #97 by #82/#86; #76, #78, #95, #98, #109, #110 by #83/#95; #99 by #83; #111 by #90; #144 by #60/#70; #145 by #61/#70), and file the unfiled markers from 1E.8 starting at #146.

## 5. Metrics

- Session PRs #54-#97: 43 (44 numbers minus issue #72). Merged: 42. Merged and on main: 40. Merged but not on main: 2 (#74, #75). Open: 1 (#97).
- Incidents filed this session: 59 (#87-#145, PR #65; S3-Incidents-report.md:3). Closed this session: 3 (#80, #81, #82; incidents.json:3432-3451). Highest id: 145 (unique, contiguous; next #146).
- Registry now: `incidents` array 138 = 122 open + 16 planned (open by severity: 1 critical, 32 high, 60 medium, 29 low); `closed` array 7 (13, 14, 52, 53, 80, 81, 82). All of #87-#145 have status `open` and `correctiveAction` null except #113, #128, #139, #140, #144 (notes only); #144's correctiveAction still says "PR #60 (open)" although #60 merged 02:48:58Z.
- Incidents claimed fixed (fully or in part) by session PRs but still open: 23 (#74-#78 and #84 were filed by the prior session; list in section 4 item 3). Whether each claim holds in code is not verified here.
- Protected drafts pending: #96 = 17 rows / 16 files; plus H-Core reference content sources, H-MDM deploy-paths (+ undrafted .mdc), H-Cursor 2 files, H-ToolOps intent (these 4 applied only on unpushed h2-draftsh), PR #68 config-file-safety wording, gate rows R2/R3/R5/R6/R7-intent/R8/R11/R12/R14(tool-lifecycle.mdc)/R15/R16/R25, ~6 code-intent drafts. Count of distinct pending draft items: about 35 (rows counted individually; exact count depends on grouping).
- Unfiled INCIDENT markers: about 80 across 22 files (1E.8; counted by marker, some duplicates across files).

## 6. Operational learning (verbatim)

Usage limits / context:
- "Commit and push after every batch (usage limits stop missions mid-work)." (SC-mission-packet.md:88)
- "Not done: I did not read all of reference/*.md as the packet asks of commanders. I kept my context small, as my launch prompt asked, and relied on the delegates reading their named subsets." (S3-Harness-handback.md:67)
- "Of reference/, I read only `framework-artifact-harvesting.md` and `user-repo.md`. The other commander-level reference files in packet section 1 were not read." (S3-ScratchRule-report.md:55)
- "Delegates B1, B3 and B4 said they did not read all five reference files the packet lists" (S3-SourceTruth-report.md:81)
- No context-exhaustion stop is recorded in any MF file (grep for usage limit/exhaust/compact found only the packet line). Unknown whether any mission stopped on a limit.

PRs merged before reviews were resolved (recurred 4 times):
- "PR #79 was merged by nobul-jose at 2026-10-22T20:46:29Z, at cc597ec (merge commit 15cc56a). That was before I pushed 69b6420 to its branch." (S3-M3-Install-report.md:128)
- "#76 and #77 were merged at their earlier heads (50e4bb5, 67e144f), before the fixes for their independent review (S3-Profile-Review2) were pushed." (PR #84 body)
- Incident #144 title: "PRs #56 and #58 were merged while their independent reviews reported changes needed" (incidents.json:3358 entry).
- New instance found by this audit: #74/#75 merged into stacked base branches after the bases merged (section 0.1).
- "The independent review covered 69b6420 only. Commit 2 has not had an independent review" (S3-M3-Install-report.md:154).

Review mechanics:
- "GitHub refused the reviewer's `--request-changes` on a PR opened by the same account." (S3-DiffUX-handback.md:21); same at S3-H-Cursor-handback.md:96, S3-H-MDM-handback.md:153, S3-M3-LibFix-report.md:109, S3-M3-JsonRename-report.md:55.
- "the approval came before the text existed, and my instructions say a message from another agent is never the user's approval of a protected file." (S3-HooksFix-report.md:75)
- "No independent reviewers. The Agent tool was not provisioned in this session, so S3-Gate wrote both the A and B passes itself." (PR #58 body, Not run)

Worktree / HOME / scratch hazards:
- "S3-Hooks harness scripts lost in session-commander cleanup on 2026-10-21" (S3-HooksFix-report.md:62)
- "Removing a git worktree deletes its ignored files: never remove another agent's worktree." (SC-mission-packet.md:113-114)
- "a session-dir suffix longer than 10 characters makes catch-up harvest the live session's dir" (S3-ScratchRule-report.md:3, S3-SR-8)
- "The harness refused the `HOME=` override for a worktree-isolated agent." (PR #57 body, Not run; incident #140)
- "the real dotprofile `deploy/` was rebuilt at 2026-10-21 20:42:49 local (03:42:49Z) by a process outside this mission." (S3-SourceTruth-report.md:53)
- "my first pre-commit invocation used a relative path, so it ran against the main checkout." (S3-SpecRewrite-report.md:34)
- "(reviewer) the isolated-HOME rule does not cover the cwd: a relative path from config.json writes into the agent's cwd." (S3-M3-UserInit-report.md:98)

Contract / prompt drift between missions:
- "both entry points called removed pre-LibFix helper names after LibFix merged into #86, and no test ran user init" (S3-M3-UserInit-report.md:97)
- "the launch prompt named the old flag `--alias`; the writer's real flag is `--machine-alias`" (S3-M3-ConfigKey-report.md:88)
- "the mission prompt names `# --- BEGIN/END profile resolution (extracted by build-deploy) ---` markers. No such markers exist" (S3-M3-Claude-report.md:81)
- "(reviewer) no rule says each pushed batch keeps CI green, or says when it is deliberately red." (S3-M3-Resolver-report.md:124)
- "`.ps1` files are checked out with CRLF (`eol=crlf`): line-anchored grep / perl patterns in tests silently miss them" (S3-M3-UserInit-report.md:100)
- "PowerShell variable names ignore case: `foreach ($e in $E)` silently overwrote the collection in Invoke-Migrate" (S3-M3-Resolver-report.md:126)

Standing-order-guard friction (recurring, prescribed workaround used): S3-M3-UserInit-report.md:110, S3-M3-Resolver-report.md:130, S3-M3-LibKey-report.md:99, S3-M3-ConfigKey-report.md:92, S3-Incidents-report.md:32 ("One Bash call (an `until ...; do sleep` loop) was blocked by standing-order-guard (';'). I used Monitor instead").

## Unknowns (stated, not guessed)

- Exact text and scope of the commander's 2026-10-22 approval of #96 and the harness drafts.
- Whether the dotprofile deploy/ committed in 825aed4 matches main's current build-deploy output.
- Whether an independent A-pass re-run (E-independence) happened.
- Where the PR #54 delegation.md draft lives and whether it was applied.
- What missions mf-audit and mf-inc will produce (no commits yet).
