# S3-SpecRewrite report

1. Drafted the full managed-file spec (reference) for the SOURCE-truth model, plus old->new drafts of the two rules and their two Cursor mirrors; none is applied.
2. The approved State Machine section is copied byte-for-byte (cmp-verified); every other section is rewritten to the interface contract.
3. Consistency table: 34 rows. 24 agree (2 of them after the review fixes). 9 are open questions, where a source is silent or defective. 1 is a real disagreement: the approved text puts cli-config.json under sync_managed_json, and the code does not.
4. Biggest contract defect: CLAUDE.md is a template; adopting LOCAL verbatim into it would bake interpolated values and the machine footer into the template (Q1).
5. Independent reviewer S3-SpecRewrite-Check found 5 contradictions; 4 are fixed in the drafts. The fifth is cli-config.json, which needs the commander (Q9). 14 open questions in total.

PR: https://github.com/nobul-tech/aitools/pull/63 (commits ea21bb2, 8eb3051, + this report update)
Branch: `docs/managed-file-spec-drafts` (from origin/main db4b3c5)

## Files (all under `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-SpecRewrite/`)

| File | What |
|------|------|
| `S3-SpecRewrite-drafts/reference/managed-file-deployment.md` (+ `.diff`) | Full rewrite. Functions table (Try-AutoMerge and deploy-state helpers removed; review_json_fields / Review-JsonFields added; adopt_managed_file internal), Signatures (contract), State Machine (verbatim), one Menu, Non-Interactive, Return Values (incl. `failed`, proposed JSON file-level precedence), Caller Responsibilities (pass ADOPT_PATH, never copy back), Deploy State removed note, Normalization, Encoding (Try-AutoMerge text dropped), Deployment Types, Content Sources (skills dotprofile-first, matching `setup-user-skills.sh:95-98`), Platform values (unchanged), Shell Script Detail (adopt target shared/hooks, written by library), JSON Config Review Detail (SOURCE-owns regime, profile-mirror regime unchanged, script-owned JSON), AI Merge Detail (text only; merge = adopt; failure = `failed`), Backup Policy (LOCAL + adopt target; restore on failure), env vars (+ AITOOLS_ABORT_FILE), auth policy (unchanged) |
| `S3-SpecRewrite-drafts/dot-claude/rules/managed-file-deployment.md` (+ `.diff`) | Types table (one menu; review_json_fields regime), approved-model pointer, "Adopt target" paragraph, backup #1 (adopt target + restore), outcome #4 (`failed` = ERROR, continue) |
| `S3-SpecRewrite-drafts/dot-claude/rules/interactive-menus.md` (+ `.diff`) | One-menu statement; return values list incl. `failed`; non-interactive applies to all three menu functions, no AI merge; Abort section (D-TS13); JSON section split into two regimes; fixed the backwards auto-adopt sentence |
| `S3-SpecRewrite-drafts/dot-cursor/rules/managed-file-deployment.mdc` (+ `.diff`) | Mirror of the rule draft |
| `S3-SpecRewrite-drafts/dot-cursor/rules/interactive-menus.mdc` (+ `.diff`) | Mirror (condensed, as the live .mdc is) |
| `S3-SpecRewrite-consistency.md` | The consistency table |
| `S3-SpecRewrite-Check-findings.md` | Independent reviewer's findings |
| `S3-SpecRewrite-report.md` | This report |

The intent statement: `reference/managed-file-deployment.md`, `.claude/rules/managed-file-deployment.md` and `.claude/rules/interactive-menus.md` have **no** `**Intent**:` block on main (read in full), so there was nothing to keep unchanged. I did not add one (protected; not asked). Optional, for approval: "**Intent**: **Purpose**: Specify how setup scripts deploy managed files: comparison, the review menu, outcomes, adopt write-back, backups and restore. **Scope**: library functions, menus, return values, caller duties, JSON regimes, AI merge detail, backup policy. NOT the choice semantics (agentic-standards.md). NOT per-tool content (tool-registry). **Audience**: every agent writing or calling setup scripts."

## Verification

- `bash .scratch/session-S3-SpecRewrite/check-sm.sh` -> `STATE MACHINE: identical` (26 lines each, cmp).
- `bash .scratch/session-S3-SpecRewrite/make-diffs.sh` -> five `.diff` files written (final: 698, 59, 116, 35, 28 lines).
- Code facts cited below were read in this session from the specdrafts worktree (origin/main db4b3c5).
- `bash scripts/check-pre-commit.sh` (worktree): 6 PASS / 11 SKIP / 2 WARN / 1 FAIL. The FAIL is step 6, the known harvesting/ file tracked 100644, and pre-dates this branch.
- `bash scripts/check-pre-push.sh` (worktree; its step 7 uses an isolated HOME): 6 PASS / 1 SKIP / 3 WARN / 0 FAIL.
- Note: my first pre-commit invocation used a relative path, so it ran against the main checkout. The check is read-only apart from checks.log, and it was re-run against the worktree.

