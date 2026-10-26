# Plan: reconcile code, docs and decisions in the deployment area (fan-out, ANSWER-1A/1B, parity, abort, step 7, incident ledger)

**Version:** v1.0, 2026-10-26. **Author:** S3-Reconcile (orchestrator, level 1, delegated by Session Commander 10cf255a-c; commander Jose). **Status:** executable. Nothing here is implemented yet.

**Intent**: **Purpose**: Give the next executing Session Commander a plan it can run without asking anyone, which resolves every pending reconciliation item between the code, the docs and the commander's recorded decisions in the deployment area, starting with: should `setup-user-claude` be updated, or the docs, or both, and which files change. **Scope**: items 1-8 of mission RECONCILE (section 2), the commander decisions they rest on (section 3), the batches that change docs and code (section 6), their order against open PRs and running missions (section 5), and the open questions only the commander can answer (section 4). NOT executing the plan. NOT the setup-user-claude fan-out refactor itself (FAN-PLAN's plan `plans/rules-fanout-claude.md`). NOT merging the open PRs, the dotprofile `deploy/` rebuild, the #102 incident apply, D-DEL5 or the v0.74.0 release (mission MERGE-ALL). NOT re-litigating recorded decisions. **Audience**: the executing Session Commander and its delegates; the commander, who answers section 4.

