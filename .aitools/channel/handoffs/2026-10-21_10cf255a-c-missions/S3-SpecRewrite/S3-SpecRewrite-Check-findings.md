# S3-SpecRewrite-Check findings (2026-10-21)

Summary:
1. The drafts mostly agree with the approved text and the contract. There are 2 contradictions with approved text: cli-config.json's regime, and what "global" abort means. There are 4 contradictions or gaps against code the drafts leave unaddressed: the hooks reverse-discovery menu, rules auto commit+push, the skills second LOCAL, and the CLAUDE.md transform.
2. The 5 drafts contain no old-model terms. Old-model terms are still live in files no draft touches: glossary (2 terms + 1 definition), aitools-workspace, config-file-safety, agentic-framework, logging, and the post-push step 29 checklist/check.
3. Two broken cross-references were carried into the drafts from main (INCIDENT). The known-stale State Machine intro sentence is confirmed, and it now also contradicts draft reference L102.

Reviewer: S3-SpecRewrite-Check. Read-only review. This file is the only thing written.
Abbreviations: REF = draft `reference/managed-file-deployment.md`; RMFD = draft `dot-claude/rules/managed-file-deployment.md`; RIM = draft `dot-claude/rules/interactive-menus.md`; CMFD / CIM = the `dot-cursor` .mdc twins; APP = approved `mfchoices/.claude/rules/agentic-standards.md`; LIB = `specdrafts/scripts/aitools-lib.sh`. All drafts are under `specdrafts/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-SpecRewrite/S3-SpecRewrite-drafts/`.

## A. Contradictions

**A1. cli-config.json regime: drafts contradict the approved text (the approved text is wrong).**
- APP:72-74 says that `sync_managed_json` / `Sync-ManagedJson` "(settings.json, cli-config.json) keep their profile-mirror rule".
- REF:37 says Sync-ManagedJson is for `settings.json` only. REF:454-466 says cli-config.json is "Script-owned ... no review menu and no adopt", with adopt target "(not adoptable)".
- The code agrees with the drafts. `setup-user-cursor.sh`:166-208 writes cli-config.json with its own node merge. `sync_managed_json` is called only from `setup-user-settings.sh`:127 (grep across the setup-user-* scripts).
- Fix: the commander amends APP:72-73 to "(settings.json)", or drops the parenthetical. Until then the drafts contradict approved text. This needs an explicit commander decision; the drafts should not ship over it silently.

**A2. Abort scope: drafts disagree with each other.**
- REF:150-151 says "Abort ends the setup script, not the installer run: the installer records the script as aborted and continues."
- RIM:102-103 says "only `abort` is global (stops the run)". RIM:117 says `[x]abort : stop the run (global)`. REF:447-448 says "[x]abort (exit 2, global)".
- Code today: `aitools-install.sh`:167-172 runs each setup script, and on any non-zero exit (including 2) logs an error, writes an ERROR row and continues. `AITOOLS_ABORT_FILE` does not appear anywhere in scripts/ on main yet (grep found nothing in aitools-install.sh/.ps1, aitools, aitools.ps1).
- So "global / stops the run" is false today. "Records the script as aborted" is a D-TS13 target, and neither APP:91 nor packet section 6 states it.
- Fix: use one phrase everywhere, e.g. "abort ends this setup script (exit 2); the installer continues with the next script". Mark "records as aborted" as D-TS13 runner behaviour (target).

**A3. REF:102 "the exact wording is the code's" against the menus it shows.**
- REF:109-125 shows `[a]ccept & adopt`, `[m]erge & adopt` and `stop this script (exit 2)`.
- The code says `[a]dopt     : local wins -> copy back to %s`, `[m]erge     : AI-assisted merge` and `[x]abort    : stop deployment` (LIB:1027-1038). The code also still has the auto-merge menu (LIB:972-1018).
- Together with the stale intro sentence at REF:76-78 ("until then the Menus, Return Values and Deploy State sections below describe the code as it is today"), both statements are now false: those sections describe the target.
- Fix: replace REF:76-78 with "The sections below describe the target model; mission HARNESS batch B1 implements it." Change REF:102 to "the exact wording is set by the B1 implementation (identical in bash and PS1, step 29)".