## Not run

- No code or setup script was run (spec-only mission). No `aitools`, no build-deploy.
- Drafts were not applied to the live files (all protected).

## WRITE_BLOCKED

None.

## INCIDENT markers (not filed)

- INCIDENT: `.claude/rules/interactive-menus.md` "JSON field-level review" on main says "When the source (`profile.json`) has a value the live file lacks, that leaf is auto-adopted into the source". The code does the opposite: `scripts/aitools-lib.sh` `sync_managed_json` buildPlan, `if (lHas && !mHas) autoAdopts.push(...)` (live has, profile lacks -> adopt into profile). The approved agentic-standards text agrees with the code. Spec deviation (rule wrong), medium. Fixed in the IM draft.
- INCIDENT: approved agentic-standards text lists `cli-config.json` under `sync_managed_json`; code: `scripts/setup-user-cursor.sh:166-292` writes it with its own node merge (no review, no adopt). Approved text disagrees with code. See Q9.
- INCIDENT: `scripts/setup-user-claude.sh:335-356` (rules accept & adopt) writes MERGED_CONTENT back to the dotprofile and auto-runs `git add`/commit/push on the user repo. No spec permits an automatic commit+push of an adopt; the approved model says the library writes the working tree only. (Code for S3-SourceTruth to remove.)
- INCIDENT: `scripts/setup-user-skills.sh:107-120` adopts a skill deployed from `shared/skills/` into `<userRepoPath>/claude/skills/` (creates a dotprofile fork) instead of the file it was read from. Under the new model ADOPT_PATH is the actual source. See Q11.
- INCIDENT: broken cross-references on main, carried into the drafts unchanged: `.claude/rules/managed-file-deployment.md` "Updating this table" cites `@.claude/rules/tool-lifecycle.md` "Deployment pattern updates", and `reference/managed-file-deployment.md` cites tool-lifecycle.md "MCP server isolation"; neither section exists (found by S3-SpecRewrite-Check, confirmed).
- INCIDENT: `.claude/rules/config-file-safety.md` "Interactive managed file deployment" says "when both sides differ" (3-way phrasing) and its backup section does not cover deployed JSON going through the library.
- INCIDENT: other docs still describe the removed model and are outside my scope: `.claude/rules/aitools-workspace.md:48` (`deploy-state/` row), `reference/agentic-framework.md:170-178` ("Deploy state migration"), `reference/post-push-checklist.md:186` (auto-merge menu parity), `reference/logging.md:38`, glossary terms "auto-merge menu" and "merge-conflict menu" and the "accept & adopt" definition (glossary rule line 40/73 and the `/glossary` registry). TODO(glossary): "review menu" and the outcome "failed" are new governed-term candidates.

## Open questions for the commander (each with a suggested answer)

