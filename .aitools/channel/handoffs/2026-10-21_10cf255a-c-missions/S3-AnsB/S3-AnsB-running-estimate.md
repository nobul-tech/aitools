# S3-AnsB running estimate

**Intent**: **Purpose**: Track every ANSWER-1B question with its status, best answer, confidence and provenance while delegates report. **Scope**: edits A-J (user-repo.md), the glossary "profile" edit, M3Lead decision 2, and questions found on the way. NOT the final report (S3-AnsB-report.md). **Audience**: S3-AnsB, Session Commander 10cf255a-c.

Rev 4 (final), 2026-10-26: all readers and the critic have reported. The critic refuted none; it weakened H (the directory move is noted) and J (text fixed). Every row is final. Open for the commander: report questions 1 (C) and 2 (H). origin/main is 480b901. Full provenance is in S3-AnsB-report.md.

| Q | Status | Best answer | Conf. | Key provenance |
|---|---|---|---|---|
| A | answered | apply, plus a missing-dir sentence | high | scripts/aitools:2032-2055; build-deploy.sh:214-216 |
| B | answered | apply with the build-deploy precision | high | aitools-profile.sh:429-433 |
| C | answered, needs commander (Q1) | Code claims an unowned profile without asking (scripts/aitools:490-497). No commander decision. Contradicts approved row 3 (#101 user-repo.md:269-271) and his 01:58:29Z answer. Do not apply C; suggest fixing the code. | high (facts) | bb43536; 10cf255a 2026-10-23T02:01:33Z, 01:58:29Z |
| D | answered | apply with precision | high | scripts/aitools:402-406 |
| E | answered | apply as drafted | high | scripts/aitools:550-552, :819-871 |
| F | answered | apply, adding the `owner unknown` line | high | scripts/aitools:422-423 |
| G | answered | apply, adding the environment case and the v1 skip | high | scripts/aitools:657-669, :746-750 |
| H | answered, plus Q2 | apply the exception text and file a fix. "only one" = N-Q6 (install methods); the single-writer rule = SD-7 + decision 7 | high | scripts/aitools:1445-1469; PR #67/9bbe9a4; 360aa8f3 handoff :98 |
| I | answered | apply the main-version text; re-check after #106 | high | deploy-harness.sh:99-115; PR #106 diff |
| J | answered | apply with the broader no-op condition | high | aitools-profile.sh:1476-1481 |
| glossary | answered | apply, with the environment:<name> qualifier | high | aitools-profile.sh:25-30; decision 5 |
| Decision 2 | answered | commander: keep asking / ERROR (2026-10-23T01:58:29Z "1) yes"); not recorded in any file | high | 10cf255a uuid e073aea3 |
| NEW-1 | answered | landed claim bullet and resolver comments false against the code; resolved with C | high | aitools-profile.sh:111-112, :1299; .ps1:1134 |
| NEW-2 | answered | #106 makes the landed "Callers" sentence false | high | PR #106 diff |
