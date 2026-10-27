# S3-Reconcile-Review verdict: plans/fan-plan-reconciliation.md v1.0

**Reviewer:** S3-Reconcile-Review (independent, read-only), 2026-10-26. **Plan reviewed:** origin/main c1358b9 (identical to the main checkout copy: `git diff origin/main -- plans/fan-plan-reconciliation.md` is empty).

## Verdict: APPROVE WITH CHANGES

The plan is mostly true and well sourced. Every code draft applies cleanly to its stated base, and most doc anchors are unique on origin/main. It cannot be run as written by a fresh Session Commander for four reasons:
- R1 points at a row that does not exist.
- The protected-file gate (G-P) is applied inconsistently. R1 and R6 ship before it, and 5.3 leaves it off most batches.
- The #105 row 8 relay Intent redraft was handed to RECONCILE by MERGE-ALL and is missing.
- Q4 asks the commander to reverse his recorded decision D5 without saying so.

13 required changes follow. None needs new research. Each one gives its fix.

---

## Required changes

**RC-1. R1 targets a row that does not exist; its fallback row does not fit the table; its gate claim is wrong.**
- Evidence:
  - `git -C /Users/new-jose/repos/aitools grep -n -i "cached alias\|decision 2\|PENDING" origin/main -- plans/tool-support-and-machine-profile.md` returns no hits. The only "pending" hits are SD-8-ext and SD-8-reg (lines 59-60).
  - The decision lives in the S3-M3Lead plan section 2 item 2: `origin/docs/m3-lead-plan:.../S3-M3Lead/S3-M3Lead-plan.md:34` "2. PENDING: cached config alias ...". That file is on PR #97 (open; MERGE-ALL merges it 5th). The code comment cites it too: `origin/main:scripts/aitools:137` "Decision 2 (PENDING with the commander -- S3-M3Lead plan section 2 item 2".
  - The "All items" table has 5 columns (`| Item | Section | Question | Decision | Note |`). R1's fallback row has 4 cells, and the file's footer says "95 items."
  - R1 calls the content "user-dictated". It is not: the agent composed the text. AnsB (`S3-AnsB-report.md:210`) said "a draft for approval".
  - PRs #101 and #106 both edit this file (`git diff --name-only origin/main...origin/docs/m3-approved-drafts` and `...feature/harness-hookin`). Their hunks do not touch the table end.
- Fix:
  - Drop the grep step.
  - Append to "All items", before the "95 items." line: `| M3Lead-2 | Chat (M3-LEAD) | Cached alias, when the profile has no machine id: keep today's behaviour (ask on a terminal, ERROR without one)? | Yes; the switch stays 0 | Decided 2026-10-23T01:58:29Z, "1) yes" (session 10cf255a-c, uuid e073aea3); S3-M3Lead plan section 2 item 2 |`. Change "95 items." to "96 items.".
  - After #97 merges, also replace "PENDING" in `S3-M3Lead-plan.md` section 2 item 2. That is a handoff path (channel exception).
  - Gate R1 on G-P (Q1), or label it "applied under A2, review after". Remove the "user-dictated" claim.
  - Note for the commander: the file's Intent scope is "decisions and notes from the review page ... and the chat clarifications that override them". An M3-LEAD chat decision is at the edge of that scope.

**RC-2. Q1's check command cannot tell the old rule from the new one.**
- Evidence: `git grep -n -i "review" origin/main -- .claude/rules/sources-of-truth.md` already returns 5 hits today: "Present for review" (:41), "Wait for approval" (:42) and others. `grep -i "review after\|review-after\|reviewed after"` returns 0.
- Fix: the check becomes `git -C /Users/new-jose/repos/aitools grep -c -i -E "review[- ]after|reviewed after" origin/main -- .claude/rules/sources-of-truth.md` >= 1 **and** `git ... grep -c "Wait for approval" origin/main -- .claude/rules/sources-of-truth.md` = 0.

**RC-3. The G-P gate is applied inconsistently.**
- Evidence:
  - Section 6 puts G-P on R2, R4, R5, R7, R8a docs, R8c docs, R12 and R13. But 5.3 adds "after G-P" only to R3/R7/R12. R2a/b, R2c, R4, R5, R6, R8 and R13 open on PR gates alone.
  - R6 says "Gate: none beyond a pull", but its step 2 (D-24) is marked "(G-P)". `shared/cursor-rules/user-rules.md` is in the protected table (`.claude/rules/sources-of-truth.md`).
  - R1 runs "now" (RC-1).