**A4. "One review menu" contradicts the hooks reverse-discovery menu (code, not covered by any draft).**
- RIM:11 says "There is one review menu". REF:100 says the same. REF:36 says `adopt_managed_file` is "Internal to the library ... Callers do not call it".
- `setup-user-hooks.sh`:240-258 shows a second menu, `[a]dopt to dotprofile  [s]kip`, for user-created hooks. It calls `adopt_managed_file` directly (:251) and writes `$USER_REPO_PATH/claude/hooks/` (the dotprofile).
- REF:398-400 says "never the dotprofile repo ... a dotprofile copy would be ignored (SD-2, incident #80)".
- Fix: REF needs a "Reverse discovery" paragraph. It should say one of three things: reverse discovery is out of the review-menu model (and why), or it is removed, or it adopts into `shared/hooks`. It should also note that it is the one remaining direct caller of `adopt_managed_file`. Suggested answer: adopt into `shared/hooks/` through the library, for consistency with SD-2, and keep `[s]kip` as the non-interactive default.

**A5. Rules merge auto commits and pushes the dotprofile (code, not covered).**
- `setup-user-claude.sh`:335-357 writes `MERGED_CONTENT` to `$USER_REPO_PATH/claude/rules/` and then runs `git add`, `git commit -m "Sync merged ..."` and `git push`.
- APP:76-81 and APP:104-106 say adopt writes the repo working tree, with "the review gate applies at commit and PR". REF:403-404 (hooks) says "the user decides whether to commit it".
- No draft says that the library never commits or pushes, so this caller behaviour stays unaddressed.
- Fix: add one line to REF "Caller Responsibilities" and to RMFD:30-33: "Adopt and merge write the working tree only; neither the library nor a caller commits or pushes." List `setup-user-claude` :335-357 as code B1 must remove.

## B. Gaps

**B1. Skills deploy to two LOCALs. The approved "next run asks nothing" does not hold for the second.**
- `setup-user-skills.sh`:128-133 copies an adopted skill to every other deploy target (`~/.cursor/skills`). The contract and REF:30 cover one LOCAL plus one adopt target.
- After adopt in the Claude pass, the Cursor LOCAL differs from the new SOURCE. APP:79-80 says "the next run verifies the file and asks nothing", which is false for that copy.
- Fix: REF should say that callers with several LOCALs for one SOURCE deploy each LOCAL through `deploy_managed_file`, and that a second LOCAL may be reviewed again. Alternatively, the library could accept a list of extra LOCALs. Suggested: keep the single-LOCAL contract. The Cursor copy will then show as `updated` (non-interactive) or be reviewed again. Document this.

**B2. Skills adopt target changes from today.**
- REF:351-352 says "The adopt target for a file is the primary or fallback source it was actually read from".
- Today `setup-user-skills.sh`:116-119 always adopts into the dotprofile, even when the source was `shared/skills/`. Under REF, adopting a shared skill writes `shared/skills/` in the aitools repo. RMFD:47 calls that directory "vendored from upstream".
- Not contradicted by APP, but it is a behaviour change no draft flags. Suggested: accept it (it matches "copies it to the repo") and list it under B1 code changes.

**B3. CLAUDE.md template adopt (REF:280-286, Q1) leaves an approved rule with no fallback.**
- APP:102-103: "Callers pass the path; they do not copy files back themselves". `adopt_claude_md` (`setup-user-claude.sh`:156-184) is a caller-side transform.
- REF says the template "cannot pass ... as a plain ADOPT_PATH" but does not say what happens until it can. RMFD:30-33 and CMFD:21 state "Callers never copy files back" with no CLAUDE.md exception.
- Fix: until Q1 is decided, add an explicit exception line to RMFD/CMFD and REF ("CLAUDE.md: adopt via the template transform; see Q1"). Suggested answer for Q1: the library takes an optional adopt-transform callback, and `adopt_claude_md` becomes that callback.

**B4. Fields only in LOCAL: "never written to SOURCE without a review", but no review is defined.**
- APP:70-71 and RIM:90-91 both say this.
- REF:422-424 defines a differing field as one in SOURCE that LOCAL lacks or has a different value for, so a LOCAL-only field is never reviewed and never adoptable.
- Either "without a review" implies a review that does not exist, or the approved text means "never". Suggested: write "is kept in LOCAL and never written to SOURCE" (drop "without a review"), or define an `[a]dopt`/`[s]kip` review for LOCAL-only fields. This needs a commander decision. APP is ambiguous here.

