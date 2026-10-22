# S3-GateFix rev 5 changelog: tool support decision tree and sibling drafts

**Intent**: **Purpose**: Map every change from decision tree rev 4 to rev 5, and every change to the sibling drafts S3-GateFix revised, to the finding it fixes, so the commander can approve rev 5 by checking each change against its reason. **Scope**: `S3-GateFix-drafts/reference/tool-support-decision-tree.md` against S3-Gate rev 4; the revised `script-standards-detail.md.edit.txt`, `shared/skills/tool-adopt/SKILL.md`, the renderer and the review page. NOT findings left open (review page items E-rev4-minors, E-rev5-minors). **Audience**: The commander at the gate; the reviewer of the S3-GateFix PR.

Finding ids: **R1-R5** = the five PR #58 review findings in the GATE-FIX brief (R1 runner coverage, R2 edit 6 wording, R3 generator wording, R4 renderer, R5 independent B-pass). **GB-nn / O-n** = `S3-GateFix-B-review.md`. Rev 4: `../S3-Gate/S3-Gate-drafts/reference/tool-support-decision-tree.md`. Full diff: `S3-GateFix-drafts/reference/tool-support-decision-tree.md.rev4-to-rev5.diff`. The intent statement is unchanged from rev 3.

## Decision tree, rev 4 to rev 5

| # | Section | Change | Finding |
|---|---|---|---|
| 1 | Banner | Revision 5 line | -- |
| 2 | §1 term "abort marker" | User abort needs an exported marker path and a non-empty marker | R1 |
| 3 | §1 new term "runner" | The four runner loops; §7.5 also binds `user init` and bootstrap | R1, GB-01, GB-03 |
| 4 | §1 D-TS13 row | "proposed / pending" → approved (commander, 2026-10-21); every runner exports and reads the marker | R1 (brief: D-TS13 approved) |
| 5 | §2 T2 rule | Windows: T2/T7/RP search the persistent Machine+User PATH (expanded), not the inherited process PATH; `Get-Command` first result | GB-04; S3-Gate-B B-10 |
| 6 | §2 RP rule | File identity (`-ef`; PS1 case-insensitive realpath compare) instead of string compare; PATHEXT and npm `.cmd` shims | GB-05, GB-14 (first half) |
| 7 | §3 ABORT row | Marker written only when `AITOOLS_ABORT_FILE` is set | R1 |
| 8 | §3 notes | Exit 2 from a script whose runner exported no marker = failure | R1 |
| 9 | §5 `path:` row | `/bin/realpath` when present (on-disk case), else perl `abs_path`; case-insensitive match on macOS/Windows | GB-05 |
| 10 | §5 Rules | Case-insensitive "inside" on macOS/Windows; lowercase with `perl -CSD`, not `tr` | GB-05, GB-06 (lowercasing half) |
| 11 | §7 intro | Only `tool_support_run` returns 2; bash logging helpers return results in named globals, never stdout; 3.2 rule covers every bash script; `tr` only for ASCII | GB-02, GB-11, O-1, GB-06 |
| 12 | §7.1 | One writer of `generated/tool-specs/` (the agent making an approved registry write); check 7 regenerates into a temp dir on every commit and never writes `generated/` | R3 |
| 13 | §7.1 spec header example | Drops "embedded by build-deploy.sh"; MDM embedding deferred (§7.5) | R3 |
| 14 | §7.2 preamble | "Prints" = bash global / PS1 return value for logging helpers | GB-02 |
| 15 | §7.5 | Rewritten: who writes the marker (library, only when set; SOURCE-TRUTH implements it); every launch site (installers, `deploy_configs` / `Deploy-Configs`, `aitools user init`, bootstrap); first launch site creates, only the creator deletes (trap/finally; re-exec safe); `cygpath -m` at creation; `GetTempFileName` fallback; guarded truncation; read with `[ -s ]`; entry point decides abort from the marker, never from `deploy_configs`' error count; "no marker exported" = failure; stale `$LASTEXITCODE` and explicit exit; `$script:DeployErrors`; relay `[q]` outside the contract | R1, GB-01, GB-03, GB-07, GB-08, GB-09, GB-10, GB-15, O-1 |
| 16 | §9 check 7 | Temp-dir regeneration, never writes `generated/` | R3 |
| 17 | §9 new check 12 | Every setup script ends with an explicit `exit` | GB-10 |
| 18 | §10 | New rows: sync-path managed-file `x`; sync-path exit 2 without marker; two failures not read as abort; install-path managed-file `x`; script run by hand; `user init` `x`; bootstrap `x`; entry-point re-exec; bash helper result in a global; RP case spelling; Windows bash runner with pwsh child | R1, GB-01, GB-02, GB-03, GB-05, GB-07, GB-08 |