- Fix: add "+ G-P" to every 5.3 line whose batch writes a protected file (R2a/b, R2c, R4, R5, R6 step 2, R8a docs, R8c docs, R13 L0-L5). R6 then reads: "step 1 approved (4) approved) — may go now; step 2 after G-P". If the commander answers Q1 with "apply now under A2", the SC drops the G-P conditions in one place, which is the reason to state them in 5.3.

**RC-4. Q4 asks the commander to reverse D5 without saying so.**
- Evidence:
  - The SC asked at 2026-10-23T00:36:13Z: "Rules fan-out: 'everything' puts aitools' project rules in every repo and adds 17 always-apply Cursor rules to every chat. User-level only, or keep everything?" (RC/S3-Reconcile-Trans-findings.md:34). Jose answered "3) put aitools rules in the user space of claude code" (transcript, uuid e073aea3, 2026-10-23T01:58:29.509Z; I re-read it).
  - The SC's restatement at 01:59:48Z ("putting all rules, aitools' included, into Claude Code's user space") was followed by "laurnch harness-2" (uuid 0527e51d).
  - FAN-PLAN records this as D5 and "implements D5 as decided" (S3-FanPlan-drafts/plans/rules-fanout-claude.md:51, :2328-2330).
  - Q4's suggested answer "no: fan out shared/rules + dotprofile claude/rules" reverses D5. The plan's own Intent says "NOT re-litigating recorded decisions".
- Fix: rewrite Q4 as "**Reverse D5?** On 2026-10-23 you answered 'put aitools rules in the user space of claude code' to the question 'User-level only, or keep everything?'. Measured cost since: ... *Suggested:* keep D5 unless the 20k-token/double-load cost changes your mind; if you reverse it, FAN-PLAN takes its costed variant." The default, if he does not answer, is D5. Keep the evidence, and cite the question he answered.

**RC-5. The #105 row 8 relay Intent redraft is missing.**
- Evidence:
  - Jose: "1c) yes, re-draft" (uuid cb1f0201, 2026-10-26T21:58:13Z; RC/Trans:120).
  - The MERGE-ALL brief (origin/main b40a320, section 3.1): "#105 row 8 needs a new version after #103 and #106 merge (RECONCILE's plan covers it — coordinate, do not duplicate)".
  - RC/S3-Reconcile-Git-findings.md:97, :143, :224 and :282 plan it and suggest doing it after #116.
  - `grep -n -i "row 8\|#105" plans/fan-plan-reconciliation.md` finds only the MERGE-ALL ownership row. No batch covers it, so neither mission owns it.
  - PR #105 body: draft at `.../S3-H2-DraftsM3b/S3-H2-DraftsM3b-drafts/scripts/aitools-lib.sh.edit.txt`. It is false today because of "Consumed by: ... deploy-harness.sh/.ps1".
