# S3-Reconcile-Fix-Docs items: docs/spec/process markers as fix items

**Delegate:** S3-Reconcile-Fix-Docs (level 3, read-only on the repo), for S3-Reconcile-Fix · **Date:** 2026-10-26 · **Baseline:** origin/main 560de56 (fetched at the end; #104 merged since the start at 60e7fd7, and no item changed) · **Drafts:** `S3-Reconcile-Fix-drafts/docs/edits-*.txt` (14 files, 39 OLD/NEW blocks, 17 repo files).

## Summary (5 lines)

1. I checked 36 markers on origin/main 560de56. 20 are OPEN with a verbatim draft, 7 are COVERED by an R-batch or FAN-PLAN (two with a residual noted), 3 are FIXED (reference/rules.md 60e7fd7, tool-ops-cursor.md through #99, the /delegate follow-up text b08ec95), 1 is FIXED ON OPEN PR #106, 3 are process specs, and 2 are partly FIXED or partly COVERED with a draft for the rest.
2. Apply test: all 39 blocks applied once each to a `git archive` export of origin/main 560de56 (`.scratch/session-rcfixd/apply-test.sh`; `fail=0`). Each repo file is touched by only one edits file. These are doc-only changes, so `bash -n` and the pwsh parser do not apply.
3. I checked two upstream facts with chrome-devtools on 2026-10-26: code.claude.com/docs/en/setup for #202 (Windows: Git Bash, plus a PowerShell tool) and docs/en/memory for item #28 (how user rules load). The #202 claim is false, and FAN-PLAN's #28 draft can now drop its UNVERIFIED mark (corrected text in D28).
4. New findings: `scripts/read-session.py` drops every user message whose content is a list, so commander AskUserQuestion answers are lost. Post-push step 30 claims a tracker check that its code computes but never compares. The /aitool-ops card still says "No follow-up messages". The `/artifact-roles` skill is cited but does not exist. documentation-standards "Skill placement" contradicts rules.md R-4.
5. 15 files are protected and ship under G-P (review after, once MERGE-ALL lands A2). The glossary changes are one `/glossary` run (spec in G1). Nothing was filed. No repo file was edited beyond my outputs.

## Items

### L1 #174: aitools-workspace.md names a `.aitools/scratch/` + `.aitools/harvesting/` namespace the harness does not use
- Source marker(s): S3-ScratchRule-report.md:66 (SR-1); Ledger 4.2 #174
- Status on origin/main 560de56: OPEN (the `deploy-state/` row, the `rules/` row and the channel pointer are COVERED by R2b steps 3-5; the rest is open)
- Evidence: `.claude/rules/aitools-workspace.md` "Workspace structure" table, project-scoped `scratch/` and `harvesting/` rows, and "Decision #34 status". Real paths: `.gitignore:32` `.scratch/`; `scripts/ait-harvest.py:792` `project_root / "harvesting"`; shared/skills/scratch/SKILL.md:41-42 ("no hook or harvester uses that path today")
- Severity: medium
- Fix: draft `edits-workspace.txt` D174a (the table becomes repo-root paths), D174b (scope boundary), D174c (#34 consolidation was never implemented). The intent ("Govern the `.aitools/` workspace namespace") is left alone: it is still roughly true, and changing it is a protected intent edit (Decision needed)
- Files: .claude/rules/aitools-workspace.md (docs; protected yes)
- Gate: G-P; ship in the same PR as R2b (same file; different anchors, so no conflict)
- Verification: `git grep -c "aitools/scratch" -- .claude/rules/aitools-workspace.md` = 1 (only the D174c history sentence); `grep -c "^| \`scratch/\`" ` = 0
- Decision needed: none. The intent can stay. Leftover `.gitignore:52` `.aitools/scratch/` is harmless; leave it

### L1 #175: /handoff SKILL.md says the SessionEnd hook deletes scratch
- Source marker(s): S3-ScratchRule-report.md:67 (SR-2)
- Status on origin/main 560de56: OPEN
- Evidence: shared/skills/handoff/SKILL.md:318-319 "Scratch directories are deleted by the SessionEnd hook (harvest-session.sh lines 164-166)", :367-368, :545-546, :598. Contrary facts: shared/skills/scratch/SKILL.md:167 "Nothing in `.scratch/` is deleted by the harness"; shared/hooks/harvest-session.sh:16 "never unlinks"; ait-harvest.py deletes only its lock file and `.current-session` (:425, :461, :878)
- Severity: medium
- Fix: `edits-handoff.txt` D175a-d (four sites; the claim becomes "gitignored, one machine, copied to harvesting/, nothing deleted")
- Files: shared/skills/handoff/SKILL.md (docs; protected no: no skills row in sources-of-truth.md, #102 open incident)
- Gate: none
- Verification: `git grep -n -i "deleted by the" -- shared/skills/handoff/SKILL.md` = 0 hits
- Decision needed: none

### L1 #176: /handoff Step 5 has no variant for an assessment written inside the handoff
- Source marker(s): S3-Handoff2-V-verification.md:267
- Status on origin/main 560de56: OPEN
- Evidence: handoff SKILL.md:355 (Step 5 template reads only `[SESSION_DIR]/S2-schwerpunkt-assessment.md`); also :239 (Step 4 reads the same file)
- Severity: low
- Fix: `edits-handoff.txt` D176 (the verifier reads the handoff section when the assessment is inline). Step 4 is left alone: it runs before the handoff exists
- Files: shared/skills/handoff/SKILL.md (docs; protected no)
- Gate: none
- Verification: `git grep -c "wrote the assessment into the handoff" -- shared/skills/handoff/SKILL.md` = 1
- Decision needed: none

### L1 #177: no guard against a stacked PR merging into a stale base
- Source marker(s): S3-Handoff2-V-verification.md:266
- Status on origin/main 560de56: OPEN (process). Live risk today: none. Every open PR's base is `main` (`gh pr list --json baseRefName`, 16 PRs). Repo setting `delete_branch_on_merge` = false (`gh api repos/nobul-tech/aitools`)
- Evidence: shared/skills/delegate/SKILL.md "Running several delegates at once" has no base-branch rule; reference/pre-push-checklist.md has no PR step (git grep: no `gh pr` or "overlap")
- Severity: medium
- Fix: `edits-delegate.txt` D177-D178, second bullet "Stacked PRs target main". This lives in the /delegate skill, not pre-push-checklist.md: the merge happens after the push. Optional repo setting: `gh api -X PATCH repos/nobul-tech/aitools -f delete_branch_on_merge=true` (makes GitHub retarget stacked PRs). That is a commander call because it deletes merged branches, which MERGE-ALL fix-forwards may reuse
- Files: shared/skills/delegate/SKILL.md (docs; protected no)
- Gate: MERGE-ALL's D-DEL5 edit of the same skill (pull, then re-anchor)
- Verification: `git grep -c "Stacked PRs target main" -- shared/skills/delegate/SKILL.md` = 1
- Decision needed: turn on delete-branch-on-merge? Suggested: not now (MERGE-ALL is mid-run); the skill text is enough

### L1 #178: no file-ownership lock between parallel missions
- Source marker(s): origin/main S3-H2-DraftsM3b-handback.md:74 ("#98 opened mid-mission on files this mission owned; only the pre-push PR check caught it")
- Status on origin/main 560de56: OPEN (process). No pre-push PR check exists in scripts/check-pre-push.sh (git grep `gh pr`: none). The "check" was a manual step
- Evidence: shared/skills/delegate/SKILL.md "Assign file ownership" (assigns owners in the prompt only); packet section 6
- Severity: low
- Fix: `edits-delegate.txt` D177-D178, first bullet (a tracked ownership list, plus a pre-PR comparison of `git diff --name-only origin/main...HEAD` against it and against open PRs). A code check (a pre-push step) is optional and not drafted
- Files: shared/skills/delegate/SKILL.md (docs; protected no)
- Gate: as #177
- Verification: `git grep -c "An overlap is reported, not pushed" -- shared/skills/delegate/SKILL.md` = 1
- Decision needed: none

### L1 #179: reference docs still describe the removed managed-file model
- Source marker(s): S3-SpecRewrite-report.md:53
- Status on origin/main 560de56: partly COVERED by R12a (agentic-framework.md "Deploy state migration", logging.md:38 "deploy-state"); the rest is OPEN
- Evidence: reference/post-push-checklist.md:186 "auto-merge menu and fallback menu" (step 29). Step 30 lists `setup-user-claude, setup-user-mcp, setup-user-hooks`, but scripts/check-post-push.sh:774-778 audits only setup-user-claude.sh ("setup-user-mcp no longer calls deploy_managed_file"). Step 29 code (:746-756) compares the sorted set of `[letter]`s, not the order per menu. Glossary half: G1
- Severity: medium
- Fix: `edits-postpush.txt` D179a, D179b. Not mine: the `# Extract [letter] patterns from auto-merge menu sections` comment in check-post-push.sh:749 is code (sibling Checks)
- Files: reference/post-push-checklist.md (docs; protected no)
- Gate: none (R12a is separate)
- Verification: `git grep -n "auto-merge" -- reference/post-push-checklist.md` = 0
- Decision needed: none

### L1 #180: config-file-safety.md uses "when both sides differ", and its backup section does not cover JSON written by the library
- Source marker(s): S3-SpecRewrite-report.md:52
- Status on origin/main 560de56: OPEN, plus a new contradiction. The rule says "Backup failures are non-fatal (warn and proceed)", but `_managed_write` stops on a failed backup: aitools-lib.sh:1057-1061 "backup of ... failed -- nothing written"; aitools-lib.ps1:992-993 the same. `sync_managed_json` warns and proceeds (aitools-lib.sh:2648-2649)
- Evidence: config-file-safety.md "Backup before overwrite" and "Interactive managed file deployment"
- Severity: low
- Fix: `edits-configsafety.txt` D180a-c. FAN-PLAN's config-file-safety draft ("Directory deployment" example) does not overlap
- Files: .claude/rules/config-file-safety.md (docs; protected yes); the `.mdc` twin is left to R7b/Q9
- Gate: G-P
- Verification: `git grep -c "both sides differ" -- .claude/rules/config-file-safety.md` = 0
- Decision needed: none

### L3 #197: cross-platform-detail.md recommends Refresh-Path against shadowing, though Refresh-Path only appends
- Source marker(s): S3-GateFix-B-review.md:85
- Status on origin/main 560de56: OPEN (confirmed). aitools-lib.ps1:2652-2662 appends missing registry entries only (`$env:Path = $env:Path + ";" + ...`)
- Evidence: reference/cross-platform-detail.md "Git Bash PATH shadowing", "Resolution in other contexts"
- Severity: low
- Fix: `edits-xplat.txt` D197
- Files: reference/cross-platform-detail.md (docs; protected no)
- Gate: none
- Verification: `git grep -c "Use \`Refresh-Path\`" -- reference/cross-platform-detail.md` = 0
- Decision needed: none

### L4 #201: tool-ops-claude-code.md is stale (2.1.81, item #1, item #25), and so is the "No follow-up messages" text
- Source marker(s): S3-RegCC-report.md:69, :71; -Check-report.md:123
- Status on origin/main 560de56: OPEN in tool-ops-claude-code.md and in shared/skills/aitool-ops/SKILL.md:181, :244-265 ("No follow-up messages possible"). FIXED in /delegate (b08ec95, PR #62: SKILL.md "Follow-up messages. Observed in Claude Code 2.1.307 ... delivered at its next tool round")
- Evidence: tool-ops-claude-code.md:17 "Current version: 2.1.81"; `claude --version` = 2.1.309 (this run); registries/tool-registry.json claude-code `versions.notes` says 2.1.307. Item 1 row says last verified 2.1.74 while its "Windows Shell Limitations" section says "Last verified: 2.1.62". :60 item 25 and the :230-258 section say SendMessage is unavailable. In this run SendMessage is among this delegate's deferred tools and `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is unset (printenv exit 1)
- Severity: medium
- Fix: `edits-toolops.txt` D201a (current version, not re-walked), D201b (item 24, see #51), D201c + D201d (item 25 and its section), D201e + D201f (the /aitool-ops card). Item 1's double "last verified" is not drafted: re-verifying needs Windows. Spec: on the next Windows session, re-check item 1 against code.claude.com/docs/en/setup (#202 facts) and set one "Last verified" in both places
- Files: reference/tool-ops-claude-code.md (protected yes), shared/skills/aitool-ops/SKILL.md (protected no)
- Gate: G-P; FAN-PLAN's #28 draft targets the same file (D28 replaces it, so only one #28 lands)
- Verification: `git grep -n "No follow-up" -- shared/skills reference` = 0; `git grep -c "2.1.309" -- reference/tool-ops-claude-code.md` >= 1
- Decision needed: none

### L4 #202: claude-shared.md says Claude Code on Windows always uses Git Bash and is not configurable
- Source marker(s): S3-RegCC-report.md:70; -Check-report.md:124
- Status on origin/main 560de56: OPEN. Upstream VERIFIED with chrome-devtools, code.claude.com/docs/en/setup, 2026-10-26: "If Git for Windows is not installed, Claude Code uses PowerShell as the shell tool instead"; "With Git for Windows, Claude Code uses Git Bash for the Bash tool. If Claude Code can't find Git Bash, set the path ... CLAUDE_CODE_GIT_BASH_PATH"; "When Git for Windows is installed, the PowerShell tool is available alongside Bash: on by default for claude.ai and Console accounts ... Set it to 0 to turn the tool off"
- Evidence: shared/claude-shared.md:83
- Severity: medium (propagates to every machine)
- Fix: `edits-claudeshared.txt` D202. Same text in `<userRepoPath>/claude/CLAUDE.md` (deploy-paths.md "Template sync"; dotprofile repo, committed and pushed to its main, N-Q2). Also update the item 1 row and the "Windows Shell Limitations" section of tool-ops-claude-code.md (spec only: needs a Windows check)
- Files: shared/claude-shared.md (protected yes); dotprofile claude/CLAUDE.md (outside this repo)
- Gate: G-P
- Verification: `git grep -c "always uses Git Bash" -- shared/claude-shared.md` = 0; diff the line against the dotprofile template
- Decision needed: none. The harness keeps assuming Git Bash; the line now says that is an assumption

### L4 #203: managed-file-deployment.md and harness.md claim a setup-user-claude fan-out
- Status on origin/main 560de56: COVERED (R2a, R2b, R3; FAN-PLAN flips them, R14). Residuals checked: deploy-paths.md / .mdc "MDM run order" already say "once it fans out" (true today). reference/rules.md:8 and R-1 (:29) state the decision, and :211 marks the Claude fan-out "Not implemented". That is consistent, not a deficiency. scripts/build-deploy.sh:1914/:2064 comments: R14 already notes them
- Severity: medium
- Fix: none beyond R2/R3
- Gate: R2/R3 gates

### L4 #204: Cursor twins drift; parity ambiguous
- Status on origin/main 560de56: COVERED (R7a/R7b/Q9 for parity; R4 step 4 for deploy-paths.mdc D-12/D-13, whose OLD strings still occur once on 560de56). The "setup-user-claude duplicated" claim FAN-PLAN reported is gone on main: deploy-paths.md/.mdc list only setup-user-hooks as duplicated
- Severity: low
- Fix: none beyond R4/R7

### L4 #206: the fan-out contract does not say how `paths:` maps to Cursor globs
- Status on origin/main 560de56: FIXED for Cursor by reference/tool-ops-cursor.md (#99, 3c4f8fe): "Glob anchoring" ("`globs: scripts/**` attaches only to `~/scripts/...`. Use `**/scripts/**`") and "Harness deployment" ("A Claude Code `paths:` key ... becomes an anchored `globs:` block list (`**/<pattern>`)"). reference/rules.md (60e7fd7) mentions "globs from `paths:`" (:210) but does not cite tool-ops-cursor or say that the two tools' scoping differs
- Severity: low
- Fix: hand to the SC's rules.md delegate (do not edit here): one sentence in rules.md section 5 citing `@reference/tool-ops-cursor.md` "Glob anchoring". Also note that a Claude user rule's `paths` is relative to the session's primary working directory (verified, D28), while the Cursor conversion `**/<pattern>` matches at any depth under `~`. So `*.md` is root-only in Claude and any-depth in Cursor
- Files: reference/rules.md (not mine)
- Gate: none
- Decision needed: none

### L4 #207: cursor-practices.md says User Rules are SQLite-only and the CLI reads no user rule files
- Source marker(s): S3-H-Cursor-handback.md:68; rules.md section 9 repeats it
- Status on origin/main 560de56: OPEN. R7a overlaps it (D-25 row, "deploy/setup-user-claude" sentence, parity text)
- Evidence: reference/cursor-practices.md "Rule Sources" row "Cursor User Rules | ... (SQLite) | Not file-accessible"; "CLAUDE.md Interop" "**Important:** ... uses Cursor User Rules (SQLite) + project CLAUDE.md + .cursor/rules/ only"; "User Rules (deprecated workflow)". Contrary: reference/tool-ops-cursor.md "User-level rules" (stored on the Cursor account; `~/.cursor/rules` applies through the ancestor walk, IDE and CLI share `LocalCursorRulesService`)
- Severity: low
- Fix: `edits-cursorpractices.txt` D207a-c. D207a's second row replaces R7a's D-25 row: fold both into the R7a PR and drop R7a's D-25 row step
- Files: reference/cursor-practices.md (docs; protected no)
- Gate: R7a (same PR)
- Verification: `git grep -c "SQLite" -- reference/cursor-practices.md` = 0
- Decision needed: none

### L4 #208: harness.md intent scope says "architecture only" but holds the conflict-handling contract
- Status on origin/main 560de56: OPEN
- Evidence: reference/harness.md intent; sections "Deployed harness (`~/.aitools`)", "Conflict handling", "Assumptions and what is not detected". At least four docs cite that section, and R2c adds a fifth
- Severity: low
- Fix: `edits-harness.txt` D208 (widen the scope; moving the section would break those citations)
- Files: reference/harness.md (protected yes, intent statement)
- Gate: G-P, in R2b's PR (same file)
- Verification: read the intent in place
- Decision needed: widen the intent or move the section? Suggested: widen

### L5 #211 / #213 / #214 (doc halves): no doc states the MDM path's size, clean-endpoint and run-context limits
- Source marker(s): S3-MdmPkg-report.md:190, :194, :195
- Status on origin/main 560de56: OPEN in `.claude/rules/deploy-paths.md`. BUILD-PKG 32bf20c added the package path, its "Equivalence" and the MDM bootstrap-keys paragraph. plans/build-package/design.md section 1 (sizes) and section 5 (run context, BP-10) hold the facts, but the deploy-paths rule does not
- Severity: medium
- Fix: `edits-deploypaths.txt` (a new "MDM path limits" subsection after "MDM run order"). Code halves (a size gate, a console-user resolver) are not mine: #211's gate is code for sibling Code/Checks (#111 adds one for deploy-harness only); #214's resolver is BUILD-PKG's BP-10
- Files: .claude/rules/deploy-paths.md (protected yes). The `.mdc` twin is not drafted (Q9: correct-when-false; its "equivalent results" line is the same claim, so R4 could add one line)
- Gate: G-P; after R4 (same file, different anchors); pull first (BUILD-PKG edits this file)
- Verification: `git grep -c "### MDM path limits" -- .claude/rules/deploy-paths.md` = 1; pre-commit step 20 (`@plans/build-package/design.md` exists)
- Decision needed: none

### L5 #212 (README half): README MDM run order omits deploy-harness
- Status on origin/main 560de56: COVERED by FAN-PLAN Batch C, C13/C14 (`plans/rules-fanout-claude.md`). Its OLD `Run these from the \`deploy/\` directory -- self-contained, MDM-ready:` occurs once (README.md:73). README has no "deploy-harness" (git grep)
- Residual: C13 keeps "MDM-ready", which #213 shows is not true on a clean endpoint. Suggest that C13 points to deploy-paths.md "MDM path limits" once that lands
- Severity: medium
- Gate: FAN-PLAN Batch C merged

### 4.3 #105: /tool-registry SKILL.md treats `overrides` as per-tool and lacks fields
- Status on origin/main 560de56: OPEN. registries/tool-registry.json: `overrides` is a top-level list of 3 entries (`tool`, `override`, ...); no tool has an `overrides` section. Sections in use but not in the table: displayName, source, purpose, notes, update, versionCheck, systemRequirements, pathIssues, platformGotchas (18/18 tools), configBehavior, perlioDeployment, setupScript (1 each); `versions.minVersion`, `blocked`, `notes`, `maintenanceFile`; `install.all`, `install.deprecated[].notes` (`.scratch/session-rcfixd/reg.py`, `reg2.py` on origin/main)
- Evidence: .claude/skills/tool-registry/SKILL.md "## Schema"
- Severity: low
- Fix: `edits-toolregistry.txt` D105
- Files: .claude/skills/tool-registry/SKILL.md (docs; protected no; no intent change)
- Gate: none
- Verification: `git grep -c "not a per-tool section" -- .claude/skills/tool-registry/SKILL.md` = 1
- Decision needed: none

### 4.3 #51: USO "Dedicated tools" names Grep/Glob, which sub-agents lack
- Status on origin/main 560de56: OPEN. This delegate (Claude Code 2.1.309) has no Grep or Glob tool. The live hook already dropped them (shared/hooks/standing-order-guard.sh:11 "Read/Edit/Write/, not Bash"; the tracked `.bak.2026-06-21T203334Z` still has the Grep/Glob checks)
- Evidence: shared/claude-shared.md:124; reference/tool-ops-claude-code.md:58 item 24; shared/skills/delegate/SKILL.md "File access"
- Severity: medium (every sub-agent sees a standing order it cannot follow)
- Where the fix lands (proposal): (1) the USO text in shared/claude-shared.md and the dotprofile template (D51 in `edits-claudeshared.txt`); (2) item 24 in tool-ops-claude-code.md (D201b); (3) /delegate "File access" (D51 in `edits-delegate.txt`); (4) /aitool-ops is re-derived from tool-ops-claude-code (spec: copy D201b's row into its version table). Not in the hook: it no longer names Grep/Glob
- Files: as listed (claude-shared.md and tool-ops-claude-code.md protected)
- Gate: G-P for the protected two
- Verification: `git grep -c "where your tool list has them" -- shared/claude-shared.md` = 1
- Decision needed: none

### G1 (Ledger 4.4 + FAN-PLAN TODO(glossary) + rules.md section 9): one `/glossary` run
- Status on origin/main 560de56: OPEN. registries/glossary.json (`terms` object): "auto-merge menu" ("shown when git 3-way merge succeeds cleanly"), "merge-conflict menu" ("git 3-way merge had conflicts or no ancestor exists"), "accept & adopt" ("The [a] menu option in both auto-merge and merge-conflict menus") and "updated" ("via auto-deploy, overwrite, or merge") describe the removed model. ABSENT: "review menu", "failed", "merge & adopt", "fan-out", "harness files", "removed", "retired", "trigger directive". FAN-PLAN Q7 (suggested answer, adopted by commander decision 2) covers "removed" only, and only after Batch A
- Spec (one run, one review; both files protected: registries/glossary.json via the skill, .claude/rules/glossary.md word list):
  1. Delete "auto-merge menu" and "merge-conflict menu" (JSON entries and rule lines).
  2. Add "review menu": "The one managed-file review menu, shown on an interactive run when LOCAL differs from SOURCE: [o]verwrite, [a]ccept & adopt, [m]erge & adopt (AI, text files only), [s]kip, [x]abort (exit 2); [a] and [m] only when the caller passes an adopt target. JSON files get the same choices per field, without [m]." Source: `.claude/rules/agentic-standards.md` "Managed-file review choices and merge".
  3. Redefine "accept & adopt": "Deployment outcome: the user kept LOCAL (or the AI merge result, for merge & adopt) and the library copied it to the adopt target in the same step. The [a] choice of the review menu; merge & adopt also returns it." (code: aitools-lib.sh:1913, :2206 set `accept & adopt`).
  4. Add "merge & adopt": "Review-menu choice [m]: AI merge of SOURCE and LOCAL (text files only), written to LOCAL and to the adopt target; its outcome is accept & adopt."
  5. Add "failed": "Deployment outcome: a write, a backup, the AI merge or validation failed; the library restored its snapshots, logged the error, and the caller records an ERROR row and continues." Source: agentic-standards.md "Failure handling"; aitools-lib.sh `MANAGED_FILE_RESULT="failed"`.
  6. Redefine "updated": "Deployment outcome: LOCAL differed from SOURCE and SOURCE was written (overwrite, or a non-interactive run)." (aitools-lib.sh:1916, :2210; merge & adopt returns accept & adopt, not updated).
  7. Add "harness files": "The summary tool name of deploy-harness, which builds the deployed harness in ~/.aitools." Source: reference/harness.md "Deployed harness".
  8. Add "fan-out": "The step of a tool's setup script that copies ~/.aitools/rules into that tool's rules location (setup-user-cursor today, converting to .mdc; setup-user-claude once FAN-PLAN lands)." Source: reference/rules.md.
  9. Gated: "retired" after #100 merges (the manifest source value; definition from #100's manifest spec); "removed" after FAN-PLAN Batch A merges (FAN-PLAN Q7: "a deployed file backed up and deleted because its source retired it"), then the governed-outcome list in reference/script-standards-detail.md and reference/framework-managed-file-deployment.md (protected) get it.
  10. "trigger directive" (rules.md section 9): "The 'When to invoke' section of a rule or skill that names the conditions for invoking it." Distinct from "trigger" (DTCC event).
  Coordinate: BUILD-PKG's pending "deployment path" and "package path" (plans/build-package/doc-edits-pending.md) belong in the same run if BUILD-PKG agrees; R5b's "profile" fix is a separate, already-approved edit.
- Severity: medium (the removed-model terms mislead every agent that reads the definitions)
- Files: registries/glossary.json, .claude/rules/glossary.md (protected yes)
- Gate: G-P; steps 1-8 and 10 now; step 9 per its gate
- Verification: the skill's validation; `python3 -c "import json,sys; json.load(open(sys.argv[1]))" registries/glossary.json`; `git grep -c "auto-merge menu" -- .claude/rules/glossary.md registries/glossary.json` = 0
- Decision needed: none

### M1: `shared/rules/*.md` is missing from the protected table
- Source marker(s): S3-Reconcile-Docs-findings.md:285
- Status on origin/main 560de56: OPEN (sources-of-truth.md has `.claude/rules/*.md` only; shared/rules holds hook-lifecycle.md and scratch.md)
- Severity: low
- Fix: `edits-sot.txt` DSOT (one row)
- Files: .claude/rules/sources-of-truth.md (protected yes)
- Gate: after MERGE-ALL's review-after change to the same file (re-anchor); R12d mirrors it into the `.mdc`
- Verification: `git grep -c "shared/rules/\*.md" -- .claude/rules/sources-of-truth.md` = 1
- Decision needed: none

### M2: the channel exception is written only in CLAUDE.md (Q14)
- Source marker(s): S3-Reconcile-Trans-findings.md:229
- Status on origin/main 560de56: OPEN. CLAUDE.md:79-85 has it. MERGE-ALL's D-DEL5 is "versions, not drafts" plus review-after (S3-MA-Brief-brief.md:29-30, :202) and does not name the channel exception, so Q14's suggested routing is unanswered and unowned. R2b step 5 covers aitools-workspace.md
- Severity: medium
- Fix: `edits-handoff.txt` DQ14 (Step 8: follow a repo's CLAUDE.md direct-to-main exception; generic because /handoff is a user-level skill). Spec for the user rule (dotprofile `claude/rules/delegation.md`, outside this repo, committed and pushed per N-Q2): one line under "Shipping (D-DEL4)": "Paths a repo's CLAUDE.md names as direct-to-main (aitools: handoffs, relay.md, plans/, CLAUDE.md) are committed to main from the main checkout, not shipped by PR."
- Files: shared/skills/handoff/SKILL.md (protected no); dotprofile delegation.md (user rule; the commander's own file)
- Gate: Q14 answer, or MERGE-ALL's D-DEL5 commit (same user rule: one edit, not two)
- Verification: `git grep -c "direct-to-main exception" -- shared/skills/handoff/SKILL.md` = 1
- Decision needed: Q14. Suggested: as the plan suggests; this draft is the /handoff half

### M3: `.cursor/rules/sources-of-truth.mdc` lacks rows and the intent gate
- Status: COVERED (R12d)

### M4: the #108/#114 Fix6 draft would define "library-style tool" a second time
- Source marker(s): S3-Reconcile-Git-findings.md:271
- Status on origin/main 560de56: OPEN as a draft defect, not a repo defect. Main has one definition: reference/logging.md "### 7. Library-style tools return diagnostics" (logging.md:107-128), with a pointer in script-standards-detail.md "Summary coverage rule" (:263-266, from #101). The Fix6 draft (`origin/fix/mf-audit-config:.../S3-MF-Fix6/S3-MF-Fix6-drafts/reference/script-standards-detail.md.edit.txt`, identical on #108) Edit 2 adds a "### Library-style tools" section
- Severity: low
- Fix (spec): apply Fix6 Edit 1 only, with its last cell changed to `Library-style tool: stdout carries data only (\`@reference/logging.md\` "Library-style tools")`. Drop Edit 2. Fold Edit 2's new clauses into logging.md section 7 as bullets: only listed scripts qualify, and adding one needs commander approval; every warning, error and exit code goes to deploy.log at `detail`, early exits included; an optional short `aitools-profile: <reason>` stderr line; the pre-lib PowerShell 7 guard exception; the contract lives in the script header and user-repo.md "Resolution", and a change updates every consumer. Not drafted verbatim: Fix6's own open question ("recognise the category at all?") is unanswered
- Files: reference/logging.md (protected no), reference/script-standards-detail.md (protected no)
- Gate: #108/#114 merged plus the Fix6 question answered; BUILD-PKG's pending logging.md sentence is in a different section
- Decision needed: Fix6 question. Suggested: yes, named scripts only (Fix6's own suggestion)

### M5: 3de51d6 (protected abort docs, 5 files) has no independent review
- Status on origin/main 560de56: OPEN, on PR #106 (still OPEN). The PR's reviews are at bbc3cbb (2026-10-23T02:31Z) and 0dea75f (02:33Z); 3de51d6 is 2026-10-26T22:23Z, and its only comment is the author's (`gh pr view 106 --json`)
- Severity: medium (process)
- Fix (spec): before MERGE-ALL merges #106, an independent reviewer (no author notes) checks 3de51d6's five files against #106's code and posts the verdict with `gh pr comment` (/delegate "Verifying what comes back" step 5). Under A2 the commander's review-after covers the protected text; the code-match check is still needed
- Gate: before #106 merges
- Decision needed: none

### M6: spec names `ADOPT_TRANSFORM` / `-AdoptTransform`; code takes `ADOPT_FILTER` / `-AdoptFilter`
- Source marker(s): S3-FanPlan-report.md:125 (Lib); FAN-PLAN's mfd draft "Why" notes it and does not fix it
- Status on origin/main 560de56: OPEN. Code: aitools-lib.sh:1780 `$6 = ADOPT_FILTER` (positional, not an environment variable); aitools-lib.ps1:1745, :1762 `-AdoptFilter`; setup-user-claude.sh:187 `claude_md_adopt_filter`; .ps1:194 `$claudeMdAdoptFilter`. No `adopt_claude_md` exists (git grep). Spec: reference/managed-file-deployment.md "Signatures", the argument bullet, the CLAUDE.md template paragraph; .claude/rules/managed-file-deployment.md "Adopt target"; .cursor/rules/managed-file-deployment.mdc
- Severity: medium (an agent following the spec writes a call the library ignores)
- Fix: `edits-adoptfilter.txt` DAF1-DAF6, assuming the code name wins (as briefed; sibling Code decides). If Code renames the code instead, drop this file
- Files: reference/managed-file-deployment.md, .claude/rules/managed-file-deployment.md, .cursor/rules/managed-file-deployment.mdc (all protected)
- Gate: G-P; R2a/R2c touch the same files at other anchors (no overlap: apply test); #106 changes a different section of the reference
- Verification: `git grep -n "ADOPT_TRANSFORM\|AdoptTransform\|adopt_claude_md" -- reference .claude/rules .cursor/rules` = 0
- Decision needed: none (sibling Code picks the name)

### M7: tool-ops-claude-code.md lacks how user rules load
- Status on origin/main 560de56: COVERED by FAN-PLAN's item #28 draft, which is now VERIFIED. I read code.claude.com/docs/en/memory with chrome-devtools on 2026-10-26: "Claude Code loads user-level rules before project rules ... Neither set overrides the other: if a user rule and a project rule conflict, Claude may follow either one"; "Each pattern is relative to the rule's base directory: ... User-level rules: the session's primary working directory"; "paths is the only field Claude Code reads from a rule"; "If the YAML between the markers doesn't parse, Claude Code ignores the frontmatter and loads the rule as if it had no paths"; "Rules without paths frontmatter are loaded at launch"; for project rules, "All .md files are discovered recursively"; no statement on user-level recursion or `.MD` case
- Fix: `edits-toolops.txt` D28 (verified text; replaces FAN-PLAN's draft, same OLD anchor). reference/rules.md section 5 should drop its UNVERIFIED mark and cite item #28 (hand to the rules.md delegate)
- Gate: G-P; whichever of FAN-PLAN's doc batch or this lands first, the other drops its #28

### M8: user-repo.md "Scope guidance" contradicts D5
- Status on origin/main 560de56: COVERED by the FAN-PLAN user-repo draft, Edit 4 (its OLD is the #101 text, now on main: reference/user-repo.md:456). rules.md section 9 repeats the marker. Commander decision 1 (2026-10-26) confirms D5 and extends it to skills
- Residual errata for that draft: its Note dates the decision "2026-10-22"; the commander's words are from 2026-10-23T01:58:29Z (uuid e073aea3). It should also say skills are fanned out too (decision 1)
- Gate: FAN-PLAN Batches B and C

### M9: "No spec covers project-scoped rules reaching user scope"
- Status: FIXED by reference/rules.md v1.0 (60e7fd7)

### M10: tool-support-decision-tree.md abort text
- Status on origin/main 560de56: FIXED ON OPEN PR #106 (3de51d6: `origin/feature/harness-hookin:reference/tool-support-decision-tree.md` D-TS13 row, section 7.5 launch sites, section 10 rows). Main's text (":65 Runners stop the run on exit 2", :475-484) is stale against main's code until then. R8c-d2 then changes ERROR to WARN if Q6 = WARN
- Residual: the tool-menu spec line `[x]abort  : change nothing and stop the run` (main :433, #106 :431) is false under #106's runners for any tool setup script. Fold into R8c-d2: `change nothing and stop this script (exit 2)`. No `tool_method_menu` exists in the code yet (git grep "change nothing": none)
- Gate: #106 merged, then R8c-d2

### M11: window.py / user-prompts.py tooling; does scripts/read-session.py have the AskUserQuestion gap?
- Status: the mission scratch tools are dropped. scripts/read-session.py on origin/main HAS the gap. Its user branch skips every message whose content is a list (`if isinstance(content, list): ... continue`). That drops AskUserQuestion answers (tool_result) and any user message sent as content blocks. It also does not filter `isSidechain`. read-session-full.py keeps tool_result entries (role TOOL_RESULT)
- Severity: medium. read-session.py is the harness's documented reader of commander words, and only Jose's own words are decisions
- Fix: code, so it becomes an FX item for the Code sibling (INCIDENT below). Spec: in the user branch, for list content, emit text blocks as COMMANDER, and emit a tool_result whose matching tool_use is AskUserQuestion as `COMMANDER (answer)`; skip entries with `isSidechain: true` unless `--sidechain`; add a fixture test
- Files: scripts/read-session.py (code)

## Apply results

`bash .scratch/session-rcfixd/apply-test.sh origin/main` (export with `git archive` into a `mktemp -d`; apply.pl per edits file):

- origin/main 60e7fd7: one failure, D208 (the OLD ran past a line break). Fixed, then 39/39 ok.
- origin/main 560de56 (after the final fetch): 39/39 ok, `fail=0`; no repo file is touched by two edits files. Lines changed per file: aitools-workspace 31, config-file-safety 25, deploy-paths 19, managed-file-deployment.md 7, sources-of-truth 1, tool-registry SKILL 29, managed-file-deployment.mdc 2, cross-platform-detail 7, cursor-practices 7, harness 4, mfd reference 23, post-push-checklist 15, tool-ops-claude-code 20, claude-shared 4, aitool-ops SKILL 11, delegate SKILL 17, handoff SKILL 25.
- No `.sh` or `.ps1` changes, so `bash -n` and the pwsh parser do not apply.

## Not verified

- Pre-commit step 20 (path refs) and step 16 (governed JSON paths) on the applied outputs; not run. The cited paths exist on 560de56. D105 names `registries/tool-registry.json` inside a skill, which governed-data-access.md allows.
- Item 1 (Windows shell) on Windows; `CLAUDE_CODE_SHELL` / #25558 status.
- That SendMessage works without the Agent Teams flag in the parent session. I checked only this delegate's environment and the /delegate skill's 2.1.307 observation.
- Whether user-level `~/.claude/rules` subdirectories load (the docs do not say).
- The Jamf script size limit.
- #33 and the other Ledger "needs verification" rows (out of scope).

## INCIDENT markers (new; for FX items upstream, not filed)

- INCIDENT (medium, code): `scripts/read-session.py` drops every user message whose content is a list, so commander AskUserQuestion answers and block-content prompts are lost; there is no sidechain filter (M11).
- INCIDENT (low, check): `scripts/check-post-push.sh` step 30 computes `sh_tracker` / `ps1_tracker` (:769-772) but never compares them, while reference/post-push-checklist.md step 30 says "Also verify `Record-DeployOutcome` / `deploy_tracker_record` handles every value". The `.ps1` twin was not read.
- INCIDENT (low, docs): `shared/skills/aitool-ops/SKILL.md` (the reference card) still says SendMessage is unavailable and "No follow-up messages possible" (:181, :244-265); drafted as D201e/f.
- INCIDENT (low, docs): `.claude/rules/documentation-standards.md` "Skill placement" says project skills are "not deployed" and never same-name at both levels, which contradicts rules.md R-4 and commander decision 1 (skills fan out to user scope). Reported by rules.md section 9; no draft here, because the wording depends on FAN-PLAN's skills half.
- INCIDENT (low, docs): reference/harness.md cites an `/artifact-roles` skill that exists in neither shared/skills nor .claude/skills (rules.md section 9; my D208 keeps the citation).
- INCIDENT (low, docs): config-file-safety.md says backup failures are non-fatal, but deploy_managed_file stops on one (aitools-lib.sh:1057-1061); drafted in D180b.

## Open questions (suggested answers)

1. Widen harness.md's intent (D208) or move the conflict-handling section? Suggested: widen. Many docs cite the section.
2. Turn on GitHub `delete_branch_on_merge`? Suggested: not while MERGE-ALL runs; the /delegate text (D177) is enough.
3. Q14 routing for the user rule `delegation.md`: MERGE-ALL's D-DEL5 commit, or a separate edit? Suggested: D-DEL5's commit (one edit to that file); DQ14 covers /handoff.
4. Fix6's "library-style tool" question: suggested yes, named scripts only, folded into logging.md section 7 (M4).
5. Who owns item #28: FAN-PLAN's doc batch or this list? Suggested: whichever lands first uses D28's verified text.

WRITE_BLOCKED: none.
