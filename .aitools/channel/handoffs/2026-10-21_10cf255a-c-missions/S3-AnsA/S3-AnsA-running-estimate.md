# S3-AnsA running estimate (final, 2026-10-26)

Fact base: origin/main 5976553. PR #99 is OPEN at head df10361. Full detail and the text to apply are in S3-AnsA-report.md.

| Q | Status | Answer | Confidence | Key provenance |
|---|---|---|---|---|
| Q1 staleness note | answered | Apply the corrected text from the report. The held proposal was reworded after the critic's review: "sources", no "yet", the dotprofile caveat, and `.claude/hooks` | high (facts); wording new | 2026-10-23T02:01:33Z uuid 0527e51d; check-pre-push.sh:123 / .ps1:126 |
| Q1b `.claude/hooks` | answered | Yes; do not break PR #111 Edit 3's anchor | high | commander 2026-10-22T00:04:12Z uuid 65461507; deploy-harness.sh:257 / .ps1:241 |
| Q1c fix step 7 | open | No commander decision; the gap is unfiled. Suggest: widen the trigger, WARN on stale deploy-harness.*, and file the incident | n/a | H-MDM Q3 (agent); registry grep |
| Q2 fan-out paragraph | answered | Apply the corrected text. If PR #110 merges first, say "User-level rules reach Cursor" | high | commander 2026-10-22T01:12:49Z uuid fc194c92; 2026-10-23T01:58:29Z uuid e073aea3; setup-user-cursor.sh:389 |
| Q2-extra | open | Same false claim at .claude/rules/managed-file-deployment.md:48, reference/harness.md:154-155, aitools-workspace.md:52. Suggest: correct them in the same batch | - | git grep origin/main |
| Q3 user-rules.md:28 | answered | Yes, `%USERPROFILE%\repos\` | high | 2026-10-22T22:09:16Z "everywhere"; commander 2026-10-23T01:58:29Z "4) approved" |
| Q4 .mdc twin | answered | Approved as derived, at df10361 only | high | commander 2026-10-26T21:58:13Z uuid cb1f0201 "1d) approved" |
| Parity ambiguity | open | Suggest: keep the existing twins and file an incident to reconcile 03933a5 with cursor-rule-parity.mdc | - | RELEASE_NOTES.md:1087 |
