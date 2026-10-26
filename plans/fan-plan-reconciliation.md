# Plan: reconcile code, docs and decisions in the deployment area (fan-out, ANSWER-1A/1B, parity, abort, step 7, incident ledger)

**Version:** v1.1, 2026-10-26 (v1.0 c1358b9; v1.1 applies the independent review's 13 required changes and the barrier test's 13 fixes). **Author:** S3-Reconcile (orchestrator, level 1, delegated by Session Commander 10cf255a-c; commander Jose). **Status:** executable. Nothing here is implemented yet.

**Intent**: **Purpose**: Give the next executing Session Commander a plan it can run without asking anyone, which resolves every pending reconciliation item between the code, the docs and the commander's recorded decisions in the deployment area, starting with: should `setup-user-claude` be updated, or the docs, or both, and which files change. **Scope**: items 1-8 of mission RECONCILE (section 2), the commander decisions they rest on (section 3), the batches that change docs and code (section 6), their order against open PRs and running missions (section 5), and the open questions only the commander can answer (section 4). NOT executing the plan. NOT the setup-user-claude fan-out refactor itself (FAN-PLAN's plan). NOT merging the open PRs, the dotprofile `deploy/` rebuild, the #102 incident apply, D-DEL5 or the v0.74.0 release (mission MERGE-ALL). NOT re-litigating recorded decisions. **Audience**: the executing Session Commander and its delegates; the commander, who answers section 4.

