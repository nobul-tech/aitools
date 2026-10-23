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
