# S3-MF-Incidents-Review: independent review of PR #102 (draft incidents #146-#161)

**Reviewer:** S3-MF-Incidents-Review (delegate of S3-MF-Incidents, mission M3-FINISH item 9, Session Commander 10cf255a-c) · **Date:** 2026-10-22
**PR head:** 168bbe4 (docs/mf-incidents) · **Code baseline:** origin/main 8a9dcb5. The worktree `scripts/` has no diff against origin/main.

## Verdict

**Changes needed (small).** 0 blockers, 1 major, 5 minor, 4 nits.

The batch is sound. All 16 entries have the 19 required fields in registry key order. Every file:line citation I re-read holds, except one wrong function in #150. Every "fixed" verdict I re-checked holds. The apply script does what the PR says. One entry (#149) partly duplicates an existing open incident (#9) without saying so. The other findings are severity consistency, one citation, and triage housekeeping. Once the major is fixed, I'd treat this as approve-equivalent.

## Findings

### Major

**M1. #149 partly duplicates #9, and #149 does not mention it.**
- #9, open, medium: "Entry point logging override pattern has unclear design intent". Its affected list includes `scripts/aitools-install.sh` and `scripts/aitools-install.ps1`. Its expected field: "No spec exists for: when and how entry points may override library functions."
- #149's second half is the same gap: "callers never redefine a lib function (or must name the override, as entry-point logging does)", for `relay_child_log` (aitools-install.sh:153 vs aitools-lib.sh:569) and `Write-JsonlRecord` (aitools-install.ps1:65 vs aitools-lib.ps1:449). Both citations hold. The installer sources the lib first (aitools-install.sh:14, aitools-install.ps1:41), so the caller's copy wins.
- #149's discoveryContext lists no related incident.
- **Fix:** either (a) keep #149 to the result-global naming and dot-sourced-scope contract, and move the shadowing evidence to #9 (an update of #9, a separate protected write), or (b) keep it merged and say in #149 that it extends #9, with #9 named in `expected`/`discoveryContext`. I suggest (b): it is one edit, and the suggestedResolution already covers both halves.

### Minor

**m1. #150 cites the wrong PS1 write path. The behaviour it describes is real.**
- #150 cites `ConvertTo-JText` (aitools-json.ps1:66-70). That is the text output of `get`.
- The rewrite path is `ConvertTo-NodeJson` (:171-174, `ConvertTo-Json`). The cause is that `ConvertFrom-Json` (:35) parses numbers into `Double`.
- I ran a probe (pwsh 7.6.3, base engine, scratch file only) on `{"a":0.10,"b":1.50,"c":12345678901234567,"d":1e2}`:
  - Types: `a`, `b` and `d` parse as Double; `c` parses as Int64.
  - Rewrite: `{"a":0.1,"b":1.5,"c":12345678901234567,"d":100.0}`.
- So the claim holds, and it is broader than stated: `1e2` becomes `100.0`.
- **Fix:** cite :35 and :171-174, add the `1e2` case, and drop "not re-run here" (it now has a repro).

**m2. Severity is inconsistent with the severity table** (incident-governance.md "Severity": medium = "Documentation drift, minor behavioral inconsistency"; low = "Cleanup, style, future-proofing").
- #146: the deploy-paths.md table is stale (documentation drift), and step 13 WARNs on every commit that touches those scripts. That is medium, like #157 and #161, which the batch rates medium for doc drift.
- #150: a live bash/PS1 behaviour difference that makes dotprofile commits churn. That is a "minor behavioral inconsistency": medium.
- #156: a live wrong ACTION (the user is told to `git push`, but nothing was committed). That is medium, not cleanup.
- #152 and #159 are latent or worked around, so low is fine there.
- **Fix:** raise #146, #150 and #156 to medium, or state in the triage why they are low.

**m3. #155 `expected` cites no rule that requires an intent in profile.json.**
- sources-of-truth.md "Intent statements" sets the review gate for intents. It does not require them.
- intent-writing covers markdown and code files. Whether it covers a dotprofile data file is not stated.
- The real basis is the pending R23 draft.
- **Fix:** write "No spec exists for: an intent statement in a scaffolded dotprofile profile.json (R23 draft, pending approval, would establish it)", and keep #104 as related.