- **Q1 CLAUDE.md adopt is a transform.** LOCAL = interpolated template + generated `## Machine-Specific` footer; today `adopt_claude_md` (`setup-user-claude.sh:156-184`) strips the footer and reverse-tokenizes before writing the template. A plain library copy to ADOPT_PATH would destroy the `{{PLACEHOLDER}}` tokens and add the footer to the template. *Suggest:* add an optional adopt-transform to the contract (bash: a function name in `ADOPT_TRANSFORM`; PS1: `-AdoptTransform` scriptblock) that the library applies to the content before writing ADOPT_PATH, and compare after the transform. Alternative: CLAUDE.md passes ADOPT_PATH "" (no adopt/merge for CLAUDE.md).
- **Q2 adopt_managed_file is not only internal today.** `setup-user-hooks.sh:251` (reverse discovery: a user-created hook with no SOURCE, adopted into the dotprofile) calls it directly; so does `.ps1:218`. *Suggest:* keep a public helper for net-new adoption (no SOURCE) or drop reverse discovery (SD-2 says one hook version, in shared/hooks; a dotprofile hook is ignored, incident #80). I lean toward dropping it.
- **Q3 How prompt_diff_review reports an AI merge failure.** Its contract values are overwrite|adopt|merge|skip; the approved text makes a merge failure a `failed` file. *Suggest:* add `failed` to DIFF_REVIEW_RESULT (merge attempted, no valid output), mapped to MANAGED_FILE_RESULT `failed` with no write.
- **Q4 Merge preview rejected ([n]o).** Today it falls back to overwrite (`aitools-lib.sh` `_invoke_ai_merge`, `*)` branch). Overwriting after the user rejected a merge is not what they asked for. *Suggest:* [n]o returns to the review menu.
- **Q5 One result for a JSON file with mixed field choices.** *Suggest* (written in REF as proposed, revised after review B9): `failed` > `accept & adopt` > `skipped` > `updated` > `verified`, so a repo write is always visible; skipped fields still appear in deploy.log.
- **Q6 Restore when the file did not exist before.** REF says the library removes it (e.g. a new dotprofile skill file). *Suggest:* approve; otherwise a failed adopt leaves a half-written new file, against "a failure never leaves a half-written file".
- **Q7 Menu for a JSON field only in LOCAL.** The approved text keeps it in LOCAL and says it is "never written to SOURCE without a review", but no review is defined for it (REF defines differing fields as SOURCE fields; review B4). *Suggest:* either define a review `[a]ccept & adopt` / `[s]kip` / `[x]abort` (no overwrite, which would delete user data; non-interactive keeps it), or amend the approved text to "never written to SOURCE". I lean to defining the review.
- **Q13 Backup failure vs "never half-written".** REF keeps "failure to back up: non-fatal" (config-file-safety.md), but then a failed write cannot be restored (review B7). *Suggest:* inside `deploy_managed_file`, a failed backup of an existing file makes the step `failed` with nothing written; other writers keep non-fatal.
- **Q14 How the library knows a file is protected** (for the adopt WARN, approved text "Rules"). The sources-of-truth table is prose. *Suggest:* a path list in the library, kept in sync with the table by a pre-commit step.
- **Q8 JSON "required keys".** review_json_fields has no required-keys input. *Suggest:* required keys = SOURCE's top-level keys (both files must still have them after writing), plus parse.
- **Q9 cli-config.json regime.** Approved text: profile mirror via sync_managed_json; code: script-owned node merge. *Suggest:* amend the approved text to "settings.json" only and record cli-config.json as script-owned (drafts already describe it that way), or open a follow-up to move cli-config.json to sync_managed_json at `cursor.cli`.
- **Q10 Stale sentence in the approved State Machine intro.** "The code implements it in mission HARNESS batch B1; until then the Menus, Return Values and Deploy State sections below describe the code as it is today." Once these drafts apply, the sections below describe the target, and the mission is SOURCE-TRUTH. *Suggest replacement:* "The code implements it in mission SOURCE-TRUTH (scripts/aitools-lib.sh, .ps1)."
- **Q11 Skills adopt target.** *Suggest:* ADOPT_PATH = the file actually read (`$DOTPROFILE_SKILLS/<name>/SKILL.md` when present, else `shared/skills/<name>/SKILL.md`); the Cursor copy then verifies in the same run because its loop reads the source again.
- **Q12 DRY_RUN result.** Code sets MANAGED_FILE_RESULT=verified in dry run (`aitools-lib.sh` deploy_managed_file). The contract is silent. *Suggest:* keep it.

## Reviewer

S3-SpecRewrite-Check (`S3-SpecRewrite-Check-findings.md`) found 5 contradictions, 10 gaps, 6 wording items, 2 broken cross-references. I spot-checked A2 (`aitools-install.sh:167-172`: any non-zero exit -> ERROR row, continue: confirmed) and E (tool-lifecycle.md has no "Deployment pattern updates" or "MCP server isolation" section: confirmed from its full text). Applied in the second commit:

- A2 abort scope: one phrase everywhere ("ends this setup script; the installer continues"); REF, RIM, CIM.
- A3: REF Menus now say the wording is set by the implementation. The approved SM intro stays verbatim (Q10).
- A4: REF "Reverse discovery" paragraph (Q2).
- A5: "no commit, no push" in REF Caller Responsibilities, RMFD, CMFD.
- B1: REF "Several LOCALs for one SOURCE". B3: CLAUDE.md exception line in RMFD/CMFD/REF. B5: JSON choices applied after the last field; abort writes nothing. B8: general protected-file adopt WARN in REF (Q14). B9: Q5 precedence revised.
- D: "Outcome tracking"; "(settings.json)" in the types table; profile-mirror menu text aligned to the code (`aitools-lib.sh` `prompt_json_field_review`); dead "adopt omitted when script-sourced" clause dropped; PS1 tracker calls show their parameters.

Not applied (commander decisions): A1 (Q9), B4 (Q7), B6 (Q8), B7 (Q13), B10 (Q4). B2 is the intended effect of Q11. C (old-model terms in other files) and E are listed under INCIDENT / follow-ups.

## Delegates used

- S3-SpecRewrite-Check (general-purpose, background, read-only + one findings file): independent contradiction hunt.