- Fix: add batch **R8d** (gate: #103, #106, #116 merged; after R8c's relay edits R1b/R2b, which change the same relay section comment; G-P because it is an intent statement). Its steps:
  - Redraft the `aitools-lib.sh/.ps1` relay-section `Intent:` against the merged consumers: installer Step 5 and 8b, the sync loop, user init.
  - Ship it as a version under A2, reviewed after.
  - Add R8d to 5.3 and to section 2 item 5.

**RC-6. R2c's own steps collide: step 2 rewrites the cell step 4 anchors on.**
- Evidence:
  - The Manifest draft for `reference/managed-file-deployment.md` (`origin/feature/harness-cursor-user-rules:.../S3-H2-Manifest-drafts/reference/managed-file-deployment.md`, Edit 1) changes the "User rules" row to `... | (none — no dotprofile rules deployed) |`.
  - R2c step 4 then targets `(none — no rules deployed)` (`origin/main:reference/managed-file-deployment.md:389`), which no longer exists after step 2.
- Fix: R2c step 4 OLD = the row exactly as Manifest Edit 1 writes it. NEW = the same row with the third cell `(dev path: none; MDM path: the build-time copy of the dotprofile rules when the machine has no dotprofile)`. Or merge steps 2 and 4 into one NEW row.

**RC-7. R8a and R8c doc anchors do not match the files as written.**
- Evidence (all on `origin/feature/harness-hookin` = #106):
  - `.cursor/rules/interactive-menus.mdc` has no `[x]abort    : stop the run` menu block (0 hits on every branch). The false text is the clause at :23: `(the profile-mirror menu's "stop the run" text included)`.
  - `reference/managed-file-deployment.md` has no "handled like any failure" (0 hits). The text is a table row at :181: "`validate_and_run` / `Invoke-ValidatedScript` treat it as a failure: ... ERROR `script failed (exit 2)`; the install continues | `deploy_configs` / `Deploy-Configs` treat it as a failure: ERROR `script failed (exit 2)` ...".
  - The decision tree has at least 7 rows carrying ERROR `script failed (exit 2)` (:484-487, :725, :726, :728, :731, :738).
  - #106 also writes the commander-backed T-Q3 note in `plans/tool-support-and-machine-profile.md` ("an exit 2 from any other setup script is an ERROR row `script failed (exit 2)`"). R8c does not list that file, so taking Q6 = WARN would leave the gate-decision record false.
- Fix:
  - R8a .mdc: OLD `(the profile-mirror menu's "stop the run" text included)` NEW `(the profile-mirror menu included: its [x]abort ends this script, exit 2)`.
  - R8c docs: list each OLD by the text above (row :181; interactive-menus.md "exit 2 is handled like any failure.\n  The runner writes ERROR `script failed (exit 2)`"; .mdc :23; the decision-tree rows by their first-cell text; the T-Q3 note). Say that the plans file is edited only if Q6 = WARN, with "(changed by the commander 2026-10-xx, Q6)".
  - Q6's text should also say that #106's T-Q3 note records ERROR as kept by his "keep functionality".

**RC-8. Four batches go over the 3-file limit.**
- Evidence (plan-execution.md and the UCI small batches rule; section 6.0 "Files per sub-batch <= 3"):
  - R7: cursor-rule-parity.mdc, cursor-practices.md, documentation-standards.mdc, config-file-safety.mdc (4).
  - R8a: aitools-lib.sh, aitools-lib.ps1, interactive-menus.md, interactive-menus.mdc (4).
  - R9b: aitools-profile.sh, aitools-profile.ps1, scripts/aitools, aitools.ps1, reference/user-repo.md (5).
  - R8c docs: interactive-menus.md, .mdc, reference/managed-file-deployment.md, tool-support-decision-tree.md, plus the plans file (RC-7) (5).
- Fix: split R7 into R7a (delete .mdc, documentation-standards.mdc, cursor-practices.md) and R7b (config-file-safety.mdc). Split R8a into R8a1 (libs) and R8a2 (rule twins). Split R9b into R9b1 (aitools-profile pair) and R9b2 (aitools/aitools.ps1 comments, user-repo.md). Split R8c docs into R8c-d1 (the interactive-menus pair + reference) and R8c-d2 (decision tree + plans file). Give each its own verify line.

**RC-9. Concurrent batches edit the same files; 5.1 misses two owners.**
- Evidence:
  - 5.3 opens R8 ("after #106, #115, #116") and R9 ("after #116") at the same moment. R8b, R8c, R9a and R10b all edit `scripts/aitools` and `scripts/aitools.ps1`. R8c and R9a both edit `tests/profile/test-user-init.sh`.
  - R2c and R8c both edit `reference/managed-file-deployment.md`.
  - FAN-PLAN Batch A edits `scripts/aitools-lib.sh/.ps1` (rules-fanout-claude.md:200, A1-A4) and lists `tests/profile/test-lib.sh` (:584). R8a and R8c edit the same files.
  - BUILD-PKG holds pending edits for files this plan touches (origin/main `plans/build-package/doc-edits-pending.md` sections 7 and 8: `reference/tool-support-decision-tree.md`, `reference/logging.md`; remediation RM-104: `.cursor/rules/tool-lifecycle.mdc`).
  - BUILD-PKG's 32bf20c (not in 5.1) changed `.claude/rules/deploy-paths.md` and `.mdc`, which R4 edits. Its 5494d93 changed `CLAUDE.md` and `README.md`, which R12b and R12c edit.
  - While I was reviewing, the main checkout's `.claude/rules/deploy-paths.md` changed again, uncommitted (its "Equivalence" section was rewritten into a numbered list of package-path differences). deploy-paths.md is still being edited.
- Fix:
  - 5.3: run R8 → R9 → R10 one after another (each PR merged before the next starts). Run R2c before R8c-docs.
  - 5.1 FAN-PLAN row: add "Batch A: aitools-lib.sh/.ps1, tests/profile/test-lib.sh — rebase R8 on it if it merges first".
  - 5.1 BUILD-PKG row: add deploy-paths.md/.mdc, cross-platform.md (32bf20c), CLAUDE.md, README.md (5494d93), and pending B13 edits to logging.md, tool-support-decision-tree.md, tool-lifecycle.mdc ("re-read before R4, R8c, R12a-c").

**RC-10. R9 leaves the `--alias` help text false, and one anchor is split across lines.**
- Evidence:
  - `origin/main:scripts/aitools:1302` and `scripts/aitools.ps1:352` say "user init --alias A  Same, registering this machine as profile A without a prompt". After R9 that is false when the alias names an unowned profile.
  - R9a's comment anchor occurs once in `scripts/aitools:1357`, but in `aitools.ps1` it is wrapped: `:399 "# prompt (P-Q12). PowerShell binds --alias ..."` (exact-match count 0).
- Fix:
  - Add to R9a: help lines in both files → "registering this machine as profile A without a prompt (a confirm on a terminal if A names a profile no machine owns)".
  - Give the .ps1 comment OLD as the two lines ending `# prompt (P-Q12).`
  - The reference/user-repo.md or README `--alias` wording is covered by AnsB C; re-check it.

**RC-11. R10a has unwritten code, and R10/R11 have no error-handling audit.**
- Evidence:
  - plan-execution.md requires "verbatim code in plan" and an audit per code batch. R10a says "add 'aiToolingRepoPath (legacy; ...)' to both 'Managed fields' headers; fix the dry-run log nit" without OLD/NEW. E11 (edits-claim.txt:182) logs "migrated ... and removed" unconditionally, including under `--dry-run`.
  - R10 and R11 have Verify lines but no audit. R11's E13a uses `... | grep -E ... | tr ... ) || d7_inputs=""` (edits-step7.txt:14). It has a comment and a fallback (empty list = strict FAIL), which passes script-standards, but the plan must state that.
- Fix:
  - Give the exact header lines (grep both setup-user-config headers for "Managed fields").
  - Give the dry-run branch, e.g. `if $DRY_RUN; then log "config: would migrate legacy key aiToolingRepoPath to repoPath"; else log "...migrated ... and removed"; fi` with its .ps1 twin, using the scripts' actual dry-run variable names.
  - Add R10 and R11 audit bullets.

**RC-12. R11's expected result contradicts itself.**
- Evidence: R11 says "on the branch (WARN expected, it changes check-pre-push only — not an input, so expect PASS after the rebuild)". But R11 also edits `reference/pre-push-checklist.md`, and `reference/` is in E13a's input regex and is a deploy-harness source (deploy-paths.md "Every `scripts/deploy-harness.*` source (`reference/`, ...)").
- Fix: "on the R11 branch: WARN (it changes `reference/pre-push-checklist.md`, a deploy/ input); on a scratch branch touching only `scripts/check-pre-push.sh` after the rebuild: PASS; on a scratch branch touching `shared/rules/scratch.md`: WARN."

**RC-13. Item 4 (parity) leaves out the commander's newer words.**
- Evidence:
  - Section 3 and Q9 cite only 2026-03-13 and 2026-03-15. I verified both: `aitools-nobul-jose/sessions/aitools/2026-03-13_bdf5e181.jsonl` uuid 4062135d "lets kill the cursor rule parity ... they need to be tracked and managed seperately"; `2026-03-14_b6a51f29.jsonl` uuid 7ab38b9f, 2026-03-15T03:33:46Z, "we dont care about rule parity anymore kil that test".
  - His newer answers are E-mdc-model "Re-mirror after the managed-file spec rewrite lands" (2026-10-22, `plans/tool-support-and-machine-profile.md` E-mdc-model row) and "1d) approved" (2026-10-26) for a new `.mdc` twin. The common brief rule is "a newer statement overrides an older one".
- Fix: add both to section 3 and Q9. Q9's suggested answer already matches them ("no mandate; keep and correct existing twins"). Say that this is how the old and new statements fit together, and that "kill the parity mandate" does not mean "stop re-mirroring when asked".

---

## Non-blocking findings

1. **R6.1 notation drops a character.** Read by the plan's own notation rule (`\`` = backtick), `\`%USERPROFILE%\repos\`` decodes to `%USERPROFILE%\repos` + backtick and loses the trailing backslash that `shared/claude-shared.md` has (`%USERPROFILE%\repos\`). The `grep -F` check would catch it. Put NEW in a fenced block.
2. **Q14** says "your 22:17:19Z answer named four places". The SC's question named four places; his answer named only CLAUDE.md ("approved, add this to aitools project CLAUDE.md file"). The phrase "for all four places" occurs once in the transcript, in the question.
3. **R2a step 1** says ".md + .mdc", but the sentence exists only in the `.md` (.mdc: 0 hits). Step 2 covers the `.mdc` row, so say "(.md only)". The Manifest rule draft's OLD (`- **Rules**: additive deploy from ...`) exists verbatim in the `.mdc` too (:32), so it can be applied there unchanged.
4. **R2c.4 OLD** should be quoted as the cell `(none — no rules deployed)`. The word "Fallback" is the column header (moot after RC-6).
5. **R12c anchors.**
   - README "12 steps" and "all 20 steps" each occur twice (the bash and pwsh lines): say "both lines".
   - Counts from the `# N.` headers on origin/main: pre-commit 1-14 and 18-20, so 20 is the last step number. Post-push 1-7 and 9-32 (no 8 or 22): "the current count" should be the number 32, not a `grep -c "step_"` count, which counts calls.
   - tool-lifecycle: the `.md` has "- `CLAUDE.md` — deploy list" (:97) and the `.mdc` has "- `CLAUDE.md` — add `setup-<tool>` to "Deploy using MDM" tool scripts list" (:58). It is one bullet per file, not two in each.
6. **Section 1.7 / R13** say "update 6" but list 8 updates (#74, #76, #77, #102, #116, #144, #87, #112). The Ledger says 8 (Ledger-findings:10).
7. **5.2 is stale.** origin/main is now c1358b9 (after 32bf20c and bc4aad1). Only #99 is merged (`gh pr list --state all`).
8. **R13-pre delivery.** "put in its mission folder" reads as writing into MERGE-ALL's folder, a running mission's files. Write the note in RECONCILE's own folder and tell MERGE-ALL's orchestrator (SendMessage if it is running) or the commander. #102 is still OPEN, so the timing holds today.
9. **R13 L0** writes `registries/incidents.json` with a scratch script. That is acceptable under governed-data-access only if the script is the `/incident` skill's validation path. Say that the skill's validation runs on the result.
10. **R11 risk.** On a push that changes an input, staleness that is not caused by the push (main already drifted) also becomes WARN. The WARN names the differing files, so it is visible. Add it to Risk.
11. **Windows.**
    - Every `.ps1` code edit (E2, E4a-c, E6/E6b, E8, E10, E12, E14a-c) is only parser-checked.
    - `tests/managed-files/test-managed-files.ps1` and `tests/profile/user-init-harness.ps1` exist on main. Add them to the R8a and R9 Verify lines, or list them under "Not run: Windows".
12. **Row 3 of #96.** Q7 says "the row-3 text you approved" (true: 0527e51d, 2026-10-23T02:01:33Z, "protected drafts approved."). On 2026-10-26T21:58:13Z he asked "7) re-state row 3 of 96" and gave no answer after the restatement (RC/Trans:128). Mention it in Q7.
13. **The "1e" condition.** "after a reviewer checks them against merged code" in section 3 is the SC's question text, not Jose's words ("1e) approved"). Mark it as the condition he approved.
14. **ROADMAP.md** has no row for this plan (`git grep -i reconcil origin/main -- ROADMAP.md` finds only an unrelated line). documentation-standards.md wants In-Progress items linked to `plans/*.md`. Add a row in R12, or say why not.
15. **Drafts the plan cites are not on main.** The S3-H2-Manifest, S3-H2-MDM and S3-H2-DraftsM3 drafts exist only on their PR branches (#100/#110/#111, #111, #101). The S3-FanPlan drafts are untracked in the main checkout only (`git status`: `?? .../S3-FanPlan/`). On another machine the SC must read them as `git show origin/<branch>:<path>` until the PRs merge, and FAN-PLAN's plan is unavailable until it is committed. Say this in 6.0 and section 7.
16. **The R8c code drafts (E3a-c) do not apply to #116's copy** of `scripts/aitools` (E3a: "OLD found 0 times"). #116 does not contain #106. After both merge (and #116's fix-forward), the merged file must be re-pinned. 6.0 already covers this ("re-pin"); a reader may expect it to be clean.

---

## What I verified (commands and results)

**State**
- `git fetch origin`; `git log --oneline -6 origin/main` → c1358b9, 32bf20c, bc4aad1, 5494d93, 3c4f8fe, b40a320.
- `gh pr list --state all`: #99 MERGED 3c4f8fe. #97, #98, #100-#106 and #108-#116 OPEN. #107 CLOSED.
- `git ls-tree origin/main`: the RC/ evidence and Code-drafts are on main (c1358b9). `plans/rules-fanout-claude.md` is not.

**Code drafts** (scratch `.scratch/session-rcrev/mkbase.sh`, `cross.sh`; bases built with `git show <ref>:<path>`)
- With the plan's stated bases (main = origin/main, pr106 = feature/harness-hookin, pr115 = fix/mf-lib-relay, pr115/aitools-116 = fix/mf-installer-relay:scripts/aitools), apply.pl applied every edit with each OLD found once:
  - edits-abort 13/13, edits-claim 7/7, edits-relay 5/5, edits-step7 6/6, edits-test 2/2.
- Also clean against #116's copies: edits-claim 7/7, edits-test 2/2, edits-relay 5/5.
- edits-abort E3a does not apply to #116's `scripts/aitools` (non-blocking 16).
- `S3-Reconcile-Code-drafts/` and `S3-Reconcile-Code-edits/` are identical (`diff -r`: empty).

**Doc anchors** (scratch `anchors.py`; exact and whitespace-normalized counts on origin/main and 15 PR branches)
- Unique (1) on main: R2a.1 (.md), R2a.3, R2b.1, R2b.3, R2b.4, R2c.1/1b, R2c.3, R3.1, R3.2, R3.3, R4.2a/b (.md and .mdc), R4.4a, R4.4c, R6.1, R6.2, R7.2a/b/c, R7.3, R7.4a/b, R8a.1 (both libs), R8a.2 (.md), R9a (sh), R9b (both), R11, R12a.1/2, R12b, R12c.1 (.md).
- Misses and duplicates: R1 (0; RC-1), R2a.1 .mdc (0; NB-3), R2c.4 "Fallback (none" (0; NB-4/RC-6), R4.4b (2, intended "each"), R8a.2 .mdc (0; RC-7), R8a.3 "Despite the menu text," (only #106 .md), R8c "handled like any failure" in the reference (0 even on #106; RC-7), R9a .ps1 (0, wrapped; RC-10), R12c README (2 each; NB-5), R12c tool-lifecycle (one per file; NB-5).
- #111 MDM deploy-paths Edits 1-3 (`mdmedits.py`): 1/1/1 exact on origin/main `.md` after BUILD-PKG 32bf20c. On `.mdc`: 0 exact, 1 whitespace-normalized, as the plan says ("re-anchor").
- The Manifest drafts are excerpts with OLD/NEW blocks (21, 38 and 88 lines), identical on #100, #110 and #111 (`cmp`). Their OLD `- **Rules**: additive deploy from` occurs once in the `.md` (:52) and the `.mdc` (:32).

**Commander quotes** (transcript `10cf255a-...jsonl` via scratch `trans.py`; the March ones from the dotprofile archive)
- e073aea3, 2026-10-23T01:58:29.509Z: "1) yes 2) yes 3) put aitools rules in the user space of claude code 4) approved ...".
- cb1f0201, 2026-10-26T21:58:13.232Z: "1d) approved 1e) approved ... 3) sure ... 6) re-factoring setup-user-claude and the fan-out requires a mission to create a plan".
- 474446b2, 22:17:19.570Z: "2) update the docs to match the current implementation of PR #106. lets keep functionality ..."; "3) approved, add this to aitools project CLAUDE.md file. project claude.md also bypassess worktrees etc".
- 0e1119a1, 22:39:56.693Z: "1) q1c pre-push step 7 should always run before pushing ..."; "no drafts, ... version 1.0"; "the plans directory should skip worktrees/prs etc ... thats a decision".
- c86608ca, 2026-10-24T22:45:50.059Z: "2) dotprofile pushes outside of main branch should error out".
- 0527e51d, 02:01:33Z: "protected drafts approved.  laurnch harness-2,".
- 65461507, 2026-10-22T00:04:12Z: "hooks/ is populated with all of shared/hooks and .claude/hooks".
- 4062135d, 2026-03-13T22:17:58Z and 7ab38b9f, 2026-03-15T03:33:46Z (parity), as quoted in RC-13.
- MERGE-ALL A1/A2/A4/A5: read in the brief at origin/main (it cites transcript lines 7286 and 7306). I did not re-read those two transcript entries myself.

**Code facts**
- Step 7 (`origin/main:scripts/check-pre-push.sh` step 7): it always runs. It rebuilds from the branch into a temporary copy of the dotprofile's committed tree (`git archive HEAD`, HOME isolated) and FAILs on `diff -rq`, plus a dry-run smoke test. This matches the R4 Q1 text and the basis for Q5.
- #106 PS1 duplicate rows (`origin/feature/harness-hookin`):
  - `aitools-install.ps1:196` and `aitools.ps1:196` pass `"harness files"`; `aitools-install.sh:270` and `aitools:1199` pass no tool.
  - On a throw, `Invoke-ChildRelayed` writes `ERROR|harness files|script failed (exception)` and returns 1 with rc 1.
  - `Invoke-HarnessStep` then writes `ERROR ... script failed (exit 1)`: two rows. R8b is right.
- `ui_register` (`origin/main:scripts/aitools:463-520`) claims an unowned profile with no confirm ("claiming it for this machine"). Return 2 = skipped at a confirm (its header), which E7b's declined path keeps.
- Pre-commit step 3 runs `build-deploy.sh` + `git add deploy/` only under `--fix` (`scripts/check-pre-commit.sh:111-115`). The plan's no-`--fix` runs are safe.

**PR and registry facts**
- #60 MERGED 845a935 (R13's #144 update).
- #102 title "File M3 incidents #146-#161" (OPEN). Its batch file holds 25 entries #146-#170. #165's suggestedResolution option A says "WARN + ACTION", so R13-pre amendment 1 is valid.
- `registries/incidents.json` on main: max id 145, 138 open, 7 closed, no duplicates. The 17 close and 8 update ids are all present and open. #144's correctiveAction says "PR #60 (open)".

**Other**
- `CLAUDE.md` "Channel exception (direct to main)" (:79-85) includes `plans/*` and the non-fast-forward rule.
- AnsA Q3 NEW text is `%USERPROFILE%\repos\` (S3-AnsA-report.md:119).
- `plans/fan-plan-reconciliation.md` overlaps per open PR (scratch `overlap.sh`): #101 (managed-file-deployment.md/.mdc, plans/tool-support..., logging.md, decision tree, user-repo.md, glossary.json), #106 (interactive-menus pair, plans/tool-support..., reference/managed-file-deployment.md, decision tree, aitools*, installers, test-hookin), and #98/#113-#116 (setup-user-config, tests/profile). Every one is behind a 5.3 gate except R1 (RC-1) and R12a/logging.md if Q1 = "apply now" (RC-9).

## What I did not verify

- Running any test suite, including the claimed 39/39, 216/216, 115/115 and 190/190 counts. That is S3-Reconcile-Barrier's job.
- The truth of the AnsB final texts (A-J) and the AnsA Q2 text against code.
- The 47 Ledger drafts and the 5 "to verify" candidates.
- "16 of the 19 PRs change a deploy input" (Q5).
- FAN-PLAN's 79 KB / ~20k token measurement.
- The #166 amendment source (`S3-MF-Fix3-Review-pr114.md:46`).
- The MERGE-ALL transcript lines 7286 and 7306 (I relied on the brief's quotes).
- Whether `reference/cursor-practices.md`'s table changes in R7 are complete.
- Anything on Windows.

## INCIDENT markers (not filed)

- INCIDENT: the #105 row 8 relay Intent redraft is assigned to RECONCILE by MERGE-ALL's brief, but RECONCILE's plan has no batch for it (RC-5). Medium (ownership gap).
- INCIDENT: the S3-M3Lead plan section 2 item 2 and the `scripts/aitools:137` / `aitools.ps1:755` comments still say decision 2 is PENDING. The answer has been on record since 2026-10-23 (RC-1; AnsB already flagged that it is recorded nowhere). Low.
- INCIDENT: the plan's "NOT re-litigating recorded decisions" Intent is contradicted by Q4's suggested reversal of D5 (RC-4). Medium (ambiguity).

WRITE_BLOCKED: none.