**m4. Triage row 6 is stale and points to a section that does not exist.**
- Row 6 ends "see open question 1". The triage file has no open-questions section; the PR body covers it under Follow-ups.
- The dotprofile has since moved on: `git -C ~/repos/aitools-nobul-jose grep` on origin/main shows `claude/CLAUDE.md:42-43` reading `nobul-jose/aitools`, and `git status` of that file is clean. This is the local origin/main ref; I did not fetch.
- So the repair appears committed and pushed.
- **Fix:** update row 6 and the PR Follow-up. Also decide whether to record it: incident-governance.md decision tree step 2 sends "something went wrong in production with real impact" to an operational incident, and a corrupted live template is that. I suggest a closed entry with rootCause, correctiveAction (a87ffce plus the template repair) and preventionLayer, in this batch or the next.

**m5. #146 does not name #33 as a close candidate.**
- #33 (open, high): "Deploy template logic not updated when scripts/ source fixed — recurring pattern". Its suggestedResolution is the extract refactor plus step 13.
- PR #95 finished that extraction for setup-user-claude/cursor, and #146 is the stale-check result of it.
- #146 says "related #33 ... not covered". That is correct; it is not a duplicate.
- **Fix:** add #33 to the triage "Close candidates" list (it stays open only for setup-user-hooks).

### Nits

- **n1.** Of the 16 discoveryContexts, only #146, #147 and #150 say the registry #1-#145 was audited. The triage says it was read in full. A short "Audited #1-#145: no match" line in the others would make each entry self-contained (Field quality rules: "Must include what you audited").
- **n2.** #154's suggestedResolution edits `.claude/rules/cross-platform.md`, but `affected` lists only reference/cross-platform-detail.md. #155's resolution adds a test in tests/profile/test-profile.sh, which is not in `affected` either.
- **n3.** Triage counts: "42 rows. 40 are markers; rows 12 and 22 are restatements and row 42 is two 'none' lines" is hard to reconcile (42 - 1 = 41). The verdict totals do add up: 16 new + 5 merged + 3 filed rows + 12 fixed + 5 dropped + 1 n/a = 42.
- **n4.** Apply script edge cases. Neither affects this batch.
  - The no-op branch compares only against `incidents` (`existing.get`). If a batch id is later moved to `closed`, a re-run reports a partial-overlap error, not a no-op.
  - `status: "closed"` passes validation and would be appended to `incidents`, not `closed`.

## What I verified and how

1. **Required fields and field quality, all 16 entries.** The apply script's validator (dry run) checks for 19 fields, no extras, the enums, non-empty `affected` and the text fields. It passed. All 16 use one key order, the same as registry entry #145. I read every entry against "Field quality rules". Titles name deficiencies, not symptoms. Every `expected` cites file:section or says "No spec exists for:". Impacts are concrete. Each discoveryContext has its date and the files read. suggestedResolutions name artifacts and list options where the path is not obvious (#146, #147, #149, #160). Exceptions: m3 and n1.
2. **New entries re-verified against the code** (git show origin/main, line ranges printed):
   - #146: holds. check-pre-commit.sh:267/:275, .ps1:262, deploy-paths.md:56-60, build-deploy.sh:625, :717, :812-843.
   - #147: holds. aitools-lib.sh:860-866, .ps1:752-757, script-standards-detail.md:239-256, setup-user-config.sh:367-370.
   - #148: holds. aitools-profile.sh:71-79, :770-783; logging.md headings 1-6; setup-user-config.sh:165-189; aitools-lib.sh:432.
   - #149: holds (see M1). aitools-lib.sh:125-134.
   - #150: holds, with the wrong function cited (m1). Probe run.
   - #152: holds. aitools-lib.sh:154-159, :216-225. `put via` appears only at aitools-profile.sh:783, :872, :907, :1040, :1147, all before cmd_register :1219 and cmd_migrate :1443. scripts/aitools:198-199. Lib mentions of register and migrate are comments only (:138, :319, :367).
   - #153: holds. delegate SKILL.md :184, :212-213; no cwd text.
   - #154: holds for (3). .gitattributes:2, test-user-init.sh:328-329, cross-platform-detail.md headings. (1) and (2) are cited from the reports, as the entry says.
   - #155: holds. aitools-profile.sh:1242, .ps1:1085; grep finds intent only in header comments.
   - #156: holds. aitools-profile.sh:969-971, aitools-lib.sh:439-447, .ps1:370-376.
   - #157: holds. script-standards-detail.md:125-131; aitools-install.sh:136-143 now escapes; jsonl_record at aitools-lib.sh:531.
   - #158: holds. cross-platform.md:32-33 and the exemptions table; no aitools-json or .pl text.
   - #159: holds (bash). aitools-lib.sh:658-691, aitools-profile.sh:70-79.
   - #160: holds. aitools-lib.sh:159-199 (-Command), cross-platform.md:119-128.
   - #161: holds. tree :306-310, :399, :564-567; aitools-lib.sh:371-378.