Evidence for every claim is in the mission folder
`.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Reconcile/`
(abbreviated **RC/** below): `S3-Reconcile-Trans-findings.md` (commander
words), `S3-Reconcile-Git-findings.md` (PRs, merge order),
`S3-Reconcile-Docs-findings.md` (false doc statements D-1..D-25, parity),
`S3-Reconcile-Code-findings.md` (code facts, tested drafts),
`S3-Reconcile-Ledger-findings.md` (incident sync), `S3-Reconcile-Code-drafts/`
(verbatim code edits + `apply.pl`), the independent review and barrier test
verdicts, and `S3-Reconcile-report.md`. The AnsA/AnsB reports are on main
(8e18ad4): `.../S3-AnsA/S3-AnsA-report.md`, `.../S3-AnsB/S3-AnsB-report.md`.

---

## 1. Summary

1. **Fan-out (item 1): both, sequenced.** Code: `setup-user-claude` gets the `~/.aitools/rules` fan-out through FAN-PLAN's plan (the commander ordered it: "put aitools rules in the user space of claude code", 2026-10-23T01:58:29Z). Docs: the five protected docs that claim the fan-out already exists are corrected **now** to describe today, with wording that names the coming change, and flipped to the final wording by FAN-PLAN's own doc batch when its code lands (batches R2, R3; FAN-PLAN section 7).
2. **ANSWER-1A (item 2):** apply AnsA Q1b, Q2, Q3 (Q4 already landed with #99). Q1's text is **rewritten** here: since 8e490d7 step 7 always runs, so AnsA's "triggers only on the `shared/` ones" is false (R4).
3. **ANSWER-1B (item 3):** apply AnsB edits A, B, D, E, F, G, I, J and the glossary "profile" fix; edit C depends on a code fix the plan carries (R9, Q7); edit H is documented now and removed by a code change (R10, Q8); decision 2's answer ("1) yes") is recorded in the decision log (R1).
4. **Parity (item 4):** the commander killed the parity mandate himself (2026-03-13, 2026-03-15); remove the leftover mandate, keep and correct the twins that exist (R7, Q9).
5. **Abort (item 5):** fix the profile-mirror menu text (no decision needed: the text is false); fix the #106 PS1 duplicate-row parity bug; changing a non-harness abort from ERROR to WARN needs the commander's yes (R8, Q6).
6. **Step 7 (item 6):** no doc still describes the old trigger (verified); the open problems are the false AnsA Q1 text (R4) and that every PR branch that changes a deploy/ input FAILs step 7 by construction even after the rebuild (R11, Q5). The rebuild itself is MERGE-ALL's (A4).
7. **Incident ledger (item 7):** after MERGE-ALL applies #146-#170: close 17, update 6, file 47 new (#171-#217, provisional) in id order (R13).
8. **Other disagreements (item 8):** 15 more false or stale statements and 4 code deviations, batched in R12 or filed as incidents.

---

## 2. Items and resolutions (one table; batches in section 6)

| # | Item | Resolution | Code / docs | Files | Batch | Gate |
|---|---|---|---|---|---|---|
| 1 | False "setup-user-claude fans out ~/.aitools/rules" claims | Correct to "today" now; FAN-PLAN flips them | both | `.claude/rules/managed-file-deployment.md` + `.mdc`, `.claude/rules/aitools-workspace.md`, `reference/harness.md`, `reference/managed-file-deployment.md` (Q2), `.claude/rules/hook-rollout.md` + `.mdc`, `shared/skills/scratch/SKILL.md`; code: FAN-PLAN | R2, R3; FAN-PLAN | G-P, Q2 |
| 2 | ANSWER-1A (Q1, Q1b, Q2, Q3, Q4) | Q1 rewritten; Q1b, Q2, Q3 applied; Q4 done (#99 merged 3c4f8fe) | docs | `.claude/rules/deploy-paths.md` + `.mdc`, `reference/managed-file-deployment.md`, `shared/cursor-rules/user-rules.md` | R4, R2c, R6 | G-P (Q3: approved) |
| 3 | ANSWER-1B (A-J, glossary, C, H, decision 2) | Apply A,B,D-G,I,J, glossary; C after R9; H now, then R10; decision 2 recorded | both | `reference/user-repo.md`, `registries/glossary.json` (via `/glossary`), `plans/tool-support-and-machine-profile.md`; code R9, R10 | R5, R1, R9, R10 | G-P, Q7, Q8 |
| 4 | .mdc parity | Remove the mandate; keep and fix existing twins | docs | `.cursor/rules/cursor-rule-parity.mdc` (delete), `reference/cursor-practices.md`, `.cursor/rules/documentation-standards.mdc`, `.cursor/rules/config-file-safety.mdc` | R7 | G-P, Q9 |
| 5 | Abort follow-ups | Menu text fixed; PS1 relay parity fixed; WARN row gated | both | `scripts/aitools-lib.sh/.ps1`, `.claude/rules/interactive-menus.md` + `.mdc`; gated: `scripts/aitools`, `aitools.ps1`, `aitools-install.sh/.ps1`, relay in the lib, tests | R8a, R8b, R8c | R8c: Q6 |
| 6 | Step 7 always runs | Docs already true except AnsA Q1 (R4); PR-branch FAIL gated | both | `scripts/check-pre-push.sh/.ps1`, `reference/pre-push-checklist.md` | R11 | Q5 |
| 7 | Incident ledger | L0 close/update, L1-L5 new | data | `registries/incidents.json` (via `/incident`) | R13 | G-P, Q13 |
| 8 | Other | R12 docs; code deviations filed (R13) | both | see R12 | R12 | G-P |

---

## 3. Commander decisions this plan relies on (newest first)

Verbatim; session 10cf255a-c unless stated; uuids and line numbers in RC/S3-Reconcile-Trans-findings.md and the MERGE-ALL brief (`.../S3-MergeAll/S3-MA-Brief-brief.md`, main b40a320).

| When (UTC) | Words | What it settles here |
|---|---|---|
| 2026-10-26T22:59:58Z (MERGE-ALL A2) | "User rule + skill; review after (Recommended)" — "Protected files: written as a version and committed; you review the commit/PR diff instead of a pre-write draft." | Gate G-P below: once MERGE-ALL lands the review-after change in `.claude/rules/sources-of-truth.md`, this plan's protected edits ship as versions and are reviewed after |
| 2026-10-26T22:59:58Z / 23:01:36Z (MERGE-ALL A1, A4, A5) | "merge commits, mission merges, in the correct order, and checks after each step"; dotprofile deploy/ "do a backup of the deploy and then do a rm -rf if necessary (the mission, not me the commander)"; "Same, and the mission tags" | MERGE-ALL merges the 19 PRs, rebuilds the dotprofile deploy/, applies #102, tags v0.74.0. This plan does not do those things; it waits for them |
| 2026-10-26T22:42:03Z (b277b82b) | "Every pending item (Recommended)"; FAN-PLAN: "Launch now, consume it" | RECONCILE's scope; consume FAN-PLAN |
| 2026-10-26T22:39:56Z (0e1119a1) | "1) q1c pre-push step 7 should always run before pushing. update docs/rule/reference file as necessary"; "no drafts, the produced plan should be executable by another sessions, it should be version 1.0"; "the plans directory should skip worktrees/prs ... thats a decision" | Step 7 always runs (8e490d7). This plan is v1.0. plans/ goes direct to main |
| 2026-10-26T22:17:19Z (474446b2) | "2) update the docs to match the current implementation of PR #106. lets keep functionality, update docs on whatever current state is"; "3) approved, add this to aitools project CLAUDE.md file. project claude.md also bypassess worktrees etc" | Abort: keep #106's stop rule; docs describe the current state (the principle R2/R3 apply to the fan-out docs). Channel exception |
| 2026-10-26T21:58:13Z (cb1f0201) | "1d) approved" (the #99 `.mdc` twin), "1e) approved" (Manifest/Cursor/MDM doc drafts, after a reviewer checks them against merged code), "3) sure" (row 6), "6) re-factoring setup-user-claude and the fan-out requires a mission to create a plan" | R4 may apply #111's MDM deploy-paths edits; R2 applies the Manifest drafts (reworded per D-1, review-after) |
| 2026-10-24T22:45:50Z (c86608ca) | "1) protected drafts approved. 2) dotprofile pushes outside of main branch should error out 3) logging suggestions all accepted" | #146-#170 approved; #165 must say ERROR |
| 2026-10-23T01:58:29Z (e073aea3) | "1) yes" (cached alias with no machine id: keep asking on a terminal, ERROR without one); "3) put aitools rules in the user space of claude code"; "4) approved" (`%USERPROFILE%\repos` everywhere) | Decision 2 (R1); fan-out ordered; AnsA Q3 approved |
| 2026-10-23T02:01:33Z (0527e51d) | "protected drafts approved." (covers #96 row 3: `--claim` only "after the user picks that profile at a terminal") | AnsB C: the code deviates (R9) |
| 2026-10-22T00:04:12Z (65461507) | "hooks/ is populated with all of shared/hooks and .claude/hooks" | AnsA Q1b |
| 2026-03-15T03:33:46Z (b6a51f29, uuid 7ab38b9f); 2026-03-13T22:17:58Z (bdf5e181, uuid 4062135d) | "we dont care about rule parity anymore kil that test"; "lets kill the cursor rule parity ... they need to be tracked and managed seperately" | Item 4 (R7) |
| 2026-10-20 (handoff 360aa8f3-8 D.3, SD-7) | config.json "has exactly one writer (setup-user-config)" | AnsB H (R10) |

Not decisions (agent text only): "Cursor user-level only" (the SC's reading of "3)"; Q3); D5 "fan out aitools project rules" scope (Q4).

---

## 4. Open questions for the commander (answer in one message; each has a suggested answer)

The executing commander asks these **before R8c-R11** and before R2/R3 if Q2 is "no". Batches not gated by a question proceed.

- **Q1. Protected-file gate.** MERGE-ALL A2 makes protected files "review after". Until MERGE-ALL commits that change to `.claude/rules/sources-of-truth.md`, the rule text still says pre-write review. *Suggested:* start the protected batches only after that commit is on main (check: `git -C /Users/new-jose/repos/aitools grep -n -i "review" origin/main -- .claude/rules/sources-of-truth.md` shows the review-after text); ship each as a version with a "Review after" section in the PR body. If you want them sooner, say "apply now under A2".
- **Q2. Fan-out docs now, or wait for FAN-PLAN's code?** *Suggested:* now (R2/R3), describing today with "once it fans out" wording; your 22:17:19Z principle is "update docs on whatever current state is", and FAN-PLAN needs #106 + its own review before it lands.
- **Q3. Cursor gets user-level rules only (#110)?** Your "3)" did not say it; the SC read it in. *Suggested:* yes (project `.claude/rules` are "(this repo)" rules and would load in every Cursor chat).
- **Q4. FAN-PLAN Q1: does Claude Code get the aitools project `.claude/rules` at user level?** Measured: 17 of 26 have no `paths:`, ~79 KB (~20k tokens) loaded in every session in every repo, loaded twice inside aitools, and `sources-of-truth.md`/`script-standards.md` would govern every repo (FAN-PLAN section 8 R1). *Suggested:* no: fan out `shared/rules` + dotprofile `claude/rules` (FAN-PLAN's costed variant, about +15 lines per language), same as Cursor. This is FAN-PLAN's gate RC-3; answering it here unblocks both plans.
- **Q5. Step 7 on PR branches.** Step 7 builds from the pushed branch and compares with the dotprofile `deploy/` built from main, so every branch that changes a deploy/ input (16 of the 19 PRs) FAILs even right after the rebuild (RC/Code 2.4). *Suggested:* apply R11: still always runs; "stale because this push changes deploy/ inputs" becomes WARN with the rebuild instruction; FAIL stays for build/smoke failure and for staleness on a push that changes no input.
- **Q6. A user abort in a non-harness script: ERROR `script failed (exit 2)` or WARN `aborted by user`?** Today three conventions exist (#106 runners ERROR `script failed (exit 2)`, #115/#116 relay ERROR `aborted (exit 2)`, #106 deploy-harness WARN `aborted by user`). Your 22:17:19Z "lets keep functionality" kept the stop rule; the row text was never asked. *Suggested:* WARN `aborted by user` everywhere, run continues, only deploy-harness stops (R8c).
- **Q7. AnsB C: should `aitools user init --alias X` claim a profile no machine owns without asking?** Today it does, with or without a terminal, against the row-3 text you approved. *Suggested:* no: confirm on a terminal, ERROR + ACTION without one (R9); a brand-new alias stays prompt-free.
- **Q8. AnsB H: the entry points' `aiToolingRepoPath` rename writes config.json without backup or validation.** *Suggested:* move it into `setup-user-config` (backup + validation), entry points read only (R10). Deleting it alone would make the writer ERROR on a legacy machine.
- **Q9. Parity.** *Suggested:* delete `.cursor/rules/cursor-rule-parity.mdc` and the parity sections (your March words); an existing `.mdc` is corrected when it is false, and a new twin is made only when you ask for it (as with "1d").
- **Q10. Timing against v0.74.0.** *Suggested:* the docs batches (R1-R7, R12) land before the v0.74.0 tag and the RELEASE mission's docs scrub takes this plan as its input for these files (no double edits); code batches R8-R11 may land after (v0.74.1) if they would hold the tag.
- **Q11. Pre-commit steps 3 and 10 still `git add` the frozen `aitools/deploy/`** after building into the dotprofile (RC/Docs D-15). *Suggested:* drop the `git add deploy/` and make step 3 a WARN that names the dotprofile rebuild; step 7 is the real check. File it (R13) and fix in a follow-up PR.
- **Q12. deploy-harness adopts into the dotprofile are not committed and pushed (N-Q2 is binding).** *Suggested:* code fix in a follow-up PR; file it (R13).
- **Q13. Incident batches L0-L5.** *Suggested:* one review page, review after (A2), then L0..L5 PRs in id order.
- **Q14. Channel exception "in all four places"** (your 22:17:19Z answer named four places; only `CLAUDE.md` has it). *Suggested:* MERGE-ALL's D-DEL5 batch (it edits the same `delegation.md` and `/delegate` skill) adds it to `~/.claude/rules/delegation.md` and the `/handoff` skill; R12 adds a pointer in `aitools-workspace.md`.

---

## 5. Dependencies and order

### 5.1 Who owns what (do not overlap)

| Mission | Owns | This plan's relation |
|---|---|---|
| MERGE-ALL (brief main b40a320) | Merging all open PRs in its order (#99, #101, #105, #104, #97, #102, #103, #98, #108, #114, #109, #113, #112, #100, #110, #111, #115, #106, #116); #102 apply (#146-#170); #74/#75 re-land; #111 `--skip-config` in Step 8b; #103/#108/#105 approved drafts; D-DEL5 + sources-of-truth review-after; build-deploy backup-then-swap + dotprofile `deploy/` rebuild; `plans/merge-friction-improvements.md`; RELEASE v0.74.0 + docs scrub + tag | Every batch here starts only after the MERGE-ALL merge step it names. Hand MERGE-ALL the two #102 amendments in R13-pre before it applies #102 |
| FAN-PLAN (`plans/rules-fanout-claude.md`, drafts in `.../S3-FanPlan/S3-FanPlan-drafts/`) | setup-user-claude fan-out code, build-deploy MDM counterpart, `tests/rules-fanout/`, its doc drafts (deploy-paths, managed-file-deployment, user-repo, harness, hook-rollout, config-file-safety, tool-ops-claude-code) | R2/R3 change some of the same lines first ("today"); FAN-PLAN's doc batch then re-anchors on R2/R3's text (section 6.R14) |
| BUILD-PKG (`plans/build-package/`) | package distribution; edited platform lists in `aitools-workspace.md`, `reference/harness.md`, `shared/cursor-rules/user-rules.md`, `.cursor/rules/cross-platform.mdc` (main 5494d93) | Re-read those files before R2b/R6; do not touch `plans/build-package/` |

### 5.2 State at plan time (verify before each batch)

origin/main 3c4f8fe (#99 merged by MERGE-ALL); main checkout 5494d93 (BUILD-PKG). Open: #97, #98, #100-#106, #108-#116. Check each gate with
`gh pr view <n> -R nobul-tech/aitools --json state,mergeCommit --jq ".state"` (MERGED expected).

### 5.3 Batch order

```
R1 (now; direct to main)
R13-pre (now; message to MERGE-ALL before it applies #102)
--- after MERGE-ALL: #101 merged ---------------> R5
--- after #99 (done) + BUILD-PKG edits pulled --> R6
--- after #100 + #110 merged -------------------> R2a, R2b
--- after #103 helper-contract draft applied by MERGE-ALL --> R2c
--- after #111 merged --------------------------> R4
--- after G-P (Q1) -----------------------------> R3, R7, R12 (any order; disjoint files)
--- after #106, #115, #116 merged --------------> R8a, R8b; R8c (Q6)
--- after #116 merged --------------------------> R9 (Q7), then R10 (Q8; same files)
--- after MERGE-ALL rebuild (A4) ---------------> R11 (Q5)
--- after #102 applied -------------------------> R13 L0, L1..L5
--- after FAN-PLAN code merges ----------------> R14 (FAN-PLAN's doc flip)
```

---

## 6. Batches

### 6.0 Rules for every batch

- **Shipping.** Channel-exception paths (`plans/*`, `.aitools/channel/handoffs/*`, `.aitools/channel/relay.md`, `CLAUDE.md`) go direct to main from the main checkout: `git -C /Users/new-jose/repos/aitools pull --ff-only`, stage only the batch's paths (never `git add -A`: the checkout holds other missions' untracked folders and harvesting files), `git commit -F <scratch msg>` ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, `git push origin main`; a non-fast-forward pull = stop and report. Everything else: a worktree off origin/main (`git -C /Users/new-jose/repos/aitools worktree add -b <branch> /Users/new-jose/repos/aitools/.claude/worktrees/<short> origin/main`), commit, `bash scripts/check-pre-commit.sh` and `bash scripts/check-pre-push.sh` from the worktree (known: pre-commit step 6 FAIL; pre-push step 7 FAIL until MERGE-ALL's rebuild, and on input-changing branches until R11), `git push -u origin <branch>`, `gh pr create -R nobul-tech/aitools --base main --head <branch> --body-file <scratch>/pr-body.md` with sections Summary; Why; Changes; Verification; Not run; Review after (protected files); Follow-ups; ending `🤖 Generated with [Claude Code](https://claude.com/claude-code)`. Who merges: the commander, or MERGE-ALL if he extends A1 to these PRs (ask in the Q-message).
- **Delegation.** One fresh sub-agent per batch (plan-execution.md: code batches and any lib change). Its prompt carries the seven duty elements (`/delegate`), the packet path `/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/SC-mission-packet.md`, this plan's path and batch id, the error-handling block from `reference/plan-execution-detail.md` "Error-handling rules (non-negotiable)" verbatim, its name prefix (`S3-RX-<batch>-`), and D-DEL4 shipping terms. An independent reviewer (separate delegate, no access to the implementer's notes) posts its verdict on the PR with `gh pr review <n> --comment --body-file <file>`.
- **Anchors, not line numbers.** Lines move (MERGE-ALL, BUILD-PKG and FAN-PLAN all commit to main). Every OLD below is a unique substring; before editing, confirm it occurs exactly once (`grep -c -F`). If it does not, re-read the file and re-anchor; never guess.
- **Code drafts** are in `RC/S3-Reconcile-Code-drafts/edits-*.txt` (`@@@FILE <base>/<file>`, `@@@OLD`, `@@@NEW`, `@@@END`). Map the base prefix: `main/aitools` -> `scripts/aitools`, `main/aitools.ps1` -> `scripts/aitools.ps1`, `main/setup-user-config.*` -> `scripts/setup-user-config.*`, `main/aitools-lib.*` -> `scripts/aitools-lib.*`, `main/check-pre-push.*` -> `scripts/check-pre-push.*`, `pr106/aitools-install.*` -> `scripts/aitools-install.*`, `pr106/aitools*` -> `scripts/aitools*`, `pr115/aitools-lib.*` -> `scripts/aitools-lib.*`, `pr115/aitools-116` -> `scripts/aitools`, `tests/...` as is. Apply with a copy of `apply.pl` after rewriting the FILE prefixes in a scratch copy of the edits file (Perl), into a scratch output dir, diff, then copy the files into the worktree. `apply.pl` dies when an OLD is not found exactly once: then re-pin that block against the merged code and record it in the PR body.
- **Docs:** never cite line numbers in rules/references (documentation-standards.md); cite functions.
- **Notation in inline OLD/NEW:** text after `OLD:` / `NEW:` on one line is written between the outer backticks; inside it, `\`` is a literal backtick and `\n` a line break (the file's own indentation follows the break). Strip the backslashes when you apply it. Fenced blocks are literal as shown.

### R1 — Decision record (direct to main; channel exception)

- **File:** `plans/tool-support-and-machine-profile.md` (protected; content is the commander's own words with provenance: user-dictated, still listed under "Review after").
- **Change:** in the row or note for M3Lead decision 2 (the cached alias question; find it with `grep -n -i "cached alias\|decision 2" plans/tool-support-and-machine-profile.md`), replace "pending"/"PENDING" with:
  ```
  Decided 2026-10-23T01:58:29Z (commander, session 10cf255a-c, uuid e073aea3): "1) yes" to "Cached alias, when the profile has no machine id: keep today's behaviour, which asks on a terminal and errors without one." The switch stays 0.
  ```
  If no such row exists, append under the file's decisions table a row `| M3Lead-2 | Cached alias, profile without machine.id: ask on a terminal, ERROR without one (switch stays 0) | 2026-10-23 | commander ("1) yes", uuid e073aea3) |`.
- **Also (same commit, mission folder):** nothing else. The code comments at `scripts/aitools` near `AITOOLS_*` switch "PENDING" (`grep -n PENDING scripts/aitools scripts/aitools.ps1`) are updated in R9 (code PR).
- **Verify:** `git diff` shows only that row; `grep -c "e073aea3" plans/tool-support-and-machine-profile.md` >= 1.

### R13-pre — Amend #102 before MERGE-ALL applies it (message, no file)

Send MERGE-ALL's orchestrator (or put in its mission folder as `S3-RX-R13pre-note.md` and commit direct to main) the two amendments from RC/S3-Reconcile-Ledger-findings.md:
1. #165 suggestedResolution must say a dotprofile push from a non-main branch is an **ERROR** (commander 2026-10-24T22:45:50Z "should error out"), not "WARN + ACTION".
2. #166: add the two-keys-differing-only-in-case case (`S3-MF-Fix3-Review-pr114.md:46`).
Also: #102's title says #146-#161; the batch is #146-#170 (25 entries). If #102 is already applied, these become L0 updates.

### R2 — Fan-out claims describe today (worktree + PR `docs/reconcile-fanout-today`)

Gate: #100 and #110 merged; G-P. Re-read each file first (BUILD-PKG edited aitools-workspace.md and harness.md on main 5494d93).

**R2a** — `.claude/rules/managed-file-deployment.md`, `.cursor/rules/managed-file-deployment.mdc`
1. OLD (Content sources table, deploy-harness row): `Rules reach the tools through the \`setup-user-claude\` / \`setup-user-cursor\` fan-out.`
   NEW: `User-level rules reach Cursor through the \`setup-user-cursor\` fan-out; Claude Code still gets the dotprofile \`claude/rules/\` from \`setup-user-claude\` directly until it fans out \`~/.aitools/rules\` too (plans/rules-fanout-claude.md).`
   (If #110 has not merged, drop "User-level ".)
2. The approved Manifest rule draft (`.../S3-H2-Manifest/S3-H2-Manifest-drafts/dot-claude/rules/managed-file-deployment.md`, "1e) approved") is applied in the same commit, with "the fan-out consumers" replaced by "`setup-user-cursor` (and `setup-user-claude` once it fans out)". Its `.mdc` twin was omitted by the draft: add the same sentence to `.cursor/rules/managed-file-deployment.mdc` next to its "Rules" bullet, and add the deploy-harness content-source row the `.mdc` lacks (copy the `.md` row as edited in step 1).
3. The FanPlan reviewer's non-blocking 4 ("Primary (wins if present)" for user rules contradicts first-source-wins): change the dotprofile row's "What it provides" cell from `CLAUDE.md template, user rules, profile.json (...)` to `CLAUDE.md template, profile.json (...); its \`claude/rules/\` reaches \`~/.aitools/rules\` last (first source wins: \`shared/\`, then \`.claude/\`, then the dotprofile)` — keep the parenthesis text as it stands.
   Verify: `grep -c "fan-out" .claude/rules/managed-file-deployment.md`; re-read the table; `bash scripts/check-pre-commit.sh`.

**R2b** — `reference/harness.md`, `.claude/rules/aitools-workspace.md`
1. harness.md "Not detected" bullet. OLD: `conflicts with files already in a\n  tool's own location (\`~/.claude/rules/\`), which the fan-out in\n  \`setup-user-claude\` / \`setup-user-cursor\` handles.`
   NEW:
   ```
   conflicts with files already in a
     tool's own rules location: `setup-user-cursor` reviews the
     `~/.cursor/rules/<name>.mdc` files it writes and keeps every other file
     there; `~/.claude/rules/` is not fed from `~/.aitools/rules/` until
     `setup-user-claude` fans it out (plans/rules-fanout-claude.md).
   ```
2. Apply the approved Manifest harness.md draft (`.../S3-H2-Manifest/S3-H2-Manifest-drafts/reference/harness.md`) and the approved MDM `--skip-config` harness.md draft (`.../S3-H2-MDM/S3-H2-MDM-drafts/reference/harness.md.edit.txt`), each only if its code has merged (#100/#110, #111). In the Manifest draft replace "The rules fan-out consumers (`setup-user-claude`, `setup-user-cursor`) read it" with "`setup-user-cursor` reads it (and `setup-user-claude` once it fans out)". Reviewer check against merged code (the "1e" condition) is the R2 PR reviewer's job; record it in the verdict.
3. aitools-workspace.md `rules/` row. OLD: `copied to each tool's rules location by \`setup-user-claude\` / \`setup-user-cursor\``
   NEW: `\`setup-user-cursor\` converts them into \`~/.cursor/rules/*.mdc\` (Claude Code still gets the dotprofile \`claude/rules/\` from \`setup-user-claude\` until it fans them out)`
4. aitools-workspace.md `deploy-state/` row (D-18). OLD: `| \`deploy-state/\` | Last-deployed file hashes for drift detection |`
   NEW: `| \`deploy-state/\` | Unused since 2026-10-21 (no deploy state: SOURCE is the source of truth); older machines may still have the directory, and nothing reads or writes it |`
   Verify: `grep -n "setup-user-claude" reference/harness.md .claude/rules/aitools-workspace.md` shows only the new wording.

**R2c** — `reference/managed-file-deployment.md` (gate: MERGE-ALL has applied #103's approved helper-contract draft to this file; pull first)
1. AnsA Q2 paragraph, directly after the "Deployed harness (`~/.aitools`)" table and before the "`userRepoPath` resolution" paragraph — insert (with #110 merged):
   ```
   User-level rules reach Cursor from `~/.aitools/rules/` through the
   `setup-user-cursor` fan-out, and Claude Code through `setup-user-claude` once
   it fans out (today it deploys `<userRepoPath>/claude/rules/` directly).
   Conflict handling and its assumptions: `@reference/harness.md` "Deployed
   harness (`~/.aitools`)".
   ```
2. Apply the approved Manifest draft for this file (`.../S3-H2-Manifest-drafts/reference/managed-file-deployment.md`) with the same "fan-out consumers" rewording as R2a.
3. D-21 (machine profile row; `grep -n "hostname match, then first profile" reference/managed-file-deployment.md`). OLD: `| Machine profile | \`<userRepoPath>/profile.json\` \`profiles[machineAlias]\` section | hostname match, then first profile |`
   NEW: `| Machine profile | \`<userRepoPath>/profile.json\` \`profiles[<machine id>]\`, chosen by the resolver (\`aitools-profile.sh\` / \`.ps1\`) | none: no match is an ERROR, never another machine's profile (\`@reference/user-repo.md\` "Resolution") |`
4. D-25b/(G) "User rules ... Fallback (none — no rules deployed)": NEW `(dev path: none; MDM path: the build-time copy when the machine has no dotprofile)`. FAN-PLAN Batch C removes that MDM copy later; its draft then updates this cell.
   Verify: `grep -c "first profile" reference/managed-file-deployment.md` = 0.

### R3 — hook-lifecycle / shared rules deployment wording (PR `docs/reconcile-shared-rules-path`)

Gate: G-P. Files: `.claude/rules/hook-rollout.md`, `.cursor/rules/hook-rollout.mdc`, `shared/skills/scratch/SKILL.md`.
1. hook-rollout.md OLD: `(deployed to \`~/.claude/rules/hook-lifecycle.md\` once a deploy path for\n\`shared/rules/\` exists)` NEW: `(copied to \`~/.aitools/rules/\` by \`deploy-harness\` and on to\n\`~/.cursor/rules/hook-lifecycle.mdc\` by \`setup-user-cursor\`; it reaches\n\`~/.claude/rules/\` once \`setup-user-claude\` fans out \`~/.aitools/rules/\`)`
2. hook-rollout.mdc OLD: `user-level rule \`shared/rules/hook-lifecycle.md\` (not yet deployed).` NEW: `user-level rule \`shared/rules/hook-lifecycle.md\` (deployed to \`~/.cursor/rules/hook-lifecycle.mdc\` through \`~/.aitools/rules/\`; Claude Code once \`setup-user-claude\` fans out).`
3. scratch SKILL.md OLD: `deployed to \`~/.claude/rules/\` once\n  deploy-harness ships a path for \`shared/rules/\`)` NEW: `copied to \`~/.aitools/rules/\` by deploy-harness; it\n  reaches \`~/.claude/rules/\` once setup-user-claude fans that out)`
- Verify: `grep -rn "once a deploy path\|not yet deployed\|ships a path for" .claude/rules .cursor/rules shared/skills` = no hits.

### R4 — deploy-paths.md / .mdc: AnsA Q1 rewritten, Q1b, #111 Edits 1-3, stale .mdc lines (PR `docs/reconcile-deploy-paths`)

Gate: #111 merged; G-P (Edits 1-3 are approved "1e"; the rest is review-after).
1. Apply #111's MDM draft Edits 1-3 (`.../S3-H2-MDM/S3-H2-MDM-drafts/dot-claude/rules/deploy-paths.md.edit.txt`) to the `.md`; for the `.mdc` re-anchor all three (the draft says "two edits" and its OLD text does not match the single-line `.mdc` paragraphs — RC/Git section 2).
2. Q1b: in the sources bullet (`- Every \`scripts/deploy-harness.*\` source`), OLD `\`shared/hooks\`, \`shared/skills\`` NEW `\`shared/hooks\`, \`.claude/hooks\`, \`shared/skills\`` (both files). Do not reflow other lines.
3. Q1 (rewritten), inserted after the sources bullet (after Edit 3 has rewritten its tail), both files:
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
4. `.mdc` only (D-12, D-13):
   - OLD `2. **MDM path** (\`deploy/setup-*.sh/.ps1\`): self-contained with build-time embedded content. Generated by \`build-deploy.sh\`.` NEW `2. **MDM path** (\`<userRepoPath>/deploy/setup-*.sh/.ps1\`): self-contained, generated by \`build-deploy.sh\` into the dotprofile repo. The shared \`aitools/deploy/\` is frozen.`
   - Each `Run \`build-deploy.sh\` to regenerate \`deploy/\`` -> `Run \`build-deploy.sh\` to regenerate \`<userRepoPath>/deploy/\``
   - OLD `3. Verify via pre-commit steps 3+10` NEW `3. Verify the dotprofile \`deploy/\` includes the change (pre-push step 7 rebuilds it on every push)`
- Verify: `grep -n "triggers only\|steps 3+10" .claude/rules/deploy-paths.md .cursor/rules/deploy-paths.mdc` — only the `.md`'s existing "no longer apply" sentence; `grep -c ".claude/hooks" .claude/rules/deploy-paths.md` = 1.

### R5 — ANSWER-1B apply: reference/user-repo.md and the glossary (PR `docs/reconcile-user-repo`)

Gate: #101 merged (AnsB edits are written on #101's text); G-P.
- **File 1** `reference/user-repo.md`: apply the **final texts** in `.../S3-AnsB/S3-AnsB-report.md` section "Per edit" for A, B, D, E, F, G, I ("Final text now"; use the "after #106 (and #111) merge" text if #106 has merged), J, and H. OLD anchors are in `.../S3-H2-DraftsM3/S3-H2-DraftsM3-drafts/reference/user-repo.md.edit.txt` (each edit's OLD).
- **Edit C:** if R9 is planned (Q7 = suggested), leave the approved bullet unchanged and apply AnsB's "If he takes the suggested answer" text **in R9's PR**, not here. If Q7 = keep the code, apply AnsB's "If he keeps the code" text here.
- **Also (AnsB critic):** the landed sentence "Migrate the live dotprofile only after #86 and #83 are merged ..." — both merged; replace with the state MERGE-ALL reports for the live re-key (unknown at plan time; ask MERGE-ALL's report). If unknown, leave it.
- **File 2** `registries/glossary.json` through the `/glossary` skill (it reads and writes the file): term "profile", fragment `(one entry of its 'profiles' object, keyed by machine id (environment:<name> for a hosted environment without one))`, source appended `; commander decision 5 of 2026-10-22`.
- Verify: `grep -c "keyed by machine alias" reference/user-repo.md registries/glossary.json` = 0; the `/glossary` skill's own validation; `python3 -c "import json,sys; json.load(open(sys.argv[1]))" registries/glossary.json`.

### R6 — shared/cursor-rules/user-rules.md (PR `docs/reconcile-cursor-user-rules`)

Gate: none beyond a pull (BUILD-PKG edited this file on 5494d93: re-read). Line 28 is **approved** ("4) approved").
1. AnsA Q3. OLD: the "Projects live in git repos under" line as it stands. NEW: `- Projects live in git repos under \`~/repos/\` (macOS) / \`%USERPROFILE%\repos\` (Windows)` (byte-identical to `shared/claude-shared.md`'s line; check with `grep -F`).
2. D-24 (G-P). OLD: `The \`setup-user-cursor\` script copies this to your clipboard automatically.` NEW: `Copy it by hand; no setup script copies it (the clipboard step was removed).`
- Also update incident #112's `affected` list in R13 L0 (AnsA follow-up).
- Verify: `grep -c "C:\\\\repos" shared/cursor-rules/user-rules.md` = 0.

### R7 — Parity mandate removed; existing twins corrected (PR `docs/reconcile-cursor-parity`)

Gate: Q9 (suggested yes); G-P.
1. Delete `.cursor/rules/cursor-rule-parity.mdc` (`git rm`).
2. `reference/cursor-practices.md`: replace the sentence `Cursor project rules mirror Claude Code rules for consistency. When changing rules, update both sets.` with `Claude Code and Cursor rules are separate harnesses, tracked and managed separately (commander, 2026-03-13; v0.54). A \`.cursor/rules/*.mdc\` twin exists only where one was made on purpose; when its \`.md\` changes, correct any \`.mdc\` statement the change makes false.`; replace the "Changing rules" steps 1-3 with that same rule as one step; fix the correspondence table (remove the `cursor-rule-parity.md` row, smoke-test-pattern has an `.mdc`, add agentic-standards, git-safety and managed-file-deployment, drop "Near-identical" for sources-of-truth and tool-lifecycle); D-25: add the row `| User rules (files) | \`~/.cursor/rules/*.mdc\` | Deployed by \`setup-user-cursor\` from \`~/.aitools/rules/\` (converted from \`.md\`) |` and change `\`deploy/setup-user-claude.sh/.ps1\` have the shared content embedded at build time.` to `\`<userRepoPath>/deploy/setup-user-claude.sh/.ps1\` (the dotprofile repo) have the shared content embedded at build time.`
3. `.cursor/rules/documentation-standards.mdc`: delete the bullet starting `**Cursor parity** —` (its target file was deleted in v0.54).
4. `.cursor/rules/config-file-safety.mdc` (false today): OLD line naming `scripts/setup-user-mcp.ps1` (settings.json) as "PowerShell merge" NEW `- Settings sync (field-level review): \`scripts/setup-user-settings.sh\` via \`sync_managed_json\` (settings.json <-> profile.json)`; OLD "Inline Node.js validation: `scripts/setup-user-mcp.sh`" NEW "Inline Node.js validation: `scripts/setup-user-hooks.sh`".
- Not in R7: `.cursor/rules/sources-of-truth.mdc` lacks 12 protected rows and the intent gate — MERGE-ALL rewrites `sources-of-truth.md` (A2); its `.mdc` is corrected in the same MERGE-ALL commit or in R12 after it (tell MERGE-ALL).
- Verify: `git grep -n -i "parity" -- .cursor/rules reference/cursor-practices.md` shows only menu parity (interactive-menus) and the new sentence; `.claude/skills/audit/tests/expected-behaviors.md` still says parity was removed (consistent).

### R8 — Abort (code PR `fix/abort-menu-and-rows`)

Gate: #106, #115, #116 merged (they own the runner and relay lines). Files per sub-batch <= 3.
- **R8a (no decision needed: the text is false).** `scripts/aitools-lib.sh`, `scripts/aitools-lib.ps1`: drafts E1, E1b, E2, E2b in `edits-abort.txt` (`[x]abort    : stop the run` -> `[x]abort    : stop this script (exit 2)`, comments). Then `.claude/rules/interactive-menus.md` and `.cursor/rules/interactive-menus.mdc` (G-P): the profile-mirror menu block line `[x]abort    : stop the run` -> `[x]abort    : stop this script (exit 2)`, and delete the clause "Despite the menu text," from #106's note (re-read the merged text).
  Verify: `git grep -n "stop the run" -- scripts .claude/rules .cursor/rules` = 0; `bash -n scripts/aitools-lib.sh`; pwsh parser on aitools-lib.ps1 (`pwsh -NoProfile -File <scratch>/parse.ps1 scripts/aitools-lib.ps1`, parse.ps1 = the Pre-validation convention in cross-platform.md); `bash tests/managed-files/test-managed-files.sh`; `bash tests/profile/test-lib.sh`.
- **R8b (parity bug; no decision needed).** `scripts/aitools-install.ps1`, `scripts/aitools.ps1`: drafts E6b, E4c (drop the 4th `"harness files"` argument to `Invoke-ChildRelayed`, as the .sh callers do). Re-pin after #116 (its installer conflict resolution may move these lines).
  Verify: `bash tests/hookin/test-hookin.sh` (39/39 on the draft copy); pwsh parser on both.
- **R8c (gate Q6 = WARN).** E3a-c (`scripts/aitools`), E4a-b (`scripts/aitools.ps1`), E5 (`aitools-install.sh`), E6 (`aitools-install.ps1`): split into two commits of <= 3 files. Then the relay drafts R1, R1b, R2, R2b (`scripts/aitools-lib.sh/.ps1`) and R3 (`scripts/aitools`, #116's Windows direct hook block), and the tests: `tests/profile/test-lib.sh` (`ERROR|child tool|aborted (exit 2)` -> `WARN|child tool|aborted by user`), `tests/profile/test-user-init.sh` (`ERROR|claude hooks|aborted (exit 2)` -> `WARN|claude hooks|aborted by user`), and a new hookin case: a stub `setup-user-claude` that exits 2 gives `WARN|setup-user-claude|aborted by user`, later stubs still run, loop rc 0. Docs (G-P): interactive-menus.md/.mdc "Abort" bullet and `reference/managed-file-deployment.md` "[x]abort": "handled like any failure ... ERROR `script failed (exit 2)`" -> "reported as WARN `aborted by user`; the run continues (only `deploy-harness`'s abort stops it)"; `reference/tool-support-decision-tree.md` D-TS13 rows likewise.
  Verify: `bash tests/hookin/test-hookin.sh`, `bash tests/profile/test-lib.sh`, `bash tests/profile/test-user-init.sh`, `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/profile/test-user-init.sh --bash-only`; `git grep -n "aborted (exit 2)" -- scripts tests` = 0.
- **Error-handling audit (R8):** no new suppressions; each abort path writes exactly one row (WARN, 15 chars); errors counter untouched on abort; `bash -n` + pwsh parser on every touched script; bash 3.2 compatible (no associative arrays, no `${x,,}`).
- Residual risk accepted by D-TS13: a bash runtime exit 2 that is not an abort shows as WARN.

### R9 — `--alias` claim needs a confirm (code PR `fix/user-init-claim-confirm`)

Gate: Q7 = suggested; #116 merged.
- **R9a** `scripts/aitools`, `scripts/aitools.ps1`, `tests/profile/test-user-init.sh`: drafts E7a, E7b, E8 (`edits-claim.txt`), T1, T2 (`edits-test.txt`). Also update the `--alias` parse comment ("register this machine without a prompt (P-Q12)") to "without a prompt, unless the alias names a profile no machine owns (then a confirm on a terminal)".
- **R9b** `scripts/aitools-profile.sh`, `scripts/aitools-profile.ps1`: the `--claim` comments ("only after the user picked KEY at a terminal") -> "only after the user picked or confirmed KEY at a terminal"; the "PENDING" decision-2 comments in `scripts/aitools`/`aitools.ps1` cite R1's record. `reference/user-repo.md` (G-P): AnsB's "If he takes the suggested answer" bullet text.
- Verify: `bash tests/profile/test-user-init.sh` (216/216 on the draft copy), `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/profile/test-user-init.sh --bash-only` (115/115), `bash tests/profile/test-profile.sh`, pwsh parser.
- Error-handling audit: each `log_error` pairs with an ERROR row + ACTION; declined confirm = WARN `skipped`; `--force` = no terminal.

### R10 — `aiToolingRepoPath` migration moves into the writer (code PR `fix/config-legacy-key`)

Gate: Q8 = suggested; after R9 (same files).
- **R10a** `scripts/setup-user-config.sh`, `scripts/setup-user-config.ps1`: drafts E11, E12; add "aiToolingRepoPath (legacy; migrated to repoPath and removed)" to both "Managed fields" headers; fix the dry-run log nit ("would migrate" when `--dry-run`).
- **R10b** `scripts/aitools`, `scripts/aitools.ps1`: drafts E9, E10 (read-only fallback + pre-lib warning).
- **R10c** docs (G-P): remove AnsB H's "Known exception, to be removed" parenthesis from `reference/user-repo.md`; `reference/harness.md` "the only config writer" stays true.
- Verify: `bash tests/profile/test-config.sh` (190/190 on the draft copy); the isolated-HOME legacy test from RC/Code 5.2 (`.scratch/session-rccode/test-legacy.sh` — copy it into the worktree's scratch); add a `tests/logging/test-logging.sh` pre-lib case (config.json with only `aiToolingRepoPath` -> warning, file hash unchanged).

### R11 — Step 7: input-changing pushes WARN (code PR `fix/pre-push-step7-branch`)

Gate: Q5 = suggested; after MERGE-ALL's rebuild (A4) so main itself is green.
- `scripts/check-pre-push.sh`, `scripts/check-pre-push.ps1`: drafts E13a-c, E14a-c (`edits-step7.txt`). `reference/pre-push-checklist.md` step 7 line: append `A difference caused by this push's own deploy/ inputs is a WARN (rebuild after the merge); staleness on a push that changes no input, a failed build and a failed smoke run FAIL.`
- Risk: the input regex duplicates deploy-harness's source list; add a comment at both places naming the other ("keep in sync with deploy-harness add_source lines") and an `INCIDENT` follow-up to derive it.
- Verify: `bash -n`, pwsh parser; run `bash scripts/check-pre-push.sh` from the worktree twice: on the branch (WARN expected, it changes check-pre-push only — not an input, so expect PASS after the rebuild) and on a scratch branch that touches `shared/rules/scratch.md` (WARN).

### R12 — Other false statements (item 8) (PR `docs/reconcile-misc`, 2-3 files per commit)

Gate: G-P.
- **R12a** `reference/agentic-framework.md` (D-19: "Deploy state migration" section -> "Removed 2026-10-21: there is no deploy state, shadow or ancestor (`@reference/managed-file-deployment.md` "Deploy State")."); `reference/logging.md` (drop "deploy-state" from the namespace list); `reference/pre-commit-checklist.md` (D-15 texts in RC/Docs).
- **R12b** `.claude/rules/git-safety.md`, `.cursor/rules/git-safety.mdc` (D-16 "deploy/ is frozen" section, text in RC/Docs D-16). `CLAUDE.md` line "`deploy/` — generated by `build-deploy.sh`; ephemeral, reset on each `aitools` run." -> "`deploy/` — frozen historical baseline (`build-deploy.sh` writes `<userRepoPath>/deploy/` in the dotprofile repo); reset to HEAD on each `aitools` run." — CLAUDE.md goes **direct to main** (channel exception), separately.
- **R12c** `.claude/rules/tool-lifecycle.md`, `.cursor/rules/tool-lifecycle.mdc` (delete the "`CLAUDE.md` — deploy list" bullet and the "Deploy using MDM" list bullet: no such list exists); `README.md` (pre-commit "12 steps" -> 20; post-push "all 20 steps" -> the current count from `grep -c "step_" scripts/check-post-push.sh`-derived step numbers; the githook sentence: builds into the dotprofile and stages the frozen `aitools/deploy/` (until Q11's fix)).
- **R12d** after MERGE-ALL's sources-of-truth.md change: `.cursor/rules/sources-of-truth.mdc` gets the missing protected rows and the intent gate (or the review-after text MERGE-ALL wrote), if MERGE-ALL did not.
- `aitools-workspace.md` channel-exception pointer (Q14): add under "Workspace structure" `Channel paths (`channel/handoffs/`, `channel/relay.md`) are committed directly to main: see CLAUDE.md "Channel exception (direct to main)".` (same PR as R2b if it has not merged; else here).
- Verify per file: grep that the old phrase is gone; `bash scripts/check-pre-commit.sh`.

### R13 — Incident ledger (via the `/incident` skill; one PR per batch)

Source of every entry: RC/S3-Reconcile-Ledger-findings.md (tables with evidence). Gate: MERGE-ALL has applied #146-#170; Q13; G-P.
1. **Parse the whole file first** (`python3` + `json`, max id over `incidents` and `closed`, duplicates). Expected next id #171; if not, renumber the drafts in order.
2. **L0 (no new ids):** close 17 (#129, #130, #84, #93, #114, #115, #122, #75, #97, #78, #95, #98, #109, #110, #99, #111, #145) with `closedIn` "PR #N (commit)" from the Ledger table (version added at the v0.74.0 tag); update 6 (#74, #76, #77, #102, #116, #144 — #144's correctiveAction "PR #60 (open)" -> "PR #60 (merged 845a935)"); keep #112 open until #99's change is verified (#99 merged: verify `user-rules.md` after R6, then close); update #87 (its resolution prescribes the reversed D-TS13 marker), #112 `affected` (+ `shared/cursor-rules/user-rules.md`). #102's apply script only appends: write a scratch close/update script (python3, backup first, validate JSON after, refuse if an id is missing), run it, diff, review.
3. **L1-L5:** file the 47 new incidents (#171-#217 provisional) in id order, 10 per PR: L1 #171-#180, L2 #181-#190, L3 #191-#200, L4 #201-#210, L5 #211-#217. Before filing, verify the five "to verify" candidates (Ledger section 4.4) in code. Add the markers this plan raised (section 8) that the Ledger list does not hold (check by title): step-7 structural FAIL (if Q5 is not taken), the PS1 relay duplicate rows (if R8b has not merged), three exit-2 conventions (if R8c is not taken), pre-commit steps 3/10 (Q11), deploy-harness N-Q2 commit gap (Q12), the channel exception in one place (Q14), parity record contradiction (closed by R7 if merged: then do not file).
4. Verify each PR: the skill's validation; `python3` parse; ids contiguous; no duplicate titles.

### R14 — Hand-off to FAN-PLAN's doc batch

When FAN-PLAN's code PR (its Batches B-D) merges, its section 7 drafts replace R2/R3's "today" texts. Tell FAN-PLAN's executor (note committed direct to main in its mission folder) that its draft OLD blocks for `.claude/rules/managed-file-deployment.md`, `reference/harness.md`, `.claude/rules/hook-rollout.md` and `.claude/rules/deploy-paths.md` must be re-anchored on R2/R3/R4's merged text, and that `.claude/rules/aitools-workspace.md` and `shared/skills/scratch/SKILL.md` (R2b/R3) need a flip it does not draft: "copied to `~/.claude/rules/` by `setup-user-claude` and converted into `~/.cursor/rules/*.mdc` by `setup-user-cursor`". FAN-PLAN's reviewer RC-1 (PowerShell Backup-File wildcard) is already fixed on main by 9923a3c; its reviewer tested #112's head, which lacks it — the executor re-tests after rebase. The `build-deploy.sh` header comment "setup-user-cursor (and the other rules fan-out consumers) read ~/.aitools/rules" (D-6) becomes true with FAN-PLAN Batch C; no edit here.

---

## 7. First actions for the executing Session Commander

1. Read the mission packet and its section 1, this plan, and RC/S3-Reconcile-report.md. `git -C /Users/new-jose/repos/aitools pull --ff-only`.
2. Check the world: `gh pr list -R nobul-tech/aitools --state open`; MERGE-ALL's progress (its mission folder `.../S3-MergeAll/` and `git log --oneline origin/main`); whether FAN-PLAN's plan is on main (`git ls-tree origin/main plans/rules-fanout-claude.md`); whether sources-of-truth.md has review-after (Q1).
3. Send the commander section 4 in one message (Q1-Q14 with the suggested answers). Do not wait for answers to start R1 and R13-pre.
4. Run R1 (direct to main) and R13-pre.
5. As each gate in 5.3 opens, launch one fresh delegate per batch with the 6.0 prompt contents; review its PR with an independent reviewer; spot-check the diff against this plan.
6. Keep a running estimate in your mission folder; at the end, append a relay entry (`.aitools/channel/relay.md`, direct to main).

---

## 8. INCIDENT markers raised by this mission (not filed; R13 files them)

- Pre-push step 7 FAILs every PR branch that changes a deploy/ input, by construction (`scripts/check-pre-push.sh` / `.ps1` step 7 compare). Medium.
- #106 PS1 passes `"harness files"` to `Invoke-ChildRelayed`, sh does not: duplicate rows (parity). Medium.
- Exit 2 reported three ways (#106 runners, #115 relay, #106 deploy-harness). Medium (ambiguity).
- Profile-mirror menu text `[x]abort : stop the run` is false. Low.
- `aitools user init` claims an unowned profile named by `--alias` without asking (`ui_register` / `Invoke-UiRegister`). High (Ledger draft #191).
- Entry points write config.json without backup/validation (`aiToolingRepoPath` rename). Low-medium.
- Five protected docs claim a setup-user-claude `~/.aitools/rules` fan-out that does not exist. Medium (closed by R2/R3).
- Pre-commit steps 3/10 and `scripts/githooks/pre-commit` stage the frozen `aitools/deploy/`. Medium.
- deploy-harness adopts into the dotprofile are not committed/pushed (N-Q2). Medium.
- `.cursor/rules/sources-of-truth.mdc` lacks 12 protected rows and the intent gate. Low.
- Parity record contradicts itself (v0.54 vs cursor-rule-parity.mdc/cursor-practices.md/documentation-standards.mdc). Low (closed by R7).
- Channel exception written in one place of four. Medium.
- Decision 2's answer recorded nowhere (closed by R1). Low.
- `reference/managed-file-deployment.md` "hostname match, then first profile". Medium (closed by R2c).
- Every open PR branch carries the old step-7 trigger in its own `check-pre-push`; a delegate pre-pushing from an un-rebased worktree gets the old behaviour. Low (closes as MERGE-ALL merges).
- The packet's "pre-push step 7 (dotprofile deploy/ stale)" known-failure note understates it (every push now). Low.

---

## 9. Not run (by the planner)

No repo file outside this plan and the mission folder was changed. No setup script, deploy-harness, build-deploy or check-pre-push ran against the real HOME; the code drafts were applied to scratch copies and their tests run under isolated HOMEs (RC/Code). Windows: nothing run. The relay drafts (R1-R3) were not run against #115/#116's tests. The FAN-PLAN plan was read as a draft from its mission folder; whether it is committed on main at execution time is for step 7.2 to check.

## 10. Provenance

Delegates: S3-Reconcile-Trans, -Git, -Docs, -Code, -Ledger (research), -Review (independent review of this plan), -Barrier (simulated first batch). Their files are in RC/. Commander words: section 3 and RC/S3-Reconcile-Trans-findings.md. MERGE-ALL decisions: `.../S3-MergeAll/S3-MA-Brief-brief.md` (main b40a320). FAN-PLAN: `.../S3-FanPlan/S3-FanPlan-drafts/plans/rules-fanout-claude.md` and `S3-FanPlan-Review-verdict.md`.
