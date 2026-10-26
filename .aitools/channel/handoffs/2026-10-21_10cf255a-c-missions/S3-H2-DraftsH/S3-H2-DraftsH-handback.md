# S3-H2-DraftsH handback (2026-10-22)

S3-H2-DraftsH to S3-Harness2. PR: https://github.com/nobul-tech/aitools/pull/99. Branch: `docs/harness-approved-drafts` (from origin/main 8a9dcb5).

## Summary

1. All five items (a-e) are written. Most of the text is verbatim from the drafts.
2. Two approved paragraphs are false against origin/main code, so I held them. Each has a corrected draft that needs re-approval:
   - the deploy-paths staleness note (from the MDM draft);
   - the closing paragraph of the managed-file-deployment subsection (from the Core draft).
3. `.cursor/rules/deploy-paths.mdc` is derived from the approved text and needs the commander to confirm it.
4. `.cursor/rules/cross-platform.mdc` has no repos-path line, so Q5 changed only `.claude/rules/cross-platform.md`.
5. Pre-commit step 20 FAILs on three dead-path hits in the approved text. The fix is three allowlist lines in `scripts/check-path-refs-allow.txt`, which is outside my files, so it is listed as a follow-up.

## Per item

| Item | Target | Status |
|---|---|---|
| a | `.claude/skills/tool-ops/SKILL.md` Intent Scope | Applied verbatim. The OLD block matched exactly. |
| b1 | tool-ops registry `tools.cursor`, plus `meta.lastUpdated` 2026-10-22 | Applied verbatim, following the /tool-ops "Adding a new tool" process (all modes `audit`, approved, `lastUpdated` set). The draft's `_draft` wrapper note was not written. `json.load` OK; `tools.cursor == draft.cursor` is True. |
| b2 | `reference/tool-ops-cursor.md` (new) | Applied verbatim, minus the HTML "DRAFT (not applied)" comment (checked with `diff`). |
| c1 | `.claude/rules/deploy-paths.md`, MDM draft | Applied verbatim except the staleness note, which is held. |
| c2 | `.claude/rules/deploy-paths.md`, #96 row 14 | Applied verbatim from the S3-M3-Docs copy (see "Row 14 source" below). |
| c3 | `.cursor/rules/deploy-paths.mdc` | Derived from the c1 and c2 text in the .mdc's own format, with frontmatter kept. Please confirm. |
| d | `reference/managed-file-deployment.md` | Heading, paragraph and table applied verbatim. The closing paragraph is held. |
| e | `.claude/rules/cross-platform.md` line 8 | `C:\repos\` changed to `%USERPROFILE%\repos\`; nothing else changed. The .mdc twin has no such line. |

### Row 14 source

The launch prompt names `S3-M3-B5a/.../deploy-paths.md.edit.txt`. `S3-M3-Docs-approval-page.md` row 14 names `S3-M3-Docs-drafts/dot-claude/rules/deploy-paths.md.edit.txt`.

- The two copies differ in one sentence.
- B5a says every resolver consumer resolves "the dotprofile and this machine's profile". That is false: `scripts/setup-user-settings.sh:67` and `scripts/setup-user-cursor.sh:199` call only `resolve_user_repo_path`.
- S3-M3-Docs says only `setup-user-claude` also resolves the machine profile (`scripts/setup-user-claude.sh:84`, `resolve_machine_profile`). That matches the code.
- I applied the S3-M3-Docs copy.

### How the two deploy-paths drafts were merged

They overlap in two places: the paragraph after the duplication table, and the auto-embedded list.

- Row 14 replaces the duplication section and the list.
- The MDM "extract + embed" paragraph comes after row 14's resolver paragraph.
- The MDM deploy-harness bullet is the last item of the list.
- Row 14's step-7 paragraph follows the list.
- The MDM "MDM run order" section is new and sits after the intro.
- Row 14's step 2 note and its heading change are applied as written.

### .mdc twin differences from the .md

- Unchanged sections keep the .mdc's existing condensed text.
- The .mdc keeps its own intro line, which says "MDM path (`deploy/setup-*.sh/.ps1`)" and is older wording than the .md. No draft touched it.
- `@shared/claude-shared.md` is written as `shared/claude-shared.md`, because the .mdc uses no `@` links.
- The final "When changing logic in the script above (`setup-user-hooks`): ..." is one line in the .mdc's style.

## Held for re-approval (corrected drafts)

- `S3-H2-DraftsH-drafts/dot-claude/rules/deploy-paths.md.edit.txt`:
  - The approved text says "pre-push step 7 does not yet trigger on them". That is false for `shared/hooks`, `shared/skills` and `shared/rules`: `scripts/check-pre-push.sh:123` `deploy_sources` matches `^shared/`.
  - The draft also offers an optional `.claude/hooks` addition to the applied sources bullet. That source is in `scripts/deploy-harness.sh:257` but absent on main.
- `S3-H2-DraftsH-drafts/reference/managed-file-deployment.md.edit.txt`:
  - The approved text says rules reach the tools "through the `setup-user-claude` / `setup-user-cursor` fan-out".
  - On main, `setup-user-claude` has no `~/.aitools/rules` fan-out: its header at line 13 manages rules from `<userRepoPath>/claude/rules/`, and a grep for `aitools[/\]rules` in the .sh and .ps1 is empty. Only `setup-user-cursor.sh:389` reads `~/.aitools/rules`.

## Q5 grep (`git grep -F "C:\repos"`, not edited)

- `shared/cursor-rules/user-rules.md:28`: protected, and needs the same change. Suggest drafting it for approval.
- `scripts/aitools.ps1:1994`: a comment example of path conversion. Fine as is.
- `RELEASE_NOTES.md:2586`: history.
- `reference/tool-ops-cursor.md:43`: approved text, an example of a workspace outside `~`. Correct.
- Handoff notes under `.aitools/channel/handoffs/`: history.

## Verification

- `bash scripts/check-pre-commit.sh` (worktree): 6 PASS, 12 SKIP, 1 WARN, 2 FAIL.
  - Step 6: known, pre-existing.
  - Step 11 WARN: the dotprofile has uncommitted changes. They are not mine.
  - Step 20 FAIL, three hits:
    - `.claude/rules/deploy-paths.md:114` and `.cursor/rules/deploy-paths.mdc:59`: `scripts/aitools-json.pl/.ps1`. This is pair notation and both files exist.
    - `reference/managed-file-deployment.md:414`: `.claude/hooks/`, which is absent on main.
  - Step 16 (capability bypass) PASS.
- `bash scripts/check-pre-push.sh`: 6 PASS, 1 SKIP, 3 WARN, 0 FAIL.
- Every OLD block and anchor matched origin/main 8a9dcb5. I checked the claims against `scripts/build-deploy.sh`, `deploy-harness.sh`, `setup-user-cursor.sh`, `setup-user-claude.sh` and `check-pre-push.sh`.

## Not run

- build-deploy: docs only.
- The Cursor live canary.
- Windows.

## Reviewer

S3-H2-DraftsH-Review (level 3, general-purpose, no isolation) found **NO BLOCKING FINDINGS**.

- Review: https://github.com/nobul-tech/aitools/pull/99#pullrequestreview-5623165189
- Verdict file: `S3-H2-DraftsH-Review-verdict.md`, in this folder.
- What it found:
  - Every applied draft block appears verbatim in its target. It checked this with scripts.
  - `tools.cursor` equals the draft.
  - Both held paragraphs were held for a correct reason.
  - The `.mdc` twin carries every approved paragraph word for word.
  - Only the 9 expected files changed.
- Non-blocking findings:
  - N1: step 20 will FAIL repo-wide after merge until the 3 allowlist lines land.
  - N2: lines in the `.mdc` that were already stale before this PR (for example "Verify via pre-commit steps 3+10").
  - N3: `shared/cursor-rules/user-rules.md:28` still says `C:\repos\`.
  - N6: the I6 "structural fix" paragraph in deploy-paths.md is stale, but no draft covers it.
- I spot-checked one claim, N3's `scripts/aitools-install.ps1:324,333` (`Join-Path $env:USERPROFILE "repos"`): confirmed. The line numbers moved from the 266/275 cited in older handbacks.
- No fixes were needed.

## WRITE_BLOCKED

None.

## INCIDENT markers (not filed)

- INCIDENT (low): `scripts/check-path-refs.py` (pre-commit step 20) reads the pair notation `scripts/aitools-json.pl/.ps1` as one path. `aitools-profile.sh/.ps1` passes, so the checker probably special-cases only `.sh/.ps1`. This is unverified; I did not read the checker.
- INCIDENT (low): `scripts/check-path-refs-allow.txt:11-12` list `reference/tool-ops-cursor.md` as "a future per-tool ops reference". The file now exists, so those entries are stale. Keep them only if they are fixtures.
- INCIDENT (low): `.cursor/rules/deploy-paths.mdc` already lagged its `.md` twin before this PR. Its old text said "Four script pairs" and listed `setup-user-mcp` as duplicated. The parity rule (`.cursor/rules/cursor-rule-parity.mdc`) has no check.

## Questions (with suggested answers)

1. Should the corrected staleness note and the closing paragraph be applied? I suggest yes: they keep the approved wording and only make the claims match the code.
2. Should I add the three allowlist lines (or a delegate do it)? I suggest yes, in this PR, because they only exist because of this PR's text. The file is outside my ownership list, so I need the commander's or S3-Harness2's say-so.
3. Should `shared/cursor-rules/user-rules.md:28` get the Q5 change too? I suggest yes, as a protected draft.
4. Is the derived `.mdc` twin acceptable? I suggest yes. An alternative is to mirror the `.md` body verbatim under the `.mdc` frontmatter.
