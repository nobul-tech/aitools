# S3-Gate rev 4 changelog: tool support decision tree

**Intent**: **Purpose**: Map every change between decision tree rev 3 and rev 4 to the review finding it fixes, so the commander can approve rev 4 by checking each change against its reason. **Scope**: Changes in `S3-Gate-drafts/reference/tool-support-decision-tree.md` against the S4-Review rev 3 copy; blocker and major findings only. NOT the minor findings (left open, listed at the end). NOT the sibling drafts. **Audience**: The commander at the gate, and the reviewer of the S3-Gate PR.

Rev 3: `/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_360aa8f3-8-missions/S4-Review/S4-Review-drafts/reference/tool-support-decision-tree.md`. Rev 4: `S3-Gate-drafts/reference/tool-support-decision-tree.md`. Full diff: `S3-Gate-drafts/reference/tool-support-decision-tree.md.rev3-to-rev4.diff` (127 insertions, 44 deletions). The intent statement is unchanged, so this rev needs no new intent approval.

| # | Section | Change | Finding |
|---|---|---|---|
| 1 | Banner | Adds the revision 4 line | -- |
| 2 | §1 terms | New term "abort marker" | S3-Gate-B B-01 |
| 3 | §1 decisions | New proposed decision D-TS13: exit 2 is a user abort only with the marker; every `[x]abort` writes it (pending commander) | B-01 |
| 4 | §2 mermaid | Menu `[r]`/`[i]` now go through a new node RQ ("P checks for the preferred method"); RQ no → REPLACE-FAIL | S3-Gate-A A-01 |
| 5 | §2 mermaid | RP label becomes "preferred copy reachable on PATH and a different file" | A-04 |
| 6 | §2 "Dry run" | After a replaced acting node the tree stops: T7 is not run, and the result is OK `dry-run: would <verb>`, exit 0. Paths without an acting node report their own leaf | A-02 |
| 7 | §2 node rule T2 | `resolveBy: knownPaths` resolves from verified known paths instead of PATH; cites cross-platform.md "Windows: managed bash" | B-03 |
| 8 | §2 node rule P | The same checks run before R1 (RQ) and before a source-build T4 update; the failure outcomes are defined | A-01 |
| 9 | §2 node rule T4 | Source-build kinds pass P first | A-01 |
| 10 | §2 node rule R1 | Runs only after RQ; prints the preferred binary path | A-01, A-04 |
| 11 | §2 node rule RP | Rewritten: a PATH directory holds `<cmd>` whose realpath equals the realpath of the path R1 printed, and differs from the old copy's realpath. A linked brew formula passes; a keg-only off-PATH formula fails | A-04 |
| 12 | §2 node rule T7 | `resolveBy: knownPaths` → T2 resolution rule; SHADOWED does not apply | B-03 |
| 13 | §3 ABORT row | The menu helper writes the abort marker | B-01 |
| 14 | §3 REPLACE-FAIL row | RQ variant: log line, WARN `<ver> (prereq missing)` (24 chars with a 7-char version), PREREQ ACTION | A-01 |
| 15 | §3 notes | Exit 2 with the marker = user abort; without it = ordinary failure | B-01 |
| 16 | §5 `path:` probe, PowerShell | `Resolve-ToolRealPath` walks every component (links and junctions); notes that `ResolveLinkTarget` alone resolves only the last component | B-04 |
| 17 | §5 `brew-formula:` probe | Compares against the realpath of `brew --prefix <name>` (the opt symlink resolves to the Cellar keg) | A-03 |
| 18 | §5 rules | New first rule: "inside" and "under" compare at a path-component boundary | A-03 (probe correctness; also covers B-08's boundary point for probes) |
| 19 | §6 | New field `resolveBy` (`path` default, `knownPaths`; may be per platform) | B-03 |
| 20 | §7 intro | bash 3.2 rule adds the empty-array idiom, the lowercase ban, `printf -v` allowed; "no helper uses return code 2"; PowerShell helpers keep the output stream clean | B-02, B-01, B-05 |
| 21 | §7.1 | The generator runs only after an approved registry write and in check 7. build-deploy, installers and setup scripts never run it. Spec example gains `TOOL_RESOLVE_BY` | B-06, B-03 |
| 22 | §7.2 `tool_spec_load` | `bash -n` / PS parser before sourcing; `Import-ToolSpec` returns `[bool]` only | B-01, B-05 |
| 23 | §7.2 `tool_detect_method` | Internal error rc 2 → 3 | B-01 |
| 24 | §7.2 new row | `tool_realpath` / `Resolve-ToolRealPath` | B-04 |
| 25 | §7.2 `tool_install`, `tool_update` | Print the preferred binary path (rule for brew linked vs keg-only) | A-04 |
| 26 | §7.2 `tool_remove`, §7.3 | "refused" rc 2 → 4 | B-01 |
| 27 | §7.2 `tool_method_menu` | Writes the abort marker on `x` | B-01 |
| 28 | §7.2 `tool_support_run` | PS1 sets `$script:ToolSupportRc` and returns nothing | B-05 |
| 29 | §7.5 | Rewritten around the abort marker: who exports it, who writes it, how runners read exit 2, and the no-rc-2 rule for helpers; `AITOOLS_ABORT_FILE` added to the inherited variables | B-01 |
| 30 | §7.6 | Adds the PowerShell shape and the reason not to read the result from the pipeline | B-05 |
| 31 | §9 check 3 | Also fails for `resolveBy: knownPaths` without a verified known path | B-03 |
| 32 | §10 | New rows: linked formula class; `r` with manager absent; `r` with linked formula; dry run fresh; directory symlink/junction (PS1); `resolveBy` Windows bash; exit 2 without marker; malformed spec; bash 3.2 empty method list. Row "pty, x" now says the marker is written | A-01..A-04, B-01..B-04 |

## Findings not applied (minor; open for a later revision)

- S3-Gate-A: A-05 (two summary rows: rev 3 still claims `show_summary` merges them; the sentence was kept unchanged in rev 4, so the review page lists it as a known defect), A-06, A-07, A-08 and A-09 (covered by the row 16 draft), A-10, A-11, A-12, A-13, A-14, A-15, A-16.
- S3-Gate-B: B-07 (S4-9 APFS; the rev 3 wording "case-insensitive on macOS and Windows" is kept), B-08 (Windows guard roots; only the component-boundary half landed, for probes), B-09, B-10, B-11, B-12, B-13.

## Check

- Every major and the blocker in S3-Gate-A/B maps to at least one row above: A-01 (4, 8, 9, 10, 14, 32), A-02 (6, 32), A-03 (17, 18, 32), A-04 (5, 10, 11, 25, 32), B-01 (2, 3, 13, 15, 20, 22, 23, 26, 27, 29, 32), B-02 (20, 32), B-03 (7, 12, 19, 21, 31, 32), B-04 (16, 24, 32), B-05 (20, 22, 28, 30), B-06 (21).
- Summary detail lengths of the new texts: `<ver> (prereq missing)` = 23 with `1.26.1`, 24 with `24.13.1`; `dry-run: would install` = 22; `dry-run: would replace` = 22. All are at most 30.