3. **"Fixed" verdicts re-verified:**
   - Row 1 (#98 anchors): holds. build-deploy.sh:137 `^\s*source\s`, :164 `^\s*\.\s`.
   - Row 2: holds. check-pre-push.sh:154, :161, :172, :220 and .ps1:247, :252, :268 say "see deploy.log".
   - Row 5: holds. sh utf16_bom/jcheck :212-229 and expand_home :232-238; ps1 Read-ResolverJson :150-166 and Expand-Home :168-172.
   - Row 14 (code): holds. `git grep 'Object.values(p.profiles)[0]' origin/main -- scripts shared` has no hits.
   - Row 15: holds. ui_commit :323-345 has the identity fallback, log_warn + ACTION and no `|| true`; ui_scaffold_claude_md :881-897.
   - Row 18: holds. The tree exists on origin/main; check-path-refs-allow.txt:25, :28.
   - Row 28: holds. ui_register_flow :657-668, ui_profile_dirty :350-357.
   - Row 32: holds. scripts/aitools:2049-2055.
   - Row 36: holds. tree :618-628, :738.
4. **Duplicates.** I listed all 145 titles (138 open/planned, 7 closed; max 145; unique; no gaps) and ran a keyword scan of every entry's full text for each batch item. Then I read #9, #25, #33, #71, #75, #83, #104, #108 and #140 in full. Result: M1 (#9) and m5 (#33). #153 and #140 differ (cwd vs HOME), and #153 cites #140. #155 and #104 differ (a scaffolded data file vs rules and scripts). The `<userRepoPath>/...` placeholder in #153's affected list has precedent in #140.
5. **Source markers.** I read the cited lines in S3-M3-B5a-report:111, ConfigKey-report:87, LibFix-report:129, LibFix-Review-pr80:189/194/199, UserInit-report:96, UserInit-Review-pr86-batch5:125, JsonRename-report:69, Install-report:158, Profile-Review-pr73:96, Profile-Review2-pr76-77:94, Docs-approval-page:94/103 and Resolver-Review-pr86-batch2:165-166. Each holds the marker the triage names.
6. **Apply script (dry run only, scratch copy; `--write` never run anywhere):**
   - Dry run: `dry run ok: would append ids 146-161 (16 entries); registry after: 154 incidents, 7 closed, max 161, unique True, lastUpdated 2026-10-22`, exit 0. The copy is byte-identical afterwards (`cmp`).
   - Negative cases, each exit 1: an id colliding with 145 ("already in the registry"), a batch starting at 147 ("not sequential from registry max + 1 (146)"), and a missing `impact` ("missing fields ['impact']").
   - The round-trip guard passed on the real registry layout.
   - The real registry has no diff against origin/main.
7. **Severity and glossary.** Severity: see m2. Glossary: none of the 16 is a terminological ambiguity (two words for one thing, or one word with two meanings). #148 introduces the phrases "library-style tool" and "advisory warning" but does not define them as terms. No /glossary routing is needed. The 5 dropped rows (8, 10, 13, 29, 38) are prompt or draft errata or coordination questions, not live-artifact defects. I agree with dropping them.

## What I did not verify (unknown)

- Windows or PS1 execution of anything except the #150 probe on macOS pwsh.
- The PS1 half of #159 (Initialize-Logging).
- Traps (1) and (2) of #154.
- The CI-red state of b70fc64 (#151).
- The cwd write (#153).
- The remaining "fixed" rows 4, 6 (code), 23, 31 and 34. Rows 1, 2, 5, 14, 15, 18, 28, 32 and 36 were checked.
- Whether the S3-M3-Docs drafts cited in #147, #148, #157 and #161 cover every line named.
- Markers in S3-Profile-Review3-pr79-80-82.md, which is in no branch.
- Whether the dotprofile repair (m4) is on the remote. I read the local origin/main ref and did not fetch.

Scratch scripts: `.scratch/session-mfirev/` (dryrun.sh, cites.sh, cites2.sh, cites3.sh, numprobe.ps1, titles.py, show.py, affected.py).

## Re-check (0b6b00e)

**Reviewer:** S3-MF-Incidents-Review · **Date:** 2026-10-22 · **PR head:** 0b6b00e · **Code baseline:** origin/main 8a9dcb5. Sources: S3-MF-Audit-findings.md section 8 (I-1..I-4), from `origin/docs/mf-audit`.

**Verdict: changes needed (small).** 0 blockers, 1 major, 4 minor, 3 nits.
- #162 is sound.
- The I-2 merge into #147 and the I-3 merge into #148 are both sound.
- #163 has the right content, but every code citation in its observation points to the wrong lines.
- The dry run passes. Neither new entry is a duplicate.

### Major

**R-M1. All three line citations in #163's observation miss the code they describe.** Here is what origin/main has at those lines:

| #163 cites | What is there | Where the described code is |
|---|---|---|
| setup-user-settings.sh:80-83 | `log_warn "profile.json not found ..."` + WARN "profile.json missing" | :72-75 ("Counted (S3-M3Lead decision)" comment, log_error, ERROR "claude settings") |
| setup-user-skills.sh:110-114 | `log_error "Skill source not found: $skill_name"` | :56-60 (log_error + the two ERROR rows "claude skills" / "cursor skills") |
| setup-user-cursor.sh:94-99 | ripgrep install failure / success | :353-358 ("Not counted again" comment, info line, ERROR "cursor cli" "skipped (dotprofile error)") |

The entry's own discoveryContext gives the right ranges (settings.sh:66-80, skills.sh:50-62, cursor.sh:350-360). The observation was probably written from other line numbers.

**Fix:** use :72-75, :56-60 and :353-358. The PS1 twins hold the same text, and I verified them: settings.ps1:58-61, skills.ps1:48-51 (one "skills" row, the A-22 parity gap), and cursor.ps1:273-278. Cite them too, rather than "not re-read".

### Minor

**R-m1. #162 and #163 do not use the batch's key order.**
- Entries #146-#161 follow the registry order (id, title, status, severity, ...).
- #162 and #163 start with `status, linked, referenceFile, discipline, ...`, and put `id` after them.
- The validator does not check order, and the apply script appends them as written. The registry would then hold the only two entries whose first key is not `id`.
- **Fix:** reorder both to the registry key order.

**R-m2. #163 `expected` stretches two rules.**
- .claude/rules/cross-platform.md and interactive-menus.md require bash and PS1 parity: identical menus and outcomes within one script pair. They do not require the same outcomes across different scripts in one run.
- script-standards-detail.md 'Governed summary outcomes' (:294) exists and fits the "skipped" point.
- **Fix:** keep 'Severity decision guide' and 'Governed summary outcomes'. Drop the cross-platform and interactive-menus claim, or reword it as "nearest: parity rules, which cover pairs only". The "No spec exists for:" line already carries the gap.

**R-m3. #162 says the lib writers have "no caller outside the lib". That is true, but it hides the reason.**
- `aitools-install.ps1` calls `Write-JsonlRecord` at :87 and :127. Those calls resolve to the installer's own definition at :65, which shadows aitools-lib.ps1:449 (the installer dot-sources the lib at :41 first).
- In bash, the lib's `jsonl_record` is called only by the lib's relay (:554). The installer uses its own `jsonl_write`.
- So the lib copies are dead because the installers shadow them. That is #149's second half and audit A-1.
- **Fix:** say "shadowed by the installers' own copies (#149, audit A-1)", and add #149 to the related incidents in its discoveryContext.

**R-m4. #147's `affected` lists only reference/script-standards-detail.md.** The rewritten resolution aligns code sites: the lib's 7 ACTION sites per language (A-5) and setup-user-config.sh:216-222 (A-10).
- **Fix:** add scripts/aitools-lib.sh/.ps1 and scripts/setup-user-config.sh/.ps1, or say that the code alignment is tracked by the audit's FIX-3.

### Nits

- **R-n1.** #148's suggestedResolution says twice to add the resolver to the 'Exemptions table' ("add the resolver to the script-standards-detail.md exemptions table" and "Also add a 'library-style tool' row to ... 'Exemptions table'"). Its observation also says twice that the table lacks the row. Merge each pair.
- **R-n2.** #163 could name #142 as related: one failure producing more than one ERROR row, in the installers.
- **R-n3.** #163's `affected` has setup-user-settings.sh and setup-user-skills.sh without their .ps1 twins. Option B changes both languages, and skills.ps1 also needs the A-22 row fix.

### Merges (question 3)

- **I-2 into #147: sound.** I-2 itself says "Same root as the S3-M3-ConfigKey-Review INCIDENT on auto-promote". The rewritten entry covers I-2's added question (how an ACTION pairs with an ERROR) in `expected` and in option B. Raising the severity to medium fits the table, since the conflict is live in 7 sites per language. One entry is right.
- **I-3 into #148: sound.** Both describe the one undefined contract for the resolver as a library-style tool: the logging contract and the missing script-standards exemption. The four stderr-only exits are a code instance (A-6), not a spec gap. They are fine here because `affected` now names aitools-profile.sh and the resolution names FIX-6.

### What I verified (re-check)

1. **Field quality, #147, #148, #162 and #163.** All 19 fields are present; the validator passed.
   - Titles name the deficiency.
   - Observations are concrete. #163's citations fail (R-M1).
   - Each `expected` cites a section or says "No spec exists for:"; #163 overreaches (R-m2).
   - Impacts are concrete.
   - Each discoveryContext has its date, what was read, and "Audited #1-#161".
   - suggestedResolutions list options A/B(/C) and name artifacts.
2. **Citations, origin/main 8a9dcb5:**
   - #147: holds. Tree :64 (D-TS12, verbatim), aitools-lib.sh:290-292, :327-328, setup-user-config.sh:216-222, and the earlier lines.
   - #148: holds. aitools-profile.sh:39-43, :167, :181, :194, :207 (all `printf ... >&2; exit 2`, no log_detail), and script-standards-detail.md:1156 '## Exemptions table'.
   - #162: holds. logging.md :66, :101 (checks.jsonl only); aitools-install.sh:124, :143; aitools-install.ps1:51, :65, :87, :127; lib jsonl_record :531, Write-JsonlRecord :449. Wording note in R-m3.
   - #163: fails (R-M1). The described code is real, at other lines.
3. **Duplicates.** I scanned keywords across #1-#145 and batch #146-#161 (deploy.jsonl, LOG_JSONL, jsonl_record; re-count, "Not counted again", "dotprofile error", "two ERROR rows", "S3-M3Lead decision"). Hits: #74 (mentions deploy.jsonl `host` only), #149, #157 and #142. I read #74 and #142 in full. Neither new entry duplicates any of them; #149 and #142 are related (R-m3, R-n2).
4. **Dry run.** The fresh scratch copy came from `git show origin/main:registries/incidents.json`. Result: `dry run ok: would append ids 146-163 (18 entries); registry after: 156 incidents, 7 closed, max 163, unique True, lastUpdated 2026-10-22`, exit 0. The copy was unchanged afterwards, and the worktree registry has no diff against origin/main. `--write` was not run.

### Not verified (re-check)

- The S3-M3Lead plan section 2 decision 3 text ("deploy.jsonl coverage"). I took it from the audit and the entry; I did not read the plan on its branch.
- Whether the S3-M3-Docs logging.md draft (row 16) answers #162's coverage question. The entry says the same.
- Anything run on Windows.