**B5. JSON abort mid-file.**
- REF:426-427 says adopted values are written "immediately, before the next file is reviewed" (per file). APP:91 says abort leaves LOCAL and the repo unchanged.
- REF does not say that an `[x]` on field N discards the overwrite and adopt choices for fields 1..N-1. `sync_managed_json` meets this today, because prompts run before apply (LIB:1385-1400 plan/apply structure).
- Fix: add one line to REF "Regime 1": "choices are applied after the last field; abort writes nothing."

**B6. JSON "required keys" validation has no input.**
- REF:430-431 and APP:95 say JSON is validated for "parses, required keys present".
- The contract `review_json_fields SRC_FILE DEST ADOPT_PATH` and `Deploy-ManagedFile` have no required-keys parameter. Unknown where the keys come from.
- Suggested: "required keys = the top-level keys of SOURCE", stated in REF.

**B7. A backup failure is non-fatal, but approved says a failure never leaves a half-written file.**
- REF:555 says "Failure to back up: Non-fatal (warn and proceed)". REF:556-559 and APP:96-99 say restore on failure and never leave a half-written file.
- If the backup failed and the write then fails, nothing can be restored.
- Suggested: for managed files under `deploy_managed_file`, a failed backup of an existing file makes the step `failed` (nothing written). Keep "non-fatal" only for the other writers (config-file-safety.md "Backup before overwrite"). This needs a commander decision.

**B8. The protected-file adopt WARN is stated only for the markdown type.**
- APP:104-106 is general.
- REF:276-278 covers `shared/claude-shared.md` only. There is no statement for the library's general behaviour, nor for how the library detects "protected" (the sources-of-truth.md table is prose, not data).
- Fix: add it to the REF "Deploy-ManagedFile" behaviour. Suggested detection: a path list in the library that the pre-commit check keeps in sync with the sources-of-truth table.

**B9. File-level JSON result precedence (REF:195-199) is a new proposal.**
- APP and the contract do not cover it.
- `skipped` > `accept & adopt` means a file with one adopted field and one skipped field reports `skipped`. The tracker then records no adopt, although the repo was written.
- Suggested: `failed` > `accept & adopt` > `skipped` > `updated` > `verified`, so the repo write is always visible. This is a commander decision (Q5).

**B10. AI merge `[n]o` (REF:534-535, Q4).**
- Today `[n]o` falls back to overwrite (LIB:893-896). An AI failure offers an `[o]/[s]` fallback (LIB:855-865), whereas REF:531-533 targets `failed`.
- Not a contradiction (it is the target), but B1 must change both. Suggested Q4 answer: `[n]o` returns to the review menu.

## C. Old-model terms still in force (files no draft covers)

- `.claude/rules/glossary.md`:40 `auto-merge menu`, :73 `merge-conflict menu` (governed terms). `registries/glossary.json`:30 (definition of `accept & adopt` cites "both auto-merge and merge-conflict menus"), :77, :215-216. Fix through the `/glossary` skill.
- `.claude/rules/aitools-workspace.md`:48 `deploy-state/` "Last-deployed file hashes for drift detection".
- `.claude/rules/config-file-safety.md`:121 says "when both sides differ" (3-way phrasing). The "Backup before overwrite" section (markdown and shell handled by `deploy_managed_file`; JSON: the caller MUST back up) does not mention deployed JSON going through the library (compare RMFD:56-61).
- `reference/agentic-framework.md`:172-178 still describes bootstrapping the shadow (`get_deploy_shadow`) before auto-merge.
- `reference/logging.md`:38 lists deploy-state.
- `reference/post-push-checklist.md`:186 and `scripts/check-post-push.sh`:754 still look for the "auto-merge menu" in step 29.
- The live `reference/managed-file-deployment.md` on main still has the whole old model (Try-AutoMerge :19, Ancestor :36-48, AdoptLabel :61-91, Deploy State (Shadow System) :140-144). The draft replaces it.

## D. Wording

