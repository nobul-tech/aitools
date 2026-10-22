# S3-SpecRewrite consistency check

Sources compared:
- **AS** = approved `.claude/rules/agentic-standards.md` "Managed-file review choices and merge" (branch docs/managed-file-choices, mfchoices worktree, lines 47-109)
- **SM** = approved State Machine, `reference/managed-file-deployment.md` (mfchoices, lines 21-45); copied byte-for-byte into the draft (`check-sm.sh`: `cmp` identical, 26 lines)
- **C** = interface contract in the mission prompt (identical in S3-SourceTruth's prompt)
- **REF** = draft `S3-SpecRewrite-drafts/reference/managed-file-deployment.md`
- **MFD** = draft `dot-claude/rules/managed-file-deployment.md` (+ `.mdc` mirror, same wording)
- **IM** = draft `dot-claude/rules/interactive-menus.md` (+ `.mdc` mirror, condensed)

Status: **agree**, or **open** (the drafts agree with each other, but a source is silent or defective; see the Q number in S3-SpecRewrite-report.md).

| # | Topic | AS | SM | C | REF | MFD / IM | Status |
|---|-------|----|----|---|-----|----------|--------|
| 1 | Source of truth | SOURCE is the source of truth | same | -- | Overview: same | MFD table: same | agree |
| 2 | Ancestor / deploy state | none; only SOURCE vs LOCAL | none | deploy state removed | "Deploy State: Removed 2026-10-21"; Functions: removed helpers listed | MFD: "no ancestor and no deploy state" | agree |
| 3 | LOCAL == SOURCE | verified, nothing written | "verified" | verified | Return Values: verified, nothing written | IM list incl. verified | agree |
| 4 | LOCAL missing | -- (silent) | write SOURCE, "created" | created | created, LOCAL written | IM list | agree |
| 5 | Non-interactive (no terminal, EOF, --force) | SOURCE written; no merge | write SOURCE (backup), "updated" | non-interactive, EOF, AITOOLS_FORCE -> overwrite | Non-Interactive section: overwrite, updated, no AI merge, EOF warns | IM: all menu functions, overwrite, no AI merge | agree |
| 6 | Menu options and order | overwrite / accept & adopt / merge & adopt / skip / abort | [o] [a] [m] [s] [x] | [o]/[a]/[m]/[s]/[x] | Menus: `choice [o/a/m/s/x]` | IM Pattern: same order | agree |
| 7 | [a]/[m] without adopt target | not offered | -- | only when ADOPT_OFFERED=1 | `choice [o/s/x]` | IM: only with adopt target | agree |
| 8 | Overwrite | SOURCE written; repo unchanged | write SOURCE (backup), "updated" | overwrite | updated, LOCAL written | -- | agree |
| 9 | Accept & adopt | LOCAL kept; copied to repo immediately | keep LOCAL + copy to repo now, "accept & adopt" | adopt -> accept & adopt | LOCAL not written, adopt target written | MFD: library writes adopt target | agree |
| 10 | Merge & adopt | text only; merge written; copied to repo immediately | AI merge (text only), write LOCAL + repo, "accept & adopt" | merge + MERGED_CONTENT | AI Merge Detail step 5: both written, accept & adopt; "Merge is adopt" | IM: JSON has no [m] | agree |
| 11 | Skip | nothing; reviewed again next run | nothing written, "skipped" | skip -> skipped | skipped, asked again next run; tracker WARN | IM list | agree |
| 12 | Abort | logs error, exits 2 | log error, exit 2 | exit 2; marker appended first when AITOOLS_ABORT_FILE set (D-TS13) | [x]abort section: marker then exit 2 | IM Abort section | agree |
| 13 | Who writes the repo | library, given adopt target path; callers do not copy back | "copy to repo now" | ADOPT_PATH; adopt_managed_file internal | Caller Responsibilities: callers never copy back | MFD "Adopt target" para | agree; see Q1 (CLAUDE.md transform), Q2 (hooks reverse discovery) |
| 14 | Adopt into protected file | allowed; working tree only; WARN naming file | -- | -- | Markdown files: same | -- | agree |
| 15 | Failure handling | backup all files written; validate; on failure restore, log reason, ERROR, continue | restore backups, log, ERROR row, continue | failed = backups restored, log_error; caller records; tracker ERROR | Return Values `failed`; Backup Policy "Restore on failure" | MFD #1, #4; IM return-value contract | agree; REF adds "a file that did not exist before is removed" (Q6) |
| 16 | AI merge failure | -> restore, log, ERROR, continue | covered by "merge failure" | no failed value for prompt_diff_review | step 6: outcome `failed` | -- | open (Q3: how prompt_diff_review signals it) |
| 17 | Merge preview rejected [n]o | -- (silent) | -- | -- | step 7: no file written; Q4 | -- | open (Q4) |
| 18 | JSON: per-field review | SOURCE owns every field; key path; whole array = one field | same choices per differing field, no [m] | review_json_fields; SOURCE owns every field | Regime 1 | IM "SOURCE owns every field" | agree |
| 19 | JSON: LOCAL-only field | kept in LOCAL; never written to SOURCE without review | -- | never written to SOURCE without a prompt | Regime 1 + Non-Interactive: stays in LOCAL | IM: same | agree (menu for such a field: Q7) |
| 20 | JSON: key order | preserved | -- | preserved | preserved | IM: preserved | agree |
| 21 | JSON: validation | parses, required keys present | -- | both files validated | parse, required keys | -- | open (Q8: contract has no required-keys input) |
| 22 | JSON file-level result | -- | -- | one MANAGED_FILE_RESULT | proposed precedence | -- | open (Q5) |
| 23 | Profile mirror regime | sync_managed_json (settings.json, **cli-config.json**) keep profile-mirror; live-only leaf auto-adopts | -- | -- | Regime 2: settings.json only; cli-config.json listed as script-owned | IM: settings.json; MFD table unchanged | **disagrees with AS on cli-config.json**: code (`scripts/setup-user-cursor.sh:166-292`) merges cli-config.json with its own node block, no review, no adopt. Drafts follow the code. Q9 |
| 24 | Live-only leaf direction (regime 2) | live-only -> profile.json | -- | -- | same | IM: fixed (main said "source has a value the live file lacks ... auto-adopted into the source", backwards vs `aitools-lib.sh` buildPlan `lHas && !mHas -> autoAdopts`) | agree |
| 25 | AI merge parameters | balanced, none, at most 1 retry, preview before write | -- | -- | same | -- | agree |
| 26 | Tracker | -- | ERROR row | failed outcome, DETAIL "failed: <item>", summary ERROR | Functions table + Return Values | MFD #4 | agree |
| 27 | Hooks adopt target | -- | -- | -- | shared/hooks path, written by library; "" when shared/hooks absent | -- | agree with SD-2 / incident #80 |
| 28 | SM intro sentence | -- | "code implements it in mission HARNESS batch B1; until then the Menus, Return Values and Deploy State sections below describe the code as it is today" | -- | sections below now describe the target | -- | **stale once drafts apply**; SM kept verbatim per orders; replacement proposed (Q10) |

| 29 | Abort scope (review A2) | exits 2 | exit 2 | exit 2 + marker | ends this setup script; installer continues | IM/CIM: same (was "global (stops the run)" from main) | agree after fix |
| 30 | Commit/push of an adopt (review A5) | working tree only; review gate at commit and PR | -- | -- | no commit, no push | MFD/CMFD: same | agree after fix (code to change: `setup-user-claude.sh:335-356`) |
| 31 | Hooks reverse discovery (review A4) | -- | -- | adopt_managed_file internal | documented as outside the model, Q2 | -- | open (Q2) |
| 32 | CLAUDE.md template adopt (review B3) | callers do not copy back | -- | ADOPT_PATH plain copy | exception noted, Q1 | MFD/CMFD exception line | open (Q1) |
| 33 | LOCAL-only JSON field review (review B4) | "never written to SOURCE without a review" | -- | "without a prompt" | no review defined | IM: approved wording | open (Q7) |
| 34 | Backup failure (review B7) | never half-written | -- | -- | non-fatal (unchanged) | -- | open (Q13) |

Reviewer: S3-SpecRewrite-Check (independent delegate) -- results in `S3-SpecRewrite-Check-findings.md`.
