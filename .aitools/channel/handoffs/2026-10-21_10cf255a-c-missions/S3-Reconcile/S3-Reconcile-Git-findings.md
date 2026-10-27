# S3-Reconcile-Git findings: open PRs #97-#116 and main since 480b901, against the reconciliation target files

**Intent**: **Purpose**: Give S3-Reconcile, per open PR and per recent main commit, what changes in the deployment-area target files, how the PRs overlap and conflict, their review state, and a merge/apply order that needs the fewest rebases. **Scope**: `gh pr view/diff -R nobul-tech/aitools`, `git log/show/merge-tree` on origin refs (fetched 2026-10-26), RELEASE_NOTES.md. NOT transcripts (S3-Reconcile-Trans). No repo file, PR or comment was changed. **Audience**: S3-Reconcile.

Delegate: S3-Reconcile-Git (read-only). Date 2026-10-26. origin/main = **8e18ad4** at fetch (one commit past the brief's 8e490d7: "Add MDM-PKG, ANSWER-1A and ANSWER-1B mission reports", channel files only).

## Summary (5 lines)

1. All 19 open PRs (#97-#106, #108-#116) have base `main`, are MERGEABLE/CLEAN against 8e18ad4, and have CI green (#102: 6 SUCCESS + 1 NEUTRAL). #107 is CLOSED (superseded by 480b901). No PR has a GitHub APPROVED review: every verdict is an agent COMMENTED review or a comment under the `nobul-jose` login.
2. Five stacks hide inside "base main": #100 < #110, #111; #98 < #113, #114, #115, #116; #103 < #112, #113, #115, #116; #108 < #114; #113 < #115 < #116. Merge with merge commits (as #93-#96 were) so the stacked heads keep their commits. Squash-merging a parent forces a rebase of every child.
3. Only two textual conflicts exist among all 19: #116 x #112 (`.github/workflows/check.yml`, add/add of CI steps) and #116 x #106 (`scripts/aitools-install.sh/.ps1`, the run-id block). If #116 merges last, one rebase of #116 resolves both. The order was simulated in a scratch clone: 18 clean merges, and only #116 conflicts.
4. The protected target docs are changed directly by only #99 (deploy-paths.md/.mdc, reference/managed-file-deployment.md), #101 (managed-file-deployment rule twins, user-repo.md, glossary, plan, script-standards-detail, decision tree) and #106 (interactive-menus twins, reference/managed-file-deployment.md "[x]abort", plan T-Q3, decision tree). Their hunks do not overlap. Every other doc change is a draft in a mission folder (#99 held paragraphs, #100/#110/#111 Manifest, #111 MDM, #103 Adopt, #108/#114 Fix6, #105 row 8). These drafts are anchored to text that #99, #101, #111 and 8e490d7 change, so they must be applied after those merge.
5. 8e490d7 makes pre-push step 7 run on every push. That makes the #99 held deploy-paths correction ("triggers only on the `shared/` ones") false before it lands. #111 Edit 3 rewrites the same bullet ("embedded as base64" moves to `deploy/deploy-harness.payload`). So the held paragraph, the optional `.claude/hooks` addition and #111 Edits 1-3 should be redrafted as one batch after #99 and #111 merge, for both deploy-paths.md and the .mdc.

---

## 1. Per-PR table

Columns: head SHA, merge state on 2026-10-26, review verdict(s) and blocking items, target files touched (main line ranges, from `gh pr diff`; `-a,b +c,d` = old start,len / new start,len).

| PR | Branch / head | State | Verdicts (all agent text) | Target files touched |
|---|---|---|---|---|
| #97 Preserve M3-LEAD plan | `docs/m3-lead-plan` 4d3f43d (merge-base 638d3ee, older than 8a9dcb5) | MERGEABLE, CLEAN, 7/7 green | none | none (one channel file) |
| #98 `--no-machine` | `feature/mf-config-no-machine` fae7d62 | CLEAN, green | S3-MF-NoMachine-Review (comment 02:18Z): **approve, 0 B / 0 M / 3 m / 4 n**; fae7d62 addresses it | none of the list (setup-user-config.sh/.ps1, tests) |
| #99 HARNESS approved drafts | `docs/harness-approved-drafts` df10361 | CLEAN, green | S3-H2-DraftsH-Review (review 02:18Z, on 9e70ca6): **NO BLOCKING FINDINGS**; re-verify of df10361 (comment 02:21Z): no blocking. Held: 2 paragraphs (deploy-paths staleness note, reference/managed-file-deployment closing paragraph); the `.mdc` twin was marked "please confirm" (commander "1d) approved", 2026-10-26, per the common brief) | `.claude/rules/deploy-paths.md` -24,6 +24,21 (new "MDM run order"), -36,6 +51,9 (build-deploy env note), -46,29 +64,67 (duplication table: 3 pairs -> 1, pure-extract list, deploy-harness extract+embed paragraph, auto-embedded bullets, step-7 sentence at new :123); `.cursor/rules/deploy-paths.mdc` -11,6 +11,12, -20,7 +26,7, -29,13 +35,30 (same content, long lines); `reference/managed-file-deployment.md` -398,6 +398,25 (new "### Deployed harness (`~/.aitools`)" subsection with table). Also cross-platform.md, tool-ops SKILL.md, tool-ops.json, tool-ops-cursor.md (not on the list) |
| #100 rules manifest | `feature/harness-rules-manifest` 699eba8 | CLEAN, green | S3-H2-Manifest-Review 02:22Z: **BLOCKING** (.ps1 removed a retired `[`/`]` rule with no backup); 02:30Z: **APPROVE-EQUIVALENT**, 161edd0 fixes it and findings 2, 3, 4, 8; 3 optional low parity notes | `scripts/deploy-harness.sh` -21,9 +21,15 (header), -150,8 +156,10, -190,6 +198,10 (`add_source` records labels), -341,6 +353,166 (new section "5b. Rules manifest ... retired rules"), -365 / -381 (manifest skip, summary log); `.ps1` the same at -22, -145, -184, -314 +322,161, -331, -340. Drafts: S3-H2-Manifest-drafts for the managed-file-deployment rule, reference/harness.md and reference/managed-file-deployment.md (section 3) |
| #101 #96 M3 rows | `docs/m3-approved-drafts` 583436e | CLEAN, green | S3-H2-DraftsM3-Review 02:21Z: **NON-BLOCKING** (every protected change is the approved text or an allowed deletion). Carries the re-approval drafts A-J (user-repo.md) and glossary "profile" (S3-AnsB) | `.claude/rules/managed-file-deployment.md` -47,8 +47,8 (Template interpolation, Machine profile selection: one resolver, no first-profile fallback), -100,9 +100,9; `.cursor/rules/managed-file-deployment.mdc` -27,8 +27,8, -56,7 +56,7; `reference/user-repo.md` -1,88 +1,363 (rewrite: Intent, resolution, schema), -100,44 +375,6 (Config Schema removed), -157 / -167 / -192 / -216 / -230 +495,15; `registries/glossary.json` -440,12 +440,12 (machine alias, machine profile); `plans/tool-support-and-machine-profile.md` -20,7, -30,6 +30,9 (two commander decisions), -103,9 +106,9 (P-Q6 note); `reference/script-standards-detail.md` -85,7 +85,10 (lib table rows), -179,6 +182,14 (OK->WARN promotion), -249,6 +260,11 ("Library-style tools" paragraph); `reference/tool-support-decision-tree.md` -53, -306, -396, -561 +563,16, -603, -614 +623,34, -736 |
| #102 M3 incidents | `docs/mf-incidents` fa90df0 | CLEAN; 6 green + 1 NEUTRAL | S3-MF-Incidents-Review 02:21Z: **changes needed (small), 0 B / 1 M / 5 m / 4 n**, fixed in fadbbb0; re-check (0b6b00e) 02:28Z: changes needed, 1 M, fixed in 27ea6bc; re-check (87284ea) 05:14Z: **changes needed, 1 M** ("which baseline the entries cite: open PR branches, not main"), author says fa90df0 fixes it (05:15Z). **No re-check of fa90df0 is recorded.** | **none**: `registries/incidents.json` is not changed. The PR carries a batch + apply script (section 6) |
| #103 dotprofile adopt push | `fix/mf-dotprofile-adopt-push` 945deb5 | CLEAN, green | S3-MF-Adopt-Review 02:37Z: **APPROVE** at c05fec8 ("approve once the macos job is green"; it is green now) | `scripts/aitools-lib.sh` -1001,12 +1001,117 (new `dotprofile_commit_push`, adopt path), -1541,9 +1646,12; `.ps1` -895,12 +895,139, -1467,9 +1594,12; `scripts/setup-user-claude.sh` -364,29 +364,9 and `.ps1` -394,32 +394,9 (private commit+push block removed). Draft: S3-MF-Adopt reference/managed-file-deployment.md (Caller Responsibilities) |
| #104 M3-FINISH audit | `docs/mf-audit` 526d48c | CLEAN, green | none | none (findings file) |
| #105 M3 intents rows 7, 12 | `docs/m3-approved-intents` dfa1776 | CLEAN, green | S3-H2-DraftsM3b-Review 02:29Z: **NON-BLOCKING, 0 B / 4 minor** | none of the list (aitools-profile.sh/.ps1 intents, shared/claude-shared.md). Draft: row 8 relay intent for aitools-lib.sh/.ps1 (section 5) |
| #106 deploy-harness hook-in | `feature/harness-hookin` 3de51d6 | CLEAN, green | S3-H2-Hookin-Review 02:31Z (bbc3cbb): **NOT BLOCKING** (finding 1 a non-blocking bug; 2-9 follow-ups/nits); follow-up 02:33Z (0dea75f): finding 1 fixed, verdict stays not blocking. 3de51d6 (abort docs, 2026-10-26): only the author's comment (S3-AbortDocs, 22:23Z); **no independent review of 3de51d6** | `.claude/rules/interactive-menus.md` -56,8 +56,19 (Abort), -119,8 +130,9 (profile-mirror note); `.cursor/rules/interactive-menus.mdc` -20,7 +20,7; `reference/managed-file-deployment.md` -172,9 +172,19 ("[x]abort" table); `plans/tool-support-and-machine-profile.md` -94,7 +94,7 (T-Q3 note); `reference/tool-support-decision-tree.md` -62, -437 +437,10, -448,41 +452,55, -704,18 +722,20; `scripts/aitools` -1089 (+`deploy_abort`), -1105/-1130/-1148/-1169/-1186 (deploy-harness first in `deploy_configs`, relayed, abort stop), -2133/-2150/-2207 (exit-2 handling); `scripts/aitools.ps1` -151 +151,25, -175, -203, -2065, -2082, -2148; `scripts/aitools-install.sh` -4, -123 +124,9 (run id export), -239 +243,47 (`run_harness_step`), -535,34 +580,7 (bin step removed), -639 +657,21 (Step 8b); `.ps1` -3, -50 +51,9, -176 +180,35, -433,31 +466,7, -563 +572,20 |
| #107 handoff | `docs/handoff-10cf255a-c` 0d51c6c | **CLOSED** 2026-10-26T22:02Z: "Superseded: committed directly to main as 480b901 (channel exception, commander order 2026-10-26)" | -- | -- |
| #108 resolver/JSON A-6..A-9 | `fix/mf-audit-profile-json` dbcc61a | CLEAN, green | S3-MF-Fix6-Review 02:49Z: **approve-worthy, 0 B / 4 non-blocking** | none of the list (aitools-json.pl/.ps1, aitools-profile.sh/.ps1). Draft: S3-MF-Fix6 reference/script-standards-detail.md (section 5) |
| #109 B8 consumer rows | `fix/mf-audit-consumers` 1692959 | CLEAN, green | S3-MF-Fix4-Review 02:44Z: **APPROVE-equivalent, no blocking** | `scripts/setup-user-cursor.ps1` -271,11 +271,11, -286,12 +286,15 (dry-run cursor cli row); `.sh` -349,13 +349,14. Also check-lib.*, setup-user-skills.ps1 |
| #110 Cursor user rules only | `feature/harness-cursor-user-rules` adcf4a7 (contains #100) | CLEAN, green | S3-H2-Cursor-Review 02:45Z: **NO BLOCKING FINDINGS**; re-verify 02:50Z: no blocking | #100's deploy-harness hunks, plus `scripts/setup-user-cursor.sh` -7,16 +7,26 (header), -382 / -400 / -446 +467,58 / -473 +541,109 / -509 / -554 / -581 +737,81 (prune against the manifest) / -641; `.ps1` -6 +6,27, -376, -394, -422, -457 +478,53, -473, -487,152 +559,323. Drafts: S3-H2-Cursor tool-ops-cursor.md, tool-ops.json (not on the list) |
| #111 MDM follow-ups | `feature/harness-mdm-followups` 8caa79e (contains #100) | CLEAN, green | S3-H2-MDM-Review 03:00Z: **BLOCKING B1** (coverage regression of the truncation guard); re-verify 03:11Z: **NO BLOCKING FINDINGS** (N6 non-ASCII paths); 03:14Z: 8caa79e fixes N6 | `scripts/build-deploy.sh` -397 +397,21 (`extract_markers`), -1680 +1695,22, -1699, -1862, -1876, -1902, -1926,78 +1961,157, -2014, -2035, -2047, -2076 +2183,73, -2114, -2164 +2304,50, -2187, -2294 +2467,28 (size limits); `scripts/deploy-harness.sh` -12 (`# --- BEGIN scope`), -20 +21,34, -50, -97 +115,16 (`config bootstrap check` markers, `--skip-config`), -114, -128 (dotprofile lookup markers), #100's hunks, -411 (`# --- END body`); `.ps1` the same. Drafts: S3-H2-MDM deploy-paths.md Edits 1-3, harness.md (section 2) |
| #112 setup-user-claude rows, build-deploy | `fix/mf-audit-claude-build` 52821bd (contains #103 via merge 547079c) | CLEAN, green | S3-MF-Fix5-Review 03:15Z: **CHANGES-REQUESTED, one small blocking B-1** (bash read-failure check could not fire); re-verify 03:20Z (18d6646): **APPROVE-equivalent**, B-1 and N-1 fixed | #103's lib and setup-user-claude hunks, plus `scripts/build-deploy.sh` -42 (blog_warn/blog_error plain), -192 / -199 (child console), -544 / -585 / -594 / -609 / -800 / -904 / -1248 (`EMBED_FINALLY_PS1`), -2216 +2244,22 (check); `scripts/setup-user-claude.sh` -90,22 +90,11 (hostname from resolver), -216, -228 +218,23 (dry-run rows); `.ps1` -168, -243 +243,24 |
| #113 lib runner result lines | `fix/mf-lib-runner-result` 2419d23 (contains #98, #103) | CLEAN, green | S3-MF-Runner-Review 03:27Z: **approve with minors, 0 B / 0 M / 2 m / 5 n** | #98 + #103 hunks, plus `scripts/aitools` -189,52 +189,20 (ui_profile_run -> lib runner), -904, -999, -1007, -1018 (`--no-machine`); `scripts/aitools.ps1` -801,36 +801,20, -1610, -1623, -1638; `scripts/aitools-lib.sh` -144,30 +144,46, -177, -185, -211 (`_aitlib_profile_run`); `.ps1` -124,22 +124,33, -148 |
| #114 setup-user-config A-10/A-11 | `fix/mf-audit-config` f8e8fc0 (contains #98, #108) | CLEAN, green | S3-MF-Fix3-Review 04:07Z: **approve-worthy, 0 B / 4 non-blocking** | none of the list (setup-user-config.*, aitools-profile.*, aitools-json.*) |
| #115 lib relay ERROR rows | `fix/mf-lib-relay` 2ae798a (contains #113) | CLEAN, green | S3-MF-Relay-ReviewA 04:14Z: **approve with minors, 0 B / 0 M / 1 m / 4 n**; 2ae798a addresses it | #113's hunks, plus `scripts/aitools-lib.sh` -339 (`resolve_machine_profile` ACTION), -473 / -482 (`run_child_relayed [--summary-tool TOOL]`), -575,46 +618,96 (relay rows: "script failed (exit N)" / "aborted (exit 2)"); `.ps1` -269, -413, -493 +523,56, -516 |
| #116 installers on lib relay | `fix/mf-installer-relay` 0e0a3f7 (contains #115) | CLEAN, green | S3-MF-Relay-ReviewB 04:55Z: **changes requested, 1 major (M-1: Git Bash user init hides the hooks review prompt), 4 m, 4 n**; author 05:05Z: fixed in 1605d6e; re-check 05:14Z: **approve with minors**, M-1 resolved | #115's hunks, plus `scripts/aitools` -903, -1015,40 +989,66 (user init children relayed), -1058, -1342 / -1354 / -1505 (pre-lib argument errors, A-15), -1752 (A-14); `scripts/aitools.ps1` -502 (A-15), -1623, -1638,36 +1641,24, -1678; `scripts/aitools-install.sh` -120,67 +120,32 (its JSONL override removed, run id), -194 +159,64 (`resolve_repos_dir`), -418, -498; `.ps1` -47, -60,65 +54,88, -129, -334, -384, -813 (run id cleared); `scripts/aitools-lib.sh` -526 (`_aitlib_jsonl_init`); `.ps1` -444 / -454 (`Write-JsonlRecord`) |

**Not touched by any open PR** (directly): `.claude/rules/aitools-workspace.md`, `reference/harness.md`, `.claude/rules/deploy-paths.md` other than #99, `shared/cursor-rules/user-rules.md` (draft only, in #99), `.cursor/rules/cursor-rule-parity.mdc`, `reference/cursor-practices.md`, `scripts/setup-user-settings.*`, `scripts/check-pre-push.*` (changed on main by 8e490d7), `registries/incidents.json`, `RELEASE_NOTES.md`, `reference/smoke-test-pattern-detail.md`, `scripts/deploy-harness.*` other than #100/#110/#111, and `prompt_json_field_review` / `Prompt-JsonFieldReview` (its `[x]abort    : stop the run` text is unchanged on every branch: `scripts/aitools-lib.sh:2376`, `.ps1:2359` on main; the same text sits at shifted lines on every branch).

## 2. #99 vs #111 Edit 3 vs #110 vs #100 (deploy-paths, managed-file-deployment, harness.md)

None of #100, #110 or #111 changes a protected doc directly. Their doc text is all drafts. The overlaps are between those drafts and the files that #99 (and #101, #106) write.

### 2.1 `.claude/rules/deploy-paths.md` (line numbers = the file as #99 writes it)

| Anchor | Written by | Drafts that edit it | Order / re-anchoring |
|---|---|---|---|
| "MDM run order", 2nd paragraph `deploy-harness` ships with ... (:35-40) | #99 | #111 S3-H2-MDM Edit 1 (payload file beside it, `OK config.json n/a (no bootstrap)` exit 0, `--skip-config`) | #99 first. The draft states "Base: the file as PR #99 writes it". OLD matches verbatim |
| deploy-harness **extract + embed** paragraph (:95-100) | #99 | #111 Edit 2 (body markers `# --- BEGIN/END ... ---`, `extract_markers`, two replaced spans) | #99 first. OLD matches. After #111 the "section headings are build cut points" warning (handoff D.4) no longer holds; the markers are the cut points |
| "What IS auto-embedded", last bullet "Every `scripts/deploy-harness.*` source ..." (:118-121) | #99 | #111 Edit 3 (the tail "embedded as base64 at build time" becomes "written as base64 to `deploy/deploy-harness.payload` ... sha256 ... Intune limits"); #99's held DraftsH paragraph, inserted **directly after this bullet** ("Because of that last bullet, ... `deploy/deploy-harness.*` stale ..."); DraftsH "Optional, same bullet": add `.claude/hooks` after `shared/hooks` | **All three edit the same bullet or the line after it.** Apply them as one edit after #99 and #111 merge. Re-anchor: (a) the `.claude/hooks` insertion is in the bullet's first line, which Edit 3's OLD does not include, so they compose. (b) The held paragraph must be rewritten. After #111 the stale artifact is `deploy/deploy-harness.payload` (plus the scripts' embedded sha256), not `deploy-harness.*` inline, and after 8e490d7 step 7 runs on every push. The DraftsH "New (proposed)" sentence "Pre-push step 7 triggers only on the `shared/` ones; it does not yet trigger on ..." is **now false**. Suggested redraft: "Because of that last bullet, a change to any of those directories makes the dotprofile `deploy/deploy-harness.payload` stale until `build-deploy.sh` runs again; pre-push step 7, which runs on every push, fails until it does." |
| `check-pre-push` step 7 sentence (:123-125) | #99 | none | Accurate after 8e490d7 (it describes the rebuild and dry run, not the trigger) |

### 2.2 `.cursor/rules/deploy-paths.mdc` (lines as #99 writes it)

The .mdc uses long single lines. #111's draft says "The same two edits apply to .cursor/rules/deploy-paths.mdc", but it has three edits, and its OLD blocks are wrapped the way the .md is, so they do not match the .mdc text. Re-anchoring is needed:
- Edit 1 replaces all of :18.
- Edit 2 replaces the first part of :51 (the line continues with "`setup-user-config`, `aitools-profile` and `aitools-json` are copied as-is ...", which must be kept).
- Edit 3 replaces the tail of :60.
- The held paragraph and the `.claude/hooks` insertion go on and after :60.

The twin is approved ("1d) approved", per the common brief). Whether twins are required at all is still the parity ambiguity (section 9 and the last INCIDENT marker).

### 2.3 `reference/managed-file-deployment.md` (lines on main 8e18ad4)

| Section (main lines) | Written by | Drafts | Notes |
|---|---|---|---|
| "### [x]abort" (:171-178) | #106 3de51d6 (-172,9 +172,19) | none | No overlap with #99 (clean merge, simulated). After #116, user init's hook exit 2 also writes ERROR `claude hooks` `aborted (exit 2)` (#116 `scripts/aitools:1015-1051`), which the 3de51d6 table does not mention. Re-verify after #116 |
| "## Caller Responsibilities", N-Q2 bullet (:255-~262) | -- | #103 S3-MF-Adopt draft (library `dotprofile_commit_push`, result table) | Apply after #103. Commander 2026-10-26: "Dotprofile pushes from a non-main branch are an ERROR". This draft says nothing about branches, and #102's draft incident #165 ("bare `git push` pushes the current branch") covers the gap. The draft needs a line once the code does it |
| "## Content Sources" table, `User rules` row (:389) | -- | #100 Manifest Edit 1 | OLD matches main and #99 (unchanged there) |
| Content Sources table, `Machine profile` row (:393) "hostname match, then first profile" | -- | **none** | Stale against SD-7 and against #101's rule text "no match = ERROR, never another machine's profile". #101 fixes only the rule twins. `INCIDENT:` (see "INCIDENT markers") |
| new "### Deployed harness (`~/.aitools`)" (#99 :398-422) | #99 | #99 held S3-H-Core closing paragraph, "directly after its table (before the `userRepoPath` resolution paragraph)" | After #110 the Cursor fan-out takes user-level rules only, and FAN-PLAN will change setup-user-claude. Hold the redraft until FAN-PLAN ships, or say "Cursor (user-level rules only)" |
| "### Script-owned JSON (no review)" (:518-534) | -- | #100 Manifest Edit 2 (new paragraph after the table) | No collision |

### 2.4 `.claude/rules/managed-file-deployment.md` and `.mdc`

#101 rewrites the "Template interpolation" and "Machine profile selection" bullets (:50-51 / .mdc :30-31). The #100 Manifest rule draft replaces the next line, "- **Rules**: additive deploy from ..." (:52 / .mdc :32). That is an adjacent line, but a string-replace applies cleanly after #101. The draft names only the `.md`; the .mdc :32 has the same bullet and needs the same edit. The draft says "the fan-out consumers ... back up and remove the copies of retired rules", but setup-user-claude has no fan-out yet (FAN-PLAN).

### 2.5 `reference/harness.md` (main lines)

- #111 MDM draft: the `config.json` sentence (:109-110), adding `--skip-config` and `n/a (no bootstrap)`.
- #100 Manifest Edit 1: the "No deletion" bullet (:156-158).
- #100 Manifest Edit 2: a new "### Rules manifest and retired rules" subsection before "## Cross-References" (:167).

The three do not overlap; both drafts say to apply on top of whichever version is current. One detail: the Manifest text says retired rules are backed up with `backup_file()`. Since 161edd0, the .ps1 copies with `-LiteralPath` itself instead of calling Backup-File. Since 9923a3c, Backup-File is literal anyway, so 161edd0's workaround could go back to Backup-File (optional simplification).

### 2.6 Which must merge first

1. **#99** before any deploy-paths/.mdc or Deployed-harness draft (#111 MDM Edits 1-3 are based on it; the held paragraphs anchor in it).
2. **#100** (then #110, #111) before the Manifest drafts, since they describe its code. **#101** before the Manifest rule draft (adjacent line).
3. **#111** before the deploy-paths bullet batch (Edit 3 + held paragraph + `.claude/hooks`).
4. **#103** before the Adopt draft. **#103, #106 and #116** before the row 8 relay intent (#105 draft). On main today the lib relay has no consumer; #106 makes the installer Step 8b and the sync loop consumers (deploy-harness is the child), and #116 makes installer Step 5 and user init consumers. The common brief says "after #103 and #106"; I suggest after #116 as well, because #116 changes who consumes the relay.

## 3. PR #106 (`feature/harness-hookin`)

- **bbc3cbb** (2026-10-22T19:20 -07:00): installer Step 8b runs deploy-harness relayed (`run_harness_step` / `Invoke-HarnessStep`). The installer's bin step is removed. deploy-harness becomes first in `deploy_configs` / `Deploy-Configs`, and setup-user-config leaves the list (the writer runs once per sync). Exit 2 = `[x]abort`: WARN `harness files|aborted by user`, summary, exit 2. Exit 1 = ERROR, continue. `bash -n` runs before the step so that a syntax error (bash exit 2) is not read as an abort. The body adds: "In `aitools install` the writer still runs twice (Step 5 bootstrap flags, then bare inside Step 8b)".
- **0dea75f** (2026-10-22T19:32): the PS1 abort line is logged under `[aitools]` (review finding 1).
- **3de51d6** (2026-10-26T15:23 -07:00, docs only): "Document the abort scope PR #106 implements". It states: exit 2 from deploy-harness stops the run (Step 8b; sync loop: summary, exit 2), and exit 2 from any other setup script is ERROR `script failed (exit 2)` and the run continues. Files: interactive-menus.md (Abort; profile-mirror note), .mdc twin, reference/managed-file-deployment.md "[x]abort" (table plus user init / bootstrap sentences), tool-support-decision-tree.md (D-TS13 row, 7.4 note, 7.5 launch sites, section 10 test matrix), plan T-Q3 note. It quotes the commander order 2026-10-26: "update the docs to match the current implementation of PR #106. lets keep functionality, update docs on whatever current state is".
- **prompt_json_field_review text: not changed.** #106 does not touch `aitools-lib.*`. 3de51d6 documents the mismatch instead: interactive-menus.md now says "(`[x]abort` ends `setup-user-settings` with exit 2. Despite the menu text, the run does not stop ...)". The S3-AbortDocs comment flags as INCIDENT: "the profile-mirror menu prints `[x]abort    : stop the run` (`prompt_json_field_review` ...) but under every runner the run continues with an ERROR row". Its second INCIDENT: a user abort in a `setup-user-*` script is reported as a failure, not as an abort.
- Interplay with #111: #111 adds `--skip-config` "for callers that already ran the writer, as `aitools-install` Step 5 does". **No PR wires it**: `git grep skip-config` finds it only on `feature/harness-mdm-followups`, and #106's Step 8b does not pass it. After both merge, `aitools install` still runs the writer twice. This needs a code follow-up.
- Interplay with #115/#116: after #115 the relay writes `aborted (exit 2)` rows (2ae798a n2). After #116, user init's hook exit 2 writes ERROR `claude hooks` `aborted (exit 2)` before "user init: aborted by user" and `return 2`. The 3de51d6 docs need one clause for that after #116 merges.

## 4. Main commits since 480b901 (author/committer "Jose <jose@nobul.tech>"; each body ends `Co-Authored-By: Claude Opus 5.5`)

| SHA | Time (-07:00) | Subject | Diff | Notes |
|---|---|---|---|---|
| 9923a3c | 10-26 15:01:28 | Use -LiteralPath in Backup-File and Backup-Dir | `scripts/aitools-lib.ps1` +15/-8 | With `-Path`, a `[ ]` name was a wildcard and got no backup while reporting success. Test-Path/Copy-Item/Remove-Item now use `-LiteralPath`, and pruning uses a literal prefix. Backup-Dir had the same fix. "Commander order 2026-10-26: fix directly on main, no PR." Tested macOS pwsh 7; test-managed-files.ps1 39/0. Not run: Windows. (It precedes 480b901 in time but is not covered by it; it is the parent of 480b901) |
| 480b901 | 15:02:14 | Add handoff 10cf255a-c and its relay entry | channel files | baseline named in the brief |
| 5976553 | 15:17:42 | Document the channel exception in CLAUDE.md | `CLAUDE.md` +8 | "Handoffs, relay.md and CLAUDE.md itself are committed directly to main from the main checkout (pull --ff-only, commit only those paths, push) ... Commander approval 2026-10-26, text approved in chat; CLAUDE.md added to the list by the commander." |
| 1af8851 | 15:40:16 | Add plans/ to the channel exception in CLAUDE.md | `CLAUDE.md` +2/-2 | "Commander decision 2026-10-26: the plans directory skips worktrees and PRs" |
| **8e490d7** | 15:42:57 | Run pre-push step 7 on every push | `reference/pre-push-checklist.md` +1/-1, `scripts/check-pre-push.sh` +5/-9, `.ps1` +5/-9 | See below |
| 8e18ad4 | 15:45:12 | Add MDM-PKG, ANSWER-1A and ANSWER-1B mission reports | 18 channel files | not in the brief (main moved past 8e490d7) |

**8e490d7 in detail.**
- `scripts/check-pre-push.sh`: removed `deploy_sources=$(echo "$PUSH_FILES" | grep -E '^(scripts/(setup-.*|build-deploy|aitools-lib|aitools-profile)\.(sh|ps1)$|scripts/aitools-json\.(pl|ps1)$|shared/)' || true)` and the `if [ -z "$deploy_sources" ]; then step_skip "7" ... "no deploy-relevant source changes"` branch. The chain now starts at `if [ -z "$USER_REPO_PATH" ] || [ ! -e "$USER_REPO_PATH/.git" ]; then step_skip "7" "deploy/ matches source" "userRepoPath not configured -- dotprofile deploy/ not verified"`, then `elif ! command -v node ...` WARN, as before.
- The header comment (:111-114 on main) now reads "On every push (commander decision 2026-10-26: step 7 always runs; it used to run only when a deploy-relevant source changed, which missed reference/, registries/, .claude/* and deploy-harness inputs), rebuild ...".
- `scripts/check-pre-push.ps1`: the same change, removing `$deploySources = @($pushFiles | Where-Object { $_ -match '...' })` and the `if ($deploySources.Count -eq 0) { StepSkip ... }` branch; the chain starts at the `userRepoPath not configured` skip.
- `reference/pre-push-checklist.md:40`: new text "Runs on every push (commander decision 2026-10-26 ...). ... A stale dotprofile `deploy/` is a FAIL: run `bash scripts/build-deploy.sh` and commit `deploy/` in the dotprofile repo. Skipped when `userRepoPath` is not configured; WARN when node (bash) or Git Bash (PowerShell) is missing."
- **Docs updated**: only pre-push-checklist.md.
- **Docs not updated / now stale**:
  - (a) #99's held DraftsH deploy-paths correction (§2.1); it is a draft, not on main.
  - (b) The never-filed step-7 trigger INCIDENT (S3-AnsA-Git §3) is now resolved in code. If it is filed, file it as closed with 8e490d7, or drop it.
  - (c) Known-failure notes in the packet section 4 and in PR bodies ("pre-push step 7 (dotprofile deploy/ stale)"). Every push from every PR branch now FAILs step 7 until the commander rebuilds the dotprofile `deploy/`.
  - `git grep "step 7|deploy-relevant|does not yet trigger"` on origin/main finds no other doc that describes the old trigger. The other hits are build-deploy.sh/check-lib/test comments about the step's temp copy, which are still true.
- The commit says "Verification (tested: macOS): bash -n and the pwsh parser pass ... Not run: Windows." No RELEASE_NOTES entry.

## 5. Drafts in PRs that the reconciliation must re-anchor (protected unless noted)

| Draft (branch:path) | Target | Anchor status |
|---|---|---|
| #99 `S3-H2-DraftsH-drafts/dot-claude/rules/deploy-paths.md.edit.txt` | deploy-paths.md + .mdc, after the deploy-harness sources bullet | needs a redraft (8e490d7, #111 Edit 3), §2.1 |
| #99 `S3-H2-DraftsH-drafts/reference/managed-file-deployment.md.edit.txt` | "Deployed harness" closing paragraph | needs a redraft after #110 and FAN-PLAN, §2.3 |
| #99 `S3-H2-DraftsH-drafts/shared/cursor-rules/user-rules.md.edit.txt` | user-rules.md:28 `C:\repos\` -> `%USERPROFILE%\repos\` | anchor holds (no PR touches the file) |
| #100/#110/#111 `S3-H2-Manifest-drafts/{dot-claude/rules/managed-file-deployment.md, reference/harness.md, reference/managed-file-deployment.md}` | §2.3-2.5 | anchors hold on main; the rule draft needs the .mdc twin; apply after #101 |
| #111 `S3-H2-MDM-drafts/dot-claude/rules/deploy-paths.md.edit.txt` (Edits 1-3) | deploy-paths.md as #99 writes it, plus the .mdc | .md OLD matches #99; .mdc needs re-anchoring, §2.2 |
| #111 `S3-H2-MDM-drafts/reference/harness.md.edit.txt` | harness.md:109-110 | holds |
| #103 (and children) `S3-MF-Adopt-drafts/reference/managed-file-deployment.md.edit.txt` | Caller Responsibilities N-Q2 bullet (:255) | holds; add the non-main-branch ERROR once the code does it |
| #105 `S3-H2-DraftsM3b-drafts/scripts/aitools-lib.sh.edit.txt` (row 8 relay intent) | aitools-lib.sh/.ps1 after the "log helpers ... PR #89" line (main :468 / :398 at 8a9dcb5; shifted by #103/#113/#115/#116 and 9923a3c) | redraft after #106 and #116 (both make the installers consumers, and deploy-harness a child) |
| #108/#114 `S3-MF-Fix6-drafts/reference/script-standards-detail.md.edit.txt` | "Logging overrides" table row + a new "### Library-style tools" section | **overlaps #101**, which adds a "Library-style tools" paragraph at script-standards-detail.md :260-264 pointing to `reference/logging.md` "Library-style tools". Applying Fix6 Edit 2 as drafted would define the term in two places. Merge #101 first, then fold Fix6 into the #101 paragraph or into logging.md. Draft incident #148 (#102) covers the same gap |

## 6. PR #102 (`docs/mf-incidents`)

- **Title is stale.** It says "#146-#161", but the batch now holds **#146-#170** (25 entries), added by 0b6b00e (S3-MF-Audit I-1..I-4 -> #162/#163) and 87284ea (final batch), and fixed by fa90df0. Ids and titles (from `S3-MF-Incidents-batch.json` on fa90df0):
  - 146 med: check-pre-commit step 13 and deploy-paths.md still treat setup-user-claude/cursor as duplicated deploy templates
  - 147 med: write_summary OK->WARN promotion vs ACTION pairing
  - 148 med: no logging contract for library-style tools
  - 149 low: lib result naming/scope contract only in a code comment
  - 150 med: JSON engines write numbers differently
  - 151 low: no stacked-batch CI-green rule
  - 152 low: lib resolver runner and register/migrate `via`
  - 153 med: isolated-HOME rule omits the cwd
  - 154 low: cross-platform-detail omits 3 traps
  - 155 low: scaffolded profile.json lacks meta.intent
  - 156 med: dirty profile.json + exception-set gives a wrong ACTION
  - 157 med: JSONL override example writes invalid JSON
  - 158 low: cross-platform.md and the aitools-json pair
  - 159 low: logging_init warning on stdout
  - 160 low: lib -> .ps1 bridge cross-language ambiguity
  - 161 med: decision tree documents pre-M3 interfaces
  - 162 med: logging.md does not define deploy.jsonl
  - 163 low: double counting of resolver errors
  - 164 med: adopt_managed_file copies into the dotprofile ...
  - 165 med: dotprofile auto-push runs a bare `git push` (current branch, earlier commits)
  - 166 low: JSON key-case behaviour undocumented
  - 167 med: setup-user-cursor `node not found` row
  - 168 low: resolver version comparison differs between bash and PS
  - 169 med: PS `New-Item -Force` returns $null
  - 170 med: PS profile function passes `--alias` as a plain string
- **Approval evidence: none from the commander.** The body says "drafted ... for your approval", "registries/incidents.json is not changed", and "Approval came first, so no direct write was approved for this batch" (precedent PR #57 drafts -> PR #65 applied after "items a-c"). The only commander words are quoted by the agent: the order 2026-10-22 "File the INCIDENT markers from the M3 reports (#146 onward) via the /incident process in one PR, after reading registries/incidents.json in full." All 6 comments are agent reviews or author replies. The last re-check (87284ea, 05:14Z) says "changes needed (small)", and no re-check of fa90df0 exists.
- **Conflicts on `registries/incidents.json`: none.** No open PR changes it (`gh pr diff` file lists, #97-#116). origin/main has 145 ids, max 145, unique (last changed by 0b1a224, PR #65), so the apply script's "registry max + 1 = 146" precondition holds today. Any other filing before #102 is applied (for example the parity marker or the other INCIDENT markers below) must take ids from #171, or #102's apply step refuses ("ids run in order from the registry max + 1").
- Relevance to commander decisions: #165 is the incident behind "Dotprofile pushes from a non-main branch are an ERROR" (2026-10-26). No open PR implements that rule: #103's `dotprofile_commit_push` is the code it would change.

## 7. Pairwise conflicts (`git merge-tree --write-tree`, git 2.54.0)

Scratch: `matrix.sh` (all 171 pairs that share a changed file, plus each PR against origin/main) and `simulate.sh` (sequential `--no-ff` merges in a throwaway clone at `.scratch/session-rcgit/sim-*`).

- **Every PR vs origin/main 8e18ad4: clean** (including the 9923a3c change to `aitools-lib.ps1` against the #103 stack).
- **Conflicting pairs (2):**
  - **#106 x #116**: `scripts/aitools-install.sh:124-133` and `.ps1:51-62`. #106 adds `export AITOOLS_RUN_ID` lines inside the installer's own JSONL block; #116 deletes that block (moved to the lib) and exports the run id at `aitools-install.sh:194-200` / `.ps1:126-132`. Resolution: take #116's side. #106's other `RUN_ID` / `$runId` uses are only inside the deleted block (`aitools-install.sh:147`, `.ps1:70`).
  - **#112 x #116**: `.github/workflows/check.yml:158-170` and `:337-343`. Both add CI steps at the same spot (`tests/claude-mdm/test-claude-mdm.sh` vs `tests/profile/test-install.sh`). Resolution: keep both.
- **Clean pairs that share files**:
  - #98 with #113/#114/#115/#116
  - #99 x #106 (reference/managed-file-deployment.md)
  - #100 with #110/#111; #110 x #111
  - #101 x #106 (plan, decision tree)
  - #103 with #112/#113/#115/#116
  - #105 x #108, #105 x #114 (aitools-profile.*)
  - #106 x #113, #106 x #115 (scripts/aitools, aitools.ps1)
  - #108 x #114
  - #109 x #110 (setup-user-cursor.*)
  - #111 x #112 (build-deploy.sh)
  - #112 x #113, #112 x #115
  - #113 x #114/#115/#116; #114 x #115/#116; #115 x #116
- **Simulations**:
  - (A) #116 before #112 and #106: #116 conflicts with check.yml.
  - (B) #116, then #112, then #106: two conflicts, on #112 and #106.
  - (C) the order below: **18 clean, and only #116 conflicts** (check.yml + aitools-install.sh/.ps1).
- **Semantic overlaps that merge cleanly but need a test run after both land**:
  - #111 + #112 (both rewrite build-deploy.sh: the MDM payload and markers vs the `EMBED_FINALLY_PS1` cleanup). Run tests/deploy-harness-mdm and tests/claude-mdm under an isolated HOME.
  - #106 + #115/#116 (#106's Step 8b uses `run_child_relayed`, whose signature and rows #115 changes; `--summary-tool` is optional, so the call stays valid). Run tests/hookin.
  - #106 + #111 (`--skip-config` not wired).
  - #109 + #110 (setup-user-cursor dry-run rows vs the prune rewrite).

## 8. Proposed merge order (the commander merges; agents never merge)

All bases are `main`, so nothing needs retargeting. Use **"Create a merge commit"** for every PR. The stacked heads share commits with their parents, so a merge commit keeps them identical, while a squash makes every child replay its parent's diff. Before each merge, confirm the base is `main` and the head SHA matches the table (handoff I: check bases).

| # | Merge | Why here | Doc batch slotted after it |
|---|---|---|---|
| 1 | **#97**, **#104** | records only; no file overlap | -- |
| 2 | **#99** | approved protected drafts; base for every deploy-paths / Deployed-harness draft | D-1: user-rules.md Q3 draft, if approved (anchor holds) |
| 3 | **#101** | approved #96 rows; base for the Manifest rule draft (adjacent line) and for Fix6 (script-standards-detail) | D-2: the A-J / glossary "profile" re-approval drafts (S3-AnsB), once approved |
| 4 | **#105** | approved intents; independent | -- |
| 5 | **#98** -> **#103** -> **#108** -> **#109** | parents of the M3-FINISH stacks; #109 independent | D-3 after #103: the Adopt draft (Caller Responsibilities); add the non-main-branch ERROR only when the code has it |
| 6 | **#112** | contains #103; must precede #116 (check.yml) | -- |
| 7 | **#100** -> **#110** -> **#111** | manifest, then its two children; #111 before the deploy-paths batch | D-4 after #110: Manifest drafts (rule .md + .mdc, reference User rules row + script-owned paragraph, harness.md edits 1-2). D-5 after #111: deploy-paths .md + .mdc batch (MDM Edits 1-3, the redrafted held paragraph, optional `.claude/hooks`), harness.md `--skip-config` edit |
| 8 | **#106** | after #111 so the `--skip-config` wiring follow-up can be one small PR; before #116 so #116 takes the single rebase | code follow-up: installer Step 8b passes `--skip-config` / `-SkipConfig` (writer runs once in `aitools install`) |
| 9 | **#113** -> **#114** -> **#115** | M3-FINISH stack (contains #98/#103, already merged) | D-6 after #114: fold the Fix6 draft into #101's Library-style paragraph / logging.md |
| 10 | **#116**, after **one rebase** (merge origin/main into `fix/mf-installer-relay` by its owner or a fresh delegate in its worktree, D-DEL4; resolve as §7; rerun tests/profile/test-install.sh, test-user-init.sh, tests/hookin) | the only PR that conflicts in this order | D-7: re-verify the 3de51d6 abort docs (user init row `aborted (exit 2)`). D-8: redraft the row 8 relay intent (#105 draft) against main. Then FAN-PLAN's setup-user-claude fan-out (every setup-user-claude toucher, #103/#112 and the stack carrying #103, has merged), then the #99 held Deployed-harness paragraph |
| 11 | **#102** | records (drafts); any time, but **apply** its batch (ids #146-#170) only after approval and before any other incident filing | ledger batch: apply #102, then file any new markers from #171 |

After the merges: the commander rebuilds and commits the dotprofile `deploy/` (8e490d7 makes every push FAIL step 7 until then), and a RELEASE_NOTES v0.74.0 entry folds in v0.73.3 (untagged: the newest tag is v0.73.2) and records 9923a3c, 8e490d7, the channel exception and the PRs above.

**Bases that are not main: none.** Stacked content: #110 and #111 contain #100's 4 commits; #112 contains #103 (merge 547079c); #113 contains #98 and #103 (merges ea6fda8, 53bc7b4); #114 contains #98 and #108 (merges 3a0711f, 518b233); #115 contains #113 (2b3e971); #116 contains #115 (27a3b15). #97's merge-base is 638d3ee (older), and it merges clean.

## 9. 03933a5 and "parity killed"

- **03933a5**: author and committer `Jose <jose@nobul.tech>`, 2026-03-13T16:48:26-07:00. Subject "Governance and compliance framework: design principles, gap governance, 30-skill plan (v0.54)". Body: "Three-layer governance model (prevention/detection/audit), ambiguity-as-defect principle, gap governance rule with JSON tracking, kill cursor rule parity, full implementation plan for 30 tool+process skills and hook specifications." Trailer: `Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>`.
- **What it changed** (10 files, +514/-71):
  - deleted `.claude/rules/cursor-rule-parity.md` (3 lines: "When modifying rules in `.claude/rules/*.md`, also update the corresponding `.cursor/rules/*.mdc` file (and vice versa). See the Rule Correspondence table in `@reference/cursor-practices.md`.")
  - documentation-standards.md: removed the "Cursor parity" bullet
  - CLAUDE.md: added "## Design Principles", including "**Separate tool harnesses**: Claude Code (`.claude/rules/`, CLAUDE.md) and Cursor (`.cursor/rules/`, agents.md) serve different purposes and are managed independently. No parity requirement."
  - also gap-governance.md (new), known-gaps.json (new, replacing .md), sources-of-truth.md, ROADMAP.md, plans/governance-and-compliance-framework.md, and RELEASE_NOTES.md +39
- It did **not** touch `.cursor/rules/cursor-rule-parity.mdc` or `reference/cursor-practices.md`, which still require parity (S3-AnsA-Git §5).
- **RELEASE_NOTES.md:1080-1095 verbatim** (origin/main):

```
| 3 | **`reference/known-gaps.json`** (NEW): Migrated 5 existing gaps from markdown to structured JSON with severity, type, created/updated dates. Replaces `known-gaps.md`. |
| 4 | **`plans/governance-and-compliance-framework.md`** (NEW): Full implementation plan — 30 skills (15 managed tools + 3 dependencies + 3 build tools + 9 process/workflow), hook specifications, permission strategy, edge cases, verification steps |

### Improvements

| # | Change |
|---|--------|
| 5 | **Cursor rule parity killed**: Removed `cursor-rule-parity.md` rule. Claude Code and Cursor are separate tool harnesses managed independently — no parity requirement. |
| 6 | **`documentation-standards.md`**: Replaced cursor parity bullet with gap-governance cross-reference; updated `known-gaps.md` → `known-gaps.json` |
| 7 | **`sources-of-truth.md`**: Updated protected files table — `known-gaps.md` → `known-gaps.json` with governance rule reference |
| 8 | **`ROADMAP.md`**: Added governance & compliance framework entry linking to plan |

### Files created

| File | Purpose |
|------|---------|
```

  The "parity killed" row is at :1087. The release header is at :1072 ("## v0.54 -- Governance and compliance framework (2026-03-13)"). :1104 "| `.claude/rules/cursor-rule-parity.md` | Replaced by \"Separate tool harnesses\" design principle |". :1107 "**Verified on:** Windows".
- **Who authored "parity killed"**: git records the author/committer as Jose, with a Claude Opus 4.6 co-author trailer. This is the same pattern as every agent commit in this repo: 2026 commits are authored "Jose", and agent text is marked by the trailer (S3-AnsB-GitHist provenance notes). The wording "kill cursor rule parity" / "Cursor rule parity killed" is therefore **agent text in a commit he authored**. Whether Jose ordered it or wrote those words is **unknown from git**. The transcript of 2026-03-13 (S3-Reconcile-Trans scope) would settle it. The principle was later removed from CLAUDE.md in b504c43 (2026-03-28), per S3-AnsA-Git.

## INCIDENT markers (not filed)

- `INCIDENT:` `reference/managed-file-deployment.md:393` (main and every branch) says machine profile fallback is "hostname match, then first profile", contradicting SD-7 (no first-profile fallback) and #101's rule text ("no match = ERROR, never another machine's profile"). No PR or draft fixes it.
- `INCIDENT:` `--skip-config` (#111) exists for "callers that already ran the writer, as `aitools-install` Step 5 does", but no PR passes it. #106's Step 8b runs the writer a second time in `aitools install` (#106 bbc3cbb body, "the writer still runs twice").
- `INCIDENT:` #111's deploy-paths draft says "The same two edits apply to .cursor/rules/deploy-paths.mdc", but it has three edits, and the .md-wrapped OLD text does not match the .mdc's single-line paragraphs.
- `INCIDENT:` #102's title and Summary say "#146-#161" while the batch is #146-#170, and its last re-check (87284ea) ended "changes needed" with no re-check of the fix fa90df0.
- `INCIDENT:` 3de51d6 (protected abort docs, 5 files) has no independent review; the only verdicts on #106 predate it (bbc3cbb, 0dea75f).
- `INCIDENT:` The #108/#114 Fix6 draft would add a second definition of "library-style tool" (script-standards-detail "### Library-style tools") beside #101's paragraph and `reference/logging.md` "Library-style tools" (no duplication, documentation-standards).
- `INCIDENT:` The #100 Manifest rule draft names only `.claude/rules/managed-file-deployment.md`, although `.cursor/rules/managed-file-deployment.mdc:32` carries the same "Rules" bullet. Its text also describes a setup-user-claude fan-out that does not exist yet.
- `INCIDENT:` (carried from S3-AnsA-Git) the parity record conflicts: 03933a5 / RELEASE_NOTES:1087 removed parity, but `.cursor/rules/cursor-rule-parity.mdc` and `reference/cursor-practices.md` still require it.

## Open questions (suggested answers)

1. Merge method: merge commits or squash? **Suggested: merge commits** for all 19. With squash, every stacked child (#110, #111, #112-#116, #114) needs a rebase after its parent.
2. Should #116 be rebased now, against today's main, or after #112 and #106 merge? **Suggested: after**, so that one rebase resolves both conflicts.
3. Should the deploy-paths bullet batch wait for #111, or should the held paragraph go in right after #99? **Suggested: wait for #111.** Otherwise the paragraph names `deploy/deploy-harness.*` and must be edited again a few merges later. It needs re-approval either way, because 8e490d7 made the proposed wording false.
4. The step-7 trigger incident that was never filed: file it as closed, or drop it? **Suggested: no incident.** Record 8e490d7 in the v0.74.0 release notes, and remove "step 7 does not yet trigger" from every redraft.
5. #102: fix the title and run one more re-check before merging? **Suggested: yes.** The re-check needs a fresh reviewer delegate posting on #102, because the last verdict was "changes needed". Apply the batch only after the commander approves it.
6. Row 8 relay intent: redraft after #103 and #106 (brief), or after #116 as well? **Suggested: after #116**, because #116 makes installer Step 5 and user init relay consumers.

## Method and sources

- `git fetch origin` (2026-10-26); `gh pr list --state all`; `gh pr view <n> --json number,title,state,baseRefName,headRefName,headRefOid,mergeable,mergeStateStatus,reviews,comments,statusCheckRollup,files,body,commits` and `gh pr diff <n>` for #97-#116.
- Scratch (`/Users/new-jose/repos/aitools/.scratch/session-rcgit/`): `dump-prs.sh`, `summarize.py` (hunk line ranges for target files), `grep-branches.sh`, `matrix.sh` / `matrix.log` (ancestry, merge-tree), `conflict-detail.sh`, `simulate.sh` (clone `sim-a/b/c`).
- `git show` on 9923a3c, 5976553, 1af8851, 8e490d7, 8e18ad4, 03933a5, 3de51d6, 0dea75f, bbc3cbb, 161edd0, 2ae798a; `git show origin/<branch>:<path>` for every draft quoted; `git grep` on origin/main and the PR heads.
- Read first: common brief, mission packet, handoff D.4 and I, S3-AnsA-Git, S3-AnsB-GitHist; the user and project rules were in context.
- Not read: transcripts (sibling's scope); remaining `.claude/rules/*.md` not already in context (config-file-safety, deploy-paths, documentation-standards, hook-rollout, managed-file-deployment, relay-outbound, tool-evaluation, tool-lifecycle, web-sources were not opened in full; deploy-paths was read as #99 writes it).

WRITE_BLOCKED: none (one Bash call was refused by standing-order-guard for a backtick inside a grep pattern; I re-ran it without the backtick, and no write was involved).
