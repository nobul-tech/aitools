# S3-MF-Incidents triage: INCIDENT markers in the M3 reports

**Mission:** M3-FINISH item 9 (S3-MF-Incidents, orchestrator S3-M3Finish, Session Commander 10cf255a-c) · **Date:** 2026-10-22 · **Baseline:** origin/main 8a9dcb5 · **Branch:** docs/mf-incidents

`registries/incidents.json` is **not modified**. Drafts in this folder:

- `S3-MF-Incidents-batch.json`: 16 entries, #146-#161, to append to the `incidents` array in this order.
- `S3-MF-Incidents-apply.py`: the apply step (python3 stdlib). Dry run by default, `--write` to write.

## Registry state

- `registries/incidents.json` on 8a9dcb5: 3,453 lines. I read it in full with offset/limit. It holds 138 open/planned and 7 closed entries (13, 14, 52, 53, 80, 81, 82). The max id is **145** and the ids are unique. The next id is **#146**, as the packet says.
- After the apply (tested on a scratch copy): 154 incidents, 7 closed, max 161, ids 1-161 unique and contiguous. Running it a second time is a no-op.

## Sources searched

- `grep -rn INCIDENT` over every M3 folder under `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/` on origin/main: S3-M3-B5a(-Review), S3-M3-B8a/b/c, S3-M3-Claude(-Review), S3-M3-ConfigKey(-Review), S3-M3-Docs, S3-M3-Install(-Review), S3-M3-JsonRename, S3-M3-LibFix, S3-M3-LibKey(-Review), S3-M3-Register, S3-M3-Resolver, S3-M3-UserInit(-Review) and S3-Profile.
- PR #97's S3-M3Lead-plan.md, via `git show origin/docs/m3-lead-plan:...`. It has no INCIDENT marker.
- The bodies, comments and reviews of the M3 PRs (#73, 76, 77, 79, 80, 82, 83, 84, 86, 89-92, 95-97), checked with `gh pr view --json`. These only repeat the report markers.
- Not found: S3-Profile-Review3-pr79-80-82.md is cited by the M3Lead plan and PR #82 ("see the INCIDENT in the full report"), but it is in no branch (`git log --all`). Its markers are known only where other reports repeat them (lib result naming, now #149; the scaffold commit identity, now resolved). Anything else in it is **unknown**.

## Triage table

Verdicts: **new** = filed in the batch; **filed** = an existing incident covers it; **fixed** = verified fixed on origin/main 8a9dcb5, not filed; **merged** = folded into another new entry; **dropped** = not a defect in a live harness artifact.

| # | Marker source (file:line) | Marker (short) | Verdict | Target / evidence |
|---|---|---|---|---|
| 1 | S3-M3-B5a-report.md:109 | build-deploy inliners replaced every line naming the lib | filed + fixed | #98. Fixed by c421511 (PR #95): build-deploy.sh:137 and :164 now anchor `^\s*source\s` and `^\s*\.\s`. #98 is a close candidate |
| 2 | S3-M3-B5a-report.md:110 | step 7 messages said "see checks.log" | fixed | 266a1ba. check-pre-push.sh:154, :161, :172, :220 and .ps1:247, :252, :268 say "see deploy.log" |
| 3 | S3-M3-B5a-report.md:111 | pre-commit step 13 still lists claude/cursor as duplicated templates | **new #146** | check-pre-commit.sh:267, .ps1:262, deploy-paths.md:56-57, build-deploy.sh:625, :717, :812 |
| 4 | S3-M3-B8a-report.md:83; S3-M3-B8a-Review-pr91.md:151 | build-deploy inlines the lib but not the resolver; no smoke check | fixed | PR #95: resolver embedded (build-deploy.sh:436-455, :1637-1642) and step 7 smoke run (check-pre-push.sh:115-117, :174-220) |
| 5 | S3-M3-B8c-report.md:109; S3-M3-B8c-Review-pr90.md:76 | resolver sh/ps1 differ on `~` and UTF-16 config.json | fixed | Both now expand `~` (aitools-profile.sh:232-236, :442; .ps1:168-171, :354) and both reject UTF-16 (sh:212-227; ps1:150-163) |
| 6 | S3-M3-Claude-report.md:79 | CLAUDE.md adopt reverse-tokenized by fixed order; live template corrupted | fixed (code and data) | Code: a87ffce (setup-user-claude.sh:183-192, one pass, longest value first). Data: the dotprofile template read `nobul-{{PROFILE_NAME}}/aitools` at :42-43 on its origin/main at first check. Another session repaired it in dotprofile commit 525ee49, "Sync CLAUDE.md template with shared and repair aitools links" (2026-10-22 19:14 -0700). Not filed; see the report's open question 1 |
| 7 | S3-M3-Claude-report.md:80 | managed-file-deployment.md documents the first-profile fallback | filed | #76 (affected already lists .claude/rules/managed-file-deployment.md, .mdc and reference/managed-file-deployment.md). Still stale: rule :51, .mdc :31, reference :393, user-repo.md :84. Drafts are in PR #96 |
| 8 | S3-M3-Claude-report.md:81 | mission prompt named BEGIN/END "profile resolution" markers that don't exist | dropped | Prompt drift. `git grep -i "profile resolution"` over scripts, reference, .claude and shared: no hits. No live artifact names the markers |
| 9 | S3-M3-ConfigKey-report.md:87; S3-M3-ConfigKey-Review-pr86-batch4.md:115 | write_summary's OK to WARN promotion is not documented | **new #147** | aitools-lib.sh:860-866, .ps1:752-757, script-standards-detail.md:239-244, setup-user-config.sh:367-370 |
| 10 | S3-M3-ConfigKey-report.md:88 | launch prompt named `--alias`, the flag is `--machine-alias` | dropped | Launch-prompt drift between missions. The flag is now `--machine-id` (M3Lead plan 3b). No live artifact is wrong |
| 11 | S3-M3-Register-keydesign.md:411; S3-M3-Resolver-report.md:123 | no logging contract for library-style tools | **new #148** | logging.md sections 1-6, aitools-profile.sh:71-79, :770-781 |
| 12 | S3-M3-Resolver-Review-pr86-batch2.md:166; S3-M3-Resolver-report.md:125 | setup-user-config turns every resolver warning into a WARN row | merged into #148 | Code fixed in PR #86 batch 4: setup-user-config.sh derive_warn (:165 onward) separates handled, advisory and real warnings. The contract part is #148 |
| 13 | S3-M3-Register-keydesign.md:413 | R18 draft describes hashed machine ids | dropped | Draft errata. `grep -i hash reference/user-repo.md` finds nothing; the claim exists only in the draft |
| 14 | S3-M3-Register-keydesign.md:415 | alias lookups fall back to the first profile (setup-user-claude, build-deploy) | filed + fixed (code) | #76. `Object.values(p.profiles)[0]` is gone from setup-user-claude.sh/.ps1, build-deploy.sh and profile-check.js (grep). The doc half is still open (row 7) |
| 15 | S3-M3-Register-keydesign.md:269 (Review3) | Path 1 claude/CLAUDE.md scaffold commit has no identity fallback, uses `\|\| true` | fixed | scripts/aitools ui_scaffold_claude_md (:878-895) commits through ui_commit (:323-345). ui_commit falls back to profile.json identity.git and logs failures as log_warn + ACTION; it has no `\|\| true` |
| 16 | S3-M3-LibFix-report.md:129 (Review3, PR #80) | no rule on lib result-global naming / dot-sourced scope | **new #149** | aitools-lib.sh:125-134 (contract exists only as a code comment); not in any spec (grep) |
| 17 | S3-M3-LibKey-report.md:95 | no rule on a lib function name that a caller also defines | merged into #149 | aitools-install.sh:153 relay_child_log and aitools-install.ps1:65 Write-JsonlRecord shadow aitools-lib.sh:569 and aitools-lib.ps1:449 |
| 18 | S3-M3-LibFix-report.md:130; S3-M3-JsonRename-report.md:67 | pre-commit step 20 fails: tree and gen-tool-specs.py missing | fixed | reference/tool-support-decision-tree.md landed in PR #78. gen-tool-specs.py is allowlisted as planned in scripts/check-path-refs-allow.txt:25 and :28 |
| 19 | S3-M3-JsonRename-report.md:69 (PR #86 review) | JSON engines write numbers differently (0.10 vs 0.1) | **new #150** | aitools-json.pl:68-70, aitools-json.ps1:66-69 |
| 20 | S3-M3-Resolver-Review-pr86-batch2.md:165; S3-M3-Resolver-report.md:124 | no rule that each pushed batch keeps CI green | **new #151** | b70fc64. grep of .claude, reference and shared finds no such rule |
| 21 | S3-M3-UserInit-report.md:96 (PR #86) | lib runner treats register/migrate exit 0 as a crash | **new #152** | aitools-lib.sh:154-159, :216-225. The resolver has no `put via` in cmd_register (:1219) or cmd_migrate (:1443). scripts/aitools:196-201 has its own runner |
| 22 | S3-M3-LibFix-Review-pr80.md:199 | no rule that a wrapper validates child output before trusting its exit code | merged into #152 | Same mechanism: the rule exists only in the lib comment |
| 23 | S3-M3-UserInit-report.md:97 | entry points called removed helper names; no test ran user init | fixed | tests/profile/test-user-init.sh exists. The entry points use ui_profile_run and the AITLIB names |
| 24 | S3-M3-UserInit-report.md:98; S3-M3-UserInit-Review-pr86-batch5.md:125 | isolated-HOME rule does not cover the cwd | **new #153** | /delegate grep: no cwd or working-directory instruction (:184, :212-213 cover HOME only) |
| 25 | S3-M3-UserInit-report.md:99; S3-M3-UserInit-Review-pr86-batch5.md:126 | no rule about success-stream output in a PS function that returns an exit code | **new #154** | cross-platform-detail.md headings: no such gotcha |
| 26 | S3-M3-Resolver-report.md:126 | PowerShell variable names ignore case | merged into #154 | Same file, same fix |
| 27 | S3-M3-UserInit-report.md:100 | .ps1 checked out CRLF; line-anchored test patterns miss it | merged into #154 | .gitattributes:2; test-user-init.sh:328-329 works around it |
| 28 | S3-M3-Docs-approval-page.md:78 | user init's ui_commit commits profile.json without a dirty check | fixed | ui_register_flow refuses to write over uncommitted edits (scripts/aitools:657-664, ui_profile_dirty :347-357). v1 migration: :746 |
| 29 | S3-M3-Docs-approval-page.md:83 | ConfigKey and Resolver reports disagree on the #86 merge condition | dropped | Mission coordination question. #86 merged; there is no harness artifact to fix |
| 30 | S3-M3-Docs-approval-page.md:94 | scaffolded profile.json has no meta.intent | **new #155** | aitools-profile.sh:1242, .ps1:1085 |
| 31 | S3-M3-Docs-approval-page.md:95; S3-M3-Docs-Check-findings.md:153 | v1 to v2 migration writes config.json with node and keys by alias | fixed | migrate_profile_v1_to_v2 (scripts/aitools:729-780) says "config.json is not written here (setup-user-config is its only writer)" and registers this machine under its id. Node is still used for the v1 transform; that is outside the marker |
| 32 | S3-M3-Docs-approval-page.md:99; S3-M3-Docs-Check-findings.md:157 | stale comments say the entry points export AITOOLS_USER_REPO_PATH | fixed | They do now: scripts/aitools:2049-2053 and aitools.ps1:1999-2007 export it for the build-deploy call, so build-deploy.sh:179 and aitools-profile.sh:17 are accurate |
| 33 | S3-M3-Docs-approval-page.md:103; S3-M3-Docs-Check-findings.md:160 | dirty profile.json + exception-set: wrappers advise "git push" | **new #156** | aitools-lib.sh:439-447, .ps1:371-376, aitools-profile.sh:960-970. The exit-3 header half was not verified and is left out |
| 34 | S3-M3-Docs-approval-page.md:107; S3-M3-Docs-Check-findings.md:165 | `user init --alias <new>` without a terminal fails on an existing profile.json | fixed | Batch 5 (PR #86): scripts/aitools:470-509 and aitools.ps1:1101 (`--allow-duplicate-alias` after confirm), per decision 1 in the PR #86 body |
| 35 | S3-M3-Install-report.md:158; S3-M3-LibKey-report.md:94 | JSONL override pattern unescaped (installer fixed; doc still shows it) | **new #157** | script-standards-detail.md:125-131; the installer is fixed at aitools-install.sh:143 (69b6420) |
| 36 | S3-Profile-Review2-pr76-77.md:93; PR #76 review | tree section 8 allows via=alias unconditionally | fixed | tree :619-628 and :738 allow `alias` only when the machine has no id |
| 37 | S3-Profile-Review2-pr76-77.md:94; PR #77 review | cross-platform.md does not cover the .pl + .ps1 pair | **new #158** | cross-platform.md "OS guard exemptions" / "Platform targeting principle"; scripts/aitools-json.pl/.ps1 |
| 38 | S3-Profile-Review2-pr76-77.md:95; PR #77 review | user-repo.md "Config Schema (v3)" draft describes a no-node fallback | dropped | Draft errata. The live reference/user-repo.md has no "node" text (grep) |
| 39 | S3-Profile-Review-pr73.md:96; PR #73 review | logging_init prints a console warn before a script can redirect | **new #159** | aitools-lib.sh:658-691. aitools-profile.sh:71-79 works around it |
| 40 | S3-M3-LibFix-Review-pr80.md:189 | cross-platform.md rules conflict for lib to .ps1 bridge | **new #160** | aitools-lib.sh:159-199; cross-platform.md :124-128 and the dispatch rule |
| 41 | S3-M3-LibFix-Review-pr80.md:194 | tree rev 5 contradicts itself on tool_exception_get output / stale globals | **new #161** | tree :300-310, :399, :564-567; also the re-key drift (profiles.<alias>) found while verifying |
| 42 | S3-M3-B8b-report.md:98; S3-M3-LibKey-Review-pr86-batch3.md:122 | "INCIDENT: none" | n/a | |
| 43 | S3-MF-Audit-findings.md §8 I-1 (PR #104) | logging.md does not define deploy.jsonl; only the installers write it | **new #162** | logging.md :66, :101 (checks.jsonl only); writers only in aitools-install.sh:124, :143 and aitools-install.ps1:65; the lib's jsonl_record has no caller |
| 44 | S3-MF-Audit-findings.md §8 I-2 | ACTION + same-text log_warn rule conflicts with write_summary auto-promote and D-TS12 | merged into #147 | Same root, as the audit itself says. #147 is rewritten: title, D-TS12 expected (tree :64), options A/B/C; severity raised to medium. aitools-lib.sh:288-294, :322-332 |
| 45 | S3-MF-Audit-findings.md §8 I-3 | no script-standards exemption category for a library-style tool | merged into #148 | #148 already named the exemptions table. It now adds the resolver header contract (aitools-profile.sh:39-43), the 'Exemptions table' (:1156), and the four bash stderr-only exits (:167, :181, :194, :207) |
| 46 | S3-MF-Audit-findings.md §8 I-4 | no spec on re-counting an error the lib wrapper already logged; B8 consumers differ | **new #163** | setup-user-settings.sh:80-83, setup-user-skills.sh:110-114, setup-user-cursor.sh:94-99 |

**Counts:** 42 rows. Rows 1-41 are markers; several cite the same marker in two files. Row 42 is two "INCIDENT: none" lines. Across rows 1-41: 16 new + 5 merged + 3 filed + 12 fixed + 5 dropped = 41. Rows 1 and 14 are counted once, as filed.
- 16 new (#146-#161).
- 5 merged into new entries (rows 12, 17, 22, 26, 27).
- 2 already filed (#76: rows 7 and 14; #98: row 1). Rows 1 and 14 are also fixed in code.
- 12 fixed, not filed (rows 2, 4, 5, 6, 15, 18, 23, 28, 31, 32, 34, 36; row 6 only for the code).
- 5 dropped (rows 8, 10, 13, 29, 38).
- 0 routed to /glossary: no marker is terminological.

## Batch table

| Id | Title (short) | Sev | Source rows |
|---|---|---|---|
| 146 | pre-commit step 13 + deploy-paths.md still list claude/cursor as duplicated | low | 3 |
| 147 | write_summary OK to WARN promotion undocumented | low | 9 |
| 148 | no logging contract for library-style tools | medium | 11, 12 |
| 149 | lib naming/scope contract only in a code comment; installers shadow lib functions | low | 16, 17 |
| 150 | JSON engines write numbers differently | low | 19 |
| 151 | no rule that each pushed stacked batch keeps CI green | low | 20 |
| 152 | lib runner rejects register/migrate; validation rule undocumented | low | 21, 22 |
| 153 | isolated-HOME rule does not cover the cwd | medium | 24 |
| 154 | cross-platform-detail omits 3 PS/CRLF traps | low | 25, 26, 27 |
| 155 | scaffolded profile.json has no meta.intent | low | 30 |
| 156 | dirty profile.json + exception-set: wrong "git push" ACTION | low | 33 |
| 157 | script-standards-detail JSONL override pattern unescaped | medium | 35 |
| 158 | cross-platform.md does not cover aitools-json.pl/.ps1 | low | 37 |
| 159 | logging_init console warn on stdout | low | 39 |
| 160 | lib to .ps1 bridge: cross-language rule ambiguity | low | 40 |
| 161 | decision tree documents pre-M3 interfaces | medium | 41 |
| 162 | logging.md does not define deploy.jsonl | medium | 43 |
| 163 | no spec on re-counting a lib-logged error; B8 consumers differ | low | 46 |

Rows 43-46 were added on 2026-10-22, at S3-M3Finish's request, from the S3-MF-Audit markers. #147 (medium) and #148 now also carry I-2 and I-3. Batch totals: 18 entries, #146-#163, with 9 medium and 9 low.

Severity: 0 high, 7 medium, 9 low. Review finding m2 raised #146, #150 and #156 from low to medium; the table rows above still show their filing severity. `referenceFile` is null on all 16: none went through the full discovery cycle. `linked` is null on all 16: no approved tracker exists (drafts are named in suggestedResolution).

## Close candidates for existing incidents (not changed here)

These were found while verifying. They are not part of this batch, because closing an incident is a separate protected write.
- **#98:** inliners anchored in c421511 (PR #95).
- **#95:** build-deploy hardcoded defaults removed in PR #95.
- **#109:** `eval "$PROFILE_VALS"` removed in PR #95.
- **#86:** build goes to a staging dir in PR #95 (review m1).
- **#76:** code half fixed (#83, #95); docs half still open.
- **#33:** deploy-template drift. The reviewer suggested it; I did not verify it here.
- **#149 / #9:** #149 now names #9, which already covers entry-point overrides (review M1).

PR #95 and S3-M3-B5a-report.md claim each of these. I verified only #98 and #76 (code) against the code.