Evidence for every claim is in the mission folder
`.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Reconcile/`
(**RC/** below), on main since c1358b9: `S3-Reconcile-Trans-findings.md`
(commander words), `S3-Reconcile-Git-findings.md` (PRs, merge order),
`S3-Reconcile-Docs-findings.md` (false doc statements D-1..D-25, parity),
`S3-Reconcile-Code-findings.md` (code facts), `S3-Reconcile-Code-drafts/`
(tested verbatim code edits + `apply.pl`), `S3-Reconcile-Ledger-findings.md`
(incident sync), `S3-Reconcile-Review-verdict.md` (independent review),
`S3-Reconcile-Barrier-results.md` (barrier test), `S3-Reconcile-report.md`.
The AnsA/AnsB reports are on main (8e18ad4): `.../S3-AnsA/S3-AnsA-report.md`,
`.../S3-AnsB/S3-AnsB-report.md`.

**Where cited drafts live.** The S3-H2-Manifest drafts are only on the
branches of #100/#110/#111 until they merge, the S3-H2-MDM drafts only on
#111's, the S3-H2-DraftsM3b row 8 draft only on #105's; read them with
`git -C /Users/new-jose/repos/aitools show origin/<branch>:<path>` (branches:
#100 `feature/harness-rules-manifest`, #110 `feature/harness-cursor-user-rules`,
#111 `feature/harness-mdm-followups`, #105 `docs/m3-approved-intents`, #97
`docs/m3-lead-plan`). FAN-PLAN's plan is on main as
`plans/rules-fanout-claude.md` (landed 3a5f260, during v1.1); its report and
review are in `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-FanPlan/`
(`S3-FanPlan-report.md`, `S3-FanPlan-Review-verdict.md`; check
`git ls-tree origin/main <path>` — they may still be untracked on the machine
that wrote them).

---

## 1. Summary

1. **Fan-out (item 1): both, sequenced.** Code: `setup-user-claude` gets the `~/.aitools/rules` fan-out through FAN-PLAN's plan (the commander ordered it: "put aitools rules in the user space of claude code", 2026-10-23T01:58:29Z). Docs: the protected docs that claim the fan-out already exists are corrected **now** to describe today, with wording that names the coming change, and flipped by FAN-PLAN's doc batch when its code lands (R2, R3, R14).
2. **ANSWER-1A (item 2):** apply AnsA Q1b, Q2, Q3 (Q4 landed with #99). Q1's text is **rewritten** here: since 8e490d7 step 7 always runs, so AnsA's "triggers only on the `shared/` ones" is false (R4).
3. **ANSWER-1B (item 3):** apply AnsB edits A, B, D, E, F, G, I, J and the glossary "profile" fix (R5); edit C goes with a code fix (R9, Q7); edit H is documented now and removed by a code change (R10, Q8); decision 2's answer ("1) yes") is recorded where the decision lives (R1).
4. **Parity (item 4):** the commander killed the parity mandate (March 2026) and since then asks for specific twins ("1d"); remove the leftover mandate, keep and correct the twins that exist (R7, Q9).
5. **Abort (item 5):** fix the profile-mirror menu text (false today); fix the #106 PS1 duplicate-row parity bug; a non-harness abort as WARN needs the commander's yes (R8, Q6); redraft #105's row 8 relay Intent (R8d).
6. **Step 7 (item 6):** no doc still describes the old trigger (verified); the open problems are the false AnsA Q1 text (R4) and that every PR branch changing a deploy/ input FAILs step 7 by construction even after the rebuild (R11, Q5). The rebuild is MERGE-ALL's (A4).
7. **Incident ledger (item 7):** after MERGE-ALL applies #146-#170: close 17, update 8, file 47 new (#171-#217, provisional) in id order (R13).
8. **Other disagreements (item 8):** 15 more false or stale statements and 4 code deviations, batched in R12 or filed in R13.

---

## 2. Items and resolutions (batches in section 6)

| # | Item | Resolution | Code / docs | Files | Batch | Gate |
|---|---|---|---|---|---|---|
| 1 | False "setup-user-claude fans out ~/.aitools/rules" claims | Correct to "today" now; FAN-PLAN flips them | both | `.claude/rules/managed-file-deployment.md` + `.mdc`, `.claude/rules/aitools-workspace.md`, `reference/harness.md`, `reference/managed-file-deployment.md`, `.claude/rules/hook-rollout.md` + `.mdc`, `shared/skills/scratch/SKILL.md`; code: FAN-PLAN | R2, R3, R14 | G-P, Q2 |
| 2 | ANSWER-1A (Q1, Q1b, Q2, Q3, Q4) | Q1 rewritten; Q1b, Q2, Q3 applied; Q4 done (#99, 3c4f8fe) | docs | `.claude/rules/deploy-paths.md` + `.mdc`, `reference/managed-file-deployment.md`, `shared/cursor-rules/user-rules.md` | R4, R2c, R6 | G-P (Q3 line approved) |
| 3 | ANSWER-1B (A-J, glossary, C, H, decision 2) | A,B,D-G,I,J, glossary in R5; C with R9; H now, removed in R10; decision 2 recorded | both | `reference/user-repo.md`, `registries/glossary.json` (via `/glossary`), `plans/tool-support-and-machine-profile.md`, `S3-M3Lead/S3-M3Lead-plan.md`; code R9, R10 | R1, R5, R9, R10 | G-P, Q7, Q8 |
| 4 | .mdc parity | Remove the mandate; correct existing twins | docs | `.cursor/rules/cursor-rule-parity.mdc` (delete), `reference/cursor-practices.md`, `.cursor/rules/documentation-standards.mdc`, `.cursor/rules/config-file-safety.mdc` | R7a, R7b | G-P, Q9 |
| 5 | Abort follow-ups | Menu text; PS1 relay parity; WARN row gated; row 8 Intent | both | `scripts/aitools-lib.sh/.ps1`, `.claude/rules/interactive-menus.md` + `.mdc`; gated: runners, relay, tests, docs | R8a1, R8a2, R8b, R8c, R8d | R8c: Q6; G-P for docs/intent |
| 6 | Step 7 always runs | AnsA Q1 rewritten (R4); PR-branch FAIL gated | both | `scripts/check-pre-push.sh/.ps1`, `reference/pre-push-checklist.md` | R4, R11 | Q5 |
| 7 | Incident ledger | R13-pre amendments; L0 close/update; L1-L5 new | data | `registries/incidents.json` (via `/incident`) | R13-pre, R13 | G-P, Q13 |
| 8 | Other | R12 docs; code deviations filed in R13 | both | see R12 | R12 | G-P |

---

## 3. Commander decisions this plan relies on (newest first)

Verbatim; session 10cf255a-c unless stated; uuids in RC/S3-Reconcile-Trans-findings.md; MERGE-ALL lines in `.../S3-MergeAll/S3-MA-Brief-brief.md` (main b40a320).

| When (UTC) | Words | What it settles here |
|---|---|---|
| 2026-10-26T22:59:58Z (MERGE-ALL A2) | "User rule + skill; review after (Recommended)" — option text: "Protected files: written as a version and committed; you review the commit/PR diff instead of a pre-write draft." | Gate G-P (section 4 Q1): once MERGE-ALL lands review-after in `.claude/rules/sources-of-truth.md`, this plan's protected edits ship as versions and are reviewed after |
| 2026-10-26T22:59:58Z / 23:01:36Z (MERGE-ALL A1, A4, A5) | "merge commits, mission merges, in the correct order, and checks after each step"; dotprofile deploy/: "do a backup of the deploy and then do a rm -rf if necessary (the mission, not me the commander)"; "Same, and the mission tags" | MERGE-ALL merges the open PRs, rebuilds the dotprofile deploy/, applies #102, tags v0.74.0. This plan waits for them |
| 2026-10-26T22:42:03Z (b277b82b) | "Every pending item (Recommended)"; FAN-PLAN: "Launch now, consume it" | RECONCILE's scope |
| 2026-10-26T22:39:56Z (0e1119a1) | "1) q1c pre-push step 7 should always run before pushing. update docs/rule/reference file as necessary"; "no drafts, the produced plan should be executable by another sessions, it should be version 1.0"; "the plans directory should skip worktrees/prs ... thats a decision" | Step 7 always runs (8e490d7); this plan is a version; plans/ direct to main |
| 2026-10-26T22:17:19Z (474446b2) | "2) update the docs to match the current implementation of PR #106. lets keep functionality, update docs on whatever current state is"; "3) approved, add this to aitools project CLAUDE.md file. project claude.md also bypassess worktrees etc" | Abort: keep #106's stop rule; docs describe the current state (the principle R2/R3 apply). Channel exception in CLAUDE.md |
| 2026-10-26T21:58:13Z (cb1f0201) | "1c) yes, re-draft" (#105 row 8); "1d) approved" (the #99 `.mdc` twin); "1e) approved" (Manifest/Cursor/MDM delegate doc drafts — the SC's question attached the condition "after a reviewer checks them against merged code"); "3) sure" (row 6); "6) re-factoring setup-user-claude and the fan-out requires a mission to create a plan"; "7) re-state row 3 of 96" (restated; no answer since) | R8d; R2/R4 apply the 1e drafts with a reviewer check |
| 2026-10-24T22:45:50Z (c86608ca) | "1) protected drafts approved. 2) dotprofile pushes outside of main branch should error out 3) logging suggestions all accepted" | #146-#170 approved; #165 must say ERROR (R13-pre) |
| 2026-10-23T02:01:33Z (0527e51d) | "protected drafts approved. laurnch harness-2," (covers #96 row 3: `--claim` only "after the user picks that profile at a terminal") | AnsB C: the code deviates (R9) |
| 2026-10-23T01:58:29Z (e073aea3) | "1) yes" (to the SC's 00:36:13Z "Cached alias, when the profile has no machine id: keep today's behaviour, which asks on a terminal and errors without one"); "3) put aitools rules in the user space of claude code" (to the SC's 00:36:13Z "Rules fan-out: 'everything' puts aitools' project rules in every repo and adds 17 always-apply Cursor rules to every chat. User-level only, or keep everything?"); "4) approved" (`%USERPROFILE%\repos` everywhere) | Decision 2 (R1); D5 (FAN-PLAN fans out aitools project rules too; Q4); AnsA Q3 |
| 2026-10-22 (f486b184, 03:43:27Z; plan row E-mdc-model) | "Re-mirror after the managed-file spec rewrite lands" | Twins are re-mirrored when asked (Q9) |
| 2026-10-22T00:04:12Z (65461507) | "hooks/ is populated with all of shared/hooks and .claude/hooks" | AnsA Q1b |
| 2026-03-15T03:33:46Z (b6a51f29, 7ab38b9f); 2026-03-13T22:17:58Z (bdf5e181, 4062135d) | "we dont care about rule parity anymore kil that test"; "lets kill the cursor rule parity ... they need to be tracked and managed seperately" | No parity mandate (R7) |
| 2026-10-20 (handoff 360aa8f3-8 D.3, SD-7) | config.json "has exactly one writer (setup-user-config)" | AnsB H (R10) |

Not decisions (agent text only): "Cursor user-level only" (the SC's reading of "3)"; Q3).

---

## 4. Open questions for the commander (answer in one message; each has a suggested answer)

The executing commander sends these first (section 7 step 3). Batches gated by an unanswered question wait; others proceed.

- **Q1. Protected-file gate (G-P).** MERGE-ALL A2 makes protected files "review after", but until MERGE-ALL commits it to `.claude/rules/sources-of-truth.md` the rule still says pre-write review. G-P is open when both hold: `git -C /Users/new-jose/repos/aitools grep -c -i -E "review[- ]after|reviewed after" origin/main -- .claude/rules/sources-of-truth.md` >= 1 and `git -C /Users/new-jose/repos/aitools grep -c "Wait for approval" origin/main -- .claude/rules/sources-of-truth.md` = 0. *Suggested:* wait for that; or answer "apply now under A2" to open G-P at once (then every protected batch ships as a version with a "Review after" PR section).
- **Q2. Fan-out docs now, or wait for FAN-PLAN's code?** *Suggested:* now (R2/R3), describing today with "until it fans out" wording; your 22:17:19Z principle is "update docs on whatever current state is", and FAN-PLAN needs #106, #100 and its own review first.
- **Q3. Cursor gets user-level rules only (#110)?** Your "3)" did not say it; the SC read it in. *Suggested:* yes.
- **Q4. Reverse D5?** On 2026-10-23 you answered "put aitools rules in the user space of claude code" to "User-level only, or keep everything?". FAN-PLAN implements that (D5). Measured since: 17 of the 26 aitools `.claude/rules` have no `paths:`, about 79 KB (~20k tokens) loaded in every session in every repo; inside aitools each loads twice; "(this repo)" rules such as `sources-of-truth.md` and `script-standards.md` would govern every repo (FAN-PLAN plan section 8 R1). *Suggested:* keep D5 unless that cost changes your mind; if you reverse it, FAN-PLAN takes its costed "skip source aitools" variant (+15 lines per language). No answer = D5.
- **Q5. Step 7 on PR branches.** Step 7 builds from the pushed branch and compares with the dotprofile `deploy/` built from main, so a branch that changes any deploy/ input (16 of the 19 PRs at plan time) FAILs even right after the rebuild (RC/Code 2.4). *Suggested:* R11: still always runs; a difference caused by the push's own deploy/ inputs becomes WARN with the rebuild instruction; FAIL stays for build/smoke failure and for staleness on a push that changes no input.
- **Q6. A user abort in a non-harness script: ERROR or WARN?** Three conventions exist: #106 runners ERROR `script failed (exit 2)`, #115/#116 relay ERROR `aborted (exit 2)`, #106 deploy-harness WARN `aborted by user`. #106's T-Q3 note in `plans/tool-support-and-machine-profile.md` records ERROR as kept under your "lets keep functionality"; the row text itself was never asked. *Suggested:* WARN `aborted by user` everywhere, run continues, only deploy-harness stops (R8c).
- **Q7. AnsB C: should `aitools user init --alias X` claim a profile no machine owns without asking?** Today it does, with or without a terminal, against the row-3 text you approved on 2026-10-23 (you asked to re-state row 3 on 2026-10-26; it was restated and not answered). *Suggested:* no: confirm on a terminal, ERROR + ACTION without one (R9); a brand-new alias stays prompt-free.
- **Q8. AnsB H: the entry points' `aiToolingRepoPath` rename writes config.json without backup or validation.** *Suggested:* move it into `setup-user-config` (backup + validation), entry points read only (R10). Deleting it alone would make the writer ERROR on a legacy machine.
- **Q9. Parity.** Your March words killed the mandate; since then you asked for specific twins ("Re-mirror after the managed-file spec rewrite lands", "1d) approved"). *Suggested:* no standing mandate (delete `cursor-rule-parity.mdc` and the parity sections); an existing `.mdc` is corrected when it is false, and re-mirrored when you ask for it; a new twin only on request.
- **Q10. Timing against v0.74.0.** *Suggested:* docs batches (R1-R7, R12) land before the tag, and MERGE-ALL's RELEASE docs scrub takes this plan as its input for these files (no double edits); code batches R8-R11 may follow in v0.74.1 if they would hold the tag.
- **Q11. Pre-commit step 3 `--fix` and `scripts/githooks/pre-commit` `git add` the frozen `aitools/deploy/`** after building into the dotprofile (RC/Docs D-15). *Suggested:* drop the `git add deploy/`; step 3 WARNs naming the dotprofile rebuild; step 7 is the real check. File it (R13), fix in a follow-up PR.
- **Q12. deploy-harness adopts into the dotprofile are not committed and pushed (N-Q2).** *Suggested:* code fix in a follow-up PR; file it (R13).
- **Q13. Incident batches L0-L5.** *Suggested:* one review page, review after (A2), then the PRs in id order.
- **Q14. Channel exception beyond CLAUDE.md.** The SC's 22:17Z question proposed it "for all four places"; your answer named CLAUDE.md. *Suggested:* MERGE-ALL's D-DEL5 batch (it edits `delegation.md` and the `/delegate` skill) adds one line to `~/.claude/rules/delegation.md` and the `/handoff` skill; R12 adds a pointer in `aitools-workspace.md`.
- **Q15. Who merges this plan's PRs?** MERGE-ALL's A1 covers the 19 PRs open at its launch. *Suggested:* extend A1: the executing commander's mission merges its own PRs with merge commits after green CI and an independent reviewer's verdict.

---

## 5. Dependencies and order

### 5.1 Who owns what (do not overlap)

| Mission | Owns | This plan's relation |
|---|---|---|
| MERGE-ALL (brief main b40a320) | Merging in its order: #99, #101, #105, #104, #97, #102, #103, #98, #108, #114, #109, #113, #112, #100, #110, #111, #115, #106, #116; #102 apply (#146-#170); #74/#75 re-land; #111 `--skip-config` in Step 8b; #103/#108/#105-rows-5-6 approved drafts; D-DEL5 + sources-of-truth review-after; build-deploy backup-then-swap + dotprofile `deploy/` rebuild; `plans/merge-friction-improvements.md`; RELEASE v0.74.0 + docs scrub + tag | Gates in 5.3 use `gh pr view <n> -R nobul-tech/aitools --json state --jq .state` (= MERGED) and `git log origin/main` for MERGE-ALL's non-PR steps (search commit subjects, e.g. `git log --oneline origin/main --grep "review after" -i`). It has no progress file. R13-pre must reach it before it applies #102 |
| FAN-PLAN (draft plan path above) | setup-user-claude fan-out code; build-deploy MDM counterpart; `tests/rules-fanout/`; its Batch A in `scripts/aitools-lib.sh/.ps1` and `tests/profile/test-lib.sh`; its doc drafts (deploy-paths, managed-file-deployment, user-repo, harness, hook-rollout, config-file-safety, tool-ops-claude-code) | R2/R3 change some of the same lines first; FAN-PLAN's doc batch re-anchors on them (R14). If FAN-PLAN Batch A merges before R8, rebase R8 on it |
| BUILD-PKG (`plans/build-package/`) | Package distribution; has edited `.claude/rules/aitools-workspace.md`, `reference/harness.md`, `shared/cursor-rules/user-rules.md`, `.cursor/rules/cross-platform.mdc`, `CLAUDE.md`, `README.md` (5494d93), `.claude/rules/deploy-paths.md` + `.mdc`, `cross-platform.md` (32bf20c), and still edits deploy-paths.md; pending B13 edits to `reference/logging.md`, `reference/tool-support-decision-tree.md`, `.cursor/rules/tool-lifecycle.mdc` (`plans/build-package/doc-edits-pending.md`) | Pull and re-read before R2b, R4, R6, R8c-d2, R12a-c; never edit `plans/build-package/` |

### 5.2 State at plan time (v1.1)

origin/main adb61ec: #99 (3c4f8fe) and #101 (adb61ec) merged by MERGE-ALL. Still open: #97, #98, #100, #102-#106, #108-#116. Re-check before every batch.

### 5.3 Batch order and gates

Each line: batch -> gate. "G-P" = section 4 Q1 open. Batches on one line may run in parallel only if their files are disjoint (they are, except where noted).

```
R13-pre -> now (before MERGE-ALL applies #102)
R1      -> #97 merged + G-P
R5      -> #101 merged (done) + G-P
R6      -> step 1 now (approved "4) approved"); step 2 + G-P
R2a+R2b -> #100 and #110 merged + G-P          (one PR)
R2c     -> R2a+R2b merged + MERGE-ALL applied #103's helper-contract draft + G-P
R3      -> G-P
R4      -> #111 merged + G-P
R7a, R7b-> Q9 + G-P
R12a-d  -> G-P (R12d after MERGE-ALL's sources-of-truth change)
R8a1    -> #106, #115, #116 merged             (code)
R8a2    -> R8a1 merged + G-P
R8b     -> #106 and #116 merged                (code)
R8c     -> R8a1, R8b merged + Q6 (+ G-P for R8c-d1/d2; R8c-d1 after R2c)
R8d     -> R8c merged (or Q6 = ERROR) + G-P
R9      -> R8c merged (same files) + Q7 (+ G-P for R9b2's doc)
R10     -> R9 merged + Q8 (+ G-P for R10c)
R11     -> MERGE-ALL rebuild of the dotprofile deploy/ + Q5
R13 L0  -> #102 applied + G-P + Q13; L1..L5 after L0, in id order
R14     -> FAN-PLAN's code PR merged
```

R8 -> R9 -> R10 run strictly one after another: R8b, R8c, R9a and R10b all edit `scripts/aitools` / `aitools.ps1`; R8c and R9a both edit `tests/profile/test-user-init.sh`.

---

## 6. Batches

### 6.0 Rules for every batch

- **Shipping.** Channel-exception paths (`plans/*`, `.aitools/channel/handoffs/*`, `.aitools/channel/relay.md`, `CLAUDE.md`) go direct to main from the main checkout: `git -C /Users/new-jose/repos/aitools pull --ff-only`; stage only the batch's paths (never `git add -A`: the checkout holds other missions' untracked folders and harvesting files); `git commit -F <scratch msg>` ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; `git push origin main`; a non-fast-forward pull = stop and report. Everything else: a worktree off origin/main, `git -C /Users/new-jose/repos/aitools worktree add -b <branch> /Users/new-jose/repos/aitools/.claude/worktrees/<batch-id-lowercase> origin/main` (e.g. `.../worktrees/rx-r2`), commit, run `bash scripts/check-pre-commit.sh` and `bash scripts/check-pre-push.sh` from the worktree (known: pre-commit step 6 FAIL; pre-push step 7 FAIL until MERGE-ALL's rebuild, and on input-changing branches until R11), `git push -u origin <branch>`, `gh pr create -R nobul-tech/aitools --base main --head <branch> --body-file <scratch>/pr-body.md`. PR body sections (this list wins over the packet's): Summary; Why (decision ids from section 3); Changes; Verification; Not run; Review after (protected files written under A2, each with old -> new); Follow-ups. End with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`. Merging: Q15.
- **Delegation.** One fresh delegate per batch, named `S3-RX-<batch>` (e.g. `S3-RX-R2`), prefix `S3-RX-<batch>-` on every `*.md` it writes, scratch `<its worktree>/.scratch/session-rx<batch>` (<= 10 chars), hand-back in `.aitools/channel/handoffs/<executing SC's mission folder>/S3-RX-<batch>/`. Its prompt carries the seven duty elements (`/delegate`), the packet path `/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/SC-mission-packet.md`, this plan's path and batch id, the "Error-handling rules (non-negotiable)" block of `reference/plan-execution-detail.md` verbatim, and the D-DEL4 shipping terms. Reviewer: a separate delegate `S3-RX-<batch>-Review` (prefix `S3-RX-<batch>-Review-`) without the implementer's notes; it posts its verdict with `gh pr review <n> --comment --body-file <file>`. For batches applying "1e"-approved drafts, the reviewer checks them against the merged code (the 1e condition) and says so.
- **Gate closed.** If a batch's gate is closed, do not start it; record it in the running estimate and move to the next open batch. Never apply a batch on a stale base "to save time".
- **Anchors, not line numbers.** Lines move (MERGE-ALL, BUILD-PKG and FAN-PLAN commit to main). Each OLD below is a unique substring on origin/main at v1.1 unless stated. Before editing, confirm it occurs exactly once (`grep -c -F`); if not, re-read the file and re-anchor; never guess.
- **Notation.** Inline `OLD:` / `NEW:` text sits between the outer backticks; inside it `\`` is a literal backtick and `\n` a line break (the file's indentation follows). Every other backslash is literal. Fenced blocks are literal as shown.
- **Code drafts** are `RC/S3-Reconcile-Code-drafts/edits-*.txt` (`@@@FILE <base>/<file> <title>`, `@@@OLD`, `@@@NEW`, `@@@END`). Map the base prefix: `main/aitools` -> `scripts/aitools`, `main/aitools.ps1` -> `scripts/aitools.ps1`, `main/setup-user-config.*` -> `scripts/setup-user-config.*`, `main/aitools-lib.*` -> `scripts/aitools-lib.*`, `main/check-pre-push.*` -> `scripts/check-pre-push.*`, `pr106/aitools-install.*` -> `scripts/aitools-install.*`, `pr106/aitools` and `pr106/aitools.ps1` -> `scripts/aitools`, `scripts/aitools.ps1`, `pr115/aitools-lib.*` -> `scripts/aitools-lib.*`, `pr115/aitools-116` -> `scripts/aitools`, `tests/...` as is. Copy the edits file into scratch, rewrite the prefixes with Perl, run `perl apply.pl <edits> <worktree> <scratch-out>`, diff the output against the worktree, then copy the files in. `apply.pl` dies when an OLD is not found exactly once: re-pin that block against the merged code and record the re-pin in the PR body. E3a does not apply to #116's copy of `scripts/aitools` (it lacks #106): after both merge, re-pin.
- **Docs** never cite line numbers in rules/references (documentation-standards.md).
- **Windows.** Every `.ps1` edit is parser-checked only on macOS. Where a `.ps1` suite exists (`tests/managed-files/test-managed-files.ps1`, `tests/profile/user-init-harness.ps1`), run it under macOS pwsh and list "Not run: Windows" in the PR body.

### R1 — Decision 2 recorded (direct to main; G-P; after #97 merged)

Two channel-exception files, one commit:
1. `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-M3Lead/S3-M3Lead-plan.md` (lands with #97). Section 2 item 2 starts `2. PENDING: cached config alias (config.json \`machineAlias\`) -> profile without`. Replace `PENDING:` with `DECIDED 2026-10-23T01:58:29Z (commander, "1) yes", session 10cf255a-c, uuid e073aea3: keep today's behaviour, ask on a terminal, ERROR without one; the switch stays 0):`.
2. `plans/tool-support-and-machine-profile.md` (protected; table `| Item | Section | Question | Decision | Note |`). Append before the line `95 items.`:
   ```
   | M3Lead-2 | Chat (M3-LEAD) | Cached alias, when the profile has no machine id: keep today's behaviour (ask on a terminal, ERROR without one)? | Yes; the switch stays 0 | Decided 2026-10-23T01:58:29Z, "1) yes" (session 10cf255a-c, uuid e073aea3); S3-M3Lead plan section 2 item 2 |
   ```
   and change `95 items.` to `96 items.`. Note for the commander in the commit body: an M3-LEAD chat decision sits at the edge of this file's Intent scope ("decisions and notes from the review page ... and the chat clarifications that override them"); written under A2, review after.
- The code comments citing "PENDING" (`scripts/aitools`, `scripts/aitools.ps1`: `grep -n "PENDING with the commander"`) change in R9b2.
- Verify: `grep -c "e073aea3" plans/tool-support-and-machine-profile.md` = 1; `grep -c "^2. PENDING" <M3Lead plan>` = 0; `tail -1`-area shows `96 items.`.

### R13-pre — Amend #102 before MERGE-ALL applies it (note + message)

Write `S3-Reconcile-R13pre-note.md` in **this plan's executing SC's own mission folder** (direct to main), and send its text to MERGE-ALL's orchestrator (SendMessage if it is running; otherwise to the commander). The file to change is `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-MF-Incidents/S3-MF-Incidents-batch.json` on branch `docs/mf-incidents` (#102):
1. #165 suggestedResolution: a dotprofile push from a non-main branch is an **ERROR** (commander 2026-10-24T22:45:50Z "dotprofile pushes outside of main branch should error out"), not "WARN + ACTION".
2. #166: add the case of two profile keys that differ only in case (`S3-MF-Fix3-Review-pr114.md:46` on #114's branch).
3. #102's title says "#146-#161"; the batch is #146-#170 (25 entries).
If #102 is already applied when you read this, these become L0 updates.

### R2 — Fan-out claims describe today (one PR `docs/reconcile-fanout-today`; R2a + R2b)

Gate: #100 and #110 merged; G-P; Q2. The Manifest drafts: `origin/feature/harness-rules-manifest:.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-H2-Manifest/S3-H2-Manifest-drafts/` (identical on #110/#111; on main once #100 merges). Pull first.

**R2a** — `.claude/rules/managed-file-deployment.md`, `.cursor/rules/managed-file-deployment.mdc`
1. `.md` only (the sentence is not in the `.mdc`). OLD: `Rules reach the tools through the \`setup-user-claude\` / \`setup-user-cursor\` fan-out.`
   NEW: `User-level rules reach Cursor through the \`setup-user-cursor\` fan-out; Claude Code still gets the dotprofile \`claude/rules/\` from \`setup-user-claude\` directly, until \`setup-user-claude\` fans out \`~/.aitools/rules\` too.`
2. Both files: apply the Manifest rule draft (`dot-claude/rules/managed-file-deployment.md` in the drafts folder); its OLD `- **Rules**: additive deploy from` occurs once in each file, and its bullet **replaces** that bullet in both. Reword its fan-out sentence so it is true today, verbatim: `\`setup-user-cursor\` updates the Cursor copies and removes the copies of retired rules; \`setup-user-claude\` does the same once it fans out \`~/.aitools/rules\`.` (singular subject; project rules retired by the manifest are pruned too).
3. Both files: the `.mdc` lacks the deploy-harness content-sources row: add the `.md` row as edited in step 1 to the `.mdc` Content sources table.
4. Both files: in the dotprofile row of Content sources, OLD `| Primary (wins if present) | CLAUDE.md template, user rules, profile.json` NEW `| Primary (wins if present) | CLAUDE.md template, profile.json` and append to that row's last cell `; its \`claude/rules/\` reaches \`~/.aitools/rules\` last (first source wins: \`shared/\`, then \`.claude/\`, then the dotprofile)`. (FanPlan reviewer non-blocking 4.)
5. Check, do not edit: "hostname match, then first profile" is gone from both files after #101 (`grep -c "first profile"` = 0 in each). If not, replace it with #101's text.
- Verify: `grep -c "Rules reach the tools" .claude/rules/managed-file-deployment.md` = 0; `grep -c "until \`setup-user-claude\` fans out" .claude/rules/managed-file-deployment.md` = 1 (step 1) and >= 1 in the `.mdc`; `bash scripts/check-pre-commit.sh`.

**R2b** — `reference/harness.md`, `.claude/rules/aitools-workspace.md`
1. harness.md "Not detected" bullet. OLD: `conflicts with files already in a\n  tool's own location (\`~/.claude/rules/\`), which the fan-out in\n  \`setup-user-claude\` / \`setup-user-cursor\` handles.`
   NEW:
   ```
   conflicts with files already in a
     tool's own rules location: `setup-user-cursor` reviews the
     `~/.cursor/rules/<name>.mdc` files it writes and keeps every other file
     there; `~/.claude/rules/` is not fed from `~/.aitools/rules/` until
     `setup-user-claude` fans it out.
   ```
2. Apply the approved Manifest harness.md draft (`reference/harness.md` in the Manifest drafts folder) and, if #111 has merged, the MDM `--skip-config` draft (`origin/feature/harness-mdm-followups:.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-H2-MDM/S3-H2-MDM-drafts/reference/harness.md.edit.txt`). In the Manifest draft, replace `The rules fan-out consumers (\`setup-user-claude\`, \`setup-user-cursor\`) read it` with `\`setup-user-cursor\` reads it (and \`setup-user-claude\` will, once it fans out)`.
3. aitools-workspace.md `rules/` row. OLD: `copied to each tool's rules location by \`setup-user-claude\` / \`setup-user-cursor\``
   NEW: `\`setup-user-cursor\` converts them into \`~/.cursor/rules/*.mdc\` (Claude Code still gets the dotprofile \`claude/rules/\` from \`setup-user-claude\` until it fans them out)`
4. aitools-workspace.md `deploy-state/` row (D-18). OLD: `| \`deploy-state/\` | Last-deployed file hashes for drift detection |`
   NEW: `| \`deploy-state/\` | Unused since 2026-10-21 (no deploy state: SOURCE is the source of truth); older machines may still have the directory, and nothing reads or writes it |`
5. aitools-workspace.md (Q14 pointer), after the project-scoped workspace table: `Channel paths (\`channel/handoffs/\`, \`channel/relay.md\`) and \`plans/\` are committed directly to main: see \`CLAUDE.md\` "Channel exception (direct to main)".`
- Verify: `grep -n "setup-user-claude" reference/harness.md .claude/rules/aitools-workspace.md` shows only the new wording; `grep -c "Last-deployed file hashes" .claude/rules/aitools-workspace.md` = 0.

### R2c — reference/managed-file-deployment.md (PR `docs/reconcile-mfd-reference`)

Gate: R2 merged; MERGE-ALL has applied #103's approved helper-contract draft to this file (pull; `git log --oneline -3 origin/main -- reference/managed-file-deployment.md`); G-P.
1. AnsA Q2 paragraph, directly after the "Deployed harness (`~/.aitools`)" table and before the "`userRepoPath` resolution" paragraph:
   ```
   User-level rules reach Cursor from `~/.aitools/rules/` through the
   `setup-user-cursor` fan-out, and Claude Code through `setup-user-claude` once
   it fans out (today it deploys `<userRepoPath>/claude/rules/` directly).
   Conflict handling and its assumptions: `@reference/harness.md` "Deployed
   harness (`~/.aitools`)".
   ```
2. Apply the approved Manifest draft for this file (`reference/managed-file-deployment.md` in the Manifest drafts folder) with the same consumer rewording as R2a step 2. Its Edit 1 rewrites the "User rules" row to end `| (none — no dotprofile rules deployed) |`.
3. Then, OLD (the row exactly as Edit 1 wrote it) cell `(none — no dotprofile rules deployed)` NEW `(dev path: none; MDM path: the build-time copy of the dotprofile rules when the machine has no dotprofile)`. FAN-PLAN Batch C removes that MDM copy; its draft then updates this cell.
4. D-21. OLD: `| Machine profile | \`<userRepoPath>/profile.json\` \`profiles[machineAlias]\` section | hostname match, then first profile |`
   NEW: `| Machine profile | \`<userRepoPath>/profile.json\` \`profiles[<machine id>]\`, chosen by the resolver (\`aitools-profile.sh\` / \`.ps1\`) | none: no match is an ERROR, never another machine's profile (\`@reference/user-repo.md\` "Resolution") |`
- Verify: `grep -c "first profile" reference/managed-file-deployment.md` = 0; `grep -c "no rules deployed)" reference/managed-file-deployment.md` = 0; read the inserted paragraph in place.

### R3 — hook-lifecycle / shared rules deployment wording (PR `docs/reconcile-shared-rules-path`)

Gate: G-P. Files: `.claude/rules/hook-rollout.md`, `.cursor/rules/hook-rollout.mdc`, `shared/skills/scratch/SKILL.md`.
1. hook-rollout.md OLD: `(deployed to \`~/.claude/rules/hook-lifecycle.md\` once a deploy path for\n\`shared/rules/\` exists)` NEW: `(copied to \`~/.aitools/rules/\` by \`deploy-harness\` and on to\n\`~/.cursor/rules/hook-lifecycle.mdc\` by \`setup-user-cursor\`; it reaches\n\`~/.claude/rules/\` once \`setup-user-claude\` fans out \`~/.aitools/rules/\`)`
2. hook-rollout.mdc OLD: `user-level rule \`shared/rules/hook-lifecycle.md\` (not yet deployed).` NEW: `user-level rule \`shared/rules/hook-lifecycle.md\` (deployed to \`~/.cursor/rules/hook-lifecycle.mdc\` through \`~/.aitools/rules/\`; to Claude Code once \`setup-user-claude\` fans out).`
3. scratch SKILL.md OLD: `deployed to \`~/.claude/rules/\` once\n  deploy-harness ships a path for \`shared/rules/\`)` NEW: `copied to \`~/.aitools/rules/\` by deploy-harness; it\n  reaches \`~/.claude/rules/\` once setup-user-claude fans that out)`
- Verify: `grep -rn "once a deploy path\|not yet deployed\|ships a path for" .claude/rules .cursor/rules shared/skills` = no hits.

### R4 — deploy-paths.md / .mdc (PR `docs/reconcile-deploy-paths`)

Gate: #111 merged; G-P. BUILD-PKG rewrote parts of this file (32bf20c) and was still editing it at v1.1: pull, re-read both files in full, re-anchor every step.
1. Apply #111's MDM draft Edits 1-3 (`S3-H2-MDM-drafts/dot-claude/rules/deploy-paths.md.edit.txt`, on main once #111 merges) to the `.md` (anchors were 1/1/1 on main after 32bf20c); in the `.mdc` re-anchor all three on its single-line paragraphs (the draft says "two edits"; there are three; its OLD text does not match the `.mdc`).
2. Q1b: in the sources bullet (starts `- Every \`scripts/deploy-harness.*\` source`), OLD `\`shared/hooks\`, \`shared/skills\`` NEW `\`shared/hooks\`, \`.claude/hooks\`, \`shared/skills\`` (both files). Do not reflow other lines.
3. Q1 (rewritten), inserted after the sources bullet (after Edit 3), both files:
   ```
   Because of that bullet, a change to any of those sources makes the
   dotprofile `deploy/deploy-harness.*` stale until `build-deploy.sh` runs again
   and the dotprofile `deploy/` is committed. Pre-push step 7 runs on every
   push: it rebuilds the whole dotprofile `deploy/` from this checkout into a
   temporary copy and FAILs when the result differs from the committed one. A
   change in the dotprofile itself (for example `<userRepoPath>/claude/rules`)
   counts only once it is committed in the dotprofile repo.
   ```
   If R11 has merged, append: `When the push itself changes a deploy/ input, the difference is a WARN that asks for the rebuild after the merge.`
4. `.mdc` only (D-12, D-13), if still present after BUILD-PKG's edits:
   - OLD `2. **MDM path** (\`deploy/setup-*.sh/.ps1\`): self-contained with build-time embedded content. Generated by \`build-deploy.sh\`.` NEW `2. **MDM path** (\`<userRepoPath>/deploy/setup-*.sh/.ps1\`): self-contained, generated by \`build-deploy.sh\` into the dotprofile repo. The shared \`aitools/deploy/\` is frozen.`
   - Each (2) `Run \`build-deploy.sh\` to regenerate \`deploy/\`` -> `Run \`build-deploy.sh\` to regenerate \`<userRepoPath>/deploy/\``
   - OLD `3. Verify via pre-commit steps 3+10` NEW `3. Verify the dotprofile \`deploy/\` includes the change (pre-push step 7 rebuilds it on every push)`
- Verify: `grep -n "triggers only\|Verify via pre-commit steps 3+10" .claude/rules/deploy-paths.md .cursor/rules/deploy-paths.mdc` = no hits; `grep -c "\.claude/hooks" .claude/rules/deploy-paths.md` = 1.

### R5 — ANSWER-1B: reference/user-repo.md and the glossary (PR `docs/reconcile-user-repo`)

Gate: #101 merged (done, adb61ec); G-P.
- **R5a** `reference/user-repo.md`: apply the **final texts** of `.../S3-AnsB/S3-AnsB-report.md` section "Per edit" for A, B, D, E, F, G, I (the "after #106 (and #111) merge" text if #106 has merged, else "Final text now"), J and H. Each edit's OLD is in `S3-H2-DraftsM3-drafts/reference/user-repo.md.edit.txt` (on main since #101 merged). Edit C: if Q7 = suggested, nothing here (R9b2 applies it); if Q7 = keep the code, apply AnsB's "If he keeps the code" text here. AnsB critic: the sentence "Migrate the live dotprofile only after #86 and #83 are merged ..." is dated (both merged): replace it with what MERGE-ALL reports about the live re-key, or leave it if MERGE-ALL reports nothing.
- **R5b** `registries/glossary.json` through the `/glossary` skill: term "profile", fragment `(one entry of its 'profiles' object, keyed by machine id (environment:<name> for a hosted environment without one))`, source appended `; commander decision 5 of 2026-10-22`.
- Verify: `grep -c "keyed by machine alias" reference/user-repo.md registries/glossary.json` = 0; `python3 -c "import json,sys; json.load(open(sys.argv[1]))" registries/glossary.json`; the skill's validation.

### R6 — shared/cursor-rules/user-rules.md (PR `docs/reconcile-cursor-user-rules`)

Gate: step 1 now (approved: "4) approved", 2026-10-23T01:58:29Z); step 2 after G-P (protected file). BUILD-PKG edited this file (5494d93): re-read.
1. AnsA Q3. OLD: the line starting `- Projects live in git repos under`. NEW (literal; byte-identical to the line in `shared/claude-shared.md` — check with `grep -c -F`):
   ```
   - Projects live in git repos under `~/repos/` (macOS) / `%USERPROFILE%\repos\` (Windows)
   ```
2. D-24. OLD: `The \`setup-user-cursor\` script copies this to your clipboard automatically.` NEW: `Copy it by hand; no setup script copies it (the clipboard step was removed).`
- Verify: `grep -c "C:.repos" shared/cursor-rules/user-rules.md` = 0; `grep -c -F "%USERPROFILE%\repos\\" shared/cursor-rules/user-rules.md shared/claude-shared.md` = 1 each (or compare the two lines with `diff`).

### R7 — Parity mandate removed; twins corrected

Gate: Q9; G-P.
- **R7a** (PR `docs/reconcile-cursor-parity`): `git rm .cursor/rules/cursor-rule-parity.mdc`; `.cursor/rules/documentation-standards.mdc`: delete the bullet starting `**Cursor parity** —` (its target was deleted in v0.54); `reference/cursor-practices.md`:
  - OLD `Cursor project rules mirror Claude Code rules for consistency. When changing rules, update both sets.` NEW `Claude Code and Cursor rules are separate harnesses, tracked and managed separately (commander, 2026-03-13). A \`.cursor/rules/*.mdc\` twin exists only where one was made on purpose; when its \`.md\` changes, correct any \`.mdc\` statement the change makes false, and re-mirror it when the commander asks.`
  - Replace the "Changing rules" steps 1-3 with that rule as one step.
  - Correspondence table: remove the `cursor-rule-parity.md` row; smoke-test-pattern has an `.mdc`; add the agentic-standards, git-safety and managed-file-deployment pairs; drop "Near-identical" for sources-of-truth and tool-lifecycle.
  - D-25: add the row `| User rules (files) | \`~/.cursor/rules/*.mdc\` | Deployed by \`setup-user-cursor\` from \`~/.aitools/rules/\` (converted from \`.md\`) |`; OLD `\`deploy/setup-user-claude.sh/.ps1\` have the shared content embedded at build time.` NEW `\`<userRepoPath>/deploy/setup-user-claude.sh/.ps1\` (the dotprofile repo) have the shared content embedded at build time.`
  - Verify: `git grep -n -i "parity" -- .cursor/rules reference/cursor-practices.md` shows only menu parity and the new sentence.
- **R7b** (same PR, own commit): `.cursor/rules/config-file-safety.mdc`: the line naming `scripts/setup-user-mcp.ps1` (settings.json) as "PowerShell merge" -> `- Settings sync (field-level review): \`scripts/setup-user-settings.sh\` via \`sync_managed_json\` (settings.json <-> profile.json)`; "Inline Node.js validation: `scripts/setup-user-mcp.sh`" -> "Inline Node.js validation: `scripts/setup-user-hooks.sh`". Verify: `grep -c "setup-user-mcp" .cursor/rules/config-file-safety.mdc` = 0.
- `.cursor/rules/sources-of-truth.mdc` (lacks 12 protected rows and the intent gate) is R12d.

### R8 — Abort

- **R8a1** (code PR `fix/abort-menu-text`; gate #106, #115, #116 merged): `scripts/aitools-lib.sh`, `scripts/aitools-lib.ps1`: drafts E1, E1b, E2, E2b (`edits-abort.txt`).
  Verify: `git grep -n "stop the run" -- scripts` = 0; `bash -n scripts/aitools-lib.sh`; pwsh parser on aitools-lib.ps1 (the Pre-validation convention in `.claude/rules/cross-platform.md`); `bash tests/managed-files/test-managed-files.sh`; `pwsh -NoProfile -File tests/managed-files/test-managed-files.ps1`; `bash tests/profile/test-lib.sh`.
  Audit: text and comments only; no logic change.
- **R8a2** (docs PR; gate R8a1 merged + G-P): `.claude/rules/interactive-menus.md` profile-mirror menu line `[x]abort    : stop the run` -> `[x]abort    : stop this script (exit 2)`; delete the clause `Despite the menu text,` and adjust the sentence that follows it so it still reads; `.cursor/rules/interactive-menus.mdc`: OLD `(the profile-mirror menu's "stop the run" text included)` NEW `(the profile-mirror menu included: its [x]abort ends this script, exit 2)`.
  Verify: `git grep -n "stop the run" -- .claude/rules .cursor/rules` = 0.
- **R8b** (code PR `fix/harness-relay-parity`; gate #106 and #116 merged; no decision needed: parity bug): `scripts/aitools-install.ps1`, `scripts/aitools.ps1`: drafts E6b, E4c (drop the 4th `"harness files"` argument to `Invoke-ChildRelayed`, as the .sh callers do). Re-pin after #116's installer conflict resolution.
  Verify: `bash tests/hookin/test-hookin.sh` (39/39 on the draft copy); pwsh parser on both. Audit: argument removal only; one row per outcome.
- **R8c** (gate Q6 = WARN; R8a1 + R8b merged). Code PR `fix/abort-warn-row`, three commits of <= 3 files:
  - c1: E3a-c (`scripts/aitools`), E4a-b (`scripts/aitools.ps1`).
  - c2: E5 (`scripts/aitools-install.sh`), E6 (`scripts/aitools-install.ps1`).
  - c3: relay R1, R1b, R2, R2b (`scripts/aitools-lib.sh/.ps1`), R3 (`scripts/aitools`); tests: `tests/profile/test-lib.sh` (`ERROR|child tool|aborted (exit 2)` -> `WARN|child tool|aborted by user`), `tests/profile/test-user-init.sh` (`ERROR|claude hooks|aborted (exit 2)` -> `WARN|claude hooks|aborted by user`), a new `tests/hookin/test-hookin.sh` case: a stub `setup-user-claude` exiting 2 gives `WARN|setup-user-claude|aborted by user`, later stubs still run, loop rc 0. (c3 touches 5 files; split tests into c4 if the reviewer asks.)
  - Docs (G-P), PR `docs/abort-warn-row` after the code merges: **R8c-d1** (after R2c) `.claude/rules/interactive-menus.md` OLD `exit 2 is handled like any failure.\n  The runner writes ERROR \`script failed (exit 2)\`` NEW `exit 2 is a user abort.\n  The runner writes WARN \`aborted by user\``; `.cursor/rules/interactive-menus.mdc` the matching clause; `reference/managed-file-deployment.md` the "[x]abort" table row whose cells say `` `validate_and_run` / `Invoke-ValidatedScript` treat it as a failure `` and `` `deploy_configs` / `Deploy-Configs` treat it as a failure ``: each -> `report it as WARN \`aborted by user\` and continue`. **R8c-d2** `reference/tool-support-decision-tree.md`: every row whose text says ERROR `script failed (exit 2)` for a non-harness script (`grep -n "script failed (exit 2)"`) -> WARN `aborted by user`; `plans/tool-support-and-machine-profile.md` T-Q3 note: the ERROR clause -> `an exit 2 from any other setup script is a WARN row \`aborted by user\` (changed by the commander, <date>, Q6)` — only if Q6 = WARN.
  - Verify: `bash tests/hookin/test-hookin.sh`; `bash tests/profile/test-lib.sh`; `bash tests/profile/test-user-init.sh`; `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/profile/test-user-init.sh --bash-only`; `pwsh -NoProfile -File tests/profile/user-init-harness.ps1` if it runs standalone (else Not run: Windows); `git grep -n "aborted (exit 2)" -- scripts tests` = 0.
  - Audit: no new suppressions; each abort path writes one WARN row (15 chars); errors counter untouched; `bash -n` + pwsh parser on every touched script; bash 3.2 (no associative arrays, no `${x,,}`). Residual risk accepted by D-TS13: a bash runtime exit 2 that is not an abort shows as WARN.
- **R8d** — #105 row 8 relay Intent (commander "1c) yes, re-draft"; gate R8c merged, or Q6 = ERROR; G-P because it is an intent statement). Code PR `docs/relay-intent`, files `scripts/aitools-lib.sh`, `scripts/aitools-lib.ps1`. Position: the row 8 draft's "Where" (`origin/docs/m3-approved-intents:.../S3-H2-DraftsM3b/S3-H2-DraftsM3b-drafts/scripts/aitools-lib.sh.edit.txt`: after the line ending `so installers and deploy-harness share one copy)`). First list the real consumers: `git grep -n "run_child_relayed\|Invoke-ChildRelayed" -- scripts`. Then insert (replace the Consumed-by list with the grep result; use `ERROR \`aborted (exit 2)\`` instead of the WARN clause if Q6 = ERROR):
  ```
  # Intent: give every parent script one way to run a child setup script and keep
  # its log in deploy.jsonl: show the child's console lines, mirror each structured
  # line to deploy.jsonl with JSON escaping, and count the child's warnings and
  # errors. NOT a copier of the child's lines to deploy.log (the child writes its
  # own; the relay logs one error for a failed child) and NOT a writer of the
  # child's own summary rows (given a summary tool name, it adds one row for a
  # child that wrote none: ERROR for a failure or a throw, WARN `aborted by user`
  # for exit 2). Consumed by: aitools-install.sh/.ps1 (their steps, Step 8b
  # deploy-harness included), the `aitools` / `aitools.ps1` deploy loop, and
  # `aitools user init`.
  ```
  Same text in the `.ps1` (`Invoke-ChildRelayed` named where the `.sh` names `run_child_relayed`, if the text names a function). Verify: `bash -n`, pwsh parser; `grep -c "Consumed by: aitools-install" scripts/aitools-lib.sh scripts/aitools-lib.ps1` = 1 each.

### R9 — `--alias` claim needs a confirm (code PR `fix/user-init-claim-confirm`)

Gate: Q7 = suggested; R8c merged (or R8 finished without R8c).
- **R9a** `scripts/aitools`, `scripts/aitools.ps1`, `tests/profile/test-user-init.sh`: drafts E7a, E7b, E8 (`edits-claim.txt`), T1, T2 (`edits-test.txt`). Also:
  - help line in both files, OLD `user init --alias A  Same, registering this machine as profile A without a prompt` NEW `user init --alias A  Same, registering this machine as profile A without a prompt (a confirm on a terminal if A names a profile no machine owns)`.
  - sh comment OLD `# aitools user init --alias <alias>: register this machine without a prompt (P-Q12)` NEW `# aitools user init --alias <alias>: register this machine without a prompt (P-Q12), unless the alias names a profile no machine owns (then a confirm on a terminal)`.
  - ps1 comment, two lines, OLD `# aitools user init --alias <alias> / -Alias <alias>: register this machine without a\n# prompt (P-Q12).` NEW `# aitools user init --alias <alias> / -Alias <alias>: register this machine without a\n# prompt (P-Q12), unless the alias names a profile no machine owns (then a confirm).`
- **R9b1** `scripts/aitools-profile.sh`, `scripts/aitools-profile.ps1`: the `--claim` comments "only after the user picked KEY at a terminal" -> "only after the user picked or confirmed KEY at a terminal".
- **R9b2** `scripts/aitools`, `scripts/aitools.ps1` (the "Decision 2 (PENDING with the commander" comments -> "Decision 2 (decided 2026-10-23, keep asking; plans/tool-support-and-machine-profile.md M3Lead-2"), and `reference/user-repo.md` (G-P): AnsB's "If he takes the suggested answer" bullet text (re-check the ERROR row text against the shipped code: `not claimed (no terminal)`).
- Verify: `bash tests/profile/test-user-init.sh` (216/216 on the draft copy), `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/profile/test-user-init.sh --bash-only` (115/115), `bash tests/profile/test-profile.sh`, pwsh parser on all `.ps1`.
- Audit: each `log_error` pairs with an ERROR row + ACTION; declined confirm = WARN `skipped`, return 2; `--force` = no terminal; no suppressions.

### R10 — `aiToolingRepoPath` migration moves into the writer (code PR `fix/config-legacy-key`)

Gate: Q8 = suggested; R9 merged.
- **R10a** `scripts/setup-user-config.sh`, `scripts/setup-user-config.ps1`: drafts E11, E12, then:
  - In E11's NEW, replace the line `        log "config: legacy key aiToolingRepoPath migrated to repoPath and removed"` with
    ```
            if $DRY_RUN; then
                log "config: legacy key aiToolingRepoPath would be migrated to repoPath and removed (dry run)"
            else
                log "config: legacy key aiToolingRepoPath migrated to repoPath and removed"
            fi
    ```
    and in E12's NEW, `        Log "config: legacy key aiToolingRepoPath migrated to repoPath and removed"` with
    ```
            if ($DryRun) {
                Log "config: legacy key aiToolingRepoPath would be migrated to repoPath and removed (dry run)"
            } else {
                Log "config: legacy key aiToolingRepoPath migrated to repoPath and removed"
            }
    ```
  - Headers. sh OLD `# Managed fields: version, meta, reposPath, repoPath (from flags; kept when not passed),` NEW `# Managed fields: version, meta, reposPath, repoPath (from flags; kept when not passed; else\n#   from the legacy key aiToolingRepoPath, which is then removed),`. ps1 OLD `# Managed fields: version, meta, reposPath, repoPath (from parameters; kept when not passed),` NEW `# Managed fields: version, meta, reposPath, repoPath (from parameters; kept when not passed; else\n#   from the legacy key aiToolingRepoPath, which is then removed),`.
- **R10b** `scripts/aitools`, `scripts/aitools.ps1`: drafts E9, E10 (read-only fallback + pre-lib warning).
- **R10c** docs (G-P): `reference/user-repo.md`: remove AnsB H's "(Known exception, to be removed: ...)" parenthesis.
- Verify: `bash tests/profile/test-config.sh` (190/190 on the draft copy); the isolated-HOME legacy test (copy `/Users/new-jose/repos/aitools/.scratch/session-rccode/test-legacy.sh` into the worktree scratch; on another machine rebuild it from RC/Code 5.2: config.json with only `aiToolingRepoPath` -> `repoPath` set, old key gone, other keys kept, one backup; both keys -> `repoPath` kept, old key removed); a new `tests/logging/test-logging.sh` case: config.json with only `aiToolingRepoPath` -> the pre-lib warning, file hash unchanged; `bash -n`, pwsh parser.
- Audit: `cfg_get` checks its rc and treats failure as absent; `del` only when the key exists; the dry-run branch writes nothing; the entry points no longer write config.json at all (single writer, SD-7); no new suppressions.

### R11 — Step 7: input-changing pushes WARN (code PR `fix/pre-push-step7-branch`)

Gate: Q5 = suggested; MERGE-ALL's rebuild done (main itself green on step 7).
- `scripts/check-pre-push.sh`, `scripts/check-pre-push.ps1`: drafts E13a-c, E14a-c (`edits-step7.txt`); next to each input regex add the comment `# Keep in sync with the add_source / for cli in lines of scripts/deploy-harness.sh (its sources are deploy/ inputs).` `reference/pre-push-checklist.md` step 7 line, append: `A difference caused by this push's own deploy/ inputs is a WARN (rebuild after the merge); staleness on a push that changes no input, a failed build and a failed smoke run FAIL.`
- Audit: E13a's `... | tr ... ) || d7_inputs=""` is commented in the draft; a grep failure yields an empty list, which keeps the stricter FAIL (fail-safe); no other suppressions; `bash -n` + pwsh parser; the ps1 uses `-cmatch` (case-sensitive, like `grep -E`).
- Risks: the regex duplicates deploy-harness's source list (drift; file an incident to derive it from `deploy-harness.sh`); on an input-changing push, staleness not caused by the push (main already drifted) is also WARN — visible, because the WARN names the differing files.
- Verify (from the worktree, after MERGE-ALL's rebuild): on the R11 branch, WARN (it changes `reference/pre-push-checklist.md`, a deploy/ input); on a scratch branch off main touching only `scripts/check-pre-push.sh` (not in the input regex) -> PASS; on a scratch branch touching `shared/rules/scratch.md` -> WARN.

### R12 — Other false statements (item 8) (PR `docs/reconcile-misc`; one commit per sub-batch)

Gate: G-P. Pull and re-read first (BUILD-PKG pending edits, 5.1).
- **R12a** `reference/agentic-framework.md` (D-19: the "Deploy state migration" section body -> `Removed 2026-10-21: there is no deploy state, shadow or ancestor (\`@reference/managed-file-deployment.md\` "Deploy State").`); `reference/logging.md` (drop "deploy-state" from the namespace list); `reference/pre-commit-checklist.md` (D-15: step 3 and step 10 texts in RC/Docs D-15).
- **R12b** `.claude/rules/git-safety.md`, `.cursor/rules/git-safety.mdc` (D-16: the "deploy/ is ephemeral" section -> the "deploy/ is frozen" text in RC/Docs D-16). `CLAUDE.md` (direct to main, own commit): OLD `\`deploy/\` — generated by \`build-deploy.sh\`; ephemeral, reset on each \`aitools\` run.` NEW `\`deploy/\` — frozen historical baseline (\`build-deploy.sh\` writes \`<userRepoPath>/deploy/\` in the dotprofile repo); reset to HEAD on each \`aitools\` run.`
- **R12c** `.claude/rules/tool-lifecycle.md`: delete the bullet `- \`CLAUDE.md\` — deploy list`; `.cursor/rules/tool-lifecycle.mdc`: delete the bullet `- \`CLAUDE.md\` — add \`setup-<tool>\` to "Deploy using MDM" tool scripts list` (one per file; no such list exists); `README.md` (not protected): both lines saying pre-commit "12 steps" -> "20 steps"; both lines saying post-push "all 20 steps" -> "32 steps" (the last `# N.` step header in `scripts/check-post-push.sh`; re-count before editing); the githook sentence "regenerates `deploy/`" -> "rebuilds the dotprofile `deploy/` (and stages the frozen `aitools/deploy/`, see Q11)". ROADMAP.md: add an In Progress row `| Deployment reconciliation | plans/fan-plan-reconciliation.md | High | Docs, code and decisions in the deployment area (fan-out, ANSWER-1A/1B, parity, abort, step 7, ledger) |`.
- **R12d** after MERGE-ALL's sources-of-truth.md change: `.cursor/rules/sources-of-truth.mdc` gets the protected rows the `.md` has and its review rule (or MERGE-ALL's review-after text), if MERGE-ALL did not.
- Verify per file: grep that the old phrase is gone; `bash scripts/check-pre-commit.sh`.

### R13 — Incident ledger (via the `/incident` skill; one PR per batch)

Source: RC/S3-Reconcile-Ledger-findings.md (tables with evidence). Gate: MERGE-ALL has applied #146-#170; Q13; G-P.
1. **Parse the whole file first** (`python3` + `json`: max id over `incidents` and `closed`, duplicates). Expected next id #171; if not, renumber the drafts in order.
2. **L0 (no new ids):** close 17 (#129, #130, #84, #93, #114, #115, #122, #75, #97, #78, #95, #98, #109, #110, #99, #111, #145) with `closedIn` "PR #N (commit)" from the Ledger table (version added at the v0.74.0 tag); update 8: #74, #76, #77, #102, #116, #144 (correctiveAction "PR #60 (open)" -> "PR #60 (merged 845a935)"), #87 (its resolution prescribes the reversed D-TS13 marker), #112 (`affected` + `shared/cursor-rules/user-rules.md`; close it once R6 step 1 has merged). #102's apply script only appends: write a scratch close/update script (python3; back up first; refuse if an id is missing; validate the JSON after), run it, then run the `/incident` skill's validation on the result, diff, review.
3. **L1-L5:** file the 47 new incidents (#171-#217 provisional) in id order, 10 per PR: L1 #171-#180, L2 #181-#190, L3 #191-#200, L4 #201-#210, L5 #211-#217. Before filing, verify the five "to verify" candidates (Ledger section 4.4) in code. Add the markers in section 8 below that the Ledger list lacks (check by title), skipping any closed by a merged batch here (e.g. parity after R7, decision 2 after R1).
4. Verify each PR: the skill's validation; `python3` parse; ids contiguous; no duplicate titles.

### R14 — Hand-off to FAN-PLAN's doc batch

When FAN-PLAN's code PR (its Batches B-D) merges, its section 7 drafts replace R2/R3's "today" texts. Write a note in the executing SC's mission folder (direct to main) and send it to FAN-PLAN's executor: its draft OLD blocks for `.claude/rules/managed-file-deployment.md`, `reference/harness.md`, `reference/managed-file-deployment.md`, `.claude/rules/hook-rollout.md` and `.claude/rules/deploy-paths.md` must be re-anchored on R2/R2c/R3/R4's merged text; `.claude/rules/aitools-workspace.md`, `.cursor/rules/hook-rollout.mdc` and `shared/skills/scratch/SKILL.md` need a flip it does not draft (to "copied to `~/.claude/rules/` by `setup-user-claude` and converted into `~/.cursor/rules/*.mdc` by `setup-user-cursor`"). FAN-PLAN's reviewer RC-1 (PowerShell `Backup-File` wildcard) is fixed on main by 9923a3c; that reviewer tested #112's head, which lacks it — re-test after rebase. The `build-deploy.sh` comment "setup-user-cursor (and the other rules fan-out consumers) read ~/.aitools/rules" becomes true with FAN-PLAN Batch C.

---

## 7. First actions for the executing Session Commander

1. Read the mission packet and its section 1, this plan, RC/S3-Reconcile-report.md, RC/S3-Reconcile-Review-verdict.md and RC/S3-Reconcile-Barrier-results.md. `git -C /Users/new-jose/repos/aitools pull --ff-only`.
2. Check the world: `gh pr list -R nobul-tech/aitools --state open`; MERGE-ALL's non-PR steps in `git log --oneline origin/main`; FAN-PLAN's plan on main (`git ls-tree origin/main plans/rules-fanout-claude.md`) or its draft path; G-P (Q1 commands).
3. Send the commander section 4 (Q1-Q15 with suggested answers) in one message. Do not wait for the answers to start R13-pre and R6 step 1.
4. Do R13-pre now (before #102 is applied).
5. As each gate in 5.3 opens, launch one fresh delegate per batch with the 6.0 contents; independent reviewer per PR; spot-check every diff against this plan.
6. Keep a running estimate in your mission folder; at the end append a relay entry (`.aitools/channel/relay.md`, direct to main).

---

## 8. INCIDENT markers raised by this mission (not filed; R13 files them)

- Pre-push step 7 FAILs every PR branch that changes a deploy/ input, by construction (`scripts/check-pre-push.sh` / `.ps1` step 7). Medium.
- #106 PS1 passes `"harness files"` to `Invoke-ChildRelayed`, sh does not: duplicate rows. Medium.
- Exit 2 reported three ways (#106 runners, #115 relay, #106 deploy-harness). Medium (ambiguity).
- Profile-mirror menu text `[x]abort : stop the run` is false. Low.
- `aitools user init` claims an unowned profile named by `--alias` without asking (`ui_register` / `Invoke-UiRegister`). High (Ledger draft #191).
- Entry points write config.json without backup or validation (`aiToolingRepoPath` rename). Low-medium.
- Protected docs claim a setup-user-claude `~/.aitools/rules` fan-out that does not exist. Medium (closed by R2/R3).
- Pre-commit step 3 `--fix` and `scripts/githooks/pre-commit` stage the frozen `aitools/deploy/`. Medium.
- deploy-harness adopts into the dotprofile are not committed and pushed (N-Q2). Medium.
- `.cursor/rules/sources-of-truth.mdc` lacks 12 protected rows and the intent gate. Low.
- Parity record contradicts itself. Low (closed by R7).
- Channel exception written in one place. Medium.
- Decision 2's answer recorded nowhere; S3-M3Lead plan and `scripts/aitools` comments say PENDING. Low (closed by R1/R9b2).
- `reference/managed-file-deployment.md` "hostname match, then first profile". Medium (closed by R2c).
- The #105 row 8 relay Intent redraft had no owner (MERGE-ALL assigned it here). Medium (closed by R8d).
- Every open PR branch carries the old step-7 trigger in its own check-pre-push; pre-pushing from an un-rebased worktree gives the old behaviour. Low.
- The packet's "pre-push step 7 (dotprofile deploy/ stale)" known-failure note understates it. Low.
- Pre-commit step 20 does not catch a repo path cited bare in parentheses (barrier test). Low.
- A full-tree export under the repo's `.scratch/` is loaded as project context by Claude Code and is harvester input (barrier test; `.scratch/session-rcbar/tree`). Low.

---

## 9. Not run (by the planner)

No repo file outside this plan and the mission folder was changed. Nothing ran against the real HOME; the code drafts were applied to scratch copies and their tests run under isolated HOMEs (RC/Code): test-user-init 216/216 and 115/115 (bash 3.2), test-config 190/190, test-hookin 39/39. Not run: the relay drafts against #115/#116's tests; any `.ps1` suite; Windows; Linux. The barrier test applied R1 (v1.0 text: failed, fixed in v1.1), R2a and R6 to an export of origin/main 32bf20c.

## 10. Provenance

Research delegates: S3-Reconcile-Trans, -Git, -Docs, -Code, -Ledger. Independent review: S3-Reconcile-Review (APPROVE WITH CHANGES; 13 required changes, all applied in v1.1). Barrier test: S3-Reconcile-Barrier (PASS WITH FIXES; 13 fixes, applied in v1.1). Files in RC/. Commander words: section 3 and RC/S3-Reconcile-Trans-findings.md. MERGE-ALL decisions: `.../S3-MergeAll/S3-MA-Brief-brief.md` (main b40a320). FAN-PLAN: its draft plan and `S3-FanPlan-Review-verdict.md`, `S3-FanPlan-report.md`.