Check: every R1-R3 finding and every GB major (GB-01..GB-05) maps to at least one row: R1 (2-4, 7, 8, 15, 18), R3 (12, 13, 16), GB-01 (3, 15, 18), GB-02 (11, 14, 18), GB-03 (3, 15, 18), GB-04 (5), GB-05 (6, 9, 10, 18). Not applied: GB-06 (match by identity in aitools-profile.js), GB-12, GB-13, GB-14 second half, O-2, O-3 (review page E-rev5-minors). GB-16 (header credited a review that did not yet exist) is moot now that the review exists.

## Other drafts

| File | Change | Finding |
|---|---|---|
| `S3-GateFix-drafts/reference/script-standards-detail.md.edit.txt` | Edit 6: "never exits 2 on purpose for any other reason; an unintended exit 2 without the marker is treated as a failure"; "the only exit that skips the footer" (false: the OS guard and a missing spec also exit before it) → "Like the OS guard and a missing tool spec (exit 1), it leaves before the footer; it is the only deliberate exit 2"; covers managed-file menus too; header notes D-TS13 approved. Edits 1-5 unchanged | R2 |
| `S3-GateFix-drafts/shared/skills/tool-adopt/SKILL.md` | Moved to user level; new "Where this runs" (aitools repo; RFC-0001 issue on `nobul-tech/aitools` from other repos); "Today and after M2" table with a switch-on condition; registry only via `/tool-registry`; managed-file wording per the approved model (`[a]ccept & adopt`, `[m]erge & adopt`); aitools-relative paths instead of `@` links; step numbers kept (tool-registry cites step 5, tool-eval returns to step 2); isolated HOME for build-deploy; revised intent (review page TA-INTENT) | brief "TOOL-ADOPT approval", managed-file model check |
| `/tool-eval`, `/tool-registry` drafts | Checked against the approved managed-file model: neither describes adopt or merge, step references still valid. Not copied or changed | brief "Context items" |
| `S3-GateFix-render-review-page.py` | Every summary line derived from the JSON (section counts, open/approved/superseded, row states and authors, new/changed ids, `meta.answerOrder`); explicit row fields `state`, `draftedBy`, `draftStatus`, `draft`; item kinds question/context/row; `status` + `statusNote`; `--help` and `--check`; exits 1 on any validation error and writes nothing | R4 |
| `S3-GateFix-review-page.json` / `.md` | New sections ta (TOOL-ADOPT approval) and k (context: SD-1..8, D-TS13, managed-file model); REV5; D-TS13 approved; REV4 superseded; rows R1, R4, R7, R16 updated; T-Q1, S2L-Q1, E-S4-7, E-rev4-minors, E-independence updated; new known defects E-rev5-minors, E-node-corrupt, E-merge-revert, E-mdc-model, E-relay-exit2. All 84 S3-Gate items kept | brief "New review-page content", R5 |

## Render command (recorded with both arguments)

From the worktree root:

```
python3 -I .aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-GateFix/S3-GateFix-render-review-page.py .aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-GateFix/S3-GateFix-review-page.json .aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-GateFix/S3-GateFix-review-page.md
```

Output: `ok: 98 items; ta=5, k=3, a=26, b=26, c=7, d=18, e=13`.