- RMFD:68-72 and CMFD:43 say "Three-outcome tracking: created, updated, or unchanged" and then list six outcomes. Rename to "Outcome tracking".
- RMFD:20 and CMFD:16 list cli-config.json in the row whose strategy is "Profile-sourced fields use granular field-level review (sync_managed_json)". That suggests cli-config is reviewed, which contradicts REF:454-466 (see A1). Add "(settings.json)" after "Profile-sourced fields".
- RIM:120-123 ("adopt omitted when a changed field is script-sourced") is kept as "unchanged", but `buildPlan` always emits adoptAllowed `'1'` (LIB:1472), and `sync_managed_json` is the only caller (LIB:1589; PS1 :1559). The clause is dead. Drop it, or mark it "not reachable today".
- RIM:114-117 shows profile-mirror menu text that differs from the code. Code: `[a]dopt     : keep settings.json value -> write to <label>`, `[x]abort    : stop the run` (LIB:1328-1333). Draft: "local value wins → write back to profile.json", "stop the run (global)". This was carried from main; align it with the code or label it illustrative.
- REF:62-63 shows `Record-DeployOutcome failed` and `Write-DeployTrackerSummary` without `-ToolName` / `-ItemName`. The code signatures are `(Outcome, ToolName, ItemName)` and `(ToolName)` (aitools-lib.ps1:1261-1275). Show the full call.
- APP:77 says adopt "writes the result to LOCAL", but APP:88 says "LOCAL kept". REF:190 follows the table, which is fine. Note it for an APP touch-up.

## E. Cross-reference defects (INCIDENT)

- INCIDENT: RMFD:97-98 and CMFD:59 point to `@.claude/rules/tool-lifecycle.md` "Deployment pattern updates". tool-lifecycle.md has no such section. Its headings are: Phase 2 gate, Under Evaluation guard, Bundled dependency graduation, PATH refresh after install, Install cleanup, Install method discovery, Onboarding checklist, Dotprofile priority, When to invoke /tool-registry, Cross-references. This is a pre-existing broken reference that the drafts carry forward.
- INCIDENT: REF:386-387 points to `@.claude/rules/tool-lifecycle.md` "MCP server isolation". No such section exists (pre-existing, carried forward).

## F. Checked and found consistent

1. The REF State Machine (REF:72-96) matches the approved block (mfchoices reference :21-45) line by line, read side by side.
2. The REF signatures (REF:46-64) match the contract for bash and PS1. All twin names exist in the code: `tty_interactive`/`Test-InteractiveConsole` (LIB:774, ps1:773), `_merge_validate`/`_MergeValidateWrapper` (LIB:665, ps1:660), `deploy_tracker_init|record|summary` / `Initialize-DeployTracker`/`Record-DeployOutcome`/`Write-DeployTrackerSummary` (LIB:1248-1275, ps1:1254-1274).
3. Menu letters and order are identical across REF:109-125, RIM:11-14, CIM:9-11 and the State Machine: o/a/m/s/x. Without a target: o/s/x. JSON: o/a/s/x, no m.
4. The non-interactive rules (REF:155-165, RIM:46-54, CIM:22) match APP:61-62 and the code: force at LIB:930, no tty at LIB:936, EOF to default overwrite through `read_tty_choice` at LIB:787-795.
5. RIM:100-102 corrects main's auto-adopt direction to "live file has a leaf profile.json lacks", which matches `buildPlan` LIB:1451 (`lHas && !mHas` -> autoAdopts).
6. The hooks adopt target in REF:398-406 matches the code's main loop (`setup-user-hooks.sh`:170-189, `shared/hooks` only, SD-2).
7. REF:127 "unrecognised answer selects overwrite" matches LIB:1056-1057.
8. The return values in REF:173-193 match the contract. `failed` is added in REF, RIM:25-27, CIM:17-18 and RMFD:70-72, consistent with "summary ERROR when failed>0" (REF:35, REF:223).
9. The setup-script list in REF:4-5 is right to drop setup-user-mcp: it has no `deploy_managed_file` call (grep of setup-user-mcp.sh).
10. None of the 5 drafts uses ancestor, shadow, AdoptLabel, merge-conflict, try_auto_merge or "copy back", except in "Removed 2026-10-21" notes (REF:40-42, REF:229-232) (grep).

No WRITE_BLOCKED events. No delegates used. No commits, no PR.
