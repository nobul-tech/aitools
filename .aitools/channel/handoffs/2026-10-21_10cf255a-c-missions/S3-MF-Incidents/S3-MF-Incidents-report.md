# S3-MF-Incidents report (mission M3-FINISH item 9, orchestrator S3-M3Finish, Session Commander 10cf255a-c, 2026-10-22)

1. I triaged the 40 `INCIDENT:` markers in the M3 reports and reviews. 16 are new (#146-#161), 5 were merged into new entries, 2 were already filed (#76, #98), 12 are fixed since (verified on origin/main 8a9dcb5, not filed), 5 were dropped, and 0 went to /glossary.
2. `registries/incidents.json` is not modified. The 16 entries ship as a draft batch with an idempotent apply script, following the S3-Ledger (draft) then S3-Incidents (apply after approval) precedent.
3. Severity after review: 7 medium (#146, #148, #150, #153, #156, #157, #161), 9 low, 0 high.
4. PR https://github.com/nobul-tech/aitools/pull/102, branch `docs/mf-incidents`. The branch stays open so S3-M3Finish can append more markers.
5. Reviewer verdict (S3-MF-Incidents-Review, https://github.com/nobul-tech/aitools/pull/102#issuecomment-6355849066): changes needed (small), with 0 blockers, 1 major, 5 minors and 4 nits.
   - Fixed: M1 (#149 now names #9), m1 (#150 now cites the right PS1 functions), m2 (#146, #150 and #156 raised to medium), m3 (#155 expected now says "No spec exists for:"), m4 (row 6: the dotprofile repair is committed as 525ee49) and m5 (#33 added as a close candidate). n2 is done (affected lists extended) and n3 too (counts explained).
   - Not changed: n1 (only some discoveryContexts mention the registry audit; the triage doc records the full audit) and n4 (apply-script edge cases that do not affect this batch: a closed id makes the script exit with an error, which is safe, and the batch has no closed entries).
   - I verified m1 and m4 myself: aitools-json.ps1:35 and :171, and dotprofile `git log` 525ee49.

6. **S3-MF-Audit addendum (2026-10-22).** S3-M3Finish asked for the PR #104 markers I-1 to I-4 to be added as #162 onward.
   - I-1 is filed as #162 and I-4 as #163.
   - I-2 is merged into #147. The audit itself says it has the same root as the auto-promote finding. #147 is raised to medium and now lists options A/B/C.
   - I-3 is merged into #148, which already proposed the exemptions-table row.
   - Batch now: 18 entries, #146-#163, with 9 medium and 9 low. The apply step was re-tested 7/7: 156 incidents, 7 closed, ids 1-163.
   - Following S3-M3Finish's answers: the dotprofile-template repair is not filed, #98/#76 closure stays a listed follow-up, and markers from the non-M3 missions are out of scope.

## Files

All in `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-MF-Incidents/`:
- `S3-MF-Incidents-batch.json`: the 16 entries.
- `S3-MF-Incidents-apply.py`: the apply step.
- `S3-MF-Incidents-triage.md`: the 42-row triage table with evidence, the batch table, and close candidates.
- `S3-MF-Incidents-Review-pr102.md`: the reviewer's file.
- This report.

## How the protected file is handled

Draft plus apply step. S3-Ledger's PR #57 drafted entries only (S3-Ledger-review.md: "`registries/incidents.json` is **not modified**"). S3-Incidents' PR #65 wrote the registry only after "commander approval 2026-10-21, items a-c" (S3-Incidents-review.md, "What was applied"). No commander approval exists for this batch's content, so it is a draft.

To apply after approval:

`python3 -I .aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-MF-Incidents/S3-MF-Incidents-apply.py --registry registries/incidents.json --batch .aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-MF-Incidents/S3-MF-Incidents-batch.json --write`

## Verification

- **Registry:** read in full with offset/limit (3,453 lines). Max id 145, 145 unique ids, 7 closed.
- **Markers:** `grep -rn INCIDENT` over every M3 mission folder on origin/main, PR #97's S3-M3Lead-plan.md (none), and the bodies, comments and reviews of M3 PRs #73-#97 (`gh pr view --json`; these repeat the report markers).
- **Code checks:** each verdict was checked with reads and greps on 8a9dcb5. The scratch scripts are `.scratch/session-mfinc/verify1-4.sh` and their `.out` files. After the first draft, I re-checked every line citation against grep line numbers and corrected 13 of them.
- **Apply script:** `test-apply.sh` passes 7/7 (dry run, write to a copy, idempotent rerun, gap rejected, real registry untouched). The copy after apply has 154 incidents and 7 closed, with ids 1-161 unique and contiguous.
- **check-pre-commit:** 8 PASS, 10 SKIP, 2 WARN (9, 11), 1 FAIL (step 6, the known #133).
- **check-pre-push:** 6 PASS, 1 SKIP, 3 WARN, 0 FAIL.

## Not run

- Windows and PS1.
- Repros cited from reviewer reports (#150, #151, #153, #154).
- S3-Profile-Review3-pr79-80-82.md is in no branch, so markers that exist only there are unknown.

## WRITE_BLOCKED

None. Three Bash calls were blocked by standing-order-guard (`;` in a python one-liner, `head`, and a zsh glob in `--include=*.md`). I replaced them with scratch scripts and Read; none was a write.

## Observations during the mission

- **Dotprofile template:** `claude/CLAUDE.md:42-43` on the dotprofile's origin/main read `nobul-{{PROFILE_NAME}}/aitools`, which is the S3-M3-Claude adopt corruption. Another session repaired it during this mission and committed the fix as 525ee49. I did not touch it.
- **Close candidates:** #98 (verified) and the code half of #76 (verified). #95, #109 and #86 are claimed by PR #95 and were not verified by me.

## INCIDENT markers (not filed, outside this scope)

Non-M3 missions in the same folder carry unfiled markers that S3-Incidents/S3-Ledger did not file, because they are later than #145:
- S3-SourceTruth-report.md:51-53;
- S3-SourceTruth-Audit-findings.md:118;
- S3-ScratchRule-incidents.md;
- S3-HooksFix, S3-H-*, S3-DiffUX, S3-RegCC and S3-SpecRewrite, which I did not open.

Suggested: S3-M3Finish sends them to this branch if they are in M3-FINISH scope.

## Open questions (with suggested answers)

1. **Should the dotprofile template corruption (triage row 6) be filed as a closed operational incident for provenance?** The reviewer suggests yes. My suggestion: only if you want the root cause on record. The code is fixed (a87ffce) and the data is repaired (525ee49), and the launch prompt says fixed items are not filed.
2. **Close #98 and record the #76 code fix in the same approval?** Suggested: yes, as a separate protected write after this batch (closing procedure in /incident). I verified both.
3. **Is #161 (decision tree drift) urgent?** Suggested: raise it to high if M2 B2/B3 start before the tree is updated. It stays medium today because no M2 code consumes it yet.
