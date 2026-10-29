# S3-CursorVerify-Fix hand-back v1.0

Version 1.0, 2026-10-29, by S3-CursorVerify-Fix (delegated by S3-CursorVerify).

## Summary

1. The rules filter in deploy-harness.sh is now `*.[mM][dD]`, matching the .ps1's `-notlike '*.md'`, which was already case-insensitive.
2. The rules-name regex for the manifest accepts any case of the extension in all four places: `harness_manifest_plan` (deploy-harness.sh), `Get-HarnessManifestPlan` (deploy-harness.ps1), `read_harness_manifest` (aitools-lib.sh) and `Read-HarnessManifest` (aitools-lib.ps1).
3. On both paths, an `X.MD` rule is now deployed, listed in the manifest with no WARN or ACTION, fanned out to Cursor as `X.mdc`, and retired (backed up, then removed) when its source goes.
4. The new tests in tests/deploy-harness pass on both scripts and both lib readers. Against origin/main's scripts, 9 of the new checks fail.
5. Shipped as https://github.com/nobul-tech/aitools/pull/137 on branch `fix/cursor-fanout-md-case` (my commit 193f51c946aae5c6b171880ce050d1f854b96bfe; another session then pushed merge 38c1edb, "Merge origin/main (63dff19)", which brings in two docs-only channel commits). CI on 38c1edb: all green (linux, macos, windows, CodeQL, Analyze x4); mergeStateStatus CLEAN.

## Evidence (verified on origin/main 207f1a6 before the change)

- deploy-harness.sh:251 `*.md) ;;`: the case-sensitive filter (bash hand-back G1).
- deploy-harness.sh:433 `rules => sub { $_[0] =~ /\A[^\/\\]+\.md\z/ ...`: case-sensitive.
- deploy-harness.ps1:242 `-notlike '*.md'`: case-insensitive. deploy-harness.ps1:407/428 `$namePattern = '\A[^/\\]+\.md\z'` with `-cnotmatch`: case-sensitive (pwsh hand-back G2).
- aitools-lib.sh:2742 `qr/\A[^\/\\]+\.md\z/`; aitools-lib.ps1:2733/2753 `'\A[^/\\]+\.md\z'` with `-cnotmatch`: both case-sensitive.
- setup-user-cursor (.sh/.ps1) and setup-user-claude.sh already call the lib's `read_rules_manifest` / `Read-RulesManifest` and the case-insensitive `rule_name_kind` / `Get-RuleNameKind` (setup-user-cursor.sh:555, 602; setup-user-claude.sh:391, 434; .ps1 :566, :601 and :416, :445). The lib fix therefore reaches them unchanged.

## Verification

All results are in the worktree scratch `.scratch/session-cv-fix/`.

| What | Result |
|---|---|
| tests/deploy-harness (bash 5) | 147 passed, 0 failed, 0 skipped |
| tests/deploy-harness, new tests run against origin/main scripts (negative control) | 138 passed, 9 failed: the new upper-case and reader checks |
| fanout-lib / rules-fanout-cursor / rules-fanout / skills-fanout / managed-files / deploy-harness-mdm (bash 5) | 336/0 · 215/0 (1 skip) · 118/0 (1 skip) · 219/0 (1 skip) · 57/0 · 67/0 |
| same suites under /bin/bash 3.2 | identical counts; deploy-harness 147/0 |
| E2E (.sh): fixture with dotprofile `FX-Upper.MD`; deploy-harness `--skip-config` + setup-user-cursor.sh, run twice; then the source is removed and both run twice more | see below |
| E2E (.ps1): deploy-harness.ps1 (OS-guard copy) + step4-driver.ps1, same phases | same as .sh (the reports differ only in timestamps and paths) |
| `bash -n` (2 .sh), pwsh ParseFile (2 .ps1) | clean |
| check-pre-commit.sh | FAIL at step 6 only (pre-existing: `harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh` is 100644); WARN at step 11 (the dotprofile has uncommitted changes) |
| check-pre-push.sh | FAIL at step 7 only (pre-existing: dotprofile deploy/ is stale); WARN at steps 1, 5, 6 |

What the E2E runs showed (`e2e-out-sh/report.txt` and `e2e-out-ps/report.txt`):

- **First two runs:** the manifest has `FX-Upper.MD<TAB>dotprofile`. `~/.aitools/rules/FX-Upper.MD` and `~/.cursor/rules/FX-Upper.mdc` exist. There are no WARN or ACTION rows and no `line ignored`. The second run shows `OK|cursor rules|35 verified` and `OK|harness files|145 verified`.
- **Retire run:** the manifest has `FX-Upper.MD<TAB>retired`. Only `FX-Upper.MD.bak.<UTC>` and `FX-Upper.mdc.bak.<UTC>` remain. Rows: `DETAIL|harness files|retired: rules/FX-Upper.MD`, `DETAIL|cursor rules|removed: FX-Upper.mdc` and `OK|cursor rules|1 removed, 34 verified`.
- **Rerun after that:** all 34 rules verified.
- **deploy-harness exit code:** 1 on every run, from the fixture's five intentional duplicates (ERROR rows).

## setup-user-claude (read only)

I did not run it end to end. It fans out `~/.aitools/rules` with `rule_name_kind` (case-insensitive) and reads the manifest with the lib's `read_rules_manifest`. With this fix it therefore takes `FX-Upper.MD` as a rule (deployed as `~/.claude/rules/FX-Upper.MD`), accepts its manifest line, and can retire it. Whether Claude Code loads a `.MD` rule is still unknown (plan R10).

## CONFLICT

`CONFLICT: .claude/rules/plan-execution.md (3+ code files or a shared lib -> sub-agent per batch) vs doing the edits directly -- resolved by tier 1 (rule)`. I wrote the verbatim edit plan (`S3-CursorVerify-Fix-edit-plan.md` in scratch), and a fresh delegate, S3-CursorVerify-Fix-E1, applied the 10 lines. I verified its diff myself. I reworded one comment (aitools-lib.sh:2714-2715) after its batch. I wrote the test file myself, without a sub-agent, and say so here.

## INCIDENT markers (not filed)

- `INCIDENT: read_harness_manifest / Read-HarnessManifest reject .bak. case-sensitively (/\.bak\./, -clike) while deploy-harness's manifest plan and rule_name_kind match it case-insensitively (aitools-lib.sh:2749, aitools-lib.ps1:2753)`. Low severity: deploy-harness never writes such names. It is shared with the skills manifest, so it was left out of scope.
- `INCIDENT: tests/rules-fanout-cursor/test-rules-fanout-cursor.sh:513-515 comment says the lib reader ignores "Up.MD" as invalid; stale after this PR`. Low severity. I left it because PRs 125 and 126 rewrite that file.

## Open questions

- Should a non-lower-case extension warn (plan Q11)? Suggested answer: no, as the plan says, until Claude Code's behaviour with `.MD` is verified.

## Merge notes

- PR 125 does not touch these files.
- PR 126 changes aitools-lib.sh/.ps1 only from about line 2895 onwards. This PR changes lines 2714-2742 (.sh) and 2724-2733 (.ps1), so I expect no textual conflict.
